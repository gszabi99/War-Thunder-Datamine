let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")

return function showClanPageModal(id, name, tag) {
  loadHandler(gui_handlers.clanPageModal,
    {
      clanIdStrReq = id,
      clanNameReq = name,
      clanTagReq = tag
    })
}