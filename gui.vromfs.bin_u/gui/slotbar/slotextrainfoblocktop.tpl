
<<#hasExtraInfoBlockTop>>
extraInfoBlockTop {
  table {
    size:t='pw, ph'
    smallFont:t='yes'
    text-halign='center'
    text-valign='center'
    tr {
      <<#hasPriceText>>
      td {
        textareaNoTab {
          id:t='extraInfoPriceText'
          width:t='pw'
          smallFont:t='yes'
          text:t='<<priceText>>'
          text-align:t='center'
          position:t='absolute'
          pos:t='pw/2-w/2, ph/2-(h-@sf/@pf)/2'
        }
      }
      <</hasPriceText>>

      <<#hasPriceText>>
      <<#hasAdditionalRespawns>>
      td {
        width:t='@sf/@pf'
        extraInfoVertSeparator {}
      }
      <</hasAdditionalRespawns>>
      <</hasPriceText>>

      <<#hasAdditionalRespawns>>
      td {
        textareaNoTab {
          width:t='pw'
          smallFont:t='yes'
          text:t='<<additionalRespawns>>'
          text-align:t='center'
          position:t='absolute'
          pos:t='pw/2-w/2, ph/2-(h-@sf/@pf)/2'
        }
      }
      <</hasAdditionalRespawns>>

      <<^hasAdditionalRespawns>>
      <<#hasPriceText>>
      <<#hasSpareInfo>>
      td {
        width:t='@sf/@pf'
        extraInfoVertSeparator {}
      }
      <</hasSpareInfo>>
      <</hasPriceText>>
      <</hasAdditionalRespawns>>

      <<#hasAdditionalRespawns>>
      <<#hasSpareInfo>>
      td {
        width:t='@sf/@pf'
        extraInfoVertSeparator {}
      }
      <</hasSpareInfo>>
      <</hasAdditionalRespawns>>

      <<#hasSpareInfo>>
      td {
        textareaNoTab {
          id:t="spareCount"
          width:t='pw'
          smallFont:t='yes'
          text:t='<<spareCount>>'
          text-align:t='center'
          position:t='absolute'
          pos:t='pw/2-w/2, ph/2-(h-@sf/@pf)/2'
        }
      }
      <</hasSpareInfo>>

      <<^hasAdditionalRespawns>>
      <<^hasPriceText>>
      <<^hasSpareInfo>>
      td {
        text {
          text:t='#ui/minus'
          overlayTextColor:t='common'
        }
      }
      <</hasSpareInfo>>
      <</hasPriceText>>
      <</hasAdditionalRespawns>>
    }
  }
}
<</hasExtraInfoBlockTop>>