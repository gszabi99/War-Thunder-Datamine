local enums = require("sqStdlibs/helpers/enums.nut")
local globalEnv = require_native("globalEnv")


local function getNullInput(shortcutId, showShortcutsNameIfNotAssign) {
  local nullInput = ::Input.NullInput()
  nullInput.shortcutId = shortcutId
  nullInput.showPlaceholder = showShortcutsNameIfNotAssign
  return nullInput
}

::g_shortcut_type <- {
  types = []
}

g_shortcut_type.getShortcutTypeByShortcutId <- function getShortcutTypeByShortcutId(shortcutId)
{
  foreach (t in types)
    if (t.isMe(shortcutId))
      return t
  return ::g_shortcut_type.COMMON_SHORTCUT
}

g_shortcut_type.isAxisShortcut <- function isAxisShortcut(shortcutId)
{
  foreach (postfix in ["rangeMin", "rangeMax"])
    if (::g_string.endsWith(shortcutId, postfix))
      return true
  return false
}

g_shortcut_type.expandShortcuts <- function expandShortcuts(shortcutIdList, showKeyBoardShortcutsForMouseAim = false)
{
  local result = []
  foreach (shortcutId in shortcutIdList)
  {
    local shortcutType = getShortcutTypeByShortcutId(shortcutId)
    result.extend(shortcutType.expand(shortcutId, showKeyBoardShortcutsForMouseAim))
  }

  return result
}

g_shortcut_type.getShortcutMarkup <- function getShortcutMarkup(shortcutId, preset)
{
  local markup = ""
  local shortcutType = getShortcutTypeByShortcutId(shortcutId)
  if (!shortcutType.isAssigned(shortcutId, preset))
    return markup

  local expanded = expandShortcuts([shortcutId])
  foreach (expandedShortcut in expanded)
  {
    local expandedType = getShortcutTypeByShortcutId(expandedShortcut)
    local input = expandedType.getFirstInput(expandedShortcut, preset)
    markup += input.getMarkup()
  }

  return markup
}

g_shortcut_type._isAxisBoundToMouse <- function _isAxisBoundToMouse(shortcutId)
{
  return ::is_axis_mapped_on_mouse(shortcutId)
}

g_shortcut_type._getBitArrayAxisIdByShortcutId <- function _getBitArrayAxisIdByShortcutId(shortcutId)
{
  local joyParams = ::JoystickParams()
  joyParams.setFrom(::joystick_get_cur_settings())
  local shortcutData = ::get_shortcut_by_id(shortcutId)
  local axis = joyParams.getAxis(shortcutData.axisIndex)

  if (axis.axisId < 0)
    if (_isAxisBoundToMouse(shortcutId))
      return ::get_mouse_axis(shortcutId, null, joyParams)
    else
      return GAMEPAD_AXIS.NOT_AXIS

  return 1 << axis.axisId
}


g_shortcut_type._getDeviceAxisDescription <- function _getDeviceAxisDescription(shortcutId, isMouseHigherPriority = true)
{
  local result = {
    deviceId = ::NULL_INPUT_DEVICE_ID
    axisId = -1
    mouseAxis = null
    inverse = false
  }

  local joyParams = ::JoystickParams()
  joyParams.setFrom(::joystick_get_cur_settings())
  local axisIndex = ::getTblValue("axisIndex", ::get_shortcut_by_id(shortcutId), -1)
  if (axisIndex < 0)
    return result

  local axis = joyParams.getAxis(axisIndex)

  result.axisId = axis.axisId
  result.inverse = axis.inverse

  if ((result.axisId == -1 || isMouseHigherPriority) &&
    ::is_axis_mapped_on_mouse(shortcutId, null, joyParams))
  {
    result.deviceId = ::STD_MOUSE_DEVICE_ID
    result.mouseAxis = ::get_mouse_axis(shortcutId, null, joyParams)
  }
  if (::is_xinput_device())
    result.deviceId = ::JOYSTICK_DEVICE_0_ID

  return result
}

