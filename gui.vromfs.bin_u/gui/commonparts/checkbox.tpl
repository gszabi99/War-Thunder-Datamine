<<#checkbox>>
CheckBox {
  id:t='<<id>>'
  pos:t='0, 0'
  position:t='relative'
  value:t='<<#value>>yes<</value>><<^value>>no<</value>>'
  text:t='<<text>>'
  tooltip:t='<<tooltip>>'
  <<#funcName>>
    on_change_value:t='<<funcName>>'
  <</funcName>>

  <<#useImage>>
    class:t='with_image'
  <</useImage>>

  <<#isHidden>>
    display:t='hide'
    enable:t='no'
  <</isHidden>>

  <<#isDisable>>
    enable:t='no'
  <</isDisable>>

  <<#useImage>>
    infoImg { background-image:t='<<useImage>>' }
  <</useImage>>

  <<@specialParams>>

  CheckBoxImg {}
}
<</checkbox>>
