from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "dagor.http" import httpRequest
from "auth_wt" import getPlayerToken
from "steam" import steam_is_running
from "%scripts/dagui_library.nut" import *

let ONLINE_STORE_API_URL = getCurCircuitOverride("onlineStoreApiURL", "https://api.gaijinent.com/item_info.php")

function createGuidsRequestParams(guids) {
  local res = guids.reduce(@(r, guid) $"{r}guids[]={guid}&", "")
  let payment = steam_is_running() ? "&payment=steam" : ""
  let token = getPlayerToken() != "" ? $"&jwt={getPlayerToken()}" : ""
  res = $"{res}special=1{payment}{token}"
  return res
}

function requestMultipleItems(guids, onSuccessEventName) {
  httpRequest({
    method = "POST"
    url = ONLINE_STORE_API_URL
    data = createGuidsRequestParams(guids)
    respEventId = onSuccessEventName
    context = guids
  })
}

return {
  requestMultipleItems
}