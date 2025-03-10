from "%scripts/dagui_library.nut" import *

let fonts = require("fonts")
let u = require("%sqStdLibs/helpers/u.nut")

let fontsList = {
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

let realFontNamePrefixesMap = {
  fontTiny        = "very_tiny_text"
  fontSmall       = "tiny_text"
  fontNormal      = "small_text"
  fontNormalBold  = "small_accented_text"
  fontMedium      = "medium_text"
  fontBigBold     = "big_text"
}

local daguiFonts = {

  




  getFontLineHeightPx = function(fontName, realFontName = null) {
    realFontName = realFontName ?? get_main_gui_scene().getConstantValue(fontName)
    local bbox = fonts.getStringBBox(".", realFontName)
    return bbox ? max(0, bbox[3] - bbox[1]).tointeger() : 0
  }

  






  getStringWidthPx = function(text, fontName, guiScene = null) {
    if (!text.len())
      return 0

    local res = 0
    let textList = u.isArray(text) ? text : [text]
    guiScene = guiScene || get_main_gui_scene()
    let realFontName = guiScene.getConstantValue(fontName)
    foreach (t in textList) {
      let bbox = fonts.getStringBBox(t, realFontName)
      if (bbox)
        res = max(res, (bbox[2] - bbox[0] + 0.5).tointeger())
    }
    return res
  }

  



  getMaxFontTextByWidth = function(text, WidthPx, fontKeyName) {
    let list = fontsList?[fontKeyName] ?? fontsList.defaults
    foreach (font in list)
      if (this.getStringWidthPx(text, font) < WidthPx)
        return font
    return list?[list.len() - 1] ?? ""
  }

  getRealFontNamePrefixesMap = @() realFontNamePrefixesMap
}

return daguiFonts
