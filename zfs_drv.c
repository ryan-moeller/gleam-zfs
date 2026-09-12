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

typedef struct zfs_state {
	ErlDrvPort port;	/* owner */
	int fd;			/* /dev/zfs file descriptor */
} ZfsState;

typedef struct zfs_request {
	ZfsState *zfs;
	ei_x_buff ref;
	zfs_ioc_t ioc;
	zfs_cmd_t zc;
	char *history;
	ei_x_buff res;
} ZfsRequest;

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
encode_zfs_cmd_res_headerv(ZfsRequest *req, int error, const char *fmt,
    va_list ap)
{
	ei_x_buff *x = &req->res;

	/* 5 = {zfs_cmd_res, Zc, Error, Msg, Dst} */
	ei_x_encode_tuple_header(x, 5);
	ei_x_encode_atom(x, "zfs_cmd_res");
	ei_x_encode_binary(x, &req->zc, sizeof req->zc);
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

static inline ZfsRequest *
request_alloc(ZfsState *zfs)
{
	ZfsRequest *req = driver_alloc(sizeof *req);
	req->zfs = zfs;
	req->history = NULL;
	ei_x_new_with_version(&req->ref);
	ei_x_new_with_version(&req->res);
	return req;
}

static inline void
request_free(ZfsRequest *req)
{
	driver_free(req->history);
	ei_x_free(&req->ref);
	ei_x_free(&req->res);
	driver_free(req);
}

static inline void
_zfs_fatal(ZfsRequest *req, const char *func, int line)
{
#ifndef NDEBUG
	(void) fprintf(stderr, "[%s:%d] fatal error\n", func, line);
#endif
	request_free(req);
}

#define zfs_fatal(req) _zfs_fatal((req), __func__, __LINE__)

static void
zfs_unit(ZfsRequest *req, int error, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	encode_zfs_cmd_res_headerv(req, error, fmt, ap);
	va_end(ap);
	encode_none(&req->res);
}

static ErlDrvData
zfs_start(ErlDrvPort port, char *command __unused)
{
	ZfsState *zfs = driver_alloc(sizeof *zfs);
	zfs->port = port;
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
zfs_stop(ErlDrvData drv_data)
{
	ZfsState *zfs = (ZfsState *)drv_data;
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

static void zfs_async(void *);

static void
zfs_output(ErlDrvData drv_data, char *buf, ErlDrvSizeT len)
{
	ZfsRequest *req = request_alloc((ZfsState *)drv_data);

	/*
	 * Interpret buf to determine command.  Different commands use different
	 * fields of zfs_cmd_t, some of which are pointers or are otherwise
	 * non-serializable, so must be assembled here in C.
	 *
	 * There can be multiple input nvlists for some commands.  The encoding
	 * is as follows:
	 *
	 *   {Ref, Ioc, {zfs_cmd_req, Zc, History, Src, Conf}}
	 *
	 *   Ref: ref()
	 *   Ioc: int()
	 *   Zc: BitArray zfs_cmd_t
	 *   History: Option(String)
	 *   Src: Option(BitArray) packed nvlist
	 *   Conf: Option(BitArray) packed nvlist
	 *
	 * Results are sent back with the following encoding:
	 *
	 *   {Ref, {zfs_cmd_res, Zc, Error, ErrorMessage, Dst}}
	 *
	 *   Ref: ref()
	 *   Zc: BitArray zfs_cmd_t
	 *   Error: Int
	 *   ErrorMessage: Option(String)
	 *   Dst: Option(BitArray) packed nvlist (usually)
	 */

	char atom[MAXATOMLEN];
	long binlen, ioc;
	int version, arity, type, size;
	int index = 0;

	if (ei_decode_version(buf, &index, &version) == -1)
		return zfs_fatal(req);

	ei_decode_tuple_header(buf, &index, &arity);
	/* 3 = {Ref, Ioc, Req} */
	if (arity != 3)
		return zfs_fatal(req);

	if (ei_get_type(buf, &index, &type, &size) == -1 ||
	    type != ERL_NEW_REFERENCE_EXT)
		return zfs_fatal(req);
	int ref_start = index;
	if (ei_skip_term(buf, &index) == -1)
		return zfs_fatal(req);
	ei_x_append_buf(&req->ref, &buf[ref_start], index - ref_start);

	if (ei_decode_long(buf, &index, &ioc) == -1)
		return zfs_fatal(req);
	req->ioc = ioc;

	ei_decode_tuple_header(buf, &index, &arity);
	/* 5 = {zfs_cmd_req, ZfsCmd, History, Src, Conf} */
	if (arity != 5)
		return zfs_fatal(req);

	if (ei_decode_atom(buf,	&index, atom) == -1 ||
	    strcmp(atom, "zfs_cmd_req") != 0)
		return zfs_fatal(req);

	if (ei_get_type(buf, &index, &type, &size) == -1 ||
	    type != ERL_BINARY_EXT || size != sizeof req->zc)
		return zfs_fatal(req);
	if (ei_decode_binary(buf, &index, &req->zc, &binlen) == -1)
		return zfs_fatal(req);
	assert(binlen == size);

	switch (decode_option(buf, &index)) {
	case 1:
		req->history = driver_alloc(HIS_MAX_RECORD_LEN);
		if (ei_get_type(buf, &index, &type, &size) == -1 ||
		    type != ERL_BINARY_EXT || size >= HIS_MAX_RECORD_LEN)
			return zfs_fatal(req);
		if (ei_decode_binary(buf, &index, req->history, &binlen) == -1)
			return zfs_fatal(req);
		req->history[binlen] = '\0';
		req->zc.zc_history = (uint64_t)(uintptr_t)req->history;
		break;
	case 0:
		req->history = NULL;
		break;
	case -1:
		return zfs_fatal(req);
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
			return zfs_fatal(req); \
		if (ei_decode_bitstring(buf, &index, &p, &bitoffs, &nbits) \
		    == -1 || bitoffs != 0 || (nbits & 0x7) != 0) \
			return zfs_fatal(req); \
		req->zc.zc_nvlist_ ## name = (uint64_t)(uintptr_t)p; \
		req->zc.zc_nvlist_ ## name ## _size = nbits >> 3; \
		break; \
	case 0: break; \
	case -1: return zfs_fatal(req); \
	} \
})
	NVLIST(src);
	NVLIST(conf);

	if (driver_async(req->zfs->port, NULL, zfs_async, req, NULL) == -1)
		return zfs_fatal(req);
}

static void
zfs_async(void *async_data)
{
	ZfsRequest *req = async_data;
	ErlDrvBinary *result = NULL;
	zfs_cmd_t *zc = &req->zc;
	int error;

#define zfs_success() ({ \
	zfs_unit(req, 0, NULL); \
})
#define zfs_error(error, fmt, ...) ({ \
	zfs_unit(req, (error), fmt, __VA_ARGS__); \
})

	/* Allocate/resize the result buffer. */
