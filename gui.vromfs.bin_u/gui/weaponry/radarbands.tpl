tdiv {
  <<#radarBands>>
  tooltipLink {
    <<^tooltipId>>
    isNotLink:t='yes'
    <</tooltipId>>
    textareaNoTab {
      text:t='<<name>>'
      smallFont:t='yes'
      valign:t='center'

      <<#tooltipId>>
      <<#isTooltipByHold>>
      tooltipId:t='<<tooltipId>>'
      on_hover:t='::gcb.delayedTooltipHover'
      on_unhover:t='::gcb.delayedTooltipHover'
      <</isTooltipByHold>>
      <<^isTooltipByHold>>
      tooltip:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='<<tooltipId>>'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
      <</isTooltipByHold>>
      <</tooltipId>>
    }
  }
  <<^isLast>>
  textareaNoTab {
    text:t='#ui/slash'
    smallFont:t='yes'
    valign:t='center'
    overlayTextColor:t='minor'
  }
  <</isLast>>
  <</radarBands>>
}