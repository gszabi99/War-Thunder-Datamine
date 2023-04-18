<<#iconedHints>>
iconedHints {
  size:t='0.07@shHud, 0.07@shHud'
  position:t='relative'
  top:t='ph/2 - h/2'
  behaviour:t='bhvUpdateByWatched'
  value:t='<<hintValue>>'
  css-hier-invalidate:t='yes'
  display:t='hide'

  <<#hintIcons>>
  hintIcon {
    <<#id>>id:t='<<id>>'<</id>>
    position:t='absolute'
    pos:t='pw/2 - w/2, ph/2 - h/2'
    size:t='<<iconWidth>>, <<iconWidth>>'
    background-svg-size:t='<<iconWidth>>, <<iconWidth>>'
    background-image:t='<<icon>>'
  }
  <</hintIcons>>

  text {
    id:t='hint_text'
    position:t='absolute'
    pos:t='pw/2 - w/2, ph - h'
    hudFont:t='normal'
    textShade:t='yes'
    text:t=''
  }
}
<</iconedHints>>
