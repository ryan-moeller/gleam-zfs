// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/bit_array
import gleam/erlang/port.{type Port}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/string

import nvpair/list.{type NvList} as nvl
import nvpair/stream as nvs

import struct.{
  type FieldValue, type Struct, type StructStorage, type StructT, Field,
  FieldValue, Union, build_struct, int_int32, int_uint32, int_uint64, int_uint8,
  sizeof_struct, string_pad, struct_read, uint64_int,
}

fn nvlist(pairs: List(nvl.Pair)) -> BitArray {
  let assert Some(nvl) = nvl.from_list(pairs, [nvl.UniqueName])
  nvs.pack(nvl, nvs.Native)
}

fn nvlist_opt(pairs: List(Option(nvl.Pair))) -> Option(BitArray) {
  case option.values(pairs) {
    [] -> None
    pairs -> Some(nvlist(pairs))
  }
}

fn int(b: Bool) -> Int {
  case b {
    True -> 1
    False -> 0
  }
}

fn opt(b: Bool, v: t) -> Option(t) {
  case b {
    True -> Some(v)
    False -> None
  }
}

fn str_impl(len: Int, bytes: BitArray) -> Result(String, Nil) {
  case bytes {
    <<s:bytes-size(len), 0:unit(8)-size(1), _:bytes>> -> bit_array.to_string(s)
    <<s:bytes-size(len)>> -> bit_array.to_string(s)
    _ -> str_impl(len + 1, bytes)
  }
}

fn str(bytes: BitArray) -> Result(String, Nil) {
  str_impl(0, bytes)
}

pub opaque type Handle {
  Handle(inner: Port)
}

@external(erlang, "devzfs", "open")
fn devzfs_open() -> Port

pub fn open_handle() -> Handle {
  devzfs_open() |> Handle
}

@external(erlang, "erlang", "port_close")
fn port_close(port: Port) -> Bool

pub fn close_handle(hdl: Handle) -> Bool {
  port_close(hdl.inner)
}

@external(erlang, "erlang", "port_call")
fn port_call(port: Port, op: Int, data: t1) -> t2

pub type ZfsCmd =
  StructStorage

pub type Error {
  InternalError
  ErrorWithZfsCmd(zc: ZfsCmd)
  ErrorWithCode(zc: ZfsCmd, code: Int)
  ErrorWithMessage(zc: ZfsCmd, code: Int, message: String)
  ErrorWithInfo(zc: ZfsCmd, code: Int, info: NvList)
  ErrorWithMessageAndInfo(zc: ZfsCmd, code: Int, message: String, info: NvList)
}

type ZfsIoc {
  ZfsIocPoolCreate
  ZfsIocPoolDestroy
  ZfsIocPoolImport
  ZfsIocPoolExport
  ZfsIocPoolConfigs
  ZfsIocPoolStats
  ZfsIocPoolTryImport
  ZfsIocPoolScan
  ZfsIocPoolFreeze
  ZfsIocPoolUpgrade
  ZfsIocPoolGetHistory
  ZfsIocVdevAdd
  ZfsIocVdevRemove
  ZfsIocVdevSetState
  ZfsIocVdevAttach
  ZfsIocVdevDetach
  ZfsIocVdevSetPath
  ZfsIocVdevSetFru
  ZfsIocObjsetStats
  ZfsIocObjsetZplProps
  ZfsIocDatasetListNext
  ZfsIocSnapshotListNext
  ZfsIocSetProp
  ZfsIocCreate
  ZfsIocDestroy
  ZfsIocRollback
  ZfsIocRename
  ZfsIocRecv
  ZfsIocSend
  ZfsIocInjectFault
  ZfsIocClearFault
  ZfsIocInjectListNext
  ZfsIocErrorLog
  ZfsIocClear
  ZfsIocPromote
  ZfsIocSnapshot
  ZfsIocDsObjToDsName
  ZfsIocObjToPath
  ZfsIocPoolSetProps
  ZfsIocPoolGetProps
  ZfsIocSetFsacl
  ZfsIocGetFsacl
  ZfsIocShare
  ZfsIocInheritProp
  ZfsIocSmbAcl
  ZfsIocUserSpaceOne
  ZfsIocUserSpaceMany
  ZfsIocUserSpaceUpgrade
  ZfsIocHold
  ZfsIocRelease
  ZfsIocGetHolds
  ZfsIocObjsetRecvdProps
  ZfsIocVdevSplit
  ZfsIocNextObj
  ZfsIocDiff
  ZfsIocTmpSnapshot
  ZfsIocObjToStats
  ZfsIocSpaceWritten
  ZfsIocSpaceSnaps
  ZfsIocDestroySnaps
  ZfsIocPoolReguid
  ZfsIocPoolReopen
  ZfsIocSendProgress
  ZfsIocLogHistory
  ZfsIocSendNew
  ZfsIocSendSpace
  ZfsIocClone
  ZfsIocBookmark
  ZfsIocGetBookmarks
  ZfsIocDestroyBookmarks
  ZfsIocRecvNew
  ZfsIocPoolSync
  ZfsIocChannelProgram
  ZfsIocLoadKey
  ZfsIocUnloadKey
  ZfsIocChangeKey
  ZfsIocRemap
  ZfsIocPoolCheckpoint
  ZfsIocPoolDiscardCheckpoint
  ZfsIocPoolInitialize
  ZfsIocPoolTrim
  ZfsIocRedact
  ZfsIocGetBookmarkProps
  ZfsIocWait
  ZfsIocWaitFs
  ZfsIocVdevGetProps
  ZfsIocVdevSetProps
  ZfsIocPoolScrub
  ZfsIocPoolPrefetch
  ZfsIocDdtPrune
  ZfsIocPlatform
  ZfsIocEventsNext
  ZfsIocEventsClear
  ZfsIocEventsSeek
  ZfsIocNextBoot
  ZfsIocJail
  ZfsIocUnjail
  ZfsIocSetBootEnv
  ZfsIocGetBootEnv
}

fn zfsioc_index(ioc: ZfsIoc) -> Int {
  case ioc {
    ZfsIocPoolCreate -> 0
    ZfsIocPoolDestroy -> 1
    ZfsIocPoolImport -> 2
    ZfsIocPoolExport -> 3
    ZfsIocPoolConfigs -> 4
    ZfsIocPoolStats -> 5
    ZfsIocPoolTryImport -> 6
    ZfsIocPoolScan -> 7
    ZfsIocPoolFreeze -> 8
    ZfsIocPoolUpgrade -> 9
    ZfsIocPoolGetHistory -> 10
    ZfsIocVdevAdd -> 11
    ZfsIocVdevRemove -> 12
    ZfsIocVdevSetState -> 13
    ZfsIocVdevAttach -> 14
    ZfsIocVdevDetach -> 15
    ZfsIocVdevSetPath -> 16
    ZfsIocVdevSetFru -> 17
    ZfsIocObjsetStats -> 18
    ZfsIocObjsetZplProps -> 19
    ZfsIocDatasetListNext -> 20
    ZfsIocSnapshotListNext -> 21
    ZfsIocSetProp -> 22
    ZfsIocCreate -> 23
    ZfsIocDestroy -> 24
    ZfsIocRollback -> 25
    ZfsIocRename -> 26
    ZfsIocRecv -> 27
    ZfsIocSend -> 28
    ZfsIocInjectFault -> 29
    ZfsIocClearFault -> 30
    ZfsIocInjectListNext -> 31
    ZfsIocErrorLog -> 32
    ZfsIocClear -> 33
    ZfsIocPromote -> 34
    ZfsIocSnapshot -> 35
    ZfsIocDsObjToDsName -> 36
    ZfsIocObjToPath -> 37
    ZfsIocPoolSetProps -> 38
    ZfsIocPoolGetProps -> 39
    ZfsIocSetFsacl -> 40
    ZfsIocGetFsacl -> 41
    ZfsIocShare -> 42
    ZfsIocInheritProp -> 43
    ZfsIocSmbAcl -> 44
    ZfsIocUserSpaceOne -> 45
    ZfsIocUserSpaceMany -> 46
    ZfsIocUserSpaceUpgrade -> 47
    ZfsIocHold -> 48
    ZfsIocRelease -> 49
    ZfsIocGetHolds -> 50
    ZfsIocObjsetRecvdProps -> 51
    ZfsIocVdevSplit -> 52
    ZfsIocNextObj -> 53
    ZfsIocDiff -> 54
    ZfsIocTmpSnapshot -> 55
    ZfsIocObjToStats -> 56
    ZfsIocSpaceWritten -> 57
    ZfsIocSpaceSnaps -> 58
    ZfsIocDestroySnaps -> 59
    ZfsIocPoolReguid -> 60
    ZfsIocPoolReopen -> 61
    ZfsIocSendProgress -> 62
    ZfsIocLogHistory -> 63
    ZfsIocSendNew -> 64
    ZfsIocSendSpace -> 65
    ZfsIocClone -> 66
    ZfsIocBookmark -> 67
    ZfsIocGetBookmarks -> 68
    ZfsIocDestroyBookmarks -> 69
    ZfsIocRecvNew -> 70
    ZfsIocPoolSync -> 71
    ZfsIocChannelProgram -> 72
    ZfsIocLoadKey -> 73
    ZfsIocUnloadKey -> 74
    ZfsIocChangeKey -> 75
    ZfsIocRemap -> 76
    ZfsIocPoolCheckpoint -> 77
    ZfsIocPoolDiscardCheckpoint -> 78
    ZfsIocPoolInitialize -> 79
    ZfsIocPoolTrim -> 80
    ZfsIocRedact -> 81
    ZfsIocGetBookmarkProps -> 82
    ZfsIocWait -> 83
    ZfsIocWaitFs -> 84
    ZfsIocVdevGetProps -> 85
    ZfsIocVdevSetProps -> 86
    ZfsIocPoolScrub -> 87
    ZfsIocPoolPrefetch -> 88
    ZfsIocDdtPrune -> 89
    ZfsIocPlatform -> 128
    ZfsIocEventsNext -> 129
    ZfsIocEventsClear -> 130
    ZfsIocEventsSeek -> 131
    ZfsIocNextBoot -> 132
    ZfsIocJail -> 133
    ZfsIocUnjail -> 134
    ZfsIocSetBootEnv -> 135
    ZfsIocGetBootEnv -> 136
  }
}

const sizeof_char = 1

const sizeof_int = 4

const sizeof_uint8 = 1

const sizeof_uint32 = 4

const sizeof_uint64 = 8

const sizeof_boolean = sizeof_int

const sizeof_dmu_objset_type = sizeof_int

const maxpathlen = 1024

const maxnamelen = 256

const zfs_max_dataset_name_len = maxnamelen

type ZfsShareField {
  ZExportData
  ZShareData
  ZShareType
  ZShareMax
}

fn zfs_share_t() -> StructT(ZfsShareField) {
  [
    Field(ZExportData, sizeof_uint64),
    Field(ZShareData, sizeof_uint64),
    Field(ZShareType, sizeof_uint64),
    Field(ZShareMax, sizeof_uint64),
  ]
}

