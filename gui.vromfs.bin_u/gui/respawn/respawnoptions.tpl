<<#cells>>
cell {
  id:t='<<id>>_tr'
  width:t='50%pw - 0.5'
  display:t='hide'
  td {
    cellType:t='top'
    overflow-x:t='hidden'
    optiontext {
      text:t ='<<label>>'
    }
  }
  td {
    cellType:t='bottom'
    <<#tooltipName>>
    tooltip:t="$tooltipObj"
    <</tooltipName>>
    <<#isList>>
      ComboBox {
        id:t='<<id>>'
        width:t='pw'
        on_select:t='<<cb>>'
      }
    <<#tooltipName>>
    tooltipObj {
      id:t='<<tooltipName>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
    <</tooltipName>>
    <</isList>>
    <<#isCheckbox>>
      SwitchBox {
        id:t='<<id>>'
        value:t='no'
        textChecked:t='<<?options/yes>>'
        textUnchecked:t='<<?options/no>>'
        on_change_value:t='<<cb>>'
        SwitchSliderBg { SwitchSliderBgOn {} SwitchSlider {} }
      }
    <</isCheckbox>>
    <<#isSlider>>
    tdiv {
      size:t='pw, ph'
      flow='vertical'
      textareaNoTab {
        id:t='value_<<id>>'
        position:t='relative'
        pos:t='1@comboOptionPadding,-2@sf/@pf'
      }
      slider {
        id:t='<<id>>'
        pos:t='0,-6@sf/@pf'
        clicks-by-points:t='no'
        on_change_value:t='<<cb>>'
        focus_border{}
      }
    }
    <</isSlider>>
  }
}
<</cells>>
