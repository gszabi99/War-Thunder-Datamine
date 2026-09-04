from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import is_cursor_visible_in_gui
from "%scripts/dagui_library.nut" import *








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