type DmuObjsetStatsField {
  DdsNumClones
  DdsCreationTxg
  DdsGuid
  DdsType
  DdsIsSnapshot
  DdsInconsistent
  DdsRedacted
  DdsOrigin
  DdsFlags
}

fn dmu_objset_stats_t() -> StructT(DmuObjsetStatsField) {
  [
    Field(DdsNumClones, sizeof_uint64),
    Field(DdsCreationTxg, sizeof_uint64),
    Field(DdsGuid, sizeof_uint64),
    Field(DdsType, sizeof_dmu_objset_type),
    Field(DdsIsSnapshot, sizeof_uint8),
    Field(DdsInconsistent, sizeof_uint8),
    Field(DdsRedacted, sizeof_uint8),
    Field(DdsOrigin, { sizeof_char * zfs_max_dataset_name_len }),
    Field(DdsFlags, sizeof_uint8),
  ]
}

type DrrBeginField {
  DrrMagic
  DrrVersionInfo
  DrrCreationTime
  DrrType
  DrrFlags
  DrrToguid
  DrrFromguid
  DrrToname
}

fn drr_begin_t() -> StructT(DrrBeginField) {
  [
    Field(DrrMagic, sizeof_uint64),
    Field(DrrVersionInfo, sizeof_uint64),
    Field(DrrCreationTime, sizeof_uint64),
    Field(DrrType, sizeof_dmu_objset_type),
    Field(DrrFlags, sizeof_uint32),
    Field(DrrToguid, sizeof_uint64),
    Field(DrrFromguid, sizeof_uint64),
    Field(DrrToname, { sizeof_char * maxnamelen }),
  ]
}

type ZinjectRecordField {
  ZiObjset
  ZiObject
  ZiStart
  ZiEnd
  ZiGuid
  ZiLevel
  ZiError
  ZiType
  ZiFreq
  ZiFailfast
  ZiFunc
  ZiIotype
  ZiDuration
  ZiTimer
  ZiNlanes
  ZiCmd
  ZiDvas
  ZiMatchCount
  ZiInjectCount
}

fn zinject_record_t() -> StructT(ZinjectRecordField) {
  [
    Field(ZiObjset, sizeof_uint64),
    Field(ZiObject, sizeof_uint64),
    Field(ZiStart, sizeof_uint64),
    Field(ZiEnd, sizeof_uint64),
    Field(ZiGuid, sizeof_uint64),
    Field(ZiLevel, sizeof_uint32),
    Field(ZiError, sizeof_uint32),
    Field(ZiType, sizeof_uint64),
    Field(ZiFreq, sizeof_uint32),
    Field(ZiFailfast, sizeof_uint32),
    Field(ZiFunc, { sizeof_char * maxnamelen }),
    Field(ZiIotype, sizeof_uint32),
    Field(ZiDuration, sizeof_uint32),
    Field(ZiTimer, sizeof_uint64),
    Field(ZiNlanes, sizeof_uint64),
    Field(ZiCmd, sizeof_uint32),
    Field(ZiDvas, sizeof_uint32),
    Field(ZiMatchCount, sizeof_uint64),
    Field(ZiInjectCount, sizeof_uint64),
  ]
}

type ZfsStatField {
  ZsGen
  ZsMode
  ZsLinks
  ZsCtime
}

fn zfs_stat_t() -> StructT(ZfsStatField) {
  [
    Field(ZsGen, sizeof_uint64),
    Field(ZsMode, sizeof_uint64),
    Field(ZsLinks, sizeof_uint64),
    Field(ZsCtime, { sizeof_uint64 * 2 }),
  ]
}

type ZfsCmdField {
  ZcName
  ZcNvlistSrc
  ZcNvlistSrcSize
  ZcNvlistDst
  ZcNvlistDstSize
  ZcNvlistDstFilled
  ZcPad2
  ZcHistory
  ZcValue
  ZcString
  ZcGuid
  ZcNvlistConf
  ZcNvlistConfSize
  ZcCookie
  ZcObjsetType
  ZcPermAction
  ZcHistoryLen
  ZcHistoryOffset
  ZcObj
  ZcIflags
  ZcShare
  ZcObjsetStats
  ZcBeginRecord
  ZcInjectRecord
  ZcPad1
  ZcDeferDestroy
  ZcFlags
  ZcActionHandle
  ZcCleanupFd
  ZcSimple
  ZcPad
  ZcSendobj
  ZcFromobj
  ZcCreatetxg
  ZcStat
  ZcZoneid
}

fn zfs_cmd_t() -> StructT(ZfsCmdField) {
  [
    Field(ZcName, { sizeof_char * maxpathlen }),
    Field(ZcNvlistSrc, sizeof_uint64),
    Field(ZcNvlistSrcSize, sizeof_uint64),
    Field(ZcNvlistDst, sizeof_uint64),
    Field(ZcNvlistDstSize, sizeof_uint64),
    Field(ZcNvlistDstFilled, sizeof_boolean),
    Field(ZcPad2, sizeof_int),
    Field(ZcHistory, sizeof_uint64),
    Field(ZcValue, { sizeof_char * maxpathlen * 2 }),
    Field(ZcString, { sizeof_char * maxnamelen }),
    Field(ZcGuid, sizeof_uint64),
    Field(ZcNvlistConf, sizeof_uint64),
    Field(ZcNvlistConfSize, sizeof_uint64),
    Field(ZcCookie, sizeof_uint64),
    Field(ZcObjsetType, sizeof_uint64),
    Field(ZcPermAction, sizeof_uint64),
    Field(ZcHistoryLen, sizeof_uint64),
    Field(ZcHistoryOffset, sizeof_uint64),
    Field(ZcObj, sizeof_uint64),
    Field(ZcIflags, sizeof_uint64),
    Field(ZcShare, sizeof_struct(zfs_share_t())),
    Field(ZcObjsetStats, sizeof_struct(dmu_objset_stats_t())),
    Field(ZcBeginRecord, sizeof_struct(drr_begin_t())),
    Union([
      [Field(ZcInjectRecord, sizeof_struct(zinject_record_t()))],
      [
        Field(ZcPad1, { sizeof_struct(zinject_record_t()) - 16 }),
        Field(ZcDeferDestroy, sizeof_uint32),
        Field(ZcFlags, sizeof_uint32),
        Field(ZcActionHandle, sizeof_uint64),
      ],
    ]),
    Field(ZcCleanupFd, sizeof_int),
    Field(ZcSimple, sizeof_uint8),
    Field(ZcPad, { sizeof_uint8 * 3 }),
    Field(ZcSendobj, sizeof_uint64),
    Field(ZcFromobj, sizeof_uint64),
    Field(ZcCreatetxg, sizeof_uint64),
    Field(ZcStat, sizeof_struct(zfs_stat_t())),
    Field(ZcZoneid, sizeof_uint64),
  ]
}

fn build_zfs_cmd(values: Struct(ZfsCmdField)) -> ZfsCmd {
  build_struct(zfs_cmd_t(), values)
}

type ZfsCmdReq {
  ZfsCmdReq(
    zc: ZfsCmd,
    history: Option(String),
    // only for destroy, export
    src: Option(BitArray),
    conf: Option(BitArray),
  )
}

// The driver returns our command response type wrapped in a Result, where Ok
// means the request was structurally valid and ioctl was invoked, while Error
// means the request was malformed and ioctl could not be invoked.

type ZfsCmdRes {
  ZfsCmdRes(
    zc: ZfsCmd,
    error: Int,
    message: Option(String),
    dst: Option(BitArray),
  )
}

fn ioctl(hdl: Handle, ioc: ZfsIoc, req: ZfsCmdReq) -> ZfsCmdRes {
  let assert Ok(res) = port_call(hdl.inner, zfsioc_index(ioc), req)
  res
}

fn error(res: ZfsCmdRes) -> Error {
  assert res.error != 0
  case res {
    ZfsCmdRes(zc, error, message: Some(message), dst: None) ->
      ErrorWithMessage(zc, error, message)
    ZfsCmdRes(zc, error, message: None, dst: Some(packed_info)) -> {
      let assert Ok(#(info, <<>>)) = nvs.unpack(packed_info)
      ErrorWithInfo(zc, error, info)
    }
    ZfsCmdRes(zc, error, message: Some(message), dst: Some(packed_info)) -> {
      let assert Ok(#(info, <<>>)) = nvs.unpack(packed_info)
      ErrorWithMessageAndInfo(zc, error, message, info)
    }
    ZfsCmdRes(zc, ..) -> ErrorWithZfsCmd(zc)
  }
}

fn ioctl_unit(hdl: Handle, ioc: ZfsIoc, req: ZfsCmdReq) -> Result(Nil, Error) {
  case ioctl(hdl, ioc, req) {
    ZfsCmdRes(error: 0, message: None, dst: None, ..) -> Ok(Nil)
    ZfsCmdRes(error: 0, message: None, dst: Some(packed), ..) -> {
      let assert Ok(#(info, <<>>)) = nvs.unpack(packed)
      assert nvl.is_empty(info)
      Ok(Nil)
    }
    res -> Error(error(res))
  }
}

fn ioctl_nvlist(
  hdl: Handle,
  ioc: ZfsIoc,
  req: ZfsCmdReq,
) -> Result(NvList, Error) {
  case ioctl(hdl, ioc, req) {
    ZfsCmdRes(error: 0, message: None, dst: Some(packed), ..) -> {
      let assert Ok(#(nvl, <<>>)) = nvs.unpack(packed)
      Ok(nvl)
    }
    res -> Error(error(res))
  }
}

const esrch = 3

fn ioctl_stats_list_next(
  hdl: Handle,
  ioc: ZfsIoc,
  req: ZfsCmdReq,
) -> Result(Option(#(String, Int, ObjsetStats, Option(NvList))), Error) {
  case ioctl(hdl, ioc, req) {
    ZfsCmdRes(zc: _, error: error, message: None, dst: None) if error == esrch ->
      Ok(None)
    ZfsCmdRes(zc, error: 0, message: None, dst: dst) -> {
      let t = zfs_cmd_t()
      use next_name <- result.try(
        struct_read(t, ZcName, zc)
        |> str()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use next_cookie <- result.try(
        struct_read(t, ZcCookie, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use objset_stats <- result.try(
        struct_read(t, ZcObjsetStats, zc)
        |> bin_objset_stats()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      Ok(
        Some(#(
          next_name,
          next_cookie,
          objset_stats,
          option.map(dst, fn(packed_config) {
            let assert Ok(#(config, <<>>)) = nvs.unpack(packed_config)
            config
          }),
        )),
      )
    }
    res -> Error(error(res))
  }
}

fn zfs_cmd_string_field(
  field: ZfsCmdField,
  value: String,
) -> Result(FieldValue(ZfsCmdField), Error) {
  string_pad(zfs_cmd_t(), field, value)
  |> result.replace_error(InternalError)
}

pub fn pool_create(
  hdl: Handle,
  name: String,
  config: NvList,
  props: Option(NvList),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolCreate,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: option.map(props, nvs.pack(_, nvs.Native)),
      conf: Some(nvs.pack(config, nvs.Native)),
    ),
  )
}

pub fn pool_destroy(
  hdl: Handle,
  name: String,
  history: Option(String),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolDestroy,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: history,
      src: None,
      conf: None,
    ),
  )
}

pub type ImportFlag {
  ImportNormal
  ImportVerbatim
  ImportAnyHost
  ImportMissingLog
  ImportOnly
  ImportTempName
  ImportSkipMmp
  ImportLoadKeys
  ImportCheckpoint
}

fn import_flags_int(flags: List(ImportFlag)) -> Int {
  list.fold(flags, 0, fn(acc, flag) {
    int.bitwise_or(acc, case flag {
      ImportNormal -> 0x00
      ImportVerbatim -> 0x01
      ImportAnyHost -> 0x02
      ImportMissingLog -> 0x04
      ImportOnly -> 0x08
      ImportTempName -> 0x10
      ImportSkipMmp -> 0x20
      ImportLoadKeys -> 0x40
      ImportCheckpoint -> 0x80
    })
  })
}

pub fn pool_import(
  hdl: Handle,
  name: String,
  guid: Int,
  config: NvList,
  props: Option(NvList),
  flags: List(ImportFlag),
) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_config = nvs.pack(config, nvs.Native)
  let packed_config_size = bit_array.byte_size(packed_config)
  ioctl_nvlist(
    hdl,
    ZfsIocPoolImport,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcCookie, import_flags_int(flags) |> int_uint64()),
        FieldValue(ZcGuid, int_uint64(guid)),
        FieldValue(ZcNvlistDstSize, int_uint64(2 * packed_config_size)),
      ]),
      history: None,
      src: option.map(props, nvs.pack(_, nvs.Native)),
      conf: Some(packed_config),
    ),
  )
}

