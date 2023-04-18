root {
  type:t='big'
  blur {}
  blur_foreground {}

  frame {
    pos:t='50%pw-50%w, 40%ph-40%h';
    position:t='absolute';
    class:t='wndNav';
    countryExpType:t='centered';

    frame_header {
      activeText {
        caption:t='yes';
        text:t='<<headerText>>';
      }
      Button_close {}
    }

    textAreaCentered {
      width:t='pw';
      text-align:t='center';
      padding-left:t='1.5*@scrn_tgt/100.0';
      padding-right:t='1.5*@scrn_tgt/100.0';
      text:t='<<messageText>>';
    }

    tdiv {
      size:t='pw, 11*@scrn_tgt/100.0';
      pos:t='0,5*@scrn_tgt/100.0';
      position:t='relative';

      HorizontalListBox {
        id:t='countries_list';
        pos:t='50%pw-50%w,50%ph-50%h';
        position:t='relative';
        class:t='countries';
        activeAccesskeys:t='LeftRight';
        shortcutActivate:t='';
        on_select:t='onCountrySelect';
        on_dbl_click:t='onApply';

        <<#shopFilterItems>>
        shopFilter {
          id:t='<<shopFilterId>>';
          shopFilterImg {
            background-image:t='<<shopFilterImage>>';
          }
          shopFilterText{
            text:t='<<shopFilterText>>';
          }
        }
        <</shopFilterItems>>
      }
    }

    navBar {
      hintDiv {
        hintText {}
      }

      <<#showOkButton>>
      navLeft {
        Button_text {
          id:t='btn_changeMode';
          text:t='#mainmenu/changeMode';
          btnName:t='Y';
          _on_click:t='onChangeMode';
          ButtonImg {}
        }
      }
      navRight {
        Button_text {
          id:t='btn_apply';
          text:t='#mainmenu/btnOk';
          btnName:t='A';
          _on_click:t='onApply';
          ButtonImg {}
        }
      }
      <</showOkButton>>
      <<^showOkButton>>
      navMiddle {
        Button_text {
          id:t='btn_changeMode';
          text:t='#mainmenu/changeMode';
          btnName:t='A';
          _on_click:t='onChangeMode';
          ButtonImg {}
        }
      }
      <</showOkButton>>

    }
  }
}
