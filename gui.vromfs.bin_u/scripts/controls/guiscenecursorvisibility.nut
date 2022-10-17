let { isMouseCursorVisible, forceHideCursor } = require("%scripts/controls/mousePointerVisibility.nut")
let { isHudVisible } = require("%scripts/hud/hudVisibility.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")

let guiSceneCursorVisible = keepref(::Computed(@() (isHudVisible.value || !isInBattleState.value)
  && isMouseCursorVisible.value && !forceHideCursor.value))

let function onGuiSceneCursorVisible(isVisible) {
  ::call_darg("updateExtWatched", { cursorVisible = isVisible })
  ::get_cur_gui_scene()?.showCursor(isVisible)
}

guiSceneCursorVisible.subscribe(onGuiSceneCursorVisible)
onGuiSceneCursorVisible(guiSceneCursorVisible.value)

::cross_call_api.getValueGuiSceneCursorVisible <- @() guiSceneCursorVisible.value