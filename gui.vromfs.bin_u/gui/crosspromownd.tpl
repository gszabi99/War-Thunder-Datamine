root {
  blur {}
  blur_foreground {}

  frame {
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    width:t='80%sh'
    max-width:t='800*@sf/@pf + 2@framePadding'
    max-height:t='@rh'
    class:t='wndNav'

    frame_header {
      activeText {
        caption:t='yes'
        text:t='#shop/cross_promo_popup/title'
      }
      Button_close {}
    }

    img {
      width:t='pw'
      height:t='0.375w'
      max-width:t='800*@sf/@pf'
      max-height:t='300*@sf/@pf'
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      background-image:t=<<bannerSrc>>
    }

    tdiv {
      width:t='pw'
      max-height:t='fh'
      pos:t='0, 0.005@scrn_tgt'
      position:t='relative'
      flow:t='vertical'
      overflow-y:t='auto'

      textarea {
        width:t='pw'
        chapterTextAreaStyle:t='yes'
        hideEmptyText:t='yes'
        font-bold:t='@fontMedium'
        text:t='#shop/cross_promo_popup/text'
        padding-left:t='0.02@sf'
      }
    }

    navBar {
      navRight {
        Button_text {
            pos:t='0, 50%ph-50%h'
            position:t='relative'
            btnName:t='A'
            noMargin:t='yes'
            on_click='onGoToPromoLanding'
            ButtonImg {}
            externalLink:t='yes'
            activeText {
              position:t='absolute'
              pos:t='0.5pw-0.5w, 0.5ph-0.5h - 2@sf/@pf'
              text:t='#msgbox/btn_more'
              underline {}
            }
          }
      }
    }
  }
}
