tdiv {
  flow:t='vertical'
  width:t=<<#isTooltipWide>>'460@sf/@pf'<</isTooltipWide>><<^isTooltipWide>>'360@sf/@pf'<</isTooltipWide>>

  textareaNoTab {
    text:t='<<header>>'
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
      tdiv {
        width:t='2@sIco'
        margin-right:t='2@blockInterval'
        img {
          background-image:t='<<unitTypeIco>>'
          size:t='<<#isWideIco>>2<</isWideIco>>@sIco, @sIco'
          background-svg-size:t='<<#isWideIco>>2<</isWideIco>>@sIco, @sIco'
          background-repeat:t='aspect-ratio'
          valign:t='center'
          halign:t='center'
        }
      }
      textareaNoTab {
        text:t='<<unitName>>'
        smallFont:t='yes'
        width:t='fw'
      }
      textareaNoTab {
        text:t='<<value>>'
        smallFont:t='yes'
        min-width:t='50@sf/@pf'
        text-align:t='right'
      }
    }
    <</units>>
  }

  <<#hasMoreVehicles>>
  tdiv {
    size:t='pw, 2@sf/@pf'
    background-color:t='@separatorBlockColor'
    margin:t='0, 0.5@blockInterval, 0, 0.5@blockInterval'
  }
  textareaNoTab {
    width:t='pw'
    tinyFont:t='yes'
    text-align:t='left'
    text:t='<<moreVehicles>>'
  }
  <</hasMoreVehicles>>
}