::g_shortcut_type.template <- {
  isMe = function (shortcutId) { return false }
  isAssigned = function (shortcutId, preset = null) { return false }


  /**
   * Expands complex shortcuts and axes to most suitable
   * list of common shortcuts or axis for display
   */
  expand = function (shortcutId, showKeyBoardShortcutsForMouseAim) { return [shortcutId] }


  /**
   * @return array of Input instances
   * Array contains atlast one element (NullInput)
   */
  getInputs = ::kwarg(function getInputs(shortcutId, preset = null,
    isMouseHigherPriority = true, showShortcutsNameIfNotAssign = false)
  {
    return [getNullInput(shortcutId, showShortcutsNameIfNotAssign)]
  })


  /**
   * @return first Input for @shortcutId or NullInput.
   * Also tries to find input with most suitable device type.
   */
  getFirstInput = function (shortcutId, preset = null, showShortcutsNameIfNotAssign = false) {
    local inputs = getInputs({
      shortcutId = shortcutId
      preset = preset
      showShortcutsNameIfNotAssign = showShortcutsNameIfNotAssign
    })
    local bestInput = inputs[0]

    if (::is_xinput_device())
    {
      foreach (input in inputs)
        if (input.getDeviceId() == ::JOYSTICK_DEVICE_0_ID)
        {
          bestInput = input
          break
        }
    }

    return bestInput
  }

}

