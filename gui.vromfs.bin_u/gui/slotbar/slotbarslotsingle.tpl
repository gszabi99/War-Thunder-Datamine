<<#isInTable>>
id:t='<<slotId>>'

<<#slotInactive>>
inactive:t='yes'
<</slotInactive>>

<<#isSlotbarItem>>
slotbarCurAir {}
<</isSlotbarItem>>
<</isInTable>>

shopItem {
  id:t='<<shopItemId>>'
  behavior:t='Timer'
  timer_interval_msec:t='1000'
  unit_name:t='<<unitName>>'
  <<#crewId>>crew_id:t='<<crewId>>'<</crewId>>

  <<^isInTable>>
  isInTable:t='no'
  <</isInTable>>

  <<^hasHoverMenu>>refuseOpenHoverMenu:t='yes'<</hasHoverMenu>>
  <<#hasHoverMenu>>on_hover:t='onUnitHover'<</hasHoverMenu>>

  bgPlate {}

  itemWinkBlock {
    buttonWink {
      _transp-timer:t='0'
    }
  }

  hoverHighlight {}

  pattern {
    <<#premiumPatternType>>
    type:t='premium'
    <</premiumPatternType>>

    <<^premiumPatternType>>
    type:t='bright_texture'
    <</premiumPatternType>>
  }

  shopStat:t='<<shopStatus>>'
  unitRarity:t='<<unitRarity>>'

  <<#isBroken>>
  isBroken:t='yes'
  <</isBroken>>

  <<^isBroken>>
  isBroken:t='no'
  <</isBroken>>

  <<#isPkgDev>>
  shopAirImg { foreground-image:t='#ui/gameuiskin#unit_under_construction' }
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
    place:t='unit'
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
      size:t='fw, ph'

      shopItemText {
        text:t='<<progressText>>'
        progressStatus:t='<<progressStatus>>'
        position:t='absolute'
        pos:t='pw-w, -2/3h'
        smallFont:t='yes'
        talign:t='right'
        shadeStyle:t='textOnIcon'
      }
      <<@progressBlk>>
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

  <<#showInService>>
  shopInServiceImg {
    <<#isMounted>>
    mounted:t='yes'
    <</isMounted>>
    icon {}
  }
  <</showInService>>

  <<@itemButtons>>

  tooltipObj {
    tooltipId:t='<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }

  tooltip-float:t='horisontal'
  title:t='$tooltipObj'

  focus_border {}

  <<@bottomButton>>
}