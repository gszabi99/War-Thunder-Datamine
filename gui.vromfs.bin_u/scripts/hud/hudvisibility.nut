//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let isHudVisible = Watched(::is_hud_visible())

// Called from client
::on_show_hud <- function on_show_hud(show = true) {
  isHudVisible(show)
  ::handlersManager.getActiveBaseHandler()?.onShowHud(show, true)
  ::broadcastEvent("ShowHud", { show = show })
}

return {
  isHudVisible
}
