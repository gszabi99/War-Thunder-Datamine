<<#items>>
tdiv {
  position:t='relative'
  width:t='<<itemSize>>'
  flow:t='vertical'
  <<#iconMargin>>
  margin:t='<<iconMargin>>'
  <</iconMargin>>

  tdiv {
    position:t='relative'
    size:t='pw, pw'
    <<@itemIcon>>
  }
  textareaNoTab {
    position:t='relative'
    max-width:t='pw'
    smallFont:t='yes'
    text-align:t='center'
    left:t='(pw-w)/2'
    text:t='<<text>>'
  }
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
<</items>>