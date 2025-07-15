from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { registerRespondent } = require("scriptRespondent")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { setBlkValueByPath, getBlkValueByPath } = require("%globalScripts/dataBlockExt.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { debug_dump_stack } = require("dagor.debug")
let DataBlock = require("DataBlock")
let { get_local_custom_settings_blk, get_common_local_settings_blk } = require("blkGetters")
let { getStateDebugStr } = require("%scripts/login/loginStates.nut")
let { isLoggedIn, isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { shouldDisableMenu } = require("%globalScripts/clientState/initialState.nut")

const EATT_UNKNOWN = -1

function onUpdateProfile(taskId, action, transactionType) {
  broadcastEvent("ProfileUpdated", { taskId, action, transactionType })

  if (!isLoggedIn.get())
    return

  ::update_gamercards()
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
}