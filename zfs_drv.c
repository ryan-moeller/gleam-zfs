/*
 * Copyright (c) 2026 Ryan Moeller
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <sys/ioctl.h>
#include <sys/zfs_ioctl.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <libnvpair.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <erl_driver.h>
#include <ei.h>

#define ZFS_DRV "zfs_drv"
#define ZFS_IOCVER_OZFS	15

typedef struct zfs_iocparm {
	uint32_t zfs_ioctl_version;
	uint64_t zfs_cmd;
	uint64_t zfs_cmd_size;
} zfs_iocparm_t;

/*
 * Per-instance state structure.
 *
 * XXX: What is the mapping of state <-> threads?  Does each driver open spawn a
 * dedicated thread, or do they share threads?  Ideally, a thread pool is used
 * service concurrent operations without dedicating a thread to each handle.  It
 * is expected that many handles will need to be opened and in use concurrently.
 *
 * For now, we can at least open multiple instances of the driver, which is
 * enough to be usable even if not necessarily the most optimal implementation.
 */
typedef struct zfs_state {
	int fd;			/* /dev/zfs file descriptor */
} ZfsState;

static ErlDrvSSizeT _zfs_fatal(char **, ErlDrvSizeT);

#ifdef NDEBUG
#define zfs_fatal(rbuf, rlen) _zfs_fatal((rbuf), (rlen))
#else
#define zfs_fatal(rbuf, rlen) ({ \
	fprintf(stderr, "[%s:%d] fatal error\n", __func__, __LINE__); \
	_zfs_fatal((rbuf), (rlen)); \
})
#endif

static int
decode_option(const char *buf, int *index)
{
	char atom[MAXATOMLEN];
	int type, size, arity;

	if (ei_get_type(buf, index, &type, &size) == -1)
		return -1;
	switch (type) {
	case ERL_ATOM_EXT:
		if (ei_decode_atom(buf, index, atom) == -1 ||
		    strcmp(atom, "none") != 0)
			return -1;
		return 0;
	case ERL_SMALL_TUPLE_EXT:
		if (ei_decode_tuple_header(buf, index, &arity) == -1 ||
		    arity != 2)
			return -1;
		if (ei_decode_atom(buf, index, atom) == -1 ||
		    strcmp(atom, "some") != 0)
			return -1;
		return 1;
	default:
		return -1;
	}
	__builtin_unreachable();
}

static inline void
encode_ok_header(ei_x_buff *x)
{
	ei_x_encode_tuple_header(x, 2);
	ei_x_encode_atom(x, "ok");
}

static inline void
encode_error_header(ei_x_buff *x)
{
	ei_x_encode_tuple_header(x, 2);
	ei_x_encode_atom(x, "error");
}

static inline void
encode_none(ei_x_buff *x)
{
	ei_x_encode_atom(x, "none");
}

static inline void
encode_some_header(ei_x_buff *x)
{
	ei_x_encode_tuple_header(x, 2);
	ei_x_encode_atom(x, "some");
}

static inline void
encode_zfs_cmd_res_headerv(ei_x_buff *x, zfs_cmd_t *zc, int error,
    const char *fmt, va_list ap)
{
	/* 5 = {zfs_cmd_res, Zc, Error, Msg, Dst} */
	ei_x_encode_tuple_header(x, 5);
	ei_x_encode_atom(x, "zfs_cmd_res");
	ei_x_encode_binary(x, zc, sizeof *zc);
	ei_x_encode_long(x, error);
	if (fmt == NULL)
		encode_none(x);
	else {
		char msg[NL_TEXTMAX];
		int len;

		len = vsnprintf(msg, sizeof msg, fmt, ap);
		assert(len < sizeof msg);

		encode_some_header(x);
		ei_x_encode_binary(x, msg, len);
	}
}

static inline ErlDrvSSizeT
buff_fill(ei_x_buff *x, char **rbuf, ErlDrvSizeT rlen)
{
	size_t len = x->index;

	if (len > rlen) {
		*rbuf = driver_alloc(len);
		assert(*rbuf != NULL);
	}
	memcpy(*rbuf, x->buff, len);
	ei_x_free(x);
	return len;
}

