local stdMath = require("std/math.nut")

::wn_sideRecursion <- 0
::wn_sideRecursionFound <- false

enum NAV_SHORTCUT { //bit mask
  CANCEL          = 0x0001
  ACTIVATE        = 0x0002
}

class gui_bhv.wrapNavigator
{
  eventMask = ::EV_JOYSTICK | ::EV_PROCESS_SHORTCUTS | ::EV_MOUSE_L_BTN | ::EV_MOUSE_EXT_BTN
              | ::EV_MOUSE_DBL_CLICK | ::EV_ON_FOCUS_SET | ::EV_ON_FOCUS_LOST | ::EV_ON_CMD
  curItemPID = ::dagui_propid.add_name_id("cur_item")
  skipFocusPID = ::dagui_propid.add_name_id("_skipFocus")
  pushedShortcutsPID = ::dagui_propid.add_name_id("_pushedShortcuts")

  function onFocus(obj, event)
  {
    if (obj.getIntProp(skipFocusPID, 0))
      return ::RETCODE_HALT

    if (event == ::EV_ON_FOCUS_SET)
    {
      //push another focus right inside from current focus update can broke scene update.
      if (!checkWrapFrom(obj))
        obj.getScene().performDelayed(this, @() ::check_obj(obj) && obj.isFocused() && selectItem(obj, 1,false))
      ::play_gui_sound("focus")
    }
    obj.sendNotify("set_focus")
    return ::RETCODE_HALT
  }

  function getValue(obj)
  {
    return obj.getIntProp(curItemPID, 0)
  }

  function setValue(obj, value)
  {
    local prevIdx = getValue(obj)
    local needSound = true
    if (prevIdx == value)
      needSound = false

    obj.setIntProp(curItemPID, value)
    selectItem(obj, 0, needSound)
  }

  function isActiveObj(obj)
  {
    return obj.isEnabled() && obj.isVisible() && obj?.inactive != "yes"
  }

  function isFlowVertical(obj)
  {
    return obj.getFinalProp("flow")=="vertical"
  }

  function checkWrapFrom(obj)
  {
    local wrapObj = ::g_last_nav_wrap.getWrapObj()
    if (!wrapObj)
      return false

    local wrapDir = ::g_last_nav_wrap.getWrapDir()
    local needWrapTo = isFlowVertical(obj) == wrapDir.isVertical
    ::g_last_nav_wrap.clearWrap()
    if (needWrapTo)
      selectSideItem(obj, wrapDir.isPositive)
    return needWrapTo
  }

  function selectSideItem(obj, left)
  {
    if (!obj.isEnabled())
      return

    if (::wn_sideRecursion > 3) {
      ::wn_sideRecursionFound = true
      return
    }
    ::wn_sideRecursion++

    local total = obj.childrenCount()
    local idx = left? 0 : total - 1
    if (idx < 0 || idx >= total || !isActiveObj(obj.getChild(idx)))
    {
      obj.setIntProp(curItemPID, idx)
      moveSelect(obj, left? 1 : -1)
    } else
      setValue(obj, idx)

    ::wn_sideRecursion--
    if (::wn_sideRecursionFound)
    {
      local objId = obj?.id ?? "null"
      ::dagor.debug("Error: recursion of select side item. obj.id = " + objId + ", childrenCount = " + obj.childrenCount())
      if (::wn_sideRecursion <= 0)
      {
        ::dagor.assertf(false, "Error: wrapNavigator found recursion in selectSideItem. obj.id = " + objId)
        ::wn_sideRecursionFound = false
      }
    }
  }

  function selectItem(obj, moveIfInactive = 0, needSound = true)
  {
    local idx = getValue(obj)
    if (idx < 0) idx = 0
    if (obj.childrenCount() > idx)
    {
      local cObj = obj.getChild(idx)
      if (moveIfInactive && !isActiveObj(cObj))
        return moveSelect(obj, moveIfInactive, true)

      obj.setIntProp(skipFocusPID, 1)
      cObj.select()
      cObj.scrollToView()
      obj.setIntProp(skipFocusPID, 0)

    if (needSound)
      ::play_gui_sound("choose")
    } else
      if (obj.childrenCount())
        moveSelect(obj, -1, true)
  }

  function doWrap(obj, wrapDir)
  {
    local wrapFromObj = obj
    local idx = getValue(obj)
    if (0 <= idx && idx < obj.childrenCount())
    {
      local childObj = obj.getChild(idx)
      if (childObj.isValid() && childObj.isFocused())
        wrapFromObj = childObj
    }

    ::g_last_nav_wrap.setWrapFrom(wrapFromObj, wrapDir)
    obj.sendNotify(wrapDir.notifyId)
  }

  function moveSelect(obj, dir, cycled = false)
  {
    local idx = getValue(obj)
    local childrenCount = obj.childrenCount()
    for(local i = 0; i < childrenCount; i++)
    {
      idx += dir

      if (idx >= childrenCount)
        if (cycled)
          idx = 0
        else
          return doWrap(obj, isFlowVertical(obj) ? ::g_wrap_dir.DOWN : ::g_wrap_dir.RIGHT)

      if (idx < 0)
        if (cycled)
          idx = childrenCount - 1
        else
          return doWrap(obj, isFlowVertical(obj) ? ::g_wrap_dir.UP : ::g_wrap_dir.LEFT)

      if (isActiveObj(obj.getChild(idx)))
        break
    }
    setValue(obj, idx)
  }

  function onShortcutLeft(obj, is_down)
  {
    if(is_down)
      if (isFlowVertical(obj))
        doWrap(obj, ::g_wrap_dir.LEFT)
      else
        moveSelect(obj, -1)
    return ::RETCODE_HALT
  }

  function onShortcutRight(obj, is_down)
  {
    if(is_down)
      if (isFlowVertical(obj))
        doWrap(obj, ::g_wrap_dir.RIGHT)
      else
        moveSelect(obj, 1)
    return ::RETCODE_HALT
  }

  function onShortcutUp(obj, is_down)
  {
    if (is_down)
      if (isFlowVertical(obj))
        moveSelect(obj, -1)
      else
        doWrap(obj, ::g_wrap_dir.UP)
    return ::RETCODE_HALT
  }

  function onShortcutDown(obj, is_down)
  {
    if (is_down)
      if (isFlowVertical(obj))
        moveSelect(obj, 1)
      else
        doWrap(obj, ::g_wrap_dir.DOWN)
    return ::RETCODE_HALT
  }

  //return true if bit changed
  function setPushed(obj, navShortcut, value = true)
  {
    local mask = obj.getIntProp(pushedShortcutsPID, 0)
    local newMask = stdMath.change_bit(mask, navShortcut, value)
    if (newMask == mask)
      return false
    obj.setIntProp(pushedShortcutsPID, newMask)
    return true
  }

  function onShortcutCancel(obj, is_down)
  {
    if (is_down)
      setPushed(obj, NAV_SHORTCUT.CANCEL, true)
    else if (setPushed(obj, NAV_SHORTCUT.CANCEL, false))
      obj.sendNotify("cancel_edit")
    return ::RETCODE_HALT
  }

  function onShortcutActivate(obj, is_down)
  {
    if (is_down)
      setPushed(obj, NAV_SHORTCUT.ACTIVATE, true)
    else if (setPushed(obj, NAV_SHORTCUT.ACTIVATE, false))
    {
      obj.sendNotify("activate");
      return ::RETCODE_HALT;
    }
    return ::RETCODE_NOTHING;
  }
}