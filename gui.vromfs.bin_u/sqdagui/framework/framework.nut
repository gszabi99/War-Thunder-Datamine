::gui_handlers <- {}

global enum handlerType
{
  ROOT    //root handler dosn't destroy on switch between base handlers. Share object where to create base handlers
  BASE    //main handler ingame. can be active only one at time.
  MODAL   //opened in modal window, auto destroys on switch base handler
  CUSTOM  //handler created in custom object. usualy has parent handler, because it not full scene handler.

  ANY
}

foreach (fn in [
                 "msgBox.nut"
                 "baseGuiHandler.nut"
                 "baseGuiHandlerManager.nut"
                 "framedMessageBox.nut"
               ])
  ::g_script_reloader.loadOnce("sqDagui/framework/" + fn)


::open_url_by_obj <- function open_url_by_obj(obj)
{
  if (!check_obj(obj) || obj?.link == null || obj?.link == "")
    return
  if (!("open_url" in getroottable()))
    return

  local link = (obj.link.slice(0, 1) == "#") ? ::loc(obj.link.slice(1)) : obj.link
  ::open_url(link, false, false, obj?.bqKey ?? obj?.id)
}