<<#items>>
tooltipLink {
  <<#isNotLink>>isNotLink:t='yes'<</isNotLink>>
  textareaNoTab {
    text:t='<<itemName>>'
    tooltip:t='$tooltipObj'
    tooltipId:t='<<tooltipId>>'
    tooltipObj {
      tooltipId:t='<<tooltipId>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
  }
}
<<^isLastItem>>
textareaNoTab { text:t=', '}
<</isLastItem>>
<</items>>