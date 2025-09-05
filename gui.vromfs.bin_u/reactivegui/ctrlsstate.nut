from "%rGui/globals/ui_library.nut" import *

let extWatched = require("%rGui/globals/extWatched.nut")
let { inputChatVisible } = require("%rGui/hudChatState.nut")

let gamepadCursorControl = extWatched("gamepadCursorControl", false)
let haveXinputDevice = extWatched("haveXinputDevice", false) 
let showConsoleButtons = extWatched("showConsoleButtons", false)
let cursorVisible = extWatched("cursorVisible", true)

let enabledGamepadCursorControlInScene = keepref(Computed(
  @() gamepadCursorControl.get() && haveXinputDevice.get() && cursorVisible.get()))

let enabledKBCursorControlInScene = keepref(Computed(@() cursorVisible.get()))

function updateSceneGamepadCursorControl(value) {
  log($"ctrlsState: updateSceneGamepadCursorControl: {value} ({gamepadCursorControl.get()}, {haveXinputDevice.get()}, {cursorVisible.get()})")
  gui_scene.setConfigProps({ gamepadCursorControl = value })
}
updateSceneGamepadCursorControl(enabledGamepadCursorControlInScene.get())

function updateSceneKBCursorControl(value) {
  gui_scene.setConfigProps({ kbCursorControl = value })
}
updateSceneKBCursorControl(true)

let isEnableInput = keepref(Computed(
  @() cursorVisible.get() || inputChatVisible.get()))

gui_scene.enableInput(isEnableInput.get())

isEnableInput.subscribe(@(v) gui_scene.enableInput(v))

enabledGamepadCursorControlInScene.subscribe(updateSceneGamepadCursorControl)
enabledKBCursorControlInScene.subscribe(updateSceneKBCursorControl)

return {
  showConsoleButtons
  cursorVisible
}
