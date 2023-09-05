//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

local isVisibleHint = false

const DELAYED_SHOW_HINT_SEC = 1

local screen = [ 0, 0 ]
local unsafe = [ 0, 0 ]
local offset = [ 0, 0 ]

local hintObj = null

let function initBackgroundModelHint(handler) {
  let cursorOffset = handler.guiScene.calcString("22@dp", null)
  screen = [ ::screen_width(), ::screen_height() ]
  unsafe = [ handler.guiScene.calcString("@bw", null), handler.guiScene.calcString("@bh", null) ]
  offset = [ cursorOffset, cursorOffset ]
  handler.scene.findObject("background_model_hint")?.setUserData(handler)
}

let function getHintObj() {
  if (hintObj?.isValid())
    return hintObj
  let handler = handlersManager.getActiveBaseHandler()
  if (!handler)
    return null
  let res = handler.scene.findObject("background_model_hint")
  return res?.isValid() ? res : null
}


let function placeBackgroundModelHint(obj) {
  if (!isVisibleHint)
    return

  let cursorPos = ::get_dagui_mouse_cursor_pos_RC()
  let size = obj.getSize()
  obj.left = clamp(cursorPos[0] + offset[0], unsafe[0], max(unsafe[0], screen[0] - unsafe[0] - size[0])).tointeger()
  obj.top = clamp(cursorPos[1] + offset[1], unsafe[1], max(unsafe[1], screen[1] - unsafe[1] - size[1])).tointeger()
}

let function showHint() {
  let obj = getHintObj()
  if (!obj)
    return

  hintObj = obj
  obj.show(true)
  placeBackgroundModelHint(obj)
}

local hoverHintTask = -1
let function removeHintTask() {
  if (hoverHintTask != -1)
    ::periodic_task_unregister(hoverHintTask)
  hoverHintTask = -1
}
let function startHintTask(cb) {
  removeHintTask()
  hoverHintTask = ::periodic_task_register({}, cb, DELAYED_SHOW_HINT_SEC)
}

let function hideHint() {
  isVisibleHint = false
  removeHintTask()
  getHintObj()?.show(false)
  hintObj = null
}

let function showBackgroundModelHint(params) {
  let { isHovered = false } = params
  if (!isHovered) {
    hideHint()
    return
  }

  if (!showConsoleButtons.value || ::is_mouse_last_time_used()) //show hint only for gamepad
    return

  isVisibleHint = true
  startHintTask(function(_) {
    removeHintTask()
    showHint()
  })
}

subscribe("backgroundHangarVehicleHoverChanged", showBackgroundModelHint)

addListenersWithoutEnv({
  ActiveHandlersChanged = @(_p) hideHint()
  HangarModelLoading = @(_p) hideHint()
})

return {
  initBackgroundModelHint
  placeBackgroundModelHint
}
