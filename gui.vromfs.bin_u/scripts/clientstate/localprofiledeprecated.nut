from "%globalScripts/dataBlockExt.nut" import setBlkValueByPath, getBlkValueByPath
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "%globalScripts/clientState/initialState.nut" import shouldDisableMenu
from "dagor.debug" import debug_dump_stack
from "blkGetters" import get_local_custom_settings_blk
from "%scripts/dagui_natives.nut" import get_cur_circuit_name
from "%scripts/dagui_library.nut" import *

let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getStateDebugStr } = require("%scripts/login/loginStates.nut")


function loadLocalByAccount(path, defValue = null) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings read: loadLocalByAccount at login state ",
      getStateDebugStr()))
    return defValue
  }

  let cdb = get_local_custom_settings_blk()
  let circuitName = get_cur_circuit_name()
  let id = $"{userIdStr.get()}.{circuitName}"
  local profileBlk = cdb?.accounts[id]
  if (profileBlk) {
    let value = getBlkValueByPath(profileBlk, path)
    if (value != null)
      return value
  }
  profileBlk = cdb?.accounts[userIdStr.get()]
  if (profileBlk) {
    let value = getBlkValueByPath(profileBlk, path)
    if (value != null)
      return value
  }
  return defValue
}


function saveLocalByAccount(path, value, saveFunc = saveProfile) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings read: saveLocalByAccount at login state ",
      getStateDebugStr()))
    return
  }

  let cdb = get_local_custom_settings_blk()
  let circuitName = get_cur_circuit_name()
  let id = $"{userIdStr.get()}.{circuitName}"
  if (setBlkValueByPath(cdb, $"accounts/{id}/{path}", value))
    saveFunc()
}

return {
  saveLocalByAccount
  loadLocalByAccount
}