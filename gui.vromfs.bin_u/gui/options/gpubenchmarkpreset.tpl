<<#presets>>
tdiv {
  size:t='pw, 1@buttonHeight+1@blockInterval'

  Button_text {
    presetName:t='<<presetName>>'
    position:t='absolute'
    right:t='50%pw+1@blockInterval'
    top:t='50%(ph-h)'
    noMargin:t='yes'
    text:t='#<<label>>'
    btnName:t='<<shortcut>>'
    on_click:t='onPresetApply'
    ButtonImg {}
  }
  textareaNoTab {
    text:t='<<presetText>>'
    position:t='absolute'
    pos:t='50%pw+6@blockInterval, 50%(ph-h)'
    tooltip:t='#guiHints/graphicsQuality_<<presetName>>'
  }
}
<</presets>>