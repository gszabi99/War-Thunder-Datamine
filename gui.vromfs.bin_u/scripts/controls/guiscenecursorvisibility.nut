local { isMouseCursorVisible } = require("scripts/controls/mousePointerVisibility.nut")
local { isHudVisible } = require("scripts/hud/hudVisibility.nut")

local guiSceneCursorVisible = keepref(::Computed(@() isHudVisible.value && isMouseCursorVisible.value))

guiSceneCursorVisible.subscribe(function(isVisible) {
  ::call_darg("updateExtWatched", { cursorVisible = isVisible })
  ::get_cur_gui_scene().showCursor(isVisible)
})

::cross_call_api.getValueGuiSceneCursorVisible <- @() guiSceneCursorVisible.value
