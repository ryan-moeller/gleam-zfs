import gleam/option.{type Option, None, Some}

pub type Feature {
  AllocationClasses
  AsyncDestroy
  AvzV2
  Blake3
  BlockCloning
  BlockCloningEndian
  BookmarkV2
  BookmarkWritten
  Bookmarks
  DeviceRebuild
  DeviceRemoval
  Draid
  DraidFailDomains
  DynamicGangHeader
  Edonr
  EmbeddedData
  EmptyBpobj
  EnabledTxg
  Encryption
  ExtensibleDataset
  FastDedup
  FsSsLimit
  HeadErrlog
  HoleBirth
  LargeBlocks
  LargeDnode
  LargeMicrozap
  Livelist
  LogSpacemap
  Longname
  Lz4Compress
  MultiVdevCrashDump
  ObsoleteCounts
  PhysicalRewrite
  PoolCheckpoint
  ProjectQuota
  RaidzExpansion
  RedactedDatasets
  RedactionBookmarks
  RedactionListSpill
  ResilverDefer
  Sha512
  Skein
  SpacemapHistogram
  SpacemapV2
  UserobjAccounting
  ZilSaXattr
  ZstdCompress
}

pub fn from_string(s: String) -> Option(Feature) {
  case s {
    "allocation_classes" -> Some(AllocationClasses)
    "async_destroy" -> Some(AsyncDestroy)
    "blake3" -> Some(Blake3)
    "block_cloning" -> Some(BlockCloning)
    "block_cloning_endian" -> Some(BlockCloningEndian)
    "bookmark_v2" -> Some(BookmarkV2)
    "bookmark_written" -> Some(BookmarkWritten)
    "bookmarks" -> Some(Bookmarks)
    "device_rebuild" -> Some(DeviceRebuild)
    "device_removal" -> Some(DeviceRemoval)
    "draid" -> Some(Draid)
    "draid_failure_domains" -> Some(DraidFailDomains)
    "dynamic_gang_header" -> Some(DynamicGangHeader)
    "edonr" -> Some(Edonr)
    "embedded_data" -> Some(EmbeddedData)
    "empty_bpobj" -> Some(EmptyBpobj)
    "enabled_txg" -> Some(EnabledTxg)
    "encryption" -> Some(Encryption)
    "extensible_dataset" -> Some(ExtensibleDataset)
    "fast_dedup" -> Some(FastDedup)
    "filesystem_limit" -> Some(FsSsLimit)
    "head_errlog" -> Some(HeadErrlog)
    "hole_birth" -> Some(HoleBirth)
    "large_blocks" -> Some(LargeBlocks)
    "large_dnode" -> Some(LargeDnode)
    "large_microzap" -> Some(LargeMicrozap)
    "livelist" -> Some(Livelist)
    "log_spacemap" -> Some(LogSpacemap)
    "longname" -> Some(Longname)
    "lz4_compress" -> Some(Lz4Compress)
    "multi_vdev_crash_dump" -> Some(MultiVdevCrashDump)
    "obsolete_counts" -> Some(ObsoleteCounts)
    "physical_rewrite" -> Some(PhysicalRewrite)
    "project_quota" -> Some(ProjectQuota)
    "raidz_expansion" -> Some(RaidzExpansion)
    "redacted_datasets" -> Some(RedactedDatasets)
    "redaction_bookmarks" -> Some(RedactionBookmarks)
    "redaction_list_spill" -> Some(RedactionListSpill)
    "resilver_defer" -> Some(ResilverDefer)
    "sha512" -> Some(Sha512)
    "skein" -> Some(Skein)
    "spacemap_histogram" -> Some(SpacemapHistogram)
    "spacemap_v2" -> Some(SpacemapV2)
    "userobj_accounting" -> Some(UserobjAccounting)
    "vdev_zaps_v2" -> Some(AvzV2)
    "zilsaxattr" -> Some(ZilSaXattr)
    "zpool_checkpoint" -> Some(PoolCheckpoint)
    "zstd_compress" -> Some(ZstdCompress)
    _ -> None
  }
}

