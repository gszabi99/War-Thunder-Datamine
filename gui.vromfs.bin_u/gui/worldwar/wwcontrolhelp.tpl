tdiv {
  <<#isControlHelpCentered>>
    left:t='50%pw-50%w'
    position:t='relative'
  <</isControlHelpCentered>>

  <<#consoleButtonsIconName>>
    ButtonImg {
      size:t='@cIco, @cIco'
      top:t='50%ph-50%h'
      position:t='relative'
      btnName:t='<<consoleButtonsIconName>>'
    }
  <</consoleButtonsIconName>>
  <<#controlHelpText>>
    textareaNoTab {
      top:t='50%ph-50%h'
      position:t='relative'
      text:t='<<controlHelpText>>'
      overlayTextColor:t='active'
      smallFont:t='yes'
    }
  <</controlHelpText>>
  <<#controlHelpDesc>>
  textareaNoTab {
    padding:t='0, 1@framePadding'
    top:t='50%ph-50%h'
    position:t='relative'
    text:t='<<controlHelpDesc>>'
    overlayTextColor:t='active'
    smallFont:t='yes'
  }
  <</controlHelpDesc>>
}
