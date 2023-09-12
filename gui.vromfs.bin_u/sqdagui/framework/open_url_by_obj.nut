from "%sqDagui/daguiNativeApi.nut" import *

let { loc } = require("dagor.localize")
let { check_obj } = require("%sqDagui/daguiUtil.nut")

let function open_url_by_obj(obj) {
  if (!check_obj(obj) || obj?.link == null || obj?.link == "")
    return
  let open_url = getroottable()?["open_url"]
  if (!open_url)
    return

  let link = (obj.link.slice(0, 1) == "#") ? loc(obj.link.slice(1)) : obj.link
  open_url(link, false, false, obj?.bqKey ?? obj?.id)
}

return { open_url_by_obj }