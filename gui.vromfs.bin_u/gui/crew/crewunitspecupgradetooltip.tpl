crewUnitSpecUpgradeTooltip {
  flow:t='vertical'
  width:t='0.7*@sf'

  textareaNoTab {
    width:t='pw'
    padding:t='1@tooltipPadding'
    text:t='<<tooltipText>>'
  }

  <<#tinyTooltipText>>
  textareaNoTab {
    width:t='pw'
    padding:t='1@tooltipPadding'
    smallFont:t='yes'
    text:t='<<tinyTooltipText>>'
  }
  <</tinyTooltipText>>

  <<#hasExpUpgrade>>
  tdiv {
    height:t='14*@sf/@pf'
    width:t='pw - 41*@sf/@pf'
    pos:t='0.5pw - 0.5w, 0'
    position:t='relative'
    margin-bottom:t='21*@sf/@pf'
    margin-top:t='31*@sf/@pf'

    crewSpecProgressBar {
      height:t='ph - 5*@sf/@pf'
      width:t='pw'
      top:t='0.5ph-0.5h'
      position:t='relative'
      min:t='0'
      max:t='1000'
      value:t='<<progressBarValue>>'
    }

    <<#markers>>
    referenceMarker {
      left:t='<<markerRatio>> * pw - 0.5w'
      textarea {
        position:t='absolute'
        pos:t='0.5pw - 0.5w, -h - 1*@sf/@pf'
        text:t='<<markerText>>'
      }
    }
    <</markers>>
  }

  textareaNoTab {
    padding:t='1@tooltipPadding'
    text:t='<<expUpgradeText>>'
    width:t='pw'
    exp_upgrade_text_area:t='yes'
  }
  <</hasExpUpgrade>>
}
