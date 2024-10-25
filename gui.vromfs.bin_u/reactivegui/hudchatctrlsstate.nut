from "%rGui/globals/ui_library.nut" import *
let { setAllowedControlsMask } = require("controlsMask")
let { isInFlight } = require("globalState.nut")
let { canWriteToChat, inputChatVisible } = require("hudChatState.nut")
let { isChatPlaceVisible } = require("hud/hudPartVisibleState.nut")

let ctrlsState = keepref(Computed(function() {
  if (isInFlight.value && canWriteToChat.value && inputChatVisible.value
      && isChatPlaceVisible.value)
    return CtrlsInGui.CTRL_IN_MP_CHAT
      | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
      | CtrlsInGui.CTRL_ALLOW_MP_CHAT
  else
    return CtrlsInGui.CTRL_ALLOW_FULL
}))

ctrlsState.subscribe(setAllowedControlsMask)
