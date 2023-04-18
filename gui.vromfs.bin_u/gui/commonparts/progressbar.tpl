<<#btnOnDec>>
  Button_text {
    id:t='btn_dec'
    text:t='#ui/minus'
    square:t='yes'
    on_click:t='<<btnOnDec>>'
    tooltip:t='#weaponry/descreaseValue'
    <<#disable>>
      enable:t='no'
    <</disable>>
  }
<</btnOnDec>>

invisSlider {
  id:t='progress_slider'
  size:t='fw, 1@sliderRowHeight'
  pos:t='0, 50%ph-50%h'
  position:t='relative'
  margin:t='0.5@sliderThumbWidth + 1@blockInterval, 0'
  value:t='0'
  min:t='0'
  max:t='<<maxValue>>'
  <<#onChangeSliderValue>>
    on_change_value:t='<<onChangeSliderValue>>'
  <</onChangeSliderValue>>
  <<#disable>>
    enable:t='no'
  <</disable>>

  <<#needOldSlider>>
    expProgress {
      id:t='old_progress'
      width:t='pw'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t="absolute"
      type:t='old'
      value:t='0'
      max:t='<<maxValue>>'
      <<#disable>>
        inactiveColor:t='yes'
      <</disable>>
    }
  <</needOldSlider>>

  <<#needNewSlider>>
    expProgress {
      id:t='new_progress'
      width:t='pw'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t="absolute"
      type:t='new'
      value:t='<<value>>'
      max:t='<<maxValue>>'
      <<#disable>>
        inactiveColor:t='yes'
      <</disable>>
    }
  <</needNewSlider>>

  <<#sliderButton>>
    sliderButton {
      type:t='<<type>>'
      <<#disable>>
        enable:t='no'
      <</disable>>
      img {
        <<#showWhenSelected>>
          showWhenSelected:t='yes'
        <</showWhenSelected>>
      }
      <<^disable>>
        textareaNoTab {
          id:t='slider_button_text'
          top:t='-h'
          left:t='50%pw-50%w'
          position:t='absolute'
          talign:t='left'
          text:t='<<sliderButtonText>>'
        }
      <</disable>>
    }
  <</sliderButton>>
}

<<#btnOnInc>>
  Button_text {
    id:t='btn_inc'
    text:t='#keysPlus'
    square:t='yes'
    on_click:t='<<btnOnInc>>'
    tooltip:t='#weaponry/increaseValue'
    <<#disable>>
      enable:t='no'
    <</disable>>
  }
<</btnOnInc>>

<<#btnOnMax>>
  Button_text {
    id:t = 'btn_max'
    text:t = '#profile/maximumExp'
    on_click:t='<<btnOnMax>>'
    inactiveColor:t='no'
    <<#disable>>
      enable:t='no'
    <</disable>>
    <<#shortcut>>
      btnName:t='<<shortcut>>'
      ButtonImg {}
    <</shortcut>>
    <<^shortcut>>
      <<#shortcutIcon>>
        hasConsoleImage:t='yes'
        ButtonImg {
          showOnSelect:t='yes'
          btnName:t='<<shortcutIcon>>'
        }
      <</shortcutIcon>>
      <<^shortcutIcon>>
        showConsoleImage:t='no'
      <</shortcutIcon>>
    <</shortcut>>
  }
<</btnOnMax>>
