from "frp" import *
from "daRg" import *

local modalWindows = []
local modalWindowsGeneration = Watched(0)
local hasModalWindows = Computed(@() modalWindowsGeneration.value >= 0 && modalWindows.len() > 0)

local WND_PARAMS = {
  key = null //generate automatically when not set
  children= null
  onClick = null //remove current modal window when not set

  size = flex()
  behavior = Behaviors.Button
  stopMouse = true
  stopHotkeys = true

  animations = [
    { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.3, play=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.25, playFadeOut=true, easing=OutCubic }
  ]
}

local function remove(key) {
  local idx = modalWindows.findindex(@(w) w.key == key)
  if (idx == null)
    return false
  modalWindows.remove(idx)
  modalWindowsGeneration(modalWindowsGeneration.value+1)
  return true
}

local lastWndIdx = 0
local function add(wnd = WND_PARAMS) {
  wnd = WND_PARAMS.__merge(wnd)
  if (wnd.key != null)
    remove(wnd.key)
  else {
    lastWndIdx++
    wnd.key = $"modal_wnd_{lastWndIdx}"
  }
  wnd.onClick = wnd.onClick ?? @() remove(wnd.key)
  modalWindows.append(wnd)
  modalWindowsGeneration(modalWindowsGeneration.value+1)
}

local function clear() {
  if (modalWindows.len() == 0)
    return
  modalWindows.clear()
  modalWindowsGeneration(modalWindowsGeneration.value+1)
}

local modalWindowsComponent = @() {
  watch = modalWindowsGeneration
  size = flex()
  children = modalWindows
}

return {
  add
  remove
  addModalWindow = add
  removeModalWindow = remove
  hideAll = clear
  component = modalWindowsComponent
  modalWindowsComponent
  hasModalWindows
}