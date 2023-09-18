from "%scripts/dagui_library.nut" import *

let { hangar_enable_controls } = require("hangar")

// Hangar controls enable by mouse move over the tracking object if it exist in the scene.
// Hangar controls will be disabled:
//    -by wheel or left clicking when mouse is out of tracking object;
//    -on detach event.

let class HangarControlTracking {
  eventMask = EV_MOUSE_L_BTN | EV_MOUSE_EXT_BTN | EV_MOUSE_NOT_ON_OBJ | EV_MOUSE_MOVE | EV_JOYSTICK

  function onMouseMove(_obj, _mx, _my, bits) {
    if (bits & BITS_MOUSE_NOT_ON_OBJ)
      return RETCODE_NOTHING

    hangar_enable_controls(true)
    return RETCODE_PROCESSED
  }

  function onExtMouse(_obj, _mx, _my, btn_id, _is_up, bits) {
    if (btn_id != 2 && btn_id != 32 && btn_id != 64) //rclick and mouse whell up and down
       return RETCODE_NOTHING

    hangar_enable_controls((bits & BITS_MOUSE_NOT_ON_OBJ) == 0)
    return RETCODE_PROCESSED
  }

  function onLMouse(_obj, _mx, _my, is_up, bits) {
    if (is_up || !(bits & BITS_MOUSE_NOT_ON_OBJ))
      return RETCODE_NOTHING

    hangar_enable_controls(false)
    return RETCODE_PROCESSED
  }

  function onJoystick(obj, _joy, _btn_idx, _is_up, _buttons) {
    hangar_enable_controls(obj.isHovered())
    return RETCODE_NOTHING
  }

  function onDetach(_obj) {
    hangar_enable_controls(false)
    return RETCODE_NOTHING
  }
}

replace_script_gui_behaviour("hangarControlTracking", HangarControlTracking)
