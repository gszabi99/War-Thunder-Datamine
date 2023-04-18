tdiv {
  width:t='pw'
  margin:t='1@wwWindowListBackgroundPadding'
  flow:t='vertical'

  <<#haveUnitsList>>
  textareaNoTab {
    <<#invert>>
      left:t='pw-w'; position:t='relative'
    <</invert>>
    text:t='#worldwar/available_crafts'
  }
  tdiv {
    width:t='pw'
    flow:t='vertical'
    <<#invert>>
      left:t='pw-w'; position:t='relative'
    <</invert>>
    <<@unitsList>>
  }
  <</haveUnitsList>>

  <<#haveAIUnitsList>>
  textareaNoTab {
    <<#invert>>
      left:t='pw-w'; position:t='relative'
    <</invert>>
    margin-top:t='1@wwWindowListBackgroundPadding'
    text:t='#worldwar/unit/controlledByAI'
    overlayTextColor:t='disabled'
  }
  tdiv {
    width:t='pw'
    flow:t='vertical'
    <<#invert>>
      left:t='pw-w'; position:t='relative'
    <</invert>>
    <<@aiUnitsList>>
  }
  <</haveAIUnitsList>>
}
