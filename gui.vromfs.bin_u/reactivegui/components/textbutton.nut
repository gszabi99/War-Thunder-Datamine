import "%rGui/style/fontsState.nut" as fontsState
import "%rGui/components/textButtonTextCtor.nut" as textButtonTextCtor
import "%rGui/style/cssColor.nut" as cssColor
from "%rGui/globals/ui_library.nut" import *

let textButton = require("%rGui/components/textButtonBase.nut")

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
    BgNormal     = cssColor("buttonColor")
    BgHover      = cssColor("buttonColorHover")
    BgActive     = cssColor("buttonColorPushed")
    BgFocused    = cssColor("buttonColorFocus")
    BgDisabled   = cssColor("buttonColorDisabled")

    BdNormal     = cssColor("buttonBorderColor")
    BdHover      = cssColor("buttonBorderColorHover")
    BdActive     = cssColor("buttonBorderColorPushed")
    BdFocused    = cssColor("buttonBorderColorFocus")
    BdDisabled   = cssColor("buttonBorderColorDisabled")

    TextNormal   = cssColor("buttonFontColor")
    TextHover    = cssColor("buttonFontColorHover")
    TextActive   = cssColor("buttonFontColorPushed")
    TextFocused  = cssColor("buttonFontColorFocus")
    TextDisabled = cssColor("buttonFontColorDisabled")
  }
}

let steamReviewButtonStyle = commonButtonStyle.__merge({
  style = {
    BgNormal     = cssColor("buttonSteamColor")
    BgHover      = cssColor("buttonSteamHoverColor")
    BgActive     = 0xFFFFFFFF

    BdNormal     = cssColor("buttonSteamColor")
    BdHover      = cssColor("buttonSteamHoverColor")
    BdActive     = 0xFFFFFFFF

    TextNormal   = cssColor("buttonSteamFontColor")
    TextHover    = 0xFFFFFFFF
    TextActive   = cssColor("buttonSteamFontPushedColor")
  }
})

return freeze({
  commonTextButton = @(text, handler, params = {}) textButton.Bordered(text, handler, commonButtonStyle.__merge(params))
  steamReviewTextButton = @(text, handler, params = {})
    textButton.Bordered(text, handler, steamReviewButtonStyle.__merge(params))
  buttonHeight
})
