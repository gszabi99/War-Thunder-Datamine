class gui_bhv.ControlsInput
{
  eventMask = ::EV_MOUSE_L_BTN | ::EV_PROCESS_SHORTCUTS | ::EV_MOUSE_EXT_BTN | ::EV_KBD_UP | ::EV_KBD_DOWN | ::EV_JOYSTICK | ::EV_GESTURE

  function onLMouse(obj, mx, my, is_up, bits)
  {
    setMouseButton(obj, "0", is_up)
    return ::RETCODE_HALT
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, bits)
  {
    local btn = null
    if (btn_id==2)
      btn="1"
    else if (btn_id==4)
      btn="2"
    else if (btn_id==8)
      btn="3"
    else if (btn_id==16)
      btn="4"
    else if (btn_id==32)
      btn="5"
    else if (btn_id==64)
      btn="6"

    if (btn)
      setMouseButton(obj, btn, is_up)
    return ::RETCODE_HALT
  }

  function getCurrentBtnIndex(obj)
  {
    for (local i = 0; i < ::TOTAL_DEVICES; i++)
      if (!obj["device" + i].len())
        return i

    return -1
  }

  function checkActive(obj)
  {
    if (!::is_app_active() || ::steam_is_overlay_active())
    {
      for (local i = 0; i < 3; i++)
      {
        obj["device" + i] = ""
        obj["button" + i] = ""
      }
      obj.sendNotify("change_value")
      return false
    }
    return true
  }

  function setMouseButton(obj, button, is_up)
  {
    if (!checkActive(obj))
      return
    if (!is_up)
    {
      local btnIndex = getCurrentBtnIndex(obj)
      if (btnIndex >= 0 && !obj["device" + btnIndex].len())
      {
        if (!isExistsShortcut(obj, ::STD_MOUSE_DEVICE_ID.tostring(), button))
        {
          obj["device" + btnIndex] = ::STD_MOUSE_DEVICE_ID.tostring()
          obj["button" + btnIndex] = button
          obj.sendNotify("change_value")
        }
      }
    }
    else
    {
      if (obj["device0"] != "" && obj["button0"] != "")
        obj.sendNotify("end_edit")
    }
  }

  function isExistsShortcut(obj, dev, btn)
  {
    for (local i = 0; i < 3; i++)
    {
      if (obj["device" + i] == dev && obj["button" + i] == btn)
        return true
    }

    return false
  }

  function onKbd(obj, event, btn_idx)
  {
    if (!checkActive(obj))
      return ::RETCODE_HALT
    if (event == ::EV_KBD_DOWN)
    {
      local btnIndex = getCurrentBtnIndex(obj)
      if (btnIndex >= 0 && !obj["device" + btnIndex].len())
      {
        if (!isExistsShortcut(obj, ::STD_KEYBOARD_DEVICE_ID.tostring(), btn_idx.tostring()))
        {
          obj["device" + btnIndex] = ::STD_KEYBOARD_DEVICE_ID.tostring()
          obj["button" + btnIndex] = btn_idx.tostring()
          obj.sendNotify("change_value")
        }
        return ::RETCODE_HALT
      }
    }
    else if (event == ::EV_KBD_UP)
    {
      if (obj["device0"] != "" && obj["button0"] != "")
        obj.sendNotify("end_edit")
    }
    return ::RETCODE_HALT
  }

  function isAnalog(dev_id, btn_id)
  {
    local button = ::get_button_name(dev_id, btn_id)
    return button == "LT" ||
      button == "RT" ||
      button == "LS.Right" ||
      button == "LS.Left" ||
      button == "LS.Up" ||
      button == "LS.Down" ||
      button == "RS.Right" ||
      button == "RS.Left" ||
      button == "RS.Up" ||
      button == "RS.Down"
  }

  function onJoystick(obj, joy, btn_idx, is_up, buttons)
  {
    if (!checkActive(obj))
      return ::RETCODE_HALT
    if (!is_up)
    {
      local ignore = (btn_idx >= joy.getButtonCount()) //<-- ignore PoV hats for now
      print("btn_idx " + btn_idx)
      if (!ignore)
      {
        local id = ::JOYSTICK_DEVICE_0_ID
        if (id>=0)
        {
          local btnIndex = getCurrentBtnIndex(obj)
          if (btnIndex >= 0 && !obj["device" + btnIndex].len())
          {
            if (!isExistsShortcut(obj, id.tostring(), btn_idx.tostring()))
            {
              local checkAnalog = obj?["check_analog"]
              if (checkAnalog == null || checkAnalog.tointeger() == 0 ||
                (obj["device0"] != "" && obj["button0"] != "") || !isAnalog(id, btn_idx))
              {
                obj["device" + btnIndex] = id.tostring()
                obj["button" + btnIndex] = btn_idx.tostring()
                obj.sendNotify("change_value")
              }
            }
          }
        }
      }
    }
    else
    {
      if (obj["device0"] != "" && obj["button0"] != "")
        obj.sendNotify("end_edit")
    }
    return ::RETCODE_HALT
  }

  function onGesture(obj, event, gesture_idx)
  {
    if (!checkActive(obj))
      return ::RETCODE_HALT

    if (event == ::EV_GESTURE_START)
    {
      local btnIndex = getCurrentBtnIndex(obj)
      if (btnIndex >= 0 && !obj["device" + btnIndex].len())
      {
        if (!isExistsShortcut(obj, ::STD_GESTURE_DEVICE_ID.tostring(), gesture_idx.tostring()))
        {
          obj["device" + btnIndex] = ::STD_GESTURE_DEVICE_ID.tostring()
          obj["button" + btnIndex] = gesture_idx.tostring()
          obj.sendNotify("change_value")
        }
        return ::RETCODE_HALT
      }
    }
    else if (event == ::EV_GESTURE_END)
    {
      if (obj["device0"] != "" && obj["button0"] != "")
        obj.sendNotify("end_edit")
    }

    return ::RETCODE_HALT
  }

  function onShortcutCancel(obj, is_down)
  {
    if (!is_down)
      obj.sendNotify("cancel_edit")
    return ::RETCODE_HALT
  }

  function onShortcutActivate(obj, is_down)
  {
    if (is_down)
      obj.sendNotify("activate")

    return ::RETCODE_HALT
  }
}
