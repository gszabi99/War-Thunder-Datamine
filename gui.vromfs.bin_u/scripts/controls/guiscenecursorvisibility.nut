let { isMouseCursorVisible } = require("%scripts/controls/mousePointerVisibility.nut")
let { isHudVisible } = require("%scripts/hud/hudVisibility.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")

let guiSceneCursorVisible = keepref(::Computed(@() (isHudVisible.value || !isInBattleState.value)
  && isMouseCursorVisible.value))

guiSceneCursorVisible.subscribe(function(isVisible) {
  ::call_darg("updateExtWatched", { cursorVisible = isVisible })
  ::get_cur_gui_scene().showCursor(isVisible)
})

::cross_call_api.getValueGuiSceneCursorVisible <- @() guiSceneCursorVisible.value
