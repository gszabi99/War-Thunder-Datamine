<<#itemsForChoose>>
img {
  id:t='<<id>>'
  size:t='<<sizeX>>, <<sizeY>>'
  margin:t='<<spaceX>>, <<spaceY>>'
  background-image:t='<<image>>'
  selected:t='<<selected>>'
  interactive:t='yes'
  css-hier-invalidate:t='yes'
  input-transparent:t='yes'

  <<#tooltipText>>
  tooltip:t='<<tooltipText>>'
  <</tooltipText>>

  <<^enabled>>
  tdiv {
    pos:t='0, ph-h'
    position:t='absolute'
    size:t='pw, ph/2'
    background-svg-size:t='pw, ph/2'
    background-image:t='!ui/images/profile/wnd_gradient.svg'
    background-color:t='@black'
    background-repeat:t='expand-svg'
  }
  <</enabled>>

  focus_border {}

  <<#tooltipId>>
  title:t='$tooltipObj'
  tooltipObj {
    tooltipId:t='<<tooltipId>>'
    display:t='hide'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
  }
  <</tooltipId>>
}
<</itemsForChoose>>