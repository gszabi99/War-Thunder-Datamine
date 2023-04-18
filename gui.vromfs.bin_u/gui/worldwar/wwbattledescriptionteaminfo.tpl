tdiv {
  width:t='pw'
  padding:t='0, 0.005@scrn_tgt'
  flow:t='vertical'

  <<#armies>>
  tdiv {
    <<^invert>>
    img {
      size:t='1@wwSmallCountryFlagWidth, 1@wwSmallCountryFlagHeight'
      background-svg-size:t='1@wwSmallCountryFlagWidth, 1@wwSmallCountryFlagHeight'
      margin:t='1@framePadding, 0'
      background-image:t='<<countryIconBig>>'
    }
    <</invert>>
    wwBattleTeamSize {
      top:t='50%(ph-h)'
      position:t='relative'
      activeText { text:t='<<teamSizeText>>' }
    }
    <<#invert>>
    left:t='pw-w'; position:t='relative'
    img {
      size:t='1@wwSmallCountryFlagWidth, 1@wwSmallCountryFlagHeight'
      background-svg-size:t='1@wwSmallCountryFlagWidth, 1@wwSmallCountryFlagHeight'
      margin:t='1@framePadding, 0'
      background-image:t='<<countryIconBig>>'
    }
    <</invert>>
  }

  tdiv {
    margin-top:t='1@blockInterval'

    width:t='pw'
    flow:t='vertical'
    <<@armyViews>>
  }
  <</armies>>
}
