local extWatched = require("reactiveGui/globals/extWatched.nut")

local baseNameFontsById = {
  tiny       = "very_tiny_text"
  small      = "tiny_text"
  normal     = "small_text"
  normalBold = "small_accented_text"
  medium     = "medium_text"
  bigBold    = "big_text"
}

local fontGenId = extWatched("fontGenId",  @() ::cross_call.getCurrentFontParams()?.fontGenId ?? "")
local fontSizePx = extWatched("fontSizePx", @() ::cross_call.getCurrentFontParams()?.fontSizePx ?? 0)

local get = @(fontId) Fonts?[(baseNameFontsById?[fontId] ?? "") + fontGenId.value]
local getSizePx = @(val = 1) ::math.round(val * fontSizePx.value / 1080.0).tointeger()
local getSizeByScrnTgt = @(val = 1) ::math.round(val * fontSizePx.value).tointeger()
local getSizeByDp = @(val = 1) val * max((fontSizePx.value/900.0 + 0.5).tointeger(), 1)

return {
  get = get
  getSizePx = getSizePx
  getSizeByScrnTgt = getSizeByScrnTgt
  getSizeByDp = getSizeByDp
}
