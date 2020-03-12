tdiv {
  top:t='50%ph-50%h'
  position:t='relative'
  flow:t='vertical'
  total-input-transparent:t='yes'
  <<#type>>
    type:t='<<type>>'
  <</type>>
  tdiv {
    left:t='50%pw-50%w'
    position:t='relative'
    css-hier-invalidate:t='yes'

    <<#shortcutText>>
    textareaNoTab {
      text:t='<<shortcutText>>'
      overlayTextColor:t='hotkey'
    }
    textareaNoTab { text:t=' ' }
    textareaNoTab { text:t='#ui/mdash' }
    textareaNoTab { text:t=' ' }
    <</shortcutText>>

    textareaNoTab {
      text:t='<<name>>'

      <<#chatMode>>
      chatMode:t='<<chatMode>>'
      <</chatMode>>
    }
  }
  textareaNoTab {
    text:t='<<additionalText>>'
    smallFont:t='yes'
    hideEmptyText:t='yes'
  }
}
