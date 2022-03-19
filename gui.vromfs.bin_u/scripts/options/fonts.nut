local enums = require("sqStdLibs/helpers/enums.nut")
local screenInfo = require("scripts/options/screenInfo.nut")
local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")
local { is_stereo_mode } = ::require_native("vr")
local { setFontDefHt, getFontDefHt, getFontInitialHt } = require("fonts")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local { isSmallScreen } = require("scripts/clientState/touchScreen.nut")

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
  PX_COMPATIBILITY = "gui/const/const_pxFonts.css"
  SCALE_COMPATIBILITY = "gui/const/const_fonts.css"
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

local getFontsSh = screenInfo.getScreenHeightForFonts

local appliedFontsSh = 0
local appliedFontsScale = 0

local function update_font_heights(font)
{
  local fontsSh = getFontsSh(::screen_width(), ::screen_height())
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
  getFontSizePx = @(sWidth, sHeight) ::round(sizeMultiplier * getFontsSh(sWidth, sHeight)).tointeger()
  getPixelToPixelFontSizeOutdatedPx = @(sWidth, sHeight) 800 //!!TODO: remove this together with old fonts
  isLowWidthScreen = function()
  {
    local sWidth = ::screen_width()
    local sHeight = ::screen_height()
    local mainScreenSize = screenInfo.getMainScreenSizePx(sWidth, sHeight)
    local sf = getFontSizePx(sWidth, sHeight)
    return 10.0 / 16 * mainScreenSize[0] / sf < 0.99
  }

  genCssString = function()
  {
    local sWidth = ::screen_width()
    local sHeight = ::screen_height()
    local config = {
      set = fontGenId
      scrnTgt = getFontSizePx(sWidth, sHeight)
      isWide = isLowWidthScreen() ? 0 : 1
      pxFontTgtOutdated = getPixelToPixelFontSizeOutdatedPx(sWidth, sHeight)
    }
    if (config.scrnTgt <= 0) {
      local configStr = ::toString(config) // warning disable: -declared-never-used
      ::script_net_assert_once("Bad screenTgt", "Bad screenTgt const at load fonts css")
    }
    foreach(prefixId in daguiFonts.getRealFontNamePrefixesMap())
      config[$"fontHeight_{prefixId}"] <- daguiFonts.getFontLineHeightPx(null, $"{prefixId}{fontGenId}")
    return ::handyman.renderCached("gui/const/const_fonts_css", config)
  }

  //text visible in options
  getOptionText = @() ::loc("fontSize/" + id.tolower())
    + ::loc("ui/parentheses/space", { text = "{0}%".subst(::round(100 * sizeMultiplier).tointeger()) })
  getFontExample = @() "small_text; font-pixht: {0}".subst(::round(getFontInitialHt("small_text") * sizeMultiplier).tointeger())
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

g_font.getAvailableFontBySaveId <- function getAvailableFontBySaveId(saveId)
{
  local res = enums.getCachedType("saveId", saveId, cache.bySaveId, this, null)
  if (res && res.isAvailable(::screen_width(), ::screen_height()))
    return res

  foreach(font in types)
    if (font.saveIdCompatibility
      && ::isInArray(saveId, font.saveIdCompatibility)
      && font.isAvailable(::screen_width(), ::screen_height()))
      return font

  return null
}

g_font.getAvailableFonts <- function getAvailableFonts()
{
  local sWidth = ::screen_width()
  local sHeight = ::screen_height()
  return ::u.filter(types, @(f) f.isAvailable(sWidth, sHeight))
}

g_font.getSmallestFont <- function getSmallestFont(sWidth, sHeight)
{
  local res = null
  foreach(font in types)
    if (font.isAvailable(sWidth, sHeight) && (!res || font.sizeMultiplier < res.sizeMultiplier))
      res = font
  return res
}

g_font.getFixedFont <- function getFixedFont() //return null if can change fonts
{
  local availableFonts = getAvailableFonts()
  return availableFonts.len() == 1 ? availableFonts[0] : null
}

g_font.canChange <- function canChange()
{
  return getFixedFont() == null
}

g_font.getDefault <- function getDefault()
{
  local fixedFont = getFixedFont()
  if (fixedFont)
    return fixedFont

  if (is_stereo_mode())
    return SMALL
  if (::is_platform_shield_tv() || isPlatformSony || isPlatformXboxOne || ::is_steam_big_picture())
    return LARGE
  if (isSmallScreen)
    return HUGE

  local displayScale = ::display_scale()
  local sWidth = ::screen_width()
  local sHeight = ::screen_height()
  if (displayScale <= 1.2 && COMPACT.isAvailable(sWidth, sHeight))
    return COMPACT
  if (displayScale <= 1.4 && MEDIUM.isAvailable(sWidth, sHeight))
    return MEDIUM
  return LARGE
}

g_font.getCurrent <- function getCurrent()
{
  if (!canChange())
    return update_font_heights(getDefault())

  if (!::g_login.isProfileReceived())
  {
    local fontSaveId = ::getSystemConfigOption(FONTS_SAVE_PATH_CONFIG)
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

//return isChanged
g_font.setCurrent <- function setCurrent(font)
{
  if (!canChange())
    return false

  local fontSaveId = ::load_local_account_settings(FONTS_SAVE_PATH)
  local isChanged = font.saveId != fontSaveId
  if (isChanged)
    ::save_local_account_settings(FONTS_SAVE_PATH, font.saveId)

  saveFontToConfig(font)
  update_font_heights(font)
  return isChanged
}

g_font.saveFontToConfig <- function saveFontToConfig(font)
{
  if (::getSystemConfigOption(FONTS_SAVE_PATH_CONFIG) != font.saveId)
    ::setSystemConfigOption(FONTS_SAVE_PATH_CONFIG, font.saveId)
}

g_font.validateSavedConfigFonts <- function validateSavedConfigFonts()
{
  if (canChange())
    saveFontToConfig(getCurrent())
}

::reset_applied_fonts_scale <- function reset_applied_fonts_scale()
{
  ::dagor.debug("[fonts] Resetting appliedFontsSh, sizes of font will be set again")
  appliedFontsSh = 0;
  update_font_heights(g_font.getCurrent());
}

::cross_call_api.getCurrentFontParams <- function() {
  local currentFont = ::g_font.getCurrent()
  return {
    fontGenId = currentFont.fontGenId
    fontSizePx = currentFont.getFontSizePx(::screen_width(), ::screen_height())
  }
}