// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result

import file_streams/file_stream
import file_streams/internal/raw_result.{type RawResult}
import iv
import pprint

import nvpair/list.{type NvList} as nvl
import nvpair/stream as nvs

import utils
import zfs/feature
import zfs/ioctls

const test_pool_name = "testpool"

const test_dataset_name = test_pool_name <> "/testdataset"

const test_snapshot_name = test_dataset_name <> "@testsnapshot"

const test_bookmark_name = test_dataset_name <> "#testbookmark"

const test_mount_name = "testmnt"

const test_file_name = "testfile"

const test_property_name = "user:testproperty"

const test_property_value = "testvalue"

const test_tag_name = "testtag"

const test_vdev_name = "testdev"

const test_vdev_size = 134_217_728

// 128 MiB
const test_channel_program_instrlimit = 1024

const test_channel_program_memlimit = 262_144

// 256 KiB

const test_channel_program = "
  args = ...
  DS = args['DS']
  res = {}
  for fs in zfs.list.children(DS) do
    res[#res+1] = fs
  end
  zfs.debug('found ' .. tostring(#res) .. ' children')
  return res
"

fn home() -> String {
  utils.cmd("echo $HOME")
}

fn vdev_file_create(name: String) -> String {
  let path = home() <> name
  let assert Ok(stream) = file_stream.open_write(path)
  let assert Ok(_) =
    file_stream.position(stream, file_stream.BeginningOfFile(test_vdev_size))
  let assert Ok(Nil) = file_stream.truncate(stream)
  let assert Ok(Nil) = file_stream.close(stream)
  path
}

fn vdev_label_read(path: String) -> NvList {
  let vdev_labels = 4
  let sizeof_vdev_label = 256 * 1024
  let label_offset = fn(size: Int, l: Int) -> Int {
    l
    * sizeof_vdev_label
    + case l < vdev_labels / 2 {
      True -> 0
      False -> size - vdev_labels * sizeof_vdev_label
    }
  }
  let align = fn(x: Int) -> Int {
    int.bitwise_and(x, int.bitwise_not(sizeof_vdev_label - 1))
  }
  let assert Ok(stream) = file_stream.open_read(path)
  let assert Ok(info) = file_stream.read_file_info(stream)
  let assert Some(raw_size) = info.size
  let size = align(raw_size)
  let assert Ok(config) =
    list.find_map([1, 2, 3, 4], fn(l) {
      let offset = label_offset(size, l)
      // TODO: file_stream.pread instead
      use _pos <- result.try(result.replace_error(
        file_stream.position(stream, file_stream.BeginningOfFile(offset)),
        Nil,
      ))
      use label <- result.try(result.replace_error(
        file_stream.read_bytes_exact(stream, sizeof_vdev_label),
        Nil,
      ))
      let vdev_phys_offset = 16 * 1024
      let vdev_phys_length = 112 * 1024
      use vdev_phys <- result.try(bit_array.slice(
        label,
        vdev_phys_offset,
        vdev_phys_length,
      ))
      let nvlist_offset = 0
      let nvlist_length = vdev_phys_length - 5 * 8
      use packed_config <- result.try(bit_array.slice(
        vdev_phys,
        nvlist_offset,
        nvlist_length,
      ))
      use #(config, _) <- result.try(result.replace_error(
        nvs.unpack(packed_config),
        Nil,
      ))
      use _state <- result.try(case nvl.lookup(config, "state") {
        Some(nvl.Uint64(_, state)) if state <= 2 -> Ok(state)
        _ -> Error(Nil)
      })
      use _txg <- result.try(case nvl.lookup(config, "txg") {
        Some(nvl.Uint64(_, txg)) -> Ok(txg)
        _ -> Error(Nil)
      })
      Ok(config)
    })
  let assert Ok(Nil) = file_stream.close(stream)
  config
}

fn common_root_vdevs(vdevs: List(String)) -> NvList {
  let assert Some(root) =
    nvl.from_list(
      [
        nvl.String("type", "root"),
        nvl.NvlistArray(
          "children",
          iv.from_list(
            list.map(vdevs, fn(path) {
              let assert Some(disk) =
                nvl.from_list(
                  [
                    nvl.String("path", path),
                    nvl.String("type", "file"),
                    nvl.Uint64("is_log", 0),
                  ],
                  [nvl.UniqueName],
                )
              disk
            }),
          ),
        ),
      ],
      [nvl.UniqueName],
    )
  root
}

fn common_all_features() -> NvList {
  let assert Some(features) =
    nvl.from_list(
      feature.all_features
        |> list.map(feature.to_string)
        |> list.map(fn(name) { nvl.Uint64("feature@" <> name, 0) }),
      [nvl.UniqueName],
    )
  features
}

fn common_zpool_create(vdevs: List(String)) {
  let hdl = ioctls.open_handle()
  let config = common_root_vdevs(vdevs)
  let props = common_all_features()
  let assert Ok(Nil) =
    ioctls.pool_create(hdl, test_pool_name, config, Some(props))
  assert ioctls.close_handle(hdl)
}

fn common_zpool_destroy() {
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.pool_destroy(hdl, test_pool_name, Some("destroying test pool"))
  assert ioctls.close_handle(hdl)
}

fn common_setup() -> List(String) {
  utils.cmd("mdo zpool destroy " <> test_pool_name)
  let vdevs = [vdev_file_create(test_vdev_name)]
  common_zpool_create(vdevs)
  vdevs
}

@external(erlang, "file", "delete")
fn file_delete(path: String) -> RawResult

fn common_cleanup_vdevs(vdevs: List(String)) {
  list.each(vdevs, file_delete)
}

fn common_cleanup(vdevs: List(String)) {
  common_zpool_destroy()
  common_cleanup_vdevs(vdevs)
}

fn common_get_config(vdevs: List(String)) -> NvList {
  let assert Ok(vdev) = list.first(vdevs)
  let label = vdev_label_read(vdev)
  let assert Some(vdev_children) = nvl.lookup(label, "vdev_children")
  let assert Some(version) = nvl.lookup(label, "version")
  let assert Some(pool_guid) = nvl.lookup(label, "pool_guid")
  let assert nvl.Uint64(_, guid) = pool_guid
  let assert Some(name) = nvl.lookup(label, "name")
  // XXX: "comment" dropped for now
  let assert Some(state) = nvl.lookup(label, "state")
  let assert Some(hostid_or_hostname) =
    option.or(nvl.lookup(label, "hostid"), nvl.lookup(label, "hostname"))
  let assert Some(nvl.Nvlist(_, top)) = nvl.lookup(label, "vdev_tree")
  let assert Some(root) =
    nvl.from_list(
      [
        nvl.String("type", "root"),
        nvl.Uint64("id", 0),
        nvl.Uint64("guid", guid),
        nvl.NvlistArray("children", iv.wrap(top)),
      ],
      [nvl.UniqueName],
    )
  let assert Some(id) = nvl.lookup(top, "id")
  let assert Some(policy) =
    nvl.from_list(
      [
        nvl.Uint64("load-request-txg", -1),
        nvl.Uint32("load-rewind-policy", 1),
      ],
      [nvl.UniqueName],
    )
  let assert Some(conf) =
    nvl.from_list(
      [
        vdev_children,
        version,
        pool_guid,
        name,
        state,
        hostid_or_hostname,
        id,
        nvl.Nvlist("vdev_tree", root),
        nvl.Nvlist("load-policy", policy),
      ],
      [nvl.UniqueName],
    )
  let hdl = ioctls.open_handle()
  let assert Ok(config) = ioctls.pool_tryimport(hdl, conf)
  assert ioctls.close_handle(hdl)
  config
}

fn common_vdev_guid(vdevs: List(String)) -> Int {
  let assert Ok(vdev) = list.first(vdevs)
  let label = vdev_label_read(vdev)
  let assert Some(nvl.Nvlist(_, vdev_tree)) = nvl.lookup(label, "vdev_tree")
  let assert Some(nvl.Uint64(_, guid)) = nvl.lookup(vdev_tree, "guid")
  guid
}

fn common_vdev_attach(vdevs: List(String), name: String) -> List(String) {
  let guid = common_vdev_guid(vdevs)
  let path = vdev_file_create(name)
  let config = common_root_vdevs([path])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.vdev_attach(hdl, test_pool_name, guid, config, False, False)
  assert ioctls.close_handle(hdl)
  [path, ..vdevs]
}

fn common_dataset_create(name: String) {
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.create(hdl, name, ioctls.ObjsetTypeZfs, None, None)
  assert ioctls.close_handle(hdl)
}

fn common_snapshot_create(name: String) {
  let assert Some(snaps) = nvl.from_list([nvl.Boolean(name)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.snapshot(hdl, test_pool_name, snaps, None)
  assert ioctls.close_handle(hdl)
}

fn common_clone_create(origin: String, name: String) {
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.clone(hdl, name, origin, None, None)
  assert ioctls.close_handle(hdl)
}

fn common_bookmark_create(snap: String, name: String) {
  let assert Some(bookmarks) =
    nvl.from_list([nvl.String(name, snap)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.bookmark(hdl, test_pool_name, bookmarks)
  assert ioctls.close_handle(hdl)
}

fn common_hold_create(snap: String, tag: String) {
  let assert Some(holds) =
    nvl.from_list([nvl.String(snap, tag)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.hold(hdl, test_pool_name, holds, None)
  assert ioctls.close_handle(hdl)
}

fn common_stats_get(name: String) -> NvList {
  let hdl = ioctls.open_handle()
  let assert Ok(#(_stats, Some(props))) = ioctls.objset_stats(hdl, name, False)
  assert ioctls.close_handle(hdl)
  props
}

fn common_objset_id_lookup(name: String) -> Int {
  let stats = common_stats_get(name)
  let assert Some(nvl.Nvlist(_, prop)) = nvl.lookup(stats, "objsetid")
  let assert Some(nvl.Uint64(_, objsetid)) = nvl.lookup(prop, "value")
  objsetid
}

fn common_inject_fault(vdevs: List(String)) -> Int {
  let guid = common_vdev_guid(vdevs)
  let enxio = 6
  let record =
    ioctls.InjectRecord(
      objset: 0,
      object: 0,
      start: 0,
      end: 0,
      guid:,
      level: 0,
      error: enxio,
      object_type: ioctls.DmuObjTypeNone,
      freq: 0,
      failfast: 0,
      func: "",
      iotype: ioctls.IotypeAll,
      duration: 0,
      timer: 10,
      nlanes: 2,
      cmd: ioctls.InjectDelayIo,
      dvas: 0,
      match_count: 0,
      inject_count: 0,
    )
  let hdl = ioctls.open_handle()
  let assert Ok(fault_id) = ioctls.inject_fault(hdl, test_pool_name, record, [])
  assert ioctls.close_handle(hdl)
  fault_id
}

fn common_clear_fault(fault_id: Int) {
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.clear_fault(hdl, fault_id)
  assert ioctls.close_handle(hdl)
}

fn common_mount_dataset(dataset: String, mountpoint: String) {
  list.each(
    [
      "mkdir -p " <> mountpoint,
      "mount -t zfs " <> dataset <> " " <> mountpoint,
    ],
    utils.cmd,
  )
}

fn common_create_file(path: String) {
  let assert Ok(stream) = file_stream.open_write(path)
  let assert Ok(Nil) = file_stream.close(stream)
  Nil
}

fn common_file_inode(path: String) -> Int {
  let assert Ok(stream) = file_stream.open_read(path)
  let assert Ok(info) = file_stream.read_file_info(stream)
  let assert Ok(Nil) = file_stream.close(stream)
  let assert Some(inode) = info.inode
  inode
}

fn common_unmount_dataset(mountpoint: String) {
  list.each(
    [
      "umount -f " <> mountpoint,
      "rmdir " <> mountpoint,
    ],
    utils.cmd,
  )
}

// pool_create
// pool_destroy
pub fn pool_create_destroy_test() {
  let vdevs = common_setup()
  common_cleanup(vdevs)
}

// pool_set_props
pub fn pool_set_props_test() {
  let vdevs = common_setup()
  let assert Some(props) =
    nvl.from_list([nvl.String("bootfs", test_pool_name)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.pool_set_props(hdl, test_pool_name, props)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_get_props
pub fn pool_get_props_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(_props) = ioctls.pool_get_props(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_export
pub fn pool_export_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.pool_export(
      hdl,
      test_pool_name,
      False,
      False,
      Some("exporting test pool"),
    )
  assert ioctls.close_handle(hdl)
  common_cleanup_vdevs(vdevs)
}

// pool_tryimport
pub fn pool_tryimport_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.pool_export(
      hdl,
      test_pool_name,
      False,
      False,
      Some("exporting test pool"),
    )
  assert ioctls.close_handle(hdl)
  let config = common_get_config(vdevs)
  let assert Some(nvl.String(_, name)) = nvl.lookup(config, "name")
  io.println("got config for pool " <> name)
  common_cleanup_vdevs(vdevs)
}

// pool_import
pub fn pool_import_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.pool_export(
      hdl,
      test_pool_name,
      False,
      False,
      Some("exporting test pool"),
    )
  let config = common_get_config(vdevs)
  let assert Some(nvl.Uint64(_, pool_guid)) = nvl.lookup(config, "pool_guid")
  io.println("pool guid: " <> int.to_string(pool_guid))
  let assert Ok(config) =
    ioctls.pool_import(hdl, test_pool_name, pool_guid, config, None, [
      ioctls.ImportOnly,
    ])
  assert ioctls.close_handle(hdl)
  let assert Some(nvl.String(_, name)) = nvl.lookup(config, "name")
  io.println("imported pool: " <> name)
  common_cleanup_vdevs(vdevs)
}

// pool_configs
pub fn pool_configs_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(#(ns_gen, configs)) = ioctls.pool_configs(hdl, 0)
  assert ioctls.close_handle(hdl)
  io.println("got configs for namespace generation: " <> int.to_string(ns_gen))
  iv.each(configs.pairs, fn(pair) { io.println("\t" <> nvl.pair_name(pair)) })
  common_cleanup(vdevs)
}

// pool_stats
pub fn pool_stats_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(#(Some(_config), None, None)) =
    ioctls.pool_stats(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_scan
pub fn pool_scan_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.pool_scan(hdl, test_pool_name, ioctls.ScanScrub, ioctls.ScrubNormal)
  let assert Ok(Nil) =
    ioctls.pool_scan(hdl, test_pool_name, ioctls.ScanNone, ioctls.ScrubNormal)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_freeze
pub fn pool_freeze_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.pool_freeze(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_upgrade
pub fn pool_upgrade_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.pool_upgrade(hdl, test_pool_name, 5000)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

fn history_loop(hdl: ioctls.Handle, offset: Int) {
  let assert Ok(result) = ioctls.pool_get_history(hdl, test_pool_name, offset)
  pprint.debug(result)
  case result {
    #([], _) -> Nil
    #(_, new_offset) -> history_loop(hdl, new_offset)
  }
}

// pool_get_history
pub fn pool_get_history_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  history_loop(hdl, 0)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_reguid
pub fn pool_reguid_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.pool_reguid(hdl, test_pool_name, None)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_reopen
pub fn pool_reopen_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.pool_reopen(hdl, test_pool_name, False)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_checkpoint
pub fn pool_checkpoint_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.pool_checkpoint(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_discard_checkpoint
pub fn pool_discard_checkpoint_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.pool_checkpoint(hdl, test_pool_name)
  let assert Ok(Nil) = ioctls.pool_discard_checkpoint(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_initialize
pub fn pool_initialize_test() {
  let vdevs = common_setup()
  let assert Some(vdev_guids) =
    nvl.from_list(
      list.map(vdevs, fn(path) {
        let label = vdev_label_read(path)
        let assert Some(nvl.Uint64(_, guid)) = nvl.lookup(label, "guid")
        nvl.Uint64(path, guid)
      }),
      [nvl.UniqueName],
    )
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.pool_initialize(
      hdl,
      test_pool_name,
      ioctls.PoolInitializeStart,
      vdev_guids,
    )
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_scrub
pub fn pool_scrub_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.pool_scrub(
      hdl,
      test_pool_name,
      ioctls.ScanScrub,
      ioctls.ScrubNormal,
      None,
      None,
    )
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_sync
pub fn pool_sync_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.pool_sync(hdl, test_pool_name, False)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// pool_trim
pub fn pool_trim_test() {
  let vdevs = common_setup()
  let assert Ok(vdev) = list.first(vdevs)
  let label = vdev_label_read(vdev)
  let assert Some(nvl.Uint64(_, guid)) = nvl.lookup(label, "guid")
  let assert Some(trim_vdevs) =
    nvl.from_list([nvl.Uint64(vdev, guid)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.pool_trim(
      hdl,
      test_pool_name,
      ioctls.PoolTrimStart,
      trim_vdevs,
      None,
      None,
    )
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// vdev_add
pub fn vdev_add_test() {
  let vdevs = common_setup()
  let vdev = vdev_file_create(test_vdev_name <> "0")
  let config = common_root_vdevs([vdev])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.vdev_add(hdl, test_pool_name, config, True)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// vdev_remove
pub fn vdev_remove_test() {
  let vdevs =
    int.range(from: 0, to: 3, with: [], run: fn(acc, i) {
      [vdev_file_create(test_vdev_name <> int.to_string(i)), ..acc]
    })
  common_zpool_create(vdevs)
  let guid = common_vdev_guid(vdevs)
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.vdev_remove(hdl, test_pool_name, guid)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// vdev_remove_cancel
pub fn vdev_remove_cancel_test() {
  let vdevs =
    int.range(from: 0, to: 3, with: [], run: fn(acc, i) {
      [vdev_file_create(test_vdev_name <> int.to_string(i)), ..acc]
    })
  common_zpool_create(vdevs)
  let guid = common_vdev_guid(vdevs)
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.vdev_remove(hdl, test_pool_name, guid)
  let assert Ok(Nil) = ioctls.vdev_remove_cancel(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// vdev_set_state
pub fn vdev_set_state_test() {
  let vdevs = common_setup()
  let guid = common_vdev_guid(vdevs)
  // VDEV_AUX_ERR_EXCEEDED
  let flags = 11
  let hdl = ioctls.open_handle()
  let assert Ok(ioctls.VdevStateUnknown) =
    ioctls.vdev_set_state(
      hdl,
      test_pool_name,
      guid,
      ioctls.VdevStateFaulted,
      Some(flags),
    )
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// vdev_attach
pub fn vdev_attach_test() {
  let vdevs = common_setup()
  let vdevs = common_vdev_attach(vdevs, test_vdev_name <> "0")
  common_cleanup(vdevs)
}

// vdev_detach
pub fn vdev_detach_test() {
  let vdevs = common_setup()
  let guid = common_vdev_guid(vdevs)
  let vdevs = common_vdev_attach(vdevs, test_vdev_name <> "0")
  utils.cmd("sleep 1")
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.vdev_detach(hdl, test_pool_name, guid)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// vdev_split
pub fn vdev_split_test() {
  let vdevs = common_setup()
  let vdevs = common_vdev_attach(vdevs, test_vdev_name <> "0")
  let assert Ok(vdev) = list.first(vdevs)
  let label = vdev_label_read(vdev)
  let assert Some(nvl.Uint64(_, version)) = nvl.lookup(label, "version")
  let assert Some(nvl.Nvlist(_, top)) = nvl.lookup(label, "vdev_tree")
  let assert Some(nvl.NvlistArray(_, children)) = nvl.lookup(top, "children")
  assert iv.size(children) == 2
  let assert Ok(split_children) = iv.slice(from: children, start: 0, size: 1)
  let assert Some(root) =
    nvl.from_list(
      [
        nvl.String("type", "root"),
        nvl.NvlistArray("children", split_children),
      ],
      [nvl.UniqueName],
    )
  let newname = test_pool_name <> "0"
  let assert Some(conf) =
    nvl.from_list(
      [
        nvl.String("name", newname),
        nvl.Uint64("version", version),
        nvl.Nvlist("vdev_tree", root),
      ],
      [nvl.UniqueName],
    )
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.vdev_split(hdl, test_pool_name, newname, conf, None, [
      ioctls.ZpoolExportAfterSplit,
    ])
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// vdev_set_path
pub fn vdev_set_path_test() {
  let vdevs = common_setup()
  let guid = common_vdev_guid(vdevs)
  let assert Ok(path) = list.first(vdevs)
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.vdev_set_path(hdl, test_pool_name, guid, path)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// vdev_set_fru
pub fn vdev_set_fru_test() {
  let vdevs = common_setup()
  let guid = common_vdev_guid(vdevs)
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.vdev_set_fru(hdl, test_pool_name, guid, "test")
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// vdev_set_props
// vdev_get_props
pub fn vdev_set_get_props_test() {
  let vdevs = common_setup()
  let guid = common_vdev_guid(vdevs)
  let assert Some(props) =
    nvl.from_list([nvl.String("comment", test_property_value)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.vdev_set_props(hdl, test_pool_name, guid, props)
  let assert Some(props) =
    nvl.from_list([nvl.Boolean("comment")], [nvl.UniqueName])
  let assert Ok(props) =
    ioctls.vdev_get_props(hdl, test_pool_name, guid, Some(props))
  assert ioctls.close_handle(hdl)
  let assert Some(nvl.Nvlist(_, comment)) = nvl.lookup(props, "comment")
  let assert Some(nvl.String(_, value)) = nvl.lookup(comment, "value")
  assert value == test_property_value
  common_cleanup(vdevs)
}

// objset_stats
pub fn objset_stats_test() {
  let vdevs = common_setup()
  let _ = common_stats_get(test_pool_name)
  common_cleanup(vdevs)
}

// objset_zpl_props
pub fn objset_zpl_props_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(_props) = ioctls.objset_zpl_props(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// objset_recvd_props requires a received dataset maybe

// ds_obj_to_ds_name
pub fn ds_obj_to_ds_name_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  let dsobj = common_objset_id_lookup(test_dataset_name)
  let hdl = ioctls.open_handle()
  let assert Ok(dsname) = ioctls.ds_obj_to_ds_name(hdl, test_pool_name, dsobj)
  assert ioctls.close_handle(hdl)
  assert dsname == test_dataset_name
  common_cleanup(vdevs)
}

// next_obj
pub fn next_obj_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(_next_opt) = ioctls.next_obj(hdl, test_pool_name, 0)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// diff
pub fn diff_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  let snap0 = test_snapshot_name <> "0"
  let snap1 = test_snapshot_name <> "1"
  common_snapshot_create(snap0)
  common_snapshot_create(snap1)
  let hdl = ioctls.open_handle()
  // XXX: sending diff to stderr might not end well
  let assert Ok(Nil) = ioctls.diff(hdl, snap1, snap0, 2)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// obj_to_path
pub fn obj_to_path_test() {
  let vdevs = common_setup()
  common_mount_dataset(test_pool_name, test_mount_name)
  let test_file_path = test_mount_name <> "/" <> test_file_name
  common_create_file(test_file_path)
  let obj = common_file_inode(test_file_path)
  common_unmount_dataset(test_mount_name)
  let hdl = ioctls.open_handle()
  let assert Ok(path) = ioctls.obj_to_path(hdl, test_pool_name, obj)
  assert ioctls.close_handle(hdl)
  assert path == "/" <> test_file_name
  common_cleanup(vdevs)
}

// obj_to_stats
pub fn obj_to_stats_test() {
  let vdevs = common_setup()
  common_mount_dataset(test_pool_name, test_mount_name)
  let test_file_path = test_mount_name <> "/" <> test_file_name
  common_create_file(test_file_path)
  let obj = common_file_inode(test_file_path)
  common_unmount_dataset(test_mount_name)
  let hdl = ioctls.open_handle()
  let assert Ok(stats) = ioctls.obj_to_stats(hdl, test_pool_name, obj)
  assert ioctls.close_handle(hdl)
  pprint.debug(stats)
  common_cleanup(vdevs)
}

// inject_fault
// clear_fault
pub fn inject_clear_fault_test() {
  let vdevs = common_setup()
  let fault_id = common_inject_fault(vdevs)
  common_clear_fault(fault_id)
  common_cleanup(vdevs)
}

// inject_list_next
pub fn inject_list_next_test() {
  let vdevs = common_setup()
  let fault_id = common_inject_fault(vdevs)
  let hdl = ioctls.open_handle()
  let assert Ok(Some(#(next_id, pool, _record))) =
    ioctls.inject_list_next(hdl, 0)
  assert ioctls.close_handle(hdl)
  assert next_id == fault_id
  assert pool == test_pool_name
  common_clear_fault(fault_id)
  common_cleanup(vdevs)
}

// dataset_list_next
pub fn dataset_list_next_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  let hdl = ioctls.open_handle()
  let assert Ok(Some(#(dataset, _cookie, _stats, Some(_props)))) =
    ioctls.dataset_list_next(hdl, test_pool_name, False, 0)
  assert ioctls.close_handle(hdl)
  assert dataset == test_dataset_name
  common_cleanup(vdevs)
}

// snapshot_list_next
pub fn snapshot_list_next_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  let hdl = ioctls.open_handle()
  let assert Ok(Some(#(snapshot, _cookie, _stats, Some(_props)))) =
    ioctls.snapshot_list_next(hdl, test_dataset_name, False, 0)
  assert ioctls.close_handle(hdl)
  assert snapshot == test_snapshot_name
  common_cleanup(vdevs)
}

// get_fsacl
pub fn get_fsacl_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(_fsacl) = ioctls.get_fsacl(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// set_fsacl
pub fn set_fsacl_test() {
  let vdevs = common_setup()
  let assert Some(perms) =
    nvl.from_list([nvl.Boolean("allow")], [nvl.UniqueName])
  let assert Some(acl) =
    nvl.from_list(
      [
        nvl.Nvlist("el$", perms),
        nvl.Nvlist("El$", perms),
        nvl.Nvlist("ed$", perms),
        nvl.Nvlist("Ed$", perms),
      ],
      [nvl.UniqueName],
    )
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.set_fsacl(hdl, test_pool_name, False, acl)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// set_prop
pub fn set_prop_test() {
  let vdevs = common_setup()
  let assert Some(props) =
    nvl.from_list([nvl.String(test_property_name, test_property_value)], [
      nvl.UniqueName,
    ])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.set_prop(hdl, test_pool_name, props)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// create
pub fn create_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_cleanup(vdevs)
}

// destroy
pub fn destroy_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.destroy(hdl, test_dataset_name, False)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// rename
pub fn rename_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  let newname = test_dataset_name <> "0"
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.rename(hdl, test_dataset_name, newname, [])
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// snapshot
pub fn snapshot_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  common_cleanup(vdevs)
}

// rollback
pub fn rollback_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  let hdl = ioctls.open_handle()
  let assert Ok(target) = ioctls.rollback(hdl, test_dataset_name, None)
  assert ioctls.close_handle(hdl)
  assert target == test_snapshot_name
  common_cleanup(vdevs)
}

// clone
pub fn clone_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  let clone_name = test_dataset_name <> "0"
  common_clone_create(test_snapshot_name, clone_name)
  common_cleanup(vdevs)
}

// promote
pub fn promote_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  let clone_name = test_dataset_name <> "0"
  common_clone_create(test_snapshot_name, clone_name)
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.promote(hdl, clone_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// redact
pub fn redact_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  let snap0 = test_snapshot_name <> "0"
  let snap1 = test_snapshot_name <> "1"
  common_snapshot_create(snap0)
  common_snapshot_create(snap1)
  let assert Some(snaps) = nvl.from_list([nvl.Boolean(snap1)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.redact(hdl, snap0, "testredaction", snaps)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// destroy_snaps
pub fn destroy_snaps_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  let assert Some(snaps) =
    nvl.from_list([nvl.Boolean(test_snapshot_name)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.destroy_snaps(hdl, test_pool_name, snaps, False)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// inherit_prop
pub fn inherit_prop_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.inherit_prop(hdl, test_pool_name, test_property_name, False)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// user_space_one
pub fn user_space_one_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(space) =
    ioctls.user_space_one(hdl, test_pool_name, ioctls.UserUsed, "", 0)
  assert ioctls.close_handle(hdl)
  io.println("user root (0) used " <> int.to_string(space) <> " bytes")
  common_cleanup(vdevs)
}

// user_space_many
pub fn user_space_many_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(#(_cursor, useraccts)) =
    ioctls.user_space_many(hdl, test_pool_name, ioctls.UserUsed, 8, 0)
  assert ioctls.close_handle(hdl)
  let nuseraccts = list.length(useraccts)
  io.println("got " <> int.to_string(nuseraccts) <> " useracct record(s)")
  common_cleanup(vdevs)
}

// user_space_upgrade
pub fn user_space_upgrade_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.user_space_upgrade(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// hold
pub fn hold_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  common_hold_create(test_snapshot_name, test_tag_name)
  common_cleanup(vdevs)
}

// release
pub fn release_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  common_hold_create(test_snapshot_name, test_tag_name)
  let assert Some(forsnap) =
    nvl.from_list([nvl.Boolean(test_tag_name)], [nvl.UniqueName])
  let assert Some(holds) =
    nvl.from_list([nvl.Nvlist(test_snapshot_name, forsnap)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.release(hdl, test_pool_name, holds)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// get_holds
pub fn get_holds_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  common_hold_create(test_snapshot_name, test_tag_name)
  let hdl = ioctls.open_handle()
  let assert Ok(_holds) = ioctls.get_holds(hdl, test_snapshot_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// TODO: send, recv, send_progress, send_new

// send_space
pub fn send_space_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  let hdl = ioctls.open_handle()
  let assert Ok(results) = ioctls.send_space(hdl, test_snapshot_name, None)
  assert ioctls.close_handle(hdl)
  let assert Some(nvl.Uint64(_, space)) = nvl.lookup(results, "space")
  io.println("send space: " <> int.to_string(space) <> " bytes")
  common_cleanup(vdevs)
}

// clear
pub fn clear_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(None) = ioctls.clear(hdl, test_pool_name, None, None)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// bookmark
pub fn bookmark_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  common_bookmark_create(test_snapshot_name, test_bookmark_name)
  common_cleanup(vdevs)
}

// get_bookmarks
pub fn get_bookmarks_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  common_bookmark_create(test_snapshot_name, test_bookmark_name)
  let assert Some(props) =
    nvl.from_list([nvl.Boolean("guid")], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(_bookmarks) =
    ioctls.get_bookmarks(hdl, test_dataset_name, Some(props))
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// get_bookmark_props
pub fn get_bookmark_props_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  common_bookmark_create(test_snapshot_name, test_bookmark_name)
  let hdl = ioctls.open_handle()
  let assert Ok(_bookmarks) = ioctls.get_bookmark_props(hdl, test_bookmark_name)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// destroy_bookmarks
pub fn destroy_bookmarks_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  common_bookmark_create(test_snapshot_name, test_bookmark_name)
  let assert Some(bookmarks) =
    nvl.from_list([nvl.Boolean(test_bookmark_name)], [nvl.UniqueName])
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.destroy_bookmarks(hdl, test_pool_name, bookmarks)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// nextboot
pub fn nextboot_test() {
  let vdevs = common_setup()
  let assert Ok(vdev) = list.first(vdevs)
  let label = vdev_label_read(vdev)
  let assert Some(nvl.Uint64(_, pool_guid)) = nvl.lookup(label, "pool_guid")
  let assert Some(nvl.Uint64(_, guid)) = nvl.lookup(label, "guid")
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.nextboot(hdl, "", pool_guid, guid)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// channel_program
pub fn channel_program_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  let assert Some(arglist) =
    nvl.from_list([nvl.String("DS", test_pool_name)], [nvl.UniqueName])
  let assert Some(args) =
    nvl.from_list(
      [
        nvl.String("program", test_channel_program),
        nvl.Nvlist("arg", arglist),
        nvl.Uint64("instrlimit", test_channel_program_instrlimit),
        nvl.Uint64("memlimit", test_channel_program_memlimit),
      ],
      [nvl.UniqueName],
    )
  let hdl = ioctls.open_handle()
  let assert Ok(_results) =
    ioctls.channel_program(
      hdl,
      test_pool_name,
      args,
      test_channel_program_memlimit,
    )
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// error_log
pub fn error_log_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(errors) = ioctls.error_log(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  assert errors == []
  common_cleanup(vdevs)
}

// log_history
pub fn log_history_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) = ioctls.log_history(hdl, "this is a test")
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// TODO: tmp_snapshot wants an fd

// jail and unjail are a bit complicated without more bindings

// space_written
pub fn space_written_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  common_snapshot_create(test_snapshot_name)
  let hdl = ioctls.open_handle()
  let assert Ok(#(used, compressed, uncompressed)) =
    ioctls.space_written(hdl, test_dataset_name, test_snapshot_name)
  assert ioctls.close_handle(hdl)
  io.println(
    "space written: "
    <> int.to_string(used)
    <> " bytes ("
    <> int.to_string(compressed)
    <> " compressed, "
    <> int.to_string(uncompressed)
    <> " uncompressed)",
  )
  common_cleanup(vdevs)
}

// space_snaps
pub fn space_snaps_test() {
  let vdevs = common_setup()
  common_dataset_create(test_dataset_name)
  let snap0 = test_snapshot_name <> "0"
  let snap1 = test_snapshot_name <> "1"
  common_snapshot_create(snap0)
  common_snapshot_create(snap1)
  let hdl = ioctls.open_handle()
  let assert Ok(_results) = ioctls.space_snaps(hdl, snap1, snap0)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// set_boot_env
// get_boot_env
pub fn set_get_boot_env_test() {
  let vdevs = common_setup()
  let assert Some(cfg) =
    nvl.from_list(
      [
        nvl.Uint64("version", 1),
        nvl.String("testvar", "testval"),
      ],
      [nvl.UniqueName],
    )
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.set_boot_env(hdl, test_pool_name, ioctls.BootEnvNvlist(cfg))
  let assert Ok(boot_env) = ioctls.get_boot_env(hdl, test_pool_name)
  assert ioctls.close_handle(hdl)
  let assert Some(nvl.String(_, value)) = nvl.lookup(boot_env, "testvar")
  assert value == "testval"
  common_cleanup(vdevs)
}

// wait
pub fn wait_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(results) =
    ioctls.wait(hdl, test_pool_name, ioctls.ZpoolWaitFree, None)
  assert ioctls.close_handle(hdl)
  let assert Some(nvl.BooleanValue(_, _)) = nvl.lookup(results, "wait_waited")
  common_cleanup(vdevs)
}

// wait_fs
pub fn wait_fs_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(results) =
    ioctls.wait_fs(hdl, test_pool_name, ioctls.ZfsWaitDeleteQ)
  assert ioctls.close_handle(hdl)
  let assert Some(nvl.BooleanValue(_, _)) = nvl.lookup(results, "wait_waited")
  common_cleanup(vdevs)
}

// load_key, unload_key, change_key are too complicated for these tests

// pool_prefetch
pub fn pool_prefetch_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.pool_prefetch(hdl, test_pool_name, ioctls.ZpoolPrefetchBrt)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}

// ddt_prune
pub fn ddt_prune_test() {
  let vdevs = common_setup()
  let hdl = ioctls.open_handle()
  let assert Ok(Nil) =
    ioctls.ddt_prune(hdl, test_pool_name, ioctls.ZpoolDdtPrunePercentage, 100)
  assert ioctls.close_handle(hdl)
  common_cleanup(vdevs)
}
