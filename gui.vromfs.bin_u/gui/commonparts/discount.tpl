tdiv {
  <<#needHeader>>
    textarea {
      text:t='<<?ugm/price>><<?ui/colon>>'
      removeParagraphIndent:t='yes'
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

  textarea {
    text:t='<<priceText>>'
    removeParagraphIndent:t='yes'

    <<#haveDiscount>>
      <<#havePsPlusDiscount>>
        overlayTextColor:t='psplus'
      <</havePsPlusDiscount>>
      <<^havePsPlusDiscount>>
        overlayTextColor:t='good'
      <</havePsPlusDiscount>>
    <</haveDiscount>>
  }

  <<#haveDiscount>>
    textarea {
      text:t='<<listPriceText>>'
      removeParagraphIndent:t='yes'
      overlayTextColor:t='faded'
      margin-left:t='0.01@scrn_tgt'
      tdiv {
        size:t='pw, 1@dp'
        position:t='absolute'
        pos:t='0, 50%ph-50%h'
        background-color:t='@commonTextColor'
      }
    }
  <</haveDiscount>>
}