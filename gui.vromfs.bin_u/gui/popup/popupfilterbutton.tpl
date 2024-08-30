tdiv {
  flow:t='horizontal'
  Button_text {
    id:t='filter_button'
    <<#buttonPos>>
    pos:t='<<buttonPos>>'
    position:t='absolute'
    <</buttonPos>>
    class:t='image'
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
    img {
      background-image:t='#ui/gameuiskin#filter_icon.svg'
    }
    textarea {
      id:t='filter_button_text'
      pos:t='pw-w, 0.5ph-0.5h'
      padding-right:t='1@buttonImgPadding'
      position:t='absolute'
    }
  }
}
