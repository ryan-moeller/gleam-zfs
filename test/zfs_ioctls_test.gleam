import pprint

import zfs/ioctls

pub fn open_close_test() {
  let hdl = ioctls.open_handle()
  pprint.debug(hdl)
  ioctls.close_handle(hdl)
}

pub fn pool_list_test() {
  let hdl = ioctls.open_handle()
  pprint.debug(hdl)
  pprint.debug(ioctls.pool_configs(hdl, 0))
}
