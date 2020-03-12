id:t='<<slotId>>'

<<#isSlotbarItem>>
slotbarCurAir {}
<</isSlotbarItem>>

shopItem {
  id:t='<<shopItemId>>'
  <<#shopStatus>>
  shopStat:t='<<shopStatus>>'
  <</shopStatus>>
  bgPlate {}

  <<@crewLevelInfo>>

  focus_border {}

  <<#crewImage>>
  img {
    position:t='absolute'
    size:t='2.074ph, 1.037ph'
    background-repeat:t='aspect-ratio'
    background-image:t='<<crewImage>>'
    <<#isCrewRecruit>>
    style:t='background-color:#808080'
    pos:t='0.06ph, ph-h-3'
    <</isCrewRecruit>>
    <<^isCrewRecruit>>
    pos:t='0.15ph, ph-h-3'
    <</isCrewRecruit>>
  }

  topline {
    shopItemPrice {
      text:t='<<shopItemPriceText>>'
      header:t='yes'
    }
  }

  bottomline {
    shopItemText {
      id:t='<<shopItemTextId>>'
      margin-right:t='0.008@sf'
      width:t='pw'
      text-align:t='right'
      text:t='<<shopItemTextValue>>'
    }
  }
  <</crewImage>>
  <<^crewImage>>
  middleline {
    shopItemText {
      id:t='<<shopItemTextId>>'
      text:t='<<shopItemTextValue>>'
    }
  }
  <</crewImage>>

  <<@itemButtons>>
}
