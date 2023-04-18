bottomButtonsDiv {
  class:t='smallFont'

  <<#hasButton>>
  Button_text {
    id:t='air_action_button'
    holderId:t='<<holderId>>'

    btnName:t='SpaceA'
    visualStyle:t='common'
    class:t='bottomAirItem'
    text:t='<<mainButtonText>>'
    on_click:t='<<mainButtonAction>>'

    <<#hasMainButtonIcon>>
    img {
      background-image:t='<<mainButtonIcon>>'
    }
    <</hasMainButtonIcon>>

    ButtonImg {}
  }
  <</hasButton>>
}
