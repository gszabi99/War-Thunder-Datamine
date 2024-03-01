from "%scripts/dagui_natives.nut" import inventory_get_transfer_items_by_state
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

local sendingList = {}

function updateSendingList() {
  let newList = inventory_get_transfer_items_by_state(INVENTORY_STATE_SENDING)

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
}, g_listener_priority.CONFIG_VALIDATION)

return {
  getSendingList = @() sendingList
}