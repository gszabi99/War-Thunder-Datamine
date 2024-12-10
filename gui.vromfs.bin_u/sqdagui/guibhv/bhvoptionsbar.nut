from "%sqDagui/daguiNativeApi.nut" import *
from "%scripts/dagui_library.nut" import *
let { setTimeout } = require("dagor.workcycle")

const TEXT_AUTOSCROLL_DELAY_AFTER_SWITCH_OPTION = 1

let OptionsBar = class {
  eventMask = EV_PROCESS_SHORTCUTS | EV_MOUSE_L_BTN | EV_ON_CMD | EV_MOUSE_NOT_ON_OBJ | EV_MOUSE_MOVE
    | EV_AFTER_APPLY_CSS
  valuePID = dagui_propid_add_name_id("value")
  pointerCenteringPID = dagui_propid_add_name_id("mouse-pointer-centering")

  getOptionsBarsContainer = @(obj) obj.findObject("options_bars_container")
  getOptionsCount = @(obj) this.getOptionsBarsContainer(obj).childrenCount()
  getValue = @(obj) obj.getIntProp(this.valuePID, -1)

  function onAttach(obj) {
    let val = obj.value == ""
      ? - 1
      : obj.value.tointeger()
    obj.setValue(val)
    return RETCODE_NOTHING
  }

  function onDetach(obj) {
    if (obj.isMouseCaptured())
      obj.getScene().setProtectedMouseCapture(null)
  }

  function setValue(obj, value, setCursor = false) {
    let curValue = obj.getValue()
    let options = this.getOptionsBarsContainer(obj)

    if (curValue != null && curValue != -1 && curValue < this.getOptionsCount(obj)) {
      let prevSelectedBar = options.getChild(curValue).getChild()
      if (prevSelectedBar)
        prevSelectedBar.selected = "no"
    }

    if (value != -1) {
      let curSelectedBar = options.getChild(value).getChild()
      if (curSelectedBar) {
        curSelectedBar.selected = "yes"
        if (setCursor)
          curSelectedBar.setMouseCursorOnObject()
      }
    }

    obj.setIntProp(this.valuePID, value)
    obj.sendNotify("change_value")
    obj.getScene().playSound("choose")

    if (obj.isHovered()) {
      let textObj = obj.findObject("text_container").getChild()
      this.resetTextAutoscrollOffset(textObj)
    }
  }

  function onLMouse(obj, mx, _my, is_up, bits) {
    if (is_up && obj.isMouseCaptured())
      obj.getScene().setProtectedMouseCapture(null)

    if (is_up)
      return RETCODE_NOTHING
    let isOnObj = !(bits & BITS_MOUSE_NOT_ON_OBJ)
    if (!isOnObj)
      return RETCODE_NOTHING

    this.selectOptionByXCoord(obj, mx)

    obj.isChanging = "yes"
    obj.getScene().setProtectedMouseCapture(obj)
    obj.getScene().removeTooltip()
    return RETCODE_HALT
  }

  function onMouseMove(obj, x, _y, bits) {
    if (obj.isMouseCaptured())
      this.selectOptionByXCoord(obj, x)
    else if (!(bits & BITS_MOUSE_NOT_ON_OBJ))
      obj.isChanging = "no"
    return RETCODE_NOTHING
  }

  function onShortcutSelect(obj, is_down) {
    if (is_down)
      return RETCODE_NOTHING
    let [mx] = get_dagui_mouse_cursor_pos()
    this.selectOptionByXCoord(obj, mx)
    return RETCODE_PROCESSED
  }

  function onShortcutLeft(obj, is_down) {
    if (!is_down)
      return RETCODE_NOTHING
    this.setPrevValue(obj)
    return RETCODE_PROCESSED
  }

  function onShortcutRight(obj, is_down) {
    if (!is_down)
      return RETCODE_NOTHING
    this.setNextValue(obj)
    return RETCODE_PROCESSED
  }

  function onModalChange(obj, isModal) {
    if (isModal && obj.isMouseCaptured())
      obj.getScene().setProtectedMouseCapture(null)
  }

  function onCssApplied(obj) {
    let centeringX = this.getCenteringX(obj)
    obj.set_prop_latent(this.pointerCenteringPID, $"{centeringX}, 77")
  }

  function selectOptionByXCoord(obj, mx) {
    let [width] = obj.getSize()
    let [xPos] = obj.getPos()

    if (mx < xPos || mx > (xPos + width))
      return

    let optsCount = this.getOptionsCount(obj)
    let barWidth = width / optsCount
    let relativeMx = mx - xPos
    let barIndex = clamp(relativeMx / barWidth, 0, optsCount - 1)

    this.setValue(obj, barIndex)
  }

  function setNextValue(obj) {
    let optsCount = this.getOptionsCount(obj)
    let curValue = obj.getValue()
    if (curValue != -1 && curValue < optsCount - 1)
      this.setValue(obj, curValue + 1, true)
  }

  function setPrevValue(obj) {
    let curValue = obj.getValue()
    if (curValue != 0)
      this.setValue(obj, curValue - 1, true)
  }

  function resetTextAutoscrollOffset(textObj) {
    textObj.autoScroll="no"
    setTimeout(TEXT_AUTOSCROLL_DELAY_AFTER_SWITCH_OPTION, function() {
      if (textObj?.isValid())
        textObj.autoScroll="yes"
    })
  }

  function getCenteringX(obj) {
    let [controlWidth] = obj.getSize()
    let optsCount = this.getOptionsCount(obj)
    if (controlWidth == 0 || optsCount == 0)
      return 0
    let optionWidth = controlWidth / optsCount
    let selectedOptionMiddleX = obj.getValue() * optionWidth + optionWidth / 2
    return selectedOptionMiddleX * 100 / controlWidth
  }
}

replace_script_gui_behaviour("optionsBar", OptionsBar)

return { OptionsBar }