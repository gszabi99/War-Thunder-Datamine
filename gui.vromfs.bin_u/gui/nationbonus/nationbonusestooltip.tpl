tdiv {
  flow:t='vertical'
  width:t='360@sf/@pf'

  textareaNoTab {
    text:t='#shop/unit_nation_bonus_tooltip/header'
    smallFont:t='yes'
    width:t='pw'
    margin-bottom:t='1@blockInterval'
    overlayTextColor:t='active'
  }

  tdiv {
    flow:t='vertical'
    width:t='pw'
    <<#units>>
    nationBonusUnit {
      flow:t='horizontal'
      width:t='pw'
      <<#even>>even:t='yes'<</even>>
      <<#hasCountry>>
      img {
        background-image:t='<<countryIcon>>'
        size:t='@sIco, @sIco'
        background-svg-size:t='@sIco, @sIco'
        margin-right:t='2@blockInterval'
      }
      <</hasCountry>>
      img {
        background-image:t='<<unitTypeIco>>'
        size:t='@sIco, @sIco'
        background-svg-size:t='@tableIcoSize, @tableIcoSize'
        background-repeat:t='aspect-ratio'
        margin-right:t='2@blockInterval'
      }
      textareaNoTab {
        text:t='<<unitName>>'
        smallFont:t='yes'
        width:t='fw'
      }
      textareaNoTab {
        text:t='<<battlesRemain>>'
        smallFont:t='yes'
        width:t='50@sf/@pf'
        text-align:t='center'
      }
    }
    <</units>>
  }
}