pub fn pool_export(
  hdl: Handle,
  name: String,
  force: Bool,
  hardforce: Bool,
  history: Option(String),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolExport,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcCookie, int(force) |> int_uint64()),
        FieldValue(ZcGuid, int(hardforce) |> int_uint64()),
      ]),
      history: history,
      src: None,
      conf: None,
    ),
  )
}

pub fn pool_configs(hdl: Handle, ns_gen: Int) -> Result(#(Int, NvList), Error) {
  let t = zfs_cmd_t()
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        FieldValue(ZcCookie, int_uint64(ns_gen)),
        FieldValue(ZcNvlistDstSize, int_uint64(256 * 1024)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocPoolConfigs, req) {
    ZfsCmdRes(zc, error: 0, message: None, dst: Some(packed_configs)) -> {
      use ns_gen <- result.try(
        struct_read(t, ZcCookie, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      let assert Ok(#(configs, <<>>)) = nvs.unpack(packed_configs)
      Ok(#(ns_gen, configs))
    }
    res -> Error(error(res))
  }
}

pub fn pool_stats(
  hdl: Handle,
  name: String,
) -> Result(#(Option(NvList), Option(String), Option(Int)), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(64 * 1024)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  let t = zfs_cmd_t()
  case ioctl(hdl, ZfsIocPoolStats, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: dst) -> {
      use error <- result.try(
        struct_read(t, ZcCookie, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use altroot <- result.try(
        struct_read(t, ZcValue, zc)
        |> str()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      Ok(
        #(
          option.map(dst, fn(packed_config) {
            let assert Ok(#(config, <<>>)) = nvs.unpack(packed_config)
            config
          }),
          case altroot {
            "" -> None
            _ -> Some(altroot)
          },
          case error {
            0 -> None
            _ -> Some(error)
          },
        ),
      )
    }
    ZfsCmdRes(zc: zc, error: error, message: None, dst: None) -> {
      use altroot <- result.try(
        struct_read(t, ZcValue, zc)
        |> str()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      Ok(
        #(
          None,
          case altroot {
            "" -> None
            _ -> Some(altroot)
          },
          case error {
            0 -> None
            error -> Some(error)
          },
        ),
      )
    }
    res -> Error(error(res))
  }
}

pub fn pool_tryimport(hdl: Handle, config: NvList) -> Result(NvList, Error) {
  let packed_config = nvs.pack(config, nvs.Native)
  let packed_config_size = bit_array.byte_size(packed_config)
  let dst_size = int.max(256 * 1024, packed_config_size * 32)
  ioctl_nvlist(
    hdl,
    ZfsIocPoolTryImport,
    ZfsCmdReq(
      zc: build_zfs_cmd([FieldValue(ZcNvlistDstSize, int_uint64(dst_size))]),
      history: None,
      src: None,
      conf: Some(packed_config),
    ),
  )
}

pub type PoolScanFunc {
  ScanNone
  ScanScrub
  ScanResilver
  ScanErrorScrub
}

fn scan_func_index(func: PoolScanFunc) -> Int {
  case func {
    ScanNone -> 0
    ScanScrub -> 1
    ScanResilver -> 2
    ScanErrorScrub -> 3
  }
}

pub type PoolScrubCmd {
  ScrubNormal
  ScrubPause
  ScrubFromLastTxg
}

fn scrub_cmd_index(cmd: PoolScrubCmd) -> Int {
  case cmd {
    ScrubNormal -> 0
    ScrubPause -> 1
    ScrubFromLastTxg -> 2
  }
}

pub fn pool_scan(
  hdl: Handle,
  name: String,
  func: PoolScanFunc,
  cmd: PoolScrubCmd,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolScan,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcCookie, scan_func_index(func) |> int_uint64()),
        FieldValue(ZcFlags, scrub_cmd_index(cmd) |> int_uint32()),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn pool_freeze(hdl: Handle, name: String) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolFreeze,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn pool_upgrade(
  hdl: Handle,
  name: String,
  version: Int,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolUpgrade,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcCookie, int_uint64(version)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

fn split_history(
  acc: List(BitArray),
  rest: BitArray,
) -> Result(List(NvList), Nil) {
  case rest {
    <<>> ->
      acc
      |> list.reverse
      |> list.map(nvs.unpack)
      |> result.all
      |> result.map(list.map(_, pair.first))
      |> result.replace_error(Nil)
    <<len:native-unsigned-size(64), data:bytes-size(len), rest:bytes>> ->
      split_history([data, ..acc], rest)
    _ -> Error(Nil)
  }
}

pub fn pool_get_history(
  hdl: Handle,
  name: String,
  offset: Int,
) -> Result(#(List(NvList), Int), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcHistoryOffset, int_uint64(offset)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocPoolGetHistory, req) {
    ZfsCmdRes(
      zc,
      error: 0,
      message: None,
      dst: Some(<<new_offset:native-unsigned-size(64), history_chunk:bytes>>),
    ) ->
      case split_history([], history_chunk) {
        Ok(history) -> Ok(#(history, new_offset))
        Error(Nil) -> Error(ErrorWithZfsCmd(zc))
      }
    res -> Error(error(res))
  }
}

pub fn vdev_add(
  hdl: Handle,
  name: String,
  config: NvList,
  check_ashift: Bool,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocVdevAdd,
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          opt(check_ashift, FieldValue(ZcFlags, int(True) |> int_uint32())),
        ]),
      ),
      history: None,
      src: None,
      conf: Some(nvs.pack(config, nvs.Native)),
    ),
  )
}

pub fn vdev_remove(hdl: Handle, name: String, guid: Int) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocVdevRemove,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcGuid, int_uint64(guid)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn vdev_remove_cancel(hdl: Handle, name: String) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocVdevRemove,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcCookie, int(True) |> int_uint64()),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub type VdevState {
  VdevStateUnknown
  VdevStateClosed
  VdevStateOffline
  VdevStateRemoved
  VdevStateCantOpen
  VdevStateFaulted
  VdevStateDegraded
  VdevStateHealthy
}

fn vdev_state_index(state: VdevState) -> Int {
  case state {
    VdevStateUnknown -> 0
    VdevStateClosed -> 1
    VdevStateOffline -> 2
    VdevStateRemoved -> 3
    VdevStateCantOpen -> 4
    VdevStateFaulted -> 5
    VdevStateDegraded -> 6
    VdevStateHealthy -> 6
  }
}

fn index_vdev_state(index: Int) -> Option(VdevState) {
  case index {
    0 -> Some(VdevStateUnknown)
    1 -> Some(VdevStateClosed)
    2 -> Some(VdevStateOffline)
    3 -> Some(VdevStateRemoved)
    4 -> Some(VdevStateCantOpen)
    5 -> Some(VdevStateFaulted)
    6 -> Some(VdevStateDegraded)
    7 -> Some(VdevStateHealthy)
    _ -> None
  }
}

pub fn vdev_set_state(
  hdl: Handle,
  name: String,
  guid: Int,
  state: VdevState,
  flags: Option(Int),
) -> Result(VdevState, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          Some(FieldValue(ZcCookie, vdev_state_index(state) |> int_uint64())),
          Some(FieldValue(ZcGuid, int_uint64(guid))),
          option.map(flags, fn(obj) { FieldValue(ZcObj, int_uint64(obj)) }),
        ]),
      ),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocVdevSetState, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) -> {
      use cookie <- result.try(
        struct_read(zfs_cmd_t(), ZcCookie, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      let assert Some(vdev_state) = index_vdev_state(cookie)
      Ok(vdev_state)
    }
    res -> Error(error(res))
  }
}

pub fn vdev_attach(
  hdl: Handle,
  name: String,
  guid: Int,
  config: NvList,
  replacing: Bool,
  rebuild: Bool,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocVdevAttach,
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          opt(replacing, FieldValue(ZcCookie, int(True) |> int_uint64())),
          Some(FieldValue(ZcGuid, int_uint64(guid))),
          opt(rebuild, FieldValue(ZcSimple, int(True) |> int_uint8())),
        ]),
      ),
      history: None,
      src: None,
      conf: Some(nvs.pack(config, nvs.Native)),
    ),
  )
}

