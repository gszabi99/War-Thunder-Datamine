tdiv {
  <<#needHeader>>
    textareaNoTab {
      text:t='<<#headerText>><<headerText>><</headerText>><<^headerText>><<?ugm/price>><<?ui/colon>><</headerText>>'
    }
  <</needHeader>>

  <<#havePsPlusDiscount>>
    cardImg {
      type:t='small'
      background-image:t='#ui/gameuiskin#ps_plus.svg'
      top:t='50%ph-50%h'
      position:t='relative'
      margin-right:t='0.005@scrn_tgt'
    }
  <</havePsPlusDiscount>>

  <<^needDiscountOnRight>>
  textareaNoTab {
    text:t='<<priceText>>'

    <<#haveDiscount>>
      margin-right:t='0.01@scrn_tgt'
      <<#havePsPlusDiscount>>
        overlayTextColor:t='psplus'
      <</havePsPlusDiscount>>
      <<^havePsPlusDiscount>>
        overlayTextColor:t='good'
      <</havePsPlusDiscount>>
    <</haveDiscount>>
  }
  <</needDiscountOnRight>>

  <<#haveDiscount>>
    textareaNoTab {
      text:t='<<listPriceText>>'
      overlayTextColor:t='faded'
      tdiv {
        size:t='pw, 1@dp'
        position:t='absolute'
        pos:t='0, 50%ph-50%h'
        background-color:t='@commonTextColor'
      }
    }
  <</haveDiscount>>

  <<#needDiscountOnRight>>
  textareaNoTab {
    text:t='<<priceText>>'

    <<#haveDiscount>>
      margin-left:t='0.01@scrn_tgt'
      overlayTextColor:t='good'
    <</haveDiscount>>
  }
  <</needDiscountOnRight>>

  <<#endText>>
    textareaNoTab {
      text:t='<<endText>>'
    }
  <</endText>>
}