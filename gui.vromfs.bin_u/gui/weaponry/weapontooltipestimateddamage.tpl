<<#estimatedDamageToBases>>
estimatedDamageBlock {
  flow:t='vertical'
  width:t='pw'
  padding-bottom:t='1/2@bulletTooltipPadding'

  tooltipDesc {
    tinyFont:t='yes'
    padding:t='1@bulletTooltipPadding'
    <<#presetsNames>>
    text:t='<<estimatedDamageTitle>><<?ui/colon>>'
    <</presetsNames>>

    <<^presetsNames>>
    text:t='<<estimatedDamageTitle>>'
    background-color:t='@frameHeaderBackgroundColor'
    margin-bottom:t='1@bulletTooltipPadding'
    <</presetsNames>>
  }
  <<#params>>
  tdiv {
    padding:t='1@bulletTooltipPadding, 0'
    margin-bottom:t='1/2@bulletTooltipPadding'

    activeText { text:t='<<damageValue>>'; smallFont:t='yes' }
    textareaNoTab {
      text:t=' - <<text>>'
      smallFont:t='yes'
      valign:t='center'
      overlayTextColor:t='minor'
    }
  }
  <</params>>
}
<</estimatedDamageToBases>>