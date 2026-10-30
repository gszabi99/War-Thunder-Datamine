from "console" import register_command
from "%sqstd/globalState.nut" import hardPersistWatched
from "%rGui/globals/ui_library.nut" import *

let testBackgroundColor = hardPersistWatched("rGui.testBackgroundColor", null)

register_command(@(color) testBackgroundColor.set(color), "ui.test_background",
  "a solid color (decimal ARGB, 4278190080 = black) under the whole GUI, for screenshot tests; null = off")

let testBackground = @() {
  watch = testBackgroundColor
  size = FLEX
  rendObj = testBackgroundColor.get() == null ? null : ROBJ_SOLID
  color = testBackgroundColor.get()
}

return testBackground
