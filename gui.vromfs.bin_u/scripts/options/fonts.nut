import "%appGlobals/style/fontIds.nut" as fontIds
from "%appGlobals/options/screenInfo.nut" import getScreenHeightForFonts
from "%appGlobals/options/fontTypes.nut" import FONTS_SAVE_PATH_CONFIG, fontTypes, getAvailableFontBySaveId, getAvailableFonts, canChange, getDefault, getPreLoginFontType
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%globalScripts/systemConfig.nut" import getSystemConfigOption, setSystemConfigOption
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "math" import round
from "vr" import is_stereo_mode
from "fonts" import setFontDefHt, getFontDefHt, getFontInitialHt
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

const FONTS_SAVE_PATH = "fonts_css"
const FONTS_SAVE_PATH_VR = "fonts_css_vr"

let getFontsSavePath = @() is_stereo_mode() ? FONTS_SAVE_PATH_VR : FONTS_SAVE_PATH

local appliedFontsSh = 0
local appliedFontsScale = 0

function update_font_heights(font) {
  let fontsSh = getScreenHeightForFonts(screen_width(), screen_height())
  if (appliedFontsSh == fontsSh && appliedFontsScale == font.sizeMultiplier)
    return font;
  log("update_font_heights: screenHt={0} fontSzMul={1}".subst(fontsSh, font.sizeMultiplier))
  foreach (prefixId in fontIds) {
    setFontDefHt(prefixId, round(getFontInitialHt(prefixId) * font.sizeMultiplier).tointeger())
    log("  font <{0}> sz={1}".subst(prefixId, getFontDefHt(prefixId)))
  }
  appliedFontsSh = fontsSh
  appliedFontsScale = font.sizeMultiplier
  return font;
}

let optionTexts = {
  
  getOptionText = @() "".concat(
    loc($"fontSize/{this.id.tolower()}"),
    loc("ui/parentheses/space", { text = "{0}%".subst(round(100 * this.sizeMultiplier).tointeger()) }))

  getFontExampleHt = @() round(getFontInitialHt("small_text") * this.sizeMultiplier).tointeger()
  getFontExample = @() "small_text; font-pixht: {0}".subst(this.getFontExampleHt())
}

foreach (font in fontTypes.types)
  font.__update(optionTexts)

function getSmallestFont(sWidth, sHeight) {
  local res = null
  foreach (font in fontTypes.types)
    if (font.isAvailable(sWidth, sHeight) && (!res || font.sizeMultiplier < res.sizeMultiplier))
      res = font
  return res
}

function getCurrentFontType() {
  if (!canChange())
    return update_font_heights(getDefault())

  if (!isProfileReceived.get())
    return update_font_heights(getPreLoginFontType())

  let fontSaveId = loadLocalAccountSettings(getFontsSavePath())
  let res = getAvailableFontBySaveId(fontSaveId)
  return update_font_heights(res || getDefault())
}

function saveFontToConfig(font) {
  if (getSystemConfigOption(FONTS_SAVE_PATH_CONFIG) != font.saveId)
    setSystemConfigOption(FONTS_SAVE_PATH_CONFIG, font.saveId)
}


function setCurrentFontType(font) {
  if (!canChange())
    return false

  let savePath = getFontsSavePath()
  let fontSaveId = loadLocalAccountSettings(savePath)
  let isChanged = font.saveId != fontSaveId
  if (isChanged)
    saveLocalAccountSettings(savePath, font.saveId)

  saveFontToConfig(font)
  update_font_heights(font)
  return isChanged
}


function validateSavedConfigFonts() {
  if (canChange())
    saveFontToConfig(getCurrentFontType())
}

function resetAppliedFontsScale(_) {
  log("[fonts] Resetting appliedFontsSh, sizes of font will be set again")
  appliedFontsSh = 0;
  update_font_heights(getCurrentFontType())
}

eventbus_subscribe("reset_applied_fonts_scale", resetAppliedFontsScale)

return freeze({
  fontTypes
  getAvailableFonts
  getCurrentFontType
  setCurrentFontType
  getFontsSavePath
  getSmallestFont
  validateSavedConfigFonts
})
