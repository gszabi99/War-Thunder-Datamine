root {
  bgrStyle:t='fullScreenWnd'
  blur {}
  blur_foreground {}

  img {
    position:t='absolute'
    size:t='sw, 0.145sw'
    background-image:t='#ui/images/steam_rate_bg?P1'

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
      tdiv {
        width:t='fw'
        pos:t='0, 50%ph-50%h'
        position:t='relative'

        textarea {
          pos:t='pw-w, 0'
          position:t='relative'
          text:t='War Thunder'
          bigBoldFont:t='yes'
          overlayTextColor:t='active'
        }
      }
    }
  }

  frame {
    id:t='wnd_frame'
    size:t='@rw, @rh'
    pos:t='0.5pw-0.5w, 0.5ph-0.5h'
    position:t='absolute'
    class:t='wndNav'
    fullScreenSize:t='yes'

    frame_header { Button_close {} }
  }

  tdiv {
    size:t='0.75sh, 0.5625*sh'
    pos:t='0.5sw-0.5w, 0.5sh-0.5h'
    position:t='absolute'
    flow:t='vertical'

    titleTextArea {
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
      width:t='pw'
      text:t='#msgbox/steam/rate_review'
    }

    navBar {
      class:t='embedded'
      isTransparent:t='yes'
      navLeft {
        Button_text {
          text:t='#msgbox/goToSteam'
          on_click:t='onApply'
          visualStyle:t='steam'
          focusBtnName:t='A'
          showConsoleImage:t='no'
          externalLink:t='yes'
        }
      }
      
      navRight {
        Button_text {
          text:t='#mainmenu/btnClose'
          on_click:t='goBack'
          visualStyle:t='steam'
          focusBtnName:t='A'
          showConsoleImage:t='no'
        }
      }
    }
  }
}