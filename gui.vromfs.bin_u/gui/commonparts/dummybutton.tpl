DummyButton {
  id:t='<<id>>'
  <<#funcName>>
    <<#delayed>>_<</delayed>>on_click:t='<<funcName>>'
  <</funcName>>

  <<#btnKey>>
    btnName:t='<<btnKey>>'
  <</btnKey>>

  <<#isDisabled>>
    enable:t='no'
  <</isDisabled>>
}
