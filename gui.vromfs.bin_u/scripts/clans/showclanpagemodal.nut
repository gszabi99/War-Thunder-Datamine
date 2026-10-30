from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler

return function showClanPageModal(id, name, tag) {
  loadHandler(get_gui_handler("clanPageModal"),
    {
      clanIdStrReq = id,
      clanNameReq = name,
      clanTagReq = tag
    })
}