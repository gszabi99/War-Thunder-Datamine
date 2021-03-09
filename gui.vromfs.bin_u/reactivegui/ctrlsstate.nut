local { isInFlight } = require("globalState.nut")
local { inputEnabled, inputChatVisible } = require("hudChatState.nut")
local extWatched = require("globals/extWatched.nut")
local { isChatPlaceVisible } = require("hud/hudPartVisibleState.nut")
local { cursorVisible } = require("hudState.nut")

local ctrlsState = keepref(::Computed(function() {
  if (isInFlight.value && inputEnabled.value && inputChatVisible.value
      && isChatPlaceVisible.value)
    return CtrlsInGui.CTRL_IN_MP_CHAT
      | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
      | CtrlsInGui.CTRL_ALLOW_MP_CHAT
  else
    return CtrlsInGui.CTRL_ALLOW_FULL
}))

ctrlsState.subscribe(function (new_val) {
  ::set_allowed_controls_mask(new_val)
})


local gamepadCursorControl = extWatched("gamepadCursorControl",
  @() ::cross_call.getValueGamepadCursorControl())

local haveXinputDevice = extWatched("haveXinputDevice",  //FIX ME: remove "haveXinputDevice" when in darg scene will be determined correctly that joystick has controller
  @() ::cross_call.haveXinputDevice())

local enabledGamepadCursorControlInScene = keepref(::Computed(
  @() gamepadCursorControl.value && haveXinputDevice.value && cursorVisible.value))

local enabledKBCursorControlInScene = keepref(::Computed(@() cursorVisible.value))

local function updateSceneGamepadCursorControl(value) {
  log($"ctrlsState: updateSceneGamepadCursorControl: {value} ({gamepadCursorControl.value}, {haveXinputDevice.value}, {cursorVisible.value})")
  ::gui_scene.config.gamepadCursorControl = value
}
updateSceneGamepadCursorControl(enabledGamepadCursorControlInScene.value)

local function updateSceneKBCursorControl(value) {
  ::gui_scene.config.kbCursorControl = value
}
updateSceneKBCursorControl(enabledKBCursorControlInScene.value)

enabledGamepadCursorControlInScene.subscribe(updateSceneGamepadCursorControl)
enabledKBCursorControlInScene.subscribe(updateSceneKBCursorControl)

local showConsoleButtons = extWatched("showConsoleButtons", @() ::cross_call.isConsoleModeEnabled())

return {
  showConsoleButtons = showConsoleButtons
}
