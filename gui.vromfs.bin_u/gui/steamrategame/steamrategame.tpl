root {
  bgrStyle:t='fullScreenWnd'
  bgcolor:t='#18202a'

  <<#backgroundImg>>
  img {
    id:t='backgroundImg'
    size:t='h/<<backgroundImgRatio>>, sh'
    position:t='absolute'
    pos:t='0.5pw-0.5w, 0'
    background-image:t='<<backgroundImg>>'
    background-repeat:t='aspect-ratio'

    tdiv {
      position:t='absolute'
      size:t='<<widthCoeff>>pw + 4@sf/@pf, ph'
      pos:t='0.5pw-0.5w, 0'
      background-image:t='!#ui/images/chests/square_gradient_9rect.svg'
      bgcolor:t='#18202a'
      background-svg-size:t='620@sf/@pf, 560@sf/@pf'
      background-repeat:t='expand-svg'
    }
  }
  <</backgroundImg>>

  img {
    position:t='absolute'
    pos:t='@bw, @bh'
    size:t='1@steamButtonWidth, 0.33@steamButtonWidth'
    background-image:t='@!ui/images/steam_logo.svg'
    background-svg-size:t='1@steamButtonWidth, 0.33@steamButtonWidth'
    background-repeat:t='aspect-ratio'
  }

  tdiv {
    width:t='@rw'
    pos:t='0.5pw-0.5w, @bh'
    position:t='absolute'
    Button_close { _on_click:t = 'goBack' }
  }

  tdiv {
    width:t='0.75sw'
    pos:t='0.5sw-0.5w, sh-1@bh-h-1@steamButtonHeight'
    position:t='absolute'
    flow:t='vertical'

    titleTextArea {
      id:t='rate_text'
      bigBoldFont:t='yes'
      shadeStyle:t='shadowed'
      text:t='<<descText>>'
      input-transparent:t='yes'
      text-align:t='center'
    }

    tdiv {
      width:t='<<btnWidth>>'
      position:t='relative'
      flow:t='vertical'
      halign:t='center'

      Button_text {
        text:t='<<writeReviewBtnText>>'
        on_click:t='onApply'
        visualStyle:t='steam'
        focusBtnName:t='A'
        showConsoleImage:t='no'
        externalLink:t='yes'
        margin-top:t='7@blockInterval'
      }

      Button_text {
        text:t='<<closeBtnText>>'
        on_click:t='goBack'
        visualStyle:t='steam'
        focusBtnName:t='A'
        showConsoleImage:t='no'
        margin-top:t='5@blockInterval'
      }
    }
  }
}