from "%sqDagui/daguiNativeApi.nut" import *

let { markChildrenInteractive, markObjShortcutOnHover } = require("%sqDagui/guiBhv/guiBhvUtils.nut")
let { posNavigator } = require("bhvPosNavigator.nut")






let HoverNavigator = class (posNavigator) {
  bhvId = "HoverNavigator"

  function onAttach(obj) {
    markChildrenInteractive(obj, true)
    markObjShortcutOnHover(obj, true)
    return RETCODE_NOTHING
  }

  onFocus = @(_obj, _event) RETCODE_NOTHING
  getValue = @(obj) this.getHoveredChild(obj).hoveredIdx ?? -1
  setValue = @(obj, value) this.selectItem(obj, value)
  getSelectedValue = @(obj) this.getValue(obj)
  getCanSelectNone = @(_obj) true
  selectItem = @(obj, idx, idxObj = null, needSound = true, _needSetMouse = false)
    base.selectItem(obj, idx, idxObj, needSound, true)

  function onLMouse(obj, _mx, _my, is_up, bits) {
    if (!is_up && (bits & BITS_MOUSE_DBL_CLICK) && (bits & BITS_MOUSE_BTN_L)) {
      this.activateAction(obj)
      return RETCODE_HALT
    }
    return RETCODE_NOTHING
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, _bits) {
    if (btn_id != 2)  
      return RETCODE_NOTHING
    if (is_up && this.findClickedObj(obj, mx, my))
      obj.sendNotify("r_click")
    return RETCODE_PROCESSED
  }

  setChildSelected = @(_obj, _childObj, _isSelected = true) null 
  onGamepadMouseFinishMove = @(_obj) null
  isOnlyHover = @(_obj) true
}

replace_script_gui_behaviour("HoverNavigator", HoverNavigator)

return {HoverNavigator}