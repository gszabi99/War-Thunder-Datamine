from "%scripts/dagui_library.nut" import *

let { hangar_enable_controls } = require("hangar")






let class HangarControlTracking {
  eventMask = EV_MOUSE_L_BTN | EV_MOUSE_EXT_BTN | EV_MOUSE_NOT_ON_OBJ | EV_MOUSE_HOVER_CHANGE
  isActivatePushedPID     = dagui_propid_add_name_id("_isActivatePushed")

  function onMouseHover(obj, _isHover) {
    if (this.isActivatePushed(obj))
      return RETCODE_NOTHING

    hangar_enable_controls(obj.isHovered())
    return RETCODE_NOTHING
  }

  function onMouseActivate(obj, is_up, bits) {
    if (is_up) {
      this.onActivateUnpushed(obj)
      return RETCODE_NOTHING
    }

    if ((bits & BITS_MOUSE_NOT_ON_OBJ) == 0) {
      this.onActivatePushed(obj)
      return RETCODE_NOTHING
    }
    return RETCODE_NOTHING
  }

  function onExtMouse(obj, _mx, _my, btn_id, is_up, bits) {
    if (btn_id != 2 && btn_id != 32 && btn_id != 64) 
       return RETCODE_NOTHING

    return this.onMouseActivate(obj, is_up, bits)
  }

  function onLMouse(obj, _mx, _my, is_up, bits) {
    return this.onMouseActivate(obj, is_up, bits)
  }

  function onDetach(obj) {
    this.onActivateUnpushed(obj)
    hangar_enable_controls(false)
    return RETCODE_NOTHING
  }

  isActivatePushed = @(obj) obj.getIntProp(this.isActivatePushedPID, 0) == 1

  function onActivatePushed(obj) {
    obj.setIntProp(this.isActivatePushedPID, 1)
  }

  function onActivateUnpushed(obj) {
    if (!this.isActivatePushed(obj))
      return false
    obj.setIntProp(this.isActivatePushedPID, 0)
    hangar_enable_controls(obj.isHovered())
    return true
  }

}

replace_script_gui_behaviour("hangarControlTracking", HangarControlTracking)
