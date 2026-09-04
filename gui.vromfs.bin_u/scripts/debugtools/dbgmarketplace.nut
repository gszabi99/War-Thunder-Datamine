from "console" import register_command
from "%scripts/dagui_library.nut" import *

let { WorkshopPreview } = require("%scripts/items/workshop/workshopPreview.nut")
let { handlersManager, get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")









function debug_show_workshop_event_preview(id) {
  let workshopPreview = require("%scripts/items/workshop/workshopPreview.nut")
  let workshop = require("%scripts/items/workshop/workshop.nut")
  let ws = workshop.getSetById(id)
  if (!ws)
    return "Workshop set not found"
  if (!ws.hasPreview())
    return "Workshop set has no eventPreview block"

  let handler = handlersManager.findHandlerClassInScene(WorkshopPreview)
  if (handler) {
    handler.goBack()
    get_cur_base_gui_handler().guiScene.performDelayed(this, @() workshopPreview.open(ws))
  }
  else
    workshopPreview.open(ws)
  return "Success"
}

register_command(debug_show_workshop_event_preview, "debug.show_workshop_event_preview")
