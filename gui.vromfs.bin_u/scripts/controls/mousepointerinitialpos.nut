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

local { isMouseCursorVisible } = require("scripts/controls/mousePointerVisibility.nut")

const MOUSE_POINTER_SHOWN_RECENTLY_MS = 250

local lastMousePointerTimeShow = -1
local lastMousePointerTimeHide = -1

isMouseCursorVisible.subscribe(function(isVisible) {
  local now = ::dagor.getCurTime()
  if (isVisible)
    lastMousePointerTimeShow = now
  else
    lastMousePointerTimeHide = now
})

local function setMousePointerInitialPos(obj)
{
  local now = ::dagor.getCurTime()
  local isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  local isCursorVisible = ::is_cursor_visible_in_gui()

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

local function setMousePointerInitialPosOnChildByValue(obj)
{
  local idx = obj?.isValid() ? obj.getValue() : -1
  if (idx < 0 || idx >= obj.childrenCount())
    return false
  return setMousePointerInitialPos(obj.getChild(idx))
}

return {
  setMousePointerInitialPos
  setMousePointerInitialPosOnChildByValue
}
