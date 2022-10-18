let enums = require("%sqStdLibs/helpers/enums.nut")
let screenInfo = require("%scripts/options/screenInfo.nut")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let { is_stereo_mode } = ::require_native("vr")
let { setFontDefHt, getFontDefHt, getFontInitialHt } = require("fonts")
let { isPlatformSony, isPlatformXboxOne, isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")

const FONTS_SAVE_PATH = "fonts_css"
const FONTS_SAVE_PATH_CONFIG = "video/fonts"

enum FONT_SAVE_ID {
  TINY = "tiny"
  SMALL = "small"
  COMPACT = "compact"
  MEDIUM = "medium"
  LARGE = "big"
  HUGE = "huge"

  //wop_1_69_3_x fonts
  PX = "px"
  SCALE = "scale"

  //wop_1_69_3_X
  PX_COMPATIBILITY = "%gui/const/const_pxFonts.css"
  SCALE_COMPATIBILITY = "%gui/const/const_fonts.css"
}

enum FONT_SIZE_ORDER {
  PX    //wop_1_69_3_X
  TINY
  SMALL
  COMPACT
  MEDIUM
  LARGE
  SCALE  //wop_1_69_3_X
  HUGE
}

let getFontsSh = screenInfo.getScreenHeightForFonts

local appliedFontsSh = 0
local appliedFontsScale = 0

let function update_font_heights(font)
{
  let fontsSh = getFontsSh(::screen_width(), ::screen_height())
  if (appliedFontsSh == fontsSh && appliedFontsScale == font.sizeMultiplier)
    return font;
  ::dagor.debug("update_font_heights: screenHt={0} fontSzMul={1}".subst(fontsSh, font.sizeMultiplier))
  foreach(prefixId in daguiFonts.getRealFontNamePrefixesMap())
  {
    setFontDefHt(prefixId, ::round(getFontInitialHt(prefixId) * font.sizeMultiplier).tointeger())
    ::dagor.debug("  font <{0}> sz={1}".subst(prefixId, getFontDefHt(prefixId)))
  }
  appliedFontsSh = fontsSh
  appliedFontsScale = font.sizeMultiplier
  return font;
}

::g_font <- {
  types = []
  cache = { bySaveId = {} }
}

::g_font.template <- {
  id = ""  //by type name
  fontGenId = ""
  saveId = ""
  saveIdCompatibility = null //array of ids. need to easy switch between fonts by feature
  isScaleable = true
  sizeMultiplier = 1.0
  sizeOrder = 0 //FONT_SIZE_ORDER

  isAvailable = @(sWidth, sHeight) true
  getFontSizePx = @(sWidth, sHeight) ::round(this.sizeMultiplier * getFontsSh(sWidth, sHeight)).tointeger()
  getPixelToPixelFontSizeOutdatedPx = @(sWidth, sHeight) 800 //!!TODO: remove this together with old fonts
  isLowWidthScreen = function()
  {
    let sWidth = ::screen_width()
    let sHeight = ::screen_height()
    let mainScreenSize = screenInfo.getMainScreenSizePx(sWidth, sHeight)
    let sf = this.getFontSizePx(sWidth, sHeight)
    return 10.0 / 16 * mainScreenSize[0] / sf < 0.99
  }

  genCssString = function()
  {
    let sWidth = ::screen_width()
    let sHeight = ::screen_height()
    let config = {
      set = this.fontGenId
      scrnTgt = this.getFontSizePx(sWidth, sHeight)
      isWide = this.isLowWidthScreen() ? 0 : 1
      pxFontTgtOutdated = this.getPixelToPixelFontSizeOutdatedPx(sWidth, sHeight)
    }
    if (config.scrnTgt <= 0) {
      let configStr = ::toString(config) // warning disable: -declared-never-used
      ::script_net_assert_once("Bad screenTgt", "Bad screenTgt const at load fonts css")
    }
    foreach(prefixId in daguiFonts.getRealFontNamePrefixesMap())
      config[$"fontHeight_{prefixId}"] <- daguiFonts.getFontLineHeightPx(null, $"{prefixId}{this.fontGenId}")
    return ::handyman.renderCached("%gui/const/const_fonts_css", config)
  }

  //text visible in options
  getOptionText = @() ::loc("fontSize/" + this.id.tolower())
    + ::loc("ui/parentheses/space", { text = "{0}%".subst(::round(100 * this.sizeMultiplier).tointeger()) })
  getFontExample = @() "small_text; font-pixht: {0}".subst(::round(getFontInitialHt("small_text") * this.sizeMultiplier).tointeger())
}

enums.addTypesByGlobalName("g_font",
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
    isAvailable = @(sWidth, sHeight) !isSmallScreen && !is_stereo_mode()
  }

  HUGE = {
    saveId = FONT_SAVE_ID.HUGE
    sizeMultiplier = 1.5
    sizeOrder = FONT_SIZE_ORDER.HUGE

    isAvailable = @(sWidth, sHeight) isSmallScreen && !is_stereo_mode()
  }
},
null,
"id")

