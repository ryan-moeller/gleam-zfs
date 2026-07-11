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
    <<s:bytes-size(len), 0:size(8), _:bytes>> -> bit_array.to_string(s)
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

pub type Error {
  InternalError
  ErrorCode(code: Int)
  ErrorMessage(code: Int, message: String)
  ErrorInfo(code: Int, info: NvList)
  ErrorMessageWithInfo(code: Int, message: String, info: NvList)
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

type ZfsCmdReq {
  ZfsCmdReq(name: Option(String), data: List(BitArray))
}

// TODO: The result interface needs further refinement.  Right now it is close
// to the previous ErlIOVec-based interface, but with terms we are able to build
// the final result term directly in the driver.  That would eliminate the error
// handling code below.
//
// For now, the driver returns our command response type wrapped in a Result,
// where Ok means the request was structurally valid and ioctl was invoked,
// while Error means the request was malformed and ioctl could not be invoked.

type ZfsCmdRes {
  ZfsCmdRes(error: Int, msg: Option(String), data: List(BitArray))
}

fn ioctl(hdl: Handle, ioc: ZfsIoc, req: ZfsCmdReq) -> ZfsCmdRes {
  let assert Ok(res) = port_call(hdl.inner, zfsioc_index(ioc), req)
  res
}

fn error(res: ZfsCmdRes) -> Error {
  assert res.error != 0
  case res {
    ZfsCmdRes(error: error, msg: Some(msg), data: []) ->
      ErrorMessage(error, msg)
    ZfsCmdRes(error: error, msg: None, data: [packed_info]) -> {
      let assert Ok(#(info, <<>>)) = nvs.unpack(packed_info)
      ErrorInfo(error, info)
    }
    ZfsCmdRes(error: error, msg: Some(msg), data: [packed_info]) -> {
      let assert Ok(#(info, <<>>)) = nvs.unpack(packed_info)
      ErrorMessageWithInfo(error, msg, info)
    }
    _ -> InternalError
  }
}

fn ioctl_unit(hdl: Handle, ioc: ZfsIoc, req: ZfsCmdReq) -> Result(Nil, Error) {
  case ioctl(hdl, ioc, req) {
    ZfsCmdRes(error: 0, msg: None, data: []) -> Ok(Nil)
    ZfsCmdRes(error: 0, msg: None, data: [packed]) -> {
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
    ZfsCmdRes(error: 0, msg: None, data: [packed]) -> {
      let assert Ok(#(nvl, <<>>)) = nvs.unpack(packed)
      Ok(nvl)
    }
    res -> Error(error(res))
  }
}

fn ioctl_stats_list_next(
  hdl: Handle,
  ioc: ZfsIoc,
  simple: Bool,
  req: ZfsCmdReq,
) -> Result(Option(#(String, Int, ObjsetStats, Option(NvList))), Error) {
  case ioctl(hdl, ioc, req) {
    ZfsCmdRes(error: 0, msg: None, data: []) -> Ok(None)
    ZfsCmdRes(error: 0, msg: None, data: data) -> {
      use #(results, config) <- result.try(case data {
        [packed_results, packed_config] -> {
          assert !simple
          let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
          let assert Ok(#(config, <<>>)) = nvs.unpack(packed_config)
          Ok(#(results, Some(config)))
        }
        [packed_results] -> {
          assert simple
          let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
          Ok(#(results, None))
        }
        _ -> Error(InternalError)
      })
      let assert Some(nvl.String(_, next_name)) = nvl.lookup(results, "name")
      let assert Some(nvl.Uint64(_, next_cookie)) =
        nvl.lookup(results, "cookie")
      let assert Some(nvl.ByteArray(_, objset_stats_bin)) =
        nvl.lookup(results, "objset_stats")
      let assert Some(objset_stats) = bin_objset_stats(objset_stats_bin)
      Ok(Some(#(next_name, next_cookie, objset_stats, config)))
    }
    res -> Error(error(res))
  }
}

pub fn pool_create(
  hdl: Handle,
  name: String,
  config: NvList,
  props: Option(NvList),
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocPoolCreate,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        Some(nvs.pack(config, nvs.Native)),
        option.map(props, nvs.pack(_, nvs.Native)),
      ]),
    ),
  )
}

pub fn pool_destroy(
  hdl: Handle,
  name: String,
  history: Option(String),
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocPoolDestroy,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([option.map(history, nvl.String("history", _))]),
      ]),
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
  ioctl_nvlist(
    hdl,
    ZfsIocPoolImport,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        Some(
          nvlist([
            nvl.Uint64("cookie", import_flags_int(flags)),
            nvl.Uint64("guid", guid),
          ]),
        ),
        Some(nvs.pack(config, nvs.Native)),
        option.map(props, nvs.pack(_, nvs.Native)),
      ]),
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
  let assert Some(params) =
    nvlist_opt([
      Some(nvl.Uint64("cookie", int(force))),
      Some(nvl.Uint64("guid", int(hardforce))),
      option.map(history, nvl.String("history", _)),
    ])
  ioctl_unit(hdl, ZfsIocPoolExport, ZfsCmdReq(Some(name), data: [params]))
}

pub fn pool_configs(hdl: Handle, ns_gen: Int) -> Result(#(Int, NvList), Error) {
  let req =
    ZfsCmdReq(None, data: [
      nvlist([nvl.Uint64("cookie", ns_gen)]),
    ])
  case ioctl(hdl, ZfsIocPoolConfigs, req) {
    ZfsCmdRes(error: 0, msg: None, data: [packed_results, packed_configs]) -> {
      let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
      let assert Ok(#(configs, <<>>)) = nvs.unpack(packed_configs)
      let assert Some(nvl.Uint64(_, ns_gen)) = nvl.lookup(results, "cookie")
      Ok(#(ns_gen, configs))
    }
    res -> Error(error(res))
  }
}

pub fn pool_stats(
  hdl: Handle,
  name: String,
) -> Result(#(Option(NvList), Option(String), Option(Int)), Error) {
  case ioctl(hdl, ZfsIocPoolStats, ZfsCmdReq(Some(name), [])) {
    ZfsCmdRes(error: 0, msg: None, data: [packed_results, packed_config]) -> {
      let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
      let assert Some(nvl.Uint64(_, error)) = nvl.lookup(results, "cookie")
      let assert Some(nvl.String(_, altroot)) = nvl.lookup(results, "value")
      let assert Ok(#(config, <<>>)) = nvs.unpack(packed_config)
      Ok(
        #(
          Some(config),
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
    ZfsCmdRes(error: error, msg: None, data: [packed_results]) -> {
      let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
      let assert Some(nvl.String(_, altroot)) = nvl.lookup(results, "value")
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
  ioctl_nvlist(
    hdl,
    ZfsIocPoolTryImport,
    ZfsCmdReq(None, data: [nvs.pack(config, nvs.Native)]),
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
  ioctl_unit(
    hdl,
    ZfsIocPoolScan,
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Uint64("cookie", scan_func_index(func)),
        nvl.Uint32("flags", scrub_cmd_index(cmd)),
      ]),
    ]),
  )
}

pub fn pool_freeze(hdl: Handle, name: String) -> Result(Nil, Error) {
  ioctl_unit(hdl, ZfsIocPoolFreeze, ZfsCmdReq(Some(name), []))
}

pub fn pool_upgrade(
  hdl: Handle,
  name: String,
  version: Int,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocPoolUpgrade,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("cookie", version)]),
    ]),
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
  let req =
    ZfsCmdReq(Some(name), [
      nvlist([nvl.Uint64("history_offset", offset)]),
    ])
  case ioctl(hdl, ZfsIocPoolGetHistory, req) {
    ZfsCmdRes(
      error: 0,
      msg: None,
      data: [<<new_offset:native-size(64), history_chunk:bytes>>],
    ) ->
      case split_history([], history_chunk) {
        Ok(history) -> Ok(#(history, new_offset))
        Error(Nil) -> Error(InternalError)
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
  ioctl_unit(
    hdl,
    ZfsIocVdevAdd,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([opt(check_ashift, nvl.Uint32("flags", int(True)))]),
        Some(nvs.pack(config, nvs.Native)),
      ]),
    ),
  )
}

pub fn vdev_remove(hdl: Handle, name: String, guid: Int) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocVdevRemove,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("guid", guid)]),
    ]),
  )
}

