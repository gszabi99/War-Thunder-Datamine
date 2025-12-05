root {
  blur {}
  blur_foreground {}
  tdiv {
    size:t='1@twoStepLoginBgrImgWidth, 1@twoStepLoginBgrImgHeight'
    pos:t='50%pw-50%w, 1@centeredWndTopPosUnderLogo'
    position:t='absolute'
    background-image:t='<<backgroundImg>>'
    background-color:t='@white'
    css-hier-invalidate:t='yes'
    total-input-transparent:t='yes'

    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<passText>>'
      }

      Button_close { id:t = 'btn_back' }
    }

    tdiv{
      width:t='0.4pw'
      pos:t='70@sf/@pf, 70@sf/@pf+1@frameHeaderHeight'
      position:t='absolute'
      flow:t='vertical'
      textareaNoTab {
        width:t='pw'
        position:t='relative'
        text:t='<<descText>>'
      }

      Button_text {
        visualStyle:t='twoStepLogin'
        position:t='relative'
        pos:t='0, 2@blockInterval'
        navButtonFont:t='yes'
        text:t = '<<passText>>'
        link:t='<<twoStepCodeAppURL>>'
        on_click:t = 'onMsgLink'
        btnName:t='X'
        ButtonImg{}
      }
    }

    Button_text {
      pos:t='pw-w-2@blockInterval, ph-h-2@blockInterval'
      position:t='absolute'
      visualStyle:t='noFrame'
      isLink:t='yes'
      isFeatured:t='yes'
      link:t='<<signInTroublesURL>>'
      on_click:t='onMsgLink'

      btnText{
        text:t='<<whyNeedText>>'
        underline{}
      }
      btnName:t='R3'
      ButtonImg {}
    }

    CheckBox {
      width:t='0.5pw'
      pos:t='2@blockInterval, ph-h-2@blockInterval'
      position:t='absolute'
      text:t='#options/dont_show_again'
      on_change_value:t='onDontShowChange'
      btnName:t='Y'
      ButtonImg{}
      CheckBoxImg{}
    }
  }
}
