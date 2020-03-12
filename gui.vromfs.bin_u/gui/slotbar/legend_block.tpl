<<#haveLegend>>
tdiv {
  flow:t='vertical';
  padding-top:t='0.01@scrn_tgt'
  inactive:t='yes'
  textarea {
    overlayTextColor:t='active'
    text:t='<<header>>';
    position:t='relative';
    pos:t='50%pw-50%w, 0';
  }
  <<#legendData>>
  tdiv {
    img {
      size:t='1@cIco, 1@cIco'
      background-image:t='<<imagePath>>'
      pos:t = '0, 50%ph-50%h';
    }
    textarea {
      max-width:t='0.5@rw -0.5@slot_width'
      text:t='<<locId>>'
      smallFont:t='yes'
      valign:t='center'
    }
  }
  <</legendData>>
}
<</haveLegend>>