/* invalid messages result in Error(Nil), but this should be reconsidered */
static ErlDrvSSizeT
_zfs_fatal(char **rbuf, ErlDrvSizeT rlen)
{
	ei_x_buff x;

	ei_x_new_with_version(&x);
	encode_error_header(&x);
	ei_x_encode_atom(&x, "nil");

	return buff_fill(&x, rbuf, rlen);
}

/* ioctl errors are encoded as Ok() of a ZfsCmdRes with error info */
static ErlDrvSSizeT
zfs_unit(char **rbuf, ErlDrvSizeT rlen, zfs_cmd_t *zc, int error,
    const char *fmt, ...)
{
	ei_x_buff x;
	va_list ap;

	ei_x_new_with_version(&x);
	encode_ok_header(&x);
	va_start(ap, fmt);
	encode_zfs_cmd_res_headerv(&x, zc, error, fmt, ap);
	va_end(ap);
	encode_none(&x);

	return buff_fill(&x, rbuf, rlen);
}

static ErlDrvData
zfs_start(ErlDrvPort port, char *command __unused)
{
	ZfsState *zfs = driver_alloc(sizeof *zfs);
	zfs->fd = open(ZFS_DEV, O_RDWR | O_CLOEXEC);
	if (zfs->fd < 0) {
		int error = errno;
		driver_free(zfs);
		errno = error;
		return ERL_DRV_ERROR_ERRNO;
	}
	return (ErlDrvData)zfs;
}

static void
zfs_stop(ErlDrvData handle)
{
	ZfsState *zfs = (ZfsState *)handle;
	(void) close(zfs->fd);
	driver_free(zfs);
}

static int
zfs_ioctl(ZfsState *zfs, unsigned long request, zfs_cmd_t *zc)
{
	zfs_iocparm_t zp;
	size_t oldsize;

	oldsize = zc->zc_nvlist_dst_size;
	zp.zfs_cmd = (uint64_t)(uintptr_t)zc;
	zp.zfs_cmd_size = sizeof (zfs_cmd_t);
	zp.zfs_ioctl_version = ZFS_IOCVER_OZFS;
	if (ioctl(zfs->fd, _IOWR('Z', request, zfs_iocparm_t), &zp) != 0)
		return errno;
	if (oldsize < zc->zc_nvlist_dst_size)
		return ENOMEM;
	return 0;
}