pub fn vdev_detach(hdl: Handle, name: String, guid: Int) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocVdevDetach,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcGuid, int_uint64(guid)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn vdev_set_path(
  hdl: Handle,
  name: String,
  guid: Int,
  path: String,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  use value_field <- result.try(zfs_cmd_string_field(ZcValue, path))
  ioctl_unit(
    hdl,
    ZfsIocVdevSetPath,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcGuid, int_uint64(guid)),
        value_field,
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn vdev_set_fru(
  hdl: Handle,
  name: String,
  guid: Int,
  fru: String,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  use value_field <- result.try(zfs_cmd_string_field(ZcValue, fru))
  ioctl_unit(
    hdl,
    ZfsIocVdevSetFru,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcGuid, int_uint64(guid)),
        value_field,
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub type ObjsetType {
  ObjsetTypeNone
  ObjsetTypeMeta
  ObjsetTypeZfs
  ObjsetTypeZvol
  ObjsetTypeOther
  ObjsetTypeAny
}

fn objset_type_index(objset_type: ObjsetType) -> Int {
  case objset_type {
    ObjsetTypeNone -> 0
    ObjsetTypeMeta -> 1
    ObjsetTypeZfs -> 2
    ObjsetTypeZvol -> 3
    ObjsetTypeOther -> 4
    ObjsetTypeAny -> 5
  }
}

fn index_objset_type(index: Int) -> Option(ObjsetType) {
  case index {
    0 -> Some(ObjsetTypeNone)
    1 -> Some(ObjsetTypeMeta)
    2 -> Some(ObjsetTypeZfs)
    3 -> Some(ObjsetTypeZvol)
    4 -> Some(ObjsetTypeOther)
    5 -> Some(ObjsetTypeAny)
    _ -> None
  }
}

pub type ObjsetStats {
  ObjsetStats(
    num_clones: Int,
    creation_txg: Int,
    guid: Int,
    objset_type: ObjsetType,
    is_snapshot: Bool,
    inconsistent: Bool,
    redacted: Bool,
    origin: String,
    flags: Int,
  )
}

fn bin_objset_stats(bin: BitArray) -> Result(ObjsetStats, Nil) {
  case bin {
    <<
      num_clones:native-unsigned-size(64),
      creation_txg:native-unsigned-size(64),
      guid:native-unsigned-size(64),
      objset_type_index:native-size(32),
      is_snapshot:size(8),
      inconsistent:size(8),
      redacted:size(8),
      origin_bytes:bytes-size(zfs_max_dataset_name_len),
      flags:size(8),
    >> -> {
      let assert Some(objset_type) = index_objset_type(objset_type_index)
      let assert Ok(origin) = str(origin_bytes)
      Ok(ObjsetStats(
        num_clones,
        creation_txg,
        guid,
        objset_type,
        is_snapshot != 0,
        inconsistent != 0,
        redacted != 0,
        origin,
        flags,
      ))
    }
    _ -> Error(Nil)
  }
}

pub fn objset_stats(
  hdl: Handle,
  name: String,
  simple: Bool,
) -> Result(#(ObjsetStats, Option(NvList)), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          Some(FieldValue(ZcSimple, int(simple) |> int_uint8())),
          opt(!simple, FieldValue(ZcNvlistDstSize, int_uint64(256 * 1024))),
        ]),
      ),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocObjsetStats, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: dst) -> {
      use objset_stats <- result.try(
        struct_read(zfs_cmd_t(), ZcObjsetStats, zc)
        |> bin_objset_stats()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      Ok(#(
        objset_stats,
        option.map(dst, fn(packed_props) {
          let assert Ok(#(props, <<>>)) = nvs.unpack(packed_props)
          props
        }),
      ))
    }
    res -> Error(error(res))
  }
}

pub fn objset_zpl_props(hdl: Handle, name: String) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_nvlist(
    hdl,
    ZfsIocObjsetZplProps,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(256 * 1024)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn dataset_list_next(
  hdl: Handle,
  name: String,
  simple: Bool,
  cookie: Int,
) -> Result(Option(#(String, Int, ObjsetStats, Option(NvList))), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_stats_list_next(
    hdl,
    ZfsIocDatasetListNext,
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          Some(FieldValue(ZcSimple, int(simple) |> int_uint8())),
          Some(FieldValue(ZcCookie, int_uint64(cookie))),
          opt(!simple, FieldValue(ZcNvlistDstSize, int_uint64(256 * 1024))),
        ]),
      ),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn snapshot_list_next(
  hdl: Handle,
  name: String,
  simple: Bool,
  cookie: Int,
) -> Result(Option(#(String, Int, ObjsetStats, Option(NvList))), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_stats_list_next(
    hdl,
    ZfsIocSnapshotListNext,
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          Some(FieldValue(ZcSimple, int(simple) |> int_uint8())),
          Some(FieldValue(ZcCookie, int_uint64(cookie))),
          opt(!simple, FieldValue(ZcNvlistDstSize, int_uint64(256 * 1024))),
        ]),
      ),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn set_prop(
  hdl: Handle,
  name: String,
  props: NvList,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_props = nvs.pack(props, nvs.Native)
  let packed_props_size = bit_array.byte_size(packed_props)
  let dst_size = int.max(256 * 1024, packed_props_size)
  ioctl_unit(
    hdl,
    ZfsIocSetProp,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_props),
      conf: None,
    ),
  )
}

pub fn create(
  hdl: Handle,
  name: String,
  objset_type: ObjsetType,
  props: Option(NvList),
  hidden_args: Option(NvList),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocCreate,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: nvlist_opt([
        Some(nvl.Int32("type", objset_type_index(objset_type))),
        option.map(props, nvl.Nvlist("props", _)),
        option.map(hidden_args, nvl.Nvlist("hidden_args", _)),
      ]),
      conf: None,
    ),
  )
}

pub fn destroy(hdl: Handle, name: String, defer: Bool) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocDestroy,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: nvlist_opt([opt(defer, nvl.Uint32("defer_destroy", int(True)))]),
      conf: None,
    ),
  )
}

pub fn rollback(
  hdl: Handle,
  name: String,
  target: Option(String),
) -> Result(String, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocRollback,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(128 * 1024)),
      ]),
      history: None,
      src: nvlist_opt([option.map(target, nvl.String("target", _))]),
      conf: None,
    ),
  ))
  let assert Some(nvl.String(_, target)) = nvl.lookup(results, "target")
  Ok(target)
}

pub type RenameFlag {
  RenameRecursive
  RenameNounmount
}

fn rename_flags_int(flags: List(RenameFlag)) -> Int {
  list.fold(flags, 0, fn(acc, flag) {
    int.bitwise_or(acc, case flag {
      RenameRecursive -> 0x1
      RenameNounmount -> 0x2
    })
  })
}

pub fn rename(
  hdl: Handle,
  name: String,
  newname: String,
  flags: List(RenameFlag),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  use value_field <- result.try(zfs_cmd_string_field(ZcValue, newname))
  let flags_opt = case flags {
    [] -> None
    _ -> Some(rename_flags_int(flags))
  }
  ioctl_unit(
    hdl,
    ZfsIocRename,
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          Some(value_field),
          option.map(flags_opt, fn(cookie) {
            FieldValue(ZcCookie, int_uint64(cookie))
          }),
        ]),
      ),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

// TODO: recv, send

pub type DmuObjectType {
  DmuObjTypeNone
  // XXX: option?
  DmuObjTypeObjectDirectory
  DmuObjTypeObjectArray
  DmuObjTypePackedNvlist
  DmuObjTypePackedNvlistSize
  DmuObjTypeBpobj
  DmuObjTypeBpobjHdr
  DmuObjTypeSpaceMapHeader
  DmuObjTypeSpaceMap
  DmuObjTypeIntentLog
  DmuObjTypeDnode
  DmuObjTypeObjset
  DmuObjTypeDslDir
  DmuObjTypeDslDirChildMap
  DmuObjTypeDslDsSnapMap
  DmuObjTypeDslProps
  DmuObjTypeDslDataset
  DmuObjTypeZnode
  DmuObjTypeOldAcl
  DmuObjTypePlainFileContents
  DmuObjTypeDirectoryContents
  DmuObjTypeMasterNode
  DmuObjTypeUnlinkedSet
  DmuObjTypeZvol
  DmuObjTypeZvolProp
  DmuObjTypePlainOther
  DmuObjTypeUint64Other
  DmuObjTypeZapOther
  DmuObjTypeErrorLog
  DmuObjTypeSpaHistory
  DmuObjTypeSpaHistoryOffsets
  DmuObjTypePoolProps
  DmuObjTypeDslPerms
  DmuObjTypeAcl
  DmuObjTypeSysAcl
  DmuObjTypeFuid
  DmuObjTypeFuidSize
  DmuObjTypeNextClones
  DmuObjTypeScanQueue
  DmuObjTypeUsergroupUsed
  DmuObjTypeUsergroupQuota
  DmuObjTypeUserrefs
  DmuObjTypeDdtZap
  DmuObjTypeDdtStats
  DmuObjTypeSa
  DmuObjTypeSaMasterNode
  DmuObjTypeSaAttrRegistration
  DmuObjTypeSaAttrLayouts
  DmuObjTypeScanXlate
  DmuObjTypeDedup
  DmuObjTypeDeadlist
  DmuObjTypeDeadlistHdr
  DmuObjTypeDslClones
  DmuObjTypeBpobjSubobj
  DmuObjTypeNumtypes
  // XXX: put this elsewhere?
  DmuObjTypeNewUint8Data
  DmuObjTypeNewUint8Metadata
  DmuObjTypeNewUint16Data
  DmuObjTypeNewUint16Metadata
  DmuObjTypeNewUint32Data
  DmuObjTypeNewUint32Metadata
  DmuObjTypeNewUint64Data
  DmuObjTypeNewUint64Metadata
  DmuObjTypeNewZapData
  DmuObjTypeNewZapMetadata
  DmuObjTypeNewUint8EncData
  DmuObjTypeNewUint8EncMetadata
  DmuObjTypeNewUint16EncData
  DmuObjTypeNewUint16EncMetadata
  DmuObjTypeNewUint32EncData
  DmuObjTypeNewUint32EncMetadata
  DmuObjTypeNewUint64EncData
  DmuObjTypeNewUint64EncMetadata
  DmuObjTypeNewZapEncData
  DmuObjTypeNewZapEncMetadata
}

