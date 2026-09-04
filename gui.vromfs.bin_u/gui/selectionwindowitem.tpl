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
  imgGradient {
    pos:t='0, ph-h'
    size:t='pw, ph/2'
    background-color:t='@black'
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