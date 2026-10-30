from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "dagor.workcycle" import defer
from "%scripts/dagui_library.nut" import *

function gui_modal_userCard(playerInfo) {  
  let guiScene = get_gui_scene()
  if (guiScene?.isInAct()) {
    defer(@() loadHandler(get_gui_handler("UserCardHandler"), { info = playerInfo }))
    return
  }
  loadHandler(get_gui_handler("UserCardHandler"), { info = playerInfo })
}

return freeze({
  gui_modal_userCard
})