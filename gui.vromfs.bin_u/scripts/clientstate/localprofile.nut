import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%scripts/clientState/saveProfile.nut" import saveProfile
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/login/loginState.nut" import hasFullLoginState, isProfileReceived
from "eventbus" import eventbus_send, eventbus_subscribe
from "scriptRespondent" import registerRespondent
from "blkGetters" import get_local_custom_settings_blk
from "%scripts/dagui_library.nut" import *

const EATT_UNKNOWN = -1

function onUpdateProfile(taskId, action, transactionType) {
  broadcastEvent("ProfileUpdated", { taskId, action, transactionType })

  if (!hasFullLoginState.get())
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

return freeze({
  saveLocalByScreenSize
  loadLocalByScreenSize
  clearLocalByScreenSize
})
