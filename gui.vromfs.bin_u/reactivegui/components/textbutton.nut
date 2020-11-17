local textButton = require("daRg/components/textButton.nut")
local fontsState = require("reactiveGui/style/fontsState.nut")
local textButtonTextCtor = require("textButtonTextCtor.nut")

local commonButtonStyle = {
  halign = ALIGN_CENTER
  font = fontsState.get("normal")
  borderWidth = ::dp(1)
  size = [SIZE_TO_CONTENT, ::dp(2) + ::fpx(36)]
  minWidth = ::scrn_tgt(0.16)
  padding = [::fpx(3), ::scrn_tgt(0.005)]
  borderRadius = 0
  textCtor = textButtonTextCtor
  textMargin = 0

  style = {
    BgNormal     = Color(58,71,79)
    BgHover      = Color(224, 224, 224)
    BgActive     = Color(2, 5, 9, 153)
    BgFocused    = Color(140, 140, 140, 140)
    BgDisabled   = Color(11, 14, 16, 127)

    BdNormal     = Color(58,71,79)
    BdHover      = Color(224, 224, 224)
    BdActive     = Color(7, 9, 11, 153)
    BdFocused    = Color(204, 204, 204, 204)
    BdDisabled   = Color(25, 25, 25, 25)

    TextNormal   = Color(224, 224, 224)
    TextHover    = Color(24, 24, 24)
    TextActive   = Color(144, 143, 143)
    TextFocused  = Color(24, 24, 24)
    TextDisabled = Color(33, 33, 33, 38)
  }
}
return {
  commonTextButton = @(text, handler, params = {}) textButton.Bordered(text, handler, commonButtonStyle.__merge(params))
}
