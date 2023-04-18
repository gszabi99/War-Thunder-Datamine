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
  textarea{
    id:t='expTeaser'
    pos:t='pw-w, 0'; position:t='relative'
    noMargin:t='yes'
    talign:t='right'
    text:t='<<expTeaser>>'
    style:t='color:@disabledTextColor;'
  }
  textarea{
    id:t='wpTeaser'
    pos:t='pw-w, 0'; position:t='relative'
    noMargin:t='yes'
    talign:t='right'
    text:t='<<wpTeaser>>'
    style:t='color:@disabledTextColor;'
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
  textarea{
    id:t='exp'
    pos:t='pw-w, 0'; position:t='relative'
    noMargin:t='yes'
    talign:t='right'
    style:t='color:@mainTitleTextColor;'
    text:t='<<exp>>'
  }
  textarea{
    id:t='wp'
    pos:t='pw-w, 0'; position:t='relative'
    noMargin:t='yes'
    talign:t='right'
    style:t='color:@mainTitleTextColor;'
    text:t='<<wp>>'
  }
}
