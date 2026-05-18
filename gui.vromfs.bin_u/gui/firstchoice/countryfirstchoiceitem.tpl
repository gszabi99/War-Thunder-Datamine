<<#countries>>
firstChoiceItem {
  countryName:t='<<country>>'
  margin-bottom:t='1@countryChoiceInterval'
  behaviour:t='button'
  on_click:t='onClickCountryItem'
  focusBtnName:t='A'
  not-input-transparent:t='yes'
  gamercardSkipNavigation:t='yes'
  tooltip:t='<<tooltip>>'

  firstChoiceImage {
    background-image:t='<<backgroundImage>>'

    firstChoiceShadow {
      size:t='pw, 1@countryChoiceTextBlockHeight'
      background-svg-size:t='1@unitChoiceImageWidth, 1@countryChoiceTextBlockHeight'
      background-image:t='!ui/images/firstChoice/countryChoiceShadow.svg'
    }

    firstChoiceText {
      text:t='<<countryName>>'
      css-hier-invalidate:t='yes'
    }
    <<#isRecomended>>
    activeText {
      pos:t='pw-w-2@blockInterval, 2@blockInterval'
      position:t='absolute'
      smallFont:t='yes'
      text:t='#mainmenu/recommended'
    }
    <</isRecomended>>
  }
  slotHoverHighlight {}
  slotTopGradientLine {}
  slotBottomGradientLine {}
}
<</countries>>
