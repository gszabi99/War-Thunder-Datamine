root {
  background-color:t='@modalShadeColor'
  tdiv {
    size:t='1@twoStepLoginBgrImgWidth, 1@twoStepLoginBgrImgHeight'
    pos:t='0.5pw-0.5w, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)'
    position:t='absolute'
    class:t='wndNav'
    background-image:t='#ui/images/two_step_form_bg'
    background-color:t='@white'
    css-hier-invalidate:t='yes'
    total-input-transparent:t='yes'

    Button_close {
      id:t = 'btn_back'
      on_click:t='goBack'
    }
    tdiv {
      width:t='0.3pw'
      pos:t='20@sf/@pf, 70@sf/@pf'
      position:t='absolute'

      tdiv {
        position:t='relative'
        size:t='1@twoStepLoginLogoSIze, 1@twoStepLoginLogoSIze'
        background-svg-size:t='1@twoStepLoginLogoSIze, 1@twoStepLoginLogoSIze'
        background-image:t='!ui/gaijin_logo_snail.svg'
        background-color:t='#80FFFFFF'
      }

      tdiv {
        width:t='pw-20@sf/@pf-1@twoStepLoginLogoSIze'
        pos:t='1@twoStepLoginLogoSIze, 0'
        position:t='absolute'
        flow:t='vertical'

        textareaNoTab {
          width:t='pw'
          position:t='relative'
          text:t='#mainmenu/account'
        }

        text {
          position:t='relative'
          text:t='#mainmenu/GaijinNet'
          normalBoldFont:t='yes'
        }
      }
    }

    img {
      size:t='1@twoStepLoginImgWidth, 1@twoStepLoginImgHeight'
      pos:t='pw-w, 0.5ph-0.5h'
      position:t='absolute'
      background-image:t='<<authTypeImg>>'
    }

    tdiv{
      width:t='0.4pw'
      pos:t='0.3pw, 0.5ph-0.5h'
      position:t='absolute'
      flow:t='vertical'
      textareaNoTab {
        width:t='pw'
        position:t='relative'
        text:t='#mainmenu/2step/EnhancedProtection'
        bigBoldFont:t='yes'
      }
      textareaNoTab {
        id:t='verStatus'
        width:t='pw'
        position:t='relative'
        padding:t='0, 1@blockInterval'
        text:t='<<verStatusText>>'
        tooltip:t='#mainmenu/2stepVerifCode/tooltip'
      }
      EditBox {
        id:t = 'loginbox_code'
        size:t='290@sf/@pf, 70@sf/@pf'
        position:t='relative'
        padding:t='0, 1@blockInterval'
        withTab:t='yes'
        mouse-focusable:t='yes'
        multiline:t='no'
        max-len:t='6'
        _on_activate:t = 'onSubmit'
        char-mask:t='1234567890'
        twoStepType:t='yes'
        text:t=''
      }
      Button_text {
        id:t='loginBtn'
        visualStyle:t='twoStepLogin'
        position:t='relative'
        pos:t='0, 1@blockInterval'
        on_click:t = 'onSubmit'

        btnText{
          text:t = '#msgbox/btn_signIn'
          pos:t='0.5pw-0.5w, 0.5ph-0.5h'
        }
        btnName:t='X'
        ButtonImg{}
      }
      <<^isMailAuth>>
      Button_text {
        pos:t='0, 1@blockInterval'
        position:t='relative'
        visualStyle:t='noFrame'
        isLink:t='yes'
        isFeatured:t='yes'
        link:t='#url/2step/restoreProfile'
        on_click:t='onMsgLink'

        btnText{
          text:t='#mainmenu/2step/lostAccess'
          underline{}
        }
        btnName:t='L3'
        ButtonImg {}
      }
      <</isMailAuth>>
      Button_text {
        pos:t='0, 1@blockInterval'
        position:t='relative'
        visualStyle:t='noFrame'
        isLink:t='yes'
        isFeatured:t='yes'
        link:t='#url/2step/signInTroubles'
        on_click:t='onMsgLink'

        btnText{
          text:t='#mainmenu/2step/signInTroubles'
          underline{}
        }
        btnName:t='R3'
        ButtonImg {}
      }
    }
    CheckBox {
      id:t='loginbox_code_remember_this_device'
      width:t='0.5pw'
      pos:t='1@blockInterval, ph-h-1@blockInterval'
      position:t='absolute'
      text:t='#options/remember_cur_device'
      <<#isRememberDevice>>
      value:t='yes'
      <</isRememberDevice>>
      onlyA:t='yes'
      btnName:t='A'
      ButtonImg{}
      CheckBoxImg{}
    }
    textareaNoTab {
      id:t='currTimeText'
      width:t='<<timerWidth>>'
      pos:t='pw-w-1@blockInterval, ph-h'
      position:t='absolute'
      text:t=''
    }
  }
}