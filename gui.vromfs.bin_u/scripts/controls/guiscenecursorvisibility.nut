import "%scripts/global/updateExtWatched.nut" as updateExtWatched
from "%scripts/controls/mousePointerVisibility.nut" import isMouseCursorVisible, forceHideCursor
from "%scripts/hud/hudVisibility.nut" import needShowHud
from "%scripts/dagui_library.nut" import *
from "dagui" import set_cursor_visibility

let guiSceneCursorVisible = keepref(Computed(@() needShowHud.get()
  && isMouseCursorVisible.get() && !forceHideCursor.get()))

function onGuiSceneCursorVisible(isVisible) {
  updateExtWatched({ cursorVisible = isVisible })
  get_cur_gui_scene()?.showCursor(isVisible)
  set_cursor_visibility(isVisible)
}

guiSceneCursorVisible.subscribe(onGuiSceneCursorVisible)
onGuiSceneCursorVisible(guiSceneCursorVisible.get())
