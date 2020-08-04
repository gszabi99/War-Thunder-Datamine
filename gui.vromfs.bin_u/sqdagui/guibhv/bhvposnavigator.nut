//blk params:
//  value
//  moveX, moveY  =  "linear", "closest"  (default = "closest")

class gui_bhv.posNavigator
{
  eventMask = ::EV_JOYSTICK | ::EV_PROCESS_SHORTCUTS | ::EV_MOUSE_L_BTN | ::EV_MOUSE_EXT_BTN | ::EV_MOUSE_DBL_CLICK
              | ::EV_ON_FOCUS_SET | ::EV_ON_FOCUS_LOST | ::EV_ON_CMD
  valuePID    = ::dagui_propid.add_name_id("value")
  selectedPID = ::dagui_propid.add_name_id("value") //value = selected
  moveTypeXPID = ::dagui_propid.add_name_id("moveX")
  moveTypeYPID = ::dagui_propid.add_name_id("moveY")
  fixedCoordPID = ::dagui_propid.add_name_id("_fixedCoord")
  fixedAxisPID = ::dagui_propid.add_name_id("_fixedAxis")
  disableFocusParentPID = ::dagui_propid.add_name_id("disableFocusParent")
  disableFixedCoordPID = ::dagui_propid.add_name_id("disableFixedCoord")
  lastMoveTimeMsecPID = ::dagui_propid.add_name_id("_lastMoveTimeMsec")
  canSelectNonePID = ::dagui_propid.add_name_id("canSelectNone")
  fixedCoordTimeoutMsec = 5000

  canChooseByMClick = false

  function onAttach(obj)
  {
    if (obj?.value)
      setValue(obj, obj.value.tointeger())
    return ::RETCODE_NOTHING
  }

  function onFocus(obj, event)
  {
    if (event == ::EV_ON_FOCUS_SET)
    {
      if (!checkWrapFrom(obj))
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
    return obj?.clearOnFocusLost != "no"
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

  function getClosestCoordsByAxis(obj, point, axis)
  {
    local pos = obj.getPos()
    local size = obj.getSize()
    local res = []
    for(local a= 0; a < 2; a++)
      res.append(a == axis
        ? ::clamp(point[a], pos[a], pos[a] + (size[a] < 0 ? 0 : size[a]))
        : pos[a] + 0.5*size[a])
    return res
  }

  function selectCurItem(obj)
  {
    local value = getSelectedValue(obj)
    local valObj = getChildObj(obj, value)
    if (valObj && isSelectable(valObj) && selectItem(obj, value, valObj, false))
      return

    local coords = valObj? getMiddleCoords(valObj) : obj.getPos()
    selectClosestItem(obj, coords, false)
  }

  function isSelectable(obj)
  {
    return obj.isVisible() && obj.isEnabled() && obj?.inactive != "yes"
  }

  function selectClosestItem(obj, coords, needSound)
  {
    local foundObj = null
    local foundIdx = -1
    local sqDist = -1
    for(local i = 0; i < obj.childrenCount(); i++)
    {
      local cObj = obj.getChild(i)
      if (!isSelectable(cObj))
        continue

      local coords2 = getClosestCoords(cObj, coords)
      local cSqDist = (coords[0]-coords2[0])*(coords[0]-coords2[0]) + (coords[1]-coords2[1])*(coords[1]-coords2[1])
      if (sqDist < 0 || cSqDist < sqDist)
      {
        foundObj = cObj
        foundIdx = i
        sqDist = cSqDist
      }
      if (!sqDist)
        break
    }
    if (foundObj)
      selectItem(obj, foundIdx, foundObj, needSound)
    return foundObj
  }

  function selectItem(obj, idx, idxObj = null, needSound = true)
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
    }

    if (needSound && needNotify)
      obj.getScene().playSound(obj?.snd_select ? obj.snd_select : "choose")
    if (needNotify)
      onSelectAction(obj)
    return true
  }

  function chooseItem(obj, idx, needSound = true) {}

  function onSelectAction(obj)
  {
    obj.sendNotify("select")
  }

  function activateAction(obj)
  {
    obj.sendNotify("dbl_click");
    obj.sendNotify("activate");
  }

  function onShortcutActivate(obj, is_down)
  {
    if (!is_down)
      activateAction(obj)
    return ::RETCODE_HALT;
  }

  function findClickedObj(obj, mx, my)
  {
    for (local i=0; i < obj.childrenCount(); i++)
    {
      local iObj = obj.getChild(i)
      if (!isSelectable(iObj))
        continue

      local pos = iObj.getPos()
      local size = iObj.getSize()
      if (mx >= pos[0] && mx <= pos[0]+size[0] && my >= pos[1] && my <= pos[1]+size[1])
        return { idx = i, obj = iObj }
    }
    return null
  }

