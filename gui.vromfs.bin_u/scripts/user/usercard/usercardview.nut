from "dagor.workcycle" import defer
from "%scripts/dagui_library.nut" import *

let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")

function gui_modal_userCard(playerInfo) {  
  if (!hasFeature("UserCards"))
    return
  let guiScene = get_gui_scene()
  if (guiScene?.isInAct()) {
    defer(@() loadHandler(get_gui_handler("UserCardHandler"), { info = playerInfo }))
    return
  }
  loadHandler(get_gui_handler("UserCardHandler"), { info = playerInfo })
}

return {
  gui_modal_userCard
}