static ErlDrvSSizeT
zfs_call(ErlDrvData handle, unsigned int command, char *buf, ErlDrvSizeT len,
    char **rbuf, ErlDrvSizeT rlen, unsigned int *ret_flags)
{
	ZfsState *zfs = (ZfsState *)handle;
	zfs_ioc_t ioc = command;
	zfs_cmd_t zc;

	/*
	 * Interpret buf according to command.  Different commands use different
	 * fields of zfs_cmd_t, some of which are pointers or are otherwise
	 * non-serializable, so must be assembled here in C.
	 *
	 * There can be multiple input nvlists for some commands.  The encoding
	 * is as follows:
	 *
	 *   zc: BitArray zfs_cmd_t
	 *   history: Option(String)
	 *   src: Option(BitArray) packed nvlist
	 *   conf: Option(BitArray) packed nvlist
	 *
	 * Results are sent back with the following encoding:
	 *
	 *   zc: BitArray zfs_cmd_t
	 *   error: Int
	 *   error message: Option(String)
	 *   dst: Option(BitArray) packed nvlist (usually)
	 */

	char atom[MAXATOMLEN];
	long binlen;
	int version, arity, type, size;
	int index = 0;

	if (ei_decode_version(buf, &index, &version) == -1)
		return zfs_fatal(rbuf, rlen);

	ei_decode_tuple_header(buf, &index, &arity);
	if (arity != 5) /* {zfs_cmd_req, ZfsCmd, History, Src, Conf} */
		return zfs_fatal(rbuf, rlen);

	if (ei_decode_atom(buf,	&index, atom) == -1 ||
	    strcmp(atom, "zfs_cmd_req") != 0)
		return zfs_fatal(rbuf, rlen);

	if (ei_get_type(buf, &index, &type, &size) == -1 ||
	    type != ERL_BINARY_EXT || size != sizeof zc)
		return zfs_fatal(rbuf, rlen);
	if (ei_decode_binary(buf, &index, &zc, &binlen) == -1)
		return zfs_fatal(rbuf, rlen);
	assert(binlen == size);

	char history[HIS_MAX_RECORD_LEN];
	switch (decode_option(buf, &index)) {
	case 1:
		if (ei_get_type(buf, &index, &type, &size) == -1 ||
		    type != ERL_BINARY_EXT || size >= sizeof history)
			return zfs_fatal(rbuf, rlen);
		if (ei_decode_binary(buf, &index, history, &binlen) == -1)
			return zfs_fatal(rbuf, rlen);
		history[binlen] = '\0';
		zc.zc_history = (uint64_t)(uintptr_t)history;
		break;
	case 0: break;
	case -1: return zfs_fatal(rbuf, rlen);
	}

	/* Populate an input nvlist pointer if provided. */
#define NVLIST(name) ({ \
	const char *p; \
	unsigned int bitoffs; \
	size_t nbits; \
	switch (decode_option(buf, &index)) { \
	case 1: \
		if (ei_get_type(buf, &index, &type, &size) == -1 || \
		    type != ERL_BINARY_EXT) \
			return zfs_fatal(rbuf, rlen); \
		if (ei_decode_bitstring(buf, &index, &p, &bitoffs, &nbits) \
		    == -1 || bitoffs != 0 || (nbits & 0x7) != 0) \
			return zfs_fatal(rbuf, rlen); \
		zc.zc_nvlist_ ## name = (uint64_t)(uintptr_t)p; \
		zc.zc_nvlist_ ## name ## _size = nbits >> 3; \
		break; \
	case 0: break; \
	case -1: return zfs_fatal(rbuf, rlen); \
	} \
})
	NVLIST(src);
	NVLIST(conf);

	ErlDrvSSizeT res;
	int error;

#define zfs_success() ({ \
	res = zfs_unit(rbuf, rlen, &zc, 0, NULL); \
})
#define zfs_error(error, fmt, ...) ({ \
	res = zfs_unit(rbuf, rlen, &zc, (error), fmt, __VA_ARGS__); \
})

	ErlDrvBinary *result = NULL;

	/* Allocate/resize the result buffer. */
#define RESULT(size) ({ \
	result = driver_realloc_binary(result, (size)); \
	assert(result != NULL); /* XXX */ \
	zc.zc_nvlist_dst_size = result->orig_size; \
	zc.zc_nvlist_dst = (uint64_t)(uintptr_t)&result->orig_bytes[0]; \
})

#define zfs_result(error) ({ \
	ei_x_buff x; \
	ei_x_new_with_version(&x); \
	encode_ok_header(&x); \
	encode_zfs_cmd_res_headerv(&x, &zc, (error), NULL, NULL); \
	encode_some_header(&x); \
	assert(zc.zc_nvlist_dst_filled); \
	assert(zc.zc_nvlist_dst_size <= result->orig_size); \
	ei_x_encode_binary(&x, result->orig_bytes, zc.zc_nvlist_dst_size); \
	driver_free_binary(result); \
	res = buff_fill(&x, rbuf, rlen); \
})

#define zfs_ioctl_checked(ioc, ...) ({ \
	if ((error = zfs_ioctl(zfs, (ioc), &zc)) != 0) { \
		__VA_ARGS__; \
		zfs_error(error, "ioctl(%s) failed", ZFS_DEV); \
		break; \
	} \
})

#define zfs_ioctl_resize_checked(ioc, ...) ({ \
	while ((error = zfs_ioctl(zfs, (ioc), &zc)) == ENOMEM) { \
		__VA_ARGS__; \
		assert(zc.zc_nvlist_dst_size > result->orig_size); \
		RESULT(zc.zc_nvlist_dst_size); \
	} \
	if (error != 0) { \
		if (zc.zc_nvlist_dst_filled) { \
			zfs_result(error); \
			break; \
		} \
		driver_free_binary(result); \
		zfs_error(error, "ioctl(%s) failed", ZFS_DEV); \
		break; \
	} \
})

	/* A basic ioctl returning unit (nothing) or an error. */
