from "%scripts/dagui_natives.nut" import fill_joysticks_desc, set_current_controls
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/rawShortcuts.nut" import SHORTCUT, GAMEPAD_ENTER_SHORTCUT

let { isPC } = require("%sqstd/platform.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { hasXInputDevice, isXInputDevice } = require("controls")
let { startsWith } = require("%sqstd/string.nut")
let { set_option, registerOption } = require("%scripts/options/optionsExt.nut")
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let optionsExtNames = require("%scripts/options/optionsExtNames.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_CONTROLS_PRESET } = optionsExtNames
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let ControlsPreset = require("%scripts/controls/controlsPreset.nut")
let { getCurControlsPreset, setCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { shortcutsList } = require("%scripts/controls/shortcutsList/shortcutsList.nut")
let { registerRespondent } = require("scriptRespondent")

let { getNullControlsPresetInfo, getControlsPresetsList, getControlsPresetFilename, parseControlsPresetName
} = require("%scripts/controls/controlsPresets.nut")

local isControlsCommitPerformed = false
let isLastLoadControlsSucceeded = Watched(false)

let fixesList = [
  {
    isAppend = true
    source = "ID_FLIGHTMENU"
    target = "ID_FLIGHTMENU_SETUP"
    value = [{
      deviceId = SHORTCUT.GAMEPAD_START.dev[0]
      buttonId = SHORTCUT.GAMEPAD_START.btn[0]
    }]
    shouldAppendIfEmptyOnXInput = true
  }
  {
    isAppend = true
    source = "ID_CONTINUE",
    target = "ID_CONTINUE_SETUP"
    value = [{
      deviceId = GAMEPAD_ENTER_SHORTCUT.dev[0]
      buttonId = GAMEPAD_ENTER_SHORTCUT.btn[0]
    }]
    shouldAppendIfEmptyOnXInput = true
  }
  {
    target = "ID_FLIGHTMENU"
    value = [[{
      deviceId = SHORTCUT.KEY_ESC.dev[0]
      buttonId = SHORTCUT.KEY_ESC.btn[0]
    }]]
  }
  {
    target = "ID_CONTINUE"
    valueFunction = function() {
      return [[isXInputDevice() ? {
        deviceId = GAMEPAD_ENTER_SHORTCUT.dev[0]
        buttonId = GAMEPAD_ENTER_SHORTCUT.btn[0] 
      } :
      {
        deviceId = SHORTCUT.KEY_SPACE.dev[0]
        buttonId = SHORTCUT.KEY_SPACE.btn[0]
      }]]
    }
  }
]

let hardcodedShortcuts = [
  {
    condition = function() { return isPC }
    list = [
      {
        name = "ID_SCREENSHOT",
        combo = [{
          deviceId = SHORTCUT.KEY_PRNT_SCRN.dev[0]
          buttonId = SHORTCUT.KEY_PRNT_SCRN.btn[0]
        }]
      }
    ]
  }
]

function fixDeviceMapping() {
  let realMapping = []

  let blkDeviceMapping = DataBlock()
  fill_joysticks_desc(blkDeviceMapping)

  eachBlock(blkDeviceMapping, @(blkJoy)
    realMapping.append({
      name          = blkJoy["name"]
      devId         = blkJoy["devId"]
      buttonsOffset = blkJoy["btnOfs"]
      buttonsCount  = blkJoy["btnCnt"]
      axesOffset    = blkJoy["axesOfs"]
      axesCount     = blkJoy["axesCnt"]
      connected     = !getTblValue("disconnected", blkJoy, false)
    }))

  if (getCurControlsPreset().updateDeviceMapping(realMapping))
    broadcastEvent("ControlsPresetChanged")
}

function setDefaultRelativeAxes() {
  let curPreset = getCurControlsPreset()
  foreach (shortcut in shortcutsList)
    if (shortcut.type == CONTROL_TYPE.AXIS && (shortcut?.isAbsOnlyWhenRealAxis ?? false)) {
      let axis = curPreset.getAxis(shortcut.id)
      if (axis.axisId == -1)
        axis.relative = true
    }
}

function fixControls() {
  let curPreset = getCurControlsPreset()
  foreach (fixData in fixesList) {
    let value = "valueFunction" in fixData ?
      fixData.valueFunction() : fixData.value
    if (getTblValue("isAppend", fixData)) {
      let isGamepadExpected =  isXInputDevice() || hasXInputDevice()
      if (curPreset.isHotkeyShortcutBinded(fixData.source, value)
          || (fixData.shouldAppendIfEmptyOnXInput
              && isGamepadExpected
              && curPreset.getHotkey(fixData.target).len() == 0))
        curPreset.addHotkeyShortcut(fixData.target, value)
    }
    else
      curPreset.setHotkey(fixData.target, value)
  }
  foreach (shortcutsGroup in hardcodedShortcuts)
    if (!("condition" in shortcutsGroup) || shortcutsGroup.condition())
      foreach (shortcut in shortcutsGroup.list)
        curPreset.removeHotkeyShortcut(shortcut.name, shortcut.combo)
  setDefaultRelativeAxes()
}

function restoreHardcodedKeys(maxShortcutCombinations) {
  let curPreset = getCurControlsPreset()
  foreach (shortcutsGroup in hardcodedShortcuts)
    if (!("condition" in shortcutsGroup) || shortcutsGroup.condition())
      foreach (shortcut in shortcutsGroup.list)
        if (curPreset.getHotkey(shortcut.name).len() < maxShortcutCombinations)
          curPreset.addHotkeyShortcut(shortcut.name, shortcut.combo)
}

function clearCurControlsPresetGuiOptions() {
  let prefix = "USEROPT_"
  let userOptTypes = []
  let curPreset = getCurControlsPreset()
  foreach (oType, _value in curPreset.params)
    if (startsWith(oType, prefix))
      userOptTypes.append(oType)
  foreach (oType in userOptTypes)
    curPreset.params.$rawdelete(oType)
}

function commitGuiOptions() {
  if (!isProfileReceived.get())
    return

  let mainOptionsMode = getGuiOptionsMode()
  setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)
  let prefix = "USEROPT_"
  let curPreset = getCurControlsPreset()
  foreach (oType, value in curPreset.params)
    if (startsWith(oType, prefix))
      if (oType in optionsExtNames)
        set_option(optionsExtNames[oType], value)
  setGuiOptionsMode(mainOptionsMode)
}


function commitControls() {
  if (isControlsCommitPerformed)
    return
  isControlsCommitPerformed = true

  fixControls()
  commitGuiOptions()

  
  broadcastEvent("BeforeControlsCommit")

  
  set_current_controls(getCurControlsPreset())

  clearCurControlsPresetGuiOptions()
  isControlsCommitPerformed = false
}

function setAndCommitCurControlsPreset(otherPreset) {
  log("ControlsManager: curPreset updated")
  setCurControlsPreset(otherPreset)
  fixDeviceMapping()
  broadcastEvent("ControlsReloaded")
  commitControls()
}

function controlsFixDeviceMapping() {
  fixDeviceMapping()
  commitControls()
}

function fillUseroptControlsPresetDescr(_optionId, descr, _context) {
  descr.id = "controls_preset"
  descr.items = []
  descr.values = getControlsPresetsList()
  descr.trParams <- "optionWidthInc:t='double';"

  if (!isPlatformSony && !isPlatformXbox)
    descr.values.insert(0, "") 
  let p = getCurControlsPreset()?.getBasePresetInfo()
    ?? getNullControlsPresetInfo()
  for (local k = 0; k < descr.values.len(); k++) {
    local name = descr.values[k]
    local suffix = isPlatformSony ? "ps4/" : ""
    let vPresetData = parseControlsPresetName(name)
    if (p.name == vPresetData.name && p.version == vPresetData.version)
      descr.value = k
    local imageName = "preset_joystick.svg"
    if (name.indexof("keyboard") != null)
      imageName = "preset_mouse_keyboard.svg"
    else if (name.indexof("xinput") != null || name.indexof("xboxone") != null)
      imageName = "preset_gamepad.svg"
    else if (name.indexof("default") != null || name.indexof("dualshock4") != null)
      imageName = "preset_ps4.svg"
    else if (name == "") {
      name = "custom"
      imageName = "preset_custom"
      suffix = ""
    }

    descr.items.append({
      text = $"#presets/{suffix}{name}"
      image = $"#ui/gameuiskin#{imageName}"
    })
  }
  descr.optionCb = "onSelectPreset"
  descr.skipOptContainerStyles <- true
}

function setUseroptControlsPreset(value, descr, _optionId) {
  if (descr.values[value] != "")
    ::apply_joy_preset_xchange(getControlsPresetFilename(descr.values[value]))
}

registerOption(USEROPT_CONTROLS_PRESET, fillUseroptControlsPresetDescr, setUseroptControlsPreset)

let sendEventControlsChangedToDarg = @() eventbus_send("controlsChanged")

addListenersWithoutEnv({
  
  
  function MissionStarted(_) {
    if (isPlatformSony)
      commitControls()
  }

  ControlsPresetChanged = @(_) sendEventControlsChangedToDarg()
  ControlsChangedShortcuts = @(_) sendEventControlsChangedToDarg()
  ControlsChangedAxes = @(_) sendEventControlsChangedToDarg()
})

eventbus_subscribe("controls_fix_device_mapping", @(_) controlsFixDeviceMapping())


function onLoadControls(blkOrPresetPath) {
  let otherPreset = ControlsPreset(blkOrPresetPath)
  if (otherPreset.isLoaded && otherPreset.hotkeys.len() > 0) {
    setAndCommitCurControlsPreset(otherPreset)
    isLastLoadControlsSucceeded.set(true)
  }
  else {
    log($"ControlsGlobals: Prevent setting incorrect preset: {blkOrPresetPath}")
    showInfoMsgBox($"{loc("msgbox/errorLoadingPreset")}: {blkOrPresetPath}")
    isLastLoadControlsSucceeded.set(false)
  }
}
registerRespondent("load_controls", onLoadControls)

return {
  restoreHardcodedKeys
  clearCurControlsPresetGuiOptions
  commitControls
  setAndCommitCurControlsPreset
  isLastLoadControlsSucceeded
}
