rootUnderPopupMenu {
  on_click:t='onCancel'
  on_r_click:t='onCancel'
  input-transparent:t='yes'
}

popup_menu {
  id:t='popup_frame'
  cluster_select:t='yes'
  menu_align:t='<<align>>'
  pos:t='50%sw-50%w, 50%sh-50%h'
  position:t='root'
  total-input-transparent:t='yes'
  width:t='0.325*@scrn_tgt'
  height:t='0.185*@scrn_tgt'
  flow:t='vertical'

  Button_close { _on_click:t='onCancel'; smallIcon:t='yes'}

  textareaNoTab {
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    padding-top:t='1*@scrn_tgt/100.0'
    padding-bottom:t='2*@scrn_tgt/100.0'
    overlayTextColor:t='active'
    text:t='<<headerText>>'
  }

  tdiv {
    left:t='50%pw-50%w'
    position:t='relative'

    <<^needSlider>>
    display:t='hide'
    <</needSlider>>

    Button_text {
      id:t='buttonDec'
      text:t='-'
      square:t='yes'
      on_click:t='onButtonDec'
    }

    slider {
      id:t='amount_slider'
      size:t='20*@scrn_tgt/100.0, 2*@scrn_tgt/100.0'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      margin:t='0.5@sliderThumbWidth + 1@blockInterval, 0'

      min:t='<<minValue>>'
      max:t='<<maxValue>>'
      optionAlign:t='<<valueStep>>'
      value:t='<<curValue>>'
      on_change_value:t='onValueChange'
    }

    Button_text {
      id:t='buttonInc'
      text:t='+'
      square:t='yes'
      on_click:t='onButtonInc'
    }
  }

  textAreaCentered {
    id:t='cur_value_text'
    pos:t='50%pw-50%w, 1@blockInterval'
    position:t='relative'
    text:t=''
  }

  Button_text {
    position:t='relative'
    pos:t='50%pw-50%w, 1@blockInterval'
    noMargin:t='yes'
    btnName:t='A'
    text:t='<<buttonText>>'
    on_click:t='onAccept'
    ButtonImg{}
  }

  <<#hasPopupMenuArrow>>
  popup_menu_arrow{}
  <</hasPopupMenuArrow>>
}