pub fn vdev_remove_cancel(hdl: Handle, name: String) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocVdevRemove,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("cookie", int(True))]),
    ]),
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
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocVdevSetState,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.Uint64("guid", guid)),
          Some(nvl.Uint64("cookie", vdev_state_index(state))),
          option.map(flags, nvl.Uint64("obj", _)),
        ]),
      ]),
    ),
  ))
  let assert Some(nvl.Uint64(_, newstate)) = nvl.lookup(results, "cookie")
  let assert Some(newstate) = index_vdev_state(newstate)
  Ok(newstate)
}

pub fn vdev_attach(
  hdl: Handle,
  name: String,
  guid: Int,
  config: NvList,
  replacing: Bool,
  rebuild: Bool,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocVdevAttach,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          opt(replacing, nvl.Uint64("cookie", int(True))),
          Some(nvl.Uint64("guid", guid)),
          opt(rebuild, nvl.Uint8("simple", int(True))),
        ]),
        Some(nvs.pack(config, nvs.Native)),
      ]),
    ),
  )
}

pub fn vdev_detach(hdl: Handle, name: String, guid: Int) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocVdevDetach,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("guid", guid)]),
    ]),
  )
}

pub fn vdev_set_path(
  hdl: Handle,
  name: String,
  guid: Int,
  path: String,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocVdevSetPath,
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Uint64("guid", guid),
        nvl.String("value", path),
      ]),
    ]),
  )
}

