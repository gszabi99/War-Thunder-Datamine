let extWatched = require("reactiveGui/globals/extWatched.nut")

let baseNameFontsById = {
  tiny       = "very_tiny_text"
  small      = "tiny_text"
  normal     = "small_text"
  normalBold = "small_accented_text"
  medium     = "medium_text"
  bigBold    = "big_text"
}

let fontGenId = extWatched("fontGenId",  @() ::cross_call.getCurrentFontParams()?.fontGenId ?? "")
let fontSizePx = extWatched("fontSizePx", @() ::cross_call.getCurrentFontParams()?.fontSizePx ?? 0)

let get = @(fontId) Fonts?["".concat((baseNameFontsById?[fontId] ?? ""), fontGenId.value)]
let getSizePx = @(val = 1) ::math.round(val * fontSizePx.value / 1080.0).tointeger()
let getSizeByScrnTgt = @(val = 1) ::math.round(val * fontSizePx.value).tointeger()
let getSizeByDp = @(val = 1) val * max((fontSizePx.value/900.0 + 0.5).tointeger(), 1)

return {
  get
  getSizePx
  getSizeByScrnTgt
  getSizeByDp
}
