let { hangar_enable_controls } = require("hangar")

// Hangar controls enable by mouse move over the tracking object if it exist in the scene.
// Hangar controls will be disabled:
//    -by wheel or left clicking when mouse is out of tracking object;
//    -on detach event.

let class HangarControlTracking {
  eventMask = EV_MOUSE_L_BTN | EV_MOUSE_EXT_BTN | EV_MOUSE_NOT_ON_OBJ | EV_MOUSE_MOVE

  function onMouseMove(_obj, _mx, _my, bits) {
    if (bits & BITS_MOUSE_NOT_ON_OBJ)
      return RETCODE_NOTHING

    hangar_enable_controls(true)
    return RETCODE_PROCESSED
  }

  function onExtMouse(_obj, _mx, _my, btn_id, _is_up, bits) {
    if (btn_id != 2 && btn_id != 32)
      return RETCODE_NOTHING

    hangar_enable_controls(btn_id == 2 || !(bits & BITS_MOUSE_NOT_ON_OBJ))
    return RETCODE_PROCESSED
  }

  function onLMouse(_obj, _mx, _my, is_up, bits) {
    if (is_up || !(bits & BITS_MOUSE_NOT_ON_OBJ))
      return RETCODE_NOTHING

    hangar_enable_controls(false)
    return RETCODE_PROCESSED
  }

  function onDetach(_obj) {
    hangar_enable_controls(false)
    return RETCODE_NOTHING
  }
}

::replace_script_gui_behaviour("hangarControlTracking", HangarControlTracking)
