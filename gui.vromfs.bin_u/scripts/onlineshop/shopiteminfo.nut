let json = require("json")
let http = require("dagor.http")
let { getPlayerToken } = require("auth_wt")

let ONLINE_STORE_API_URL = "https://api.gaijinent.com/item_info.php"

let function createGuidsRequestParams(guids) {
  local res = guids.reduce(@(res, guid) $"{res}guids[]={guid}&", "")
  let payment = ::steam_is_running() ? "&payment=steam" : ""
  let token = getPlayerToken() != "" ? $"&token={getPlayerToken()}" : ""
  res = $"{res}special=1{payment}{token}"
  return res
}

let function requestMultipleItems(guids, onSuccess, onFailure = null) {
  http.request({
      method = "POST"
      url = ONLINE_STORE_API_URL
      data = createGuidsRequestParams(guids)
      callback = function(response) {
        if (response.status != http.SUCCESS || !response?.body) {
          onFailure?()
          return
        }

        try {
          let body = response.body.as_string()
          ::dagor.debug($"shopItemInfo: requested [{",".join(guids)}], got\n{body}")

          if (body.len() > 6 && body.slice(0, 6) == "<html>") { //error 404 and other html pages
            ::dagor.debug(ONLINE_STORE_API_URL,
              $"ShopState: Request result is html page instead of data {ONLINE_STORE_API_URL}")
            onFailure?()
            return
          }

          let data = json.parse(body)
          if (data?.status == "OK")
            onSuccess(data)
          else
            onFailure?()
        }
        catch(e) {
          ::dagor.debug($"shopTimeInfo: failed getting [{",".join(guids)}]: {e}")
          onFailure?()
        }
      }
    })
}

return {
  requestMultipleItems
}
