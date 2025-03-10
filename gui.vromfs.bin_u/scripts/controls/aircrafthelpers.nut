from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import AIR_MOUSE_USAGE, optionControlType

let globalEnv = require("globalEnv")
let { set_gui_option } = require("guiOptions")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_HELPERS_MODE,USEROPT_HELPERS_MODE_GM, USEROPT_MOUSE_USAGE,
  USEROPT_MOUSE_USAGE_NO_AIM, USEROPT_INSTRUCTOR_ENABLED, USEROPT_AUTOTRIM
} = require("%scripts/options/optionsExtNames.nut")
let { get_gui_option_in_mode, set_gui_option_in_mode } = require("%scripts/options/options.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { commitControls } = require("%scripts/controls/controlsManager.nut")
let { get_option, registerOption } = require("%scripts/options/optionsExt.nut")

local isAircraftHelpersOptionsInitialized = false
local isHelpersChangePerformed = false


let controlHelpersOptions = {
  helpersMode       = USEROPT_HELPERS_MODE
  mouseUsage        = USEROPT_MOUSE_USAGE
  mouseUsageNoAim   = USEROPT_MOUSE_USAGE_NO_AIM
  instructorEnabled = USEROPT_INSTRUCTOR_ENABLED
  autotrim          = USEROPT_AUTOTRIM
}


function getPresetMouseUsage() {
  
  let curPreset = getCurControlsPreset()
  if (curPreset.params?.mouseJoystick)
    return AIR_MOUSE_USAGE.JOYSTICK
  if (curPreset.getAxis("elevator")?.mouseAxisId == 1)
    return AIR_MOUSE_USAGE.RELATIVE
  if (curPreset.getAxis("camy")?.mouseAxisId == 1)
    return AIR_MOUSE_USAGE.VIEW

  return AIR_MOUSE_USAGE.NOT_USED
}


function updatePresetMouseUsage() {
  let curPreset = getCurControlsPreset()
  let mouseUsageNoAim = get_gui_option_in_mode(
    USEROPT_MOUSE_USAGE_NO_AIM, OPTIONS_MODE_GAMEPLAY)

  
  if (getPresetMouseUsage() == mouseUsageNoAim)
    return

  
  curPreset.params.mouseJoystick <-
    mouseUsageNoAim == AIR_MOUSE_USAGE.JOYSTICK

  
  foreach (_axisName, axis in curPreset.axes)
    if ("mouseAxisId" in axis &&
      (axis.mouseAxisId == 0 || axis.mouseAxisId == 1))
      axis.mouseAxisId <- -1

  
  if (mouseUsageNoAim == AIR_MOUSE_USAGE.JOYSTICK ||
    mouseUsageNoAim == AIR_MOUSE_USAGE.RELATIVE) {
    curPreset.getAxis("ailerons").mouseAxisId <- 0
    curPreset.getAxis("elevator").mouseAxisId <- 1
  }
  else if (mouseUsageNoAim == AIR_MOUSE_USAGE.VIEW) {
    curPreset.getAxis("camx").mouseAxisId <- 0
    curPreset.getAxis("camy").mouseAxisId <- 1
  }

  
  commitControls()
}


function onHelpersChanged(forcedByOption = null, forceUpdateFromPreset = false) {
  
  if (!isLoggedIn.get() || isHelpersChangePerformed)
    return
  isHelpersChangePerformed = true

  
  let options = {}
  if (!forceUpdateFromPreset)
    foreach (name, optionId in controlHelpersOptions)
      options[name] <- get_gui_option_in_mode(
        optionId, OPTIONS_MODE_GAMEPLAY)
  else
    foreach (name, _optionId in controlHelpersOptions)
      options[name] <- null
  let prevOptions = clone options

  
  if (options.mouseUsage != AIR_MOUSE_USAGE.AIM) {
    if (forcedByOption == USEROPT_MOUSE_USAGE_NO_AIM)
      options.mouseUsage = options.mouseUsageNoAim
    else
      options.mouseUsageNoAim = options.mouseUsage
  }

  
  if (forcedByOption == USEROPT_MOUSE_USAGE) {
    if (options.mouseUsage == AIR_MOUSE_USAGE.AIM)
      options.helpersMode = globalEnv.EM_MOUSE_AIM
    else
      options.helpersMode = max(options.helpersMode, globalEnv.EM_INSTRUCTOR)
    }
  else if (USEROPT_INSTRUCTOR_ENABLED == forcedByOption) {
    if (options.instructorEnabled)
      options.helpersMode = min(options.helpersMode, globalEnv.EM_INSTRUCTOR)
    else
      options.helpersMode = max(options.helpersMode, globalEnv.EM_REALISTIC)
  }
  else if (USEROPT_AUTOTRIM == forcedByOption) {
    if (options.autotrim)
      options.helpersMode = min(options.helpersMode, globalEnv.EM_REALISTIC)
    else
      options.helpersMode = globalEnv.EM_FULL_REAL
  }
  else if (options.helpersMode == null) {
    
    if (options.mouseUsage == AIR_MOUSE_USAGE.AIM)
      options.helpersMode = globalEnv.EM_MOUSE_AIM
    else if (options.autotrim == false)
      options.helpersMode = globalEnv.EM_FULL_REAL
    else if (options.instructorEnabled == false)
      options.helpersMode = globalEnv.EM_REALISTIC
    else
      options.helpersMode = is_platform_android ?
        globalEnv.EM_INSTRUCTOR : globalEnv.EM_MOUSE_AIM
  }


  
  options.instructorEnabled = true
  options.autotrim = true

  
  let helpersMode = options.helpersMode
  if ( helpersMode == globalEnv.EM_FULL_REAL) {
    options.instructorEnabled = false
    options.autotrim = false
    if (options.mouseUsage == AIR_MOUSE_USAGE.AIM)
      options.mouseUsage = options.mouseUsageNoAim
  }
  else if (helpersMode == globalEnv.EM_REALISTIC) {
    options.instructorEnabled = false
    if (options.mouseUsage == AIR_MOUSE_USAGE.AIM)
      options.mouseUsage = options.mouseUsageNoAim
  }
  else if (helpersMode == globalEnv.EM_INSTRUCTOR) {
    if (options.mouseUsage == AIR_MOUSE_USAGE.AIM)
      options.mouseUsage = options.mouseUsageNoAim
  }
  else if ( helpersMode == globalEnv.EM_MOUSE_AIM) {
    options.mouseUsage = AIR_MOUSE_USAGE.AIM
  }

  
  if (options.mouseUsageNoAim == null) {
    options.mouseUsageNoAim = getPresetMouseUsage()
    if (options.mouseUsage == null)
      options.mouseUsage = options.mouseUsageNoAim
  }

  
  foreach (name, optionId in controlHelpersOptions)
    if (options[name] != prevOptions[name])
      set_gui_option_in_mode(optionId,
        options[name], OPTIONS_MODE_GAMEPLAY)

  updatePresetMouseUsage()
  isHelpersChangePerformed = false
  isAircraftHelpersOptionsInitialized = true
}


function setAircraftHelpersOptionValue(optionId, newValue) {
  let oldValue = get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY)
  if (oldValue == newValue)
    return
  set_gui_option_in_mode(optionId, newValue, OPTIONS_MODE_GAMEPLAY)
  onHelpersChanged(optionId)
}


