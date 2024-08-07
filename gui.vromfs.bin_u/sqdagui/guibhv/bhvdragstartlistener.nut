
from "%scripts/dagui_library.nut" import *
let { abs, sqrt } = require("math")
let { get_time_msec } = require("dagor.time")

const START_DRAG_OFFSET = 3
const DOUBLE_CLICK_TRESHOLD = 250

// To detect the start of drag gestures without moving an object
let class DragStartListener {
  eventMask = EV_MOUSE_L_BTN | EV_MOUSE_NOT_ON_OBJ | EV_MOUSE_MOVE

  isDraggingPID = dagui_propid_add_name_id("is_dragging")
  clickPosPID = dagui_propid_add_name_id("_click_pos")
  isMousePressedPID = dagui_propid_add_name_id("is_mouse_pressed")
  lastClickedTimePID = dagui_propid_add_name_id("last_clicked_time")

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

  function findParentObj(sourceObj) {
    let parentObjTag = sourceObj?.proxyEventsParentTag
    if (parentObjTag == null)
      return null

    local curParent = sourceObj?.getParent()
    local foundObj = null
    while(curParent != null) {
      if (curParent?.tag == parentObjTag) {
        foundObj = curParent
        break
      }
      curParent = curParent?.getParent()
    }
    return foundObj
  }

  function notifyParentObj(sourceObj, event) {
    let foundObj = this.findParentObj(sourceObj)
    if (foundObj?.isValid())
      foundObj.sendNotify(event)
  }

  function notifyParentRMouse(sourceObj, mx, my, is_up, bits) {
    let foundObj = this.findParentObj(sourceObj)
    if (foundObj?.isValid())
      foundObj?.sendMouseRBtn(mx, my, is_up, bits)
  }

  function handleDblClick(obj, is_up) {
    let curTime = get_time_msec()
    if (!is_up) {
      let lastClickedTime = obj.getIntProp(this.lastClickedTimePID) ?? 0
      if (curTime - lastClickedTime <= DOUBLE_CLICK_TRESHOLD)
        this.notifyParentObj(obj, "dbl_click")
    }

    if (is_up)
      obj.setIntProp(this.lastClickedTimePID, curTime)
  }

  function onLMouse(obj, mx, my, is_up, bits) {
    obj.setIntProp(this.isMousePressedPID, is_up ? 0 : 1)
    obj.setIntProp(this.isDraggingPID, 0)
    if (!this.getIsObjDragging(obj))
      this.notifyParentRMouse(obj, mx, my, is_up, bits) // !!!FIX ME - Due to a bug in the posNavigator, it does not receive onLMouse events.
                                                        // As a workround, we throw onExtMouse into it.
                                                        // The right click was left because bhvPosNavigator did not process the left click as expected.


    if (!is_up)
      obj.setIntProp2x16(this.clickPosPID, mx, my)
    if (obj?.proxyEventsParentTag)
      this.handleDblClick(obj, is_up)

    return !is_up ? RETCODE_HALT : RETCODE_PROCESSED
  }

  function onDetach(obj) {
    obj.setIntProp(this.isDraggingPID, 0)
    obj.setIntProp(this.isMousePressedPID, 0)
    obj.setIntProp2x16(this.clickPosPID, 0, 0)
    return RETCODE_NOTHING
  }
}

replace_script_gui_behaviour("dragStartListener", DragStartListener)
