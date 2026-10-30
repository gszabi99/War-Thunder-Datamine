<<#countries>>
firstChoiceItem {
  behaviour:t='button'
  width:t='1@countryChoiceImageWidth'
  height:t='1@countryChoiceImageHeight'
  margin-right:t='1@countryChoiceInterval'
  margin-bottom:t='1@countryChoiceInterval'

  countryName:t='<<country>>'
  on_click:t='onClickCountryItem'
  focusBtnName:t='A'
  not-input-transparent:t='yes'
  gamercardSkipNavigation:t='yes'
  tooltip:t='<<tooltip>>'

  firstChoiceImage {
    background-image:t='<<backgroundImage>>'
  }

  <<#videoPreview>>
  movie {
    movie-load='<<videoPreview>>'
    movie-autoStart:t='yes'
    movie-loop:t='yes'
  }
  <</videoPreview>>

  firstChoiceShadow {}

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

  slotHoverHighlight {}
  firstChoiceSelectRect {}
}
<</countries>>
