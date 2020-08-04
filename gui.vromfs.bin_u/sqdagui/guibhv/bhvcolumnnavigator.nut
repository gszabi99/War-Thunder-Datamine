class gui_bhv.columnNavigator
{
  eventMask = ::EV_JOYSTICK | ::EV_PROCESS_SHORTCUTS | ::EV_MOUSE_L_BTN | ::EV_MOUSE_EXT_BTN | ::EV_MOUSE_DBL_CLICK | ::EV_ON_FOCUS_SET | ::EV_ON_FOCUS_LOST

  function onFocus(obj, event)
  {
    if (event == ::EV_ON_FOCUS_SET)
    {
      selectCurItem(obj)
      obj.getScene().playSound("focus")
    }
    else if (event == ::EV_ON_FOCUS_LOST)
    {
      if (obj?.clearOnFocusLost != "no")
        clearSelect(obj)
    }
    obj.sendNotify("set_focus")
    return ::RETCODE_HALT
  }

  function selectCurItem(obj)
  {
    local found = selectCell(obj, obj.cur_row.tointeger(), obj.cur_col.tointeger())
    if (found || !::is_obj_have_active_childs(obj))
      return
    found = selectCell(obj, 0, 0)
    if (found)
      return

    obj.cur_row = "0"
    obj.cur_col = "0"
    onShortcutDown(obj, true)
  }

  function processShortcut(obj, shortcut_id, is_down) {}

  function onShortcutActivate(obj, is_down)
  {
    if (!is_down)
    {
      obj.sendNotify("dbl_click");
      return ::RETCODE_HALT;
    }
    return ::RETCODE_NOTHING;
  }

  function onLMouse(obj, mx, my, is_up, bits)
  {
    if (is_up)
      return ::RETCODE_NOTHING

    local numRows = obj.childrenCount()

    for (local iRow=0; iRow < numRows; ++iRow)
    {
      local tr = obj.getChild(iRow)
      for (local iCol=0; iCol < tr.childrenCount(); ++iCol)
      {
        local td = tr.getChild(iCol)

        local pos = td.getPos()
        local size = td.getSize()
        if (mx >= pos[0] && mx <= pos[0]+size[0] && my >= pos[1] && my <= pos[1]+size[1])
        {
          if (td?.inactive == "yes")
            return ::RETCODE_HALT

          if (!is_up && (bits&::BITS_MOUSE_DBL_CLICK) && (bits&::BITS_MOUSE_BTN_L))
          {
            obj.sendNotify("dbl_click") // HERE
            return ::RETCODE_HALT
          }
          else
          {
            selectCell(obj, iRow, iCol)
            obj.sendNotify("click")
            return ::RETCODE_HALT
          }
        }
      }
    }

    return ::RETCODE_NOTHING
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, bits)
  {
    if (btn_id != 2)  //right mouse button
      return ::RETCODE_NOTHING
    if (is_up)
    {
      obj.sendNotify("r_click")
      return ::RETCODE_PROCESSED
    }

    return onLMouse(obj, mx, my, is_up, bits);
  }

  function onShortcutDown(obj, is_down)
  {
    if (is_down)
    {
      local curRow = obj.cur_row.tointeger()
      local curCol = obj.cur_col.tointeger()
      local curTr = null
      local numRows = obj.childrenCount()

      do
      {
        if (++curRow >= numRows)
        {
          obj.sendNotify("wrap_down")
          return ::RETCODE_HALT
        }
        curTr = obj.getChild(curRow)
      } while ((curTr.childrenCount() <= curCol) || curTr.getChild(curCol)?.inactive == "yes")

      selectCell(obj, curRow, curCol)
      return ::RETCODE_HALT
    }
    return ::RETCODE_NOTHING
  }

  function onShortcutUp(obj, is_down)
  {
    if (is_down)
    {
      local numRows = obj.childrenCount()
      local curRow = min(obj.cur_row.tointeger(), numRows)
      local curCol = obj.cur_col.tointeger()
      local curTr = null

      do
      {
        if (--curRow < 0)
        {
          obj.sendNotify("wrap_up")
          return ::RETCODE_HALT
        }
        curTr = obj.getChild(curRow)
      } while ((curTr.childrenCount() <= curCol) || curTr.getChild(curCol)?.inactive == "yes")

      selectCell(obj, curRow, curCol)
      return ::RETCODE_HALT
    }
    return ::RETCODE_NOTHING
  }

  function onShortcutLeft(obj, is_down)
  {
    if (is_down)
      return selectColumn(obj, -1)
    return ::RETCODE_NOTHING
  }

  function onShortcutRight(obj, is_down)
  {
    if (is_down)
      return selectColumn(obj, 1)
    return ::RETCODE_NOTHING
  }

  function selectColumn(obj, way)
  {
    local curRow = obj.fixed_row.tointeger() //obj.cur_row.tointeger()
    local curCol = obj.cur_col.tointeger()
    local curTr = obj.getChild(curRow)
    local numRows = obj.childrenCount()
    local numCols = curTr.childrenCount()

    curCol+= way
    if (curCol >= numCols)
    {
      obj.sendNotify("wrap_right")
      return ::RETCODE_HALT
    }
    if (curCol < 0)
    {
      obj.sendNotify("wrap_left")
      return ::RETCODE_HALT
    }

    if (curTr.getChild(curCol)?.inactive == "yes")
    {
      //choose closest row to fixedRow
      local deviation = 0
      local deviation1 = 0
      local deviation2 = 0

      for(local k=1; k <= curRow; k++)
      {
        curTr = obj.getChild(curRow-k)
        if (curTr.childrenCount() > curCol && curTr.getChild(curCol)?.inactive != "yes")
        {
          deviation1 = k
          break
        }
      }
      for(local k=1; k < (numRows-curRow); k++)
      {
        curTr = obj.getChild(curRow+k)
        if (curTr.childrenCount() > curCol && curTr.getChild(curCol)?.inactive != "yes")
        {
          deviation2 = k
          break
        }
      }

      if (deviation1==0)
        deviation = deviation2
      else if((deviation2==0)||(deviation1 < deviation2)||(deviation1==deviation2))
        deviation = -deviation1
      else if(deviation2 < deviation1)
        deviation = deviation2

      if (deviation == 0)
      {
        selectColumn(obj, way + way/abs(way))
        return ::RETCODE_HALT
      }

      curRow += deviation
    }

    selectCell(obj, curRow, curCol, true, false)
    return ::RETCODE_HALT
  }

  function selectCell(obj, row, col, needSound = true, fixedRow = true, needNotify=true)
  {
    if ((row < 0) || (row >= obj.childrenCount()))
      return false

    local tr = obj.getChild(row)
    if (tr.childrenCount() <= col)
      return false

    local curRow = obj.cur_row.tointeger()
    local curCol = obj.cur_col.tointeger()
    //deselect previous item
    if (obj.childrenCount() > curRow && curRow >= 0)
    {
      local curTr = obj.getChild(curRow)
      curTr["selected"] = "no"
      if (curTr.childrenCount() > curCol && curCol >= 0)
      {
        local curTd = curTr.getChild(curCol)
          curTd["selected"] = "no"
      }
    }

    tr["selected"] = "yes"
    local td = tr.getChild(col)
      td["selected"] = "yes"

    needNotify = needNotify && ((obj?.cur_row != row.tostring()) || (obj?.cur_col != col.tostring()))
    obj.cur_row = row.tostring()
    obj.cur_col = col.tostring()
    if (fixedRow)
      obj.fixed_row = row.tostring()

    if (!td.isVisible() || !td.isEnabled() || td?.inactive == "yes")
      return false
    td.scrollToView()
    if (needSound && ((curRow != row)||(curCol != col)))
      obj.getScene().playSound("choose")
    if (needNotify)
      obj.sendNotify("select")
    return true
  }

  function getSelectedObj(obj)
  {
    local curRow = obj.cur_row.tointeger()
    local curCol = obj.cur_col.tointeger()
    if (curRow < 0 || curRow >= obj.childrenCount())
      return null
    local trObj = obj.getChild(curRow)
    if (curCol < 0 || curCol >= trObj.childrenCount())
      return null
    return trObj.getChild(curCol)
  }

  function clearSelect(obj)
  {
    for (local iRow=0; iRow < obj.childrenCount(); ++iRow)
    {
      local tr = obj.getChild(iRow)
      tr["selected"] = "no"
      for (local iCol=0; iCol < tr.childrenCount(); ++iCol)
      {
        local td = tr.getChild(iCol)
        td["selected"] = "no"
      }
    }
  }

  function onShortcutCancel(obj, is_down)
  {
    if (!is_down)
      obj.sendNotify("cancel_edit")
    return ::RETCODE_HALT
  }
}

::selectColumnNavigatorObj <- function selectColumnNavigatorObj(obj)
{
  if (!obj) return
  ::gui_bhv.columnNavigator.selectCurItem.call(::gui_bhv.columnNavigator, obj)
}