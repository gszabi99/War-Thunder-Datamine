local { markChildrenInteractive, markInteractive, markObjShortcutOnHover, getObjCentering
} = require("sqDagui/guiBhv/guiBhvUtils.nut")

const DEF_HOLD_DELAY = 700 //same with bhvButton

//blk params:
//  value
//  moveX, moveY  =  "linear", "closest"  (default = "closest")

class gui_bhv.posNavigator
{
  bhvId = "posNavigator"
  eventMask = ::EV_JOYSTICK | ::EV_PROCESS_SHORTCUTS | ::EV_MOUSE_L_BTN | ::EV_MOUSE_EXT_BTN | ::EV_MOUSE_DBL_CLICK
    | ::EV_ON_FOCUS_SET | ::EV_ON_FOCUS_LOST | ::EV_ON_CMD | ::EV_ON_INSERT_REMOVE | ::EV_TIMER | ::EV_MOUSE_NOT_ON_OBJ
  valuePID                 = ::dagui_propid.add_name_id("value")
  selectedPID              = ::dagui_propid.add_name_id("value") //value = selected
  moveTypeXPID             = ::dagui_propid.add_name_id("moveX")
  moveTypeYPID             = ::dagui_propid.add_name_id("moveY")
  fixedCoordPID            = ::dagui_propid.add_name_id("_fixedCoord")
  fixedAxisPID             = ::dagui_propid.add_name_id("_fixedAxis")
  disableFocusParentPID    = ::dagui_propid.add_name_id("disableFocusParent")
  disableFixedCoordPID     = ::dagui_propid.add_name_id("disableFixedCoord")
  lastMoveTimeMsecPID      = ::dagui_propid.add_name_id("_lastMoveTimeMsec")
  canSelectNonePID         = ::dagui_propid.add_name_id("canSelectNone")
  holdStartDelayPID        = ::dagui_propid.add_name_id("hold-start-delay"); //same id with bhvButton
  holdTimePID              = ::dagui_propid.add_name_id("hold-time");
  activatePushedIdxPID     = ::dagui_propid.add_name_id("_activatePushedIdx");
  fixedCoordTimeoutMsec = 5000

  canChooseByMClick = false

  function onAttach(obj)
  {
    if (obj?.value)
      setValue(obj, obj.value.tointeger())
    obj.timer_interval_msec = "100"
    markChildrenInteractive(obj, true)
    markObjShortcutOnHover(obj, true)
    return ::RETCODE_NOTHING
  }

  function onDetach(obj) {
    markChildrenInteractive(obj, false)
    markObjShortcutOnHover(obj, false)
    if (obj.getIntProp(activatePushedIdxPID, -1) >= 0)
      onActivateUnpushed(obj)
    return ::RETCODE_NOTHING
  }

  function onFocus(obj, event)
  {
    if (event == ::EV_ON_FOCUS_SET)
    {
      if (!isOnlyHover(obj))
        selectCurItem(obj)
      obj.getScene().playSound("focus")
    }
    else if (event == ::EV_ON_FOCUS_LOST)
    {
      if (canSelectOnlyFocused(obj))
        clearSelect(obj)
      resetFixedCoord(obj)
    }

    local selObj = getChildObj(obj, getSelectedValue(obj))
    if (selObj && selObj.isValid())
      selObj.markObjChanged()

    obj.sendNotify("set_focus")
    return (obj?.disableFocusParent == "yes")? ::RETCODE_HALT : ::RETCODE_NOTHING
  }

  function canSelectOnlyFocused(obj)
  {
    return obj?.clearOnFocusLost == "yes"
  }

  function getValue(obj)
  {
    return obj.getIntProp(valuePID, -1)
  }

  function setValue(obj, value)
  {
    selectItem(obj, value)
  }

  function getSelectedValue(obj)
  {
    return getValue(obj)
  }

  function getCanSelectNone(obj)
  {
    return obj?.canSelectNone == "yes"
  }