pub type Attributes {
  Attributes(
    name: String,
    guid: String,
    description: String,
    readonly_compat: Bool,
    required_for_mos: Bool,
    activate_on_enable: Bool,
    per_dataset: Bool,
    no_upgrade: Bool,
    depends: List(Feature),
  )
}

pub fn attributes(feat: Feature) -> Attributes {
  case feat {
    AllocationClasses ->
      Attributes(
        name: "allocation_classes",
        guid: "org.zfsonlinux:allocation_classes",
        description: "Support for separate allocation classes.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    AsyncDestroy ->
      Attributes(
        name: "async_destroy",
        guid: "com.delphix:async_destroy",
        description: "Destroy filesystems asynchronously.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    AvzV2 ->
      Attributes(
        name: "vdev_zaps_v2",
        guid: "com.klarasystems:vdev_zaps_v2",
        description: "Support for root vdev ZAP.",
        readonly_compat: False,
        required_for_mos: True,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    Blake3 ->
      Attributes(
        name: "blake3",
        guid: "org.openzfs:blake3",
        description: "BLAKE3 hash algorithm.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    BlockCloning ->
      Attributes(
        name: "block_cloning",
        guid: "com.fudosecurity:block_cloning",
        description: "Support for block cloning via Block Reference Table.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    BlockCloningEndian ->
      Attributes(
        name: "block_cloning_endian",
        guid: "com.truenas:block_cloning_endian",
        description: "Fixes BRT ZAP endianness on new pools.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    BookmarkV2 ->
      Attributes(
        name: "bookmark_v2",
        guid: "com.datto:bookmark_v2",
        description: "Support for larger bookmarks",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [ExtensibleDataset, Bookmarks],
      )
    BookmarkWritten ->
      Attributes(
        name: "bookmark_written",
        guid: "com.delphix:bookmark_written",
        description: // FIXME
        "Additional accounting, enabling the written#<bookmark> property
           (space written since a bookmark), and estimates of send stream
           sizes for incrementals from bookmarks.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [BookmarkV2, ExtensibleDataset, Bookmarks],
      )
    Bookmarks ->
      Attributes(
        name: "bookmarks",
        guid: "com.delphix:bookmarks",
        description: "\"zfs bookmark\" command",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    DeviceRebuild ->
      Attributes(
        name: "device_rebuild",
        guid: "org.openzfs:device_rebuild",
        description: "Support for sequential mirror/dRAID device rebuilds.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    DeviceRemoval ->
      Attributes(
        name: "device_removal",
        guid: "com.delphix:device_removal",
        description: "Top-level vdevs can be removed, reducing logical pool size.",
        readonly_compat: False,
        required_for_mos: True,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    Draid ->
      Attributes(
        name: "draid",
        guid: "org.openzfs:draid",
        description: "Support for distributed spare RAID",
        readonly_compat: False,
        required_for_mos: True,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    DraidFailDomains ->
      Attributes(
        name: "draid_failure_domains",
        guid: "com.seagate:draid_failure_domains",
        description: "Support for failure domains in dRAID",
        readonly_compat: False,
        required_for_mos: True,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [Draid],
      )
    DynamicGangHeader ->
      Attributes(
        name: "dynamic_gang_header",
        guid: "com.klarasystems:dynamic_gang_header",
        description: "com.klarasystems:dynamic_gang_header",
        readonly_compat: False,
        required_for_mos: True,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: True,
        depends: [],
      )
    Edonr ->
      Attributes(
        name: "edonr",
        guid: "org.illumos:edonr",
        description: "Edon-R hash algorithm.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    EmbeddedData ->
      Attributes(
        name: "embedded_data",
        guid: "com.delphix:embedded_data",
        description: "Blocks which compress very well use even less space.",
        readonly_compat: False,
        required_for_mos: True,
        activate_on_enable: True,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    EmptyBpobj ->
      Attributes(
        name: "empty_bpobj",
        guid: "com.delphix:empty_bpobj",
        description: "Snapshots use less space.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    EnabledTxg ->
      Attributes(
        name: "enabled_txg",
        guid: "com.delphix:enabled_txg",
        description: "Record txg at which a feature is enabled",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    Encryption ->
      Attributes(
        name: "encryption",
        guid: "com.datto:encryption",
        description: "Support for dataset level encryption",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset, BookmarkV2],
      )
    ExtensibleDataset ->
      Attributes(
        name: "extensible_dataset",
        guid: "com.delphix:extensible_dataset",
        description: "Enhanced dataset functionality, used by other features.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    FastDedup ->
      Attributes(
        name: "fast_dedup",
        guid: "com.klarasystems:fast_dedup",
        description: "Support for advanced deduplication",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    FsSsLimit ->
      Attributes(
        name: "filesystem_limits",
        guid: "com.joyent:filesystem_limits",
        description: "Filesystem and snapshot limits.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    HeadErrlog ->
      Attributes(
        name: "head_errlog",
        guid: "com.delphix:head_errlog",
        description: "Support for per-dataset on-disk error logs.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: True,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    HoleBirth ->
      Attributes(
        name: "hole_birth",
        guid: "com.delphix:hole_birth",
        description: "Retain hole birth txg for more precise zfs send",
        readonly_compat: False,
        required_for_mos: True,
        activate_on_enable: True,
        per_dataset: False,
        no_upgrade: False,
        depends: [EnabledTxg],
      )
    LargeBlocks ->
      Attributes(
        name: "large_blocks",
        guid: "org.open-zfs:large_blocks",
        description: "Support for blocks larger than 128KB.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    LargeDnode ->
      Attributes(
        name: "large_dnode",
        guid: "org.zfsonlinux:large_dnode",
        description: "Variable on-disk size of dnodes.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    LargeMicrozap ->
      Attributes(
        name: "large_microzap",
        guid: "com.klarasystems:large_microzap",
        description: "Support for microzaps larger than 128KB.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset, LargeBlocks],
      )
    Livelist ->
      Attributes(
        name: "livelist",
        guid: "com.delphix:livelist",
        description: "Improved clone deletion performance.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    LogSpacemap ->
      Attributes(
        name: "log_spacemap",
        guid: "com.delphix:log_spacemap",
        description: // FIXME
        "Log metaslab changes on a single spacemap and flush them
           periodically.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [SpacemapV2],
      )
    Longname ->
      Attributes(
        name: "longname",
        guid: "org.zfsonlinux:longname",
        description: "support filename up to 1024 bytes",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    Lz4Compress ->
      Attributes(
        name: "lz4_compress",
        guid: "org.illumos:lz4_compress",
        description: "LZ4 compression algorithm support.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: True,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    MultiVdevCrashDump ->
      Attributes(
        name: "multi_vdev_crash_dump",
        guid: "com.joyent:multi_vdev_crash_dump",
        description: "Crash dumps to multiple vdev pools.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    ObsoleteCounts ->
      Attributes(
        name: "obsolete_counts",
        guid: "com.delphix:obsolete_counts",
        description: // FIXME
        "Reduce memory used by removed devices when their blocks are freed
           or remapped.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [ExtensibleDataset, DeviceRemoval],
      )
    PhysicalRewrite ->
      Attributes(
        name: "physical_rewrite",
        guid: "com.Truenas:physical_rewrite",
        description: "Support for preserving logical birth time during rewrite.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    PoolCheckpoint ->
      Attributes(
        name: "zpool_checkpoint",
        guid: "com.delphix:zpool_checkpoint",
        description: "Pool state can be checkpointed, allowing rewind later.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    ProjectQuota ->
      Attributes(
        name: "project_quota",
        guid: "org.zfsonlinux:project_quota",
        description: "space/object accounting based on project ID.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    RaidzExpansion ->
      Attributes(
        name: "raidz_expansion",
        guid: "org.openzfs:raidz_expansion",
        description: "Support for raidz expansion",
        readonly_compat: False,
        required_for_mos: True,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    RedactedDatasets ->
      Attributes(
        name: "redacted_datasets",
        guid: "com.delphix:redacted_datasets",
        description: // FIXME
        "Support for redacted datasets, produced by receiving a redacted zfs
           send stream.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    RedactionBookmarks ->
      Attributes(
        name: "redaction_bookmarks",
        guid: "com.delphix:redaction_bookmarks",
        description: // FIXME
        "Support for bookmarks which store redaction lists for zfs redacted
           send/recv.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [BookmarkV2, ExtensibleDataset, Bookmarks],
      )
    RedactionListSpill ->
      Attributes(
        name: "redaction_list_spill",
        guid: "com.delphix:redaction_list_spill",
        description: // FIXME
        "Support for increased number of redaction_snapshot arguments in zfs
           redact.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [RedactionBookmarks],
      )
    ResilverDefer ->
      Attributes(
        name: "resilver_defer",
        guid: "com.datto:resilver_defer",
        description: "Support for deferring new resilvers when one is already running.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    Sha512 ->
      Attributes(
        name: "sha512",
        guid: "org.illumos:sha512",
        description: "SHA-512/256 hash algorithm.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    Skein ->
      Attributes(
        name: "skein",
        guid: "org.illumos:skein",
        description: "Skein hash algorithm.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    SpacemapHistogram ->
      Attributes(
        name: "spacemap_histogram",
        guid: "com.delphix:spacemap_histogram",
        description: "Spacemaps maintain space histograms.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    SpacemapV2 ->
      Attributes(
        name: "spacemap_v2",
        guid: "com.delphix:spacemap_v2",
        description: "Space maps representing large segments are more efficient.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: True,
        per_dataset: False,
        no_upgrade: False,
        depends: [],
      )
    UserobjAccounting ->
      Attributes(
        name: "userobj_accounting",
        guid: "org.zfsonlinux:userobj_accounting",
        description: "User/group object accounting.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    ZilSaXattr ->
      Attributes(
        name: "zilsaxattr",
        guid: "org.openzfs:zilsaxattr",
        description: "Support for xattr=sa extended attribute logging in ZIL.",
        readonly_compat: True,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
    ZstdCompress ->
      Attributes(
        name: "zstd_compress",
        guid: "org.freebsd:zstd_compress",
        description: "zstd compression algorithm support.",
        readonly_compat: False,
        required_for_mos: False,
        activate_on_enable: False,
        per_dataset: True,
        no_upgrade: False,
        depends: [ExtensibleDataset],
      )
  }
}

pub fn to_string(feat: Feature) -> String {
  attributes(feat).name
}

// TODO: some "all_supported_features()" that uses sysctl to check version
// TODO: make the kernel module report supported features on FreeBSD
pub const all_features = [
  AllocationClasses,
  AsyncDestroy,
  AvzV2,
  Blake3,
  BlockCloning,
  //BlockCloningEndian,
  BookmarkV2,
  BookmarkWritten,
  Bookmarks,
  DeviceRebuild,
  DeviceRemoval,
  Draid,
  //DraidFailDomains,
  //DynamicGangHeader,
  Edonr,
  EmbeddedData,
  EmptyBpobj,
  EnabledTxg,
  Encryption,
  ExtensibleDataset,
  FastDedup,
  FsSsLimit,
  HeadErrlog,
  HoleBirth,
  LargeBlocks,
  LargeDnode,
  LargeMicrozap,
  Livelist,
  LogSpacemap,
  Longname,
  Lz4Compress,
  MultiVdevCrashDump,
  ObsoleteCounts,
  //PhysicalRewrite,
  PoolCheckpoint,
  ProjectQuota,
  RaidzExpansion,
  RedactedDatasets,
  RedactionBookmarks,
  RedactionListSpill,
  ResilverDefer,
  Sha512,
  Skein,
  SpacemapHistogram,
  SpacemapV2,
  UserobjAccounting,
  ZilSaXattr,
  ZstdCompress,
]
