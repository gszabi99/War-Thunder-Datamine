tdiv {
  width:t='@rw'
  max-height:t='@rh'
  pos:t='50%sw-50%w, 50%sh-50%h'
  position:t='root'
  flow:t='vertical'

  tdiv {
    width:t='pw'
    flow:t="h-flow"
    flow-align:t='center'
    padding-bottom:t='0.05@sf'

    SwitchBox {
      textChecked:t='activeTextColor'
      textUnchecked:t='commonTextColor'

      value:t='<<#isActiveColor>>yes<</isActiveColor>><<^isActiveColor>>no<</isActiveColor>>'
      on_change_value:t='onColorChange'

      SwitchSliderBg { SwitchSliderBgOn {} SwitchSlider {} }
    }

    SwitchBox {
      textChecked:t='border on'
      textUnchecked:t='border off'

      value:t='<<#needBorder>>yes<</needBorder>><<^needBorder>>no<</needBorder>>'
      on_change_value:t='onBorderChange'

      SwitchSliderBg { SwitchSliderBgOn {} SwitchSlider {} }
    }

    EditBox
    {
      size:t='0.5@sf, 2@buttonHeight'
      multiline:t='yes'
      text:t='<<fontsAdditionalText>>'
      on_change_value:t='onTextChange'
    }
  }

  tdiv {
    width:t='pw'
    max-height:t='fh'
    overflow-y:t='auto'
    flow:t="h-flow"
    flow-align:t='center'

    <<#textsList>>
    tdiv {
      id:t='<<id>>'
      max-width:t='0.3pw'
      margin:t='0.03@sf, 0.01@sf'

      behaviour:t='textArea'
      re-type:t='textarea'
      font:t='<<font>>'
      color:t='<<color>>'
      text:t='<<text>>'

      <<#needBorder>>border:t='yes'<</needBorder>>
      border-color:t='#808080'
    }
    <</textsList>>
  }
}