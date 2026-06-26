<<#units>>
unitContactRow {
  width:t='pw'
  flow:t='horizontal'
  <<#even>>even:t='yes'<</even>>
  tdiv {
    width:t='1.5@sIco'
    margin-right:t='2@blockInterval'
    valign:t='center'
    <<#countryIcon>>
    img {
      size:t='@sIco, 0.66@sIco'
      pos:t='pw/2-w/2, ph/2-h/2'
      position:t='relative'
      background-image:t='<<countryIcon>>'
      background-svg-size:t='@sIco, 0.66@sIco'
      background-repeat:t='aspect-ratio'
    }
    <</countryIcon>>
    <<^countryIcon>>
    textareaNoTab {
      text:t='#leaderboards/notAvailable'
      tinyFont:t='yes'
      valign:t='center'
      halign:t='center'
    }
    <</countryIcon>>
  }
  tdiv {
    width:t='2@sIco'
    margin-right:t='2@blockInterval'
    valign:t='center'
    <<#unitTypeIco>>
    img {
      size:t='<<#isWideIco>>2<</isWideIco>>@sIco, @sIco'
      background-image:t='<<unitTypeIco>>'
      background-svg-size:t='<<#isWideIco>>2<</isWideIco>>@sIco, @sIco'
      background-repeat:t='aspect-ratio'
      valign:t='center'
      halign:t='center'
    }
    <</unitTypeIco>>
    <<^unitTypeIco>>
    textareaNoTab {
      text:t='#leaderboards/notAvailable'
      tinyFont:t='yes'
      valign:t='center'
      halign:t='center'
    }
    <</unitTypeIco>>
  }
  textareaNoTab {
    width:t='fw'
    text:t='<<unitName>>'
    smallFont:t='yes'
  }
  textareaNoTab {
    text:t='<<additionalInfo>>'
    smallFont:t='yes'
  }
}
<</units>>
