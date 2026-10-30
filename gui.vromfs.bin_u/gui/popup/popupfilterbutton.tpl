tdiv {
  flow:t='horizontal'
  Button_text {
    id:t='filter_button'
    <<#buttonPos>>
    pos:t='<<buttonPos>>'
    position:t='root'
    <</buttonPos>>
    <<#hasBtnIcon>>
    class:t='image'
    <</hasBtnIcon>>
    noMargin:t='yes'
    width:t='<<btnWidth>>'
    visualStyle:t='<<visualStyle>>'
    _on_click:t='<<on_click>>'
    <<#btnName>>
    btnName:t='<<btnName>>'
    ButtonImg{}
    <</btnName>>
    <<^btnName>>
    btnName:t=''
    <</btnName>>
    <<#hasBtnIcon>>
    img {
      background-image:t='#ui/gameuiskin#filter_icon.svg'
    }
    <</hasBtnIcon>>
    <<^hasBtnIcon>>
    btnText {
      pos:t='1@buttonTextPadding, 0.5ph-0.5h'
      position:t='absolute'
      text:t='<<btnTitle>>'
    }
    <</hasBtnIcon>>
    textarea {
      id:t='filter_button_text'
      pos:t='pw-w-1@buttonImgPadding, 0.5ph-0.5h'
      position:t='absolute'
    }
  }
}
