
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
      <<#hasSpareCount>>
      td {
        width:t='@sf/@pf'
        extraInfoVertSeparator {}
      }
      <</hasSpareCount>>
      <</hasPriceText>>
      <</hasAdditionalRespawns>>

      <<#hasAdditionalRespawns>>
      <<#hasSpareCount>>
      td {
        width:t='@sf/@pf'
        extraInfoVertSeparator {}
      }
      <</hasSpareCount>>
      <</hasAdditionalRespawns>>

      <<#hasSpareCount>>
      td {
        text {
          id:t="spareCount"
          text:t='<<spareCount>>'
          style:t="color:#657c8a;"
        }
      }
      <</hasSpareCount>>

      <<^hasAdditionalRespawns>>
      <<^hasPriceText>>
      <<^hasSpareCount>>
      td {
        text {
          text:t='#ui/minus'
          style:t="color:#657c8a;"
        }
      }
      <</hasSpareCount>>
      <</hasPriceText>>
      <</hasAdditionalRespawns>>
    }
  }
}
<</hasExtraInfoBlockTop>>