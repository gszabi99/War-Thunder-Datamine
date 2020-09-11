local fonts = require_native("fonts")
local u = require("sqStdLibs/helpers/u.nut")

local fontsList = {
  defaults = [
    "fontBigBold",
    "fontMedium",
    "fontNormalBold",
    "fontNormal",
    "fontSmall",
    "fontTiny"
  ]
  bold = [
    "fontBigBold",
    "fontNormalBold",
    "fontNormal"
  ]
}

local realFontNamePrefixesMap = {
  fontTiny        = "very_tiny_text"
  fontSmall       = "tiny_text"
  fontNormal      = "small_text"
  fontNormalBold  = "small_accented_text"
  fontMedium      = "medium_text"
  fontBigBold     = "big_text"
}

local daguiFonts = {

  /**
   * Returns line height in pixels for given font.
   * @param {string} fontName - font CSS const name.
   * @return {int} - line height in pixels, or 0 in case of error.
   */
  getFontLineHeightPx = function(fontName, realFontName = null)
  {
    realFontName = realFontName ?? ::get_main_gui_scene().getConstantValue(fontName)
    local bbox = fonts.getStringBBox(".", realFontName)
    return bbox ? ::max(0, bbox[3] - bbox[1]).tointeger() : 0
  }

  /**
   * Returns width in pixels for given text string rendered in given font (or max width for texts list).
   * @param {string} text - text string to be measured, without line breaks, or array of texts
   * @param {string} fontName - font CSS const name.
   * @param {instance} [guiScene] - optional valid instance of ScriptedGuiScene.
   * @return {int} - text width in pixels, or 0 in case of error or empty string.
   */
  getStringWidthPx = function(text, fontName, guiScene = null)
  {
    if (!text.len())
      return 0

    local res = 0
    local textList = u.isArray(text) ? text : [text]
    guiScene = guiScene || ::get_main_gui_scene()
    local realFontName = guiScene.getConstantValue(fontName)
    foreach(t in textList)
    {
      local bbox = fonts.getStringBBox(t, realFontName)
      if (bbox)
        res = ::max(res, (bbox[2] - bbox[0] + 0.5).tointeger())
    }
    return res
  }

  /**
   * Returns the maximum font from the font table by key
     for a given text string that can be contained in the specified number of pixels
  */
  getMaxFontTextByWidth = function(text, WidthPx, fontKeyName)
  {
    local list = fontsList?[fontKeyName] ?? fontsList.defaults
    foreach (font in list)
      if (getStringWidthPx(text,font) < WidthPx)
        return font
    return list?[list.len() - 1] ?? ""
  }

  getRealFontNamePrefixesMap = @() realFontNamePrefixesMap
}

return daguiFonts
