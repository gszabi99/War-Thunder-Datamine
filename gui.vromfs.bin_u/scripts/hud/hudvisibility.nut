//checked for plus_string
from "%scripts/dagui_natives.nut" import is_hud_visible
from "%scripts/dagui_library.nut" import *

let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let isHudVisible = Watched(is_hud_visible())

// Called from client
::on_show_hud <- function on_show_hud(show = true) {
  isHudVisible(show)
  handlersManager.getActiveBaseHandler()?.onShowHud(show, true)
  broadcastEvent("ShowHud", { show = show })
}

return {
  isHudVisible
}
