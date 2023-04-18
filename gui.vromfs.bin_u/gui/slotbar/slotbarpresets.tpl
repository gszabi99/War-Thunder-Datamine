gcButtonsHolder {
  id:t='slotbar-presetsList'
  width:t='pw'
  showSelect='yes'
  <<#isSmallFont>>smallFont:t='yes'<</isSmallFont>>
  css-hier-invalidate:t='yes'

  behavior:t='ActivateSelect'
  navigatorShortcuts:t='yes'
  on_select:t='onPresetChange'

  <<#presets>>
  activateTab {
    position:t='relative'
    margin-right:t='1@dp'
    enable:t='no'
    display:t='hide'
    css-hier-invalidate:t='yes'

    tabText {
      id:t='tab_text'
      text:t = ''
      min-width:t='@minPresetNameTextWidth'
      max-width:t='@maxPresetNameTextWidth'
      pare-text:t='yes'
    }
    blockSeparator {}
  }
  <</presets>>

  Button_text {
    id:t='btn_slotbar_presets'
    style:t='height:1@bottomMenuPanelHeight;'
    tooltip:t='#shop/slotbarPresets/tooltip'
    on_click:t='onSlotsChoosePreset'

    img {
      isFirstLeft:t='yes'
      background-image:t='#ui/gameuiskin#slot_change_aircraft.svg'
    }

    btnText {
      pos:t='@blockInterval, 50%ph-50%h'
      position:t='relative'
      text-align:t='left'
      text:t='#shop/slotbarPresets/button'
    }
  }
}