  function onLMouse(obj, mx, my, is_up, bits)
  {
    if (is_up)
      return ::RETCODE_NOTHING

    if (!is_up && (bits&::BITS_MOUSE_DBL_CLICK) && (bits&::BITS_MOUSE_BTN_L))
    {
      activateAction(obj)
      return ::RETCODE_HALT;
    }

    local clicked = findClickedObj(obj, mx, my)
    if (clicked)
    {
      selectItem(obj, clicked.idx, clicked.obj, !canChooseByMClick)
      resetFixedCoord(obj)
      obj.sendNotify("click")
      if (canChooseByMClick)
        chooseItem(obj, clicked.idx, true)
      return ::RETCODE_HALT
    }
    return ::RETCODE_NOTHING
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
    return onLMouse(obj, mx, my, is_up, bits);
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

  function moveSelect(obj, axis, dir)
  {
    local valueObj = getChildObj(obj, getSelectedValue(obj))
    if (!valueObj)
    {
      if (!selectClosestItem(obj, obj.getPos(), true))
        sendNotifyWrap(obj, axis, dir)
      return ::RETCODE_HALT
    }

    return moveFromObj(obj, valueObj, axis, dir)
  }

  function moveFromObj(obj, objFrom, axis, dir, isFromOutside = false)
  {
    local moveType = obj?[axis? "moveY" : "moveX"]
    if (moveType=="linear")
      return moveSelectLinear(obj, objFrom, axis, dir, isFromOutside)
    return moveSelectClosest(obj, objFrom, axis, dir, isFromOutside)
  }

  function checkWrapFrom(obj)
  {
    local wrapObj = ::g_last_nav_wrap.getWrapObj()
    if (!wrapObj)
      return false

    local wrapDir = ::g_last_nav_wrap.getWrapDir()
    ::g_last_nav_wrap.clearWrap()
    moveFromObj(obj, wrapObj, wrapDir.isVertical ? 1 : 0, wrapDir.isPositive ? 1 : -1, true)
    return true
  }

  function sendNotifyWrap(obj, axis, dir)
  {
    local wrapDir = ::g_wrap_dir.getWrapDir(axis == 1, dir > 0)
    local wrapObj = getChildObj(obj, getSelectedValue(obj))
    if (!wrapObj)
      wrapObj = obj
    ::g_last_nav_wrap.setWrapFrom(wrapObj, wrapDir)

    obj.sendNotify(wrapDir.notifyId)
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
    local pos = getMiddleCoords(valueObj)
    pos = validateOutsidePos(obj, pos, axis, dir, isFromOutside)
    pos = checkFixedCoord(obj, axis, pos, !isFromOutside)

    local foundObj = null
    local foundIdx = -1
    local sqDist = -1
    for(local i = 0; i < obj.childrenCount(); i++)
    {
      local cObj = obj.getChild(i)
      if (!isSelectable(cObj))
        continue

      local pos2 = getClosestCoords(cObj, pos)
      if ((pos2[axis] - pos[axis]) * dir <= 0)
        continue

      local primOffsetSq = (pos[axis] - pos2[axis]) * (pos[axis] - pos2[axis])
      local secOffsetSq = (pos[1-axis] - pos2[1-axis]) * (pos[1-axis] - pos2[1-axis])
      if (4 * primOffsetSq < secOffsetSq)  // 60 degrees
        continue

      local cSqDist = primOffsetSq + secOffsetSq
      if (sqDist < 0 || cSqDist < sqDist)
      {
        foundObj = cObj
        foundIdx = i
        sqDist = cSqDist
      }
    }
    if (foundObj)
      selectItem(obj, foundIdx, foundObj)
    else
      sendNotifyWrap(obj, axis, dir)
    return ::RETCODE_HALT
  }

  function moveSelectLinear(obj, valueObj, axis, dir, isFromOutside = false)
  {
    local pos = getMiddleCoords(valueObj)
    pos = validateOutsidePos(obj, pos, axis, dir, isFromOutside)
    pos = checkFixedCoord(obj, axis, pos, !isFromOutside)
    local posDiv = isFromOutside ? getScreenSizeByAxis(axis) : 0.4 * valueObj.getSize()[1-axis]

    local foundObj = null
    local foundIdx = -1
    local distRating = -1 //best distance is not shorter
    for(local i = 0; i < obj.childrenCount(); i++)
    {
      local cObj = obj.getChild(i)
      if (!isSelectable(cObj))
        continue
      local pos2 = getClosestCoordsByAxis(cObj, pos, 1-axis)
      local distSubAxis = ::abs(pos[1-axis] - pos2[1-axis])
      if ((pos2[axis] - pos[axis]) * dir <= 0
          || distSubAxis > posDiv)
        continue

      //we trying to keep choosen line, so distance in other line has much lower priority
      local distAxis = abs(pos[axis] - pos2[axis])
      local cDistRating = distAxis + 100 * distSubAxis
      if (distRating < 0 || cDistRating < distRating)
      {
        foundObj = cObj
        foundIdx = i
        distRating = cDistRating
      }
    }
    if (foundObj)
      selectItem(obj, foundIdx, foundObj)
    else
      sendNotifyWrap(obj, axis, dir)
    return ::RETCODE_HALT
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
    return obj.isFocused() || !canSelectOnlyFocused(obj)
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
}
