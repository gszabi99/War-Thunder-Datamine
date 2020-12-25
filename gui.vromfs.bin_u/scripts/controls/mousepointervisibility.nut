/**
 * Informs when in-game mouse pointer visibility toggles. In the battle, mouse
 * pointer is usually hidden in HUD, it shows either when some GUI scene is opened
 * (like MpStatistics, TacticalMap, Respawn, etc.), or when player holds the
 * ID_SHOW_MOUSE_CURSOR shortcut button.
 */

local isMouseCursorVisible = ::Watched(::is_cursor_visible_in_gui())

// Called from client
::on_changed_cursor_visibility <- @(oldValue) isMouseCursorVisible(::is_cursor_visible_in_gui())

isMouseCursorVisible.subscribe(function(isVisible) {
  ::broadcastEvent("ChangedCursorVisibility", { isVisible = isVisible })
  ::call_darg("hudCursorVisibleUpdate", isVisible)
})

return {
  isMouseCursorVisible
}
