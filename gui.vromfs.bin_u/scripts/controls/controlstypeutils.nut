from "%scripts/dagui_library.nut" import *

let { save_profile } = require("chard")
let { is_android, is_xbox, isPC, isPS4, isSony, isXbox } = require("%sqstd/platform.nut")
let { ControlHelpersMode, setControlHelpersMode } = require("globalEnv")
let { isPlatformSony, isPlatformXbox, isPlatformSteamDeck, isPlatformShieldTv
} = require("%scripts/clientState/platform.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { set_option, get_option, registerOption } = require("%scripts/options/optionsExt.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_HELPERS_MODE, USEROPT_CONTROLS_PRESET
} = require("%scripts/options/optionsExtNames.nut")
let { parseControlsPresetName, getHighestVersionControlsPreset,
  getNullControlsPresetInfo, getControlsPresetsList, getControlsPresetFilename
} = require("%scripts/controls/controlsPresets.nut")
let ControlsPreset = require("%scripts/controls/controlsPreset.nut")
let { joystickGetCurSettings, getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { restoreShortcuts } = require("%scripts/controls/shortcutsUtils.nut")
let { switchShowConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { getCurrentHelpersMode } = require("%scripts/controls/aircraftHelpers.nut")
let { setAndCommitCurControlsPreset } = require("%scripts/controls/controlsManager.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")

function setHelpersModeAndOption(mode) { 
  set_option(USEROPT_HELPERS_MODE, mode) 
  setControlHelpersMode(mode); 
}

function switchHelpersModeAndOption(preset = "") {
  let joyCurSettings = joystickGetCurSettings()
  if (joyCurSettings.useMouseAim)
    setHelpersModeAndOption(ControlHelpersMode.EM_MOUSE_AIM)
  else if (isPS4 && preset == getControlsPresetFilename("thrustmaster_hotas4")) {
    if (getCurrentHelpersMode() == ControlHelpersMode.EM_MOUSE_AIM)
      setHelpersModeAndOption(ControlHelpersMode.EM_INSTRUCTOR)
  }
  else if (isSony || isXbox || isPlatformShieldTv())
    setHelpersModeAndOption(ControlHelpersMode.EM_REALISTIC)
  else if (getCurrentHelpersMode() == ControlHelpersMode.EM_MOUSE_AIM)
    setHelpersModeAndOption(ControlHelpersMode.EM_INSTRUCTOR)
}

let shortcutsNotChangeByPreset = [
  "ID_INTERNET_RADIO",
  "ID_INTERNET_RADIO_PREV",
  "ID_INTERNET_RADIO_NEXT",
  "ID_PTT"
]

function applyJoyPresetXchange(preset, updateHelpersMode = true) {
  if (!preset || preset == "")
    return

  let scToRestore = getShortcuts(shortcutsNotChangeByPreset)
  setAndCommitCurControlsPreset(ControlsPreset(preset))
  restoreShortcuts(scToRestore, shortcutsNotChangeByPreset)

  if (isPC)
    switchShowConsoleButtons(preset.indexof("xinput") != null)

  if (updateHelpersMode)
    switchHelpersModeAndOption(preset)

  saveProfile()
}

function setControlTypeByID(ct_id) {
  let mainOptionsMode = getGuiOptionsMode()
  setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

  local ct_preset = ""
  if (ct_id == "ct_own") {
    
    ct_preset = "keyboard"
    setHelpersModeAndOption(ControlHelpersMode.EM_INSTRUCTOR)
    save_profile(false)
    return
  }
  else if (ct_id == "ct_xinput") {
    ct_preset = "pc_xinput_ma"
    if (is_android || isPlatformShieldTv())
      ct_preset = "tegra4_gamepad"
    setHelpersModeAndOption(ControlHelpersMode.EM_INSTRUCTOR)
  }
  else if (ct_id == "ct_mouse") {
    ct_preset = ""
    if (is_android)
      ct_preset = "tegra4_gamepad";
    setHelpersModeAndOption(ControlHelpersMode.EM_MOUSE_AIM)
  }

  local preset = null

  if (ct_preset != "")
    preset = parseControlsPresetName(ct_preset)
  else if (ct_id == "ct_mouse") {
    if (isPlatformSony)
      preset = parseControlsPresetName("dualshock4")
    else if (is_xbox)
      preset = parseControlsPresetName("xboxone_ma")
    else if (isPlatformSteamDeck)
      preset = parseControlsPresetName("steamdeck_ma")
    else
      preset = parseControlsPresetName("keyboard_shooter")
  }
  preset = getHighestVersionControlsPreset(preset)
  applyJoyPresetXchange(preset.fileName)

  if (isPlatformSony || isPlatformXbox || isPlatformSteamDeck) {
    let presetMode = get_option(USEROPT_CONTROLS_PRESET)
    ct_preset = parseControlsPresetName(presetMode.values[presetMode.value])
    
    local realisticPresetNames = ["default", "xboxone_simulator", "stimdeck_simulator"]
    local mouseAimPresetNames = ["dualshock4", "xboxone_ma", "stimdeck_ma"]
    if (ct_preset.name in realisticPresetNames)
      setHelpersModeAndOption(ControlHelpersMode.EM_REALISTIC)
    else if (ct_preset.name in mouseAimPresetNames)
      setHelpersModeAndOption(ControlHelpersMode.EM_MOUSE_AIM)
  }

  save_profile(false)

  setGuiOptionsMode(mainOptionsMode)
}

function fillUseroptControlsPresetDescr(_optionId, descr, _context) {
  descr.id = "controls_preset"
  descr.items = []
  descr.values = getControlsPresetsList()
  descr.trParams <- "optionWidthInc:t='double';"

  if (!isSony && !isXbox)
    descr.values.insert(0, "") 
  let p = getCurControlsPreset()?.getBasePresetInfo()
    ?? getNullControlsPresetInfo()
  for (local k = 0; k < descr.values.len(); k++) {
    local name = descr.values[k]
    local suffix = isSony ? "ps4/" : ""
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
    applyJoyPresetXchange(getControlsPresetFilename(descr.values[value]))
}

registerOption(USEROPT_CONTROLS_PRESET, fillUseroptControlsPresetDescr, setUseroptControlsPreset)

return {
  setHelpersModeAndOption
  setControlTypeByID
  applyJoyPresetXchange
}