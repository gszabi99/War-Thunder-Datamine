<<#items>>
tdiv {
  flow:t='horizontal'
  textareaNoTab {
    text:t='<<value>>'
  }
  <<#topValue>>
  tdiv {
    textareaNoTab {
      text:t=' ('
    }
    img {
      background-image:t='#ui/gameuiskin#spec_icon2.svg'
      background-svg-size:t='@sIco,@sIco'
      size:t='@sIco,@sIco'
      valign:t='center'
    }
    textareaNoTab {
      text:t='<<topValue>>'
    }
    textareaNoTab {
      text:t=')'
    }
  }
  <</topValue>>
}
<</items>>