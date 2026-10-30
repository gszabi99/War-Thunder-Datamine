import "%sqStdLibs/helpers/enums.nut" as enums
from "%appGlobals/options/screenInfo.nut" import getMainScreenSizePx, getScreenHeightForFonts, getScreenWidth, getScreenHeight
from "%sqstd/platform.nut" import isSony, isXbox, is_steam_deck, is_windows
from "%appGlobals/clientState/platform.nut" import isPlatformShieldTv
from "%appGlobals/clientState/touchScreen.nut" import isSmallScreen
from "%globalScripts/systemConfig.nut" import getSystemConfigOption
from "math" import round
from "vr" import is_stereo_mode
from "guiScriptUtils" import is_steam_big_picture
from "dagor.system" import get_primary_screen_info
from "%globalScripts/logs.nut" import log

const FONTS_SAVE_PATH_CONFIG = "video/fonts"

function getDisplayScale() {
  if (!is_windows)
    return 1.0

  local horizDpi = null
  try{
    horizDpi = get_primary_screen_info()?.horizDpi
  }
  catch(e) {
    log("get_primary_screen_info failed", e)
  }
  if (horizDpi == null)
    return 1.0
  let scale = horizDpi / 96.0
  return scale > 1.0 ? scale : 1.0
}

enum FONT_SAVE_ID {
  TINY = "tiny"
  SMALL = "small"
  COMPACT = "compact"
  MEDIUM = "medium"
  LARGE = "big"
  HUGE = "huge"

  
  PX = "px"
  SCALE = "scale"

  
  PX_COMPATIBILITY = "%gui/const/const_pxFonts.css"
  SCALE_COMPATIBILITY = "%gui/const/const_fonts.css"
}

enum FONT_SIZE_ORDER {
  PX    
  TINY
  SMALL
  COMPACT
  MEDIUM
  LARGE
  SCALE  
  HUGE
}

let getFontsSh = getScreenHeightForFonts

let fontTypes = {
  types = []
  cache = { bySaveId = {} }
  template = {
    id = ""  
    fontGenId = ""
    saveId = ""
    saveIdCompatibility = null 
    sizeMultiplier = 1.0
    sizeOrder = 0 

    isAvailable = @(_sWidth, _sHeight) true
    getFontSizePx = @(sWidth, sHeight) round(this.sizeMultiplier * getFontsSh(sWidth, sHeight)).tointeger()
    isLowWidthScreen = function() {
      let sWidth = getScreenWidth()
      let sHeight = getScreenHeight()
      let mainScreenSize = getMainScreenSizePx(sWidth, sHeight)
      let sf = this.getFontSizePx(sWidth, sHeight)
      return 10.0 / 16 * mainScreenSize[0] / sf < 0.99
    }
  }
}

enums.enumsAddTypes(fontTypes,
{
  TINY = {
    saveId = FONT_SAVE_ID.TINY
    sizeMultiplier = 0.5
    sizeOrder = FONT_SIZE_ORDER.TINY

    isAvailable = @(sWidth, sHeight) !isSmallScreen && (is_stereo_mode() || getFontsSh(sWidth, sHeight) >= 800)
  }

  SMALL = {
    saveId = FONT_SAVE_ID.SMALL
    sizeMultiplier = 0.66667
    sizeOrder = FONT_SIZE_ORDER.SMALL

    isAvailable = @(sWidth, sHeight) !isSmallScreen && (is_stereo_mode() || getFontsSh(sWidth, sHeight) >= 768)
  }

  COMPACT = {
    saveId = FONT_SAVE_ID.COMPACT
    sizeMultiplier = 0.75
    sizeOrder = FONT_SIZE_ORDER.COMPACT

    isAvailable = @(sWidth, sHeight) !isSmallScreen && (is_stereo_mode() || getFontsSh(sWidth, sHeight) >= 720)
  }

  MEDIUM = {
    saveId = FONT_SAVE_ID.MEDIUM
    sizeMultiplier = 0.83334
    saveIdCompatibility = [FONT_SAVE_ID.PX]
    sizeOrder = FONT_SIZE_ORDER.MEDIUM

    isAvailable = @(sWidth, sHeight) !isSmallScreen && !is_stereo_mode() && getFontsSh(sWidth, sHeight) >= 720
  }

  LARGE = {
    saveId = FONT_SAVE_ID.LARGE
    sizeMultiplier = 1.0
    sizeOrder = FONT_SIZE_ORDER.LARGE
    saveIdCompatibility = [FONT_SAVE_ID.SCALE]
    isAvailable = @(_sWidth, _sHeight) !isSmallScreen && !is_stereo_mode()
  }

  HUGE = {
    saveId = FONT_SAVE_ID.HUGE
    sizeMultiplier = 1.5
    sizeOrder = FONT_SIZE_ORDER.HUGE

    isAvailable = @(_sWidth, _sHeight) isSmallScreen && !is_stereo_mode()
  }
},
null,
"id")

fontTypes.types.sortby(@(a) a.sizeOrder)

function getAvailableFontBySaveId(saveId) {
  let res = enums.enumsGetCachedType("saveId", saveId, fontTypes.cache.bySaveId, fontTypes, null)
  if (res && res.isAvailable(getScreenWidth(), getScreenHeight()))
    return res

  foreach (font in fontTypes.types)
    if (font.saveIdCompatibility
      && font.saveIdCompatibility.contains(saveId)
      && font.isAvailable(getScreenWidth(), getScreenHeight()))
      return font

  return null
}

function getAvailableFonts() {
  let sWidth = getScreenWidth()
  let sHeight = getScreenHeight()
  return fontTypes.types.filter(@(f) f.isAvailable(sWidth, sHeight))
}

function getFixedFont() { 
  let availableFonts = getAvailableFonts()
  return availableFonts.len() == 1 ? availableFonts[0] : null
}

function canChange() {
  return getFixedFont() == null
}

function getDefault() {
  let { SMALL, LARGE, MEDIUM, HUGE, COMPACT } = fontTypes
  let fixedFont = getFixedFont()
  if (fixedFont)
    return fixedFont

  if (is_stereo_mode())
    return SMALL
  if (isPlatformShieldTv() || isSony || isXbox || is_steam_big_picture())
    return LARGE
  if (isSmallScreen)
    return HUGE
  if (is_steam_deck)
    return MEDIUM

  let displayScale = getDisplayScale()
  let sWidth = getScreenWidth()
  let sHeight = getScreenHeight()
  if (displayScale <= 1.2 && COMPACT.isAvailable(sWidth, sHeight))
    return COMPACT
  if (displayScale <= 1.4 && MEDIUM.isAvailable(sWidth, sHeight))
    return MEDIUM
  return LARGE
}

function getPreLoginFontType() {
  let fontSaveId = getSystemConfigOption(FONTS_SAVE_PATH_CONFIG)
  return (fontSaveId && getAvailableFontBySaveId(fontSaveId)) || getDefault()
}

return freeze({
  FONTS_SAVE_PATH_CONFIG
  fontTypes
  getAvailableFontBySaveId
  getAvailableFonts
  canChange
  getDefault
  getPreLoginFontType
})
