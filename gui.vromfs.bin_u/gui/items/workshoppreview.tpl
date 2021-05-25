root {
  blur {}
  blur_foreground {}

  frame {
    id:t='window_root'
    pos:t='50%pw-50%w, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)'
    position:t='absolute'
    width:t='<<windowWidthScale>>@sf $min 1@maxWindowWidth'

    class:t='wnd'

    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<headerText>>'
      }
      Button_close {}
    }

    tdiv {
      size:t='pw, 1@workshoPreviewHeight'

      img {
        size:t='(<<mainImageScale>>@workshoPreviewHeight $min 0.75*@srw, ph'
        background-repeat:t='aspect-ratio'
        background-image:t='<<bgImage>>'
      }

      frameBlock {
        size:t='fw, ph'
        pos:t='1@blockInterval, 0'
        padding:t='1@blockInterval'
        position:t='relative'
        flow:t='vertical'

        tdiv {
          size:t='pw, fh'
          flow:t='vertical'
          overflow-y:t='auto'

          <<#infoBlocks>>
          <<#image>>
          img {
            size:t='pw, 0.05@sf<<#imageScale>>*<<imageScale>><</imageScale>>'
            margin-top:t='0, 0.0085@sf'
            background-image:t='<<image>>'
            background-repeat:t='aspect-ratio'
          }
          <</image>>
          <<#text>>
          textAreaCentered {
           width:t='pw'
           margin:t='0, @blockInterval'
           smallFont:t='yes'
           text:t='<<text>>'
          }
          <</text>>
          <<#space>>
          tdiv { height:t='<<space>> * 0.017@sf' } //text string height
          <</space>>
          <</infoBlocks>>
        }
        tdiv {
          pos:t='50%pw-50%w, 0'
          position:t='relative'
          margin-bottom:t='2@blockInterval'
          Button_text {
            id:t='btn_start';
            style:t='size:1@bigButtonWidth, 1@battleButtonHeight;'
            class:t='battle'
            iconPos:t='middleBottom'
            btnName:t='A'
            text:t='#mainmenu/btnToWorkshop'
            on_click:t='goBack'

            pattern { type:t='bright_texture' }
            buttonWink { _transp-timer:t='0' }
            buttonGlance {}
            focus_border{}
            ButtonImg{}
            btnText { text:t = '#mainmenu/btnToWorkshop' }
          }
        }
      }
    }
  }
}
