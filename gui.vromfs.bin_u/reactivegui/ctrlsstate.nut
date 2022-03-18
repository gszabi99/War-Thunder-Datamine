let extWatched = require("globals/extWatched.nut")

let gamepadCursorControl = extWatched("gamepadCursorControl",
  @() ::cross_call.getValueGamepadCursorControl())

let haveXinputDevice = extWatched("haveXinputDevice",  //FIX ME: remove "haveXinputDevice" when in darg scene will be determined correctly that joystick has controller
  @() ::cross_call.haveXinputDevice())

let cursorVisible = extWatched("cursorVisible",
  @() ::cross_call.getValueGuiSceneCursorVisible())

let enabledGamepadCursorControlInScene = keepref(::Computed(
  @() gamepadCursorControl.value && haveXinputDevice.value && cursorVisible.value))

let enabledKBCursorControlInScene = keepref(::Computed(@() cursorVisible.value))

let function updateSceneGamepadCursorControl(value) {
  log($"ctrlsState: updateSceneGamepadCursorControl: {value} ({gamepadCursorControl.value}, {haveXinputDevice.value}, {cursorVisible.value})")
  ::gui_scene.config.gamepadCursorControl = value
}
updateSceneGamepadCursorControl(enabledGamepadCursorControlInScene.value)

let function updateSceneKBCursorControl(value) {
  ::gui_scene.config.kbCursorControl = value
}
updateSceneKBCursorControl(true)

enabledGamepadCursorControlInScene.subscribe(updateSceneGamepadCursorControl)
enabledKBCursorControlInScene.subscribe(updateSceneKBCursorControl)

let showConsoleButtons = extWatched("showConsoleButtons", @() ::cross_call.isConsoleModeEnabled())

return {
  showConsoleButtons
  cursorVisible
}
