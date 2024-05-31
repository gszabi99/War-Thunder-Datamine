
from "%scripts/dagui_library.nut" import *
let { abs, sqrt } = require("math")

const START_DRAG_OFFSET = 3

// To detect the start of drag gestures without moving an object
let class DragStartListener {
  eventMask = EV_MOUSE_L_BTN | EV_MOUSE_NOT_ON_OBJ | EV_MOUSE_MOVE

  isDraggingPID = dagui_propid_add_name_id("is_dragging")
  clickPosPID = dagui_propid_add_name_id("_click_pos")
  isMousePressedPID = dagui_propid_add_name_id("is_mouse_pressed")

  getIsObjDragging = @(obj) obj.getIntProp(this.isDraggingPID, 0)
  getIsMousePressedOnObj = @(obj) obj.getIntProp(this.isMousePressedPID, 0)

  function onMouseMove(obj, mx, my, bits) {
    let onObj = !(bits & BITS_MOUSE_NOT_ON_OBJ)
    if (!this.getIsMousePressedOnObj(obj) || !onObj)
      return RETCODE_NOTHING

    if (!this.getIsObjDragging(obj)) {
      let [clickX = 0, clickY = 0] = obj.getIntProp2x16(this.clickPosPID)
      let vx = abs(mx - clickX)
      let vy = abs(my - clickY)
      if (sqrt(vx*vx + vy*vy) > START_DRAG_OFFSET) {
        obj.sendSceneEvent("drag_start")
        obj.setIntProp(this.isDraggingPID, 1)
      }
    }

    return RETCODE_NOTHING
  }

  function onLMouse(obj, mx, my, is_up, _bits) {
    obj.setIntProp(this.isMousePressedPID, is_up ? 0 : 1)
    if (is_up && !this.getIsObjDragging(obj))  // it's a simple click without movement
      obj.getScene().simulateMouseClick(mx, my, 1)

    obj.setIntProp(this.isDraggingPID, 0)
    if (!is_up)
      obj.setIntProp2x16(this.clickPosPID, mx, my)

    return  !is_up ? RETCODE_HALT : RETCODE_PROCESSED
  }

  function onDetach(obj) {
    obj.setIntProp(this.isDraggingPID, 0)
    obj.setIntProp(this.isMousePressedPID, 0)
    obj.setIntProp2x16(this.clickPosPID, 0, 0)
    return RETCODE_NOTHING
  }
}

replace_script_gui_behaviour("dragStartListener", DragStartListener)

