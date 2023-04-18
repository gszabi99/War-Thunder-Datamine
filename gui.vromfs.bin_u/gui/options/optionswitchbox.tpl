SwitchBox {
  <<#id>>
  id:t='<<id>>'
  <</id>>

  value:t='<<#value>>yes<</value>><<^value>>no<</value>>'

  textChecked:t='<<textChecked>><<^textChecked>><<?options/yes>><</textChecked>>'
  textUnchecked:t='<<textUnchecked>><<^textUnchecked>><<?options/no>><</textUnchecked>>'

  <<#cb>>
  on_change_value:t='<<cb>>'
  <</cb>>

  SwitchSliderBg { SwitchSliderBgOn {} SwitchSlider {} }
}