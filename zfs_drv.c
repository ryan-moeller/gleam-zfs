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

typedef struct zfs_iocparam {
	uint32_t zfs_ioctl_version;
	uint64_t zfs_cmd;
	uint64_t zfs_cmd_size;
} zfs_iocparam_t;

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
encode_zfs_cmd_res_headerv(ei_x_buff *x, int error, const char *fmt, va_list ap)
{
	ei_x_encode_tuple_header(x, 4); /* {zfs_cmd_res, Error, Msg, Data} */
	ei_x_encode_atom(x, "zfs_cmd_res");
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
zfs_fatal(char **rbuf, ErlDrvSizeT rlen)
{
	ei_x_buff x;

	ei_x_new_with_version(&x);
	encode_error_header(&x);
	ei_x_encode_atom(&x, "nil");

	return buff_fill(&x, rbuf, rlen);
}

/* ioctl errors are encoded as Ok() of a ZfsCmdRes with error info */
static ErlDrvSSizeT
zfs_unit(char **rbuf, ErlDrvSizeT rlen, int error, const char *fmt, ...)
{
	ei_x_buff x;
	va_list ap;

	ei_x_new_with_version(&x);
	encode_ok_header(&x);
	va_start(ap, fmt);
	encode_zfs_cmd_res_headerv(&x, error, fmt, ap);
	va_end(ap);
	ei_x_encode_empty_list(&x);

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
	zfs_iocparam_t zp;
	size_t oldsize;

	oldsize = zc->zc_nvlist_dst_size;
	zp.zfs_cmd = (uint64_t)(uintptr_t)zc;
	zp.zfs_cmd_size = sizeof (zfs_cmd_t);
	zp.zfs_ioctl_version = ZFS_IOCVER_OZFS;
	if (ioctl(zfs->fd, _IOWR('Z', request, zfs_iocparam_t), &zp) != 0)
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
	zfs_cmd_t zc = {"\0"};

	/*
	 * Interpret buf according to command.  Different commands use different
	 * fields of zfs_cmd_t, some of which are pointers or are otherwise
	 * non-serializable, so must be assembled here in C.
	 *
	 * There can be multiple input nvlists for some commands.  The encoding
	 * is as follows:
	 *
	 *   name: Option(String)
	 *   lists: List(BitArray) packed nvlist binaries
	 *
	 * The role of each list varies for each command.  Some commands only
	 * take nvlists as input.  Other commands require populating zc fields
	 * other than name and use an nvlist to provide these fields.  Separate
	 * nvlists allows only the command nvlist to be unpacked while other
	 * nvlists remain packed.
	 *
	 * Results are sent back with the following encoding:
	 *
	 *   error: Int
	 *   error message: Option(String)
	 *   binaries: List(BitArray) usually packed nvlist binaries
	 *
	 * The role of the nvlists varies depending on the command.  In some
	 * cases, a "packed nvlist" binary may contain something other than a
	 * packed nvlist.  These fields form a tuple of abstract binaries which
	 * may contain anything, not just packed nvlists.
	 */

	char atom[MAXATOMLEN];
	int version, arity, type, size;
	int index = 0; /* XXX TODO: should validate index as we go */

	if (ei_decode_version(buf, &index, &version) == -1)
		return zfs_fatal(rbuf, rlen);

	ei_decode_tuple_header(buf, &index, &arity);
	if (arity != 3) /* {zfs_cmd_req, Name, Data} */
		return zfs_fatal(rbuf, rlen);

	if (ei_decode_atom(buf,	&index, atom) == -1 ||
	    strcmp(atom, "zfs_cmd_req") != 0)
		return zfs_fatal(rbuf, rlen);

	if (ei_get_type(buf, &index, &type, &size) == -1)
		return zfs_fatal(rbuf, rlen);

	char name[ZFS_MAX_DATASET_NAME_LEN];
	long namelen;
	switch (type) {
	case ERL_ATOM_EXT:
		if (ei_decode_atom(buf, &index, atom) == -1 ||
		    strcmp(atom, "none") != 0)
			return zfs_fatal(rbuf, rlen);
		namelen = 0;
		break;
	case ERL_SMALL_TUPLE_EXT:
		if (ei_decode_tuple_header(buf, &index, &arity) == -1 ||
		    arity != 2)
			return zfs_fatal(rbuf, rlen);
		if (ei_decode_atom(buf, &index, atom) == -1 ||
		    strcmp(atom, "some") != 0)
			return zfs_fatal(rbuf, rlen);
		if (ei_get_type(buf, &index, &type, &size) == -1 ||
		    type != ERL_BINARY_EXT || size >= sizeof name)
			return zfs_fatal(rbuf, rlen);
		if (ei_decode_binary(buf, &index, name, &namelen) == -1)
			return zfs_fatal(rbuf, rlen);
		break;
	default:
		return zfs_fatal(rbuf, rlen);
	}
	assert(namelen >= 0);
	name[namelen] = '\0';

	if (ei_decode_list_header(buf, &index, &arity) == -1 || arity < 0)
		return zfs_fatal(rbuf, rlen);

	nvlist_t *params = NULL;
	nvlist_t *results = NULL;
	ErlDrvSSizeT res;
	int error;

#define zfs_success() ({ \
	res = zfs_unit(rbuf, rlen, 0, NULL); \
})
#define zfs_error(error, fmt, ...) ({ \
	res = zfs_unit(rbuf, rlen, error, fmt, __VA_ARGS__); \
})

