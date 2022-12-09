from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let controlsOperations = require("%scripts/controls/controlsOperations.nut")
let { ActionGroup } = require("controls")

return [
  {
    id = "ID_COMMON_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
  }
//-------------------------------------------------------
  {
    id = "ID_COMMON_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() ::have_xinput_device()
  }
  {
    id = "ID_COMMON_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.ONLY_COMMON | ActionGroup.HANGAR | ActionGroup.REPLAY,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() ::have_xinput_device()
  }
  {
    id = "ID_COMMON_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.ONLY_COMMON | ActionGroup.HANGAR | ActionGroup.REPLAY
    )
    showFunc = @() ::have_xinput_device()
  }
]