fn object_type_index(ot: DmuObjectType) -> Int {
  case ot {
    DmuObjTypeNone -> 0
    // XXX: option?
    DmuObjTypeObjectDirectory -> 1
    DmuObjTypeObjectArray -> 2
    DmuObjTypePackedNvlist -> 3
    DmuObjTypePackedNvlistSize -> 4
    DmuObjTypeBpobj -> 5
    DmuObjTypeBpobjHdr -> 6
    DmuObjTypeSpaceMapHeader -> 7
    DmuObjTypeSpaceMap -> 8
    DmuObjTypeIntentLog -> 9
    DmuObjTypeDnode -> 10
    DmuObjTypeObjset -> 11
    DmuObjTypeDslDir -> 12
    DmuObjTypeDslDirChildMap -> 13
    DmuObjTypeDslDsSnapMap -> 14
    DmuObjTypeDslProps -> 15
    DmuObjTypeDslDataset -> 16
    DmuObjTypeZnode -> 17
    DmuObjTypeOldAcl -> 18
    DmuObjTypePlainFileContents -> 19
    DmuObjTypeDirectoryContents -> 20
    DmuObjTypeMasterNode -> 21
    DmuObjTypeUnlinkedSet -> 22
    DmuObjTypeZvol -> 23
    DmuObjTypeZvolProp -> 24
    DmuObjTypePlainOther -> 25
    DmuObjTypeUint64Other -> 26
    DmuObjTypeZapOther -> 27
    DmuObjTypeErrorLog -> 28
    DmuObjTypeSpaHistory -> 29
    DmuObjTypeSpaHistoryOffsets -> 30
    DmuObjTypePoolProps -> 31
    DmuObjTypeDslPerms -> 32
    DmuObjTypeAcl -> 33
    DmuObjTypeSysAcl -> 34
    DmuObjTypeFuid -> 35
    DmuObjTypeFuidSize -> 36
    DmuObjTypeNextClones -> 37
    DmuObjTypeScanQueue -> 38
    DmuObjTypeUsergroupUsed -> 39
    DmuObjTypeUsergroupQuota -> 40
    DmuObjTypeUserrefs -> 41
    DmuObjTypeDdtZap -> 42
    DmuObjTypeDdtStats -> 43
    DmuObjTypeSa -> 44
    DmuObjTypeSaMasterNode -> 45
    DmuObjTypeSaAttrRegistration -> 46
    DmuObjTypeSaAttrLayouts -> 47
    DmuObjTypeScanXlate -> 48
    DmuObjTypeDedup -> 49
    DmuObjTypeDeadlist -> 50
    DmuObjTypeDeadlistHdr -> 51
    DmuObjTypeDslClones -> 52
    DmuObjTypeBpobjSubobj -> 53
    DmuObjTypeNumtypes -> 54
    // XXX: put this elsewhere?
    DmuObjTypeNewUint8Data -> 128
    DmuObjTypeNewUint8Metadata -> 192
    DmuObjTypeNewUint16Data -> 129
    DmuObjTypeNewUint16Metadata -> 193
    DmuObjTypeNewUint32Data -> 130
    DmuObjTypeNewUint32Metadata -> 194
    DmuObjTypeNewUint64Data -> 131
    DmuObjTypeNewUint64Metadata -> 195
    DmuObjTypeNewZapData -> 132
    DmuObjTypeNewZapMetadata -> 196
    DmuObjTypeNewUint8EncData -> 160
    DmuObjTypeNewUint8EncMetadata -> 224
    DmuObjTypeNewUint16EncData -> 161
    DmuObjTypeNewUint16EncMetadata -> 225
    DmuObjTypeNewUint32EncData -> 162
    DmuObjTypeNewUint32EncMetadata -> 226
    DmuObjTypeNewUint64EncData -> 163
    DmuObjTypeNewUint64EncMetadata -> 227
    DmuObjTypeNewZapEncData -> 164
    DmuObjTypeNewZapEncMetadata -> 228
  }
}

fn index_object_type(index: Int) -> Option(DmuObjectType) {
  case index {
    0 -> Some(DmuObjTypeNone)
    // XXX: option?
    1 -> Some(DmuObjTypeObjectDirectory)
    2 -> Some(DmuObjTypeObjectArray)
    3 -> Some(DmuObjTypePackedNvlist)
    4 -> Some(DmuObjTypePackedNvlistSize)
    5 -> Some(DmuObjTypeBpobj)
    6 -> Some(DmuObjTypeBpobjHdr)
    7 -> Some(DmuObjTypeSpaceMapHeader)
    8 -> Some(DmuObjTypeSpaceMap)
    9 -> Some(DmuObjTypeIntentLog)
    10 -> Some(DmuObjTypeDnode)
    11 -> Some(DmuObjTypeObjset)
    12 -> Some(DmuObjTypeDslDir)
    13 -> Some(DmuObjTypeDslDirChildMap)
    14 -> Some(DmuObjTypeDslDsSnapMap)
    15 -> Some(DmuObjTypeDslProps)
    16 -> Some(DmuObjTypeDslDataset)
    17 -> Some(DmuObjTypeZnode)
    18 -> Some(DmuObjTypeOldAcl)
    19 -> Some(DmuObjTypePlainFileContents)
    20 -> Some(DmuObjTypeDirectoryContents)
    21 -> Some(DmuObjTypeMasterNode)
    22 -> Some(DmuObjTypeUnlinkedSet)
    23 -> Some(DmuObjTypeZvol)
    24 -> Some(DmuObjTypeZvolProp)
    25 -> Some(DmuObjTypePlainOther)
    26 -> Some(DmuObjTypeUint64Other)
    27 -> Some(DmuObjTypeZapOther)
    28 -> Some(DmuObjTypeErrorLog)
    29 -> Some(DmuObjTypeSpaHistory)
    30 -> Some(DmuObjTypeSpaHistoryOffsets)
    31 -> Some(DmuObjTypePoolProps)
    32 -> Some(DmuObjTypeDslPerms)
    33 -> Some(DmuObjTypeAcl)
    34 -> Some(DmuObjTypeSysAcl)
    35 -> Some(DmuObjTypeFuid)
    36 -> Some(DmuObjTypeFuidSize)
    37 -> Some(DmuObjTypeNextClones)
    38 -> Some(DmuObjTypeScanQueue)
    39 -> Some(DmuObjTypeUsergroupUsed)
    40 -> Some(DmuObjTypeUsergroupQuota)
    41 -> Some(DmuObjTypeUserrefs)
    42 -> Some(DmuObjTypeDdtZap)
    43 -> Some(DmuObjTypeDdtStats)
    44 -> Some(DmuObjTypeSa)
    45 -> Some(DmuObjTypeSaMasterNode)
    46 -> Some(DmuObjTypeSaAttrRegistration)
    47 -> Some(DmuObjTypeSaAttrLayouts)
    48 -> Some(DmuObjTypeScanXlate)
    49 -> Some(DmuObjTypeDedup)
    50 -> Some(DmuObjTypeDeadlist)
    51 -> Some(DmuObjTypeDeadlistHdr)
    52 -> Some(DmuObjTypeDslClones)
    53 -> Some(DmuObjTypeBpobjSubobj)
    54 -> Some(DmuObjTypeNumtypes)
    // XXX: put this elsewhere?
    128 -> Some(DmuObjTypeNewUint8Data)
    192 -> Some(DmuObjTypeNewUint8Metadata)
    129 -> Some(DmuObjTypeNewUint16Data)
    193 -> Some(DmuObjTypeNewUint16Metadata)
    130 -> Some(DmuObjTypeNewUint32Data)
    194 -> Some(DmuObjTypeNewUint32Metadata)
    131 -> Some(DmuObjTypeNewUint64Data)
    195 -> Some(DmuObjTypeNewUint64Metadata)
    132 -> Some(DmuObjTypeNewZapData)
    196 -> Some(DmuObjTypeNewZapMetadata)
    160 -> Some(DmuObjTypeNewUint8EncData)
    224 -> Some(DmuObjTypeNewUint8EncMetadata)
    161 -> Some(DmuObjTypeNewUint16EncData)
    225 -> Some(DmuObjTypeNewUint16EncMetadata)
    162 -> Some(DmuObjTypeNewUint32EncData)
    226 -> Some(DmuObjTypeNewUint32EncMetadata)
    163 -> Some(DmuObjTypeNewUint64EncData)
    227 -> Some(DmuObjTypeNewUint64EncMetadata)
    164 -> Some(DmuObjTypeNewZapEncData)
    228 -> Some(DmuObjTypeNewZapEncMetadata)
    _ -> None
  }
}

pub type InjectIotype {
  IotypeNull
  IotypeRead
  IotypeWrite
  IotypeFree
  IotypeClaim
  IotypeFlush
  IotypeTrim
  IotypeAll
  IotypeProbe
}

fn inject_iotype_index(iotype: InjectIotype) -> Int {
  case iotype {
    IotypeNull -> 0
    IotypeRead -> 1
    IotypeWrite -> 2
    IotypeFree -> 3
    IotypeClaim -> 4
    IotypeFlush -> 5
    IotypeTrim -> 6
    IotypeAll -> 7
    IotypeProbe -> 16
  }
}

fn index_inject_iotype(index: Int) -> Option(InjectIotype) {
  case index {
    0 -> Some(IotypeNull)
    1 -> Some(IotypeRead)
    2 -> Some(IotypeWrite)
    3 -> Some(IotypeFree)
    4 -> Some(IotypeClaim)
    5 -> Some(IotypeFlush)
    6 -> Some(IotypeTrim)
    7 -> Some(IotypeAll)
    16 -> Some(IotypeProbe)
    _ -> None
  }
}

pub type InjectType {
  InjectUninitialized
  InjectDataFault
  InjectDeviceFault
  InjectLabelFault
  InjectIgnoredWrites
  InjectPanic
  InjectDelayIo
  InjectDecryptFault
  InjectDelayImport
  InjectDelayExport
  InjectDelayReady
}

fn inject_type_index(it: InjectType) -> Int {
  case it {
    InjectUninitialized -> 0
    InjectDataFault -> 1
    InjectDeviceFault -> 2
    InjectLabelFault -> 3
    InjectIgnoredWrites -> 4
    InjectPanic -> 5
    InjectDelayIo -> 6
    InjectDecryptFault -> 7
    InjectDelayImport -> 8
    InjectDelayExport -> 9
    InjectDelayReady -> 10
  }
}

fn index_inject_type(index: Int) -> Option(InjectType) {
  case index {
    0 -> Some(InjectUninitialized)
    1 -> Some(InjectDataFault)
    2 -> Some(InjectDeviceFault)
    3 -> Some(InjectLabelFault)
    4 -> Some(InjectIgnoredWrites)
    5 -> Some(InjectPanic)
    6 -> Some(InjectDelayIo)
    7 -> Some(InjectDecryptFault)
    8 -> Some(InjectDelayImport)
    9 -> Some(InjectDelayExport)
    10 -> Some(InjectDelayReady)
    _ -> None
  }
}

pub type InjectRecord {
  InjectRecord(
    objset: Int,
    object: Int,
    start: Int,
    end: Int,
    guid: Int,
    level: Int,
    error: Int,
    object_type: DmuObjectType,
    freq: Int,
    failfast: Int,
    func: String,
    iotype: InjectIotype,
    duration: Int,
    timer: Int,
    nlanes: Int,
    cmd: InjectType,
    dvas: Int,
    match_count: Int,
    inject_count: Int,
  )
}

fn bin_inject_record(bin: BitArray) -> Result(InjectRecord, Nil) {
  case bin {
    <<
      objset:native-unsigned-size(64),
      object:native-unsigned-size(64),
      start:native-unsigned-size(64),
      end:native-unsigned-size(64),
      guid:native-unsigned-size(64),
      level:native-unsigned-size(32),
      error:native-unsigned-size(32),
      object_type_index:native-unsigned-size(64),
      freq:native-unsigned-size(32),
      failfast:native-unsigned-size(32),
      func_raw:bytes-size(maxnamelen),
      iotype_index:native-unsigned-size(32),
      duration:native-size(32),
      timer:native-unsigned-size(64),
      nlanes:native-unsigned-size(64),
      cmd_index:native-unsigned-size(32),
      dvas:native-unsigned-size(32),
      match_count:native-unsigned-size(64),
      inject_count:native-unsigned-size(64),
    >> -> {
      let assert Some(object_type) = index_object_type(object_type_index)
      let assert Some(iotype) = index_inject_iotype(iotype_index)
      let assert Some(cmd) = index_inject_type(cmd_index)
      let assert Ok(func) = str(func_raw)
      Ok(InjectRecord(
        objset,
        object,
        start,
        end,
        guid,
        level,
        error,
        object_type,
        freq,
        failfast,
        func,
        iotype,
        duration,
        timer,
        nlanes,
        cmd,
        dvas,
        match_count,
        inject_count,
      ))
    }
    _ -> Error(Nil)
  }
}

