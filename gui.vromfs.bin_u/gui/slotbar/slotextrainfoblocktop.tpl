
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
          overlayTextColor:t='active'
          smallFont:t='yes'
          text:t='<<priceText>>'
          text-align:t='center'
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
          overlayTextColor:t='active'
          smallFont:t='yes'
          text:t='<<additionalRespawns>>'
          text-align:t='center'
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
        }
      }
      <</hasSpareInfo>>

      <<^hasAdditionalRespawns>>
      <<^hasPriceText>>
      <<^hasSpareInfo>>
      td {
        text {
          text:t='#ui/minus'
          style:t="color:#657c8a;"
        }
      }
      <</hasSpareInfo>>
      <</hasPriceText>>
      <</hasAdditionalRespawns>>
    }
  }
}
<</hasExtraInfoBlockTop>>