function getAircraftHelpersOptionValue(optionId) {
  if (!isAircraftHelpersOptionsInitialized)
    onHelpersChanged()
  return get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY)
}

function fillUseroptMouseUsageDescr(optionId, descr, _context) {
  let ignoreAim = optionId == USEROPT_MOUSE_USAGE_NO_AIM
  descr.id = ignoreAim ? "mouse_usage_no_aim" : "mouse_usage"
  descr.items = [
    "#options/nothing"
    "#options/mouse_aim"
    "#options/mouse_joystick"
    "#options/mouse_relative"
    "#options/mouse_view"
  ]
  descr.values = [
    AIR_MOUSE_USAGE.NOT_USED
    AIR_MOUSE_USAGE.AIM
    AIR_MOUSE_USAGE.JOYSTICK
    AIR_MOUSE_USAGE.RELATIVE
    AIR_MOUSE_USAGE.VIEW
  ]

  if (ignoreAim) {
    let aimIdx = descr.values.indexof(AIR_MOUSE_USAGE.AIM)
    descr.values.remove(aimIdx)
    descr.items.remove(aimIdx)
  }

  descr.defaultValue = descr.values.indexof(
    getAircraftHelpersOptionValue(optionId))
}

let setUseroptHelpersMode = @(value, descr, optionId)
  setAircraftHelpersOptionValue(optionId, descr.values != null ? descr.values?[value] ?? 0 : value)

