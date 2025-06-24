from "%scripts/dagui_library.nut" import *
from "app" import pauseGame
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { floor } = require("math")
let { format } = require("string")

let { restartReplay, getReplayTotalTime, getCameraFov, setCameraFov,
  getFreeCameraInertia, setFreeCameraInertia, getFreeCameraZoomSpeed, setFreeCameraZoomSpeed,
  getFreeCameraMaxSpeed, setFreeCameraMaxSpeed, getFreeCameraMaxOrientSpeed, setFreeCameraMaxOrientSpeed,
  resetCameraRoll, turnOnFreeCamera, getEnabledDepthofField, setEnabledDepthofField,
  getNearDistance, getNearFadeDistance, getNearBlur, setNearDistances, setLinearBlend,
  getFarDistance, getFarFadeDistance, getFarBlur, setFarDistances,
  trackEditorLoadKeyTrack, trackEditorAddKey, trackEditorRemoveLastKey, trackEditorClearAllKeys,
  trackEditorJumpPrevKey, trackEditorJumpNextKey, trackEditorGetCurEditTime, trackEditorGetKeyNumber,
  trackEditorGetCurKeyTime, trackEditorGetCurKeyFov, trackEditorGetCurKeyRoll, getPlayKeysPosition,
  setPlayKeysPosition, getPlayKeysRotation, setPlayKeysRotation, getPlayKeysRoll, setPlayKeysRoll,
  getPlayKeysFov, setPlayKeysFov } = require("replays")


let near_dof_ids = ["neardof_distance_slider", "neardof_fade_distance_slider", "neardof_blur_slider", "soft_render_checkbox"]
let far_dof_ids = ["fardof_distance_slider", "fardof_fade_distance_slider", "fardof_blur_slider"]

function updateCurKeyValues() {
  get_cur_gui_scene()["track_time"].setValue(format("%.3f", trackEditorGetCurEditTime()))
  get_cur_gui_scene()["current_key_index"].setValue(trackEditorGetKeyNumber())
  get_cur_gui_scene()["current_key_time"].setValue(format("%.3f", trackEditorGetCurKeyTime()))
  get_cur_gui_scene()["current_key_fov"].setValue(format("%.3f", trackEditorGetCurKeyFov()))
  get_cur_gui_scene()["current_key_roll"].setValue(format("%.3f", trackEditorGetCurKeyRoll()))
}

