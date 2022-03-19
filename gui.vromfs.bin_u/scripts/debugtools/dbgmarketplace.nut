/**
 *  Shows a preview wnd for workshop set, which is shown to users only once.
 *  Those previews are defined in 'eventPreview' blocks in workshop.blk.
 *
 *  @params {string} id - Block name from workshop.blk file root.
 *
**/

::debug_show_workshop_event_preview <- function debug_show_workshop_event_preview(id)
{
  local workshopPreview = require("scripts/items/workshop/workshopPreview.nut")
  local workshop = require("scripts/items/workshop/workshop.nut")
  local ws = workshop.getSetById(id)
  if (!ws)
    return "Workshop set not found"
  if (!ws.hasPreview())
    return "Workshop set has no eventPreview block"

  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.WorkshopPreview)
  if (handler) {
    handler.goBack()
    ::get_cur_base_gui_handler().guiScene.performDelayed(this, @() workshopPreview.open(ws))
  }
  else
    workshopPreview.open(ws)
  return "Success"
}
