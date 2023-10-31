root {
  bgrStyle:t='fullScreenWnd'
  blur {}
  blur_foreground {}
  background-color:t='@fullScreenBgrColor'

  img {
    id:t='backgroundImg'
    size:t='sw, 752w/1584'
    max-width:t='(280/1920sw $min 0.26sh)1920/280'
    position:t='absolute'
    pos:t='0.5pw-0.5w, 0.5(ph+(280/1920sw $min 0.26sh)-h)'
    background-image:t='#ui/images/cat_fix'
    background-repeat:t='aspect-ratio'
    display:t='hide'
    tdiv {
      size:t='pw, ph'
      background-color:t='#7205090D'
    }
  }

  img {
    position:t='absolute'
    size:t='sw, 280/1920sw'
    max-height:t='0.26sh'
    background-image:t='#ui/images/steam_rate_bg?P1'
    background-repeat:t='aspect-ratio'

    tdiv {
      width:t='0.75@rh' //by size of frame 
      pos:t='50%pw-50%w, ph - h - 0.035@scrn_tgt'
      position:t='relative'
      img {
        position:t='relative'
        size:t='1@steamButtonWidth, 0.33@steamButtonWidth'
        background-image:t='@!ui/images/steam_logo.svg'
        background-svg-size:t='1@steamButtonWidth, 0.33@steamButtonWidth'
        background-repeat:t='aspect-ratio'
      }
    }
  }

  tdiv {
    width:t='@rw'
    pos:t='0.5pw-0.5w, @bh'
    position:t='absolute'
    Button_close { _on_click:t = 'goBack' }
  }

  tdiv {
    size:t='0.75sh,  0.5625*sh'
    pos:t='0.5sw-0.5w, 0.5sh-0.5h'
    position:t='absolute'
    flow:t='vertical'

    titleTextArea {
      id:t='rate_text'
      left:t='0.5pw-0.5w'
      top:t='0.7ph-0.5h'
      position:t='absolute'
      width:t='pw'
      shadeStyle:t='shadowed'
      text:t='#msgbox/steam/rate_review'
      input-transparent:t='yes'
    }

    navBar {
      class:t='embedded'
      isTransparent:t='yes'
      navLeft {
        Button_text {
          text:t='#mainmenu/btnClose'
          on_click:t='goBack'
          visualStyle:t='steam'
          focusBtnName:t='A'
          showConsoleImage:t='no'
        }
      }
      
      navRight {
        Button_text {
          text:t='#write_review'
          on_click:t='onApply'
          visualStyle:t='steam'
          focusBtnName:t='A'
          showConsoleImage:t='no'
          externalLink:t='yes'
        }
      }
    }
  }
}