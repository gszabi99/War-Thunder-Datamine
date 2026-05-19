from "%scripts/dagui_library.nut" import *
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")

local onLoadValue = null

const ENABLE_MOD_PARAMETR_NAME = "sound/enable_mod"

let isEnabledCustomSoundMods = @() getSystemConfigOption(ENABLE_MOD_PARAMETR_NAME, false)

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