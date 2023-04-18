<<#checkbox>>
CheckBox {
  id:t='<<id>>'
  <<#textWidth>>
  width:t='<<textWidth>>+1@cIco+1@checkboxSize'
  <</textWidth>>
  pos:t='0, 0'
  position:t='relative'
  value:t='<<#value>>yes<</value>><<^value>>no<</value>>'
  text:t='<<text>>'
  tooltip:t='<<tooltip>>'
  <<#funcName>>
    on_change_value:t='<<funcName>>'
  <</funcName>>

  <<#image>>
    class:t='with_image'
  <</image>>

  <<#isHidden>>
    display:t='hide'
    enable:t='no'
  <</isHidden>>

  <<#isDisable>>
    enable:t='no'
  <</isDisable>>

  <<#image>>
    infoImg { background-image:t='<<image>>' }
  <</image>>

  <<@specialParams>>

  CheckBoxImg {}
}
<</checkbox>>
