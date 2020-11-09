<<#hasFullGroupBlock>>
id:t='<<fullGroupBlockId>>'
group:t='yes'

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
  shopStat:t='<<groupStatus>>'

  <<#isBroken>>
  isBroken:t='yes'
  <</isBroken>>

  bgPlate {}

  itemWinkBlock {
    buttonWink {
      _transp-timer:t='0'
    }
  }

  hoverHighlight {}

  pattern {
    type:t='bright_texture'
  }

  focus_border {}

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
  talismanIcon {
    <<#talismanIncomplete>>
    incomplete:t=yes
    <</talismanIncomplete>>
  }
  <</hasTalismanIcon>>

  discount_notification {
    id:t='<<discountId>>'
    type:t='box_down'
    place:t='unitGroup'
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

  groupUnfoldMark {
    pattern {
      type:t='bright_texture'
    }
    img {}
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

  <<#bonusId>>
  bonus {
    id:t='<<bonusId>>-bonus'
    text:t=''
  }
  <</bonusId>>

  tooltipObj {
    tooltipId:t='<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }

  tooltip-float:t='horisontal'
  title:t='$tooltipObj'

  <<@bottomButton>>

<<#hasFullGroupBlock>>
}
<</hasFullGroupBlock>>
