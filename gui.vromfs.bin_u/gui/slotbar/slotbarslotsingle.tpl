<<#position>>
position:t='<<position>>'
pos:t='<<posX>>w, <<posY>>h'
<</position>>

<<#selectOnHover>>
on_mouse_enter:t='onUnitSlotMouseEnter'
<</selectOnHover>>

<<#isInTable>>
id:t='<<slotId>>'

<<#slotInactive>>
inactive:t='yes'
<</slotInactive>>

<<#isSlotbarItem>>
chosen:t='no'
selected:t='no'
<</isSlotbarItem>>
<</isInTable>>

<<#isTooltipByHold>>tooltipId:t='<<tooltipId>>'<</isTooltipByHold>>
<<#crewId>>crewId:t='<<crewId>>'<</crewId>>
shopItem {
  id:t='<<shopItemId>>'
  interactive:t='yes'
  behavior:t='Timer'
  timer_interval_msec:t='1000'
  unit_name:t='<<unitName>>'
  proxyEventsParentTag:t='slotbarTable';
  <<#crewId>>crew_id:t='<<crewId>>'<</crewId>>
  <<#crewInfoTranslucent>>crewInfoTranslucent:t='<<crewInfoTranslucent>>'<</crewInfoTranslucent>>

  <<^isInTable>>
  isInTable:t='no'
  <</isInTable>>
  on_hover:t='onUnitHover'
  on_unhover:t='::gcb.delayedTooltipHover'
  <<#isTooltipByHold>>
  tooltipId:t='<<tooltipId>>'
  <</isTooltipByHold>>

  refuseOpenHoverMenu:t='<<refuseOpenHoverMenu>>'
  <<#hasContextCursor>>cursor:t='context-menu'<</hasContextCursor>>

  <<@extraInfoBlock>>
  <<@extraInfoBlockTop>>

  <<#showInService>>
  shopInServiceImg {
    <<#isMounted>>
    mounted:t='yes'
    <</isMounted>>
    shopInServiceImgBg {}
    icon {}
  }
  <</showInService>>

  slotPlate {
    middleBg { pattern {} }
    topLine {}
    bottomShade {}
  }

  itemWinkBlock {
    buttonWink {
      _transp-timer:t='0'
    }
  }

  slotHoverHighlight {}

  shopStat:t='<<shopStatus>>'
  unitRarity:t='<<unitRarity>>'

  <<#isBroken>>
  isBroken:t='yes'
  <</isBroken>>

  <<^isBroken>>
  isBroken:t='no'
  <</isBroken>>

  <<#isPkgDev>>
  isPkgDev:t='yes'
  <</isPkgDev>>

  shopAirImg {
    foreground-image:t='<<shopAirImg>>'
  }

  <<#isElite>>
    isElite:t='yes'
  <</isElite>>

  <<^isElite>>
    isElite:t='no'
  <</isElite>>

  eliteIcon {}

  <<#isSlotbarItem>>
  slotTopGradientLine {}
  slotBottomGradientLine {}
  <</isSlotbarItem>>

  <<#isRecentlyReleased>>
  recentlyReleasedIcon {}
  <</isRecentlyReleased>>

  <<#hasTalismanIcon>>
  talismanIcon {}
  <</hasTalismanIcon>>

  discount_notification {
    id:t='<<discountId>>'
    type:t='box_down'
    text:t=''

    <<#showDiscount>>
    showDiscount:t='yes'
    <</showDiscount>>

    <<^showDiscount>>
    showDiscount:t='no'
    <</showDiscount>>
  }

  topline {
    shopItemDiv {
      position:t='relative'
      tdiv {
        size:t='@weaponStatusIconSize, @weaponStatusIconSize'
        position:t='relative'
        valign:t='center'
        margin-right:t='1@blockInterval'
        background-svg-size:t='@weaponStatusIconSize, @weaponStatusIconSize'
        background-repeat:t='aspect-ratio'
        background-image:t='#ui/gameuiskin#dice_outline_white.svg'
        background-color:t='@activeTextColor'
        <<^isRandomUnit>>
        display:t='hide'
        <</isRandomUnit>>
      }
      shopItemText {
        id:t='<<shopItemTextId>>'
        noPadding:t='yes'
        text:t='<<shopItemText>>'
        header:t='yes'
      }
    }
  }

  bottomline {
    tdiv {
      width:t='fw'
      pos:t='0, ph-h'
      flow:t='vertical'

      shopItemText {
        text:t='<<progressText>>'
        progressStatus:t='<<progressStatus>>'
        position:t='relative'
        pos:t='pw-w, 0'
        smallFont:t='yes'
        talign:t='right'
        shadeStyle:t='textOnIcon'
      }
      tdiv {
        width:t='pw'
        position:t='relative'
        pos:t='0, -3@sf/@pf'
        <<@progressBlk>>
      }
    }

    shopItemPrice {
      <<#isLongPriceText>>
      tinyFont:t='yes'
      <</isLongPriceText>>
      text:t='<<priceText>>'
    }
    <<^bottomLineText>>
    shopItemText {
      id:t='rank_text'
      text:t='<<unitRankText>>'

      <<#isLongPriceText>>
      tinyFont:t='yes'
      <</isLongPriceText>>

      <<#isItemLocked>>
      locked:t='yes'
      <</isItemLocked>>
      <<^isItemLocked>>
      locked:t='no'
      <</isItemLocked>>

      text-align:t='right'
    }
    <</bottomLineText>>
    <<#bottomLineText>>
    tdiv{
      <<#isLongPriceText>>
      width:t='0.4pw'
      <</isLongPriceText>>
      <<^isLongPriceText>>
      width:t='pw-1@tableIcoSize-0.003@sf'
      <</isLongPriceText>>
      overflow:t='hidden'
      shopItemText {
        min-width:t='pw'
        autoScrollText:t='hoverOrSelect'
        text:t='<<bottomLineText>>'
        text-align:t='right'
      }
    }
    <</bottomLineText>>
    classIconPlace {
      <<#bottomLineText>>
      margin-top:t='0.003@sf'
      <</bottomLineText>>
      classIcon {
        text:t='<<unitClassIcon>>'
        shopItemType:t='<<shopItemType>>'
      }
    }
    crewNumText {
      text:t='<<crewNumWithTitle>>'
      display:t='hide'
    }
  }

  <<@itemButtons>>

  <<#bonusId>>
  bonus {
    id:t='<<bonusId>>-bonus'
    text:t=''
  }
  <</bonusId>>

  <<^isTooltipByHold>>
  tooltipObj {
    tooltipId:t='<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }

  tooltip-float:t='horizontal'
  title:t='$tooltipObj'
  <</isTooltipByHold>>

  focus_border {}

  <<#needDnD>>
  on_drag_start:t='onUnitCellDragStart'
  on_drag_drop:t='onUnitCellDrop'
  on_move:t='onUnitCellMove'
  dragParent:t='yes'
  <</needDnD>>
}
<<#needDnD>>
on_end_edit:t='onCrewDropFinish'
on_drag_drop:t='onCrewDrop'
on_move:t='onCrewMove'
<</needDnD>>