#define zfs_ioctl_unit(ioc) ({ \
	zfs_ioctl_checked(ioc); \
	zfs_success(); \
})

	/* A basic ioctl returning an nvlist or an error. */
#define zfs_ioctl_nvlist(ioc, ...) ({ \
	zfs_ioctl_resize_checked(ioc, __VA_ARGS__); \
	if (zc.zc_nvlist_dst_filled) { \
		zfs_result(error); \
		break; \
	} \
	driver_free_binary(result); \
	zfs_success(); \
})

	/* An ioctl with a sentinel errno. */
#define zfs_ioctl_sentinel(ioc, sentinel, ...) ({ \
	zfs_ioctl_checked(ioc, ({ \
		if (error == (sentinel)) { \
			res = zfs_unit(rbuf, rlen, &zc, sentinel, NULL); \
			break; \
		} \
	})); \
	zfs_success(); \
})

	switch (ioc) {
	case ZFS_IOC_POOL_DESTROY:
	case ZFS_IOC_POOL_EXPORT:
	case ZFS_IOC_POOL_SCAN:
	case ZFS_IOC_POOL_FREEZE:
	case ZFS_IOC_USERSPACE_UPGRADE:
	case ZFS_IOC_UNLOAD_KEY:
	case ZFS_IOC_POOL_CHECKPOINT:
	case ZFS_IOC_POOL_DISCARD_CHECKPOINT:
	case ZFS_IOC_POOL_UPGRADE:
	case ZFS_IOC_VDEV_REMOVE:
	case ZFS_IOC_VDEV_SET_STATE:
	case ZFS_IOC_VDEV_DETACH:
	case ZFS_IOC_CLEAR_FAULT:
	case ZFS_IOC_VDEV_SETPATH:
	case ZFS_IOC_VDEV_SETFRU:
	case ZFS_IOC_DESTROY:
	case ZFS_IOC_RENAME:
	case ZFS_IOC_SEND:
	case ZFS_IOC_INJECT_FAULT:
	case ZFS_IOC_INJECT_LIST_NEXT:
	case ZFS_IOC_DSOBJ_TO_DSNAME:
	case ZFS_IOC_OBJ_TO_PATH:
	case ZFS_IOC_INHERIT_PROP:
	case ZFS_IOC_USERSPACE_ONE:
	case ZFS_IOC_DIFF:
	case ZFS_IOC_TMP_SNAPSHOT:
	case ZFS_IOC_OBJ_TO_STATS:
	case ZFS_IOC_SPACE_WRITTEN:
	case ZFS_IOC_SEND_PROGRESS:
	case ZFS_IOC_JAIL:
	case ZFS_IOC_UNJAIL:
	case ZFS_IOC_POOL_REGUID:
	case ZFS_IOC_POOL_REOPEN:
	case ZFS_IOC_POOL_CREATE:
	case ZFS_IOC_VDEV_ADD:
	case ZFS_IOC_VDEV_ATTACH:
	case ZFS_IOC_VDEV_SPLIT:
	case ZFS_IOC_CREATE:
	case ZFS_IOC_POOL_SET_PROPS:
	case ZFS_IOC_LOG_HISTORY:
	case ZFS_IOC_SEND_NEW:
	case ZFS_IOC_POOL_SYNC:
	case ZFS_IOC_LOAD_KEY:
	case ZFS_IOC_CHANGE_KEY:
	case ZFS_IOC_REDACT:
	case ZFS_IOC_POOL_SCRUB:
	case ZFS_IOC_POOL_PREFETCH:
	case ZFS_IOC_DDT_PRUNE:
	case ZFS_IOC_NEXTBOOT:
	case ZFS_IOC_SET_BOOTENV:
	case ZFS_IOC_SET_FSACL:
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_POOL_STATS:
	case ZFS_IOC_OBJSET_ZPLPROPS:
	case ZFS_IOC_POOL_GET_PROPS:
	case ZFS_IOC_OBJSET_RECVD_PROPS:
	case ZFS_IOC_GET_FSACL:
	case ZFS_IOC_GET_HOLDS:
	case ZFS_IOC_GET_BOOKMARK_PROPS:
	case ZFS_IOC_GET_BOOTENV:
	case ZFS_IOC_ROLLBACK:
	case ZFS_IOC_SEND_SPACE:
	case ZFS_IOC_GET_BOOKMARKS:
	case ZFS_IOC_RECV:
	case ZFS_IOC_POOL_TRYIMPORT:
	case ZFS_IOC_POOL_IMPORT:
	case ZFS_IOC_SNAPSHOT:
	case ZFS_IOC_SPACE_SNAPS:
	case ZFS_IOC_DESTROY_SNAPS:
	case ZFS_IOC_CLONE:
	case ZFS_IOC_BOOKMARK:
	case ZFS_IOC_DESTROY_BOOKMARKS:
	case ZFS_IOC_RECV_NEW:
	case ZFS_IOC_POOL_INITIALIZE:
	case ZFS_IOC_POOL_TRIM:
	case ZFS_IOC_WAIT:
	case ZFS_IOC_WAIT_FS:
	case ZFS_IOC_VDEV_GET_PROPS:
	case ZFS_IOC_VDEV_SET_PROPS:
	case ZFS_IOC_SET_PROP:
	case ZFS_IOC_HOLD:
	case ZFS_IOC_RELEASE:
	case ZFS_IOC_CLEAR:
		if ((zc.zc_cookie & ZPOOL_NO_REWIND) == 0)
			RESULT(zc.zc_nvlist_dst_size);
		zfs_ioctl_nvlist(ioc, ({
			if ((zc.zc_cookie & ZPOOL_NO_REWIND) != 0)
				break;
		}));
		break;
	case ZFS_IOC_POOL_CONFIGS: {
		RESULT(zc.zc_nvlist_dst_size);
		uint64_t gen = zc.zc_cookie;
		zfs_ioctl_nvlist(ioc, ({
			zc.zc_cookie = gen; /* reset gen */
		}));
		break;
	}
	case ZFS_IOC_POOL_GET_HISTORY: {
		/*
		 * This ioctl returns an offset and a buffer filled with
		 * <size, packed nvlist> records.  We encode these into a single
		 * binary result rather than adding additional nvlists.
		 */
		result = driver_alloc_binary(128 << 10);
		assert(result != NULL); /* XXX */
		zc.zc_history_len = result->orig_size;
		zc.zc_history = (uint64_t)(uintptr_t)&result->orig_bytes[0];
		/* Reserve leading space for offset. */
		zc.zc_history_len -= sizeof (uint64_t);
		zc.zc_history += sizeof (uint64_t);
		zfs_ioctl_checked(ioc, ({
			driver_free_binary(result);
		}));
		/* Fill in offset. */
		(void) memcpy(result->orig_bytes, &zc.zc_history_offset,
		    sizeof (uint64_t));

		ei_x_buff x;

		ei_x_new_with_version(&x);
		encode_ok_header(&x);
		encode_zfs_cmd_res_headerv(&x, &zc, error, NULL, NULL);
		encode_some_header(&x);

		assert(zc.zc_history_len <=
		    (result->orig_size - sizeof (uint64_t)));
		ei_x_encode_binary(&x, result->orig_bytes,
		    zc.zc_history_len + sizeof (uint64_t));
		driver_free_binary(result);

		res = buff_fill(&x, rbuf, rlen);
		break;
	}
	case ZFS_IOC_OBJSET_STATS:
		if (!zc.zc_simple)
			RESULT(zc.zc_nvlist_dst_size);
		zfs_ioctl_nvlist(ioc, ({
			if (zc.zc_simple)
				break;
		}));
		break;
	case ZFS_IOC_USERSPACE_MANY:
		RESULT(zc.zc_nvlist_dst_size);
		zfs_ioctl_resize_checked(ioc);
		zfs_result(error);
		break;
	case ZFS_IOC_DATASET_LIST_NEXT:
	case ZFS_IOC_SNAPSHOT_LIST_NEXT: {
		if (!zc.zc_simple)
			RESULT(zc.zc_nvlist_dst_size);
		char name[ZFS_MAX_DATASET_NAME_LEN];
		uint64_t cookie = zc.zc_cookie;
		strlcpy(name, zc.zc_name, sizeof name);
		while ((error = zfs_ioctl(zfs, ioc, &zc)) == ENOMEM) {
			if (zc.zc_simple)
				break;
			assert(zc.zc_nvlist_dst_size >
			    result->orig_size);
			RESULT(zc.zc_nvlist_dst_size);
			/* Restore request fields. */
			(void) strcpy(zc.zc_name, name);
			zc.zc_cookie = cookie;
			zc.zc_objset_stats.dds_creation_txg = 0;
		}
		if (error == ESRCH)
			zfs_success();
		else
			zfs_result(error);
		break;
	}
	case ZFS_IOC_ERROR_LOG: {
		uint64_t count = zc.zc_nvlist_dst_size;
		result = driver_realloc_binary(result,
		    count * sizeof (zbookmark_phys_t));
		assert(result != NULL); /* XXX */
		zc.zc_nvlist_dst = (uint64_t)(uintptr_t)&result->orig_bytes[0];
		zfs_ioctl_resize_checked(ioc, ({
			count *= 2;
			result = driver_realloc_binary(result,
			    count * sizeof (zbookmark_phys_t));
			assert(result != NULL); /* XXX */
			zc.zc_nvlist_dst =
			    (uint64_t)(uintptr_t)&result->orig_bytes[0];
			zc.zc_nvlist_dst_size = count;
		}));

		ei_x_buff x;

		ei_x_new_with_version(&x);
		encode_ok_header(&x);
		encode_zfs_cmd_res_headerv(&x, &zc, error, NULL, NULL);
		encode_some_header(&x);

		/*
		 * This ioctl fills the buffer from the back and returns
		 * with the remaining leading space in nvlist_dst_size.
		 */
		size_t pad =
		    zc.zc_nvlist_dst_size * sizeof (zbookmark_phys_t);
		char *p = result->orig_bytes + pad;
		size_t len = result->orig_size - pad;
		ei_x_encode_binary(&x, p, len);
		driver_free_binary(result);

		res = buff_fill(&x, rbuf, rlen);
		break;
	}
	case ZFS_IOC_PROMOTE:
		zfs_ioctl_sentinel(ioc, EEXIST);
		break;
	case ZFS_IOC_NEXT_OBJ:
		zfs_ioctl_sentinel(ioc, ESRCH);
		break;
	case ZFS_IOC_CHANNEL_PROGRAM:
		RESULT(zc.zc_nvlist_dst_size);
		zfs_ioctl_checked(ioc, ({
			if (zc.zc_nvlist_dst_filled) {
				zfs_result(error);
				break;
			}
			driver_free_binary(result);
		}));
		zfs_result(error);
		break;
	default:
		zfs_error(EINVAL, "invalid ioctl", ZFS_DRV);
		break;
	}
	return res;
}

static ErlDrvEntry zfs_driver_entry = {
	.init = NULL,
	.start = zfs_start,
	.stop = zfs_stop,
	.output = NULL,
	.ready_input = NULL,
	.ready_output = NULL,
	.driver_name = ZFS_DRV,
	.finish = NULL,
	.handle = NULL,
	.control = NULL,
	.timeout = NULL,
	.outputv = NULL,
	.ready_async = NULL,
	.flush = NULL,
	.call = zfs_call,
	.unused_event_callback = NULL,
	.extended_marker = ERL_DRV_EXTENDED_MARKER,
	.major_version = ERL_DRV_EXTENDED_MAJOR_VERSION,
	.minor_version = ERL_DRV_EXTENDED_MINOR_VERSION,
	.driver_flags = 0,
	.handle2 = NULL,
	.process_exit = NULL,
	.stop_select = NULL,
};

DRIVER_INIT(zfs_drv)
{
	return &zfs_driver_entry;
}
