class gui_bhv.ControlsGrid
{
  eventMask = ::EV_PROCESS_SHORTCUTS | ::EV_MOUSE_L_BTN | ::EV_MOUSE_EXT_BTN | ::EV_MOUSE_DBL_CLICK;

  function onAttach(obj)
  {
    local curRow = obj.cur_row.tointeger()
    while (obj.getChild(curRow).inactive) {
      if (++curRow >= obj.childrenCount()) {
        curRow = 0
        selectCell(obj, curRow, obj.cur_col.tointeger())
      }
      obj.cur_row = curRow.tostring()
    }

    selectCell(obj, obj.cur_row.tointeger(), obj.cur_col.tointeger())
    return ::RETCODE_NOTHING
  }

  function onDetach(obj)
  {
  }

  function onLMouse(obj, mx, my, is_up, bits)
  {
    if (is_up)
      return ::RETCODE_NOTHING;

    if (!is_up && (bits&::BITS_MOUSE_DBL_CLICK) && (bits&::BITS_MOUSE_BTN_L))
    {
      obj.sendNotify("dbl_click");
      return ::RETCODE_HALT;
    }

    for (local iRow=0; iRow < obj.childrenCount(); ++iRow)
    {
      local tr = obj.getChild(iRow)
      local found = false
      for (local iCol=0; iCol<numCols; ++iCol)
      {
        local td = tr.getChild(1+iCol)

        local pos = td.getPos()
        local size = td.getSize()
        if ((mx >= pos[0] && mx <= pos[0]+size[0] && my >= pos[1] && my <= pos[1]+size[1])
           &&(!obj.getChild(iRow).inactive))
        {
          selectCell(obj, iRow, iCol)
          obj.cur_row = iRow.tostring()
          obj.cur_col = iCol.tostring()
          found = true
          break
        }
      }
      if (found)
        return ::RETCODE_HALT;
    }

    return ::RETCODE_NOTHING;
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, bits)
  {
    if (btn_id == 0x100000)
      return ::RETCODE_NOTHING
    return onLMouse(obj, mx, my, is_up, bits);
  }

  function onShortcutUp(obj, is_down)
  {
    if (is_down)
    {
      local curRow = obj.cur_row.tointeger();

      do {
        if (--curRow < 0)
        {
          local navObjName = obj?.nav_overflow_up
          if (navObjName == null)
            curRow = obj.childrenCount()-1;
          else
          {
            local guiScene = ::get_gui_scene()
            local navObj = guiScene[navObjName]
            if (navObj != null)
            {
              navObj.select()
              navObj.scrollToView();
              return ::RETCODE_HALT
            }
          }
          selectCell(obj, curRow, obj.cur_col.tointeger())
        }
      } while (obj.getChild(curRow)?.inactive)

      selectCell(obj, curRow, obj.cur_col.tointeger());
      obj.cur_row = curRow.tostring();
      return ::RETCODE_HALT;
    }
    return ::RETCODE_NOTHING;
  }

  function onShortcutDown(obj, is_down)
  {
    if (is_down)
    {
      local curRow = obj.cur_row.tointeger();

      do {
        if (++curRow >= obj.childrenCount())
        {
          local navObjName = obj?.nav_overflow_down
          if (navObjName == null)
            curRow = 0
          else
          {
            local guiScene = ::get_gui_scene()
            local navObj = guiScene[navObjName]
            if (navObj != null)
            {
              navObj.select()
              navObj.scrollToView();
              return ::RETCODE_HALT
            }
          }
          selectCell(obj, curRow, obj.cur_col.tointeger())
        }
      } while (obj.getChild(curRow)?.inactive)

      selectCell(obj, curRow, obj.cur_col.tointeger());
      obj.cur_row = curRow.tostring();
      return ::RETCODE_HALT;
    }
    return ::RETCODE_NOTHING;
  }

  function onShortcutLeft(obj, is_down)
  {
    if (is_down)
    {
      local curCol = obj.cur_col.tointeger();
      if (--curCol < 0) curCol = numCols-1;
      selectCell(obj, obj.cur_row.tointeger(), curCol);
      obj.cur_col = curCol.tostring();
      return ::RETCODE_HALT;
    }
    return ::RETCODE_NOTHING;
  }

  function onShortcutRight(obj, is_down)
  {
    if (is_down)
    {
      local curCol = obj.cur_col.tointeger();
      if (++curCol >= numCols) curCol = 0;
      selectCell(obj, obj.cur_row.tointeger(), curCol);
      obj.cur_col = curCol.tostring();
      return ::RETCODE_HALT;
    }
    return ::RETCODE_NOTHING;
  }

  function onShortcutActivate(obj, is_down)
  {
    if (is_down)
    {
      obj.sendNotify("dbl_click");
      return ::RETCODE_HALT;
    }
    return ::RETCODE_NOTHING;
  }

  function selectCell(obj, row, col)
  {
//    dagor.screenlog("selectCell("+row+", "+col+")")
/*
    local cell = obj.findObject(::format("cell_%02d_%02d", row, col))
    cell["background-color"] = "#0000FF"
*/
    if (row < obj.childrenCount())
    {
      local newRow = obj.getChild(row)
      if ((newRow["selected"] == "no") ||
          (col < numCols && newRow.getChild(1 + col)["selected"] == "no"))
      {
        obj.getScene().playSound("focus")
      }
    }

    for (local iRow=0; iRow < obj.childrenCount(); ++iRow)
    {
      local tr = obj.getChild(iRow)
      tr["selected"] = (iRow==row)? "yes" : "no"

      for (local iCol=0; iCol<numCols; ++iCol)
      {
        local td = tr.getChild(1+iCol)
        td["selected"] = (iRow==row && iCol==col)? "yes" : "no"
      }
    }

    if (obj.childrenCount()>0)
      obj.getChild(row).scrollToView();
  }

  numCols = 3
}
