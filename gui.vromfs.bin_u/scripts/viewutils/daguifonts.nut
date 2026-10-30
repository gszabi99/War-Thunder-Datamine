import "%sqStdLibs/helpers/u.nut" as u
import "fonts" as fonts
import "%appGlobals/style/fontIds.nut" as fontIds
from "%scripts/dagui_library.nut" import *
from "%scripts/utils/screenUtils.nut" import setScrnTgt
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%sqstd/string.nut" import capitalize

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






function getFontLineHeightPx(fontName, realFontName = null) {
  realFontName = realFontName ?? get_main_gui_scene().getConstantValue(fontName)
  local bbox = fonts.getStringBBox(".", realFontName)
  return bbox ? max(0, bbox[3] - bbox[1]).tointeger() : 0
}








function getStringWidthPx(text, fontName, guiScene = null) {
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





function getMaxFontTextByWidth(text, WidthPx, fontKeyName) {
  let list = fontsList?[fontKeyName] ?? fontsList.defaults
  foreach (font in list)
    if (getStringWidthPx(text, font) < WidthPx)
      return font
  return list?[list.len() - 1] ?? ""
}

function getCssFontConsts(font) {
  let sWidth = screen_width()
  let sHeight = screen_height()
  let scrnTgt = font.getFontSizePx(sWidth, sHeight)
  setScrnTgt(scrnTgt)
  let consts = {
    scrn_tgt = scrnTgt
    isWide = font.isLowWidthScreen() ? 0 : 1
    pf_outdated = 800 
    sf = scrnTgt
    pf = 1080
  }
  if (scrnTgt <= 0)
    script_net_assert_once("Bad screenTgt", $"Bad screenTgt const at load fonts css /*configStr = {toString(consts)}*/")
  foreach (id, prefixId in fontIds) {
    let fontName = $"{prefixId}{font.fontGenId}"
    consts[$"font{capitalize(id)}"] <- fontName
    consts[$"fontHeight{capitalize(id)}"] <- getFontLineHeightPx(null, fontName) 
  }
  return consts.keys().sort().map(@(name) { name, value = $"{consts[name]}" })
}

return freeze({
  getFontLineHeightPx
  getStringWidthPx
  getMaxFontTextByWidth
  getCssFontConsts
})
