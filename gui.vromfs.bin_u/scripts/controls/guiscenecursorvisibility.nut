from "%scripts/dagui_library.nut" import *
from "dagui" import set_cursor_visibility
let { isMouseCursorVisible, forceHideCursor } = require("%scripts/controls/mousePointerVisibility.nut")
let { needShowHud } = require("%scripts/hud/hudVisibility.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")

let guiSceneCursorVisible = keepref(Computed(@() needShowHud.get()
  && isMouseCursorVisible.get() && !forceHideCursor.get()))

function onGuiSceneCursorVisible(isVisible) {
  updateExtWatched({ cursorVisible = isVisible })
  get_cur_gui_scene()?.showCursor(isVisible)
  set_cursor_visibility(isVisible)
}

guiSceneCursorVisible.subscribe(onGuiSceneCursorVisible)
onGuiSceneCursorVisible(guiSceneCursorVisible.get())
