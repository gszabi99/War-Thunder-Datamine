tdiv {
  width:t='pw'

  <<#hasPadding>>
  padding:t='0, 1@blockInterval'
  <</hasPadding>>

  <<#icon>>
  textareaNoTab {
    pos:t='0, 0'; position:t='relative'
    width:t='1@dIco'
    text:t=' '
    img {
      background-image:t='<<icon>>'
      pos:t='0, ph/2-h/2'; position:t='absolute'
      size:t='1@dIco, 1@dIco'
    }
  }
  <</icon>>

  <<#title>>
  textareaNoTab {
    pos:t='1@itemPadding, ph/2-h/2'
    position:t='relative'
    text:t='<<title>>'
  }
  <</title>>

  <<#count>>
  textareaNoTab {
    pos:t='0, ph/2-h/2'
    position:t='relative'
    text:t='<<count>>'
  }
  <</count>>

  <<#tooltipId>>
  tooltipObj {
    id:t='tooltip_<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
  title:t='$tooltipObj'
  tooltip-float:t='horizontal'
  <</tooltipId>>
}
