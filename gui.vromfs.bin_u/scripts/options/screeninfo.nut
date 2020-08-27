local function isTripleHead(sw = null, sh = null)
{
  if ("is_triple_head" in ::getroottable()) // Temporary compatibility with 1.89.1.X and older.
    return false

  sw = sw ?? ::screen_width()
  sh = sh ?? ::screen_height()
  return sw >= sh * 3 * 5 / 4
}

local function isUltraWide(sw = null, sh = null)
{
  sw = sw ?? ::screen_width()
  sh = sh ?? ::screen_height()
  local ratio = 1.0 * sw / sh

  if ("is_triple_head" in ::getroottable()) // Temporary compatibility with 1.89.1.X and older.
    return !::is_triple_head(sw, sh) && ratio >= 2.5

  return !isTripleHead(sw, sh) && ratio >= 2.5
}

local function getHudWidthLimit()
{
  local sw = ::screen_width()
  local sh = ::screen_height()
  return isTripleHead(sw, sh) ? (1.0 / 3)
    : isUltraWide(sw, sh) ? (1.0 * sh * 16 / 9 / sw)
    : 1.0
}

local function getMenuWidthLimit()
{
  return isTripleHead() ? (1.0 / 3) : 1.0
}

local function getFinalSafearea(safearea, widthLimit)
{
  if (widthLimit < 1.0 && safearea < 1.0 && isTripleHead())
    widthLimit = widthLimit * safearea
  return [ ::min(safearea, widthLimit), safearea ]
}

local function getMainScreenSizePx(sw = null, sh = null)
{
  sw = sw ?? ::screen_width()
  sh = sh ?? ::screen_height()
  if (isTripleHead(sw, sh))
    sw = sw / 3
  return [ sw, sh ]
}

local function getScreenHeightForFonts(sw, sh)
{
  local mainScreenSize = getMainScreenSizePx(sw, sh)
  return ::min(0.75 * mainScreenSize[0], mainScreenSize[1])
}

return {
  isUltraWide = isUltraWide
  getHudWidthLimit = getHudWidthLimit
  getMenuWidthLimit = getMenuWidthLimit
  getFinalSafearea = getFinalSafearea
  getMainScreenSizePx = getMainScreenSizePx
  getScreenHeightForFonts = getScreenHeightForFonts
}
