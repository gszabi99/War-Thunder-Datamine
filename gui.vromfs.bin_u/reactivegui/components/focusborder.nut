from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%rGui/globals/ui_library.nut" import *

let focusBorder = @(override = {})
  @() {
    size = FLEX
    watch = showConsoleButtons
    children = showConsoleButtons.get()
      ? {
        rendObj = ROBJ_9RECT
        size = FLEX
        image = Picture("!ui/gameuiskin#item_selection")
        color = Color(255, 211, 75)
        screenOffs = 8
        texOffs = 8
      }
      : null
  }.__update(override)

return focusBorder
