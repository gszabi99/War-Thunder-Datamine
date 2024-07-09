from "%scripts/dagui_library.nut" import *
let { strip } = require("string")
// To immediately move an object along with the mouse (withoud mouse pressing)
// Fires the 'drag_drop' event on mouse up
let class DragDropMover {
  eventMask = EV_MOUSE_L_BTN | EV_MOUSE_NOT_ON_OBJ | EV_MOUSE_MOVE

  draggingOffsetPID = dagui_propid_add_name_id("_dragging_offset")
  isDragStartedPID = dagui_propid_add_name_id("_is_drag_started")
  dragBoundsPID = dagui_propid_add_name_id("bounds")
  dragBoundsArr = null

  function onMouseMove(obj, mx, my, _bits) {
    let isDragStarted = !!obj.getIntProp(this.isDragStartedPID, 0)
    let draggingObj = obj?.dragParent == "yes" ? obj.getParent() : obj

    if (!isDragStarted) {
      let pos = draggingObj.getPos()
      obj.setIntProp2x16(this.draggingOffsetPID, mx - pos[0], my - pos[1])
      obj.setIntProp(this.isDragStartedPID, 1)
    }

    let dragBounds = draggingObj.getFinalProp(this.dragBoundsPID) ?? ""
    let dragBoundsArr = dragBounds.split(",").map(@(v) to_integer_safe(strip(v), null, false))
    while(dragBoundsArr.len() < 4)
      dragBoundsArr.append(null)

    let [offsetX = 0, offsetY = 0] = obj.getIntProp2x16(this.draggingOffsetPID)
    local x = mx - offsetX
    local y = my - offsetY

    let draggingObjSize = draggingObj.getSize()

    if(dragBoundsArr[0] != null && dragBoundsArr[0] > x)
      x = dragBoundsArr[0]
    else if(dragBoundsArr[2] != null && dragBoundsArr[2] < x + draggingObjSize[0])
      x = dragBoundsArr[2] - draggingObjSize[0]

    if(dragBoundsArr[1] != null && dragBoundsArr[1] > y)
      y = dragBoundsArr[1]
    else if(dragBoundsArr[3] != null && dragBoundsArr[3] < y + draggingObjSize[1])
      y = dragBoundsArr[3] - draggingObjSize[1]

    draggingObj.pos = $"{x}, {y}"
    obj.sendSceneEvent("move")
    return RETCODE_NOTHING
  }

  function onLMouse(obj, _mx, _my, is_up, _bits) {
    if (is_up)
      obj.sendSceneEvent("drag_drop")
    return RETCODE_NOTHING
  }

  function onDetach(obj) {
    obj.setIntProp(this.isDragStartedPID, 0)
    obj.setIntProp2x16(this.draggingOffsetPID, 0, 0)
    return RETCODE_NOTHING
  }
}

replace_script_gui_behaviour("dragDropMover", DragDropMover)