fn inject_record_bin(record: InjectRecord) -> BitArray {
  let pad_len = maxnamelen - string.length(record.func)
  <<
    record.objset:native-size(64),
    record.object:native-size(64),
    record.start:native-size(64),
    record.end:native-size(64),
    record.guid:native-size(64),
    record.level:native-size(32),
    record.error:native-size(32),
    object_type_index(record.object_type):native-size(64),
    record.freq:native-size(32),
    record.failfast:native-size(32),
    record.func:utf8,
    0:unit(8)-size(pad_len),
    inject_iotype_index(record.iotype):native-size(32),
    record.duration:native-size(32),
    record.timer:native-size(64),
    record.nlanes:native-size(64),
    inject_type_index(record.cmd):native-size(32),
    record.dvas:native-size(32),
    record.match_count:native-size(64),
    record.inject_count:native-size(64),
  >>
}

pub type ZinjectFlag {
  ZinjectNull
  ZinjectFlushArc
  ZinjectUnloadSpa
  ZinjectCalcRange
}

fn zinject_flags_int(flags: List(ZinjectFlag)) -> Int {
  list.fold(flags, 0, fn(acc, flag) {
    int.bitwise_or(acc, case flag {
      ZinjectNull -> 0x1
      ZinjectFlushArc -> 0x2
      ZinjectUnloadSpa -> 0x4
      ZinjectCalcRange -> 0x8
    })
  })
}

pub fn inject_fault(
  hdl: Handle,
  name: String,
  record: InjectRecord,
  flags: List(ZinjectFlag),
) -> Result(Int, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcGuid, zinject_flags_int(flags) |> int_uint64()),
        FieldValue(ZcInjectRecord, inject_record_bin(record)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocInjectFault, req) {
    ZfsCmdRes(zc, error: 0, message: None, dst: None) ->
      struct_read(zfs_cmd_t(), ZcGuid, zc)
      |> uint64_int()
      |> result.replace_error(ErrorWithZfsCmd(zc))
    res -> Error(error(res))
  }
}

pub fn clear_fault(hdl: Handle, guid: Int) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocClearFault,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        FieldValue(ZcGuid, int_uint64(guid)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

const enoent = 2

pub fn inject_list_next(
  hdl: Handle,
  guid: Int,
) -> Result(Option(#(Int, String, InjectRecord)), Error) {
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        FieldValue(ZcGuid, int_uint64(guid)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocInjectListNext, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) -> {
      let t = zfs_cmd_t()
      use guid <- result.try(
        struct_read(t, ZcGuid, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use name <- result.try(
        struct_read(t, ZcName, zc)
        |> str()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use inject_record <- result.try(
        struct_read(t, ZcInjectRecord, zc)
        |> bin_inject_record()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      Ok(Some(#(guid, name, inject_record)))
    }
    ZfsCmdRes(zc: _, error: error, message: _, dst: None) if error == enoent ->
      Ok(None)
    res -> Error(error(res))
  }
}

pub type ZbookmarkPhys {
  ZbookmarkPhys(objset: Int, object: Int, level: Int, blkid: Int)
}

fn bin_bookmarks_impl(
  acc: List(ZbookmarkPhys),
  nr: Int,
  bin: BitArray,
) -> Option(List(ZbookmarkPhys)) {
  case nr, bin {
    0, <<>> -> Some(acc)
    n,
      <<
        objset:native-unsigned-size(64),
        object:native-unsigned-size(64),
        level:native-size(64),
        blkid:native-unsigned-size(64),
        rest:bytes,
      >>
      if n > 0
    ->
      bin_bookmarks_impl(
        [ZbookmarkPhys(objset, object, level, blkid), ..acc],
        n - 1,
        rest,
      )
    _, _ -> None
  }
}

const sizeof_zbookmark_phys = 256

fn bin_bookmarks(bin: BitArray) -> Option(List(ZbookmarkPhys)) {
  bin_bookmarks_impl([], bit_array.byte_size(bin) / sizeof_zbookmark_phys, bin)
}

pub fn error_log(
  hdl: Handle,
  name: String,
) -> Result(List(ZbookmarkPhys), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocErrorLog, req) {
    ZfsCmdRes(zc: _, error: 0, message: None, dst: Some(bookmarks_bin)) -> {
      let assert Some(bookmarks) = bin_bookmarks(bookmarks_bin)
      Ok(bookmarks)
    }
    res -> Error(error(res))
  }
}

const zpool_no_rewind = 1

pub fn clear(
  hdl: Handle,
  name: String,
  guid: Option(Int),
  rewind_policy: Option(NvList),
) -> Result(Option(NvList), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let no_rewind = option.is_none(rewind_policy)
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          opt(no_rewind, FieldValue(ZcCookie, int_uint64(zpool_no_rewind))),
          option.map(guid, fn(guid) { FieldValue(ZcGuid, int_uint64(guid)) }),
          Some(FieldValue(ZcNvlistDstSize, int_uint64(256 * 1024))),
        ]),
      ),
      history: None,
      src: option.map(rewind_policy, nvs.pack(_, nvs.Native)),
      conf: None,
    )
  case no_rewind {
    True -> ioctl_unit(hdl, ZfsIocClear, req) |> result.replace(None)
    False -> ioctl_nvlist(hdl, ZfsIocClear, req) |> result.map(Some)
  }
}

pub fn promote(hdl: Handle, name: String) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPromote,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn snapshot(
  hdl: Handle,
  name: String,
  snaps: NvList,
  props: Option(NvList),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let assert Some(packed_args) =
    nvlist_opt([
      Some(nvl.Nvlist("snaps", snaps)),
      option.map(props, nvl.Nvlist("props", _)),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_unit(
    hdl,
    ZfsIocSnapshot,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn ds_obj_to_ds_name(
  hdl: Handle,
  name: String,
  dsobj: Int,
) -> Result(String, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcObj, int_uint64(dsobj)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocDsObjToDsName, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) ->
      struct_read(zfs_cmd_t(), ZcValue, zc)
      |> str()
      |> result.replace_error(ErrorWithZfsCmd(zc))
    res -> Error(error(res))
  }
}

pub fn obj_to_path(
  hdl: Handle,
  name: String,
  obj: Int,
) -> Result(String, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcObj, int_uint64(obj)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocObjToPath, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) ->
      struct_read(zfs_cmd_t(), ZcValue, zc)
      |> str()
      |> result.replace_error(ErrorWithZfsCmd(zc))
    res -> Error(error(res))
  }
}

pub fn pool_set_props(
  hdl: Handle,
  name: String,
  props: NvList,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolSetProps,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: Some(nvs.pack(props, nvs.Native)),
      conf: None,
    ),
  )
}

pub fn pool_get_props(hdl: Handle, name: String) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_nvlist(
    hdl,
    ZfsIocPoolGetProps,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(256 * 1024)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn set_fsacl(
  hdl: Handle,
  name: String,
  un: Bool,
  acl: NvList,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocSetFsacl,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcPermAction, int(un) |> int_uint64()),
      ]),
      history: None,
      src: Some(nvs.pack(acl, nvs.Native)),
      conf: None,
    ),
  )
}

pub fn get_fsacl(hdl: Handle, name: String) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_nvlist(
    hdl,
    ZfsIocGetFsacl,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(2048)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn inherit_prop(
  hdl: Handle,
  name: String,
  prop: String,
  received: Bool,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  use value_field <- result.try(zfs_cmd_string_field(ZcValue, prop))
  ioctl_unit(
    hdl,
    ZfsIocInheritProp,
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          Some(value_field),
          opt(received, FieldValue(ZcCookie, int(True) |> int_uint64())),
        ]),
      ),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub type UserQuotaProp {
  UserUsed
  UserQuota
  GroupUsed
  GroupQuota
  UserObjUsed
  UserObjQuota
  GroupObjUsed
  GroupObjQuota
  ProjectUsed
  ProjectQuota
  ProjectObjUsed
  ProjectObjQuota
}

fn user_quota_prop_index(prop: UserQuotaProp) -> Int {
  case prop {
    UserUsed -> 0
    UserQuota -> 1
    GroupUsed -> 2
    GroupQuota -> 3
    UserObjUsed -> 4
    UserObjQuota -> 5
    GroupObjUsed -> 6
    GroupObjQuota -> 7
    ProjectUsed -> 8
    ProjectQuota -> 9
    ProjectObjUsed -> 10
    ProjectObjQuota -> 11
  }
}

pub fn user_space_one(
  hdl: Handle,
  name: String,
  prop: UserQuotaProp,
  domain: String,
  id: Int,
) -> Result(Int, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  use value_field <- result.try(zfs_cmd_string_field(ZcValue, domain))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcObjsetType, user_quota_prop_index(prop) |> int_uint64()),
        value_field,
        FieldValue(ZcGuid, int_uint64(id)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocUserSpaceOne, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) ->
      struct_read(zfs_cmd_t(), ZcCookie, zc)
      |> uint64_int()
      |> result.replace_error(ErrorWithZfsCmd(zc))
    res -> Error(error(res))
  }
}

pub type UserAcct {
  UserAcct(domain: String, rid: Int, space: Int)
}

fn bin_user_acct(bin: BitArray) -> Result(UserAcct, Nil) {
  case bin {
    <<
      domain_raw:bytes-size(256),
      rid:native-unsigned-size(32),
      _pad:size(32),
      space:native-unsigned-size(64),
    >> -> {
      let assert Ok(domain) = str(domain_raw)
      Ok(UserAcct(domain, rid, space))
    }
    _ -> Error(Nil)
  }
}

const sizeof_zfs_useracct_t = 272

fn bin_user_accts_impl(
  acc: List(UserAcct),
  n: Int,
  bin: BitArray,
) -> Result(List(UserAcct), Nil) {
  case n, bin {
    0, <<>> -> Ok(acc)
    _, <<user_acct_bin:bytes-size(sizeof_zfs_useracct_t), rest:bytes>> -> {
      use user_acct <- result.try(bin_user_acct(user_acct_bin))
      bin_user_accts_impl([user_acct, ..acc], n - 1, rest)
    }
    _, _ -> Error(Nil)
  }
}

fn bin_user_accts(bin: BitArray) -> Result(List(UserAcct), Nil) {
  bin_user_accts_impl([], bit_array.byte_size(bin) / sizeof_zfs_useracct_t, bin)
}