let sliders = {
  rewind_slider = {
    value = 0
    onValueChangeFunction = @(value) this.value = value * this.precision
    initFunction = function(slider) {
      slider["min"] = "0"
      slider["max"] = floor(getReplayTotalTime() / this.precision).tostring()
      slider.setValue(this.value)
    }
    precision = 0.1
  }
  free_camera_inertia_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value * this.precision
      setFreeCameraInertia(this.value)
    }
    initFunction = function(slider) {
      this.value = getFreeCameraInertia() / this.precision
      slider["min"] = "0"
      slider["max"] = "1000"
      slider.setValue(this.value)
    }
    precision = 0.001
  }
  camera_fov_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value
      setCameraFov(value)
    }
    initFunction = function(slider) {
      this.value = getCameraFov()
      slider["min"] = "1"
      slider["max"] = "180"
      slider.setValue(this.value)
    }
  }
  free_camera_zoom_speed_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value
      setFreeCameraZoomSpeed(value)
    }
    initFunction = function(slider) {
      this.value = getFreeCameraZoomSpeed()
      slider["min"] = "1"
      slider["max"] = "200"
      slider.setValue(this.value)
    }
  }
  camera_max_speed_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value * this.precision
      setFreeCameraMaxSpeed(this.value)
    }
    initFunction = function(slider) {
      this.value = getFreeCameraMaxSpeed() / this.precision
      slider["min"] = "0"
      slider["max"] = "1000000"
      slider.setValue(this.value)
    }
    precision = 0.001
  }
  camera_max_orient_speed_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value * this.precision
      setFreeCameraMaxOrientSpeed(this.value)
    }
    initFunction = function(slider) {
      this.value = getFreeCameraMaxOrientSpeed() / this.precision
      slider["min"] = "0"
      slider["max"] = "2000"
      slider.setValue(this.value)
    }
    precision = 0.001
  }
  neardof_distance_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value
    }
    initFunction = function(slider) {
      this.value = getNearDistance()
      slider["min"] = "0"
      slider["max"] = "2500"
      slider.setValue(this.value)
    }
    precision = 1
  }
  neardof_fade_distance_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value
    }
    initFunction = function(slider) {
      this.value = getNearFadeDistance()
      slider["min"] = "0"
      slider["max"] = "50"
      slider.setValue(this.value)
    }
  }
  neardof_blur_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value * this.precision
    }
    initFunction = function(slider) {
      this.value = getNearBlur() / this.precision
      slider["min"] = "0"
      slider["max"] = "1000"
      slider.setValue(this.value)
    }
    precision = 0.001
  }
  fardof_distance_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value
    }
    initFunction = function(slider) {
      this.value = getFarDistance()
      slider["min"] = "0"
      slider["max"] = "2500"
      slider.setValue(this.value)
    }
  }
  fardof_fade_distance_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value
    }
    initFunction = function(slider) {
      this.value = getFarFadeDistance()
      slider["min"] = "0"
      slider["max"] = "50"
      slider.setValue(this.value)
    }
  }
  fardof_blur_slider = {
    value = 0
    onValueChangeFunction = function(value) {
      this.value = value * this.precision
    }
    initFunction = function(slider) {
      this.value = getFarBlur() / this.precision
      slider["min"] = "0"
      slider["max"] = "1000"
      slider.setValue(this.value)
    }
    precision = 0.001
  }
}

let buttons = {
  rewind_button = {
    onClickFunction = @() restartReplay(sliders["rewind_slider"].value)
  }
  reset_camera_roll_button = {
    onClickFunction = @() resetCameraRoll()
  }
  add_key_button = {
    onClickFunction = function() {
      trackEditorLoadKeyTrack()
      trackEditorAddKey()
      updateCurKeyValues()
    }
  }
  remove_last_key_button = {
    onClickFunction = function() {
      trackEditorRemoveLastKey()
      updateCurKeyValues()
    }
  }
  clear_all_key_button = {
    onClickFunction = function() {
      trackEditorClearAllKeys()
      updateCurKeyValues()
    }
  }
  jump_prev_key = {
    onClickFunction = function() {
      trackEditorJumpPrevKey()
      updateCurKeyValues()
    }
  }
  jump_next_key = {
    onClickFunction = function() {
      trackEditorJumpNextKey()
      updateCurKeyValues()
    }
  }
}

let checkboxes = {
  enable_dof_checkbox = {
    initFunction = @ (checkbox) checkbox.setValue(getEnabledDepthofField())
    onSwitchFunction = @ (val) setEnabledDepthofField(val)
  }
  soft_render_checkbox = {
    value = 0
    initFunction = @(_checkbox) null
    onSwitchFunction = function (val) {
      this.value = val
    }
  }
  linear_blend_checkbox = {
    initFunction = @(checkbox) checkbox.setValue(true)
    onSwitchFunction = @ (val) setLinearBlend(val)
  }

  play_keys_position = {
    initFunction = @(checkbox) checkbox.setValue(getPlayKeysPosition())
    onSwitchFunction = @ (val) setPlayKeysPosition(val)
  }

  play_keys_rotation = {
    initFunction = @(checkbox) checkbox.setValue(getPlayKeysRotation())
    onSwitchFunction = @ (val) setPlayKeysRotation(val)
  }

  play_keys_roll = {
    initFunction = @(checkbox) checkbox.setValue(getPlayKeysRoll())
    onSwitchFunction = @ (val) setPlayKeysRoll(val)
  }

  play_keys_fov = {
    initFunction = @(checkbox) checkbox.setValue(getPlayKeysFov())
    onSwitchFunction = @ (val) setPlayKeysFov(val)
  }
}

