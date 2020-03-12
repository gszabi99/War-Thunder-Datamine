local controlsOperations = require("scripts/controls/controlsOperations.nut")

return [
  {
    id = "ID_COMMON_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
  }
//-------------------------------------------------------
  {
    id = "ID_COMMON_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() ::is_xinput_device()
  }
  {
    id = "ID_COMMON_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ctrlGroups.ONLY_COMMON | ctrlGroups.HANGAR | ctrlGroups.REPLAY,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() ::is_xinput_device()
  }
  {
    id = "ID_COMMON_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ctrlGroups.ONLY_COMMON | ctrlGroups.HANGAR | ctrlGroups.REPLAY
    )
    showFunc = @() ::is_xinput_device()
  }
]