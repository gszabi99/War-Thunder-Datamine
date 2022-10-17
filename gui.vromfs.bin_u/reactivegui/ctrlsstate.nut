from "%rGui/globals/ui_library.nut" import *

let { send } = require("eventbus")
let extWatched = require("globals/extWatched.nut")

let gamepadCursorControl = extWatched("gamepadCursorControl", false)
let haveXinputDevice = extWatched("haveXinputDevice", false) //FIX ME: remove "haveXinputDevice" when in darg scene will be determined correctly that joystick has controller
let showConsoleButtons = extWatched("showConsoleButtons", false)
send("updateGamepadStates", {})

let cursorVisible = extWatched("cursorVisible", true)
send("updateGuiSceneCursorVisible", {})

let enabledGamepadCursorControlInScene = keepref(Computed(
  @() gamepadCursorControl.value && haveXinputDevice.value && cursorVisible.value))

let enabledKBCursorControlInScene = keepref(Computed(@() cursorVisible.value))

let function updateSceneGamepadCursorControl(value) {
  log($"ctrlsState: updateSceneGamepadCursorControl: {value} ({gamepadCursorControl.value}, {haveXinputDevice.value}, {cursorVisible.value})")
  gui_scene.setConfigProps({gamepadCursorControl = value})
}
updateSceneGamepadCursorControl(enabledGamepadCursorControlInScene.value)

let function updateSceneKBCursorControl(value) {
  gui_scene.setConfigProps({kbCursorControl = value})
}
updateSceneKBCursorControl(true)

enabledGamepadCursorControlInScene.subscribe(updateSceneGamepadCursorControl)
enabledKBCursorControlInScene.subscribe(updateSceneKBCursorControl)

return {
  showConsoleButtons
  cursorVisible
}
