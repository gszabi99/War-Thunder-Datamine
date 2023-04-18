<<#buttons>>
selectButton {
  flow:t='horizontal'
  Button_text {
    forPresetId:t = '<<presetNumber>>'
    text:t = '#ship/btn_select_for'
    on_click:t = 'onSelectFor'
    ButtonImg {}
    enable:t='yes'
    display:t='show'
  }
  damageControlPresetShortcut {
    size:t='2@damageControlIconSize, 1@buttonHeight'
    pos:t='0, ph/2 - h/2'
    position:t='relative'

    activeText {
      text:t='<<shortcut>>'
    }
  }
}
<</buttons>>