pub fn vdev_set_fru(
  hdl: Handle,
  name: String,
  guid: Int,
  fru: String,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocVdevSetFru,
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Uint64("guid", guid),
        nvl.String("value", fru),
      ]),
    ]),
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

// TODO: This should live elsewhere
pub const zfs_max_dataset_name_len = 256

fn bin_objset_stats(bin: BitArray) -> Option(ObjsetStats) {
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
      Some(ObjsetStats(
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
    _ -> None
  }
}

pub fn objset_stats(
  hdl: Handle,
  name: String,
  simple: Bool,
) -> Result(#(ObjsetStats, Option(NvList)), Error) {
  let req =
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint8("simple", int(simple))]),
    ])
  case ioctl(hdl, ZfsIocObjsetStats, req) {
    ZfsCmdRes(error: 0, msg: None, data: [packed_results, packed_props]) -> {
      assert !simple
      let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
      let assert Ok(#(props, <<>>)) = nvs.unpack(packed_props)
      let assert Some(nvl.ByteArray(_, stats_bin)) =
        nvl.lookup(results, "objset_stats")
      let assert Some(objset_stats) = bin_objset_stats(stats_bin)
      Ok(#(objset_stats, Some(props)))
    }
    ZfsCmdRes(error: 0, msg: None, data: [packed_results]) -> {
      assert simple
      let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
      let assert Some(nvl.ByteArray(_, stats_bin)) =
        nvl.lookup(results, "objset_stats")
      let assert Some(objset_stats) = bin_objset_stats(stats_bin)
      Ok(#(objset_stats, None))
    }
    res -> Error(error(res))
  }
}

pub fn objset_zpl_props(hdl: Handle, name: String) -> Result(NvList, Error) {
  ioctl_nvlist(hdl, ZfsIocObjsetZplProps, ZfsCmdReq(Some(name), []))
}

pub fn dataset_list_next(
  hdl: Handle,
  name: String,
  simple: Bool,
  cookie: Int,
) -> Result(Option(#(String, Int, ObjsetStats, Option(NvList))), Error) {
  ioctl_stats_list_next(
    hdl,
    ZfsIocDatasetListNext,
    simple,
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Uint8("simple", int(simple)),
        nvl.Uint64("cookie", cookie),
      ]),
    ]),
  )
}

pub fn snapshot_list_next(
  hdl: Handle,
  name: String,
  simple: Bool,
  cookie: Int,
) -> Result(Option(#(String, Int, ObjsetStats, Option(NvList))), Error) {
  ioctl_stats_list_next(
    hdl,
    ZfsIocSnapshotListNext,
    simple,
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Uint8("simple", int(simple)),
        nvl.Uint64("cookie", cookie),
      ]),
    ]),
  )
}

pub fn set_prop(
  hdl: Handle,
  name: String,
  props: NvList,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocSetProp,
    ZfsCmdReq(Some(name), data: [nvs.pack(props, nvs.Native)]),
  )
}

pub fn create(
  hdl: Handle,
  name: String,
  objset_type: ObjsetType,
  props: Option(NvList),
  hidden_args: Option(NvList),
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocCreate,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.Int32("type", objset_type_index(objset_type))),
          option.map(props, nvl.Nvlist("props", _)),
          option.map(hidden_args, nvl.Nvlist("hidden_args", _)),
        ]),
      ]),
    ),
  )
}

pub fn destroy(hdl: Handle, name: String, defer: Bool) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocDestroy,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([opt(defer, nvl.Uint32("defer_destroy", int(True)))]),
      ]),
    ),
  )
}

pub fn rollback(
  hdl: Handle,
  name: String,
  target: Option(String),
) -> Result(String, Error) {
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocRollback,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([option.map(target, nvl.String("target", _))]),
      ]),
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
  ioctl_unit(
    hdl,
    ZfsIocRename,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.String("value", newname)),
          case flags {
            [] -> None
            _ -> Some(nvl.Uint64("cookie", rename_flags_int(flags)))
          },
        ]),
      ]),
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

