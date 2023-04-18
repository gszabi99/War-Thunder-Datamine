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
    <<#isList>>
      ComboBox {
        id:t='<<id>>'
        width:t='pw'
        on_select:t='<<cb>>'
      }
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
  }
}
<</cells>>
