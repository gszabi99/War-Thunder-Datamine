tdiv {
  width:t='1@wwMapPanelInfoWidth'
  padding:t='1@wwGlobeTooltipPadding, 1@framePadding'
  bgcolor:t='@frameDarkBackgroundColor'
  color-factor:t='192'

  img {
    size:t='1@wwSmallCountryFlagWidth, 1@wwSmallCountryFlagHeight'
    background-svg-size:t='1@wwSmallCountryFlagWidth, 1@wwSmallCountryFlagHeight'
    background-image:t='<<country_0_icon>>'
  }

  tdiv {
    width:t='fw'
    top:t='0.5ph-0.5h'
    position:t='relative'

    textareaNoTab {
      margin:t='1@blockInterval, 0'
      style:t='color:#<<side_0_color>>;'
      text:t='<<rate_0>>%'
    }

    tdiv {
      size:t='fw, 1@blockInterval'
      top:t='0.5(ph-h)'
      position:t='relative'

      tdiv {
        size:t='<<rate_0>>%pw, ph'
        bgcolor:t='#<<side_0_color>>'
      }
      tdiv {
        size:t='fw, ph'
        bgcolor:t='#<<side_1_color>>'
      }
    }

    textareaNoTab {
      margin:t='1@blockInterval, 0'
      style:t='color:#<<side_1_color>>;'
      text:t='<<rate_1>>%'
    }
  }

  img {
    size:t='1@wwSmallCountryFlagWidth, 1@wwSmallCountryFlagHeight'
    background-svg-size:t='1@wwSmallCountryFlagWidth, 1@wwSmallCountryFlagHeight'
    background-image:t='<<country_1_icon>>'
  }
}

<<#rows>>
tdiv {
  width:t='1@wwMapPanelInfoWidth'
  padding:t='1@wwGlobeTooltipPadding, 0'

  textareaNoTab {
    width:t='1@wwSmallCountryFlagWidth'
    text-align:t='center'
    overlayTextColor:t='active'
    text:t='<<side_0>>'
  }

  textareaNoTab {
    width:t='fw'
    margin:t='15@sf/@pf, 0'
    position:t='relative'
    top:t='0.5(ph-h)'
    text-align:t='center'
    smallFont:t='yes'
    text:t='#multiplayer/<<text>>'
  }

  textareaNoTab {
    width:t='1@wwSmallCountryFlagWidth'
    text-align:t='center'
    overlayTextColor:t='active'
    text:t='<<side_1>>'
  }
}
<</rows>>
