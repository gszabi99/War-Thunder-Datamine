root {
  blur {}
  blur_foreground {}

  frame {
    id:t='wnd_frame'
    min-width:t='0.6@sf'
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

    tdiv {
      width:t='pw'
      flow:t='vertical'
      margin:t='1@blockInterval, 0'

      textAreaCentered {
        width:t='pw'
        left:t='0.5pw-0.5w'
        position:t='relative'
        text:t='<<infoText>>'
        margin-bottom:t='1@blockInterval'
      }
      tdiv {
        id:t='wnd_content'
        left:t='0.5pw-0.5w'
        position:t='relative'
        <<#qrCode>>
        include "%gui/commonParts/qrCode"
        <</qrCode>>
      }

      <<#needShowUrlLink>>
      tdiv {
        left:t='0.5pw-0.5w'
        position:t='relative'
        margin-top:t='1@blockInterval'

        <<#isAllowExternalLink>>
        Button_text {
          id:t='btn_link'
          text:t='#open_url_in_browser'
          hideText:t='yes'
          link:t='<<baseUrl>>'
          externalLink:t='yes'
          margin-top:t='1@blockInterval'
          btnName:t='X'
          on_click:t='onMsgLink'
          ButtonImg{}
          btnText {
            id:t='btn_link_text'
            text:t='#open_url_in_browser'
            underline {}
          }
        }
        <</isAllowExternalLink>>
        <<^isAllowExternalLink>>
        textareaNoTab {
          text:t='<<urlWithoutTags>>'
        }
        <</isAllowExternalLink>>
      }
      <</needShowUrlLink>>
    }

    <<#buttons>>
    navBar {
      navMiddle {
        include "%gui/commonParts/buttonsList"
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
