local { showConsoleButtons } = require("reactiveGui/ctrlsState.nut")

local focusBorder = @(override = {})
  @() {
    size = flex()
    watch = showConsoleButtons
    children = showConsoleButtons.value
      ? {
        rendObj = ROBJ_9RECT
        size = flex()
        image = ::Picture("!ui/gameuiskin#item_selection")
        color = Color(255, 211, 75)
        screenOffs = 8
        texOffs = 8
      }
      : null
  }.__update(override)

return focusBorder
