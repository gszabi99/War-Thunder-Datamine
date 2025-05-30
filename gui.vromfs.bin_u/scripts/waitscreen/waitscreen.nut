from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { update_msg_boxes, reset_msg_box_check_anim_time, need_new_msg_box_anim
} = require("%sqDagui/framework/msgBox.nut")
let { defer } = require("dagor.workcycle")

local currentWaitScreen = null
local currentWaitScreenText = ""

function showWaitScreen(txt) {
  log($"GuiManager: showWaitScreen {txt}")
  if (checkObj(currentWaitScreen)) {
    if (currentWaitScreenText == txt)
      return log("already have this screen, just ignore")

    log("wait screen already exist, remove old one.")
    currentWaitScreen.getScene().destroyElement(currentWaitScreen)
    currentWaitScreen = null
    reset_msg_box_check_anim_time()
  }

  let guiScene = get_main_gui_scene()
  if (guiScene == null)
    return log("guiScene == null")

  let needAnim = need_new_msg_box_anim()
  currentWaitScreen = guiScene.loadModal("", "%gui/waitBox.blk", needAnim ? "massTransp" : "div", null)
  if (!checkObj(currentWaitScreen))
    return log("Error: failed to create wait screen")

  let obj = currentWaitScreen.findObject("wait_screen_msg")
  if (!checkObj(obj))
    return log("Error: failed to find wait_screen_msg")

  obj.setValue(loc(txt))
  currentWaitScreenText = txt
  broadcastEvent("WaitBoxCreated")
}

function closeWaitScreen() {
  log("close_wait_screen")
  if (!checkObj(currentWaitScreen))
    return

  let guiScene = currentWaitScreen.getScene()
  guiScene.destroyElement(currentWaitScreen)
  currentWaitScreen = null
  reset_msg_box_check_anim_time()
  broadcastEvent("ModalWndDestroy")

  defer(update_msg_boxes)
}

eventbus_subscribe("showWaitScreenNative", @(payloadText) showWaitScreen(payloadText.txt))
eventbus_subscribe("closeWaitScreenNative", @(_) closeWaitScreen())

return {
  getCurrentWaitScreen = @() currentWaitScreen
  showWaitScreen
  closeWaitScreen
}