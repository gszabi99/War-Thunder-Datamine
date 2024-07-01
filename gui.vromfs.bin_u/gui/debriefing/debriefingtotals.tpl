<<#showTeaser>>
tdiv{
  pos:t='0, 0'; position='relative'
  flow:t='vertical'
  tooltip:t='<<teaserTooltip>>'

  activeText{
    pos:t='pw-w, 0'; position:t='relative'
    padding-bottom:t='0.004@sf'
    noMargin:t='yes'
    talign:t='right'
    text:t='#debriefing/withPremium'
    style:t='color:@disabledTextColor;'
    smallFont:t='yes'
  }
  tdiv {
    pos:t='pw-w, 0'
    position:t='relative'
    textarea{
      id:t='expTeaser'
      noMargin:t='yes'
      text:t='<<expTeaser>>'
      style:t='color:@disabledTextColor;'
    }
    img {
      size:t='1@sIco, 1@sIco'
      top:t='0.5ph-0.5h'
      position:t='relative'
      background-image:t='#ui/gameuiskin#item_type_RP.svg'
      background-svg-size:t='1@sIco, 1@sIco'
    }
  }
  tdiv {
    pos:t='pw-w, 0'
    position:t='relative'
    textarea{
      id:t='wpTeaser'
      noMargin:t='yes'
      text:t='<<wpTeaser>>'
      style:t='color:@disabledTextColor;'
    }
    img {
      size:t='1@sIco, 1@sIco'
      top:t='0.5ph-0.5h'
      position:t='relative'
      background-image:t='#ui/gameuiskin#item_type_warpoints.svg'
      background-svg-size:t='1@sIco, 1@sIco'
    }
  }
}
<</showTeaser>>

tdiv{
  pos:t='0.01@sf, 0'; position='relative'
  flow:t='vertical'

  <<#showTeaser>>
  activeText{
    pos:t='pw-w, 0'; position:t='relative'
    padding-bottom:t='0.004@sf'
    noMargin:t='yes'
    talign:t='right'
    text:t='#debriefing/withoutPremium'
    smallFont:t='yes'
  }
  <</showTeaser>>
  tdiv {
    pos:t='pw-w, 0'
    position:t='relative'
    textarea{
      id:t='exp'
      noMargin:t='yes'
      style:t='color:@mainTitleTextColor;'
      text:t='<<exp>>'
    }
    img {
      size:t='1@sIco, 1@sIco'
      top:t='0.5ph-0.5h'
      position:t='relative'
      background-image:t='#ui/gameuiskin#item_type_RP.svg'
      background-svg-size:t='1@sIco, 1@sIco'
    }
  }
  tdiv {
    pos:t='pw-w, 0'
    position:t='relative'
    textarea{
      id:t='wp'
      noMargin:t='yes'
      style:t='color:@mainTitleTextColor;'
      text:t='<<wp>>'
    }
    img {
      size:t='1@sIco, 1@sIco'
      top:t='0.5ph-0.5h'
      position:t='relative'
      background-image:t='#ui/gameuiskin#item_type_warpoints.svg'
      background-svg-size:t='1@sIco, 1@sIco'
    }
  }
}
