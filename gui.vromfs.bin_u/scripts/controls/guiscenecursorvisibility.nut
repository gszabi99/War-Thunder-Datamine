from "%scripts/dagui_library.nut" import *

let { isMouseCursorVisible, forceHideCursor } = require("%scripts/controls/mousePointerVisibility.nut")
let { isHudVisible } = require("%scripts/hud/hudVisibility.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")

let guiSceneCursorVisible = keepref(Computed(@() (isHudVisible.get() || !isInBattleState.get())
  && isMouseCursorVisible.get() && !forceHideCursor.get()))

function onGuiSceneCursorVisible(isVisible) {
  updateExtWatched({ cursorVisible = isVisible })
  get_cur_gui_scene()?.showCursor(isVisible)
}

guiSceneCursorVisible.subscribe(onGuiSceneCursorVisible)
onGuiSceneCursorVisible(guiSceneCursorVisible.get())
