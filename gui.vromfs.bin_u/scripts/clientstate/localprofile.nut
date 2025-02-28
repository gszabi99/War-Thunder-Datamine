from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { setBlkValueByPath, getBlkValueByPath } = require("%globalScripts/dataBlockExt.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { debug_dump_stack } = require("dagor.debug")
let DataBlock = require("DataBlock")
let { get_local_custom_settings_blk, get_common_local_settings_blk } = require("blkGetters")
let { getStateDebugStr } = require("%scripts/login/loginStates.nut")
let { isLoggedIn, isProfileReceived } = require("%appGlobals/login/loginState.nut")

const EATT_UNKNOWN = -1

eventbus_subscribe("onUpdateProfile", function(msg) {
  let { taskId = -1, action = "", transactionType = EATT_UNKNOWN } = msg
  broadcastEvent("ProfileUpdated", { taskId, action, transactionType })

  if (!isLoggedIn.get())
    return

  ::update_gamercards()
  eventbus_send("request_show_banned_status_msgbox", {showBanOnly = true})
})

//save/load settings by account. work only after local profile received from host.
function saveLocalAccountSettings(path, value) {
  if (!::should_disable_menu() && !isProfileReceived.get()) {
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
  if (!::should_disable_menu() && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings read: loadLocalAccountSettings at login state ",
      getStateDebugStr()))
    return defValue
  }

  let cdb = get_local_custom_settings_blk()
  return getBlkValueByPath(cdb, path, defValue)
}

//save/load setting to local profile, not depend on account, so can be usable before login.
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

//save/load settings by account and by screenSize
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
    return  //no need save when no changes
  else
    cdb[rootName][name] = value

  saveProfile()
}

//remove all data by screen size from all size blocks
//also clear empty size blocks
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
}