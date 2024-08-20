tdiv {
  flow:t='vertical'
  tdiv {
    activeText {
      text:t='#shop/unit_nation_bonus_tooltip/header'
      smallFont:t='yes'
    }
  }
  <<#units>>
  tdiv {
    flow:t='horizontal'
    <<#hasCountry>>
    img {//flag
      background-image:t='<<countryIcon>>'
      size:t='@sIco, @sIco'
      background-svg-size:t='@sIco, @sIco'
      margin-right:t='@blockInterval'
    }
    <</hasCountry>>
    activeText {
      text:t='<<unitType>>'
      smallFont:t='yes'
      margin-right:t='@blockInterval'
    }
    activeText {
      text:t='<<unitName>>'
      smallFont:t='yes'
      margin-right:t='@blockInterval'
    }
    activeText {
      text:t='<<battlesRemain>>'
      smallFont:t='yes'
    }
  }
  <</units>>
}