id:t='<<slotId>>'
<<#position>>
position:t='<<position>>'
pos:t='<<posX>>w, <<posY>>h'
<</position>>

<<#selectOnHover>>
on_mouse_enter='onUnitSlotMouseEnter'
<</selectOnHover>>

<<#isSlotbarItem>>
chosen:t='no'
selected:t='no'
<</isSlotbarItem>>

unhoverDiv {
  size:t='pw, ph'
  display:t='hide'
  position:t='absolute'
  not-input-transparent:t='yes'
}

shopItem {
  id:t='<<shopItemId>>'
  interactive:t='yes'
  <<#shopStatus>>
  shopStat:t='<<shopStatus>>'
  <</shopStatus>>

  <<@extraInfoBlock>>

  slotPlate {
    middleBg {}
    topLine {}
    bottomShade {}
  }

  <<#isSlotbarItem>>
  slotHoverHighlight {}
  <</isSlotbarItem>>

  focus_border {}

  <<#crewImage>>
  img {
    position:t='absolute'
    pos:t='-@blockInterval, ph-h-@slotBottomShadeHeight'
    size:t='2.074ph, 1.037ph'
    background-svg-size:t='2.074ph, 1.037ph'
    background-repeat:t='aspect-ratio'
    background-image:t='<<crewImage>>'
    background-align:t='left'
    <<#isCrewRecruit>>
    style:t='background-color:#808080'
    <</isCrewRecruit>>
  }

  <<#isSlotbarItem>>
  slotBottomGradientLine {}
  <</isSlotbarItem>>

  topline {
    shopItemText {
      id:t='<<shopItemTextId>>'
      margin-right:t='0.008@sf'
      width:t='pw'
      text-align:t='right'
      text:t='<<shopItemTextValue>>'
    }
  }

  bottomline {
    shopItemPrice {
      text:t='<<shopItemPriceText>>'
      header:t='yes'
    }
    crewNumText {
      text:t='<<crewNumWithTitle>>'
      display:t='hide'
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