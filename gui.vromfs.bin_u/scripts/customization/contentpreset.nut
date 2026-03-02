from "%scripts/dagui_natives.nut" import get_ugc_blk, get_preset_by_skin_tags
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY,
  USEROPT_CONTENT_ALLOWED_PRESET_ARCADE, USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC,
  USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR, USEROPT_CONTENT_ALLOWED_PRESET

let { g_difficulty } = require("%scripts/difficulty.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { get_gui_option_in_mode, set_gui_option_in_mode } = require("%scripts/options/options.nut")
let { set_gui_option } = require("guiOptions")
let { get_option, registerOption } = require("%scripts/options/optionsExt.nut")

let contentPresets = []
local contentPresetIdxByName = {}

const AGREED_PRESET_SAVE_ID_PREFIX = "contentPreset/agreed"

function getContentPresets() {
  if (contentPresets.len() > 0 || !isLoggedIn.get())
    return contentPresets

  eachBlock(get_ugc_blk()?.presets, @(_, n) contentPresets.append(n))

  contentPresetIdxByName = u.invert(contentPresets)
  return contentPresets
}

function getDifficultyByOptionId(optionId) {
  foreach (difficulty in g_difficulty.types)
    if (difficulty.contentAllowedPresetOption == optionId)
      return difficulty
  return g_difficulty.UNKNOWN
}

function getCurPresetId(diffCode) {
  let optionId = g_difficulty.getDifficultyByDiffCode(diffCode).contentAllowedPresetOption
  let option = get_option(optionId)
  let defValue = option.value in option.values ? option.values[option.value] : "historical"
  return get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY, defValue)
}

function getAgreedPreset(diffCode) {
  let saveId = $"{AGREED_PRESET_SAVE_ID_PREFIX}{diffCode}"
  let difficulty = g_difficulty.getDifficultyByDiffCode(diffCode)
  return loadLocalAccountSettings(saveId, difficulty.contentAllowedPresetOptionDefVal)
}

function setAgreedPreset(diffCode, presetId) {
  let saveId = $"{AGREED_PRESET_SAVE_ID_PREFIX}{diffCode}"
  saveLocalAccountSettings(saveId, presetId)
}

function setPreset(diffCode, presetId, needSetAgreed) {
  if (!presetId)
    return
  let optionId = g_difficulty.getDifficultyByDiffCode(diffCode).contentAllowedPresetOption
  set_gui_option_in_mode(optionId, presetId, OPTIONS_MODE_GAMEPLAY)
  if (needSetAgreed)
    setAgreedPreset(diffCode, presetId)
}

function getPresetIdBySkin(diffCode, unitId, skinId) {
  return get_preset_by_skin_tags(diffCode, unitId, skinId) || getCurPresetId(diffCode)
}

function isAgreed(diffCode, presetId) {
    let agreedPresetId = getAgreedPreset(diffCode)
    return !(agreedPresetId in contentPresetIdxByName) || !(presetId in contentPresetIdxByName) ||
      contentPresetIdxByName[agreedPresetId] >= contentPresetIdxByName[presetId]
}

function fillContentAllowedPreset(optionId, descr, _context) {
  let difficulty = getDifficultyByOptionId(optionId)
  descr.defaultValue = difficulty.contentAllowedPresetOptionDefVal
  descr.id = "content_allowed_preset"
  descr.title = loc("options/content_allowed_preset")
  if (difficulty != g_difficulty.UNKNOWN) {
    descr.id = $"{descr.id}{difficulty.diffCode}"
    descr.title = "".concat(descr.title, loc("ui/parentheses/space", { text = loc(difficulty.locId) }))
  }
  descr.hint  = loc("guiHints/content_allowed_preset")
  descr.controlType = optionControlType.LIST
  descr.controlName <- "combobox"
  descr.items = []
  descr.values = []
  foreach (value in getContentPresets()) {
    descr.items.append(loc($"content/tag/{value}"))
    descr.values.append(value)
  }
}

function setContentAllowedPreset(value, descr, optionId) {
  if (descr.controlType == optionControlType.LIST) {
    if (type(descr.values) != "array")
      return
    if (value < 0 || value >= descr.values.len())
      return
    set_gui_option(optionId, descr.values[value])
  }
  else if (descr.controlType == optionControlType.CHECKBOX) {
    if (u.isBool(value))
      set_gui_option(optionId, value)
  }
}

registerOption(USEROPT_CONTENT_ALLOWED_PRESET_ARCADE, fillContentAllowedPreset, setContentAllowedPreset)
registerOption(USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC, fillContentAllowedPreset, setContentAllowedPreset)
registerOption(USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR, fillContentAllowedPreset, setContentAllowedPreset)
registerOption(USEROPT_CONTENT_ALLOWED_PRESET, fillContentAllowedPreset, setContentAllowedPreset)

return {
  getContentPresets = getContentPresets
  getDifficultyByOptionId = getDifficultyByOptionId
  getCurPresetId = getCurPresetId
  setPreset = setPreset
  getPresetIdBySkin = getPresetIdBySkin
  isAgreed = isAgreed
}
