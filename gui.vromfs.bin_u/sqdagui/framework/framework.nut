#explicit-this
#no-root-fallback

let { loc } = require("dagor.localize")
let { check_obj } = require("%sqDagui/daguiUtil.nut")
::gui_handlers <- {}

foreach (fn in [
                 "msgBox.nut"
                 "baseGuiHandler.nut"
                 "baseGuiHandlerManager.nut"
                 "framedMessageBox.nut"
               ])
  ::g_script_reloader.loadOnce("%sqDagui/framework/" + fn)


::open_url_by_obj <- function open_url_by_obj(obj)
{
  if (!check_obj(obj) || obj?.link == null || obj?.link == "")
    return
  if (!("open_url" in getroottable()))
    return

  let link = (obj.link.slice(0, 1) == "#") ? loc(obj.link.slice(1)) : obj.link
  ::open_url(link, false, false, obj?.bqKey ?? obj?.id)
}