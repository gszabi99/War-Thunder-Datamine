root {
  blur {}
  blur_foreground {}
  tdiv {
    size:t='1@twoStepLoginBgrImgWidth, 1@twoStepLoginBgrImgHeight'
    pos:t='0.5pw-0.5w, 0.5ph-0.5h'
    position:t='absolute'
    padding:t='1@blockInterval'
    background-image:t='<<backgroundImg>>'
    background-color:t='@white'
    css-hier-invalidate:t='yes'
    total-input-transparent:t='yes'

    Button_close {
      id:t = 'btn_back'
      _on_click:t='goBack'
    }

    tdiv {
      size:t='fw, fh'
      textareaNoTab {
        position:t='relative'
        text:t='#mainmenu/2step/EnhancedProtection'
      }

      img {
        size:t='1@twoStepLoginImgWidth, 1@twoStepLoginImgHeight'
        pos:t='0.77pw-0.5w, 0.5ph-0.5h'
        position:t='absolute'
        background-image:t='<<authTypeImg>>'
        background-repeat:t='aspect-ratio'
      }

      tdiv{
        width:t='0.4pw'
        pos:t='0.14pw, 0.5ph-0.5h'
        position:t='absolute'
        flow:t='vertical'

        textareaNoTab {
          id:t='verStatus'
          width:t='pw'
          position:t='relative'
          mediumFont:t='yes'
          text:t='#mainmenu/2step/confirmSign'
        }

        textareaNoTab {
          id:t='verStatus'
          width:t='pw'
          position:t='relative'
          pos:t='0, 1@blockInterval'
          text:t='<<verStatusText>>'
          tooltip:t='#mainmenu/2stepVerifCode/tooltip'
        }

        EditBox {
          id:t = 'loginbox_code'
          size:t='290@sf/@pf, 60@sf/@pf'
          position:t='relative'
          margin:t='0, 1@blockInterval'
          twoStepType:t='yes'
          max-len:t='6'
          _on_activate:t = 'onSubmit'
          char-mask:t='1234567890'
          text:t=''
        }

        CheckBox {
          id:t='loginbox_code_remember_this_device'
          width:t='pw'
          text:t='#options/remember_cur_device'
          <<#isRememberDevice>>
          value:t='yes'
          <</isRememberDevice>>
          btnName:t='Y'
          ButtonImg{}
          CheckBoxImg{}
        }

        tdiv {
          size:t='290@sf/@pf, 60@sf/@pf'
          position:t='relative'
          pos:t='0, 1@blockInterval'
          Button_text {
            id:t='loginBtn'
            visualStyle:t='twoStepLogin'
            parentWidth:t='yes'
            useParentHeight:t='yes'
            noMargin:t='yes'
            _on_click:t = 'onSubmit'

            btnText{
              normalBoldFont:t='yes'
              text:t = '#msgbox/btn_signIn'
            }
            btnName:t='X'
            ButtonImg{}
          }
        }
      }
      tdiv {
        width:t='pw'
        pos:t='0, ph-h'
        position:t='absolute'

        <<#isShowRestoreLink>>
        button {
          pos:t='0, ph-h'
          position:t='relative'
          noMargin:t='yes'
          smallFont:t='yes'
          class:t='link'
          text:t='#mainmenu/2step/lostAccess'
          link:t='<<restoreProfileURL>>'
          on_click:t='onMsgLink'
          underline{}
        }
        <</isShowRestoreLink>>
        button {
          pos:t='0, ph-h'
          position:t='relative'
          noMargin:t='yes'
          smallFont:t='yes'
          class:t='link'
          <<#isShowRestoreLink>>
          margin-left:t='2@blockInterval'
          <</isShowRestoreLink>>
          text:t='#mainmenu/2step/signInTroubles'
          link:t='<<signInTroublesURL>>'
          on_click:t='onMsgLink'
          underline{}
        }

        textareaNoTab {
          id:t='currTimeText'
          width:t='<<timerWidth>>'
          pos:t='pw-w, ph-h'
          position:t='absolute'
          smallFont:t='yes'
          text:t=''
        }
      }
    }
  }
}