//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
/**
 * Informs when in-game mouse pointer visibility toggles. In the battle, mouse
 * pointer is usually hidden in HUD, it shows either when some GUI scene is opened
 * (like MpStatistics, TacticalMap, Respawn, etc.), or when player holds the
 * ID_SHOW_MOUSE_CURSOR shortcut button.
 */

let isMouseCursorVisible = Watched(::is_cursor_visible_in_gui())
let forceHideCursor = Watched(false)
// Called from client
::on_changed_cursor_visibility <- @(_oldValue) isMouseCursorVisible(::is_cursor_visible_in_gui())

isMouseCursorVisible.subscribe(function(isVisible) {
  broadcastEvent("ChangedCursorVisibility", { isVisible = isVisible })
})

return {
  isMouseCursorVisible
  forceHideCursor
}
