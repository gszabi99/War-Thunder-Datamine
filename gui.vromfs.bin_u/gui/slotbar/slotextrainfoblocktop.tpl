
<<#hasExtraInfoBlockTop>>
extraInfoBlockTop {
  id:t="extraInfoBlockTop"
  <<#hasExtraInfo>>
  hasInfo:t='yes'
  <</hasExtraInfo>>
  cursor:t='normal'
  tdiv {
    size:t='pw, ph'
    textareaNoTab {
      id:t='extraInfoPriceText'
      width:t='<<priceWidth>>'
      smallFont:t='yes'
      text:t='<<priceText>>'
      text-align:t='center'
      position:t='relative'
      pos:t='0, ph/2-(h-@sf/@pf)/2'
      <<#hasPriceText>>
      display:t='show'
      hasInfo:t='yes'
      <</hasPriceText>>
      <<^hasPriceText>>
      display:t='hide'
      hasInfo:t='no'
      <</hasPriceText>>
    }

    extraInfoVertSeparator {
      id:t='priceSeparator'
      <<#hasPriceSeparator>>
      display:t='show'
      <</hasPriceSeparator>>
      <<^hasPriceSeparator>>
      display:t='hide'
      <</hasPriceSeparator>>
    }

    tdiv {
      id:t='additionalHistoricalRespawnsNest'
      width:t='<<addHistoricalRespawnsWidth>>'
      position:t='relative'
      pos:t='0, ph/2-(h-@sf/@pf)/2'
      css-hier-invalidate:t='yes'
      <<#hasAdditionalHistoricalRespawns>>
      display:t='show'
      hasInfo:t='yes'
      <</hasAdditionalHistoricalRespawns>>
      <<^hasAdditionalHistoricalRespawns>>
      display:t='hide'
      hasInfo:t='no'
      <</hasAdditionalHistoricalRespawns>>
      tdiv {
        position:t='relative'
        pos:t='pw/2-w/2, ph/2-h/2'
        css-hier-invalidate:t='yes'
        tdiv {
          size:t="@cIco, @sIco"
          pos:t='0, ph/2-h/2'
          position:t='relative'
          background-svg-size:t="@cIco, @sIco"
          background-repeat:t="aspect-ratio"
          background-image:t="<<unitClassIco>>"
          background-color:t='<<unitClassIcoColor>>'
          margin-right:t="2@sf/@pf"
        }
        textareaNoTab {
          id:t='additionalHistoricalRespawns'
          smallFont:t='yes'
          text:t='<<additionalHistoricalRespawns>>'
          text-align:t='center'
          position:t='relative'
          pos:t='0, ph/2-h/2'
        }
      }
    }

    extraInfoVertSeparator {
      id:t='additionalRespawnsSeparator'
      <<#hasAdditionalRespawnsSeparator>>
      display:t='show'
      <</hasAdditionalRespawnsSeparator>>
      <<^hasAdditionalRespawnsSeparator>>
      display:t='hide'
      <</hasAdditionalRespawnsSeparator>>
    }

    textareaNoTab {
      id:t='additionalRespawns'
      width:t='<<addRespawnsWidth>>'
      smallFont:t='yes'
      text:t='<<additionalRespawns>>'
      text-align:t='center'
      position:t='relative'
      pos:t='0, ph/2-(h-@sf/@pf)/2'
      <<#hasAdditionalRespawns>>
      display:t='show'
      hasInfo:t='yes'
      <</hasAdditionalRespawns>>
      <<^hasAdditionalRespawns>>
      display:t='hide'
      hasInfo:t='no'
      <</hasAdditionalRespawns>>
    }

    extraInfoVertSeparator {
      id:t='spareSeparator'
      <<#hasSpareSeparator>>
      display:t='show'
      <</hasSpareSeparator>>
      <<^hasSpareSeparator>>
      display:t='hide'
      <</hasSpareSeparator>>
    }

    textareaNoTab {
      id:t='spareCount'
      width:t='fw'
      smallFont:t='yes'
      text:t='<<spareCount>>'
      text-align:t='center'
      position:t='relative'
      pos:t='0, ph/2-(h-@sf/@pf)/2'
      <<#hasSpareInfo>>
      display:t='show'
      hasInfo:t='yes'
      <</hasSpareInfo>>
      <<^hasSpareInfo>>
      display:t='hide'
      hasInfo:t='no'
      <</hasSpareInfo>>
    }

    text {
      id:t='emptyExtraInfoText'
      width:t='fw'
      position:t='relative'
      pos:t='0, ph/2-(h-@sf/@pf)/2'
      text:t='#ui/minus'
      overlayTextColor:t='common'
      <<^hasExtraInfo>>
      display:t='show'
      <</hasExtraInfo>>
      <<#hasExtraInfo>>
      display:t='hide'
      <</hasExtraInfo>>
    }
  }

  <<#showAdditionExtraInfo>>
  slotMissionHintContainer {
    slotMissionHint {
      textareaNoTab {
        id:t="extraInfoPriceTextHint"
        width:t='pw'
        smallFont:t='yes'
        text:t='<<priceHintText>>'
        position:t='relative'
        margin-bottom:t="3@sf/@pf"
        <<#hasPriceText>>
        display:t='show'
        <</hasPriceText>>
        <<^hasPriceText>>
        display:t='hide'
        <</hasPriceText>>
      }

      tdiv {
        width:t='pw'
        position:t='relative'
        margin-bottom:t="3@sf/@pf"
        <<#hasAdditionalHistoricalRespawns>>
        display:t='show'
        <</hasAdditionalHistoricalRespawns>>
        <<^hasAdditionalHistoricalRespawns>>
        display:t='hide'
        <</hasAdditionalHistoricalRespawns>>
        tdiv {
          position:t='relative'
          pos:t='0, ph/2-h/2'
          width:t='pw'
          tdiv {
            size:t="@cIco, @sIco"
            position:t='relative'
            background-svg-size:t="@cIco, @sIco"
            background-repeat:t="aspect-ratio"
            background-image:t="<<unitClassIco>>"
            background-color:t='@commonTextColor'
            margin-right:t="2@sf/@pf"
          }
          textareaNoTab {
            width:t='pw'
            smallFont:t='yes'
            text:t='<<additionalHistoricalRespawnsHintText>>'
            position:t='relative'
            pos:t='-@cIco, ph/2-h/2'
            paragraph-indent:t="7@blockInterval"

          }
        }
      }

      textareaNoTab {
        margin-bottom:t="3@sf/@pf"
        width:t='pw'
        smallFont:t='yes'
        text:t='<<additionalRespawnsHintText>>'
        position:t='relative'
        <<#hasAdditionalRespawns>>
        display:t='show'
        <</hasAdditionalRespawns>>
        <<^hasAdditionalRespawns>>
        display:t='hide'
        <</hasAdditionalRespawns>>
      }

      textareaNoTab {
        margin-bottom:t="3@sf/@pf"
        <<#hasSpareInfo>>
        display:t='show'
        <</hasSpareInfo>>
        <<^hasSpareInfo>>
        display:t='hide'
        <</hasSpareInfo>>
        width:t='pw'
        smallFont:t='yes'
        text:t='<<spareHintText>>'
        position:t='relative'
      }
    }

    slotHoverHighlight {}
    slotBottomGradientLine {}
  }
  <</showAdditionExtraInfo>>
}
<</hasExtraInfoBlockTop>>