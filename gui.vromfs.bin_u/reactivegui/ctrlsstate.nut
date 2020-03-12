local globalState = require("globalState.nut")
local hudChatState = require("hudChatState.nut")
local frp = require("std/frp.nut")


local ctrlsState = frp.combine(
  [globalState.isInFlight, hudChatState.inputEnabled, hudChatState.inputChatVisible],
  function (list) {
    if (list[0] && list[1] && list[2])
      return CtrlsInGui.CTRL_IN_MP_CHAT
        | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
        | CtrlsInGui.CTRL_ALLOW_MP_CHAT
    else
      return CtrlsInGui.CTRL_ALLOW_FULL
  }
)

ctrlsState.subscribe(function (new_val) {
  ::set_allowed_controls_mask(new_val)
})