  function getChildObj(obj, value)
  {
    if (value >= 0 && value < obj.childrenCount())
      return obj.getChild(value)
    return null
  }

  function getMiddleCoords(obj)
  {
    local pos = obj.getPos()
    local size = obj.getSize()
    return [pos[0] + 0.5*size[0], pos[1] + 0.5*size[1]]
  }

  function getClosestCoords(obj, point)
  {
    local pos = obj.getPos()
    local size = obj.getSize()
    return [::clamp(point[0], pos[0], pos[0] + (size[0] < 0 ? 0 : size[0]))
            ::clamp(point[1], pos[1], pos[1] + (size[1] < 0 ? 0 : size[1]))
           ]
  }

  function selectCurItem(obj)
  {
    local byHover = isOnlyHover(obj)
    local value = byHover ? getHoveredChild(obj).hoveredIdx : getSelectedValue(obj)
    local valObj = getChildObj(obj, value)
    if (valObj && isSelectable(valObj) && selectItem(obj, value, valObj, false, true))
      return

    local coords = valObj? getMiddleCoords(valObj)
      : byHover ? ::get_dagui_mouse_cursor_pos_RC()
      : obj.getPos()

    local { foundObj, foundIdx } = getClosestItem(obj, coords)
    if (foundObj)
      selectItem(obj, foundIdx, foundObj, false, true)
  }

  function isSelectable(obj)
  {
    return obj.isVisible() && obj.isEnabled() && obj?.inactive != "yes" && !obj.isUnderWindow()
  }

  function eachSelectable(obj, handler) {
    for(local i = 0; i < obj.childrenCount(); i++)
    {
      local cObj = obj.getChild(i)
      if (isSelectable(cObj))
        if (handler(cObj, i))
          break
    }
  }

  function getClosestItem(obj, coords)
  {
    local foundObj = null
    local foundIdx = -1
    local sqDist = -1
    eachSelectable(obj, function(cObj, i) {
      local coords2 = getClosestCoords(cObj, coords)
      local cSqDist = (coords[0]-coords2[0])*(coords[0]-coords2[0]) + (coords[1]-coords2[1])*(coords[1]-coords2[1])
      if (sqDist < 0 || cSqDist < sqDist)
      {
        foundObj = cObj
        foundIdx = i
        sqDist = cSqDist
      }
      return !sqDist
    })
    return { foundObj = foundObj, foundIdx = foundIdx }
  }

  function selectItem(obj, idx, idxObj = null, needSound = true, needSetMouse = false)
  {
    local canSelectNone = getCanSelectNone(obj)

    if (!idxObj)
      idxObj = getChildObj(obj, idx)
    if ( ! idxObj && ! canSelectNone)
      return false

    local needNotify = false
    local prevIdx = getSelectedValue(obj)

    if(canSelectNone && prevIdx==idx)
    {
      if( ! idxObj)
        return false
      idxObj = null
      idx = -1
    }

    if (prevIdx!=idx || canSelectNone)
    {
      needNotify = true
      local prevObj = getChildObj(obj, prevIdx)
      setChildSelected(obj, prevObj, false)
    }

    obj.setIntProp(selectedPID, idx)

    if(idxObj)
    {
      setChildSelected(obj, idxObj, true)
      idxObj.scrollToView()
      if (needSetMouse)
        idxObj.setMouseCursorOnObject()
    }

    if (needSound && needNotify)
      obj.getScene().playSound(obj?.snd_select ? obj.snd_select : "choose")
    if (needNotify)
      onSelectAction(obj)
    return true
  }

  function hoverMove(obj, childObj, needSound = true) {
    childObj.scrollToView()
    childObj.setMouseCursorOnObject()
    if (needSound)
      obj.getScene().playSound(obj?.snd_select ? obj.snd_select : "choose")
  }

  function chooseItem(obj, idx, needSound = true) {}

  function onSelectAction(obj)
  {
    obj.sendNotify("select")
  }

