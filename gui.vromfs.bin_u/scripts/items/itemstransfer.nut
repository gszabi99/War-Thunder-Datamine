//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

local sendingList = {}

let function updateSendingList() {
  let newList = ::inventory_get_transfer_items_by_state(INVENTORY_STATE_SENDING)

  local isChanged = newList.len() != sendingList.len()
  if (!isChanged)
    foreach (key, _data in newList)
      if (!(key in sendingList)) {
        isChanged = true
        break
      }
  sendingList = newList
  if (isChanged)
    broadcastEvent("SendingItemsChanged")
}

addListenersWithoutEnv({
  SignOut = @(_p) sendingList.clear()
  ProfileUpdated = @(_p) updateSendingList()
  ScriptsReloaded = @(_p) ::g_login.isProfileReceived() && updateSendingList()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  getSendingList = @() sendingList
}