tr {
  <<#optRowId>>
  id:t='<<optRowId>>'
  <</optRowId>>
  width:t='pw'
  optContainer:t='yes'
  hotkeyOpt:t='yes'

  td {
    width:t='0.55pw'
    cellType:t='left'

    optiontext {
      text:t ='<<optionText>>'
    }
  }

  td {
    width:t='0.45pw'
    cellType:t='right'

    cellSeparator{}

    Button_text {
      _on_click:t = '<<onAssignFnName>>'
      <<#tip>>
      tooltip:t ='<<tip>>'
      <</tip>>
      textarea {
        id:t="<<shortcutTextareaId>>"
        position:t='relative'
        pos:t="0.5pw-0.5w,0.5ph-0.5h"
        text-align:t="center"
        text:t='<<shortcutText>>'
        voiceShortcut:t="yes"
      }
    }

    Button_text {
      margin-left:t='1@blockInterval'
      text:t ='#mainmenu/btnReset'
      tooltip:t ='<<#resetTip>><<resetTip>><</resetTip>><<^resetTip>>#mainmenu/btnReset<</resetTip>>'
      _on_click:t = '<<onResetFnName>>'
    }
  }
}