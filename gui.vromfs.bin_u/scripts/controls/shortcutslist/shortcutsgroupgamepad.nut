from "%scripts/dagui_library.nut" import *

let controlsOperations = require("%scripts/controls/controlsOperations.nut")
let { ActionGroup, hasXInputDevice } = require("controls")
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")

return [
  {
    id = "ID_COMMON_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
  }
//-------------------------------------------------------
  {
    id = "ID_COMMON_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_COMMON_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.ONLY_COMMON | ActionGroup.HANGAR | ActionGroup.REPLAY,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_COMMON_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.ONLY_COMMON | ActionGroup.HANGAR | ActionGroup.REPLAY
    )
    showFunc = @() hasXInputDevice()
  }
]
