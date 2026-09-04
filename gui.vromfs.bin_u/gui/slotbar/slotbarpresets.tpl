
tdiv {
  id:t='slotbarPresetsButtons'
  position:t='relative'
  top:t='ph/2 - h/2 - 0.5@blockInterval'
  height:t='41@sf/@pf'

  Button_text {
    id:t = 'btnPresetsShowSettings'
    class:t='image'
    valign:t='center'
    showConsoleImage:t='no'
    useParentHeight:t='yes'
    reduceWidthToHeight:t='yes'
    on_click:t='onPresetsShowSettings'
    tooltip:t='#presets/filter/title'

    img {
      id:t='icon'
      background-image:t='#ui/gameuiskin#slot_modifications.svg'
      halign:t='center'
      valign:t='center'
    }
  }
  Button_text {
    id:t = 'btnPresets'
    text:t = '#shop/slotbarPresets/button'
    tooltip:t = '#shop/slotbarPresets/tooltip'
    reduceMinimalWidth:t='yes'
    useParentHeight:t='yes'
    valign:t='center'
    on_click:t='onSlotsChoosePreset'
  }
}

presetsContainer {
  id:t='slotbarPresetsContainer'
  size:t='fw - 5@blockInterval, 1@bottomMenuPanelHeight'
  css-hier-invalidate:t='yes'

  tdiv {
    id:t='slotbarPresetsList'
    behavior:t='ActivateSelect'
    size:t='fw, ph'
    overflow-x:t='auto'
    showSelect:t='yes'
    <<#isSmallFont>>smallFont:t='yes'<</isSmallFont>>
    css-hier-invalidate:t='yes'
    navigatorShortcuts:t='yes'
    on_select:t='onPresetChange'

    <<#presets>>
    presetTab {
      presetIdx:t=''
      position:t='relative'
      gap:t='2@blockInterval'
      enable:t='no'
      display:t='hide'
      css-hier-invalidate:t='yes'
      on_hover:t='onPresetHover'
      on_unhover:t='onPresetUnHover'

      textareaNoTab {
        id:t='presetBR'
        position:t='relative'
        normalBoldFont:t='yes'
      }
      textareaNoTab {
        id:t='presetGameMode'
        position:t='relative'
        overlayTextColor:t='minor'
      }
      textareaNoTab {
        id:t='presetName'
        presetName:t='yes'
        position:t='relative'
      }
      blockSeparator {}
    }
    <</presets>>
  }
}
