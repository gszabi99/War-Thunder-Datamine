from "%scripts/dagui_library.nut" import *

let { httpRequest } = require("dagor.http")
let { getPlayerToken } = require("auth_wt")
let { steam_is_running } = require("steam")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")

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