#define RESULT(size) ({ \
	result = driver_realloc_binary(result, (size)); \
	assert(result != NULL); /* XXX */ \
	zc->zc_nvlist_dst_size = result->orig_size; \
	zc->zc_nvlist_dst = (uint64_t)(uintptr_t)&result->orig_bytes[0]; \
})

#define zfs_result(error) ({ \
	ei_x_buff *x = &req->res; \
	encode_zfs_cmd_res_headerv(req, (error), NULL, NULL); \
	encode_some_header(x); \
	assert(zc->zc_nvlist_dst_filled); \
	assert(zc->zc_nvlist_dst_size <= result->orig_size); \
	ei_x_encode_binary(x, result->orig_bytes, zc->zc_nvlist_dst_size); \
	driver_free_binary(result); \
})

#define zfs_ioctl_checked(ioc, ...) ({ \
	if ((error = zfs_ioctl(req->zfs, (ioc), zc)) != 0) { \
		__VA_ARGS__; \
		return zfs_error(error, "ioctl(%s) failed", ZFS_DEV); \
	} \
})

#define zfs_ioctl_resize_checked(ioc, ...) ({ \
	while ((error = zfs_ioctl(req->zfs, (ioc), zc)) == ENOMEM) { \
		__VA_ARGS__; \
		assert(zc->zc_nvlist_dst_size > result->orig_size); \
		RESULT(zc->zc_nvlist_dst_size); \
	} \
	if (error != 0) { \
		if (zc->zc_nvlist_dst_filled) \
			return zfs_result(error); \
		driver_free_binary(result); \
		return zfs_error(error, "ioctl(%s) failed", ZFS_DEV); \
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
	if (zc->zc_nvlist_dst_filled) \
		return zfs_result(error); \
	driver_free_binary(result); \
	return zfs_success(); \
})

	/* An ioctl with a sentinel errno. */
