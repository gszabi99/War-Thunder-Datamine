local stdMath = require("std/math.nut")

return [
  {
    id = "rangeMax"
    type = CONTROL_TYPE.AXIS_SHORTCUT
    symbol = "controls/rangeMax_symbol"
  }
  {
    id = "rangeMin"
    type = CONTROL_TYPE.AXIS_SHORTCUT
    symbol = "controls/rangeMin_symbol"
  }
  {
    id = "rangeSet"
    type = CONTROL_TYPE.AXIS_SHORTCUT
    symbol = "controls/rangeSet_symbol"
  }
  {
    id = ""
    type = CONTROL_TYPE.AXIS_SHORTCUT
    symbol = "controls/enable_symbol"
  }
  {
    id = "keepDisabledValue"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(axis) axis.keepDisabledValue
    setValue = @(axis, objValue) axis.keepDisabledValue = objValue
  }
  {
    id = "deadzone"
    type = CONTROL_TYPE.SLIDER
    min = 0
    max = 100
    step = 5
    showValueMul = 0.005
    value = @(axis) (axis.innerDeadzone/max_deadzone) * 100
    setValue = @(axis, objValue) axis.innerDeadzone = objValue / 100.0 * max_deadzone
  }
  {
    id = "nonlinearity"
    type = CONTROL_TYPE.SLIDER
    min = 10
    max = max_nonlinearity * 10
    step = 1
    showValueMul = 0.1
    value = @(axis) axis.nonlinearity * 10.0 + 10.0
    setValue = @(axis, objValue) axis.nonlinearity = (objValue / 10.0) - 1.0
  }
  {
    id = "invertAxis"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(axis) axis.inverse
    setValue = @(axis, objValue) axis.inverse = objValue
  }
  {
    id = "relativeAxis"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(axis) axis.relative
    setValue = @(axis, objValue) axis.relative = objValue
    onChangeValue = "onChangeAxisRelative"
  }
  {
    id = "kRelSpd"
    type = CONTROL_TYPE.SLIDER
    min = 1
    max = 10
    step = 1
    showValuePercMul = 10
    value = @(axis) ::sqrt(axis.relSens) * 10.0
    setValue = @(axis, objValue) axis.relSens = stdMath.pow(objValue / 10.0, 2)
  }
  {
    id = "kRelStep"
    type = CONTROL_TYPE.SLIDER
    min = 0
    max = 50
    step = 1
    value = @(axis) axis.relStep * 100.0
    setValue = @(axis, objValue) axis.relStep = objValue / 100.0
  }
  {
    id = "kMul"
    type = CONTROL_TYPE.SLIDER
    min = 20
    max = 200
    step = 5
    showValueMul = 0.01
    value = @(axis) axis.kMul * 100.0
    setValue = @(axis, objValue) axis.kMul = objValue / 100.0
  }
  {
    id = "kAdd"
    type = CONTROL_TYPE.SLIDER
    min = -50
    max = 50
    step = 1
    value = @(axis) axis.kAdd * 50.0
    setValue = @(axis, objValue) axis.kAdd = objValue / 50.0
  }
]