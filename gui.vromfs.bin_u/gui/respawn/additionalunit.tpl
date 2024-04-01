<<#units>>
additionalUnit{
  id:t='<<unitName>>'
  on_hover:t='::gcb.delayedTooltipHover'
  on_unhover:t='::gcb.delayedTooltipHover'

  behavior:t='Timer'
  timer_interval_msec:t='1000'

  <<^isFirst>>
  margin-left:t='2@blockInterval'
  <</isFirst>>
  flow:t='vertical'
  padding:t='1@blockInterval'
  textareaNoTab {
    normalFont:t='yes'
    text:t='<<unitFullName>>'
    halign:t='center'
  }
  tdiv {
    position:t='relative'
    height:t='fh'
    width:t='pw'
    margin-top:t='1@blockInterval'
    img {
      width:t='540/294h'
      height:t='fh'
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      background-image:t='<<unitImage>>'
      background-svg-size:t='540/294h, h'
      input-transparent:t='yes'
      css-hier-invalidate:t='yes'
    }
  }
  tooltip-float:t='horizontal'
  title:t='$tooltipObj'
  tooltipObj {
    tooltipId:t='<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
  isLocked:t='<<isLocked>>'
  <<#isSelected>>
  chosen:t='yes'
  <</isSelected>>
}
<</units>>