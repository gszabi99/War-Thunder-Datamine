tdiv {
  flow:t='horizontal'
  Button_text {
    id:t='ammo_load_button'
    noMargin:t='yes'
    width:t='<<btnWidth>>'
    btnName:t=''
    tooltip:t='#mainmenu/btnAmmoLoad/tooltip'
    _on_click:t='onAmmoLoadBtnClick'
    text:t=''
    btnText {
      pos:t='1@buttonTextPadding, 0.5ph-0.5h'
      position:t='absolute'
      text:t='#mainmenu/btnAmmoLoad'
    }
    textareaNoTab {
      id:t='ammo_load_button_count'
      pos:t='pw-w-1@buttonTextPadding, 0.5ph-0.5h'
      position:t='absolute'
      input-transparent:t='yes'
    }
  }
}

tdiv {
  id:t='ammo_load_window_nest'
  size:t='pw, ph'
  position:t='absolute'
}