pub fn user_space_many(
  hdl: Handle,
  name: String,
  prop: UserQuotaProp,
  count: Int,
  cursor: Int,
) -> Result(#(Int, List(UserAcct)), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcCookie, int_uint64(cursor)),
        FieldValue(ZcObjsetType, user_quota_prop_index(prop) |> int_uint64()),
        FieldValue(ZcNvlistDstSize, int_uint64(count * sizeof_zfs_useracct_t)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocUserSpaceMany, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: Some(user_accts_bin)) -> {
      use cursor <- result.try(
        struct_read(zfs_cmd_t(), ZcCookie, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use user_accts <- result.try(
        bin_user_accts(user_accts_bin)
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      Ok(#(cursor, user_accts))
    }
    res -> Error(error(res))
  }
}

pub fn user_space_upgrade(hdl: Handle, name: String) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocUserSpaceUpgrade,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn hold(
  hdl: Handle,
  name: String,
  holds: NvList,
  cleanup_fd: Option(Int),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let assert Some(packed_args) =
    nvlist_opt([
      Some(nvl.Nvlist("holds", holds)),
      option.map(cleanup_fd, nvl.Int32("cleanup_fd", _)),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_unit(
    hdl,
    ZfsIocHold,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn release(hdl: Handle, name: String, holds: NvList) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_args = nvs.pack(holds, nvs.Native)
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_unit(
    hdl,
    ZfsIocRelease,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn get_holds(hdl: Handle, name: String) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_nvlist(
    hdl,
    ZfsIocGetHolds,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(128 * 1024)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn objset_recvd_props(hdl: Handle, name: String) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_nvlist(
    hdl,
    ZfsIocObjsetRecvdProps,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(256 * 1024)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub type VdevSplitFlag {
  ZpoolExportAfterSplit
}

fn vdev_split_flags_int(flags: List(VdevSplitFlag)) -> Int {
  list.fold(flags, 0, fn(acc, flag) {
    int.bitwise_or(acc, case flag {
      ZpoolExportAfterSplit -> 0x1
    })
  })
}

pub fn vdev_split(
  hdl: Handle,
  name: String,
  newname: String,
  conf: NvList,
  props: Option(NvList),
  flags: List(VdevSplitFlag),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  use string_field <- result.try(zfs_cmd_string_field(ZcString, newname))
  ioctl_unit(
    hdl,
    ZfsIocVdevSplit,
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          Some(string_field),
          case vdev_split_flags_int(flags) {
            0 -> None
            flags_int -> Some(FieldValue(ZcCookie, int_uint64(flags_int)))
          },
        ]),
      ),
      history: None,
      src: option.map(props, nvs.pack(_, nvs.Native)),
      conf: Some(nvs.pack(conf, nvs.Native)),
    ),
  )
}

pub fn next_obj(
  hdl: Handle,
  name: String,
  obj: Int,
) -> Result(Option(Int), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcObj, int_uint64(obj)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocNextObj, req) {
    ZfsCmdRes(zc: _, error: error, message: None, dst: None) if error == esrch ->
      Ok(None)
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) ->
      struct_read(zfs_cmd_t(), ZcObj, zc)
      |> uint64_int()
      |> result.map(Some)
      |> result.replace_error(ErrorWithZfsCmd(zc))
    res -> Error(error(res))
  }
}

pub fn diff(
  hdl: Handle,
  to: String,
  from: String,
  fd: Int,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, to))
  use value_field <- result.try(zfs_cmd_string_field(ZcValue, from))
  ioctl_unit(
    hdl,
    ZfsIocDiff,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        value_field,
        FieldValue(ZcCookie, int_uint64(fd)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn tmp_snapshot(
  hdl: Handle,
  name: String,
  prefix: String,
  cleanup_fd: Int,
) -> Result(String, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  use value_field <- result.try(zfs_cmd_string_field(ZcValue, prefix))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        value_field,
        FieldValue(ZcCleanupFd, int_int32(cleanup_fd)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocTmpSnapshot, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) ->
      struct_read(zfs_cmd_t(), ZcValue, zc)
      |> str()
      |> result.replace_error(ErrorWithZfsCmd(zc))
    res -> Error(error(res))
  }
}

pub type Stat {
  Stat(gen: Int, mode: Int, links: Int, ctime: #(Int, Int))
}

fn bin_stat(bin: BitArray) -> Result(Stat, Nil) {
  case bin {
    <<
      gen:native-unsigned-size(64),
      mode:native-unsigned-size(64),
      links:native-unsigned-size(64),
      ctime0:native-unsigned-size(64),
      ctime1:native-unsigned-size(64),
    >> -> Ok(Stat(gen, mode, links, #(ctime0, ctime1)))
    _ -> Error(Nil)
  }
}

pub fn obj_to_stats(
  hdl: Handle,
  name: String,
  obj: Int,
) -> Result(#(String, Stat), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcObj, int_uint64(obj)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocObjToStats, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) -> {
      let t = zfs_cmd_t()
      use path <- result.try(
        struct_read(t, ZcValue, zc)
        |> str()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use stat <- result.try(
        struct_read(t, ZcStat, zc)
        |> bin_stat()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      Ok(#(path, stat))
    }
    res -> Error(error(res))
  }
}

pub fn space_written(
  hdl: Handle,
  name: String,
  snap: String,
) -> Result(#(Int, Int, Int), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  use value_field <- result.try(zfs_cmd_string_field(ZcValue, snap))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        value_field,
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocSpaceWritten, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) -> {
      let t = zfs_cmd_t()
      use used <- result.try(
        struct_read(t, ZcCookie, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use compressed <- result.try(
        struct_read(t, ZcObjsetType, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use uncompressed <- result.try(
        struct_read(t, ZcPermAction, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      Ok(#(used, compressed, uncompressed))
    }
    res -> Error(error(res))
  }
}

pub fn space_snaps(
  hdl: Handle,
  name: String,
  firstsnap: String,
) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_args = nvlist([nvl.String("firstsnap", firstsnap)])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_nvlist(
    hdl,
    ZfsIocSpaceSnaps,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn destroy_snaps(
  hdl: Handle,
  name: String,
  snaps: NvList,
  defer: Bool,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let assert Some(packed_args) =
    nvlist_opt([
      Some(nvl.Nvlist("snaps", snaps)),
      opt(defer, nvl.Boolean("defer")),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_unit(
    hdl,
    ZfsIocDestroySnaps,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn pool_reguid(
  hdl: Handle,
  name: String,
  guid: Option(Int),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolReguid,
    ZfsCmdReq(
      zc: build_zfs_cmd(
        option.values([
          Some(name_field),
          option.map(guid, fn(guid) { FieldValue(ZcGuid, int_uint64(guid)) }),
        ]),
      ),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn pool_reopen(
  hdl: Handle,
  name: String,
  scrub_restart: Bool,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolReopen,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: nvlist_opt([
        opt(scrub_restart, nvl.BooleanValue("scrub_restart", True)),
      ]),
      conf: None,
    ),
  )
}

pub fn send_progress(
  hdl: Handle,
  name: String,
  fd: Int,
) -> Result(#(Int, Int), Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let req =
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcCookie, int_uint64(fd)),
      ]),
      history: None,
      src: None,
      conf: None,
    )
  case ioctl(hdl, ZfsIocSendProgress, req) {
    ZfsCmdRes(zc: zc, error: 0, message: None, dst: None) -> {
      let t = zfs_cmd_t()
      use written <- result.try(
        struct_read(t, ZcCookie, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      use traversed <- result.try(
        struct_read(t, ZcObjsetType, zc)
        |> uint64_int()
        |> result.replace_error(ErrorWithZfsCmd(zc)),
      )
      Ok(#(written, traversed))
    }
    res -> Error(error(res))
  }
}

pub fn log_history(hdl: Handle, message: String) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocLogHistory,
    ZfsCmdReq(
      zc: build_zfs_cmd([]),
      history: None,
      src: Some(nvlist([nvl.String("message", message)])),
      conf: None,
    ),
  )
}

pub fn send_new(
  hdl: Handle,
  tosnap: String,
  args: NvList,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, tosnap))
  ioctl_unit(
    hdl,
    ZfsIocSendNew,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: Some(nvs.pack(args, nvs.Native)),
      conf: None,
    ),
  )
}

pub fn send_space(
  hdl: Handle,
  tosnap: String,
  args: Option(NvList),
) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, tosnap))
  let opt_packed_args = option.map(args, nvs.pack(_, nvs.Native))
  let packed_args_size = case opt_packed_args {
    Some(packed_args) -> bit_array.byte_size(packed_args)
    None -> 0
  }
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_nvlist(
    hdl,
    ZfsIocSendSpace,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: opt_packed_args,
      conf: None,
    ),
  )
}

pub fn clone(
  hdl: Handle,
  name: String,
  origin: String,
  props: Option(NvList),
  hidden_args: Option(NvList),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let assert Some(packed_args) =
    nvlist_opt([
      Some(nvl.String("origin", origin)),
      option.map(props, nvl.Nvlist("props", _)),
      option.map(hidden_args, nvl.Nvlist("hidden_args", _)),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_unit(
    hdl,
    ZfsIocClone,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn bookmark(
  hdl: Handle,
  name: String,
  bookmarks: NvList,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_bookmarks = nvs.pack(bookmarks, nvs.Native)
  let packed_bookmarks_size = bit_array.byte_size(packed_bookmarks)
  let dst_size = int.max(128 * 1024, packed_bookmarks_size * 2)
  ioctl_unit(
    hdl,
    ZfsIocBookmark,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_bookmarks),
      conf: None,
    ),
  )
}

pub fn get_bookmarks(
  hdl: Handle,
  name: String,
  props: Option(NvList),
) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let opt_packed_args = option.map(props, nvs.pack(_, nvs.Native))
  let packed_args_size = case opt_packed_args {
    Some(packed_args) -> bit_array.byte_size(packed_args)
    None -> 0
  }
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_nvlist(
    hdl,
    ZfsIocGetBookmarks,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: opt_packed_args,
      conf: None,
    ),
  )
}

pub fn destroy_bookmarks(
  hdl: Handle,
  name: String,
  list: NvList,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_list = nvs.pack(list, nvs.Native)
  let packed_list_size = bit_array.byte_size(packed_list)
  let dst_size = int.max(128 * 1024, packed_list_size * 2)
  ioctl_unit(
    hdl,
    ZfsIocDestroyBookmarks,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_list),
      conf: None,
    ),
  )
}

pub fn recv_new(
  hdl: Handle,
  name: String,
  args: NvList,
) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_args = nvs.pack(args, nvs.Native)
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_nvlist(
    hdl,
    ZfsIocRecvNew,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn pool_sync(hdl: Handle, name: String, force: Bool) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolSync,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: Some(nvlist([nvl.BooleanValue("force", force)])),
      conf: None,
    ),
  )
}

pub fn channel_program(
  hdl: Handle,
  name: String,
  args: NvList,
  memlimit: Int,
) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_nvlist(
    hdl,
    ZfsIocChannelProgram,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(memlimit)),
      ]),
      history: None,
      src: Some(nvs.pack(args, nvs.Native)),
      conf: None,
    ),
  )
}

