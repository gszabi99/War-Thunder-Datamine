//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")

let contentPresets = []
local contentPresetIdxByName = {}

const AGREED_PRESET_SAVE_ID_PREFIX = "contentPreset/agreed"

let function getContentPresets() {
  if (contentPresets.len() > 0 || !::g_login.isLoggedIn())
    return contentPresets

  eachBlock(::get_ugc_blk()?.presets, @(_, n) contentPresets.append(n))

  contentPresetIdxByName = u.invert(contentPresets)
  return contentPresets
}

let function getDifficultyByOptionId(optionId) {
  foreach (difficulty in ::g_difficulty.types)
    if (difficulty.contentAllowedPresetOption == optionId)
      return difficulty
  return ::g_difficulty.UNKNOWN
}

let function getCurPresetId(diffCode) {
  let optionId = ::g_difficulty.getDifficultyByDiffCode(diffCode).contentAllowedPresetOption
  let option = ::get_option(optionId)
  let defValue = option.value in option.values ? option.values[option.value] : "historical"
  return ::get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY, defValue)
}

let function getAgreedPreset(diffCode) {
  let saveId = AGREED_PRESET_SAVE_ID_PREFIX + diffCode
  let difficulty = ::g_difficulty.getDifficultyByDiffCode(diffCode)
  return loadLocalAccountSettings(saveId, difficulty.contentAllowedPresetOptionDefVal)
}

let function setAgreedPreset(diffCode, presetId) {
  let saveId = AGREED_PRESET_SAVE_ID_PREFIX + diffCode
  saveLocalAccountSettings(saveId, presetId)
}

let function setPreset(diffCode, presetId, needSetAgreed) {
  if (!presetId)
    return
  let optionId = ::g_difficulty.getDifficultyByDiffCode(diffCode).contentAllowedPresetOption
  ::set_gui_option_in_mode(optionId, presetId, OPTIONS_MODE_GAMEPLAY)
  if (needSetAgreed)
    setAgreedPreset(diffCode, presetId)
}

let function getPresetIdBySkin(diffCode, unitId, skinId) {
  return ::get_preset_by_skin_tags(diffCode, unitId, skinId) || getCurPresetId(diffCode)
}

let function isAgreed(diffCode, presetId) {
    let agreedPresetId = getAgreedPreset(diffCode)
    return !(agreedPresetId in contentPresetIdxByName) || !(presetId in contentPresetIdxByName) ||
      contentPresetIdxByName[agreedPresetId] >= contentPresetIdxByName[presetId]
}

return {
  getContentPresets = getContentPresets
  getDifficultyByOptionId = getDifficultyByOptionId
  getCurPresetId = getCurPresetId
  setPreset = setPreset
  getPresetIdBySkin = getPresetIdBySkin
  isAgreed = isAgreed
}