function changeNearDistances() {
  let { neardof_distance_slider, neardof_fade_distance_slider, neardof_blur_slider } = sliders
  let isSoft = checkboxes.soft_render_checkbox.value
  setNearDistances(neardof_distance_slider.value, neardof_fade_distance_slider.value, neardof_blur_slider.value, isSoft)
}

function changeFarDistances() {
  let { fardof_distance_slider, fardof_fade_distance_slider, fardof_blur_slider } = sliders
  setFarDistances(fardof_distance_slider.value, fardof_fade_distance_slider.value, fardof_blur_slider.value)
}

let class ReplaySystem (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/replays/replaySystemWindow.blk"
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FLIGHT_MENU

  function initScreen() {
    turnOnFreeCamera()
    foreach (sliderId, sliderData in sliders) {
      let slider = this.scene.findObject(sliderId)
      if (slider == null) {
        logerr($"there is no slider {sliderId} in the scene")
        continue
      }
      sliderData.initFunction(slider)
      this.guiScene.applyPendingChanges(false)
      this.updateSliderTextValue(sliderId, sliderData.value)

      pauseGame(true)
    }

    foreach (checkBoxId, checkBoxData in checkboxes) {
      let checkBox = this.scene.findObject(checkBoxId)
      if (checkBox == null) {
        logerr($"there is no checkbox {checkBoxId} in the scene")
        continue
      }
      checkBoxData.initFunction(checkBox)
    }

    updateCurKeyValues()
  }

  function onContentExpand(obj) {
    let parentTab = obj.getParent()
    if (parentTab == null)
      return
    let contentHidden = parentTab?["expanded"] ?? "no"
    parentTab["expanded"] = contentHidden == "no" ? "yes" : "no"
  }

  function onSliderValueChange(obj) {
    if (!obj.isValid() || obj?.id == null)
      return

    let sliderId = obj.id
    let sliderData = sliders?[sliderId]
    if (sliderData == null)
      return

    sliderData.onValueChangeFunction(obj.getValue())
    this.updateSliderTextValue(sliderId, sliderData.value)
    if (near_dof_ids.indexof(sliderId) != null)
      changeNearDistances()

    if (far_dof_ids.indexof(sliderId) != null)
      changeFarDistances()
  }

  function onButtonClick(obj) {
    if (!obj.isValid() || obj?.id == null)
      return

    let buttonData = buttons?[obj.id]
    if (buttonData == null)
      return

    buttonData.onClickFunction()
  }

  function onCheckBoxSwitch(obj) {
    if (!obj.isValid() || obj?.id == null)
      return

    let checkboxData = checkboxes?[obj.id]
    if (checkboxData == null)
      return

    checkboxData.onSwitchFunction(obj.getValue())
    if (near_dof_ids.indexof(obj.id) != null)
      changeNearDistances()
  }

  function updateSliderTextValue(sliderId, sliderValue) {
    let sliderTextValueId = $"{sliderId}_value"
    let sliderTextValueObj = this.scene.findObject(sliderTextValueId)
    if (sliderTextValueObj.isValid())
      sliderTextValueObj["text"] = sliderValue.tostring()
  }
}

gui_handlers.ReplaySystem <- ReplaySystem

return {
  replaySystemWindowOpen = @() handlersManager.loadHandler(ReplaySystem, {})
  replaySystemWindowClose = function() {
    local handler = handlersManager.findHandlerClassInScene(gui_handlers.ReplaySystem)
    if (handler) {
      pauseGame(false)
      handler.switchControlsAllowMask(CtrlsInGui.CTRL_ALLOW_FULL)
      handlersManager.destroyHandler(handler)
    }
  }
}
