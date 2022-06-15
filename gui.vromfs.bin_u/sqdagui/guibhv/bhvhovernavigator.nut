let { markChildrenInteractive, markObjShortcutOnHover } = require("%sqDagui/guiBhv/guiBhvUtils.nut")

/*
getValue is always hovered child index or -1
setValue only move mouse to child
*/

::gui_bhv.HoverNavigator <- class extends ::gui_bhv.posNavigator {
  bhvId = "HoverNavigator"

  function onAttach(obj)
  {
    markChildrenInteractive(obj, true)
    markObjShortcutOnHover(obj, true)
    return ::RETCODE_NOTHING
  }

  onFocus = @(obj, event) ::RETCODE_NOTHING
  getValue = @(obj) this.getHoveredChild(obj).hoveredIdx ?? -1
  setValue = @(obj, value) this.selectItem(obj, value)
  getSelectedValue = @(obj) this.getValue(obj)
  getCanSelectNone = @(obj) true
  selectItem = @(obj, idx, idxObj = null, needSound = true, needSetMouse = false)
    base.selectItem(obj, idx, idxObj, needSound, true)

  function onLMouse(obj, mx, my, is_up, bits) {
    if (!is_up && (bits & ::BITS_MOUSE_DBL_CLICK) && (bits & ::BITS_MOUSE_BTN_L)) {
      this.activateAction(obj)
      return ::RETCODE_HALT
    }
    return ::RETCODE_NOTHING
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, bits)
  {
    if (btn_id != 2)  //right mouse button
      return ::RETCODE_NOTHING
    if (is_up && this.findClickedObj(obj, mx, my))
      obj.sendNotify("r_click")
    return ::RETCODE_PROCESSED
  }

  setChildSelected = @(obj, childObj, isSelected = true) null //do not set child selected, work only by hover
  onGamepadMouseFinishMove = @(obj) null
  isOnlyHover = @(obj) true
}
