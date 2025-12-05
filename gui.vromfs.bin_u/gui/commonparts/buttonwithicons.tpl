Button_text {
  id:t='<<id>>'

  <<#onClick>>
    <<#delayed>>_<</delayed>>on_click:t='<<onClick>>'
  <</onClick>>

  <<@actionParamsMarkup>>

  <<#isHidden>>
    display:t='hide'
    enable:t='no'
  <</isHidden>>

  buttonWink {}
  buttonGlance {}

  content {
    position:t='relative'
    flow:t='horizontal'
    pos:t='(pw-w)/2, (ph-h)/2'
    css-hier-invalidate:t='yes'

    <<#firstIcon>>
      img {
        size:t='1@cIco, 1@cIco'
        background-image:t='<<firstIcon>>'
        background-svg-size:t='1@cIco, 1@cIco'
        margin-right:t='1@blockInteraval'
      }
    <</firstIcon>>

    btnText {
      text:t='<<text>>'
    }

    <<#secondIcon>>
      img {
        size:t='1@cIco, 1@cIco'
        background-image:t='<<secondIcon>>'
        background-svg-size:t='1@cIco, 1@cIco'
        background-color:t='@buttonFontColor'
        margin-left:t='1@blockInteraval'
      }
    <</secondIcon>>
  }
}