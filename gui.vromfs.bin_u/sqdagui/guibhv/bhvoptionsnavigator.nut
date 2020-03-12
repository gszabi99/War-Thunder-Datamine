class gui_bhv.OptionsNavigator
{
  eventMask = ::EV_JOYSTICK | ::EV_PROCESS_SHORTCUTS | ::EV_MOUSE_L_BTN | ::EV_MOUSE_EXT_BTN |
                ::EV_MOUSE_DBL_CLICK | ::EV_ON_FOCUS_SET | ::EV_ON_FOCUS_LOST | ::EV_ON_CMD
  skipFocusPID = ::dagui_propid.add_name_id("_skipFocus")

  function onAttach(obj)
  {
    if (obj?.selectOnAttach != "no")
      selectCurItem(obj)
    else
      viewDeselect(obj)
    return ::RETCODE_NOTHING
  }

  function onDetach(obj)
  {
  }

  function onFocus(obj, event)
  {
    if (obj.getIntProp(skipFocusPID, 0))
      return ::RETCODE_HALT

    if (event == ::EV_ON_FOCUS_SET)
    {
      selectCurItem(obj)
      ::play_gui_sound("focus")
    } else if (event == ::EV_ON_FOCUS_LOST)
      viewDeselect(obj)

    return ::RETCODE_NOTHING
  }

  function checkCurItem(obj)
  {
    local total = obj.childrenCount()
    if (total == 0)
    {
      obj.cur_row = -1
      return
    }

    local wasRow = obj.cur_row.tointeger()
    local row = ::clamp(wasRow, 0, total - 1)
    if (obj.getChild(row)?.inactive == "yes")
    {
      local found = false
      for (local i = row-1; i >= 0; i--)
        if (obj.getChild(i)?.inactive != "yes")
        {
          found = true
          row = i
          break
        }
      if (!found)
        for(local i = row+1; i < total; i++)
          if (obj.getChild(i)?.inactive != "yes")
          {
            found = true
            row = i
            break
          }
    }
    if (row != wasRow)
      obj.cur_row = row
  }

  function selectCurItem(obj)
  {
    checkCurItem(obj)
    selectCell(obj, obj.cur_row.tointeger(), obj.cur_col.tointeger())
  }

  function processShortcut(obj, shortcut_id, is_down)
  {

  }

  function onShortcutActivate(obj, is_down)
  {
    if (!is_down)
    {
      obj.sendNotify("dbl_click");
      return ::RETCODE_HALT;
    }
    return ::RETCODE_NOTHING;
  }

  function getClickedCellCoords(obj, mx, my)
  {
    local numRows = obj.childrenCount()

    for (local iRow=0; iRow < numRows; ++iRow)
    {
      local tr = obj.getChild(iRow)
      if (tr?.inactive == "yes")
        continue

      for (local iCol=0; iCol < tr.childrenCount(); ++iCol)
      {
        local td = tr.getChild(iCol)
        if (!td.isVisible())
          continue

        local pos = td.getPos()
        local size = td.getSize()
        if (mx >= pos[0] && mx <= pos[0]+size[0] && my >= pos[1] && my <= pos[1]+size[1])
        {
          return [iRow, iCol]
        }
      }
    }
    return null
  }

  function onLMouse(obj, mx, my, is_up, bits)
  {
    if (is_up)
      return ::RETCODE_HALT //::RETCODE_NOTHING

    local coords = getClickedCellCoords(obj, mx, my)
    if (!coords)
      return ::RETCODE_NOTHING

    if (!is_up && (bits&::BITS_MOUSE_DBL_CLICK) && (bits&::BITS_MOUSE_BTN_L))
    {
      if (getValue(obj) == coords[0])
      {
        obj.sendNotify("dbl_click")
        return ::RETCODE_HALT
      }
    }
    selectCell(obj, coords[0], 2)
    return ::RETCODE_PROCESSED
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, bits)
  {
    if (btn_id != 2)
      return ::RETCODE_NOTHING
    return onLMouse(obj, mx, my, is_up, bits);
  }

  function moveSelect(obj, add_val)
  {
    if (add_val == 0)
      return ::RETCODE_NOTHING

    local curRow = obj.cur_row.tointeger()
    local curCol = obj.cur_col.tointeger()
    local numRows = obj.childrenCount()

    local minVal = 0

    local wasRow = curRow

    do {
      curRow += add_val
    } while (curRow<numRows && curRow>=minVal && !isSelectable(obj.getChild(curRow)))
    if (curRow >= numRows)
    {
      obj.sendNotify("wrap_down")
      return ::RETCODE_NOTHING
    }
    if (curRow < minVal)
    {
      obj.sendNotify("wrap_up")
      return ::RETCODE_NOTHING
    }

    selectCell(obj, curRow, curCol)
    if (wasRow != curRow)
      ::play_gui_sound("choose")
    return ::RETCODE_PROCESSED
  }

  function onShortcutDown(obj, is_down)
  {
    if (is_down)
      return moveSelect(obj, 1)
    return ::RETCODE_NOTHING
  }

  function onShortcutUp(obj, is_down)
  {
    if (is_down)
      return moveSelect(obj, -1)
    return ::RETCODE_NOTHING
  }

  function viewDeselect(obj)
  {
    for (local iRow=0; iRow < obj.childrenCount(); ++iRow)
      obj.getChild(iRow)["selected"] = "no"
  }

  function selectCell(obj, row, col)
  {
    local isChanged = false
    for (local iRow=0; iRow < obj.childrenCount(); ++iRow)
    {
      local tr = obj.getChild(iRow)
      local selected = iRow == row
      tr["selected"] = selected? "yes" : "no"
      if (!selected)
        continue

      isChanged = (obj?.cur_row != row.tostring()) || (obj?.cur_col != col.tostring())
      obj.cur_row = row.tostring()
      obj.cur_col = col.tostring()

      if (tr.childrenCount() > 1)
      {
        local td = tr.getChild(1)
        if (td.childrenCount())
        {
          obj.setIntProp(skipFocusPID, 1)
          td.getChild(0).select()
          obj.setIntProp(skipFocusPID, 0)
        }
      }
    }

    if (isChanged && row >= 0 && row < obj.childrenCount())
      obj.getChild(row).scrollToView()
    if (isChanged)
      obj.sendNotify("click");

    // updating hint  - strange code, better to fix it by "on_click" function
    if (::generic_options != null)
    {
      local guiScene = ::get_gui_scene();
      guiScene.performDelayed(this, function(){ ::generic_options.onHintUpdate(); });
    }
  }

  function clearSelect(obj)
  {
    for (local iRow=0; iRow < obj.childrenCount(); ++iRow)
    {
      local tr = obj.getChild(iRow)
      tr["selected"] = "no"
      //tr["background-color"] = "#00000000"
    }
  }

  function getValue(obj)
  {
    return obj.cur_row.tointeger()
  }

  function setValue(obj, value)
  {
    selectCell(obj, value, 0)
  }

  function isSelectable(obj)
  {
    return obj.isVisible() && obj.isEnabled() && obj?.inactive != "yes"
  }
}

::selectOptionsNavigatorObj <- function selectOptionsNavigatorObj(obj)
{
  if (!obj) return
  ::gui_bhv.OptionsNavigator.selectCurItem.call(::gui_bhv.OptionsNavigator, obj)
}