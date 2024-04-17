tdiv {
  pos:t='pw/2 - w/2, ph/2 - h/2'
  width:t='0'
  height:t='0'
  position:t='absolute'
  background-image:t='!#ui/images/chests/prizes_bg.avif'
  background-color:t='#FFFFFF'
  re-type:t='9rect'
  background-position:t='86@sf/@pf, 0, 86@sf/@pf, 0'
  background-svg-size:t='246@sf/@pf, 160@sf/@pf'
  background-repeat:t='expand'
  color-factor:t="0"
  behaviour:t='basicSize'
  min-width:t='192@sf/@pf'
  width-base:t='0'
  height-base:t='140'
  width-end:t='110'
  height-end:t='140'
  size-func:t='linear'
  size-scale:t='parent'
  size-time:t='300'
  size-delay:t='<<bgDelay>>'

  behaviour:t='basicTransparency'
  transp-base:t='0'
  transp-func:t='linear'
  transp-end:t='125'
  transp-time:t='150'
  transp-delay:t='<<bgDelay>>'
}

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
    transp-time:t='200'
    transp-delay:t='800'
    _blink:t='no'

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
    id:t='blue_bg'
    position:t='absolute'
    pos:t='pw/2, 0.5@itemHeight'
    size:t='0,0'
    display:t='hide'

    tdiv {
      size:t='1.5@itemWidth, 1.5@itemHeight'
      pos:t='-w/2, -h/2'
      position:t='absolute'
      background-image:t='!#ui/images/chests/chest_bg_cloud'
      background-color:t='#FFFFFFFF'
      color-factor:t="0"
      behaviour:t='basicTransparency'
      transp-base:t='0'
      transp-func:t='linear'
      transp-end:t='255'
      transp-time:t='125'
    }
  }

  tdiv {
    id:t='prize_info'
    flow:t='vertical'

    behaviour:t='massTransparency' //always in anim when enabled
    transp-base:t='0'
    transp-end:t='255'
    transp-func:t='cube'
    transp-time:t='0'
    transp-delay:t='100'
    _blink:t='no'

    <<#prizeTooltipId>>
    title:t='$tooltipObj'
    tooltipObj  {
      tooltipId:t='<<prizeTooltipId>>'
      display:t='hide'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
    }
    <</prizeTooltipId>>

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
  tdiv {
    id:t='rays'
    position:t='absolute'
    pos:t='pw/2, 0.5@itemHeight'
    size:t='0,0'
    display:t='hide'
    <<#rays>>
      include "%gui/items/chestOpenFxRay.tpl"
    <</rays>>
  }
}
<</prizes>>
