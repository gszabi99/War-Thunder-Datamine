from "%rGui/globals/ui_library.nut" import *
let { setAllowedControlsMask } = require("controlsMask")
let { isInFlight } = require("globalState.nut")
let { canWriteToChat, inputChatVisible } = require("hudChatState.nut")
let { isChatPlaceVisible } = require("hud/hudPartVisibleState.nut")
let { isAAComplexMenuActive } = require("%rGui/antiAirComplexMenu/antiAirComplexMenuState.nut")

let ctrlsState = keepref(Computed(function() {
  local res = CtrlsInGui.CTRL_ALLOW_FULL
  if (!isInFlight.get())
    return res
  if (canWriteToChat.get() && inputChatVisible.get() && isChatPlaceVisible.get())
    res = CtrlsInGui.CTRL_IN_MP_CHAT
      | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
      | CtrlsInGui.CTRL_ALLOW_MP_CHAT
  if (isAAComplexMenuActive.get())
    res = (res & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE) | CtrlsInGui.CTRL_IN_AA_COMPLEX_MENU
  return res
}))

ctrlsState.subscribe(setAllowedControlsMask)
