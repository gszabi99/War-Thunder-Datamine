<<#changeToSpecs>>
weaponPresetChangeSpecBlock {
  flow:t='vertical'
  width:t='pw'
  padding-bottom:t='1/2@bulletTooltipPadding'
  tooltipDesc {
    tinyFont:t='yes'
    padding:t='1@bulletTooltipPadding'
    <<#presetsNames>>
    text:t='<<changeSpecTitle>><<?ui/colon>>'
    <</presetsNames>>

    <<^presetsNames>>
    text:t='<<changeSpecTitle>>'
    background-color:t='@frameHeaderBackgroundColor'
    margin-bottom:t='1@bulletTooltipPadding'
    <</presetsNames>>
  }

  <<#changeToSpecsParams>>
  tdiv {
    width:t='pw'
    padding:t='1@bulletTooltipPadding, 0'
    margin-bottom:t='1/2@bulletTooltipPadding'
    <<#effectValue>>
    textareaNoTab {
      width:t='fw'
      max-width:t='fw'
      text:t='<<effectValue>> - <<text>>'
      smallFont:t='yes'
      valign:t='center'
      overlayTextColor:t='minor'
    }
    <</effectValue>>
  }
  <</changeToSpecsParams>>

  textareaNoTab {
    padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
    width:t='pw'
    text:t='<<changeSpecNotice>>'
    tinyFont:t='yes'
    overlayTextColor:t='minor'
  }
}
<</changeToSpecs>>
