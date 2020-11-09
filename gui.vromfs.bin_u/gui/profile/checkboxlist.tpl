<<#checkBoxes>>
  CheckBox {
    id:t='<<id>>'
    text:t=''
    value:t='<<value>>'
    on_change_value:t='<<onChangeFunction>>'
    <<#isLastCheckBox>>
      isLastCheckBox:t='yes'
    <</isLastCheckBox>>
    CheckBoxImg{}
    <<#image>>
      class:t='with_image'
      infoImg {
        background-image:t='<<image>>'
      }
    <</image>>
    tooltip:t='<<tooltip>>'
  }
<</checkBoxes>>