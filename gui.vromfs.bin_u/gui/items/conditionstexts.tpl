<<#rows>>
  <<#text>>
  textareaNoTab {
    width:t='pw'
    text:t='<<text>>'

    <<#tooltip>>
    tooltip:t='<<tooltip>>'
    <</tooltip>>

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
  <</text>>

  <<^text>>
  tdiv {
    width:t='pw'
    flow:t='h-flow';

    <<#subTexts>>
    textareaNoTab {
      max-width:t='pw'
      text:t='<<text>>'

      <<#tooltip>>
      tooltip:t='<<tooltip>>'
      <</tooltip>>

      <<#tooltipId>>
      tooltipObj {
        id:t='tooltip_<<tooltipId>>'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
      title:t='$tooltipObj'
      <</tooltipId>>
    }
    <</subTexts>>
  }
  <</text>>
<</rows>>