function fillUseroptHelpersModeDescr(optionId, descr, _context) {
  descr.id = "helpers_mode"
  descr.items = []
  let types = ["mouse_aim", "virtual_instructor", "simplified_controls", "full_real"]
  for (local t = 0; t < types.len(); t++)
    descr.items.append({
      text = $"#options/{types[t]}"
      tooltip = $"#options/{types[t]}/tooltip"
    })
  descr.values = [
    globalEnv.EM_MOUSE_AIM,
    globalEnv.EM_INSTRUCTOR,
    globalEnv.EM_REALISTIC,
    globalEnv.EM_FULL_REAL
  ]
  descr.optionCb = "onHelpersModeChange"
  descr.defaultValue = getAircraftHelpersOptionValue(optionId)
}

function fillUseroptHelpersModeGMDescr(_optionId, descr, _context) {
  descr.id = "helpers_mode"
  descr.items = []
  let types = ["mouse_aim", "virtual_instructor", "simplified_controls", "full_real"]
  for (local t = 0; t < types.len(); t++)
    descr.items.append({
      text = $"#options/{types[t]}/tank"
      tooltip = $"#options/{types[t]}/tank/tooltip"
    })
  descr.values = [
    globalEnv.EM_MOUSE_AIM,
    globalEnv.EM_INSTRUCTOR,
    globalEnv.EM_REALISTIC,
    globalEnv.EM_FULL_REAL
  ]
  descr.optionCb = "onHelpersModeChange"
  descr.defaultValue = get_option(USEROPT_HELPERS_MODE).value
}

let descriptionOptionId = {
  [USEROPT_INSTRUCTOR_ENABLED] = "instructor_enabled",
  [USEROPT_AUTOTRIM]           = "autotrim"
}

function fillUseroptHelpersModeSwitchboxDescr(optionId, descr, _context) {
  descr.id = descriptionOptionId[optionId]
  descr.controlType = optionControlType.CHECKBOX
  descr.controlName <- "switchbox"
  descr.defaultValue = getAircraftHelpersOptionValue(optionId)
}

let setUseroptHelpersModeGM = @(value, descr, _optionId) set_gui_option(USEROPT_HELPERS_MODE, descr.values[value])

registerOption(USEROPT_HELPERS_MODE, fillUseroptHelpersModeDescr, setUseroptHelpersMode)
registerOption(USEROPT_HELPERS_MODE_GM, fillUseroptHelpersModeGMDescr, setUseroptHelpersModeGM)
registerOption(USEROPT_MOUSE_USAGE, fillUseroptMouseUsageDescr, setUseroptHelpersMode)
registerOption(USEROPT_MOUSE_USAGE_NO_AIM, fillUseroptMouseUsageDescr, setUseroptHelpersMode)
registerOption(USEROPT_INSTRUCTOR_ENABLED, fillUseroptHelpersModeSwitchboxDescr, setUseroptHelpersMode)
registerOption(USEROPT_AUTOTRIM, fillUseroptHelpersModeSwitchboxDescr, setUseroptHelpersMode)

addListenersWithoutEnv({
  SignOut = @(_) isAircraftHelpersOptionsInitialized = false
  LoginComplete = @(_) onHelpersChanged()
  BeforeControlsCommit = @(_) onHelpersChanged()
  ControlsReloaded = @(_) onHelpersChanged(null, true)
})

return {
  controlHelpersOptions
  setAircraftHelpersOptionValue
  getAircraftHelpersOptionValue
}