  function activateAction(obj)
  {
    obj.sendNotify("dbl_click")
    if (obj.isValid())
      obj.sendNotify("activate")
  }

  function onShortcutActivate(obj, is_down)
  {
    if (is_down) {
      ::set_script_gui_behaviour_events(bhvId, obj, ::EV_MOUSE_HOVER_CHANGE)
      onActivatePushed(obj, getValue(obj))
      return ::RETCODE_HALT
    }

    local pushedIdx = obj.getIntProp(activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return ::RETCODE_HALT
    local wasHoldStarted = onActivateUnpushed(obj)
    if ((!wasHoldStarted || needActionAfterHold(obj)) && getValue(obj) == pushedIdx)
      activateAction(obj)
    return ::RETCODE_HALT
  }

  function findClickedObj(obj, mx, my)
  {
    local res = null
    eachSelectable(obj, function(iObj, i) {
      local pos = iObj.getPos()
      local size = iObj.getSize()
      if (mx >= pos[0] && mx <= pos[0]+size[0] && my >= pos[1] && my <= pos[1]+size[1])
        res = { idx = i, obj = iObj }
      return res != null
    })
    return res
  }

  function selectItemByClick(obj, mx, my) {
    local clicked = findClickedObj(obj, mx, my)
    if (!clicked)
      return -1

    selectItem(obj, clicked.idx, clicked.obj, !canChooseByMClick)
    resetFixedCoord(obj)
    obj.sendNotify("click")
    if (canChooseByMClick)
      chooseItem(obj, clicked.idx, true)
    return clicked.idx
  }

  function onLMouse(obj, mx, my, is_up, bits) {
    if (!is_up) {
      local isOnObj = !(bits & (is_up ? ::BITS_MOUSE_OUTSIDE : ::BITS_MOUSE_NOT_ON_OBJ))
      if (!isOnObj)
        return ::RETCODE_NOTHING
      local { idx = -1 } = findClickedObj(obj, mx, my)
      if (idx < 0)
        return ::RETCODE_NOTHING

      if (!(bits & ::BITS_MOUSE_TAP))
        obj.getScene().setProtectedMouseCapture(obj)
      onActivatePushed(obj, idx)
      return ::RETCODE_HALT
    }

    if (obj.isMouseCaptured())
      obj.getScene().setProtectedMouseCapture(null)

    local pushedIdx = obj.getIntProp(activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return ::RETCODE_NOTHING

    local wasHoldStarted = onActivateUnpushed(obj)
    if (wasHoldStarted && !needActionAfterHold(obj))
      return ::RETCODE_HALT
    local { idx = -1 } = findClickedObj(obj, mx, my)
    if (idx != pushedIdx)
      return ::RETCODE_HALT

    if (bits & ::BITS_MOUSE_DBL_CLICK) {
      if (getValue(obj) == -1)
        selectItemByClick(obj, mx, my)
      activateAction(obj)
      return ::RETCODE_HALT
    }

    selectItemByClick(obj, mx, my)
    return ::RETCODE_HALT
  }

  function onModalChange(obj, isModal) {
    if (!isModal)
      return
    if (obj.isMouseCaptured())
      obj.getScene().setProtectedMouseCapture(null)
    if (obj.getIntProp(activatePushedIdxPID, -1) >= 0)
      onActivateUnpushed(obj)
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, bits)
  {
    if (btn_id != 2)  //right mouse button
      return ::RETCODE_NOTHING
    if (is_up)
    {
      if (findClickedObj(obj, mx, my))
        obj.sendNotify("r_click")
      return ::RETCODE_PROCESSED
    }
    if (findClickedObj(obj, mx, my)?.idx == getValue(obj))
      return ::RETCODE_PROCESSED
    return selectItemByClick(obj, mx, my) >= 0 ? ::RETCODE_HALT : ::RETCODE_NOTHING
  }

  function onShortcutLeft(obj, is_down)
  {
    if (is_down)
      return moveSelect(obj, 0, -1)
    return ::RETCODE_NOTHING
  }

  function onShortcutRight(obj, is_down)
  {
    if (is_down)
      return moveSelect(obj, 0, 1)
    return ::RETCODE_NOTHING
  }

  function onShortcutDown(obj, is_down)
  {
    if (is_down)
      return moveSelect(obj, 1, 1)
    return ::RETCODE_NOTHING
  }

  function onShortcutUp(obj, is_down)
  {
    if (is_down)
      return moveSelect(obj, 1, -1)
    return ::RETCODE_NOTHING
  }

  function onShortcutSelect(obj, is_down)
  {
    if (!isShortcutsByHover(obj))
      return ::RETCODE_NOTHING

    local { hoveredObj, hoveredIdx } = getHoveredChild(obj)
    if (is_down) {
      if (hoveredIdx == null)
        return ::RETCODE_NOTHING
      ::set_script_gui_behaviour_events(bhvId, obj, ::EV_MOUSE_HOVER_CHANGE)
      onActivatePushed(obj, hoveredIdx)
      return ::RETCODE_HALT
    }

    local pushedIdx = obj.getIntProp(activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return ::RETCODE_HALT
    local wasHoldStarted = onActivateUnpushed(obj)
    if (pushedIdx != hoveredIdx)
      return ::RETCODE_HALT

    if (!wasHoldStarted || needActionAfterHold(obj))
      if (hoveredIdx == getSelectedValue(obj))
        activateAction(obj)
      else
        selectItem(obj, hoveredIdx, hoveredObj, true, true)
    return ::RETCODE_HALT
  }

  function moveSelect(obj, axis, dir)
  {
    local byHover = isShortcutsByHover(obj)
    local valueObj = (byHover ? getHoveredChild(obj).hoveredObj : null) ?? getChildObj(obj, getSelectedValue(obj))
    if (!valueObj)
    {
      local { foundObj, foundIdx } = getClosestItem(obj, byHover ? ::get_dagui_mouse_cursor_pos_RC() : obj.getPos())
      if (!foundObj)
        sendNotifyWrap(obj, axis, dir)
      else if (byHover)
        hoverMove(obj, foundObj)
      else
        selectItem(obj, foundIdx, foundObj, true, true)
      return ::RETCODE_HALT
    }
    return moveFromObj(obj, valueObj, axis, dir)
  }

  function moveFromObj(obj, objFrom, axis, dir)
  {
    local moveType = obj?[axis? "moveY" : "moveX"]
    local { foundObj, foundIdx } = moveType == "linear" ? moveSelectLinear(obj, objFrom, axis, dir)
      : moveSelectClosest(obj, objFrom, axis, dir)
    if (!foundObj)
      sendNotifyWrap(obj, axis, dir)
    else if (isOnlyHover(obj))
      hoverMove(obj, foundObj)
    else
      selectItem(obj, foundIdx, foundObj, true, true)
    return ::RETCODE_HALT
  }

  function sendNotifyWrap(obj, axis, dir)
  {
    obj.setIntProp(lastMoveTimeMsecPID, 0)

    local wrapDir = ::g_wrap_dir.getWrapDir(axis == 1, dir > 0)
    if (!obj.sendSceneEvent(wrapDir.notifyId))
      ::set_dirpad_event_processed(false)
  }

  function resetFixedCoord(obj)
  {
    obj.setIntProp(fixedAxisPID, -1)
  }

  function checkFixedCoord(obj, axis, newPos, canChangeFixedData = true)
  {
    if (obj?.disableFixedCoord == "yes")
      return newPos

    local fixedAxis = -1
    local timeMsec = ::dagor.getCurTime()
    if (timeMsec - obj.getIntProp(lastMoveTimeMsecPID, 0) < fixedCoordTimeoutMsec)
      fixedAxis = obj.getIntProp(fixedAxisPID, -1)
    obj.setIntProp(lastMoveTimeMsecPID, timeMsec)

    local objPos = obj.getPos()
    local coord = obj.getIntProp(fixedCoordPID)
    if (fixedAxis==axis && coord!=null)
      newPos[1-axis] = coord + objPos[1-axis]
    else if (canChangeFixedData)
    {
      obj.setIntProp(fixedAxisPID, axis)
      obj.setIntProp(fixedCoordPID, newPos[1-axis] - objPos[1-axis])
    }
    return newPos
  }

  function getScreenSizeByAxis(axis)
  {
    return axis ? ::screen_height() : ::screen_width()
  }

  function validateOutsidePos(obj, pos, axis, dir, isFromOutside)
  {
    if (!isFromOutside)
      return pos

    local objPos = obj.getPos()
    local objSize = obj.getSize()

    local screenByAxis = getScreenSizeByAxis(axis)
    objPos[axis] = ::clamp(objPos[axis], 0, screenByAxis)
    if (dir > 0 && pos[axis] > objPos[axis])
      pos[axis] -= screenByAxis
    else if (dir < 0 && pos[axis] < objPos[axis] + objSize[axis])
      pos[axis] += screenByAxis

    local objSizeByAxis = objSize[1-axis]
    pos[1-axis] = (objSizeByAxis > 0)
      ? ::clamp(pos[1-axis], objPos[1-axis], objPos[1-axis] + objSizeByAxis)
      : objPos[1-axis]
    return pos
  }

  function moveSelectClosest(obj, valueObj, axis, dir, isFromOutside = false)
  {
    local pos = isOnlyHover ? ::get_dagui_mouse_cursor_pos_RC() : getMiddleCoords(valueObj)
    pos = validateOutsidePos(obj, pos, axis, dir, isFromOutside)
    pos = checkFixedCoord(obj, axis, pos, !isFromOutside)

    local foundObj = null
    local foundIdx = -1
    local sqDist = -1
    eachSelectable(obj, function(cObj, i) {
      if (valueObj?.isEqual(cObj))
        return
      local pos2 = getClosestCoords(cObj, pos)
      if ((pos2[axis] - pos[axis]) * dir <= 0)
        return

      local primOffsetSq = (pos[axis] - pos2[axis]) * (pos[axis] - pos2[axis])
      local secOffsetSq = (pos[1-axis] - pos2[1-axis]) * (pos[1-axis] - pos2[1-axis])
      if (4 * primOffsetSq < secOffsetSq)  // 60 degrees
        return

      local cSqDist = primOffsetSq + secOffsetSq
      if (sqDist < 0 || cSqDist < sqDist)
      {
        foundObj = cObj
        foundIdx = i
        sqDist = cSqDist
      }
    })
    return { foundObj = foundObj, foundIdx = foundIdx }
  }

  function getClosestCoordsByAxis(obj, point, axis)
  {
    local pos = obj.getPos()
    local size = obj.getSize().map(@(v) ::max(0, v))
    return getObjCentering(obj)
      .map(@(pointerMul, a) a == axis
        ? ::clamp(point[a], pos[a], pos[a] + ::min(1.0, 0.5 + pointerMul) * size[a])
        : pos[a] + pointerMul*size[a])
  }

  function moveSelectLinear(obj, valueObj, axis, dir, isFromOutside = false)
  {
    local pos = isOnlyHover ? ::get_dagui_mouse_cursor_pos_RC() : getMiddleCoords(valueObj)
    pos = validateOutsidePos(obj, pos, axis, dir, isFromOutside)
    pos = checkFixedCoord(obj, axis, pos, !isFromOutside)
    local posDiv = isFromOutside ? getScreenSizeByAxis(axis) : 0.4 * valueObj.getSize()[1-axis]

    local foundObj = null
    local foundIdx = -1
    local distRating = -1 //best distance is not shorter
    eachSelectable(obj, function(cObj, i) {
      if (valueObj?.isEqual(cObj))
        return
      local pos2 = getClosestCoordsByAxis(cObj, pos, 1-axis)
      local distSubAxis = ::abs(pos[1-axis] - pos2[1-axis])
      if ((pos2[axis] - pos[axis]) * dir <= 0
          || distSubAxis > posDiv)
        return

      //we trying to keep choosen line, so distance in other line has much lower priority
      local distAxis = abs(pos[axis] - pos2[axis])
      local cDistRating = distAxis + 100 * distSubAxis
      if (distRating < 0 || cDistRating < distRating)
      {
        foundObj = cObj
        foundIdx = i
        distRating = cDistRating
      }
    })
    return { foundObj = foundObj, foundIdx = foundIdx }
  }

  function setChildSelected(obj, childObj, isSelected = true)
  {
    if (!childObj || !childObj.isValid())
      return false

    childObj["selected"] = canSelectChild(obj) && isSelected ? "yes" : "no"
    return true
  }

  function canSelectChild(obj)
  {
    return obj.isHovered() || !canSelectOnlyFocused(obj)
  }

  function clearSelect(obj)
  {
    local valueObj = getChildObj(obj, getSelectedValue(obj))
    setChildSelected(obj, valueObj, false)
  }

  function onShortcutCancel(obj, is_down)
  {
    if (!is_down)
      obj.sendNotify("cancel_edit")
    return ::RETCODE_HALT
  }

  function getHoveredChild(obj) {
    local hoveredObj = null
    local hoveredIdx = null
    eachSelectable(obj, function(child, i) {
      if (!child.isHovered())
        return false
      hoveredObj = child
      hoveredIdx = i
      return true
    })
    return { hoveredObj = hoveredObj, hoveredIdx = hoveredIdx }
  }

  function onGamepadMouseFinishMove(obj) {
    if (isOnlyHover(obj))
      return true;
    local { hoveredObj, hoveredIdx } = getHoveredChild(obj)
    if (hoveredObj && getSelectedValue(obj) != hoveredIdx)
      selectItem(obj, hoveredIdx, hoveredObj)
    return true;
  }

  function onActivatePushed(obj, childIdx) {
    if (childIdx < 0 || obj.getIntProp(activatePushedIdxPID, -1) >= 0)
      return
    obj.setIntProp(activatePushedIdxPID, childIdx)
    obj.setFloatProp(holdTimePID, 0.0)
    obj.sendSceneEvent("pushed")
  }

  getHoldStartDelay = @(obj) 0.001 * (obj.getFinalProp(holdStartDelayPID) ?? DEF_HOLD_DELAY).tointeger()

  function onActivateUnpushed(obj) {
    obj.setIntProp(activatePushedIdxPID, -1)
    ::del_script_gui_behaviour_events(bhvId, obj, ::EV_MOUSE_HOVER_CHANGE)

    local isHoldFulfilled = obj.sendSceneEvent("hold_stop")
    return isHoldFulfilled && obj.getFloatProp(holdTimePID, 0.0) >= getHoldStartDelay(obj)
  }

  function onMouseHover(obj, isHover) {
    if (!isHover && obj.getIntProp(activatePushedIdxPID, -1) >= 0)
      onActivateUnpushed(obj)
    return ::RETCODE_NOTHING;
  }

  function onTimer(obj, dt) {
    local pushedIdx = obj.getIntProp(activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return

    local holdTime = obj.getFloatProp(holdTimePID, 0.0)
    local holdDelay = getHoldStartDelay(obj)
    local needEvent = holdTime < holdDelay
    holdTime += dt
    obj.setFloatProp(holdTimePID, holdTime)
    if (needEvent && holdTime >= holdDelay)
      obj.sendSceneEvent("hold_start")
  }

  onInsert = @(obj, child, index) markInteractive(child, true)
  isShortcutsByHover = @(obj) obj.getFinalProp("shortcut-on-hover") == "yes"
  isOnlyHover = @(obj) obj.getFinalProp("move-only-hover") == "yes"
  needActionAfterHold = @(obj) obj.getFinalProp("need-action-after-hold") == "yes"
}