pub fn load_key(
  hdl: Handle,
  name: String,
  hidden_args: NvList,
  noop: Bool,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocLoadKey,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: nvlist_opt([
        Some(nvl.Nvlist("hidden_args", hidden_args)),
        opt(noop, nvl.Boolean("noop")),
      ]),
      conf: None,
    ),
  )
}

pub fn unload_key(hdl: Handle, name: String) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocUnloadKey,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn change_key(
  hdl: Handle,
  name: String,
  crypt_cmd: Option(Int),
  hidden_args: Option(NvList),
  props: Option(NvList),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocChangeKey,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: nvlist_opt([
        option.map(crypt_cmd, nvl.Uint64("crypt_cmd", _)),
        option.map(hidden_args, nvl.Nvlist("hidden_args", _)),
        option.map(props, nvl.Nvlist("props", _)),
      ]),
      conf: None,
    ),
  )
}

pub fn pool_checkpoint(hdl: Handle, name: String) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolCheckpoint,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub fn pool_discard_checkpoint(
  hdl: Handle,
  name: String,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolDiscardCheckpoint,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub type PoolInitializeFunc {
  PoolInitializeStart
  PoolInitializeCancel
  PoolInitializeSuspend
  PoolInitializeUninit
}

fn pool_initialize_func_index(func: PoolInitializeFunc) -> Int {
  case func {
    PoolInitializeStart -> 0
    PoolInitializeCancel -> 1
    PoolInitializeSuspend -> 2
    PoolInitializeUninit -> 3
  }
}

pub fn pool_initialize(
  hdl: Handle,
  name: String,
  command: PoolInitializeFunc,
  vdevs: NvList,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_args =
    nvlist([
      nvl.Uint64("initialize_command", pool_initialize_func_index(command)),
      nvl.Nvlist("initialize_vdevs", vdevs),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  // XXX: This ioctl is bugged and returns an nvlist for errors in success.
  result.replace(
    ioctl_nvlist(
      hdl,
      ZfsIocPoolInitialize,
      ZfsCmdReq(
        zc: build_zfs_cmd([
          name_field,
          FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
        ]),
        history: None,
        src: Some(packed_args),
        conf: None,
      ),
    ),
    Nil,
  )
}

pub type PoolTrimFunc {
  PoolTrimStart
  PoolTrimCancel
  PoolTrimSuspend
}

fn pool_trim_func_index(func: PoolTrimFunc) -> Int {
  case func {
    PoolTrimStart -> 0
    PoolTrimCancel -> 1
    PoolTrimSuspend -> 2
  }
}

pub fn pool_trim(
  hdl: Handle,
  name: String,
  command: PoolTrimFunc,
  vdevs: NvList,
  rate: Option(Int),
  secure: Option(Bool),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let assert Some(packed_args) =
    nvlist_opt([
      Some(nvl.Uint64("trim_command", pool_trim_func_index(command))),
      Some(nvl.Nvlist("trim_vdevs", vdevs)),
      option.map(rate, nvl.Uint64("trim_rate", _)),
      option.map(secure, nvl.BooleanValue("trim_secure", _)),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  // XXX: This ioctl is bugged and returns an nvlist for errors in success.
  result.replace(
    ioctl_nvlist(
      hdl,
      ZfsIocPoolTrim,
      ZfsCmdReq(
        zc: build_zfs_cmd([
          name_field,
          FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
        ]),
        history: None,
        src: Some(packed_args),
        conf: None,
      ),
    ),
    Nil,
  )
}

pub fn redact(
  hdl: Handle,
  name: String,
  bookname: String,
  snaps: NvList,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocRedact,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: Some(
        nvlist([
          nvl.String("bookname", bookname),
          nvl.Nvlist("snapnv", snaps),
        ]),
      ),
      conf: None,
    ),
  )
}

pub fn get_bookmark_props(hdl: Handle, name: String) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_nvlist(
    hdl,
    ZfsIocGetBookmarkProps,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(128 * 1024)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}

pub type ZpoolWaitActivity {
  ZpoolWaitCkptDiscard
  ZpoolWaitFree
  ZpoolWaitInitialize
  ZpoolWaitReplace
  ZpoolWaitRemove
  ZpoolWaitResilver
  ZpoolWaitScrub
  ZpoolWaitTrim
  ZpoolWaitRaidzExpand
}

fn zpool_wait_activity_index(act: ZpoolWaitActivity) -> Int {
  case act {
    ZpoolWaitCkptDiscard -> 0
    ZpoolWaitFree -> 1
    ZpoolWaitInitialize -> 2
    ZpoolWaitReplace -> 3
    ZpoolWaitRemove -> 4
    ZpoolWaitResilver -> 5
    ZpoolWaitScrub -> 6
    ZpoolWaitTrim -> 7
    ZpoolWaitRaidzExpand -> 8
  }
}

pub fn wait(
  hdl: Handle,
  name: String,
  activity: ZpoolWaitActivity,
  tag: Option(Int),
) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let assert Some(packed_args) =
    nvlist_opt([
      Some(nvl.Int32("wait_activity", zpool_wait_activity_index(activity))),
      option.map(tag, nvl.Uint64("wait_tag", _)),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_nvlist(
    hdl,
    ZfsIocWait,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub type ZfsWaitActivity {
  ZfsWaitDeleteQ
}

fn zfs_wait_activity_index(act: ZfsWaitActivity) -> Int {
  case act {
    ZfsWaitDeleteQ -> 0
  }
}

pub fn wait_fs(
  hdl: Handle,
  name: String,
  activity: ZfsWaitActivity,
) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_args =
    nvlist([
      nvl.Int32("wait_activity", zfs_wait_activity_index(activity)),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_nvlist(
    hdl,
    ZfsIocWaitFs,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn vdev_get_props(
  hdl: Handle,
  name: String,
  vdev: Int,
  props: Option(NvList),
) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let assert Some(packed_args) =
    nvlist_opt([
      Some(nvl.Uint64("vdevprops_get_vdev", vdev)),
      option.map(props, nvl.Nvlist("vdevprops_get_props", _)),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_nvlist(
    hdl,
    ZfsIocVdevGetProps,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn vdev_set_props(
  hdl: Handle,
  name: String,
  vdev: Int,
  props: NvList,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  let packed_args =
    nvlist([
      nvl.Uint64("vdevprops_set_vdev", vdev),
      nvl.Nvlist("vdevprops_set_props", props),
    ])
  let packed_args_size = bit_array.byte_size(packed_args)
  let dst_size = int.max(128 * 1024, packed_args_size * 2)
  ioctl_unit(
    hdl,
    ZfsIocVdevSetProps,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(dst_size)),
      ]),
      history: None,
      src: Some(packed_args),
      conf: None,
    ),
  )
}

pub fn pool_scrub(
  hdl: Handle,
  name: String,
  scan_type: PoolScanFunc,
  scan_command: PoolScrubCmd,
  date_start: Option(Int),
  date_end: Option(Int),
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolScrub,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: nvlist_opt([
        Some(nvl.Uint64("scan_type", scan_func_index(scan_type))),
        Some(nvl.Uint64("scan_command", scrub_cmd_index(scan_command))),
        option.map(date_start, nvl.Uint64("scan_date_start", _)),
        option.map(date_end, nvl.Uint64("scan_date_end", _)),
      ]),
      conf: None,
    ),
  )
}

pub type ZpoolPrefetchType {
  ZpoolPrefetchNone
  ZpoolPrefetchDdt
  ZpoolPrefetchBrt
}

fn zpool_prefetch_type_index(prefetch: ZpoolPrefetchType) -> Int {
  case prefetch {
    ZpoolPrefetchNone -> 0
    ZpoolPrefetchDdt -> 1
    ZpoolPrefetchBrt -> 2
  }
}

pub fn pool_prefetch(
  hdl: Handle,
  name: String,
  prefetch: ZpoolPrefetchType,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocPoolPrefetch,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: Some(
        nvlist([
          nvl.Int32("prefetch_type", zpool_prefetch_type_index(prefetch)),
        ]),
      ),
      conf: None,
    ),
  )
}

pub type ZpoolDdtPruneUnit {
  ZpoolDdtPruneNone
  ZpoolDdtPruneAge
  ZpoolDdtPrunePercentage
}

fn zpool_ddt_prune_unit_index(unit: ZpoolDdtPruneUnit) -> Int {
  case unit {
    ZpoolDdtPruneNone -> 0
    ZpoolDdtPruneAge -> 1
    ZpoolDdtPrunePercentage -> 2
  }
}

pub fn ddt_prune(
  hdl: Handle,
  name: String,
  unit: ZpoolDdtPruneUnit,
  amount: Int,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocDdtPrune,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: Some(
        nvlist([
          nvl.Int32("ddt_prune_unit", zpool_ddt_prune_unit_index(unit)),
          nvl.Uint64("ddt_prune_amount", amount),
        ]),
      ),
      conf: None,
    ),
  )
}

pub fn nextboot(
  hdl: Handle,
  command: String,
  pool_guid: Int,
  guid: Int,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocNextBoot,
    ZfsCmdReq(
      zc: build_zfs_cmd([]),
      history: None,
      src: Some(
        nvlist([
          nvl.String("command", command),
          nvl.Uint64("pool_guid", pool_guid),
          nvl.Uint64("guid", guid),
        ]),
      ),
      conf: None,
    ),
  )
}

pub fn jail(hdl: Handle, name: String, jid: Int) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocJail,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: Some(nvlist([nvl.Uint64("zoneid", jid)])),
      conf: None,
    ),
  )
}

pub fn unjail(hdl: Handle, name: String, jid: Int) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocUnjail,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: Some(nvlist([nvl.Uint64("zoneid", jid)])),
      conf: None,
    ),
  )
}

pub type BootEnvConfig {
  BootEnvRaw(String)
  BootEnvNvlist(NvList)
}

pub fn set_boot_env(
  hdl: Handle,
  name: String,
  config: BootEnvConfig,
) -> Result(Nil, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_unit(
    hdl,
    ZfsIocSetBootEnv,
    ZfsCmdReq(
      zc: build_zfs_cmd([name_field]),
      history: None,
      src: Some(case config {
        BootEnvRaw(grub_envmap) ->
          nvlist([
            nvl.Uint64("version", 0),
            nvl.String("grub:envmap", grub_envmap),
          ])
        BootEnvNvlist(cfg) -> nvs.pack(cfg, nvs.Native)
      }),
      conf: None,
    ),
  )
}

pub fn get_boot_env(hdl: Handle, name: String) -> Result(NvList, Error) {
  use name_field <- result.try(zfs_cmd_string_field(ZcName, name))
  ioctl_nvlist(
    hdl,
    ZfsIocGetBootEnv,
    ZfsCmdReq(
      zc: build_zfs_cmd([
        name_field,
        FieldValue(ZcNvlistDstSize, int_uint64(128 * 1024)),
      ]),
      history: None,
      src: None,
      conf: None,
    ),
  )
}
