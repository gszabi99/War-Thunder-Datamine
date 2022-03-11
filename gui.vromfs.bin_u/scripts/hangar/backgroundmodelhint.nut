local { addListenersWithoutEnv } = require("sqStdlibs/helpers/subscriptions.nut")

local isVisibleHint = false

const DELAYED_SHOW_HINT_SEC = 1

local screen = [ 0, 0 ]
local unsafe = [ 0, 0 ]
local offset = [ 0, 0 ]

local hintObj = null

local function initBackgroundModelHint(handler) {
  local cursorOffset = handler.guiScene.calcString("22@dp", null)
  screen = [ ::screen_width(), ::screen_height() ]
  unsafe = [ handler.guiScene.calcString("@bw", null), handler.guiScene.calcString("@bh", null) ]
  offset = [ cursorOffset, cursorOffset ]
  scene.findObject("background_model_hint")?.setUserData(handler)
}

local function getHintObj() {
  if (hintObj?.isValid())
    return hintObj
  local handler = ::handlersManager.getActiveBaseHandler()
  if (!handler)
    return null
  local res = handler.scene.findObject("background_model_hint")
  return res?.isValid() ? res : null
}


local function placeBackgroundModelHint(obj) {
  if (!isVisibleHint)
    return

  local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
  local size = obj.getSize()
  obj.left = ::clamp(cursorPos[0] + offset[0], unsafe[0], ::max(unsafe[0], screen[0] - unsafe[0] - size[0])).tointeger()
  obj.top = ::clamp(cursorPos[1] + offset[1], unsafe[1], ::max(unsafe[1], screen[1] - unsafe[1] - size[1])).tointeger()
}

local function showHint() {
  local obj = getHintObj()
  if (!obj)
    return

  hintObj = obj
  obj.show(true)
  placeBackgroundModelHint(obj)
}

local hoverHintTask = -1
local function removeHintTask() {
  if (hoverHintTask != -1)
    ::periodic_task_unregister(hoverHintTask)
  hoverHintTask = -1
}
local function startHintTask(cb) {
  removeHintTask()
  hoverHintTask = ::periodic_task_register({}, cb, DELAYED_SHOW_HINT_SEC)
}

local function hideHint() {
  isVisibleHint = false
  removeHintTask()
  getHintObj()?.show(false)
  hintObj = null
}

local function showBackgroundModelHint(params) {
  local { isHovered = false } = params
  if (!isHovered) {
    hideHint()
    return
  }

  if (!::show_console_buttons || ::is_mouse_last_time_used()) //show hint only for gamepad
    return

  isVisibleHint = true
  startHintTask(function(_) {
    removeHintTask()
    showHint()
  })
}

addListenersWithoutEnv({
  ActiveHandlersChanged = @(p) hideHint()
  HangarModelLoading = @(p) hideHint()
})

return {
  showBackgroundModelHint
  initBackgroundModelHint
  placeBackgroundModelHint
}
