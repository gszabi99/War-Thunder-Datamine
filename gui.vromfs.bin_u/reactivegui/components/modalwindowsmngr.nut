from "%rGui/globals/ui_library.nut" import *

let WND_PARAMS = {
  key = null 
  children = null
  onClick = null 

  size = flex()
  behavior = Behaviors.Button
  stopMouse = true
  stopHotkeys = true
  skipDirPadNav = true
  hotkeys = [["Esc"]]
}

let modalWindows = []
let modalWindowsGeneration = Watched(0)
let hasModalWindows = Computed(@() modalWindowsGeneration.get() >= 0 && modalWindows.len() > 0)

function removeModalWindow(key) {
  let idx = modalWindows.findindex(@(w) w.key == key)
  if (idx == null)
    return false
  modalWindows.remove(idx)
  modalWindowsGeneration.set(modalWindowsGeneration.get() + 1)
  return true
}

local lastWndIdx = 0
function addModalWindow(wnd = WND_PARAMS) {
  wnd = WND_PARAMS.__merge(wnd)
  if (wnd.key != null)
    removeModalWindow(wnd.key)
  else {
    lastWndIdx++
    wnd.key = $"modal_wnd_{lastWndIdx}"
  }
  wnd.onClick = wnd.onClick ?? @() removeModalWindow(wnd.key)
  modalWindows.append(wnd)
  modalWindowsGeneration.set(modalWindowsGeneration.get() + 1)
}

function hideAllModalWindows() {
  if (modalWindows.len() == 0)
    return
  modalWindows.clear()
  modalWindowsGeneration.set(modalWindowsGeneration.get() + 1)
}

let modalWindowsComponent = @() {
  watch = modalWindowsGeneration
  zOrder = Layers.Upper
  size = flex()
  children = modalWindows
}

return {
  addModalWindow
  removeModalWindow
  hideAllModalWindows
  modalWindowsComponent
  hasModalWindows
}
