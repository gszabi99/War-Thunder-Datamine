from "%scripts/dagui_natives.nut" import is_cursor_visible_in_gui, is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *












let { isMouseCursorVisible } = require("%scripts/controls/mousePointerVisibility.nut")
let { get_time_msec } = require("dagor.time")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

const MOUSE_POINTER_SHOWN_RECENTLY_MS = 250

local lastMousePointerTimeShow = -1
local lastMousePointerTimeHide = -1

isMouseCursorVisible.subscribe(function(isVisible) {
  let now = get_time_msec()
  if (isVisible)
    lastMousePointerTimeShow = now
  else
    lastMousePointerTimeHide = now
})

function setMousePointerInitialPos(obj) {
  let now = get_time_msec()
  let isMouseMode = !showConsoleButtons.value || is_mouse_last_time_used()
  let isCursorVisible = is_cursor_visible_in_gui()

  if (isMouseMode && isCursorVisible && now > lastMousePointerTimeShow + MOUSE_POINTER_SHOWN_RECENTLY_MS)
    return false
  if (isMouseMode && !isCursorVisible && now < lastMousePointerTimeHide + MOUSE_POINTER_SHOWN_RECENTLY_MS)
    return false
  if (!obj?.isValid())
    return false

  if (obj?.setMouseCursorOnObjectInitial != null)
    obj.setMouseCursorOnObjectInitial()
  else
    obj.setMouseCursorOnObject()
  return true
}

function setMousePointerInitialPosOnChildByValue(obj) {
  let idx = obj?.isValid() ? obj.getValue() : -1
  if (idx < 0 || idx >= obj.childrenCount())
    return false
  return setMousePointerInitialPos(obj.getChild(idx))
}

return {
  setMousePointerInitialPos
  setMousePointerInitialPosOnChildByValue
}
