import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%globalScripts/dataBlockExt.nut" import setBlkValueByPath, getBlkValueByPath
from "%appGlobals/login/loginState.nut" import isLoggedIn, isProfileReceived
from "%globalScripts/clientState/initialState.nut" import shouldDisableMenu
from "eventbus" import eventbus_send, eventbus_subscribe
from "scriptRespondent" import registerRespondent
from "dagor.debug" import debug_dump_stack
from "blkGetters" import get_local_custom_settings_blk, get_common_local_settings_blk, get_local_unit_settings_blk
from "%scripts/dagui_library.nut" import *

let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { getStateDebugStr } = require("%scripts/login/loginStates.nut")

const EATT_UNKNOWN = -1
const NEED_SHOW_GRAPHICS_AA_SETTINGS_MODIFIED = "need_show_msg_graphic_aa_settings_was_modified"

function onUpdateProfile(taskId, action, transactionType) {
  broadcastEvent("ProfileUpdated", { taskId, action, transactionType })

  if (!isLoggedIn.get())
    return

  broadcastEvent("RequestUpdateGamercards")
  eventbus_send("request_show_banned_status_msgbox", {showBanOnly = true})
}


let onRefreshProfileOnLogin = @() broadcastEvent("RefreshProfileOnLogin")

registerRespondent("onUpdateProfile", onUpdateProfile) 
registerRespondent("onRefreshProfileOnLogin", onRefreshProfileOnLogin) 

eventbus_subscribe("onUpdateProfile", function(msg) {
  let { taskId = -1, action = "", transactionType = EATT_UNKNOWN } = msg
  onUpdateProfile(taskId, action, transactionType)
})

eventbus_subscribe("onRefreshProfileOnLogin", @(_) onRefreshProfileOnLogin())
registerRespondent("onBlksDataStorageLoaded", @() broadcastEvent("BlksDataStorageLoaded"))


function saveLocalAccountSettings(path, value) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings write: saveLocalAccountSettings at login state ",
      getStateDebugStr()))
    return
  }

  let cdb = get_local_custom_settings_blk()
  if (setBlkValueByPath(cdb, path, value))
    saveProfile()
}

function loadLocalAccountSettings(path, defValue = null) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings read: loadLocalAccountSettings at login state ",
      getStateDebugStr()))
    return defValue
  }

  let cdb = get_local_custom_settings_blk()
  return getBlkValueByPath(cdb, path, defValue)
}

let getRandUnitOptPath = @(unitName, optName, groupIndex = null) "".concat(
  unitName
  "/paramsForRandomUnit/"
  optName
  groupIndex == null ? "" : groupIndex
)

function saveLocalUnitSettings(path, value) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings write: saveLocalUnitSettings at login state ",
      getStateDebugStr()))
    return
  }

  let cdb = get_local_unit_settings_blk()
  if (setBlkValueByPath(cdb, path, value))
    saveProfile()
}

function loadLocalUnitSettings(path, defValue = null) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings read: loadLocalUnitSettings at login state ",
      getStateDebugStr()))
    return defValue
  }

  let cdb = get_local_unit_settings_blk()
  return getBlkValueByPath(cdb, path, defValue)
}


function saveLocalSharedSettings(path, value) {
  let blk = get_common_local_settings_blk()
  if (setBlkValueByPath(blk, path, value))
    saveProfile()
}

function loadLocalSharedSettings(path, defValue = null) {
  let blk = get_common_local_settings_blk()
  return getBlkValueByPath(blk, path, defValue)
}

let getRootSizeText = @() "{0}x{1}".subst(screen_width(), screen_height())


function loadLocalByScreenSize(name, defValue = null) {
  if (!isProfileReceived.get())
    return defValue

  let rootName = getRootSizeText()
  let cdb = get_local_custom_settings_blk()
  if (cdb?[rootName][name])
    return cdb[rootName][name]

  return defValue
}

function saveLocalByScreenSize(name, value) {
  if (!isProfileReceived.get())
    return

  let rootName = getRootSizeText()
  let cdb = get_local_custom_settings_blk()
  if (cdb?[rootName] != null && type(cdb[rootName]) != "instance")
    cdb[rootName] = null
  if (cdb?[rootName] == null)
    cdb[rootName] = DataBlock()
  if (cdb?[rootName][name] == null)
    cdb[rootName][name] = value
  else if (cdb[rootName][name] == value)
    return  
  else
    cdb[rootName][name] = value

  saveProfile()
}



function clearLocalByScreenSize(name) {
  if (!isProfileReceived.get())
    return

  let cdb = get_local_custom_settings_blk()
  local hasChanges = false
  for (local idx = cdb.blockCount() - 1; idx >= 0; idx--) {
    let blk = cdb.getBlock(idx)
    if (!(name in blk))
      continue

    hasChanges = true
    if (u.isDataBlock(blk?[name]))
      blk.removeBlock(name)
    else
      blk.removeParam(name)

    if (!blk.blockCount() && !blk.paramCount())
      cdb.removeBlockById(idx)
  }
  if (hasChanges)
    saveProfile()
}

return {
  saveLocalSharedSettings
  loadLocalSharedSettings
  saveLocalAccountSettings
  loadLocalAccountSettings
  saveLocalByScreenSize
  loadLocalByScreenSize
  clearLocalByScreenSize
  NEED_SHOW_GRAPHICS_AA_SETTINGS_MODIFIED
  getRandUnitOptPath
  loadLocalUnitSettings
  saveLocalUnitSettings
}