<<#prizes>>
tdiv {
  id:t='prize_<<idx>>'
  margin:t='4@blockInterval, 0'

  tdiv {
    id:t='prize_background'
    size:t='pw, ph'
    behaviour:t='massTransparency' //always in anim when enabled
    transp-base:t='0'
    transp-end:t='255'
    transp-func:t='cube'
    transp-time:t='0'
    _blink:t='no'

    img {
      size:t='2@itemWidth, 2@itemHeight'
      pos:t='0.5p.p.w - 0.5w, 0.5@itemHeight - 0.5h'
      position:t='absolute'
      background-svg-size:t='2@itemWidth, 2@itemHeight'
      background-image:t='!#ui/gameuiskin#circle_gradient_white.avif'
      color-factor:t='0'
    }

    <<#customImageData>>
    layeredIconContainer {
      height:t='1@itemHeight'
      position:t='absolute'
      effectType:t='blackOutline'
      <<@customImageData>>
    }
    <</customImageData>>
    <<^customImageData>>
    layeredIconContainer {
      size:t='1@itemWidth, 1@itemHeight'
      position:t='absolute'
      effectType:t='blackOutline'
      <<@layeredImage>>
    }
    <</customImageData>>
  }

  tdiv {
    id:t='prize_info'
    flow:t='vertical'

    behaviour:t='massTransparency' //always in anim when enabled
    transp-base:t='0'
    transp-end:t='255'
    transp-func:t='cube'
    transp-time:t='0'
    _blink:t='no'

    <<#customImageData>>
    tdiv {
      height:t='1@itemHeight'
      <<@customImageData>>
    }
    <</customImageData>>
    <<^customImageData>>
    tdiv {
      size:t='1@itemWidth, 1@itemHeight'
      <<@layeredImage>>
    }
    <</customImageData>>

    tdiv {
      pos:t='0.5pw-0.5w, 0'
      position:t='relative'
      margin:t='0, 1@blockInterval'
      flow:t='vertical'
      <<#textBlock>>
      tdiv {
        <<#iconBeforeText>>
        img {
          size:t='1@sIco, 1@sIco'
          pos:t='0, 0.5ph-0.5h'
          margin-right:t='1@blockInterval'
          position:t='relative'
          background-image:t='<<iconBeforeText>>'
          background-svg-size:t='1@sIco, 1@sIco'
        }
        <</iconBeforeText>>
        <<#text>>
        textareaNoTab {
          max-width:t='p.p.p.w'
          pos:t='0, 0.5ph-0.5h'
          position:t='relative'
          text:t='<<text>>'
          <<@textParams>>
        }
        <</text>>
        <<#iconAfterText>>
        img {
          size:t='1@sIco, 1@sIco'
          pos:t='1@blockInterval, 0.5ph-0.5h'
          position:t='relative'
          background-image:t='<<iconAfterText>>'
          background-svg-size:t='1@sIco, 1@sIco'
        }
        <</iconAfterText>>
      }
      <</textBlock>>
    }
  }
}
<</prizes>>
