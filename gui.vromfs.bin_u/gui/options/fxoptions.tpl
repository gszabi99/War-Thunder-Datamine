tdiv {
  size:t='0.96sw, 0.96sh'
  pos:t='50%sw-50%w, 50%sh-50%h'

  frame {
    behaviour:t='moveObj'
    class:t='wndNav'
    flow:t='vertical'
    width:t='0.7@sf'
    min-width:t='2@sliderWidth + 7@optPad'
    total-input-transparent:t='yes'

    frame_header {
      activeText {
        text:t = '<<headerText>>'
        caption:t='yes'
      }
      Button_close {}
    }

    table {
      id:t='options_list'
      behavior:t = 'PosOptionsNavigator';
      class:t = 'optionsTable'
      width:t='pw'
      baseRow:t = 'yes';
      selfFocusBorder:t="yes"

      include "gui/options/verticalOptions"
    }

    navBar {
      navLeft {
        Button_text {
          id:t="button_reset";
          text:t='#options/resetToDefaults';
          _on_click:t = 'onResetToDefaults'
          btnName:t='X'
          ButtonImg {}
        }
      }
    }
  }
}
