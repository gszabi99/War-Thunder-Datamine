<<#items>>
tdiv {
  flow:t='horizontal'
  textareaNoTab {
    text:t='<<value>>'
    <<#isDevParam>>overlayTextColor:t='dev'<</isDevParam>>
  }
  <<#topValue>>
  tdiv {
    textareaNoTab {
      text:t=' ('
      <<#isDevParam>>overlayTextColor:t='dev'<</isDevParam>>
    }
    img {
      background-image:t='#ui/gameuiskin#spec_icon2.svg'
      background-svg-size:t='@sIco,@sIco'
      size:t='@sIco,@sIco'
      valign:t='center'
    }
    textareaNoTab {
      text:t='<<topValue>>'
      <<#isDevParam>>overlayTextColor:t='dev'<</isDevParam>>
    }
    textareaNoTab {
      text:t=')'
      <<#isDevParam>>overlayTextColor:t='dev'<</isDevParam>>
    }
  }
  <</topValue>>
}
<</items>>