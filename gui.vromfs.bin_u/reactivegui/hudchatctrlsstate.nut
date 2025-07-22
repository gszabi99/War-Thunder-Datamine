from "%rGui/globals/ui_library.nut" import *
let { setAllowedControlsMask } = require("controlsMask")
let { isInFlight } = require("globalState.nut")
let { canWriteToChat, inputChatVisible } = require("hudChatState.nut")
let { isChatPlaceVisible } = require("hud/hudPartVisibleState.nut")
let { isAAComplexMenuActive, isWheelMenuActive } = require("%appGlobals/hud/hudState.nut")

let ctrlsState = keepref(Computed(function() {
  local res = CtrlsInGui.CTRL_ALLOW_FULL
  if (!isInFlight.get())
    return res
  if (canWriteToChat.get() && inputChatVisible.get() && isChatPlaceVisible.get())
    return CtrlsInGui.CTRL_IN_MP_CHAT
      | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
      | CtrlsInGui.CTRL_ALLOW_MP_CHAT
  if (isAAComplexMenuActive.get() && !isWheelMenuActive.get())
    return CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
      | CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT
      | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
      | CtrlsInGui.CTRL_ALLOW_MP_CHAT
      | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
      | CtrlsInGui.CTRL_ALLOW_FLIGHT_MENU
      | CtrlsInGui.CTRL_ALLOW_ARTILLERY
      | CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
      | CtrlsInGui.CTRL_IN_AA_COMPLEX_MENU
  return res
}))

ctrlsState.subscribe(setAllowedControlsMask)
setAllowedControlsMask(ctrlsState.get())
