from "%scripts/dagui_library.nut" import *

// To immediately move an object along with the mouse (withoud mouse pressing)
// Fires the 'drag_drop' event on mouse up
let class DragDropMover {
  eventMask = EV_MOUSE_L_BTN | EV_MOUSE_NOT_ON_OBJ | EV_MOUSE_MOVE

  draggingOffsetPID = dagui_propid_add_name_id("_dragging_offset")
  isDragStartedPID = dagui_propid_add_name_id("_is_drag_started")

  function onMouseMove(obj, mx, my, _bits) {
    let isDragStarted = !!obj.getIntProp(this.isDragStartedPID, 0)
    let draggingObj = obj?.dragParent == "yes" ? obj.getParent() : obj

    if (!isDragStarted) {
      let pos = draggingObj.getPos()
      obj.setIntProp2x16(this.draggingOffsetPID, mx - pos[0], my - pos[1])
      obj.setIntProp(this.isDragStartedPID, 1)
    }

    let [offsetX = 0, offsetY = 0] = obj.getIntProp2x16(this.draggingOffsetPID)
    let x = mx - offsetX
    let y = my - offsetY

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