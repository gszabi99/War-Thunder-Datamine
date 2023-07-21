RadioButtonList {
  on_select:t = 'onSelectPreset'
  size:t='pw,ph'
  class:t='gpuBenchmark'
  highlightSelected:t='yes'
  navigatorShortcuts:t='yes'
  <<#presets>>
  RadioButton {
    presetName:t='<<presetName>>'
    size:t='pw, 1@buttonHeight+1@blockInterval'
    position:t='relative'
    text:t='#<<label>>'
    <<#selected>>
    selected:t='yes'
    <</selected>>
    RadioButtonImg{
      position:t='absolute'
      pos:t='0, 50%(ph-h)'
    }
    textareaNoTab {
      text:t='<<presetText>>'
      position:t='absolute'
      pos:t='50%pw+6@blockInterval, 50%(ph-h)'
      tooltip:t='#guiHints/graphicsQuality_<<presetName>>'
    }
  }
  <</presets>>
}