::g_font.types.sort(@(a, b) a.sizeOrder <=> b.sizeOrder)

let function getAvailableFontBySaveId(saveId) {
  let res = enums.getCachedType("saveId", saveId, ::g_font.cache.bySaveId, ::g_font, null)
  if (res && res.isAvailable(::screen_width(), ::screen_height()))
    return res

  foreach(font in ::g_font.types)
    if (font.saveIdCompatibility
      && ::isInArray(saveId, font.saveIdCompatibility)
      && font.isAvailable(::screen_width(), ::screen_height()))
      return font

  return null
}

::g_font.getAvailableFonts <- function getAvailableFonts()
{
  let sWidth = ::screen_width()
  let sHeight = ::screen_height()
  return ::u.filter(this.types, @(f) f.isAvailable(sWidth, sHeight))
}

::g_font.getSmallestFont <- function getSmallestFont(sWidth, sHeight)
{
  local res = null
  foreach(font in this.types)
    if (font.isAvailable(sWidth, sHeight) && (!res || font.sizeMultiplier < res.sizeMultiplier))
      res = font
  return res
}

::g_font.getFixedFont <- function getFixedFont() //return null if can change fonts
{
  let availableFonts = this.getAvailableFonts()
  return availableFonts.len() == 1 ? availableFonts[0] : null
}

let function canChange() {
  return ::g_font.getFixedFont() == null
}

let function getDefault()
{
  let {getFixedFont, SMALL, LARGE, MEDIUM, HUGE, COMPACT} = ::g_font //-ident-hides-ident
  let fixedFont = getFixedFont()
  if (fixedFont)
    return fixedFont

  if (is_stereo_mode())
    return SMALL
  if (::is_platform_shield_tv() || isPlatformSony || isPlatformXboxOne || ::is_steam_big_picture())
    return LARGE
  if (isSmallScreen)
    return HUGE
  if (isPlatformSteamDeck)
    return MEDIUM

  let displayScale = ::display_scale()
  let sWidth = ::screen_width()
  let sHeight = ::screen_height()
  if (displayScale <= 1.2 && COMPACT.isAvailable(sWidth, sHeight))
    return COMPACT
  if (displayScale <= 1.4 && MEDIUM.isAvailable(sWidth, sHeight))
    return MEDIUM
  return LARGE
}

::g_font.getCurrent <- function getCurrent()
{
  if (!canChange())
    return update_font_heights(getDefault())

  if (!::g_login.isProfileReceived())
  {
    let fontSaveId = ::getSystemConfigOption(FONTS_SAVE_PATH_CONFIG)
    return update_font_heights((fontSaveId && getAvailableFontBySaveId(fontSaveId))
      || getDefault())
  }

  local fontSaveId = ::load_local_account_settings(FONTS_SAVE_PATH)
  local res = getAvailableFontBySaveId(fontSaveId)
  if (!res) //compatibility with 1.77.0.X
  {
    fontSaveId = ::loadLocalByScreenSize(FONTS_SAVE_PATH)
    if (fontSaveId)
    {
      res = getAvailableFontBySaveId(fontSaveId)
      if (res)
        ::save_local_account_settings(FONTS_SAVE_PATH, fontSaveId)
      ::clear_local_by_screen_size(FONTS_SAVE_PATH)
    }
  }
  return update_font_heights(res || getDefault())
}

let function saveFontToConfig(font) {
  if (::getSystemConfigOption(FONTS_SAVE_PATH_CONFIG) != font.saveId)
    ::setSystemConfigOption(FONTS_SAVE_PATH_CONFIG, font.saveId)
}

//return isChanged
::g_font.setCurrent <- function setCurrent(font)
{
  if (!canChange())
    return false

  let fontSaveId = ::load_local_account_settings(FONTS_SAVE_PATH)
  let isChanged = font.saveId != fontSaveId
  if (isChanged)
    ::save_local_account_settings(FONTS_SAVE_PATH, font.saveId)

  saveFontToConfig(font)
  update_font_heights(font)
  return isChanged
}


::g_font.validateSavedConfigFonts <- function validateSavedConfigFonts()
{
  if (canChange())
    saveFontToConfig(this.getCurrent())
}

::reset_applied_fonts_scale <- function reset_applied_fonts_scale()
{
  ::dagor.debug("[fonts] Resetting appliedFontsSh, sizes of font will be set again")
  appliedFontsSh = 0;
  update_font_heights(::g_font.getCurrent());
}

::cross_call_api.getCurrentFontParams <- function() {
  let currentFont = ::g_font.getCurrent()
  return {
    fontGenId = currentFont.fontGenId
    fontSizePx = currentFont.getFontSizePx(::screen_width(), ::screen_height())
  }
}