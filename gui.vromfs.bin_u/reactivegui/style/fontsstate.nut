from "daRg" import *
from "math" import round, max

let extWatched = require("%rGui/globals/extWatched.nut")

let baseNameFontsById = {
  tiny       = "very_tiny_text"
  small      = "tiny_text"
  normal     = "small_text"
  normalBold = "small_accented_text"
  medium     = "medium_text"
  bigBold    = "big_text"
}

let fontGenId = extWatched("fontGenId", "")
let fontSizePx = extWatched("fontSizePx", 0)
let fontSizeMultiplier = extWatched("fontSizeMultiplier", 1)

let get = @(fontId) Fonts?["".concat((baseNameFontsById?[fontId] ?? ""), fontGenId.value)]
let getSizePx = @(val = 1) round(val * fontSizePx.value / 1080.0).tointeger()
let getSizeByScrnTgt = @(val = 1) round(val * fontSizePx.value).tointeger()
let getSizeByDp = @(val = 1) val * max((fontSizePx.value / 900.0 + 0.5).tointeger(), 1)

return {
  get
  getSizePx
  getSizeByScrnTgt
  getSizeByDp
  fontSizeMultiplier
}
