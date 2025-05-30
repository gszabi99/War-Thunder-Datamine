from "%scripts/dagui_natives.nut" import is_online_available, update_entitlements
let { get_time_msec } = require("dagor.time")

local lastUpdateTime = get_time_msec()

function getUpdateEntitlementsTimeoutMsec() {
  return lastUpdateTime - get_time_msec() + 20000
}

function updateEntitlementsLimited(force = false) {
  if (!is_online_available())
    return -1
  if (force || getUpdateEntitlementsTimeoutMsec() < 0) {
    lastUpdateTime = get_time_msec()
    return update_entitlements()
  }
  return -1
}

return {
  getUpdateEntitlementsTimeoutMsec
  updateEntitlementsLimited
}