const maxnamelen = 256

fn bin_inject_record(bin: BitArray) -> Option(InjectRecord) {
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
      Some(InjectRecord(
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
    _ -> None
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
  let req =
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Uint64("guid", zinject_flags_int(flags)),
        nvl.ByteArray("inject_record", inject_record_bin(record)),
      ]),
    ])
  use results <- result.try(ioctl_nvlist(hdl, ZfsIocInjectFault, req))
  let assert Some(nvl.Uint64(_, guid)) = nvl.lookup(results, "guid")
  Ok(guid)
}

pub fn clear_fault(hdl: Handle, guid: Int) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocClearFault,
    ZfsCmdReq(None, data: [nvlist([nvl.Uint64("guid", guid)])]),
  )
}

pub fn inject_list_next(
  hdl: Handle,
  guid: Int,
) -> Result(Option(#(Int, String, InjectRecord)), Error) {
  let req =
    ZfsCmdReq(None, data: [
      nvlist([nvl.Uint64("guid", guid)]),
    ])
  case ioctl(hdl, ZfsIocInjectListNext, req) {
    ZfsCmdRes(error: 0, msg: None, data: [packed_results]) -> {
      let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
      let assert Some(nvl.Uint64(_, guid)) = nvl.lookup(results, "guid")
      let assert Some(nvl.String(_, name)) = nvl.lookup(results, "name")
      let assert Some(nvl.ByteArray(_, inject_record_bin)) =
        nvl.lookup(results, "inject_record")
      let assert Some(inject_record) = bin_inject_record(inject_record_bin)
      Ok(Some(#(guid, name, inject_record)))
    }
    // ENOENT
    ZfsCmdRes(error: 2, msg: _, data: []) -> Ok(None)
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
  case ioctl(hdl, ZfsIocErrorLog, ZfsCmdReq(Some(name), [])) {
    ZfsCmdRes(error: 0, msg: None, data: [bookmarks_bin]) -> {
      let assert Some(bookmarks) = bin_bookmarks(bookmarks_bin)
      Ok(bookmarks)
    }
    res -> Error(error(res))
  }
}

pub fn clear(
  hdl: Handle,
  name: String,
  guid: Option(Int),
  rewind_policy: Option(NvList),
) -> Result(Option(NvList), Error) {
  // XXX: Always send a params nvlist to avoid ambiguity.
  let params = nvlist([nvl.Uint64("guid", option.unwrap(guid, 0))])
  case rewind_policy {
    Some(policy) -> {
      use config <- result.try(ioctl_nvlist(
        hdl,
        ZfsIocClear,
        ZfsCmdReq(Some(name), data: [
          params,
          nvs.pack(policy, nvs.Native),
        ]),
      ))
      Ok(Some(config))
    }
    None -> {
      use Nil <- result.try(ioctl_unit(
        hdl,
        ZfsIocClear,
        ZfsCmdReq(Some(name), data: [params]),
      ))
      Ok(None)
    }
  }
}

pub fn promote(hdl: Handle, name: String) -> Result(Nil, Error) {
  ioctl_unit(hdl, ZfsIocPromote, ZfsCmdReq(Some(name), []))
}

pub fn snapshot(
  hdl: Handle,
  name: String,
  snaps: NvList,
  props: Option(NvList),
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocSnapshot,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.Nvlist("snaps", snaps)),
          option.map(props, nvl.Nvlist("props", _)),
        ]),
      ]),
    ),
  )
}

pub fn ds_obj_to_ds_name(
  hdl: Handle,
  name: String,
  dsobj: Int,
) -> Result(String, Error) {
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocDsObjToDsName,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("obj", dsobj)]),
    ]),
  ))
  let assert Some(nvl.String(_, dsname)) = nvl.lookup(results, "value")
  Ok(dsname)
}

pub fn obj_to_path(
  hdl: Handle,
  name: String,
  obj: Int,
) -> Result(String, Error) {
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocObjToPath,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("obj", obj)]),
    ]),
  ))
  let assert Some(nvl.String(_, path)) = nvl.lookup(results, "value")
  Ok(path)
}

pub fn pool_set_props(
  hdl: Handle,
  name: String,
  props: NvList,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocPoolSetProps,
    ZfsCmdReq(Some(name), data: [
      nvs.pack(props, nvs.Native),
    ]),
  )
}

pub fn pool_get_props(hdl: Handle, name: String) -> Result(NvList, Error) {
  ioctl_nvlist(hdl, ZfsIocPoolGetProps, ZfsCmdReq(Some(name), []))
}

