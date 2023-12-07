root {
  blur {}
  blur_foreground {}

  frame {
    id:t='wnd_frame'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='relative'
    class:t='<<#buttons>>wndNav<</buttons>><<^buttons>>wnd<</buttons>>'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<headerText>>'
      }

      Button_close {}
    }
    textAreaCentered {
      id:t='topHeader'
      max-width:t='pw'
      pos:t='50%pw-50%w, 0'
      padding-left:t='2@blockInterval'
      padding-right:t='2@blockInterval'
      position:t='relative'
      text:t='<<infoText>>'
      margin-bottom:t='1@blockInterval'
      css-hier-invalidate:t='yes'
    }
    tdiv {
      id:t='wnd_content'
      position:t='relative'
      flow:t='h-flow'
      include "%gui/commonParts/qrCodes.tpl"
    }

    <<#buttons>>
    navBar {
      navMiddle {
        include "%gui/commonParts/buttonsList.tpl"
      }
    }
    <</buttons>>
  }

  timer {
    id:t='wnd_update'
    timer_handler_func:t='onUpdate'
    timer_interval_msec:t='300000'
  }

  gamercard_div {
    include "%gui/gamercardTopPanel.blk"
    include "%gui/gamercardBottomPanel.blk"
  }
}
