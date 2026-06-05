<<#isShowSliderValue>>
tdiv {
  size:t='pw, ph'
  flow:t='vertical'

  textareaNoTab {
    id:t='<<id>>_text_value'
    position:t='absolute'
    text:t='<<text_value>>'
  }
<</isShowSliderValue>>

  slider {
    id:t='<<id>>'
    position:t='absolute'
    min:t='<<minVal>>'
    max:t='<<maxVal>>'
    step:t='<<step>>'
    value:t='<<value>>'
    <<@classProp>>
    clicks-by-points:t='<<clickByPoints>>'
    fullWidth:t='<<fullWidth>>'
    on_change_value:t='<<cb>>'

    focus_border{}
    tdiv{}
  }
<<#isShowSliderValue>>
}
<</isShowSliderValue>>
