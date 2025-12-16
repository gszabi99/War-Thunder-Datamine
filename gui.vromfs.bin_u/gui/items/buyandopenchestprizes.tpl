

<<#prizes>>
tdiv {
  id:t='prize_<<idx>>'
  margin:t='<<margin>>, 0'
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
      id:t='bg_icon_layer'
      height:t='<<chestItemWidth>>'
      position:t='absolute'
      effectType:t='blackOutline'
      <<@customImageData>>
    }
    <</customImageData>>
    <<^customImageData>>
    layeredIconContainer {
      id:t='bg_icon_layer'
      size:t='<<chestItemWidth>>, <<chestItemWidth>>'
      position:t='absolute'
      effectType:t='blackOutline'
      <<@layeredImage>>
    }
    <</customImageData>>
  }

  tdiv {
    id:t='blue_bg'
    position:t='absolute'
    pos:t='pw/2, 0.5*<<chestItemWidth>>'
    size:t='0,0'
    display:t='hide'

    tdiv {
      size:t='1.5*<<chestItemWidth>>, 1.5*<<chestItemWidth>>'
      pos:t='-w/2, -h/2'
      position:t='absolute'
      background-image:t='!#ui/images/chests/chest_bg_cloud_white'
      background-color:t='<<chestItemRarityColor>>'
      color-factor:t="0"
      behaviour:t='basicTransparency'
      transp-base:t='0'
      transp-func:t='linear'
      transp-end:t='191'
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
    hasTooltip:t='yes'
    tooltipObj  {
      tooltipId:t='<<prizeTooltipId>>'
      display:t='hide'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
    }
    <</prizeTooltipId>>

    <<#customImageData>>
    tdiv {
      height:t='<<chestItemWidth>>'
      <<@customImageData>>
    }
    <</customImageData>>
    <<^customImageData>>
    tdiv {
      size:t='<<chestItemWidth>>, <<chestItemWidth>>'
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
        id:t='text_block_<<idx>>'
        <<#iconBeforeText>>
        img {
          size:t='1@sIco, 0.66@cIco'
          pos:t='0, 0.5ph-0.5h'
          margin-right:t='1@blockInterval'
          position:t='relative'
          background-image:t='<<iconBeforeText>>'
          background-repeat:t='aspect-ratio'
          background-svg-size:t='1@sIco, 0.66@cIco'
        }
        <</iconBeforeText>>
        <<#text>>
        textareaNoTab {
          id:t='prize_text'
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
        <<#isTextNeedStroke>>
        tdiv {
          id:t='stroke_0'
          position:t='absolute'
          display:t='hide'
          width:t='pw'
          height:t=4@sf/@pf
          background-color:t='#000000';
          color-factor:t='0'
        }
        tdiv {
          id:t='stroke_1'
          position:t='absolute'
          display:t='hide'
          width:t='pw'
          height:t=4@sf/@pf
          background-color:t='#000000';
          color-factor:t='0'
        }
        tdiv {
          id:t='stroke_2'
          position:t='absolute'
          display:t='hide'
          width:t='pw'
          height:t=4@sf/@pf
          background-color:t='#000000';
          color-factor:t='0'
        }
        <</isTextNeedStroke>>
      }
      <</textBlock>>
    }
  }
  tdiv {
    id:t='rays'
    position:t='absolute'
    pos:t='pw/2, 0.5*<<chestItemWidth>>'
    size:t='0,0'
    display:t='hide'
    <<#rays>>
      include "%gui/items/chestOpenFxRay.tpl"
    <</rays>>
  }
}
<</prizes>>