pub fn set_fsacl(
  hdl: Handle,
  name: String,
  un: Bool,
  acl: NvList,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocSetFsacl,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("perm_action", int(un))]),
      nvs.pack(acl, nvs.Native),
    ]),
  )
}

pub fn get_fsacl(hdl: Handle, name: String) -> Result(NvList, Error) {
  ioctl_nvlist(hdl, ZfsIocGetFsacl, ZfsCmdReq(Some(name), []))
}

pub fn inherit_prop(
  hdl: Handle,
  name: String,
  prop: String,
  received: Bool,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocInheritProp,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.String("value", prop)),
          opt(received, nvl.Uint64("cookie", int(True))),
        ]),
      ]),
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
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocUserSpaceOne,
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Uint64("objset_type", user_quota_prop_index(prop)),
        nvl.Uint64("guid", id),
        nvl.String("value", domain),
      ]),
    ]),
  ))
  let assert Some(nvl.Uint64(_, space)) = nvl.lookup(results, "cookie")
  Ok(space)
}

pub type UserAcct {
  UserAcct(domain: String, rid: Int, space: Int)
}

fn bin_user_acct(bin: BitArray) -> Option(UserAcct) {
  case bin {
    <<
      domain_raw:bytes-size(256),
      rid:native-unsigned-size(32),
      _pad:size(32),
      space:native-unsigned-size(64),
    >> -> {
      let assert Ok(domain) = str(domain_raw)
      Some(UserAcct(domain, rid, space))
    }
    _ -> None
  }
}

const sizeof_zfs_useracct_t = 272

fn bin_user_accts_impl(
  acc: List(UserAcct),
  n: Int,
  bin: BitArray,
) -> Option(List(UserAcct)) {
  case n, bin {
    0, <<>> -> Some(acc)
    _, <<user_acct_bin:bytes-size(sizeof_zfs_useracct_t), rest:bytes>> -> {
      use user_acct <- option.then(bin_user_acct(user_acct_bin))
      bin_user_accts_impl([user_acct, ..acc], n - 1, rest)
    }
    _, _ -> None
  }
}

fn bin_user_accts(bin: BitArray) -> Option(List(UserAcct)) {
  bin_user_accts_impl([], bit_array.byte_size(bin) / sizeof_zfs_useracct_t, bin)
}

pub fn user_space_many(
  hdl: Handle,
  name: String,
  prop: UserQuotaProp,
  count: Int,
  cursor: Int,
) -> Result(#(Int, List(UserAcct)), Error) {
  let req =
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Uint64("cookie", cursor),
        nvl.Uint64("objset_type", user_quota_prop_index(prop)),
        nvl.Uint64("nvlist_dst_size", count * sizeof_zfs_useracct_t),
      ]),
    ])
  case ioctl(hdl, ZfsIocUserSpaceMany, req) {
    ZfsCmdRes(error: 0, msg: None, data: [packed_results, user_accts_bin]) -> {
      let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
      let assert Some(nvl.Uint64(_, cursor)) = nvl.lookup(results, "cookie")
      let assert Some(user_accts) = bin_user_accts(user_accts_bin)
      Ok(#(cursor, user_accts))
    }
    res -> Error(error(res))
  }
}

pub fn user_space_upgrade(hdl: Handle, name: String) -> Result(Nil, Error) {
  ioctl_unit(hdl, ZfsIocUserSpaceUpgrade, ZfsCmdReq(Some(name), []))
}

pub fn hold(
  hdl: Handle,
  name: String,
  holds: NvList,
  cleanup_fd: Option(Int),
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocHold,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.Nvlist("holds", holds)),
          option.map(cleanup_fd, nvl.Int32("cleanup_fd", _)),
        ]),
      ]),
    ),
  )
}

pub fn release(hdl: Handle, name: String, holds: NvList) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocRelease,
    ZfsCmdReq(Some(name), data: [nvs.pack(holds, nvs.Native)]),
  )
}

pub fn get_holds(hdl: Handle, name: String) -> Result(NvList, Error) {
  ioctl_nvlist(hdl, ZfsIocGetHolds, ZfsCmdReq(Some(name), []))
}

pub fn objset_recvd_props(hdl: Handle, name: String) -> Result(NvList, Error) {
  ioctl_nvlist(hdl, ZfsIocObjsetRecvdProps, ZfsCmdReq(Some(name), []))
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
  ioctl_unit(
    hdl,
    ZfsIocVdevSplit,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.String("string", newname)),
          case vdev_split_flags_int(flags) {
            0 -> None
            flags_int -> Some(nvl.Uint64("cookie", flags_int))
          },
        ]),
        Some(nvs.pack(conf, nvs.Native)),
        option.map(props, nvs.pack(_, nvs.Native)),
      ]),
    ),
  )
}

