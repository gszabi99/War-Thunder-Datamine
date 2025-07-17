from "%scripts/dagui_library.nut" import *

let regexp2 = require("regexp2")
let { split_by_chars } = require("string")
let { addTypes, enumsAddTypes } = require("%sqStdLibs/helpers/enums.nut")
let { ControlHelpersMode } = require("globalEnv")
let { isAxisBoundToMouse, getComplexAxesId, isComponentsAssignedToSingleInputItem,
  isShortcutMapped } = require("%scripts/controls/shortcutsUtils.nut")
let { KWARG_NON_STRICT } = require("%sqstd/functools.nut")
let { endsWith } = require("%sqstd/string.nut")
let { isXInputDevice } = require("controls")
let { CONTROL_TYPE, AXIS_MODIFIERS, MOUSE_AXIS } = require("%scripts/controls/controlsConsts.nut")
let { NullInput } = require("%scripts/controls/input/nullInput.nut")
let { Button } = require("%scripts/controls/input/button.nut")
let { Combination } = require("%scripts/controls/input/combination.nut")
let { KeyboardAxis } = require("%scripts/controls/input/keyboardAxis.nut")
let { Axis } = require("%scripts/controls/input/axis.nut")
let { DoubleAxis } = require("%scripts/controls/input/doubleAxis.nut")
let { InputImage } = require("%scripts/controls/input/image.nut")
let { joystickGetCurSettings, getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { getCurrentHelpersMode } = require("%scripts/controls/controlsUtils.nut")
let { getShortcutById } = require("%scripts/controls/shortcutsList/shortcutsList.nut")

function getNullInput(shortcutId, showShortcutsNameIfNotAssign) {
  let nullInput = NullInput()
  nullInput.shortcutId = shortcutId
  nullInput.showPlaceholder = showShortcutsNameIfNotAssign
  return nullInput
}

let imageRe = regexp2(@"^#[\w/_]*#[\w\d_]+")

let g_shortcut_type = {
  types = []

  function addType(typesTable) {
    addTypes(this, typesTable, null, "typeName")
  }
}

g_shortcut_type.getShortcutTypeByShortcutId <- function getShortcutTypeByShortcutId(shortcutId) {
  foreach (t in this.types)
    if (t.isMe(shortcutId))
      return t
  return g_shortcut_type.COMMON_SHORTCUT
}

g_shortcut_type.isAxisShortcut <- function isAxisShortcut(shortcutId) {
  foreach (postfix in ["rangeMin", "rangeMax"])
    if (endsWith(shortcutId, postfix))
      return true
  return false
}

g_shortcut_type.expandShortcuts <- function expandShortcuts(shortcutIdList, showKeyBoardShortcutsForMouseAim = false) {
  let result = []
  foreach (shortcutId in shortcutIdList) {
    let shortcutType = this.getShortcutTypeByShortcutId(shortcutId)
    result.extend(shortcutType.expand(shortcutId, showKeyBoardShortcutsForMouseAim))
  }

  return result
}

g_shortcut_type.getShortcutMarkup <- function getShortcutMarkup(shortcutId, preset) {
  local markup = ""
  let shortcutType = this.getShortcutTypeByShortcutId(shortcutId)
  if (!shortcutType.isAssigned(shortcutId, preset))
    return markup

  let expanded = this.expandShortcuts([shortcutId])
  foreach (expandedShortcut in expanded) {
    let expandedType = this.getShortcutTypeByShortcutId(expandedShortcut)
    let input = expandedType.getFirstInput(expandedShortcut, preset)
    markup = "".concat(markup, input.getMarkup())
  }

  return markup
}

function isAssignedToJoyAxis(shortcutId) {
  let axisDesc = g_shortcut_type._getDeviceAxisDescription(shortcutId)
  return axisDesc.axisId >= 0
}

function isAssignedToAxis(shortcutId, showKeyBoardShortcutsForMouseAim = false) {
  let isMouseAimMode = getCurrentHelpersMode() == ControlHelpersMode.EM_MOUSE_AIM
  if ((!showKeyBoardShortcutsForMouseAim || !isMouseAimMode)
    && isAxisBoundToMouse(shortcutId))
    return true
  return isAssignedToJoyAxis(shortcutId)
}

function transformAxisToShortcuts(axisId) {
  let result = []
  let axisShortcutPostfixes = ["rangeMin", "rangeMax"]
  foreach (postfix in axisShortcutPostfixes)
    result.append($"{axisId}_{postfix}")

  return result
}

function isHalfAxisAssignedToShortcuts(shortcutId) {
  return g_shortcut_type.COMMON_SHORTCUT.isAssigned(shortcutId)
}

function isAxisAssignedToShortcuts(shortcutId) {
  let shortcuts = transformAxisToShortcuts(shortcutId)
  foreach (axisBorderShortcut in shortcuts)
    if (!g_shortcut_type.COMMON_SHORTCUT.isAssigned(axisBorderShortcut))
      return false
  return true
}

function splitCompositAxis(compositAxis) {
  return split_by_chars(compositAxis, "+")
}


g_shortcut_type._getDeviceAxisDescription <- function _getDeviceAxisDescription(shortcutId, isMouseHigherPriority = true) {
  let result = {
    deviceId = NULL_INPUT_DEVICE_ID
    axisId = -1
    mouseAxis = null
    inverse = false
  }

  let joyParams = joystickGetCurSettings()
  let axisIndex = getShortcutById(shortcutId)?.axisIndex ?? -1
  if (axisIndex < 0)
    return result

  let axis = joyParams.getAxis(axisIndex)

  result.axisId = axis.axisId
  result.inverse = axis.inverse

  if ((result.axisId == -1 || isMouseHigherPriority) &&
    ::is_axis_mapped_on_mouse(shortcutId, null, joyParams)) {
    result.deviceId = STD_MOUSE_DEVICE_ID
    result.mouseAxis = ::get_mouse_axis(shortcutId, null, joyParams)
  }

  let isMappedToMouseOnly = result.axisId == -1 && result.mouseAxis != MOUSE_AXIS.NOT_AXIS
  if (isXInputDevice() && !isMappedToMouseOnly)
    result.deviceId = JOYSTICK_DEVICE_0_ID

  return result
}

g_shortcut_type.template <- {
  isMe = function (_shortcutId) { return false }
  isAssigned = function (_shortcutId, _preset = null) { return false }


  



  expand = function (shortcutId, _showKeyBoardShortcutsForMouseAim) { return [shortcutId] }


  



  getInputs = kwarg(function getInputs(shortcutId, _preset = null,
    _isMouseHigherPriority = true, showShortcutsNameIfNotAssign = false) {
    return [getNullInput(shortcutId, showShortcutsNameIfNotAssign)]
  })


  



  getFirstInput = function (shortcutId, preset = null, params = {}) {
    let { showShortcutsNameIfNotAssign = false, skipDeviceIds = {} } = params
    local inputs = this.getInputs({
      shortcutId
      preset
      showShortcutsNameIfNotAssign
    }, KWARG_NON_STRICT)
    if (skipDeviceIds.len() > 0) {
      inputs = inputs.filter(@(input) !input.isUseDevice(skipDeviceIds))
      if (inputs.len() == 0)
        inputs = [getNullInput(shortcutId, showShortcutsNameIfNotAssign)]
    }

    local bestInput = inputs[0]

    if (isXInputDevice()) {
      foreach (input in inputs)
        if (input.getDeviceId() == JOYSTICK_DEVICE_0_ID) {
          bestInput = input
          break
        }
    }

    return bestInput
  }

}

enumsAddTypes(g_shortcut_type, {
  COMMON_SHORTCUT = {
    isMe = function (shortcutId) {
      let shortcutConfig = getShortcutById(shortcutId)
      if (!shortcutConfig)
        return g_shortcut_type.isAxisShortcut(shortcutId)
      return getTblValue("type", shortcutConfig) != CONTROL_TYPE.AXIS
    }

    isAssigned = function (shortcutId, preset = null) {
      return isShortcutMapped(getShortcuts([shortcutId], preset)[0])
    }

    getInputs = kwarg(function getInputs(shortcutId, preset = null,
      _isMouseHigherPriority = true, showShortcutsNameIfNotAssign = false) {
      let rawShortcutData = getShortcuts([shortcutId], preset)[0]

      if (!rawShortcutData)
        return [getNullInput(shortcutId, showShortcutsNameIfNotAssign)]

      let inputs = []
      foreach (strokeData in rawShortcutData) {
        let buttons = []
        for (local i = 0; i < strokeData.btn.len(); ++i)
          buttons.append(Button(strokeData.dev[i], strokeData.btn[i], preset))

        if (buttons.len() > 1)
          inputs.append(Combination(buttons))
        else
          inputs.extend(buttons)
      }

      if (!inputs.len())
        inputs.append(getNullInput(shortcutId, showShortcutsNameIfNotAssign))
      return inputs
    })
  }

  AXIS = {
    isMe = function (shortcutId) {
      let shortcutConfig = getShortcutById(shortcutId)
      return getTblValue("type", shortcutConfig) == CONTROL_TYPE.AXIS
    }


    getUseAxisShortcuts = function (axisIdsArray, axisInput, preset = null) {
      let buttons = []
      let activeAxes = getShortcuts(axisIdsArray, preset)

      if (axisInput.deviceId == STD_MOUSE_DEVICE_ID && axisIdsArray.len() > 0) {
        let hotKey = this.commonShortcutActiveAxis?[axisIdsArray[0]]
        if (hotKey)
          activeAxes.extend(hotKey())
      }
      foreach (activeAxis in activeAxes) {
        if (activeAxis.len() < 1)
          continue

        for (local i = 0; i < activeAxis[0].btn.len(); ++i)
          buttons.append(Button(activeAxis[0].dev[i], activeAxis[0].btn[i], preset))

        if (buttons.len() > 0)
          break
      }

      let inputs = []
      buttons.append(axisInput)
      if (buttons.len() > 1)
        inputs.append(Combination(buttons))
      else
        inputs.extend(buttons)

      return inputs
    }

    isAssigned = function (shortcutId, _preset = null) {
      return isAssignedToAxis(shortcutId) || isAxisAssignedToShortcuts(shortcutId)
    }

    expand = function (shortcutId, showKeyBoardShortcutsForMouseAim) {
      if (isAssignedToAxis(shortcutId, showKeyBoardShortcutsForMouseAim) || this.hasDirection(shortcutId))
        return [shortcutId]
      else
        return transformAxisToShortcuts(shortcutId)
    }

    getInputs = kwarg(function getInputs(shortcutId, preset = null,
      _isMouseHigherPriority = true, _showShortcutsNameIfNotAssign = false) {
      if (this.hasDirection(shortcutId) && !isAssignedToAxis(shortcutId)) {
        let input = KeyboardAxis(this.getBaseAxesShortcuts(shortcutId).map(function(element) {
            let elementId = element.shortcut
            element.input <- g_shortcut_type.getShortcutTypeByShortcutId(elementId).getFirstInput(elementId, preset)
            return element
          }
        ))
        input.isCompositAxis = false
        return [input]
      }

      let axisDescription = g_shortcut_type._getDeviceAxisDescription(shortcutId)
      return this.getUseAxisShortcuts([shortcutId], Axis(axisDescription, AXIS_MODIFIERS.NONE, preset), preset)
    })

    commonShortcutActiveAxis =    
    {
      camx            = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      camy            = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      gm_camx         = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      gm_camy         = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      ship_camx       = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      ship_camy       = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      helicopter_camx = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      helicopter_camy = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      submarine_camx  = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      submarine_camy  = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      human_camx      = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      human_camy      = @() getShortcuts(["ID_CAMERA_NEUTRAL"])
      



    }

    getDirection = function(shortcutId) {
      return getShortcutById(shortcutId)?.axisDirection
    }

    hasDirection = function(shortcutId) {
      return this.getDirection(shortcutId) != null
    }

    getBaseAxesShortcuts = function (shortcutId) {
      let result = []
      let shortcutDirection = this.getDirection(shortcutId)
      let axisShortcutPostfixes = ["rangeMin", "rangeMax"]
      foreach (postfix in axisShortcutPostfixes)
        result.append({
          shortcut = $"{shortcutId}_{postfix}"
          axisDirection = shortcutDirection
          postfix = postfix
        })

      return result
    }
  }

  HALF_AXIS = {
    isMe = function (shortcutId) {
      return (shortcutId.indexof("=max") != null ||
             shortcutId.indexof("=min") != null) &&
             !g_shortcut_type.HALF_AXIS_HOLD.isMe(shortcutId)
    }

    getAxisName = function (shortcutId) {
      return shortcutId.slice(0, shortcutId.indexof("="))
    }

    transformHalfAxisToShortcuts = function (shortcutId) {
      let fullAxisId = this.getAxisName(shortcutId)
      if (shortcutId.indexof("=max") != null)
        return $"{fullAxisId}_rangeMax"
      if (shortcutId.indexof("=min") != null)
        return $"{fullAxisId}_rangeMin"

      
      return ""
    }

    isAssigned = function (shortcutId, preset = null) {
      let fullAxisId = this.getAxisName(shortcutId)
      return isAssignedToAxis(fullAxisId, preset) || isHalfAxisAssignedToShortcuts(this.transformHalfAxisToShortcuts(shortcutId))
    }

    expand = function (shortcutId, showKeyBoardShortcutsForMouseAim) {
      let fullAxisId = this.getAxisName(shortcutId)
      if (isAssignedToAxis(fullAxisId, showKeyBoardShortcutsForMouseAim))
        return [shortcutId]
      else
        return [this.transformHalfAxisToShortcuts(shortcutId)]
    }

    getInputs = kwarg(function getInputs(shortcutId, preset = null,
      isMouseHigherPriority = true, _showShortcutsNameIfNotAssign = false) {
      let fullAxisId = this.getAxisName(shortcutId)
      let axisDesc = g_shortcut_type._getDeviceAxisDescription(
        fullAxisId, isMouseHigherPriority)
      local modifier = AXIS_MODIFIERS.NONE
      let isInverse = axisDesc.inverse &&
        (axisDesc.axisId != -1 || axisDesc.mouseAxis == -1)
      if (shortcutId.indexof("=max") != null)
        modifier = !isInverse ? AXIS_MODIFIERS.MAX : AXIS_MODIFIERS.MIN
      if (shortcutId.indexof("=min") != null)
        modifier = !isInverse ? AXIS_MODIFIERS.MIN : AXIS_MODIFIERS.MAX

      return [Axis(axisDesc, modifier, preset)]
    })
  }

  HALF_AXIS_HOLD = {
    isMe = function (shortcutId) {
      return shortcutId.indexof("=max_hold") != null ||
             shortcutId.indexof("=min_hold") != null
    }

    getAxisName = function (shortcutId) {
      return g_shortcut_type.HALF_AXIS.getAxisName(shortcutId)
    }

    transformHalfAxisToShortcuts = function (shortcutId) {
      return g_shortcut_type.HALF_AXIS.transformHalfAxisToShortcuts(shortcutId)
    }

    isAssigned = function (shortcutId, preset = null) {
      return g_shortcut_type.HALF_AXIS.isAssigned(shortcutId, preset)
    }

    expand = function (shortcutId, _showKeyBoardShortcutsForMouseAim) {
      let fullAxisId = this.getAxisName(shortcutId)
      if (isAssignedToJoyAxis(fullAxisId))
        return [shortcutId]
      else if (isAxisAssignedToShortcuts(fullAxisId))
        return [this.transformHalfAxisToShortcuts(shortcutId)]
      else 
        return [shortcutId]
    }

    getInputs = kwarg(function getInputs(shortcutId, preset = null,
      _isMouseHigherPriority = true, showShortcutsNameIfNotAssign = false) {
      return g_shortcut_type.HALF_AXIS.getInputs({
        shortcutId = shortcutId
        preset = preset
        isMouseHigherPriority = false
        showShortcutsNameIfNotAssign = showShortcutsNameIfNotAssign
      }, KWARG_NON_STRICT)
    })
  }

  COMPOSIT_AXIS = {
    isMe = function (shortcutId) {
      return shortcutId.indexof("+") != null
    }

    isAssigned = function (shortcutId, preset = null) {
      foreach (axis in splitCompositAxis(shortcutId))
        if (!g_shortcut_type.AXIS.isAssigned(axis, preset))
          return false

      return true
    }

    expand = function (shortcutId, showKeyBoardShortcutsForMouseAim) {
      let axes = splitCompositAxis(shortcutId)

      if (isComponentsAssignedToSingleInputItem(getComplexAxesId(axes))
        || this.hasDirection(shortcutId))
        return [shortcutId]

      let result = []
      foreach (axis in axes)
        result.extend(g_shortcut_type.AXIS.expand(axis, showKeyBoardShortcutsForMouseAim))

      return result
    }

    getInputs = kwarg(function getInputs(shortcutId, preset = null,
      _isMouseHigherPriority = true, _showShortcutsNameIfNotAssign = false) {
      let axes = splitCompositAxis(shortcutId)

      let doubleAxis = DoubleAxis()
      doubleAxis.deviceId = NULL_INPUT_DEVICE_ID
      doubleAxis.axisIds = getComplexAxesId(axes)

      if (isXInputDevice())
        doubleAxis.deviceId = JOYSTICK_DEVICE_0_ID
      else if (isAxisBoundToMouse(axes[0]))
        doubleAxis.deviceId = STD_MOUSE_DEVICE_ID
      else if (this.hasDirection(shortcutId)) {
        let input = KeyboardAxis(this.getBaseAxesShortcuts(shortcutId).map(function(element) {
            let elementId = element.shortcut
            element.input <- g_shortcut_type.getShortcutTypeByShortcutId(elementId).getFirstInput(elementId, preset)
            return element
          }
        ))
        input.isCompositAxis = true
        return [input]
      }

      return g_shortcut_type.AXIS.getUseAxisShortcuts(axes, doubleAxis, preset)
    })

    hasDirection = function(shortcutId) {
      foreach (axis in splitCompositAxis(shortcutId))
        if (!g_shortcut_type.AXIS.hasDirection(axis))
          return false

      return true
    }

    getBaseAxesShortcuts = function (shortcutId) {
      let axes = splitCompositAxis(shortcutId)
      let result = []
      axes.map(@(axis) result.extend(g_shortcut_type.AXIS.getBaseAxesShortcuts(axis)))
      return result
    }
  }

  IMAGE_SHORTCUT = {
    isMe = function (shortcutId) {
      return imageRe.match(shortcutId)
    }

    isAssigned = function (_shortcutId, _preset = null) {
      return true
    }

    getFirstInput = function (shortcutId, _preset = null, _params = {}) {
      return InputImage(shortcutId)
    }
  }
}, null, "typeName")
return {g_shortcut_type}