enums.addTypesByGlobalName("g_shortcut_type", {
  COMMON_SHORTCUT = {
    isMe = function (shortcutId)
    {
      local shortcutConfig = ::get_shortcut_by_id(shortcutId)
      if (!shortcutConfig)
        return ::g_shortcut_type.isAxisShortcut(shortcutId)
      return ::getTblValue("type", shortcutConfig) != CONTROL_TYPE.AXIS
    }

    isAssigned = function (shortcutId, preset = null)
    {
      return ::isShortcutMapped(::get_shortcuts([shortcutId], preset)[0])
    }

    getInputs = ::kwarg(function getInputs(shortcutId, preset = null,
      isMouseHigherPriority = true, showShortcutsNameIfNotAssign = false)
    {
      local rawShortcutData = ::get_shortcuts([shortcutId], preset)[0]

      if (!rawShortcutData)
        return [getNullInput(shortcutId, showShortcutsNameIfNotAssign)]

      local inputs = []
      foreach (strokeData in rawShortcutData)
      {
        local buttons = []
        for (local i = 0; i < strokeData.btn.len(); ++i)
          buttons.append(::Input.Button(strokeData.dev[i], strokeData.btn[i], preset))

        if (buttons.len() > 1)
          inputs.append(::Input.Combination(buttons))
        else
          inputs.extend(buttons)
      }

      if (!inputs.len())
        inputs.append(getNullInput(shortcutId, showShortcutsNameIfNotAssign))
      return inputs
    })
  }

  AXIS = {
    isMe = function (shortcutId)
    {
      local shortcutConfig = ::get_shortcut_by_id(shortcutId)
      return ::getTblValue("type", shortcutConfig) == CONTROL_TYPE.AXIS
    }

    transformAxisToShortcuts = function (axisId)
    {
      local result = []
      local axisShortcutPostfixes = ["rangeMin", "rangeMax"]
      foreach(postfix in axisShortcutPostfixes)
        result.append(axisId + "_" + postfix)

      return result
    }

    getUseAxisShortcuts = function (axisIdsArray, axisInput, preset = null)
    {
      local buttons = []
      local activeAxes = ::get_shortcuts(axisIdsArray, preset)

      if (axisInput.deviceId == ::STD_MOUSE_DEVICE_ID && axisIdsArray.len() > 0)
      {
        local hotKey = commonShortcutActiveAxis?[axisIdsArray[0]]
        if (hotKey)
          activeAxes.extend(hotKey())
      }
      foreach (activeAxis in activeAxes)
      {
        if (activeAxis.len() < 1)
          continue

        for (local i = 0; i < activeAxis[0].btn.len(); ++i)
          buttons.append(::Input.Button(activeAxis[0].dev[i], activeAxis[0].btn[i], preset))

        if (buttons.len() > 0)
          break
      }

      local inputs = []
      buttons.append(axisInput)
      if (buttons.len() > 1)
        inputs.append(::Input.Combination(buttons))
      else
        inputs.extend(buttons)

      return inputs
    }

    isAssigned = function (shortcutId, preset = null)
    {
      return isAssignedToAxis(shortcutId) || isAssignedToShortcuts(shortcutId)
    }

    isAssignedToJoyAxis = function (shortcutId)
    {
      local axisDesc = ::g_shortcut_type._getDeviceAxisDescription(shortcutId)
      return axisDesc.axisId >= 0
    }

    isAssignedToAxis = function (shortcutId, showKeyBoardShortcutsForMouseAim = false)
    {
      local isMouseAimMode = ::getCurrentHelpersMode() == globalEnv.EM_MOUSE_AIM
      if ((!showKeyBoardShortcutsForMouseAim || !isMouseAimMode)
        && ::g_shortcut_type._isAxisBoundToMouse(shortcutId))
        return true
      return isAssignedToJoyAxis(shortcutId)
    }

    isAssignedToShortcuts = function (shortcutId)
    {
      local shortcuts = transformAxisToShortcuts(shortcutId)
      foreach (axisBorderShortcut in shortcuts)
        if (!::g_shortcut_type.COMMON_SHORTCUT.isAssigned(axisBorderShortcut))
          return false
      return true
    }

    expand = function (shortcutId, showKeyBoardShortcutsForMouseAim)
    {
      if (isAssignedToAxis(shortcutId, showKeyBoardShortcutsForMouseAim) || hasDirection(shortcutId))
        return [shortcutId]
      else
        return transformAxisToShortcuts(shortcutId)
    }

    getInputs = ::kwarg(function getInputs(shortcutId, preset = null,
      isMouseHigherPriority = true, showShortcutsNameIfNotAssign = false)
    {
      if (hasDirection(shortcutId) && !isAssignedToAxis(shortcutId))
      {
        local input = ::Input.KeyboardAxis(u.map(getBaseAxesShortcuts(shortcutId),
          function(element) {
            local elementId = element.shortcut
            element.input <- ::g_shortcut_type.getShortcutTypeByShortcutId(elementId).getFirstInput(elementId, preset)
            return element
          }
        ))
        input.isCompositAxis = false
        return [input]
      }

      local axisDescription = ::g_shortcut_type._getDeviceAxisDescription(shortcutId)
      return getUseAxisShortcuts([shortcutId], ::Input.Axis(axisDescription, AXIS_MODIFIERS.NONE, preset), preset)
    })

    commonShortcutActiveAxis =    //when axis are activated by common shortcut
    {
      camx            = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      camy            = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      gm_camx         = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      gm_camy         = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      ship_camx       = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      ship_camy       = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      helicopter_camx = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      helicopter_camy = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      submarine_camx  = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      submarine_camy  = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      //



      suit_camx       = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
      suit_camy       = @() ::get_shortcuts(["ID_CAMERA_NEUTRAL"])
    }

    getDirection = function(shortcutId)
    {
      return ::get_shortcut_by_id(shortcutId)?.axisDirection
    }

    hasDirection = function(shortcutId)
    {
      return getDirection(shortcutId) != null
    }

    getBaseAxesShortcuts = function (shortcutId)
    {
      local result = []
      local shortcutDirection = getDirection(shortcutId)
      local axisShortcutPostfixes = ["rangeMin", "rangeMax"]
      foreach(postfix in axisShortcutPostfixes)
        result.append({
          shortcut = shortcutId + "_" + postfix
          axisDirection = shortcutDirection
          postfix = postfix
        })

      return result
    }
  }

  HALF_AXIS = {
    isMe = function (shortcutId)
    {
      return (shortcutId.indexof("=max") != null ||
             shortcutId.indexof("=min") != null) &&
             !::g_shortcut_type.HALF_AXIS_HOLD.isMe(shortcutId)
    }

    getAxisName = function (shortcutId)
    {
      return shortcutId.slice(0, shortcutId.indexof("="))
    }

    transformHalfAxisToShortcuts = function (shortcutId)
    {
      local fullAxisId = getAxisName(shortcutId)
      if (shortcutId.indexof("=max") != null)
        return fullAxisId + "_rangeMax"
      if (shortcutId.indexof("=min") != null)
        return fullAxisId + "_rangeMin"

      //actualy imposible situation if isAssigned used befor expand
      return ""
    }

    isAssigned = function (shortcutId, preset = null)
    {
      return ::g_shortcut_type.AXIS.isAssigned(getAxisName(shortcutId), preset)
    }

    expand = function (shortcutId, showKeyBoardShortcutsForMouseAim)
    {
      local fullAxisId = getAxisName(shortcutId)
      if (::g_shortcut_type.AXIS.isAssignedToAxis(fullAxisId, showKeyBoardShortcutsForMouseAim))
        return [shortcutId]
      else
        return [transformHalfAxisToShortcuts(shortcutId)]
    }

    getInputs = ::kwarg(function getInputs(shortcutId, preset = null,
      isMouseHigherPriority = true, showShortcutsNameIfNotAssign = false)
    {
      local fullAxisId = getAxisName(shortcutId)
      local axisDesc = ::g_shortcut_type._getDeviceAxisDescription(
        fullAxisId, isMouseHigherPriority)
      local modifier = AXIS_MODIFIERS.NONE
      local isInverse = axisDesc.inverse &&
        (axisDesc.axisId != -1 || axisDesc.mouseAxis == -1)
      if (shortcutId.indexof("=max") != null)
        modifier = !isInverse ? AXIS_MODIFIERS.MAX : AXIS_MODIFIERS.MIN
      if (shortcutId.indexof("=min") != null)
        modifier = !isInverse ? AXIS_MODIFIERS.MIN : AXIS_MODIFIERS.MAX

      return [::Input.Axis(axisDesc, modifier, preset)]
    })
  }

  HALF_AXIS_HOLD = {
    isMe = function (shortcutId)
    {
      return shortcutId.indexof("=max_hold") != null ||
             shortcutId.indexof("=min_hold") != null
    }

    getAxisName = function (shortcutId)
    {
      return ::g_shortcut_type.HALF_AXIS.getAxisName(shortcutId)
    }

    transformHalfAxisToShortcuts = function (shortcutId)
    {
      return ::g_shortcut_type.HALF_AXIS.transformHalfAxisToShortcuts(shortcutId)
    }

    isAssigned = function (shortcutId, preset = null)
    {
      return ::g_shortcut_type.HALF_AXIS.isAssigned(shortcutId, preset)
    }

    expand = function (shortcutId, showKeyBoardShortcutsForMouseAim)
    {
      local fullAxisId = getAxisName(shortcutId)
      if (::g_shortcut_type.AXIS.isAssignedToJoyAxis(fullAxisId))
        return [shortcutId]
      else if (::g_shortcut_type.AXIS.isAssignedToShortcuts(fullAxisId))
        return [transformHalfAxisToShortcuts(shortcutId)]
      else // if mouseAxisAssigned
        return [shortcutId]
    }

    getInputs = ::kwarg(function getInputs(shortcutId, preset = null,
      isMouseHigherPriority = true, showShortcutsNameIfNotAssign = false)
    {
      return ::g_shortcut_type.HALF_AXIS.getInputs({
        shortcutId = shortcutId
        preset = preset
        isMouseHigherPriority = false
        showShortcutsNameIfNotAssign = showShortcutsNameIfNotAssign
      })
    })
  }

  COMPOSIT_AXIS = {
    isMe = function (shortcutId)
    {
      return shortcutId.indexof("+") != null
    }

    splitCompositAxis = function (compositAxis)
    {
      return ::split(compositAxis, "+")
    }

    isAssigned = function (shortcutId, preset = null)
    {
      foreach (axis in splitCompositAxis(shortcutId))
        if (!::g_shortcut_type.AXIS.isAssigned(axis, preset))
          return false

      return true
    }


    /**
     * Checks wether all components assigned to one stick or mouse move.
     * @shortcutComponents - array of components, contains shortcutIds
     * @return - bool
     */
    isComponentsAssignedToSingleInputItem = function (shortcutComponents)
    {
      local axesId = getComplexAxesId(shortcutComponents)
      return axesId == GAMEPAD_AXIS.RIGHT_STICK ||
             axesId == GAMEPAD_AXIS.LEFT_STICK  ||
             axesId == MOUSE_AXIS.MOUSE_MOVE
    }

    getComplexAxesId = function (shortcutComponents)
    {
      local axesId = 0
      foreach (shortcutId in shortcutComponents)
        axesId = axesId | ::g_shortcut_type._getBitArrayAxisIdByShortcutId(shortcutId)

      return axesId
    }

    expand = function (shortcutId, showKeyBoardShortcutsForMouseAim)
    {
      local axes = splitCompositAxis(shortcutId)

      if (isComponentsAssignedToSingleInputItem(axes)
        || hasDirection(shortcutId))
        return [shortcutId]

      local result = []
      foreach (axis in axes)
        result.extend(::g_shortcut_type.AXIS.expand(axis, showKeyBoardShortcutsForMouseAim))

      return result
    }

    getInputs = ::kwarg(function getInputs(shortcutId, preset = null,
      isMouseHigherPriority = true, showShortcutsNameIfNotAssign = false)
    {
      local axes = splitCompositAxis(shortcutId)

      local doubleAxis = ::Input.DoubleAxis()
      doubleAxis.deviceId = ::NULL_INPUT_DEVICE_ID
      doubleAxis.axisIds = getComplexAxesId(axes)

      if (::is_xinput_device())
        doubleAxis.deviceId = ::JOYSTICK_DEVICE_0_ID
      else if (::g_shortcut_type._isAxisBoundToMouse(axes[0]))
        doubleAxis.deviceId = ::STD_MOUSE_DEVICE_ID
      else if (hasDirection(shortcutId))
      {
        local input = ::Input.KeyboardAxis(u.map(getBaseAxesShortcuts(shortcutId),
          function(element) {
            local elementId = element.shortcut
            element.input <- ::g_shortcut_type.getShortcutTypeByShortcutId(elementId).getFirstInput(elementId, preset)
            return element
          }
        ))
        input.isCompositAxis = true
        return [input]
      }

      return ::g_shortcut_type.AXIS.getUseAxisShortcuts(axes, doubleAxis, preset)
    })

    hasDirection = function(shortcutId)
    {
      foreach (axis in splitCompositAxis(shortcutId))
        if (!::g_shortcut_type.AXIS.hasDirection(axis))
          return false

      return true
    }

    getBaseAxesShortcuts = function (shortcutId)
    {
      local axes = splitCompositAxis(shortcutId)
      local result = []
      axes.map(@(axis) result.extend(::g_shortcut_type.AXIS.getBaseAxesShortcuts(axis)))
      return result
    }
  }

  PSEUDO_AXIS = {
    isMe = function (shortcutId)
    {
      return ::g_pseudo_axes_list.isPseudoAxis(shortcutId)
    }

    isAssigned = function (shortcutId, preset = null)
    {
      local pseudoAxis = ::g_pseudo_axes_list.getPseudoAxisById(shortcutId)
      return pseudoAxis.isAssigned()
    }

    expand = function (shortcutId, showKeyBoardShortcutsForMouseAim)
    {
      local pseudoAxis = ::g_pseudo_axes_list.getPseudoAxisById(shortcutId)
      return pseudoAxis.translate()
    }
  }

  IMAGE_SHORTCUT = {
    imageRe = regexp2(@"^#[\w/_]*#[\w\d_]+")
    isMe = function (shortcutId)
    {
      return imageRe.match(shortcutId)
    }

    isAssigned = function (shortcutId, preset = null)
    {
      return true
    }

    getFirstInput = function (shortcutId, preset = null, showShortcutsNameIfNotAssign = false) {
      return ::Input.InputImage(shortcutId)
    }
  }
}, null, "typeName")
