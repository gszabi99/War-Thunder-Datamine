from "%scripts/dagui_library.nut" import *
let { defer } = require("dagor.workcycle")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")

function gui_modal_userCard(playerInfo) {  
  if (!hasFeature("UserCards"))
    return
  let guiScene = get_gui_scene()
  if (guiScene?.isInAct()) {
    defer(@() loadHandler(gui_handlers.UserCardHandler, { info = playerInfo }))
    return
  }
  loadHandler(gui_handlers.UserCardHandler, { info = playerInfo })
}

return {
  gui_modal_userCard
}