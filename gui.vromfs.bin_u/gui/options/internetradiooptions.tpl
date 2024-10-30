tdiv {
  position:t='relative'
  margin-top:t='2@blockInterval'

  Button_text {
    text:t ='#options/internet_radio_add'
    tooltip:t ='#guiHints/internet_radio_add'
    _on_click:t = 'onDialogAddRadio'
  }

  Button_text {
    id:t = 'btn_edit_radio'
    enable:t='no'
    tooltip:t ='#guiHints/internet_radio_edit'
    text:t ='#options/internet_radio_edit'
    _on_click:t = 'onDialogEditRadio'
  }

  Button_text {
    id:t = 'btn_remove_radio'
    enable:t='no'
    tooltip:t ='#guiHints/internet_radio_remove'
    text:t ='#options/internet_radio_remove'
    _on_click:t = 'onRemoveRadio'
  }
}

tr {
  margin-top:t='4@blockInterval'
  headerRow:t='yes'
  optContainer:t='yes'

  optionHeaderLine {}

  td { optionBlockHeader { text:t='#mainmenu/btnControls' } }
}

<<#hotkeyOpts>>
include "%gui/options/assignHotkeyOption.tpl"
<</hotkeyOpts>>