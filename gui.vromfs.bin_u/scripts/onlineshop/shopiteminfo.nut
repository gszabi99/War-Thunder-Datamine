local json = require("json")
local http = require("dagor.http")

local ONLINE_STORE_API_URL = "https://api.gaijinent.com/item_info.php"

local function requestMultipleItems(guids, onSuccess, params = {}) {
  local arguments = guids.reduce(@(res, guid) $"{res}guids[]={guid}&", "")
  arguments = arguments.slice(0, arguments.len()-1)
  foreach (k,v in params) {
    if (typeof(v) == "bool")
      arguments = $"{arguments}&{k}={v ? "1" : "0"}"
    else
      arguments = $"{arguments}&{k}={v}"
  }

  http.request({
      method = "POST"
      url = ONLINE_STORE_API_URL
      data = arguments
      callback = function(response) {
        if (response.status != http.SUCCESS || !response?.body)
          return

        try {
          local body = response.body.tostring()
          ::dagor.debug($"shopItemInfo: requested [{",".join(guids)}], got\n{body}")
          local data = json.parse(body)
          if (data?.status == "OK")
            onSuccess(data)
        }
        catch(e) { ::dagor.debug($"shopTimeInfo: failed getting [{",".join(guids)}]: {e}") }
      }
    })
}

return {
  requestMultipleItems = requestMultipleItems
}
