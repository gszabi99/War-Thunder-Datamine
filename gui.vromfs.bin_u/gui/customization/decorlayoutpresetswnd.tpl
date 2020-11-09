root {
  background-color:t='@modalShadeColor'
  on_click:t='goBack'

  frame {
    id:t='wnd_frame'
    size:t='750@sf/@pf, 600@sf/@pf'
    pos:t='pw/2-w/2, ph/2-h/2'
    position:t='relative'
    class:t='wndNav'
    css-hier-invalidate:t='yes'
    input-transparent:t='no'
    frame_header {
      activeText { id:t='wnd_title'; caption:t='yes'; text:t='#customization/decorLayout/title'}
      Button_close { id:t='btn_back' }
    }

    tdiv {
      id:t='wnd_content'
      size:t='pw, ph'
      flow:t='vertical'

      textareaNoTab {
        width:t='pw'
        padding:t='0, @blockInterval'
        text:t='#customization/decorLayout/desc1'
      }

      ComboBox {
        id:t='master_skin'
        size:t='pw, 0.6@buttonHeight'
        on_select:t='onMasterSkinSelect'

        behaviour:t='wrapBroadcast'
        on_wrap_up:t='onWrapUp'
        on_wrap_down:t='onWrapDown'
        navigatorShortcuts:t='yes'
        focusFrame:t='yes'
      }

      textareaNoTab {
        width:t='pw'
        padding:t='0, @blockInterval'
        text:t='#customization/decorLayout/desc2'
      }

      tdiv {
        size:t='pw, @buttonHeight'
        padding:t='-1@dp, 0'
        modBlockHeader {
          style:t='position:relative'
          size:t='fw, ph'
          text:t='#customization/decorLayout/linkedSkins'
        }
        modBlockHeader {
          style:t='position:relative'
          size:t='35%pw +5@sf/@pf, ph'
          text:t='#customization/decorLayout/layoutName'
        }
      }

      MultiSelect {
        id:t='destination_skins'
        size:t='pw, fh'
        pos:t='0, 1@dp'
        position:t='relative'
        overflow-y:t='auto'
        flow:t='vertical'
        on_select:t='onDestinationSkinSelect'

        on_wrap_up:t='onWrapUp'
        on_wrap_down:t='onWrapDown'
        navigatorShortcuts:t='yes'
        childsActivate:t='yes'

        <<#list>>
        multiOption {
          id:t='<<id>>'
          padding-left:t='1@blockInterval'

          ButtonImg {
            size:t='@cIco, @cIco'
            top:t='ph/2-h/2'
            position:t='relative'
            margin-right:t='1@blockInterval'
            btnName:t='A'
            showOrNoneOn:t='selectedOnConsole'
          }
          CheckBoxImg {}
          cardImg {
            margin-right:t='@blockInterval'
            background-image:t='<<icon>>'
          }
          multiOptionText {
            width:t='fw'
            textStyle:t='textarea'
            text:t='<<text>>'
          }
          multiOptionText {
            id:t='preset_of_<<id>>'
            width:t='35%pw -5@sf/@pf'
            textStyle:t='textarea'
          }
        }
        <</list>>
      }
    }

    navBar {
      navLeft {
        Button_text {
          id:t='btn_rename'
          text:t='#msgbox/btn_rename'
          on_click:t='onBtnRename'
          btnName:t='Y'
          ButtonImg{}
        }
      }

      navRight {
        Button_text {
          id:t='btn_apply'
          text:t='#mainmenu/btnApply'
          btnName:t='X'
          on_click:t='onStart'
          ButtonImg {}
        }
      }
    }
  }
}
