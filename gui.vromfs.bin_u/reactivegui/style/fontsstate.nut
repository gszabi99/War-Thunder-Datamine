local baseNameFontsById = {
  tiny       = "very_tiny_text"
  small      = "tiny_text"
  normal     = "small_text"
  normalBold = "small_accented_text"
  medium     = "medium_text"
  bigBold    = "big_text"
}

local fontGenId = persist("fontGenId",  @() Watched(""))
local fontSizePx = persist("fontSizePx", @() Watched(0))

local updateFontParams = function (params) {
  if (params?.fontGenId)
    fontGenId(params.fontGenId)
  if (params?.fontSizePx)
    fontSizePx(params.fontSizePx)
}
updateFontParams(::cross_call.getCurrentFontParams())

::interop.updateFontParams <- updateFontParams

local get = @(fontId) Fonts?[(baseNameFontsById?[fontId] ?? "") + fontGenId.value]
local getSizePx = @(val = 1) ::math.round(val * fontSizePx.value / 1080.0)
local getSizeByScrnTgt = @(val = 1) ::math.round(val * fontSizePx.value / 100)
local getSizeByDp = @(val = 1) val * max((fontSizePx.value/900.0 + 0.5).tointeger(), 1)

return {
  get = get
  getSizePx = getSizePx
  getSizeByScrnTgt = getSizeByScrnTgt
  getSizeByDp = getSizeByDp
}