#define zfs_ioctl_sentinel(ioc, sentinel, ...) ({ \
	zfs_ioctl_checked(ioc, ({ \
		if (error == (sentinel)) \
			return zfs_unit(req, sentinel, NULL); \
	})); \
	zfs_success(); \
})

	switch (req->ioc) {
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
		return zfs_ioctl_unit(req->ioc);
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
		if ((zc->zc_cookie & ZPOOL_NO_REWIND) == 0)
			RESULT(zc->zc_nvlist_dst_size);
		return zfs_ioctl_nvlist(req->ioc, ({
			if ((zc->zc_cookie & ZPOOL_NO_REWIND) != 0)
				return;
		}));
	case ZFS_IOC_POOL_CONFIGS: {
		RESULT(zc->zc_nvlist_dst_size);
		uint64_t gen = zc->zc_cookie;
		return zfs_ioctl_nvlist(req->ioc, ({
			zc->zc_cookie = gen; /* reset gen */
		}));
	}
	case ZFS_IOC_POOL_GET_HISTORY: {
		/*
		 * This ioctl returns an offset and a buffer filled with
		 * <size, packed nvlist> records.  We encode these into a single
		 * binary result rather than adding additional nvlists.
		 */
		result = driver_alloc_binary(128 << 10);
		assert(result != NULL); /* XXX */
		zc->zc_history_len = result->orig_size;
		zc->zc_history = (uint64_t)(uintptr_t)&result->orig_bytes[0];
		/* Reserve leading space for offset. */
		zc->zc_history_len -= sizeof (uint64_t);
		zc->zc_history += sizeof (uint64_t);
		zfs_ioctl_checked(req->ioc, ({
			driver_free_binary(result);
		}));
		/* Fill in offset. */
		(void) memcpy(result->orig_bytes, &zc->zc_history_offset,
		    sizeof (uint64_t));

		ei_x_buff *x = &req->res;

		encode_zfs_cmd_res_headerv(req, error, NULL, NULL);
		encode_some_header(x);

		assert(zc->zc_history_len <=
		    (result->orig_size - sizeof (uint64_t)));
		ei_x_encode_binary(x, result->orig_bytes,
		    zc->zc_history_len + sizeof (uint64_t));
		driver_free_binary(result);
		return;
	}
	case ZFS_IOC_OBJSET_STATS:
		if (!zc->zc_simple)
			RESULT(zc->zc_nvlist_dst_size);
		return zfs_ioctl_nvlist(req->ioc, ({
			if (zc->zc_simple)
				return;
		}));
	case ZFS_IOC_USERSPACE_MANY:
		RESULT(zc->zc_nvlist_dst_size);
		zfs_ioctl_resize_checked(req->ioc);
		return zfs_result(error);
	case ZFS_IOC_DATASET_LIST_NEXT:
	case ZFS_IOC_SNAPSHOT_LIST_NEXT: {
		if (!zc->zc_simple)
			RESULT(zc->zc_nvlist_dst_size);
		char name[ZFS_MAX_DATASET_NAME_LEN];
		uint64_t cookie = zc->zc_cookie;
		strlcpy(name, zc->zc_name, sizeof name);
		while ((error = zfs_ioctl(req->zfs, req->ioc, zc)) == ENOMEM) {
			if (zc->zc_simple)
				break;
			assert(zc->zc_nvlist_dst_size >
			    result->orig_size);
			RESULT(zc->zc_nvlist_dst_size);
			/* Restore request fields. */
			(void) strcpy(zc->zc_name, name);
			zc->zc_cookie = cookie;
			zc->zc_objset_stats.dds_creation_txg = 0;
		}
		return error == ESRCH ? zfs_success() : zfs_result(error);
	}
	case ZFS_IOC_ERROR_LOG: {
		uint64_t count = zc->zc_nvlist_dst_size;
		result = driver_realloc_binary(result,
		    count * sizeof (zbookmark_phys_t));
		assert(result != NULL); /* XXX */
		zc->zc_nvlist_dst = (uint64_t)(uintptr_t)&result->orig_bytes[0];
		zfs_ioctl_resize_checked(req->ioc, ({
			count *= 2;
			result = driver_realloc_binary(result,
			    count * sizeof (zbookmark_phys_t));
			assert(result != NULL); /* XXX */
			zc->zc_nvlist_dst =
			    (uint64_t)(uintptr_t)&result->orig_bytes[0];
			zc->zc_nvlist_dst_size = count;
		}));

		ei_x_buff *x = &req->res;

		encode_zfs_cmd_res_headerv(req, error, NULL, NULL);
		encode_some_header(x);

		/*
		 * This ioctl fills the buffer from the back and returns
		 * with the remaining leading space in nvlist_dst_size.
		 */
		size_t pad =
		    zc->zc_nvlist_dst_size * sizeof (zbookmark_phys_t);
		char *p = result->orig_bytes + pad;
		size_t len = result->orig_size - pad;
		ei_x_encode_binary(x, p, len);
		driver_free_binary(result);
		return;
	}
	case ZFS_IOC_PROMOTE:
		return zfs_ioctl_sentinel(req->ioc, EEXIST);
	case ZFS_IOC_NEXT_OBJ:
		return zfs_ioctl_sentinel(req->ioc, ESRCH);
	case ZFS_IOC_CHANNEL_PROGRAM:
		RESULT(zc->zc_nvlist_dst_size);
		zfs_ioctl_checked(req->ioc, ({
			if (zc->zc_nvlist_dst_filled)
				return zfs_result(error);
			driver_free_binary(result);
		}));
		return zfs_result(error);
	default:
		return zfs_error(EINVAL, "invalid ioctl", ZFS_DRV);
	}
	__builtin_unreachable();
}

static void
zfs_ready_async(ErlDrvData drv_data, ErlDrvThreadData thread_data)
{
	ZfsState *zfs = (ZfsState *)drv_data;
	ZfsRequest *req = (ZfsRequest *)thread_data;

	ErlDrvTermData port = driver_mk_port(zfs->port);
	ErlDrvTermData spec[] = {
		ERL_DRV_EXT2TERM, (ErlDrvTermData)req->ref.buff, req->ref.index,
		ERL_DRV_EXT2TERM, (ErlDrvTermData)req->res.buff, req->res.index,
		ERL_DRV_TUPLE, 2,
	};
	erl_drv_output_term(port, spec, nitems(spec));

	request_free(req);
}

static ErlDrvEntry zfs_driver_entry = {
	.init = NULL,
	.start = zfs_start,
	.stop = zfs_stop,
	.output = zfs_output,
	.ready_input = NULL,
	.ready_output = NULL,
	.driver_name = ZFS_DRV,
	.finish = NULL,
	.handle = NULL,
	.control = NULL,
	.timeout = NULL,
	.outputv = NULL,
	.ready_async = zfs_ready_async,
	.flush = NULL,
	.call = NULL,
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