#define CHECK(expr, error, container) ({ \
	if (!(expr)) { \
		zfs_error(error, "%s: invalid " #container, ZFS_DRV); \
		break; \
	} \
})
#define MCHECK(expr) CHECK((expr), EINVAL, message)
#define PCHECK(expr, error) CHECK((expr), (error), params)

	/* Consume a packed nvlist from ev into a zc field. */
#define NVLIST(field) ({ \
	const char *p; \
	unsigned int bitoffs; \
	size_t nbits; \
	MCHECK(ei_decode_bitstring(buf, &index, &p, &bitoffs, &nbits) == 0); \
	MCHECK((nbits & 0x7) == 0); \
	MCHECK(bitoffs == 0); \
	zc.zc_nvlist_##field = (uint64_t)(uintptr_t)p; \
	zc.zc_nvlist_##field##_size = nbits >> 3; \
})

	/* Consume and unpack a packed nvlist from ev into params. */
#define PARAMS() ({ \
	const char *p; \
	unsigned int bitoffs; \
	size_t nbits; \
	MCHECK(ei_decode_bitstring(buf, &index, &p, &bitoffs, &nbits) == 0); \
	MCHECK((nbits & 0x7) == 0); \
	MCHECK(bitoffs == 0); \
	PCHECK((error = nvlist_unpack(__DECONST(char *, p), nbits >> 3, \
	    &params, 0)) == 0, error); \
})

	/* Look up a zc field in params. */
#define PARAM(type, name) ({ \
	if (params == NULL) PARAMS(); \
	PCHECK((error = nvlist_lookup_##type(params, #name, \
	    (void *)&zc.zc_##name)) == 0, error); \
})
#define STRING(name) ({ \
	if (params == NULL) PARAMS(); \
	const char *value; \
	PCHECK((error = nvlist_lookup_string(params, #name, &value)) == 0, \
	    error); \
	PCHECK(strlcpy(zc.zc_##name, value, sizeof zc.zc_##name) \
	    < sizeof zc.zc_##name, ENAMETOOLONG); \
})
#define BYTES(name) ({ \
	if (params == NULL) PARAMS(); \
	uint8_t *a; \
	uint_t n; \
	PCHECK((error = nvlist_lookup_byte_array(params, #name, &a, &n)) == 0, \
	    error); \
	PCHECK(n == sizeof zc.zc_##name, EINVAL); \
	(void) memcpy(&zc.zc_##name, a, n); \
})

	/* Look up an optional zc field in params. */
#define OPTPARAM(type, name) ({ \
	if (params == NULL) PARAMS(); \
	if (nvlist_exists(params, #name)) PARAM(type, name); \
})
#define OPTSTRING(name) ({ \
	if (params == NULL) PARAMS(); \
	if (nvlist_exists(params, #name)) STRING(name); \
})

	ErlDrvBinary *result = NULL;

#define RESULT(size) ({ \
	result = driver_realloc_binary(result, size); \
	assert(result != NULL); /* XXX */ \
	zc.zc_nvlist_dst_size = result->orig_size; \
	zc.zc_nvlist_dst = (uint64_t)(uintptr_t)&result->orig_bytes[0]; \
})

#define zfs_result(error) ({ \
	ei_x_buff x; \
	ei_x_new_with_version(&x); \
	encode_ok_header(&x); \
	encode_zfs_cmd_res_headerv(&x, error, NULL, NULL); \
	ei_x_encode_list_header(&x, 1); \
	assert(zc.zc_nvlist_dst_size <= result->orig_size); \
	ei_x_encode_binary(&x, result->orig_bytes, zc.zc_nvlist_dst_size); \
	driver_free_binary(result); \
	ei_x_encode_empty_list(&x); \
	res = buff_fill(&x, rbuf, rlen); \
})