pub fn next_obj(
  hdl: Handle,
  name: String,
  obj: Int,
) -> Result(Option(Int), Error) {
  let req =
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("obj", obj)]),
    ])
  case ioctl(hdl, ZfsIocNextObj, req) {
    ZfsCmdRes(error: 0, msg: None, data: []) -> Ok(None)
    ZfsCmdRes(error: 0, msg: None, data: [packed_results]) -> {
      let assert Ok(#(results, <<>>)) = nvs.unpack(packed_results)
      let assert Some(nvl.Uint64(_, next)) = nvl.lookup(results, "obj")
      Ok(Some(next))
    }
    res -> Error(error(res))
  }
}

pub fn diff(
  hdl: Handle,
  to: String,
  from: String,
  fd: Int,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocDiff,
    ZfsCmdReq(Some(to), data: [
      nvlist([
        nvl.String("value", from),
        nvl.Uint64("cookie", fd),
      ]),
    ]),
  )
}

pub fn tmp_snapshot(
  hdl: Handle,
  name: String,
  prefix: String,
  cleanup_fd: Int,
) -> Result(String, Error) {
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocTmpSnapshot,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.String("value", prefix), nvl.Int32("cleanup_fd", cleanup_fd)]),
    ]),
  ))
  let assert Some(nvl.String(_, snapname)) = nvl.lookup(results, "value")
  Ok(snapname)
}

pub type Stat {
  Stat(gen: Int, mode: Int, links: Int, ctime: #(Int, Int))
}

fn bin_stat(bin: BitArray) -> Option(Stat) {
  case bin {
    <<
      gen:native-unsigned-size(64),
      mode:native-unsigned-size(64),
      links:native-unsigned-size(64),
      ctime0:native-unsigned-size(64),
      ctime1:native-unsigned-size(64),
    >> -> Some(Stat(gen, mode, links, #(ctime0, ctime1)))
    _ -> None
  }
}

pub fn obj_to_stats(
  hdl: Handle,
  name: String,
  obj: Int,
) -> Result(#(String, Stat), Error) {
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocObjToStats,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("obj", obj)]),
    ]),
  ))
  let assert Some(nvl.String(_, path)) = nvl.lookup(results, "value")
  let assert Some(nvl.ByteArray(_, stat_bin)) = nvl.lookup(results, "stat")
  let assert Some(stat) = bin_stat(stat_bin)
  Ok(#(path, stat))
}

pub fn space_written(
  hdl: Handle,
  name: String,
  snap: String,
) -> Result(#(Int, Int, Int), Error) {
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocSpaceWritten,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.String("value", snap)]),
    ]),
  ))
  let assert Some(nvl.Uint64(_, used)) = nvl.lookup(results, "cookie")
  let assert Some(nvl.Uint64(_, compressed)) =
    nvl.lookup(results, "objset_type")
  let assert Some(nvl.Uint64(_, uncompressed)) =
    nvl.lookup(results, "perm_action")
  Ok(#(used, compressed, uncompressed))
}

pub fn space_snaps(
  hdl: Handle,
  name: String,
  firstsnap: String,
) -> Result(NvList, Error) {
  ioctl_nvlist(
    hdl,
    ZfsIocSpaceSnaps,
    ZfsCmdReq(Some(name), data: [nvlist([nvl.String("firstsnap", firstsnap)])]),
  )
}

pub fn destroy_snaps(
  hdl: Handle,
  name: String,
  snaps: NvList,
  defer: Bool,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocDestroySnaps,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.Nvlist("snaps", snaps)),
          opt(defer, nvl.Boolean("defer")),
        ]),
      ]),
    ),
  )
}

pub fn pool_reguid(
  hdl: Handle,
  name: String,
  guid: Option(Int),
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocPoolReguid,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          option.map(guid, nvl.Uint64("guid", _)),
        ]),
      ]),
    ),
  )
}

pub fn pool_reopen(
  hdl: Handle,
  name: String,
  scrub_restart: Bool,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocPoolReopen,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          opt(scrub_restart, nvl.BooleanValue("scrub_restart", True)),
        ]),
      ]),
    ),
  )
}

pub fn send_progress(
  hdl: Handle,
  name: String,
  fd: Int,
) -> Result(#(Int, Int), Error) {
  use results <- result.try(ioctl_nvlist(
    hdl,
    ZfsIocSendProgress,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("cookie", fd)]),
    ]),
  ))
  let assert Some(nvl.Uint64(_, written)) = nvl.lookup(results, "cookie")
  let assert Some(nvl.Uint64(_, traversed)) = nvl.lookup(results, "objset_type")
  Ok(#(written, traversed))
}

