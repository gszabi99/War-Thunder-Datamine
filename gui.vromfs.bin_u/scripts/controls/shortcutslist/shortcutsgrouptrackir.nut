//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { is_stereo_mode } = require("vr")
let { isPlatformPS4, isPlatformPS5, isPlatformPC } = require("%scripts/clientState/platform.nut")

let function isHeadTrackerAvailable() {
  return isPlatformPC
      || (::ps4_headtrack_is_attached()
        && (isPlatformPS4 || (isPlatformPS5 && hasFeature("PS5HeadTracking"))))
      || ::is_tracker_joystick()
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
    showFunc = @() ::ps4_headtrack_is_attached()
    optionType = ::USEROPT_HEADTRACK_ENABLE
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "ID_TRACKER_RESET_POSITION"
    checkAssign = false
  }
  //







  {
    id = "tracker_camx"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    showFunc = @() ::is_tracker_joystick()
  }
  {
    id = "tracker_camy"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    showFunc = @() ::is_tracker_joystick()
  }
  {
    id = "trackIrZoom"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.trackIrZoom
    setValue = function(joyParams, objValue) {
      let prev = joyParams.trackIrZoom
      joyParams.trackIrZoom = objValue
      if (prev != objValue)
        ::set_controls_preset("")
    }
  }
  {
    id = "trackIrForLateralMovement"
    type = CONTROL_TYPE.SWITCH_BOX
    showFunc = @() ::ps4_headtrack_is_attached()
    value = @(joyParams) joyParams.trackIrForLateralMovement
    setValue = function(joyParams, objValue) {
      let prev = joyParams.trackIrForLateralMovement
      joyParams.trackIrForLateralMovement = objValue
      if (prev != objValue)
        ::set_controls_preset("")
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
        ::set_controls_preset("")
    }
  }
  {
    id = "headtrack_scale_x"
    type = CONTROL_TYPE.SLIDER
    showFunc = @() ::ps4_headtrack_is_attached()
    optionType = ::USEROPT_HEADTRACK_SCALE_X
  }
  {
    id = "headtrack_scale_y"
    type = CONTROL_TYPE.SLIDER
    showFunc = @() ::ps4_headtrack_is_attached()
    optionType = ::USEROPT_HEADTRACK_SCALE_Y
  }
]
