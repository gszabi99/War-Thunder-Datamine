class gui_bhv.TableNavigator extends ::gui_bhv.OptionsNavigator
{
  eventMask = ::EV_JOYSTICK | ::EV_PROCESS_SHORTCUTS | ::EV_MOUSE_L_BTN | ::EV_MOUSE_EXT_BTN | ::EV_MOUSE_DBL_CLICK
              | ::EV_ON_FOCUS_SET | ::EV_ON_FOCUS_LOST | ::EV_ON_CMD

  function onFocus(obj, event)
  {
    base.onFocus(obj, event)
    obj.sendNotify("set_focus")
    return ::RETCODE_NOTHING
  }

  function selectCurItem(obj)
  {
    selectCell(obj, obj.cur_row.tointeger(), obj.cur_col.tointeger())
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, bits)
  {
    if (btn_id != 2)  //right mouse button
      return ::RETCODE_NOTHING
    local retCode = onLMouse(obj, mx, my, is_up, bits);
    if (is_up)
    {
      local coords = getClickedCellCoords(obj, mx, my)
      if (coords)  //not inactive row
        obj.sendNotify("r_click")
      return ::RETCODE_PROCESSED
    }
    return retCode
  }

  function onShortcutDown(obj, is_down)
  {
    if (is_down)
      moveSelect(obj, 1)
    return ::RETCODE_NOTHING
  }

  function onShortcutUp(obj, is_down)
  {
    if (is_down)
      moveSelect(obj, -1)
    return ::RETCODE_NOTHING
  }

  function onShortcutLeft(obj, is_down)
  {
    if (is_down)
      obj.sendNotify("wrap_left")
    return ::RETCODE_NOTHING
  }

  function onShortcutRight(obj, is_down)
  {
    if (is_down)
      obj.sendNotify("wrap_right")
    return ::RETCODE_NOTHING
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

  function selectCell(obj, row, col)
  {
    local wasRow = obj.cur_row.tointeger()
    for (local iRow=0; iRow < obj.childrenCount(); ++iRow)
    {
      local tr = obj.getChild(iRow)
      if (iRow == row) {
        tr["selected"] = "yes"
        obj.cur_row = row.tostring()
        obj.cur_col = col.tostring()
        tr.markObjChanged()
      }
      else
        tr["selected"] = "no"
    }

    if (wasRow==row)
      return

    if (row >= 0 && row < obj.childrenCount())
      obj.getChild(row).scrollToView()

    obj.sendNotify("click")
  }

  function getValue(obj)
  {
    return obj.cur_row.tointeger()
  }

  function setValue(obj, value)
  {
    selectCell(obj, value, obj.cur_col.tointeger())
  }
}

::selectTableNavigatorObj <- function selectTableNavigatorObj(obj)
{
  if (!obj) return
  ::gui_bhv.TableNavigator.selectCurItem.call(::gui_bhv.TableNavigator, obj)
}