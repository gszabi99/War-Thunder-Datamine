from "%scripts/dagui_natives.nut" import get_cur_circuit_name
from "%scripts/dagui_library.nut" import *

let { setBlkValueByPath, getBlkValueByPath } = require("%globalScripts/dataBlockExt.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { debug_dump_stack } = require("dagor.debug")
let { get_local_custom_settings_blk } = require("blkGetters")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getStateDebugStr } = require("%scripts/login/loginStates.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

// Deprecated, for storing new data use loadLocalAccountSettings() instead.
function loadLocalByAccount(path, defValue = null) {
  if (!::should_disable_menu() && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings read: loadLocalByAccount at login state ",
      getStateDebugStr()))
    return defValue
  }

  let cdb = get_local_custom_settings_blk()
  let circuitName = get_cur_circuit_name()
  let id = $"{userIdStr.value}.{circuitName}"
  local profileBlk = cdb?.accounts[id]
  if (profileBlk) {
    let value = getBlkValueByPath(profileBlk, path)
    if (value != null)
      return value
  }
  profileBlk = cdb?.accounts[userIdStr.value]
  if (profileBlk) {
    let value = getBlkValueByPath(profileBlk, path)
    if (value != null)
      return value
  }
  return defValue
}

// Deprecated, for storing new data use saveLocalAccountSettings() instead.
function saveLocalByAccount(path, value, saveFunc = saveProfile) {
  if (!::should_disable_menu() && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings read: saveLocalByAccount at login state ",
      getStateDebugStr()))
    return
  }

  let cdb = get_local_custom_settings_blk()
  let circuitName = get_cur_circuit_name()
  let id = $"{userIdStr.value}.{circuitName}"
  if (setBlkValueByPath(cdb, $"accounts/{id}/{path}", value))
    saveFunc()
}

return {
  saveLocalByAccount
  loadLocalByAccount
}