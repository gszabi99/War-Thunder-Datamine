root {
  class:t="button"
  behaviour:t="button"
  on_click:t='goBack'
  on_r_click:t='goBack'

  rightClickMenu {
    id:t='rclick_menu_div'
    position:t='absolute'
    flow:t='vertical'
    overflow-y:t='auto';
    max-height:t='0.75@rh'

    <<#actions>>

    <<#hasSeparator>>
    menuLine { enable:t='no' }
    <</hasSeparator>>

    <<#text>>
    Button_text {
      id:t='<<id>>'
      <<#isVisualDisabled>>inactiveColor:t='yes'<</isVisualDisabled>>
      text:t='<<textUncolored>>'
      tooltip:t='<<tooltip>>'
      btnName:t='A'
      on_click:t='onMenuButton'

      <<#needTimer>>
      behaviour:t='Timer'
      <</needTimer>>

      textarea {
        id:t='text'
        text:t='<<text>>'
        <<#isVisualDisabled>>inactiveColor:t='yes'<</isVisualDisabled>>
      }
      ButtonImg{}
    }
    <</text>>

    <</actions>>
  }

  DummyButton {
    on_click:t = 'goBack'
    btnName:t='B'
  }
}
