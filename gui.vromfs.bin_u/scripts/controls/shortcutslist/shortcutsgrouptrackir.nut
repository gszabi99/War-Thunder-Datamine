from "%scripts/dagui_natives.nut" import ps4_headtrack_is_attached
from "%scripts/dagui_library.nut" import *
let { isTrackerJoystick } = require("controls")
let { isPlatformPS4, isPlatformPS5, isPlatformPC } = require("%scripts/clientState/platform.nut")
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let { USEROPT_HEADTRACK_ENABLE, USEROPT_HEADTRACK_SCALE_X, USEROPT_HEADTRACK_SCALE_Y } = require("%scripts/options/optionsExtNames.nut")
let { commitControls } = require("%scripts/controls/controlsManager.nut")

function isHeadTrackerAvailable() {
  return isPlatformPC
      || (ps4_headtrack_is_attached()
        && (isPlatformPS4 || (isPlatformPS5 && hasFeature("PS5HeadTracking"))))
      || isTrackerJoystick()
}


return [
//-------------------------------------------------------
  {
    id = "ID_COMMON_TRACKER_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = isHeadTrackerAvailable
  }
  {
    id = "headtrack_enable"
    type = CONTROL_TYPE.SWITCH_BOX
    showFunc = @() ps4_headtrack_is_attached()
    optionType = USEROPT_HEADTRACK_ENABLE
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "ID_TRACKER_RESET_POSITION"
    checkAssign = false
  }
  {
    id = "tracker_camx"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    showFunc = @() isTrackerJoystick()
  }
  {
    id = "tracker_camy"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    showFunc = @() isTrackerJoystick()
  }
  {
    id = "trackIrZoom"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.trackIrZoom
    setValue = function(joyParams, objValue) {
      let prev = joyParams.trackIrZoom
      joyParams.trackIrZoom = objValue
      if (prev != objValue)
        commitControls()
    }
  }
  {
    id = "trackIrForLateralMovement"
    type = CONTROL_TYPE.SWITCH_BOX
    showFunc = @() ps4_headtrack_is_attached()
    value = @(joyParams) joyParams.trackIrForLateralMovement
    setValue = function(joyParams, objValue) {
      let prev = joyParams.trackIrForLateralMovement
      joyParams.trackIrForLateralMovement = objValue
      if (prev != objValue)
        commitControls()
    }
  }
  {
    id = "trackIrAsHeadInTPS"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.trackIrAsHeadInTPS
    setValue = function(joyParams, objValue) {
      let prev = joyParams.trackIrAsHeadInTPS
      joyParams.trackIrAsHeadInTPS = objValue
      if (joyParams.trackIrAsHeadInTPS != prev)
        commitControls()
    }
  }
  {
    id = "headtrack_scale_x"
    type = CONTROL_TYPE.SLIDER
    showFunc = @() ps4_headtrack_is_attached()
    optionType = USEROPT_HEADTRACK_SCALE_X
  }
  {
    id = "headtrack_scale_y"
    type = CONTROL_TYPE.SLIDER
    showFunc = @() ps4_headtrack_is_attached()
    optionType = USEROPT_HEADTRACK_SCALE_Y
  }
]
