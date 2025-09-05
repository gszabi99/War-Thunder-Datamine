from "%rGui/globals/ui_library.nut" import *

let textButton = require("%rGui/components/textButtonBase.nut")
let fontsState = require("%rGui/style/fontsState.nut")
let textButtonTextCtor = require("%rGui/components/textButtonTextCtor.nut")

let buttonHeight = dp(2) + fpx(36)

let commonButtonStyle = {
  halign = ALIGN_CENTER
  font = fontsState.get("normal")
  borderWidth = dp(1)
  size = [SIZE_TO_CONTENT, buttonHeight]
  minWidth = scrn_tgt(0.16)
  borderRadius = 0
  textCtor = textButtonTextCtor
  textMargin = 0

  style = {
    BgNormal     = Color(58, 71, 79)
    BgHover      = Color(224, 224, 224)
    BgActive     = Color(2, 5, 9, 153)
    BgFocused    = Color(140, 140, 140, 140)
    BgDisabled   = Color(11, 14, 16, 127)

    BdNormal     = Color(58, 71, 79)
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

let steamReviewButtonStyle = commonButtonStyle.__merge({
  style = {
    BgNormal     = 0xFF304F70
    BgHover      = 0xFF4A88A8
    BgActive     = 0xFFFFFFFF

    BdNormal     = 0xFF304F70
    BdHover      = 0xFF4A88A8
    BdActive     = 0xFFFFFFFF

    TextNormal   = 0xFF68C1F5
    TextHover    = 0xFFFFFFFF
    TextActive   = 0xFF304F70
  }
})

return {
  commonTextButton = @(text, handler, params = {}) textButton.Bordered(text, handler, commonButtonStyle.__merge(params))
  steamReviewTextButton = @(text, handler, params = {})
    textButton.Bordered(text, handler, steamReviewButtonStyle.__merge(params))
  buttonHeight
}
