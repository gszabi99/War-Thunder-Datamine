root {
  blur {}
  blur_foreground {}

  frame {
    id:t='wnd_frame'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='relative'
    class:t='wnd'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<headerText>>'
      }

      Button_close {}
    }

    tdiv {
      flow:t='vertical'
      tdiv {
        id:t='wnd_content'
        left:t='0.5pw-0.5w'
        position:t='relative'
        <<#qrCode>>
        include "gui/commonParts/qrCode"
        <</qrCode>>
      }

      tdiv {
        left:t='0.5pw-0.5w'
        position:t='relative'
        margin-top:t='1@blockInterval'

        <<#isAllowExternalLink>>
        Button_text {
          id:t='btn_link'
          text:t='<<urlWithoutTags>>'
          hideText:t='yes'
          link:t='<<baseUrl>>'
          externalLink:t='yes'
          visualStyle:t='noFrame'
          margin-top:t='1@blockInterval'
          btnName:t='X'
          on_click:t='onMsgLink'
          ButtonImg{}
          btnText {
            id:t='btn_link_text'
            text:t='<<urlWithoutTags>>'
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
    }
  }

  timer {
    id:t='wnd_update'
    timer_handler_func:t='onUpdate'
    timer_interval_msec:t='300000'
  }

  gamercard_div {
    include "gui/gamercardTopPanel.blk"
    include "gui/gamercardBottomPanel.blk"
  }
}
