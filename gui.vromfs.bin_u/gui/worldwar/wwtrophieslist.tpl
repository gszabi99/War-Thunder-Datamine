ww_map_item {
  class:t='header'
  isReflected:t='yes'

  textareaNoTab{
    position:t='relative'
    top:t='0.5(ph-h)'
    padding-left:t='1@framePadding'
    input-transparent:t='yes'
    text:t='<<titleText>>'
    tooltip:t='<<tooltipText>>'
    overlayTextColor:t='silver'
    caption:t='yes'
  }
}

<<#trophy>>
  ww_map_item {
    isReflected:t='yes'
    total-input-transparent:t='yes'

    tdiv {
      position:t='relative'
      top:t='0.5(ph-h)'
      margin-left:t='1@blockInterval'

      textareaNoTab{
        position:t='relative'
        top:t='0.5(ph-h)'
        padding:t='1@framePadding, 0'
        text:t='<<titleText>>'
        tooltip:t='<<tooltipText>>'
        font:t='small_text_hud'
      }
      tdiv {
        <<@wwTrophyMarkup>>

        <<#isTrophyRecieved>>
        img {
          size:t='1@cIco, 1@cIco'
          pos:t='50%pw-20%w, 50%ph-50%h'
          position:t='absolute'
          background-image:t='#ui/gameuiskin#check.svg'
          background-svg-size:t='1@cIco, 1@cIco'
          input-transparent:t='yes'
        }
        <</isTrophyRecieved>>
      }
    }
  }
<</trophy>>
