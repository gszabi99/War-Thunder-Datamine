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

hasSelectedState:t='no'

unhoverDiv {
  size:t='pw, ph'
  display:t='hide'
  position:t='absolute'
  not-input-transparent:t='yes'
}
<<#crewId>>crewId:t='<<crewId>>'<</crewId>>
shopItem {
  id:t='<<shopItemId>>'
  interactive:t='yes'
  <<#shopStatus>>
  shopStat:t='<<shopStatus>>'
  <</shopStatus>>
  <<#crewId>>crew_id:t='<<crewId>>'<</crewId>>
  <<@extraInfoBlock>>

  slotPlate {
    middleBg {}
    topLine {}
    bottomShade {}
  }

  slotHoverHighlight {}
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
  slotTopGradientLine {}
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
<<#needDnD>>
on_end_edit:t='onCrewDropFinish'
on_drag_drop:t='onCrewDrop'
on_move:t='onCrewMove'
<</needDnD>>