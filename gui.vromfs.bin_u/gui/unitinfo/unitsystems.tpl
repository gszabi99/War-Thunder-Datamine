<<#items>>
tooltipLink {
  max-width:t='pw'
  <<#isNotLink>>isNotLink:t='yes'<</isNotLink>>
  textareaNoTab {
    text:t='<<itemName>>'
    <<#isTooltipByHold>>
    tooltipId:t='<<tooltipId>>'
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
  }
}
<</items>>