from "%sqDagui/daguiNativeApi.nut" import *

let { loc } = require("dagor.localize")
let { check_obj } = require("%sqDagui/daguiUtil.nut")
let { eventbus_send } = require("eventbus")

function open_url_by_obj(obj) {
  if (!check_obj(obj) || obj?.link == null || obj?.link == "")
    return

  let baseUrl = (obj.link.slice(0, 1) == "#") ? loc(obj.link.slice(1)) : obj.link
  eventbus_send("open_url", { baseUrl, biqQueryKey = obj?.bqKey ?? obj?.id })
}

return { open_url_by_obj }