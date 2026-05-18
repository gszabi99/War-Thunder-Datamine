from "%scripts/dagui_library.nut" import *
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { is_sound_mods_banks_check_failed = null } = require("soundModCheck")

local onLoadValue = null

const ENABLE_MOD_PARAMETR_NAME = "sound/enable_mod"

let isEnabledCustomSoundMods = @() getSystemConfigOption(ENABLE_MOD_PARAMETR_NAME, false) && (is_sound_mods_banks_check_failed == null || !is_sound_mods_banks_check_failed())

function isUsedCustomSoundMods() {
  if(onLoadValue == null)
    onLoadValue = isEnabledCustomSoundMods()
  return onLoadValue
}

let setCustomSoundMods = @(value) setSystemConfigOption(ENABLE_MOD_PARAMETR_NAME, value)

let hasCustomSoundMods = @() getSystemConfigOption(ENABLE_MOD_PARAMETR_NAME) != null

return {
  isUsedCustomSoundMods
  isEnabledCustomSoundMods
  setCustomSoundMods
  hasCustomSoundMods
}