pub fn log_history(hdl: Handle, message: String) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocLogHistory,
    ZfsCmdReq(None, data: [nvlist([nvl.String("message", message)])]),
  )
}

pub fn send_new(
  hdl: Handle,
  tosnap: String,
  args: NvList,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocSendNew,
    ZfsCmdReq(Some(tosnap), data: [nvs.pack(args, nvs.Native)]),
  )
}

pub fn send_space(
  hdl: Handle,
  tosnap: String,
  args: Option(NvList),
) -> Result(NvList, Error) {
  ioctl_nvlist(
    hdl,
    ZfsIocSendSpace,
    ZfsCmdReq(
      Some(tosnap),
      data: option.values([option.map(args, nvs.pack(_, nvs.Native))]),
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
  ioctl_unit(
    hdl,
    ZfsIocClone,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.String("origin", origin)),
          option.map(props, nvl.Nvlist("props", _)),
          option.map(hidden_args, nvl.Nvlist("hidden_args", _)),
        ]),
      ]),
    ),
  )
}

pub fn bookmark(
  hdl: Handle,
  name: String,
  bookmarks: NvList,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocBookmark,
    ZfsCmdReq(Some(name), data: [nvs.pack(bookmarks, nvs.Native)]),
  )
}

pub fn get_bookmarks(
  hdl: Handle,
  name: String,
  props: Option(NvList),
) -> Result(NvList, Error) {
  ioctl_nvlist(
    hdl,
    ZfsIocGetBookmarks,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        option.map(props, nvs.pack(_, nvs.Native)),
      ]),
    ),
  )
}

pub fn destroy_bookmarks(
  hdl: Handle,
  name: String,
  list: NvList,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocDestroyBookmarks,
    ZfsCmdReq(Some(name), data: [
      nvs.pack(list, nvs.Native),
    ]),
  )
}

pub fn recv_new(
  hdl: Handle,
  name: String,
  args: NvList,
) -> Result(NvList, Error) {
  ioctl_nvlist(
    hdl,
    ZfsIocRecvNew,
    ZfsCmdReq(Some(name), data: [
      nvs.pack(args, nvs.Native),
    ]),
  )
}

pub fn pool_sync(hdl: Handle, name: String, force: Bool) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocPoolSync,
    ZfsCmdReq(Some(name), data: [nvlist([nvl.BooleanValue("force", force)])]),
  )
}

pub fn channel_program(
  hdl: Handle,
  name: String,
  args: NvList,
  memlimit: Int,
) -> Result(NvList, Error) {
  ioctl_nvlist(
    hdl,
    ZfsIocChannelProgram,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("nvlist_dst_size", memlimit)]),
      nvs.pack(args, nvs.Native),
    ]),
  )
}

pub fn load_key(
  hdl: Handle,
  name: String,
  hidden_args: NvList,
  noop: Bool,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocLoadKey,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.Nvlist("hidden_args", hidden_args)),
          opt(noop, nvl.Boolean("noop")),
        ]),
      ]),
    ),
  )
}

pub fn unload_key(hdl: Handle, name: String) -> Result(Nil, Error) {
  ioctl_unit(hdl, ZfsIocUnloadKey, ZfsCmdReq(Some(name), []))
}

pub fn change_key(
  hdl: Handle,
  name: String,
  crypt_cmd: Option(Int),
  hidden_args: Option(NvList),
  props: Option(NvList),
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocChangeKey,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          option.map(crypt_cmd, nvl.Uint64("crypt_cmd", _)),
          option.map(hidden_args, nvl.Nvlist("hidden_args", _)),
          option.map(props, nvl.Nvlist("props", _)),
        ]),
      ]),
    ),
  )
}

pub fn pool_checkpoint(hdl: Handle, name: String) -> Result(Nil, Error) {
  ioctl_unit(hdl, ZfsIocPoolCheckpoint, ZfsCmdReq(Some(name), []))
}