#define zfs_results(error) ({ \
	ei_x_buff x; \
	ei_x_new_with_version(&x); \
	encode_ok_header(&x); \
	encode_zfs_cmd_res_headerv(&x, error, NULL, NULL); \
	ei_x_encode_list_header(&x, 1); \
	size_t size; \
	char *p = fnvlist_pack(results, &size); \
	ei_x_encode_binary(&x, p, size); \
	fnvlist_pack_free(p, size); \
	ei_x_encode_empty_list(&x); \
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

	switch (ioc) {
	case ZFS_IOC_POOL_CREATE:
		MCHECK(arity == 1 || arity == 2);
		NVLIST(conf);
		if (arity > 1)
			NVLIST(src);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_POOL_DESTROY:
		MCHECK(arity == 0 || arity == 1);
		if (arity > 0)
			OPTPARAM(string, history);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_POOL_IMPORT:
		MCHECK(arity == 2 || arity == 3);
		PARAM(uint64, cookie); /* flags */
		PARAM(uint64, guid);
		NVLIST(conf);
		if (arity > 2)
			NVLIST(src);
		RESULT(2 * zc.zc_nvlist_conf_size);
		zfs_ioctl_nvlist(ioc);
		break;
	case ZFS_IOC_POOL_EXPORT:
		MCHECK(arity == 0 || arity == 1);
		if (arity > 0) {
			OPTPARAM(uint64, cookie); /* force */
			OPTPARAM(uint64, guid); /* hardforce */
			OPTPARAM(string, history);
		}
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_POOL_CONFIGS:
		MCHECK(arity == 1);
		PARAM(uint64, cookie); /* gen */
		RESULT(256 << 10);
		zfs_ioctl_resize_checked(ioc, ({
			PARAM(uint64, cookie); /* reset gen */
		}));
		if (!zc.zc_nvlist_dst_filled) {
			driver_free_binary(result);
			zfs_error(error, "ioctl(%s) failed", ZFS_DEV);
		} else {
			ei_x_buff x;
			char *p;
			size_t size;

			ei_x_new_with_version(&x);
			encode_ok_header(&x);
			encode_zfs_cmd_res_headerv(&x, error, NULL, NULL);
			ei_x_encode_list_header(&x, 2);

			results = fnvlist_alloc();
			fnvlist_add_uint64(results, "cookie", zc.zc_cookie);
			p = fnvlist_pack(results, &size);
			ei_x_encode_binary(&x, p, size);
			fnvlist_pack_free(p, size);

			assert(zc.zc_nvlist_dst_size <= result->orig_size);
			ei_x_encode_binary(&x, result->orig_bytes,
			    zc.zc_nvlist_dst_size);
			driver_free_binary(result);

			ei_x_encode_empty_list(&x);
			res = buff_fill(&x, rbuf, rlen);
		}
		break;
	case ZFS_IOC_POOL_STATS:
		MCHECK(arity == 0);
		RESULT(64 << 10);
		/* XXX: This ioctl may put an error code in cookie instead. */
		while ((error = zfs_ioctl(zfs, (ioc), &zc)) == ENOMEM) {
			assert(zc.zc_nvlist_dst_size > result->orig_size);
			RESULT(zc.zc_nvlist_dst_size);
		}
		if (zc.zc_nvlist_dst_filled) {
			ei_x_buff x;
			char *p;
			size_t size;

			ei_x_new_with_version(&x);
			encode_ok_header(&x);
			encode_zfs_cmd_res_headerv(&x, error, NULL, NULL);
			ei_x_encode_list_header(&x, 2);

			results = fnvlist_alloc();
			fnvlist_add_uint64(results, "cookie", zc.zc_cookie);
			fnvlist_add_string(results, "value", zc.zc_value);
			p = fnvlist_pack(results, &size);
			ei_x_encode_binary(&x, p, size);
			fnvlist_pack_free(p, size);

			assert(zc.zc_nvlist_dst_size <= result->orig_size);
			ei_x_encode_binary(&x, result->orig_bytes,
			    zc.zc_nvlist_dst_size);
			driver_free_binary(result);

			ei_x_encode_empty_list(&x);
			res = buff_fill(&x, rbuf, rlen);
		} else {
			driver_free_binary(result);
			if (zc.zc_value[0] != '\0') {
				results = fnvlist_alloc();
				fnvlist_add_string(results, "value",
				    zc.zc_value);
				zfs_results(error);
			} else if (error == 0)
				zfs_success();
			else
				zfs_error(error, "ioctl(%s) failed", ZFS_DEV);
		}
		break;
	case ZFS_IOC_POOL_TRYIMPORT:
		MCHECK(arity == 1);
		NVLIST(conf);
		RESULT(MAX(256 << 10, zc.zc_nvlist_conf_size * 32));
		zfs_ioctl_nvlist(ioc);
		break;
	case ZFS_IOC_POOL_SCAN:
		MCHECK(arity == 1);
		PARAM(uint64, cookie); /* func */
		PARAM(uint32, flags); /* cmd */
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_POOL_FREEZE:
	case ZFS_IOC_USERSPACE_UPGRADE:
	case ZFS_IOC_UNLOAD_KEY:
	case ZFS_IOC_POOL_CHECKPOINT:
	case ZFS_IOC_POOL_DISCARD_CHECKPOINT:
		MCHECK(arity == 0);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_POOL_UPGRADE:
		MCHECK(arity == 1);
		PARAM(uint64, cookie); /* version */
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_POOL_GET_HISTORY:
		MCHECK(arity == 1);
		PARAM(uint64, history_offset);
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
		{
			ei_x_buff x;

			ei_x_new_with_version(&x);
			encode_ok_header(&x);
			encode_zfs_cmd_res_headerv(&x, error, NULL, NULL);
			ei_x_encode_list_header(&x, 1);

			assert(zc.zc_nvlist_dst_size <=
			    (result->orig_size + sizeof (uint64_t)));
			ei_x_encode_binary(&x, result->orig_bytes,
			    zc.zc_nvlist_dst_size + sizeof (uint64_t));
			driver_free_binary(result);

			ei_x_encode_empty_list(&x);
			res = buff_fill(&x, rbuf, rlen);
		}
		break;
	case ZFS_IOC_VDEV_ADD:
		MCHECK(arity == 1 || arity == 2);
		if (arity > 1)
			PARAM(uint32, flags); /* check ashift */
		NVLIST(conf);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_VDEV_REMOVE:
		MCHECK(arity == 1);
		OPTPARAM(uint64, cookie); /* cancel */
		if (zc.zc_cookie == 0)
			PARAM(uint64, guid);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_VDEV_SET_STATE:
		MCHECK(arity == 1);
		PARAM(uint64, cookie); /* state */
		if (zc.zc_cookie != VDEV_STATE_REMOVED)
			OPTPARAM(uint64, obj); /* flags */
		PARAM(uint64, guid);
		zfs_ioctl_checked(ioc);
		results = fnvlist_alloc();
		fnvlist_add_uint64(results, "cookie", zc.zc_cookie);
		zfs_results(error);
		break;
	case ZFS_IOC_VDEV_ATTACH:
		MCHECK(arity == 2);
		OPTPARAM(uint64, cookie); /* replacing */
		PARAM(uint64, guid);
		OPTPARAM(uint8, simple); /* rebuild */
		NVLIST(conf);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_VDEV_DETACH:
	case ZFS_IOC_CLEAR_FAULT:
		MCHECK(arity == 1);
		PARAM(uint64, guid);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_VDEV_SETPATH:
	case ZFS_IOC_VDEV_SETFRU:
		MCHECK(arity == 1);
		PARAM(uint64, guid);
		STRING(value);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_OBJSET_STATS:
		MCHECK(arity == 1);
		OPTPARAM(uint8, simple);
		if (!zc.zc_simple)
			RESULT(256 << 10);
		zfs_ioctl_resize_checked(ioc, ({
			if (zc.zc_simple)
				break;
		}));
		{
			ei_x_buff x;
			char *p;
			size_t size;

			ei_x_new_with_version(&x);
			encode_ok_header(&x);
			encode_zfs_cmd_res_headerv(&x, error, NULL, NULL);
			ei_x_encode_list_header(&x, zc.zc_simple ? 1 : 2);

			results = fnvlist_alloc();
			fnvlist_add_byte_array(results, "objset_stats",
			    (uchar_t *)&zc.zc_objset_stats,
			    sizeof zc.zc_objset_stats);
			p = fnvlist_pack(results, &size);
			ei_x_encode_binary(&x, p, size);
			fnvlist_pack_free(p, size);

			if (!zc.zc_simple) {
				assert(zc.zc_nvlist_dst_size <=
				    result->orig_size);
				ei_x_encode_binary(&x, result->orig_bytes,
				    zc.zc_nvlist_dst_size);
				driver_free_binary(result);
			}

			ei_x_encode_empty_list(&x);
			res = buff_fill(&x, rbuf, rlen);
		}
		break;
	case ZFS_IOC_OBJSET_ZPLPROPS:
	case ZFS_IOC_POOL_GET_PROPS:
	case ZFS_IOC_OBJSET_RECVD_PROPS:
		MCHECK(arity == 0);
		RESULT(256 << 10);
		zfs_ioctl_nvlist(ioc);
		break;
	case ZFS_IOC_DATASET_LIST_NEXT:
	case ZFS_IOC_SNAPSHOT_LIST_NEXT:
		MCHECK(arity == 1);
		PARAM(uint64, cookie);
		OPTPARAM(uint8, simple);
		if (!zc.zc_simple)
			RESULT(256 << 10);
		while ((error = zfs_ioctl(zfs, ioc, &zc)) == ENOMEM) {
			if (zc.zc_simple)
				break;
			assert(zc.zc_nvlist_dst_size > result->orig_size);
			RESULT(zc.zc_nvlist_dst_size);
			/* Restore request fields. */
			(void) strcpy(zc.zc_name, name);
			PARAM(uint64, cookie);
			zc.zc_objset_stats.dds_creation_txg = 0;
		}
		if (error == ESRCH)
			zfs_success();
		else if (error == 0) {
			ei_x_buff x;
			char *p;
			size_t size;

			ei_x_new_with_version(&x);
			encode_ok_header(&x);
			encode_zfs_cmd_res_headerv(&x, error, NULL, NULL);
			ei_x_encode_list_header(&x, zc.zc_simple ? 1 : 2);

			results = fnvlist_alloc();
			fnvlist_add_uint64(results, "cookie", zc.zc_cookie);
			fnvlist_add_byte_array(results, "objset_stats",
			    (uchar_t *)&zc.zc_objset_stats,
			    sizeof zc.zc_objset_stats);
			fnvlist_add_string(results, "name", zc.zc_name);
			p = fnvlist_pack(results, &size);
			ei_x_encode_binary(&x, p, size);
			fnvlist_pack_free(p, size);

			if (!zc.zc_simple) {
				assert(zc.zc_nvlist_dst_size <=
				    result->orig_size);
				ei_x_encode_binary(&x, result->orig_bytes,
				    zc.zc_nvlist_dst_size);
				driver_free_binary(result);
			}

			ei_x_encode_empty_list(&x);
			res = buff_fill(&x, rbuf, rlen);
		} else {
			driver_free_binary(result);
			zfs_error(error, "ioctl(%s) failed", ZFS_DEV);
		}
		break;
	case ZFS_IOC_SET_PROP:
		MCHECK(arity == 1);
		NVLIST(src);
		RESULT(MAX(256 << 10, zc.zc_nvlist_src_size));
		zfs_ioctl_nvlist(ioc);
		break;
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
		MCHECK(arity == 1);
		NVLIST(src);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_DESTROY:
		MCHECK(arity == 0 || arity == 1);
		if (arity == 1)
			PARAM(uint32, defer_destroy);
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_ROLLBACK:
		MCHECK(arity == 0 || arity == 1);
		if (arity == 1)
			NVLIST(src);
		RESULT(128 << 10);
		zfs_ioctl_nvlist(ioc);
		break;
	case ZFS_IOC_RENAME:
		MCHECK(arity == 1);
		STRING(value); /* newname */
		OPTPARAM(uint64, cookie); /* flags */
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_RECV:
		MCHECK(arity == 1 || arity == 2 || arity == 3);
		STRING(value); /* snapname */
		OPTSTRING(string); /* origin */
		PARAM(uint64, cookie); /* fd */
		BYTES(begin_record);
		OPTPARAM(uint64, guid); /* force */
		NVLIST(src); /* props */
		NVLIST(conf); /* override */
		RESULT(256 << 10);
		zfs_ioctl_checked(ioc, ({
			driver_free_binary(result);
		}));
		{
			ei_x_buff x;
			char *p;
			size_t size;

			ei_x_new_with_version(&x);
			encode_ok_header(&x);
			encode_zfs_cmd_res_headerv(&x, error, NULL, NULL);
			ei_x_encode_list_header(&x, 2);

			results = fnvlist_alloc();
			fnvlist_add_uint64(results, "cookie", zc.zc_cookie);
			fnvlist_add_uint64(results, "obj", zc.zc_obj);
			p = fnvlist_pack(results, &size);
			ei_x_encode_binary(&x, p, size);
			fnvlist_pack_free(p, size);

			assert(zc.zc_nvlist_dst_size <= result->orig_size);
			ei_x_encode_binary(&x, result->orig_bytes,
			    zc.zc_nvlist_dst_size);
			driver_free_binary(result);

			ei_x_encode_empty_list(&x);
			res = buff_fill(&x, rbuf, rlen);
		}
		break;
	case ZFS_IOC_SEND:
		MCHECK(arity == 1);
		OPTPARAM(uint64, guid); /* estimate */
		if (zc.zc_guid)
			PARAM(uint64, cookie); /* fd */
		OPTPARAM(uint64, obj); /* fromorigin */
		PARAM(uint64, sendobj);
		OPTPARAM(uint64, fromobj);
		OPTPARAM(uint32, flags);
		zfs_ioctl_checked(ioc);
		if (zc.zc_guid) {
			results = fnvlist_alloc();
			fnvlist_add_uint64(results, "objset_type",
			    zc.zc_objset_type); /* estimate */
			zfs_results(error);
		} else
			zfs_success();
		break;
	case ZFS_IOC_INJECT_FAULT:
		MCHECK(arity == 1);
		BYTES(inject_record);
		zfs_ioctl_checked(ioc);
		results = fnvlist_alloc();
		fnvlist_add_uint64(results, "guid", zc.zc_guid);
		zfs_results(error);
		break;
	case ZFS_IOC_INJECT_LIST_NEXT:
		MCHECK(arity == 1);
		PARAM(uint64, guid);
		zfs_ioctl_checked(ioc);
		results = fnvlist_alloc();
		fnvlist_add_uint64(results, "guid", zc.zc_guid);
		fnvlist_add_string(results, "name", zc.zc_name);
		fnvlist_add_byte_array(results, "inject_record",
		    (uchar_t *)&zc.zc_inject_record,
		    sizeof zc.zc_inject_record);
		zfs_results(error);
		break;
	case ZFS_IOC_ERROR_LOG: {
		MCHECK(arity == 0);
		uint64_t count = 10000;
		result = driver_realloc_binary(result,
		    count * sizeof (zbookmark_phys_t));
		assert(result != NULL); /* XXX */
		zc.zc_nvlist_dst = (uint64_t)(uintptr_t)&result->orig_bytes[0];
		zc.zc_nvlist_dst_size = count;
		zfs_ioctl_resize_checked(ioc, ({
			count *= 2;
			result = driver_realloc_binary(result,
			    count * sizeof (zbookmark_phys_t));
			assert(result != NULL); /* XXX */
			zc.zc_nvlist_dst =
			    (uint64_t)(uintptr_t)&result->orig_bytes[0];
			zc.zc_nvlist_dst_size = count;
		}));
		{
			ei_x_buff x;

			ei_x_new_with_version(&x);
			encode_ok_header(&x);
			encode_zfs_cmd_res_headerv(&x, error, NULL, NULL);

			/*
			 * This ioctl fills the buffer from the back and returns
			 * with the remaining leading space in nvlist_dst_size.
			 */
			size_t pad = zc.zc_nvlist_dst_size;
			count = pad / sizeof (zbookmark_phys_t);
			ei_x_encode_list_header(&x, count);
			for (zbookmark_phys_t *p = (void *)zc.zc_nvlist_dst;
			    count > 0; count--, p++)
				ei_x_encode_binary(&x, p, sizeof *p);
			driver_free_binary(result);

			ei_x_encode_empty_list(&x);
			res = buff_fill(&x, rbuf, rlen);
		}
		break;
	}
	case ZFS_IOC_CLEAR:
		MCHECK(arity == 1 || arity == 2);
		PARAM(uint64, guid);
		if (arity > 1) {
			NVLIST(src);
			RESULT(256 << 10);
		} else
			zc.zc_cookie = ZPOOL_NO_REWIND;
		zfs_ioctl_nvlist(ioc, ({
			if ((zc.zc_cookie & ZPOOL_NO_REWIND) != 0)
				break;
		}));
		break;
	case ZFS_IOC_PROMOTE:
		MCHECK(arity == 0);
		zfs_ioctl_checked(ioc, ({
			if (error == EEXIST) {
				results = fnvlist_alloc();
				fnvlist_add_string(results, "string",
				    zc.zc_string);
				zfs_results(error);
				break;
			}
		}));
		zfs_success();
		break;
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
		MCHECK(arity == 1);
		NVLIST(src); /* args */
		RESULT(MAX(128 << 10, zc.zc_nvlist_src_size * 2));
		zfs_ioctl_nvlist(ioc);
		break;
	case ZFS_IOC_DSOBJ_TO_DSNAME:
	case ZFS_IOC_OBJ_TO_PATH:
		MCHECK(arity == 1);
		PARAM(uint64, obj);
		zfs_ioctl_checked(ioc);
		results = fnvlist_alloc();
		fnvlist_add_string(results, "value", zc.zc_value);
		zfs_results(error);
		break;
	case ZFS_IOC_SET_FSACL:
		MCHECK(arity == 2);
		PARAM(uint64, perm_action); /* un */
		NVLIST(src); /* acl */
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_GET_FSACL:
		MCHECK(arity == 0);
		RESULT(2048);
		zfs_ioctl_nvlist(ioc);
		break;
	case ZFS_IOC_INHERIT_PROP:
		MCHECK(arity == 1);
		STRING(value); /* prop */
		OPTPARAM(uint64, cookie); /* received */
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_USERSPACE_ONE:
		MCHECK(arity == 1);
		PARAM(uint64, guid); /* id */
		PARAM(uint64, objset_type); /* prop */
		STRING(value); /* domain */
		zfs_ioctl_checked(ioc);
		results = fnvlist_alloc();
		fnvlist_add_uint64(results, "cookie", zc.zc_cookie); /* space */
		zfs_results(error);
		break;
	case ZFS_IOC_USERSPACE_MANY:
		MCHECK(arity == 1);
		PARAM(uint64, cookie); /* cursor */
		PARAM(uint64, objset_type); /* prop */
		PARAM(uint64, nvlist_dst_size);
		RESULT(zc.zc_nvlist_dst_size);
		zfs_ioctl_checked(ioc, ({
			driver_free_binary(result);
		}));
		{
			ei_x_buff x;
			char *p;
			size_t size;

			ei_x_new_with_version(&x);
			encode_ok_header(&x);
			encode_zfs_cmd_res_headerv(&x, error, NULL, NULL);
			ei_x_encode_list_header(&x, 2);

			results = fnvlist_alloc();
			fnvlist_add_uint64(results, "cookie", zc.zc_cookie);
			p = fnvlist_pack(results, &size);
			ei_x_encode_binary(&x, p, size);
			fnvlist_pack_free(p, size);

			assert(zc.zc_nvlist_dst_size <= result->orig_size);
			ei_x_encode_binary(&x, result->orig_bytes,
			    zc.zc_nvlist_dst_size);
			driver_free_binary(result);

			ei_x_encode_empty_list(&x);
			res = buff_fill(&x, rbuf, rlen);
		}
		break;
	case ZFS_IOC_HOLD:
	case ZFS_IOC_RELEASE:
		MCHECK(arity == 1);
		NVLIST(src); /* args */
		RESULT(MAX(128 << 10, zc.zc_nvlist_src_size * 2));
		zfs_ioctl_nvlist(ioc);
		break;
	case ZFS_IOC_GET_HOLDS:
	case ZFS_IOC_GET_BOOKMARK_PROPS:
	case ZFS_IOC_GET_BOOTENV:
		MCHECK(arity == 0);
		RESULT(128 << 10);
		zfs_ioctl_nvlist(ioc);
		break;
	case ZFS_IOC_VDEV_SPLIT:
		MCHECK(arity == 2 || arity == 3);
		OPTPARAM(uint64, cookie); /* flags */
		STRING(string); /* newname */
		NVLIST(conf);
		if (arity > 2)
			NVLIST(src); /* props */
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_NEXT_OBJ:
		MCHECK(arity == 1);
		PARAM(uint64, obj);
		zfs_ioctl_checked(ioc, ({
			if (error == ESRCH) {
				zfs_success();
				break;
			}
		}));
		results = fnvlist_alloc();
		fnvlist_add_uint64(results, "obj", zc.zc_obj); /* nextobj */
		zfs_results(error);
		break;
	case ZFS_IOC_DIFF:
		MCHECK(arity == 1);
		STRING(value); /* from */
		PARAM(uint64, cookie); /* fd */
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_TMP_SNAPSHOT:
		MCHECK(arity == 1);
		STRING(value); /* prefix */
		PARAM(int32, cleanup_fd);
		zfs_ioctl_checked(ioc);
		results = fnvlist_alloc();
		fnvlist_add_string(results, "value", zc.zc_value);
		zfs_results(error);
		break;
	case ZFS_IOC_OBJ_TO_STATS:
		MCHECK(arity == 1);
		PARAM(uint64, obj);
		zfs_ioctl_checked(ioc);
		results = fnvlist_alloc();
		fnvlist_add_string(results, "value", zc.zc_value);
		fnvlist_add_byte_array(results, "stat", (uchar_t *)&zc.zc_stat,
		    sizeof zc.zc_stat);
		zfs_results(error);
		break;
	case ZFS_IOC_SPACE_WRITTEN:
		MCHECK(arity == 1);
		STRING(value); /* snap */
		zfs_ioctl_checked(ioc);
		results = fnvlist_alloc();
		fnvlist_add_uint64(results, "cookie", zc.zc_cookie);
		fnvlist_add_uint64(results, "objset_type", zc.zc_objset_type);
		fnvlist_add_uint64(results, "perm_action", zc.zc_perm_action);
		zfs_results(error);
		break;
	case ZFS_IOC_POOL_REGUID:
	case ZFS_IOC_POOL_REOPEN:
		MCHECK(arity == 0 || arity == 1);
		if (arity > 0)
			NVLIST(src); /* args */
		zfs_ioctl_unit(ioc);
		break;
	case ZFS_IOC_SEND_PROGRESS:
		MCHECK(arity == 1);
		PARAM(uint64, cookie); /* fd */
		zfs_ioctl_checked(ioc);
		results = fnvlist_alloc();
		fnvlist_add_uint64(results, "cookie", zc.zc_cookie);
		fnvlist_add_uint64(results, "objset_type", zc.zc_objset_type);
		zfs_results(error);
		break;
	case ZFS_IOC_SEND_SPACE:
	case ZFS_IOC_GET_BOOKMARKS:
		MCHECK(arity == 0 || arity == 1);
		if (arity > 0)
			NVLIST(src); /* args */
		RESULT(MAX(128 << 10, zc.zc_nvlist_src_size * 2));
		zfs_ioctl_nvlist(ioc);
		break;
	case ZFS_IOC_CHANNEL_PROGRAM:
		MCHECK(arity == 2);
		PARAM(uint64, nvlist_dst_size); /* memlimit */
		NVLIST(src); /* args */
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
	case ZFS_IOC_JAIL:
	case ZFS_IOC_UNJAIL:
		MCHECK(arity == 1);
		PARAM(uint64, zoneid); /* jid */
		zfs_ioctl_unit(ioc);
		break;
	default:
		zfs_error(EINVAL, "invalid ioctl", ZFS_DRV);
		break;
	}
	nvlist_free(params);
	nvlist_free(results);
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
