import "%rGui/globals/extWatched.nut" as extWatched
import "%appGlobals/style/fontIds.nut" as fontIds
from "%appGlobals/options/fontTypes.nut" import getPreLoginFontType
from "daRg" import *
from "frp" import Computed
from "math" import round, max
from "%appGlobals/options/screenInfo.nut" import getScreenHeightForFonts

let startFont = getPreLoginFontType()
let fontGenId = extWatched("fontGenId", startFont.fontGenId)
let fontSizeMultiplier = extWatched("fontSizeMultiplier", startFont.sizeMultiplier)
let fontSizePx = Computed(@() round(fontSizeMultiplier.get() * getScreenHeightForFonts(sw(100), sh(100))).tointeger())

let get = @(fontId) Fonts?["".concat((fontIds?[fontId] ?? ""), fontGenId.get())]
let getSizePx = @(val = 1) round(val * fontSizePx.get() / 1080.0).tointeger()
let getSizeByScrnTgt = @(val = 1) round(val * fontSizePx.get()).tointeger()
let getSizeByDp = @(val = 1) val * max((fontSizePx.get() / 900.0 + 0.5).tointeger(), 1)

return freeze({
  get
  getSizePx
  getSizeByScrnTgt
  getSizeByDp
  fontSizePx
  fontSizeMultiplier
})
