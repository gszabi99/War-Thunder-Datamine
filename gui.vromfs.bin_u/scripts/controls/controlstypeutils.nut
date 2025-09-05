from "%scripts/dagui_library.nut" import *

let { save_profile } = require("chard")
let { is_android, is_xbox } = require("%sqstd/platform.nut")
let { ControlHelpersMode, setControlHelpersMode } = require("globalEnv")
let { isPlatformSony, isPlatformXbox, isPlatformSteamDeck, isPlatformShieldTv
} = require("%scripts/clientState/platform.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { set_option, get_option } = require("%scripts/options/optionsExt.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_HELPERS_MODE, USEROPT_CONTROLS_PRESET
} = require("%scripts/options/optionsExtNames.nut")
let { parseControlsPresetName, getHighestVersionControlsPreset
} = require("%scripts/controls/controlsPresets.nut")

function setHelpersModeAndOption(mode) { 
  set_option(USEROPT_HELPERS_MODE, mode) 
  setControlHelpersMode(mode); 
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
  ::apply_joy_preset_xchange(preset.fileName)

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

return {
  setHelpersModeAndOption
  setControlTypeByID
}