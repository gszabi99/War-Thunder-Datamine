from "%scripts/dagui_natives.nut" import inventory_get_transfer_items_by_state
from "%scripts/dagui_library.nut" import *
from "dagor.workcycle" import deferOnce
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

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

if (isProfileReceived.get())
  deferOnce(updateSendingList)

addListenersWithoutEnv({
  SignOut = @(_p) sendingList.clear()
  ProfileUpdated = @(_p) updateSendingList()
}, g_listener_priority.CONFIG_VALIDATION)

return {
  getSendingList = @() sendingList
}