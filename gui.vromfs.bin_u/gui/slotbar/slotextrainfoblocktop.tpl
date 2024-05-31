
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
      <<#hasAdditionalRespawns>>
      td {
        activeText {
          text:t='<<additionalRespawns>>'
        }
      }
      <</hasAdditionalRespawns>>
      <<#hasSpareCount>>
      td {
        text {
          text:t='<<spareCount>>'
          style:t="color:#657c8a;"
        }
      }
      <</hasSpareCount>>
    }
  }
}
<</hasExtraInfoBlockTop>>