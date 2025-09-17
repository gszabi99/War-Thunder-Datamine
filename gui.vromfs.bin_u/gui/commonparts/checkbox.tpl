<<#checkbox>>
CheckBox {
  id:t='<<id>>'
  <<#textWidth>>
  width:t='<<textWidth>>+1@checkboxSize<<#image>>+1@cIco<</image>>'
  <</textWidth>>
  <<#hasMinWidth>>
  min-width:t='1@buttonWidth'
  <</hasMinWidth>>
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
    infoImg {
      size:t='@cIco, <<#imageAspectRatio>><<imageAspectRatio>><</imageAspectRatio>>@cIco'
      background-svg-size:t='@cIco, <<#imageAspectRatio>><<imageAspectRatio>><</imageAspectRatio>>@cIco'
      background-image:t='<<image>>'
    }
  <</image>>

  <<@specialParams>>

  CheckBoxImg {}
}
<</checkbox>>
