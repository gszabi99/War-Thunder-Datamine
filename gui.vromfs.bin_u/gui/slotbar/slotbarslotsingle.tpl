<<#position>>
position:t='<<position>>'
pos:t='<<posX>>w, <<posY>>h'
<</position>>

<<#isInTable>>
id:t='<<slotId>>'

<<#slotInactive>>
inactive:t='yes'
<</slotInactive>>

<<#isSlotbarItem>>
slotbarCurAir {}
chosen:t='no'
<</isSlotbarItem>>
<</isInTable>>

<<#isTooltipByHold>>tooltipId:t='<<tooltipId>>'<</isTooltipByHold>>

shopItem {
  id:t='<<shopItemId>>'
  behavior:t='Timer'
  timer_interval_msec:t='1000'
  unit_name:t='<<unitName>>'
  <<#crewId>>crew_id:t='<<crewId>>'<</crewId>>

  <<^isInTable>>
  isInTable:t='no'
  <</isInTable>>

  <<#isTooltipByHold>>
  tooltipId:t='<<tooltipId>>'
  on_hover:t='::gcb.delayedTooltipHover'
  on_unhover:t='::gcb.delayedTooltipHover'
  <</isTooltipByHold>>

  <<#refuseOpenHoverMenu>>refuseOpenHoverMenu:t='yes'<</refuseOpenHoverMenu>>

  <<@extraInfoBlock>>

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

  hoverHighlight {}

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
  eliteIcon {}
  <</isElite>>

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
    shopItemText {
      id:t='<<shopItemTextId>>'
      text:t='<<shopItemText>>'
      header:t='yes'
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
      id:t='bottom_item_price_text'
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

  <<@bottomButton>>
}