pub fn pool_discard_checkpoint(
  hdl: Handle,
  name: String,
) -> Result(Nil, Error) {
  ioctl_unit(hdl, ZfsIocPoolDiscardCheckpoint, ZfsCmdReq(Some(name), []))
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
  // XXX: This ioctl is bugged and returns an nvlist for errors in success.
  result.replace(
    ioctl_nvlist(
      hdl,
      ZfsIocPoolInitialize,
      ZfsCmdReq(Some(name), data: [
        nvlist([
          nvl.Uint64("initialize_command", pool_initialize_func_index(command)),
          nvl.Nvlist("initialize_vdevs", vdevs),
        ]),
      ]),
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
  // XXX: This ioctl is bugged and returns an nvlist for errors in success.
  result.replace(
    ioctl_nvlist(
      hdl,
      ZfsIocPoolTrim,
      ZfsCmdReq(
        Some(name),
        data: option.values([
          nvlist_opt([
            Some(nvl.Uint64("trim_command", pool_trim_func_index(command))),
            Some(nvl.Nvlist("trim_vdevs", vdevs)),
            option.map(rate, nvl.Uint64("trim_rate", _)),
            option.map(secure, nvl.BooleanValue("trim_secure", _)),
          ]),
        ]),
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
  ioctl_unit(
    hdl,
    ZfsIocRedact,
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.String("bookname", bookname),
        nvl.Nvlist("snapnv", snaps),
      ]),
    ]),
  )
}

pub fn get_bookmark_props(hdl: Handle, name: String) -> Result(NvList, Error) {
  ioctl_nvlist(hdl, ZfsIocGetBookmarkProps, ZfsCmdReq(Some(name), []))
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
  ioctl_nvlist(
    hdl,
    ZfsIocWait,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.Int32("wait_activity", zpool_wait_activity_index(activity))),
          option.map(tag, nvl.Uint64("wait_tag", _)),
        ]),
      ]),
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
  ioctl_nvlist(
    hdl,
    ZfsIocWaitFs,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Int32("wait_activity", zfs_wait_activity_index(activity))]),
    ]),
  )
}

pub fn vdev_get_props(
  hdl: Handle,
  name: String,
  vdev: Int,
  props: Option(NvList),
) -> Result(NvList, Error) {
  ioctl_nvlist(
    hdl,
    ZfsIocVdevGetProps,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.Uint64("vdevprops_get_vdev", vdev)),
          option.map(props, nvl.Nvlist("vdevprops_get_props", _)),
        ]),
      ]),
    ),
  )
}

pub fn vdev_set_props(
  hdl: Handle,
  name: String,
  vdev: Int,
  props: NvList,
) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocVdevSetProps,
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Uint64("vdevprops_set_vdev", vdev),
        nvl.Nvlist("vdevprops_set_props", props),
      ]),
    ]),
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
  ioctl_unit(
    hdl,
    ZfsIocPoolScrub,
    ZfsCmdReq(
      Some(name),
      data: option.values([
        nvlist_opt([
          Some(nvl.Uint64("scan_type", scan_func_index(scan_type))),
          Some(nvl.Uint64("scan_command", scrub_cmd_index(scan_command))),
          option.map(date_start, nvl.Uint64("scan_date_start", _)),
          option.map(date_end, nvl.Uint64("scan_date_end", _)),
        ]),
      ]),
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
  ioctl_unit(
    hdl,
    ZfsIocPoolPrefetch,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Int32("prefetch_type", zpool_prefetch_type_index(prefetch))]),
    ]),
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
  ioctl_unit(
    hdl,
    ZfsIocDdtPrune,
    ZfsCmdReq(Some(name), data: [
      nvlist([
        nvl.Int32("ddt_prune_unit", zpool_ddt_prune_unit_index(unit)),
        nvl.Uint64("ddt_prune_amount", amount),
      ]),
    ]),
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
    ZfsCmdReq(None, data: [
      nvlist([
        nvl.String("command", command),
        nvl.Uint64("pool_guid", pool_guid),
        nvl.Uint64("guid", guid),
      ]),
    ]),
  )
}

pub fn jail(hdl: Handle, name: String, jid: Int) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocJail,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("zoneid", jid)]),
    ]),
  )
}

pub fn unjail(hdl: Handle, name: String, jid: Int) -> Result(Nil, Error) {
  ioctl_unit(
    hdl,
    ZfsIocUnjail,
    ZfsCmdReq(Some(name), data: [
      nvlist([nvl.Uint64("zoneid", jid)]),
    ]),
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
  ioctl_unit(
    hdl,
    ZfsIocSetBootEnv,
    ZfsCmdReq(Some(name), data: [
      case config {
        BootEnvRaw(grub_envmap) ->
          nvlist([
            nvl.Uint64("version", 0),
            nvl.String("grub:envmap", grub_envmap),
          ])
        BootEnvNvlist(cfg) -> nvs.pack(cfg, nvs.Native)
      },
    ]),
  )
}

pub fn get_boot_env(hdl: Handle, name: String) -> Result(NvList, Error) {
  ioctl_nvlist(hdl, ZfsIocGetBootEnv, ZfsCmdReq(Some(name), []))
}
