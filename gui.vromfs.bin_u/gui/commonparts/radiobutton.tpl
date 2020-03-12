<<#radiobutton>>
RadioButton {
  tooltip:t='<<tooltip>>'
  text:t='<<text>>'

  <<#selected>>
    selected:t='yes'
  <</selected>>

  RadioButtonImg{}
  <<#image>>
    RadioButtonDescImg { background-image:t='<<image>>' }
  <</image>>
}
<</radiobutton>>