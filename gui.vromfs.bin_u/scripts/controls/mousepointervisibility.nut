from "%scripts/dagui_natives.nut" import is_cursor_visible_in_gui
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
/**
 * Informs when in-game mouse pointer visibility toggles. In the battle, mouse
 * pointer is usually hidden in HUD, it shows either when some GUI scene is opened
 * (like MpStatistics, TacticalMap, Respawn, etc.), or when player holds the
 * ID_SHOW_MOUSE_CURSOR shortcut button.
 */

let isMouseCursorVisible = Watched(is_cursor_visible_in_gui())
let forceHideCursor = Watched(false)
eventbus_subscribe("on_changed_cursor_visibility", @(...) isMouseCursorVisible.set(is_cursor_visible_in_gui()))

isMouseCursorVisible.subscribe(function(isVisible) {
  broadcastEvent("ChangedCursorVisibility", { isVisible = isVisible })
})

return {
  isMouseCursorVisible
  forceHideCursor
}
