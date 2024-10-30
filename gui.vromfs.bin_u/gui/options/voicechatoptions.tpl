<<#needShowOptions>>

<<#hotkeyOpts>>
include "%gui/options/assignHotkeyOption.tpl"
<</hotkeyOpts>>

tr {
  size:t="pw, @optConatainerHeight"
  optContainer:t='yes'

  td {
    width:t='0.55pw'
    cellType:t='left'
  }

  td {
    width:t='0.45pw'
    padding-left:t='@optPad'
    cellType:t='right'

    cellSeparator{}

    Button_text {
      id:t="joinEchoButton"
      text:t ='#options/joinEcho'
      tooltip:t ='#guiHints/joinEcho'
      _on_click:t="onEchoTestButton"
    }
  }
}

<</needShowOptions>>

<<^needShowOptions>>
tr {
  margin-top:t='2@blockInterval'
  headerRow:t='yes'
  optContainer:t='yes'

  optionHeaderLine {}

  td { optionBlockHeader { text:t='#options/voicechat' } }
}

textarea {
  id:t='voice_disable_warning'
  position:t='relative'
  pos:t='50%pw-50%w, 0'
  max-width:t='50%pw'
  margin:t='0, 0.03@scrn_tgt'
  text:t='#options/voiceChat/disableWarning'
  text-align:t='center'
  overlayTextColor:t='warning'
}
<</needShowOptions>>