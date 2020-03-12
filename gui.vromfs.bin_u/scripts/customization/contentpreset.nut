local contentPresets = []
local contentPresetIdxByName = {}
local defaultPresetIdx = -1

const AGREED_PRESET_SAVE_ID_PREFIX = "contentPreset/agreed"

local function getContentPresets() {
  if (contentPresets.len() > 0 || !::g_login.isLoggedIn())
    return contentPresets

  local blk = ::get_ugc_blk()
  if (blk?.presets)
    foreach(preset in blk.presets)
      contentPresets.append(preset.getBlockName())

  contentPresetIdxByName = u.invert(contentPresets)
  defaultPresetIdx = contentPresets.len()-1
  return contentPresets
}

local function getDifficultyByOptionId(optionId) {
  foreach (difficulty in ::g_difficulty.types)
    if (difficulty.contentAllowedPresetOption == optionId)
      return difficulty
  return ::g_difficulty.UNKNOWN
}

local function getCurPresetId(diffCode) {
  local optionId = ::g_difficulty.getDifficultyByDiffCode(diffCode).contentAllowedPresetOption
  local option = ::get_option(optionId)
  local defValue = option.value in option.values? option.values[option.value] : "historical"
  return ::get_gui_option_in_mode(optionId, ::OPTIONS_MODE_GAMEPLAY, defValue)
}

local function getAgreedPreset(diffCode) {
  local saveId = AGREED_PRESET_SAVE_ID_PREFIX + diffCode
  local difficulty = ::g_difficulty.getDifficultyByDiffCode(diffCode)
  return ::load_local_account_settings(saveId, difficulty.contentAllowedPresetOptionDefVal)
}

local function setAgreedPreset(diffCode, presetId) {
  local saveId = AGREED_PRESET_SAVE_ID_PREFIX + diffCode
  ::save_local_account_settings(saveId, presetId)
}

local function setPreset(diffCode, presetId, needSetAgreed) {
  if (!presetId)
    return
  local optionId = ::g_difficulty.getDifficultyByDiffCode(diffCode).contentAllowedPresetOption
  ::set_gui_option_in_mode(optionId, presetId, ::OPTIONS_MODE_GAMEPLAY)
  if (needSetAgreed)
    setAgreedPreset(diffCode, presetId)
}

local function getPresetIdBySkin(diffCode, unitId, skinId) {
  return ::get_preset_by_skin_tags(diffCode, unitId, skinId) || getCurPresetId(diffCode)
}

local function isAgreed(diffCode, presetId) {
    local agreedPresetId = getAgreedPreset(diffCode)
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
