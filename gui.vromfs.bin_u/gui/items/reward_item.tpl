<<#items>>
rewardItemDiv {
  smallFont:t='yes';
  total-input-transparent:t='yes'
  css-hier-invalidate:t='yes'

  tdiv {
    size:t='pw, ph'
    text-halign:t='center'
    css-hier-invalidate:t='yes'

    tdiv {
      size:t='pw, ph'
      overflow:t='hidden'
      css-hier-invalidate:t='yes'
      <<@layered_image>>
    }
  }

  <<#hasFocusBorder>>
  focus_border {}
  <</hasFocusBorder>>

  <<#tooltipId>>
  tooltipObj {
    id:t='tooltip_<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
  title:t='$tooltipObj';
  tooltip-float:t='<<^tooltipFloat>>horizontal<</tooltipFloat>><<tooltipFloat>>'
  <</tooltipId>>
  <<^tooltipId>>
  tooltip:t='<<tooltip>>'
  <</tooltipId>>
}
<</items>>
