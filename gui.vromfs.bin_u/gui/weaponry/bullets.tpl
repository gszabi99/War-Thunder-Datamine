<<#addIco>>
img{
  size:t='pw,ph'
  pos:t='0, 0'
  position:t='absolute'
  background-image:t='<<img>>'
  background-svg-size:t='pw,ph'
}
<</addIco>>
<<#bullets>>
img{
  size:t='<<sizex>>,<<sizey>>'
  pos:t='<<posx>>, 0.5ph - 0.5h'
  position:t='absolute'
  background-image:t='<<image>>'
  background-repeat:t='aspect-ratio'
  background-svg-size:t='<<sizex>>,<<sizey>>'

  <<#useTooltip>>
  title:t='$tooltipObj'
  tooltip-float:t='horizontal'
  tooltipObj {
    id:t='tooltip_<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
  <<#tooltipDelayed>>
  tooltip-timeout:t='1000'
  <</tooltipDelayed>>
  <</useTooltip>>
}
<</bullets>>
