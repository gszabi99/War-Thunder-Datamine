<<#items>>
tr {
  width:t='pw'
  keyHolder {
    tdiv {
      width:t='pw'
      key {
        textareaNoTab { text:t='#xray/filter/ammo' }
        textareaNoTab { text:t='#ui/space' }
        textareaNoTab { text:t='<<getCaliber>>' }
        textareaNoTab { text:t='#ui/colon' }
      }
      dashedLine {}
    }
  }
  value {
    flow:t='h-flow'
    moveX:t='linear'
    moveY:t='closest'
    navigatorShortcuts:t='yes'
    move-only-hover:t='yes'
    <<#bullets>>
    tooltipLink {
      <<#isNotLink>>isNotLink:t='yes'<</isNotLink>>
      textareaNoTab {
        text:t='<<getLocName>>'
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
    <</bullets>>
  }
}
<</items>>