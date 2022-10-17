from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

/**
 * Sets an initial mouse pointer pos for a scenes just opened from HUD, because
 * otherwise on PC (where GamepadCursorControls are off) mouse pointer can be
 * located in any random place of the screen. This mouse pos setting should
 * always work for consoles (and can be used as move_mouse_on_obj()), but on
 * PC it works only when mouse pointer was shown recently, or is still invisible
 * (usually it becomes visible little bit later, after GUI scene initialization).
 * When mouse pointer is hidden or displayed recently, it usually means that
 * GUI scene is opened from HUD, where mouse pointer was invisible.
 */

let { isMouseCursorVisible } = require("%scripts/controls/mousePointerVisibility.nut")

const MOUSE_POINTER_SHOWN_RECENTLY_MS = 250

local lastMousePointerTimeShow = -1
local lastMousePointerTimeHide = -1

isMouseCursorVisible.subscribe(function(isVisible) {
  let now = ::dagor.getCurTime()
  if (isVisible)
    lastMousePointerTimeShow = now
  else
    lastMousePointerTimeHide = now
})

let function setMousePointerInitialPos(obj)
{
  let now = ::dagor.getCurTime()
  let isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  let isCursorVisible = ::is_cursor_visible_in_gui()

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

let function setMousePointerInitialPosOnChildByValue(obj)
{
  let idx = obj?.isValid() ? obj.getValue() : -1
  if (idx < 0 || idx >= obj.childrenCount())
    return false
  return setMousePointerInitialPos(obj.getChild(idx))
}

return {
  setMousePointerInitialPos
  setMousePointerInitialPosOnChildByValue
}
