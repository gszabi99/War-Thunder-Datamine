from "%scripts/dagui_library.nut" import *

let { parse_json } = require("json")
let { httpRequest, HTTP_SUCCESS } = require("dagor.http")
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

function requestMultipleItems(guids, onSuccess, onFailure = null) {
  httpRequest({
      method = "POST"
      url = ONLINE_STORE_API_URL
      data = createGuidsRequestParams(guids)
      callback = function(response) {
        if (response.status != HTTP_SUCCESS || !response?.body) {
          onFailure?()
          return
        }

        try {
          let body = response.body.as_string()
          log($"shopItemInfo: requested successfully")

          if (body.len() > 6 && body.slice(0, 6) == "<html>") { 
            log(ONLINE_STORE_API_URL,
              $"ShopState: Request result is html page instead of data {ONLINE_STORE_API_URL}")
            onFailure?()
            return
          }

          let data = parse_json(body)
          if (data?.status == "OK")
            onSuccess(data)
          else
            onFailure?()
        }
        catch(e) {
          log($"shopTimeInfo: failed getting: {e}")
          onFailure?()
        }
      }
    })
}

return {
  requestMultipleItems
}
