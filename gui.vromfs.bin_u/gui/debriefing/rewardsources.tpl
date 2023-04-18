<<#multiplier>>
activeText {
  style:t='color:@commonTextColor'
  smallFont:t='yes'
  parseTags:t='yes'
  text:t='<<multiplier>>'
}
activeText {
  style:t='color:@minorTextColor'
  smallFont:t='yes'
  text:t='#ui/multiply'
}
activeText {
  style:t='color:@commonTextColor'
  smallFont:t='yes'
  text:t='('
}
<</multiplier>>
<<#sources>>
tdiv {
  <<#hasPlus>>
  activeText {
    style:t='color:@minorTextColor'
    smallFont:t='yes'
    text:t='+'
  }
  <</hasPlus>>
  <<#icon>>
  tdiv {
    size:t='<<#iconWidth>><<iconWidth>><</iconWidth>><<^iconWidth>>0.75@sIco<</iconWidth>>, @sIco'
    pos:t='0, 0.5ph-0.5h'
    position:t='relative'
    img {
      size:t='@sIco, @sIco'; pos:t='pw/2-w/2, 0'; position:t='relative'
      background-image:t='<<icon>>'
      background-svg-size:t='@sIco, @sIco';
    }
  }
  <</icon>>
  activeText {
    style:t='color:<<#textColor>><<textColor>><</textColor>><<^textColor>>@commonTextColor<</textColor>>'
    smallFont:t='yes'
    parseTags:t='yes'
    text:t='<<text>>'
  }
  <<#multiplier>>
  <<#isLastBlock>>
  activeText {
    style:t='color:@commonTextColor'
    smallFont:t='yes'
    text:t=')'
  }
  <</isLastBlock>>
  <</multiplier>>
}
<</sources>>
