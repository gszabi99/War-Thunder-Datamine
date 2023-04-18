<<#hasFullGroupBlock>>
id:t='<<fullGroupBlockId>>'
group:t='yes'
<<#isTooltipByHold>>tooltipId:t='<<tooltipId>>'<</isTooltipByHold>>

<<#position>>
position:t='<<position>>'
pos:t='<<posX>>w, <<posY>>h'
<</position>>

<<#isGroupInactive>>
inactive:t='yes'
<</isGroupInactive>>

shopItem {
<</hasFullGroupBlock>>

  id:t='<<slotId>>'
  behavior:t='Timer'
  timer_interval_msec:t='1000'
  group:t='yes'
  primaryUnitId:t='<<primaryUnitId>>'

  <<#isTooltipByHold>>
  tooltipId:t='<<tooltipId>>'
  on_hover:t='::gcb.delayedTooltipHover'
  on_unhover:t='::gcb.delayedTooltipHover'
  <</isTooltipByHold>>

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
    middleBg {
      pattern {}
      groupFrame {}
    }
    topLine {}
    bottomShade {}
  }

  itemWinkBlock {
    buttonWink {
      _transp-timer:t='0'
    }
  }

  hoverHighlight {}

  shopStat:t='<<groupStatus>>'
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
  talismanIcon {
    <<#talismanIncomplete>>
    incomplete:t=yes
    <</talismanIncomplete>>
  }
  <</hasTalismanIcon>>

  discount_notification {
    id:t='<<discountId>>'
    type:t='box_down'
    text:t=''
    showDiscount:t='yes'
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
        position:t='absolute'
        pos:t='pw-w, -2/3h'
        smallFont:t='yes'
        talign:t='right'
      }
      <<@progressBlk>>
    }

    shopItemPrice {
      text:t='<<priceText>>'
    }

    shopItemText {
      id:t='rank_text'
      text:t='<<unitRankText>>'

      <<#isItemLocked>>
      locked:t='yes'
      <</isItemLocked>>

      <<^isItemLocked>>
      locked:t='no'
      <</isItemLocked>>

      text-align:t='right'
    }

    classIconPlace {
      classIcon {
        text:t='<<unitClassIcon>>'
        shopItemType:t='<<unitRole>>'
      }
    }
  }

  groupUnfoldMark {}

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

<<#hasFullGroupBlock>>
}
<</hasFullGroupBlock>>
