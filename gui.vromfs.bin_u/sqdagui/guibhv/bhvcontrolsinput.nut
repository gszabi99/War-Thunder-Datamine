from "%sqDagui/daguiNativeApi.nut" import *

let { isXInputDevice } = require("controls")

local gestureInProgress = false

let ControlsInput = class {
  eventMask = EV_MOUSE_L_BTN | EV_PROCESS_SHORTCUTS | EV_MOUSE_EXT_BTN | EV_KBD_UP | EV_KBD_DOWN | EV_JOYSTICK | EV_GESTURE

  function onLMouse(obj, _mx, _my, is_up, _bits) {
    this.setMouseButton(obj, "0", is_up)
    return RETCODE_HALT
  }

  function onExtMouse(obj, _mx, _my, btn_id, is_up, _bits) {
    local btn = null
    if (btn_id == 2)
      btn = "1"
    else if (btn_id == 4)
      btn = "2"
    else if (btn_id == 8)
      btn = "3"
    else if (btn_id == 16)
      btn = "4"
    else if (btn_id == 32)
      btn = "5"
    else if (btn_id == 64)
      btn = "6"

    if (btn)
      this.setMouseButton(obj, btn, is_up)
    return RETCODE_HALT
  }

  function getCurrentBtnIndex(obj) {
    for (local i = 0; i < TOTAL_DEVICES; i++) {
      let deviceId = $"device{i}"
      if (obj?[deviceId] && !obj[deviceId].len())
        return i
    }

    return -1
  }

  function checkActive(obj) {
    let isActive = ::is_app_active() && !::steam_is_overlay_active()
    if (!isActive) {
      local hasChanges = false
      for (local i = 0; i < 3; i++) {
        let devid = $"device{i}"
        let butid = $"button{i}"
        hasChanges = hasChanges || obj[devid] != "" || obj[butid] != ""
        obj[devid] = ""
        obj[butid] = ""
      }
      if (hasChanges)
        obj.sendNotify("change_value")
    }
    return isActive
  }

  function setMouseButton(obj, button, is_up) {
    if (!this.checkActive(obj) || gestureInProgress)
      return
    if (!is_up) {
      let btnIndex = this.getCurrentBtnIndex(obj)
      let devid = $"device{btnIndex}"
      if (btnIndex >= 0 && !obj[devid].len()) {
        if (!this.isExistsShortcut(obj, STD_MOUSE_DEVICE_ID.tostring(), button)) {
          obj[devid] = STD_MOUSE_DEVICE_ID.tostring()
          obj[$"button{btnIndex}"] = button
          obj.sendNotify("change_value")
        }
      }
    }
    else {
      if (obj["device0"] != "" && obj["button0"] != "")
        obj.sendNotify("end_edit")
    }
  }

  function isExistsShortcut(obj, dev, btn) {
    for (local i = 0; i < 3; i++) {
      if (obj[$"device{i}"] == dev && obj[$"button{i}"] == btn)
        return true
    }

    return false
  }

  function onKbd(obj, event, btn_idx) {
    if (!this.checkActive(obj))
      return RETCODE_HALT
    if (event == EV_KBD_DOWN) {
      let btnIndex = this.getCurrentBtnIndex(obj)
      let devid = $"device{btnIndex}"
      if (btnIndex >= 0 && !obj[devid].len()) {
        if (!this.isExistsShortcut(obj, STD_KEYBOARD_DEVICE_ID.tostring(), btn_idx.tostring())) {
          obj[devid] = STD_KEYBOARD_DEVICE_ID.tostring()
          obj[$"button{btnIndex}"] = btn_idx.tostring()
          obj.sendNotify("change_value")
        }
        return RETCODE_HALT
      }
    }
    else if (event == EV_KBD_UP) {
      if (obj["device0"] != "" && obj["button0"] != "")
        obj.sendNotify("end_edit")
    }
    return RETCODE_HALT
  }

  function isAnalog(dev_id, btn_id) {
    let button = get_button_name(dev_id, btn_id)
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

  function onJoystick(obj, joy, btn_idx, is_up, _buttons) {
    if (!this.checkActive(obj))
      return RETCODE_HALT

    // Gamepad START btn is reserved for toggling the input listening mode off/on.
    if (btn_idx == 4 && isXInputDevice())
      return RETCODE_NOTHING

    if (!is_up) {
      let ignore = (btn_idx >= joy.getButtonCount()) //<-- ignore PoV hats for now
      print($"btn_idx {btn_idx}")
      if (!ignore) {
        let id = JOYSTICK_DEVICE_0_ID
        if (id >= 0) {
          let btnIndex = this.getCurrentBtnIndex(obj)
          let devid = $"device{btnIndex}"
          if (btnIndex >= 0 && !obj[devid].len()) {
            if (!this.isExistsShortcut(obj, id.tostring(), btn_idx.tostring())) {
              let checkAnalog = obj?["check_analog"]
              if (checkAnalog == null || checkAnalog.tointeger() == 0 ||
                (obj["device0"] != "" && obj["button0"] != "") || !this.isAnalog(id, btn_idx)) {
                obj[devid] = id.tostring()
                obj[$"button{btnIndex}"] = btn_idx.tostring()
                obj.sendNotify("change_value")
              }
            }
          }
        }
      }
    }
    else {
      if (obj["device0"] != "" && obj["button0"] != "")
        obj.sendNotify("end_edit")
    }
    return RETCODE_HALT
  }

  function onGesture(obj, event, gesture_idx) {
    if (!this.checkActive(obj))
      return RETCODE_HALT

    if (event == EV_GESTURE_START) {
      gestureInProgress = true
      let btnIndex = this.getCurrentBtnIndex(obj)
      let devid = $"device{btnIndex}"
      if (btnIndex >= 0 && !obj[devid].len()) {
        if (!this.isExistsShortcut(obj, STD_GESTURE_DEVICE_ID.tostring(), gesture_idx.tostring())) {
          obj[devid] = STD_GESTURE_DEVICE_ID.tostring()
          obj[$"button{btnIndex}"] = gesture_idx.tostring()
          obj.sendNotify("change_value")
        }
        return RETCODE_HALT
      }
    }
    else if (event == EV_GESTURE_END) {
      if (obj["device0"] != "" && obj["button0"] != "")
        obj.sendNotify("end_edit")
      gestureInProgress = false
    }

    return RETCODE_HALT
  }

  function onShortcutCancel(obj, is_down) {
    if (!is_down)
      obj.sendNotify("cancel_edit")
    return RETCODE_HALT
  }

  function onShortcutActivate(obj, is_down) {
    if (is_down)
      obj.sendNotify("activate")

    return RETCODE_HALT
  }
}
return {ControlsInput}