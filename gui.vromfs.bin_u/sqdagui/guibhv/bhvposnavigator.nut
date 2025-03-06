from "%sqDagui/daguiNativeApi.nut" import *
from "math" import clamp, abs, max, min

let { get_time_msec } = require("dagor.time")
let { markChildrenInteractive, markInteractive, markObjShortcutOnHover, getObjCentering
} = require("%sqDagui/guiBhv/guiBhvUtils.nut")
let { g_wrap_dir } = require("wrapDir.nut")

const DEF_HOLD_DELAY = 700 //same with bhvButton

//blk params:
//  value
//  moveX, moveY  =  "linear", "closest"  (default = "closest")
//  isSkipMoving  =  "yes",    "no"       (default = "no")

let posNavigator = class {
  bhvId = "posNavigator"
  eventMask = EV_JOYSTICK | EV_PROCESS_SHORTCUTS | EV_MOUSE_L_BTN | EV_MOUSE_EXT_BTN | EV_MOUSE_DBL_CLICK
    | EV_ON_FOCUS_SET | EV_ON_FOCUS_LOST | EV_ON_CMD | EV_ON_INSERT_REMOVE | EV_TIMER | EV_MOUSE_NOT_ON_OBJ
  valuePID                 = dagui_propid_add_name_id("value")
  selectedPID              = dagui_propid_add_name_id("value") //value = selected
  moveTypeXPID             = dagui_propid_add_name_id("moveX")
  moveTypeYPID             = dagui_propid_add_name_id("moveY")
  fixedCoordPID            = dagui_propid_add_name_id("_fixedCoord")
  fixedAxisPID             = dagui_propid_add_name_id("_fixedAxis")
  disableFocusParentPID    = dagui_propid_add_name_id("disableFocusParent")
  disableFixedCoordPID     = dagui_propid_add_name_id("disableFixedCoord")
  lastMoveTimeMsecPID      = dagui_propid_add_name_id("_lastMoveTimeMsec")
  canSelectNonePID         = dagui_propid_add_name_id("canSelectNone")
  holdStartDelayPID        = dagui_propid_add_name_id("hold-start-delay"); //same id with bhvButton
  holdTimePID              = dagui_propid_add_name_id("hold-time");
  activatePushedIdxPID     = dagui_propid_add_name_id("_activatePushedIdx");
  fixedCoordTimeoutMsec = 5000

  canChooseByMClick = false

  function onAttach(obj) {
    if (obj?.value)
      this.setValue(obj, obj.value.tointeger())
    obj.timer_interval_msec = "100"
    markChildrenInteractive(obj, true)
    markObjShortcutOnHover(obj, true)
    return RETCODE_NOTHING
  }

  function onDetach(obj) {
    markChildrenInteractive(obj, false)
    markObjShortcutOnHover(obj, false)
    if (obj.getIntProp(this.activatePushedIdxPID, -1) >= 0)
      this.onActivateUnpushed(obj)
    return RETCODE_NOTHING
  }

  function onFocus(obj, event) {
    if (event == EV_ON_FOCUS_SET) {
      if (!this.isOnlyHover(obj))
        this.selectCurItem(obj)
      obj.getScene().playSound("focus")
    }
    else if (event == EV_ON_FOCUS_LOST) {
      if (this.canSelectOnlyFocused(obj))
        this.clearSelect(obj)
      this.resetFixedCoord(obj)
    }

    let selObj = this.getChildObj(obj, this.getSelectedValue(obj))
    if (selObj && selObj.isValid())
      selObj.markObjChanged()

    obj.sendNotify("set_focus")
    return (obj?.disableFocusParent == "yes") ? RETCODE_HALT : RETCODE_NOTHING
  }

  function canSelectOnlyFocused(obj) {
    return obj?.clearOnFocusLost == "yes"
  }

  function getValue(obj) {
    return obj.getIntProp(this.valuePID, -1)
  }

  function setValue(obj, value) {
    this.selectItem(obj, value)
  }

  function getSelectedValue(obj) {
    return this.getValue(obj)
  }

  function getCanSelectNone(obj) {
    return obj?.canSelectNone == "yes"
  }

  function getChildObj(obj, value) {
    if (value >= 0 && value < obj.childrenCount())
      return obj.getChild(value)
    return null
  }

  function getMiddleCoords(obj) {
    let pos = obj.getPos()
    let size = obj.getSize()
    return [pos[0] + 0.5 * size[0], pos[1] + 0.5 * size[1]]
  }

  function getClosestCoords(obj, point) {
    let pos = obj.getPos()
    let size = obj.getSize()
    return [clamp(point[0], pos[0], pos[0] + (size[0] < 0 ? 0 : size[0]))
            clamp(point[1], pos[1], pos[1] + (size[1] < 0 ? 0 : size[1]))
           ]
  }

  function selectCurItem(obj) {
    let byHover = this.isOnlyHover(obj)
    let value = byHover ? this.getHoveredChild(obj).hoveredIdx : this.getSelectedValue(obj)
    let valObj = this.getChildObj(obj, value)
    if (valObj && this.isSelectable(valObj) && this.selectItem(obj, value, valObj, false, true))
      return

    let coords = valObj ? this.getMiddleCoords(valObj)
      : byHover ? get_dagui_mouse_cursor_pos_RC()
      : obj.getPos()

    let { foundObj, foundIdx } = this.getClosestItem(obj, coords)
    if (foundObj)
      this.selectItem(obj, foundIdx, foundObj, false, true)
  }

  function isSelectable(obj) {
    return obj.isVisible() && obj.isEnabled() && obj.getFinalProp("inactive") != "yes" && !obj.isUnderWindow()
  }

  function eachSelectable(obj, handler) {
    for (local i = 0; i < obj.childrenCount(); i++) {
      let cObj = obj.getChild(i)
      if (this.isSelectable(cObj))
        if (handler(cObj, i))
          break
    }
  }

  function getClosestItem(obj, coords) {
    local foundObj = null
    local foundIdx = -1
    local sqDist = -1
    this.eachSelectable(obj, function(cObj, i) {
      let coords2 = this.getClosestCoords(cObj, coords)
      let cSqDist = (coords[0] - coords2[0]) * (coords[0] - coords2[0]) + (coords[1] - coords2[1]) * (coords[1] - coords2[1])
      if (sqDist < 0 || cSqDist < sqDist) {
        foundObj = cObj
        foundIdx = i
        sqDist = cSqDist
      }
      return !sqDist
    })
    return { foundObj = foundObj, foundIdx = foundIdx }
  }

  function selectItem(obj, idx, idxObj = null, needSound = true, needSetMouse = false) {
    let canSelectNone = this.getCanSelectNone(obj)

    if (!idxObj)
      idxObj = this.getChildObj(obj, idx)
    if (! idxObj && ! canSelectNone)
      return false

    local needNotify = false
    let prevIdx = this.getSelectedValue(obj)

    if (canSelectNone && prevIdx == idx) {
      if (! idxObj)
        return false
      idxObj = null
      idx = -1
    }

    if (prevIdx != idx || canSelectNone) {
      needNotify = true
      let prevObj = this.getChildObj(obj, prevIdx)
      this.setChildSelected(obj, prevObj, false)
    }

    obj.setIntProp(this.selectedPID, idx)

    if (idxObj) {
      this.setChildSelected(obj, idxObj, true)
      idxObj.scrollToView()
      if (needSetMouse)
        idxObj.setMouseCursorOnObject()
    }

    if (needSound && needNotify)
      obj.getScene().playSound(obj?.snd_select ? obj.snd_select : "choose")
    if (needNotify)
      this.onSelectAction(obj)
    return true
  }

  function hoverMove(obj, childObj, needSound = true) {
    childObj.scrollToView()
    childObj.setMouseCursorOnObject()
    if (needSound)
      obj.getScene().playSound(obj?.snd_select ? obj.snd_select : "choose")
  }

  function chooseItem(_obj, _idx, _needSound = true) {}

  function onSelectAction(obj) {
    obj.sendNotify("select")
  }

  function activateAction(obj) {
    obj.sendNotify("dbl_click")
    if (obj.isValid())
      obj.sendNotify("activate")
  }

  function onShortcutActivate(obj, is_down) {
    if (is_down) {
      set_script_gui_behaviour_events(this.bhvId, obj, EV_MOUSE_HOVER_CHANGE)
      this.onActivatePushed(obj, this.getValue(obj))
      return RETCODE_HALT
    }

    let pushedIdx = obj.getIntProp(this.activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return RETCODE_HALT
    let wasHoldStarted = this.onActivateUnpushed(obj)
    if ((!wasHoldStarted || this.needActionAfterHold(obj)) && this.getValue(obj) == pushedIdx)
      this.activateAction(obj)
    return RETCODE_HALT
  }

  function findClickedObj(obj, mx, my) {
    local res = null
    this.eachSelectable(obj, function(iObj, i) {
      let pos = iObj.getPos()
      let size = iObj.getSize()
      if (mx >= pos[0] && mx <= pos[0] + size[0] && my >= pos[1] && my <= pos[1] + size[1])
        res = { idx = i, obj = iObj }
      return res != null
    })
    return res
  }

  function selectItemByClick(obj, mx, my, isNeedSendClick = true) {
    let clicked = this.findClickedObj(obj, mx, my)
    if (!clicked)
      return -1

    this.selectItem(obj, clicked.idx, clicked.obj, !this.canChooseByMClick)
    this.resetFixedCoord(obj)
    if (isNeedSendClick)
      obj.sendNotify("click")
    if (this.canChooseByMClick)
      this.chooseItem(obj, clicked.idx, true)
    return clicked.idx
  }

  function onLMouse(obj, mx, my, is_up, bits) {
    if (!is_up) {
      let isOnObj = !(bits & (is_up ? BITS_MOUSE_OUTSIDE : BITS_MOUSE_NOT_ON_OBJ))
      if (!isOnObj)
        return RETCODE_NOTHING
      let { idx = -1 } = this.findClickedObj(obj, mx, my)
      if (idx < 0)
        return RETCODE_NOTHING

      if (!(bits & BITS_MOUSE_TAP))
        obj.getScene().setProtectedMouseCapture(obj)
      this.onActivatePushed(obj, idx)
      return RETCODE_HALT
    }

    if (obj.isMouseCaptured())
      obj.getScene().setProtectedMouseCapture(null)

    let pushedIdx = obj.getIntProp(this.activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return RETCODE_NOTHING

    let wasHoldStarted = this.onActivateUnpushed(obj)
    if (wasHoldStarted && !this.needActionAfterHold(obj))
      return RETCODE_HALT
    let { idx = -1 } = this.findClickedObj(obj, mx, my)
    if (idx != pushedIdx)
      return RETCODE_HALT

    if (bits & BITS_MOUSE_DBL_CLICK) {
      let curValue = this.getValue(obj)
      if (curValue  == -1)
        this.selectItemByClick(obj, mx, my, false)
      else if (idx != curValue)
        return RETCODE_NOTHING

      this.activateAction(obj)
      return RETCODE_HALT
    }

    this.selectItemByClick(obj, mx, my)
    return RETCODE_HALT
  }

  function onModalChange(obj, isModal) {
    if (!isModal)
      return
    if (obj.isMouseCaptured())
      obj.getScene().setProtectedMouseCapture(null)
    if (obj.getIntProp(this.activatePushedIdxPID, -1) >= 0)
      this.onActivateUnpushed(obj)
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, bits) {
    if (btn_id != 2)  //right mouse button
      return RETCODE_NOTHING

    let isOnObj = !(bits & (is_up ? BITS_MOUSE_OUTSIDE : BITS_MOUSE_NOT_ON_OBJ))
    if (!isOnObj)
      return RETCODE_NOTHING

    if (is_up) {
      if (this.findClickedObj(obj, mx, my))
        obj.sendNotify("r_click")
      return RETCODE_PROCESSED
    }
    if (this.findClickedObj(obj, mx, my)?.idx == this.getValue(obj))
      return RETCODE_PROCESSED
    return this.selectItemByClick(obj, mx, my, false) >= 0 ? RETCODE_HALT : RETCODE_NOTHING
  }

  function onShortcutLeft(obj, is_down) {
    if (is_down)
      return this.moveSelect(obj, 0, -1)
    return RETCODE_NOTHING
  }

  function onShortcutRight(obj, is_down) {
    if (is_down)
      return this.moveSelect(obj, 0, 1)
    return RETCODE_NOTHING
  }

  function onShortcutDown(obj, is_down) {
    if (is_down)
      return this.moveSelect(obj, 1, 1)
    return RETCODE_NOTHING
  }

  function onShortcutUp(obj, is_down) {
    if (is_down)
      return this.moveSelect(obj, 1, -1)
    return RETCODE_NOTHING
  }

  function onShortcutSelect(obj, is_down) {
    let { hoveredObj, hoveredIdx } = this.getHoveredChild(obj)
    if (is_down) {
      if (hoveredIdx == null)
        return RETCODE_NOTHING
      set_script_gui_behaviour_events(this.bhvId, obj, EV_MOUSE_HOVER_CHANGE)
      this.onActivatePushed(obj, hoveredIdx)
      return RETCODE_HALT
    }

    let pushedIdx = obj.getIntProp(this.activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return RETCODE_HALT
    let wasHoldStarted = this.onActivateUnpushed(obj)
    if (pushedIdx != hoveredIdx)
      return RETCODE_HALT

    if (!wasHoldStarted || this.needActionAfterHold(obj))
      if (hoveredIdx == this.getSelectedValue(obj))
        this.activateAction(obj)
      else
        this.selectItem(obj, hoveredIdx, hoveredObj, true, true)
    return RETCODE_HALT
  }

  function moveSelect(obj, axis, dir) {
    let valueObj = this.getHoveredChild(obj).hoveredObj ?? this.getChildObj(obj, this.getSelectedValue(obj))
    let moveType = obj?[axis ? "moveY" : "moveX"]

    if (obj?.isSkipMoving == "yes")
      return RETCODE_NOTHING

    let { foundObj, foundIdx } = moveType == "linear"
      ? this.moveSelectLinear(obj, valueObj, axis, dir)
      : this.moveSelectClosest(obj, valueObj, axis, dir)

    if (!foundObj)
      this.sendNotifyWrap(obj, axis, dir)
    else if (this.isOnlyHover(obj))
      this.hoverMove(obj, foundObj)
    else
      this.selectItem(obj, foundIdx, foundObj, true, true)

    return RETCODE_HALT
  }

  function sendNotifyWrap(obj, axis, dir) {
    obj.setIntProp(this.lastMoveTimeMsecPID, 0)

    let wrapDir = g_wrap_dir.getWrapDir(axis == 1, dir > 0)
    if (!obj.sendSceneEvent(wrapDir.notifyId))
      set_dirpad_event_processed(false)
  }

  function resetFixedCoord(obj) {
    obj.setIntProp(this.fixedAxisPID, -1)
  }

  function checkFixedCoord(obj, axis, newPos) {
    if (obj?.disableFixedCoord == "yes")
      return newPos

    local fixedAxis = -1
    let timeMsec = get_time_msec()
    if (timeMsec - obj.getIntProp(this.lastMoveTimeMsecPID, 0) < this.fixedCoordTimeoutMsec)
      fixedAxis = obj.getIntProp(this.fixedAxisPID, -1)
    obj.setIntProp(this.lastMoveTimeMsecPID, timeMsec)

    let objPos = obj.getPos()
    let coord = obj.getIntProp(this.fixedCoordPID)
    if (fixedAxis == axis && coord != null)
      newPos[1 - axis] = coord + objPos[1 - axis]
    else {
      obj.setIntProp(this.fixedAxisPID, axis)
      obj.setIntProp(this.fixedCoordPID, newPos[1 - axis] - objPos[1 - axis])
    }
    return newPos
  }

  function getScreenSizeByAxis(axis) {
    return axis ? screen_height() : screen_width()
  }

  function moveSelectClosest(obj, valueObj, axis, dir) {
    local pos = this.isOnlyHover(obj) || valueObj == null
      ? get_dagui_mouse_cursor_pos_RC()
      : this.getMiddleCoords(valueObj)
    pos = this.checkFixedCoord(obj, axis, pos)

    local foundObj = null
    local foundIdx = -1
    local sqDist = -1
    this.eachSelectable(obj, function(cObj, i) {
      if (valueObj?.isEqual(cObj))
        return
      let pos2 = this.getClosestCoords(cObj, pos)
      if ((pos2[axis] - pos[axis]) * dir <= 0)
        return

      let primOffsetSq = (pos[axis] - pos2[axis]) * (pos[axis] - pos2[axis])
      let secOffsetSq = (pos[1 - axis] - pos2[1 - axis]) * (pos[1 - axis] - pos2[1 - axis])
      if (4 * primOffsetSq < secOffsetSq)  // 60 degrees
        return

      let cSqDist = primOffsetSq + secOffsetSq
      if (sqDist < 0 || cSqDist < sqDist) {
        foundObj = cObj
        foundIdx = i
        sqDist = cSqDist
      }
    })
    return { foundObj = foundObj, foundIdx = foundIdx }
  }

  function getClosestCoordsByAxis(obj, point, axis) {
    let pos = obj.getPos()
    let size = obj.getSize().map(@(v) max(0, v))
    return getObjCentering(obj)
      .map(@(pointerMul, a) a == axis
        ? clamp(point[a], pos[a], pos[a] + min(1.0, 0.5 + pointerMul) * size[a])
        : pos[a] + pointerMul * size[a])
  }

  function moveSelectLinear(obj, valueObj, axis, dir) {
    local pos = this.isOnlyHover(obj) || valueObj == null
      ? get_dagui_mouse_cursor_pos_RC()
      : this.getMiddleCoords(valueObj)
    pos = this.checkFixedCoord(obj, axis, pos)
    let posDiv = valueObj == null
      ? this.getScreenSizeByAxis(axis)
      : 0.4 * valueObj.getSize()[1 - axis]

    local foundObj = null
    local foundIdx = -1
    local distRating = -1 //best distance is not shorter
    this.eachSelectable(obj, function(cObj, i) {
      if (valueObj?.isEqual(cObj))
        return
      let pos2 = this.getClosestCoordsByAxis(cObj, pos, 1 - axis)
      let distSubAxis = abs(pos[1 - axis] - pos2[1 - axis])
      if ((pos2[axis] - pos[axis]) * dir <= 0
          || distSubAxis > posDiv)
        return

      //we trying to keep choosen line, so distance in other line has much lower priority
      let distAxis = abs(pos[axis] - pos2[axis])
      let cDistRating = distAxis + 100 * distSubAxis
      if (distRating < 0 || cDistRating < distRating) {
        foundObj = cObj
        foundIdx = i
        distRating = cDistRating
      }
    })
    return { foundObj = foundObj, foundIdx = foundIdx }
  }

  function setChildSelected(obj, childObj, isSelected = true) {
    if (!childObj || !childObj.isValid())
      return false

    childObj["selected"] = this.canSelectChild(obj) && isSelected ? "yes" : "no"
    return true
  }

  function canSelectChild(obj) {
    return obj.isHovered() || !this.canSelectOnlyFocused(obj)
  }

  function clearSelect(obj) {
    let valueObj = this.getChildObj(obj, this.getSelectedValue(obj))
    this.setChildSelected(obj, valueObj, false)
  }

  function onShortcutCancel(obj, is_down) {
    if (!is_down)
      obj.sendNotify("cancel_edit")
    return RETCODE_HALT
  }

  function getHoveredChild(obj) {
    local hoveredObj = null
    local hoveredIdx = null
    this.eachSelectable(obj, function(child, i) {
      if (!child.isHovered())
        return false
      hoveredObj = child
      hoveredIdx = i
      return true
    })
    return { hoveredObj, hoveredIdx }
  }

  function onGamepadMouseFinishMove(obj) {
    if (this.isOnlyHover(obj))
      return true;
    let { hoveredObj, hoveredIdx } = this.getHoveredChild(obj)
    if (hoveredObj && this.getSelectedValue(obj) != hoveredIdx)
      this.selectItem(obj, hoveredIdx, hoveredObj)
    return true;
  }

  function onActivatePushed(obj, childIdx) {
    if (childIdx < 0 || obj.getIntProp(this.activatePushedIdxPID, -1) >= 0)
      return
    obj.setIntProp(this.activatePushedIdxPID, childIdx)
    obj.setFloatProp(this.holdTimePID, 0.0)
    obj.sendSceneEvent("pushed")
  }

  getHoldStartDelay = @(obj) 0.001 * (obj.getFinalProp(this.holdStartDelayPID) ?? DEF_HOLD_DELAY).tointeger()

  function onActivateUnpushed(obj) {
    obj.setIntProp(this.activatePushedIdxPID, -1)
    del_script_gui_behaviour_events(this.bhvId, obj, EV_MOUSE_HOVER_CHANGE)

    let isHoldFulfilled = obj.sendSceneEvent("hold_stop")
    return isHoldFulfilled && obj.getFloatProp(this.holdTimePID, 0.0) >= this.getHoldStartDelay(obj)
  }

  function onMouseHover(obj, isHover) {
    if (!isHover && obj.getIntProp(this.activatePushedIdxPID, -1) >= 0)
      this.onActivateUnpushed(obj)
    return RETCODE_NOTHING;
  }

  function onTimer(obj, dt) {
    let pushedIdx = obj.getIntProp(this.activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return

    local holdTime = obj.getFloatProp(this.holdTimePID, 0.0)
    let holdDelay = this.getHoldStartDelay(obj)
    let needEvent = holdTime < holdDelay
    holdTime += dt
    obj.setFloatProp(this.holdTimePID, holdTime)
    if (needEvent && holdTime >= holdDelay)
      obj.sendSceneEvent("hold_start")
  }

  onInsert = @(_obj, child, _index) markInteractive(child, true)
  isOnlyHover = @(obj) obj.getFinalProp("move-only-hover") == "yes"
  needActionAfterHold = @(obj) obj.getFinalProp("need-action-after-hold") == "yes"
}

replace_script_gui_behaviour("posNavigator", posNavigator)

return {posNavigator}