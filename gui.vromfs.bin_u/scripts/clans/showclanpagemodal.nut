let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")

return function showClanPageModal(id, name, tag) {
  loadHandler(get_gui_handler("clanPageModal"),
    {
      clanIdStrReq = id,
      clanNameReq = name,
      clanTagReq = tag
    })
}