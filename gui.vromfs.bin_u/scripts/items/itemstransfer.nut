from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")

local sendingList = {}

let function updateSendingList()
{
  let newList = ::inventory_get_transfer_items_by_state(INVENTORY_STATE_SENDING)

  local isChanged = newList.len() != sendingList.len()
  if (!isChanged)
    foreach(key, _data in newList)
      if (!(key in sendingList))
      {
        isChanged = true
        break
      }
  sendingList = newList
  if (isChanged)
    ::broadcastEvent("SendingItemsChanged")
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) sendingList.clear()
  ProfileUpdated = @(_p) updateSendingList()
  ScriptsReloaded = @(_p) ::g_login.isProfileReceived() && updateSendingList()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  getSendingList = @() sendingList
}