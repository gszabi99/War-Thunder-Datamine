from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { isMouseCursorVisible, forceHideCursor } = require("%scripts/controls/mousePointerVisibility.nut")
let { isHudVisible } = require("%scripts/hud/hudVisibility.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { subscribe, send } = require("eventbus")

let guiSceneCursorVisible = keepref(Computed(@() (isHudVisible.value || !isInBattleState.value)
  && isMouseCursorVisible.value && !forceHideCursor.value))

let function onGuiSceneCursorVisible(isVisible) {
  send("updateExtWatched", { cursorVisible = isVisible })
  ::get_cur_gui_scene()?.showCursor(isVisible)
}

guiSceneCursorVisible.subscribe(onGuiSceneCursorVisible)
onGuiSceneCursorVisible(guiSceneCursorVisible.value)

subscribe("updateGuiSceneCursorVisible",
  @(_) send("updateExtWatched", { cursorVisible = guiSceneCursorVisible.value }))
