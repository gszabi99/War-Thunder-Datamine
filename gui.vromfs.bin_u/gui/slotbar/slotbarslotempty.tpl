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

<<#isCrewRecruit>>
isCrewRecruit:t='yes'
<</isCrewRecruit>>

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
  proxyEventsParentTag:t='slotbarTable'
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
      position:t='relative'
      right:t='0'
      noPadding:t='yes'
      id:t='<<shopItemTextId>>'
      margin-right:t='0.008@sf'
      text-align:t='right'
      text:t='<<shopItemTextValue>>'
    }
  }

  bottomline {
    shopItemPrice {
      position:t='relative'
      right:t='0'
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
    <<#isShowDragAndDropIcon>>
    isShowDragAndDropIcon:t='yes'
    tooltip:t='<<dragAndDropIconHint>>'
    dragAndDropIcon {
      position:t='relative'
      top:t='50%ph-50%h'
      flow:t='horizontal'
      margin-right:t='0.5@blockInterval'
      text {
        text:t=' ('
        smallFont:t='yes'
      }
      icon {
        position:t='relative'
        top:t='50%ph-50%h'
        size:t='1@tIco, 1@tIco'
        background-image:t='#ui/gameuiskin#dnd_icon.svg'
        background-svg-size:t='@tIco, @tIco'
        background-color:t='@buttonFontColor'
      }
      text {
        text:t=')'
        smallFont:t='yes'
      }
    }
    <</isShowDragAndDropIcon>>
  }
  <</crewImage>>

  <<@itemButtons>>
  on_hover:t='onUnitHover'
}
<<#needDnD>>
on_end_edit:t='onCrewDropFinish'
on_drag_drop:t='onCrewDrop'
on_move:t='onCrewMove'
<</needDnD>>