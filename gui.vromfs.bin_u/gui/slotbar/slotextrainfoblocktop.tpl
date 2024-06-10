
<<#hasExtraInfoBlockTop>>
extraInfoBlockTop {
  tdiv {
    size:t='pw, ph'
    smallFont:t='yes'
    text-halign='center'
    text-valign='center'
    textareaNoTab {
      id:t='extraInfoPriceText'
      width:t='fw'
      smallFont:t='yes'
      text:t='<<priceText>>'
      text-align:t='center'
      position:t='relative'
      pos:t='0, ph/2-(h-@sf/@pf)/2'
      <<#hasPriceText>>
      display:t='show'
      <</hasPriceText>>
      <<^hasPriceText>>
      display:t='hide'
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

    textareaNoTab {
      id:t='additionalRespawns'
      width:t='fw'
      smallFont:t='yes'
      text:t='<<additionalRespawns>>'
      text-align:t='center'
      position:t='relative'
      pos:t='0, ph/2-(h-@sf/@pf)/2'
      <<#hasAdditionalRespawns>>
      display:t='show'
      <</hasAdditionalRespawns>>
      <<^hasAdditionalRespawns>>
      display:t='hide'
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
      <</hasSpareInfo>>
      <<^hasSpareInfo>>
      display:t='hide'
      <</hasSpareInfo>>
    }

    text {
      id:t='emptyExtraInfoText'
      width:t='fw'
      position:t='relative'
      pos:t='0, ph/2-(h-@sf/@pf)/2'
      text:t='#ui/minus'
      overlayTextColor:t='common'
      <<#isMissingExtraInfo>>
      display:t='show'
      <</isMissingExtraInfo>>
      <<^isMissingExtraInfo>>
      display:t='hide'
      <</isMissingExtraInfo>>
    }
  }
}
<</hasExtraInfoBlockTop>>