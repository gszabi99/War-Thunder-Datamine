from "%scripts/sqDagui/daguiUtil.nut" import check_obj
from "dagor.localize" import loc
from "eventbus" import eventbus_send
from "%scripts/sqDagui/daguiNativeApi.nut" import *

function open_url_by_obj(obj) {
  if (!check_obj(obj) || obj?.link == null || obj?.link == "")
    return

  let baseUrl = (obj.link.slice(0, 1) == "#") ? loc(obj.link.slice(1)) : obj.link
  eventbus_send("open_url", {
    baseUrl
    biqQueryKey = obj?.bqKey ?? obj?.id
    forceExternal = obj?.forceExternal == "yes"
  })
}

return freeze({ open_url_by_obj })