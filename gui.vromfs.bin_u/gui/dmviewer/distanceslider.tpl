slider {
  id:t='<<id>>'
  style:t='width:@sliderWidth - 2@sliderButtonSquareHeight - 1@sliderThumbWidth - 2@blockInterval;'
  pos:t='0, ph/2-h/2'
  position:t='relative'
  margin:t='1@sliderButtonSquareHeight + 0.5@sliderThumbWidth + 1@blockInterval, 0'
  min:t='<<#min>><<min>><</min>><<^min>>0<</min>>'
  max:t='<<max>>'
  optionAlign:t='<<step>>'
  value:t='<<value>>'
  snap-to-values:t='yes'
  clicks-by-points:t='no'
  on_change_value:t='<<onChangeSliderValue>>'

  tdiv {
    <<#containerId>>
    id:t=<<containerId>>
    <</containerId>>
    width:t='@sliderWidth'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    total-input-transparent:t='yes'

    <<#btnOnDec>>
    Button_text {
      id:t='buttonDec'
      text:t='-'
      square:t='yes'
      on_click:t='<<btnOnDec>>'
      tooltip:t='#hotkeys/rangeDec'
    }
    <</btnOnDec>>

    tdiv { width:t='fw' }

    <<#btnOnInc>>
    Button_text {
      id:t='buttonInc'
      text:t='+'
      square:t='yes'
      on_click:t='<<btnOnInc>>'
      tooltip:t='#hotkeys/rangeInc'
    }
    <</btnOnInc>>
  }

  sliderButton {}
}