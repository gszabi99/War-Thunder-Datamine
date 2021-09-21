<<#items>>
itemDiv {
  smallFont:t='yes';
  class:t='smallFont'
  total-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  <<#active>>
    active:t='yes'
  <</active>>

  enableBackground:t='<<#enableBackground>>yes<</enableBackground>><<^enableBackground>>no<</enableBackground>>'
  <<#isTooltipByHold>>tooltipId:t='<<tooltipId>>'<</isTooltipByHold>>

  <<#today>>
  today:t='yes'
  <</today>>

  <<#bigPicture>>
  trophyRewardSize:t='yes'
  <</bigPicture>>

  <<#ticketBuyWindow>>
  ticketBuyWindow:t='yes'
  <</ticketBuyWindow>>

  <<#isItemLocked>>
  item_locked:t='yes'
  <</isItemLocked>>
  <<#openedPicture>>
  previousDay:t='yes'
  <</openedPicture>>
  <<#itemIndex>>
  holderId:t='<<itemIndex>>'
  <</itemIndex>>
  <<#onHover>>
  on_hover:t='<<onHover>>'
  on_unhover:t='<<onHover>>'
  <</onHover>>

  <<#active>>
    wink { pattern { type:t='bright_texture'; position:t='absolute' } }
  <</active>>

  <<#rarityColor>>
  rarityBorder {
    size:t='pw-4@dp, ph-4@dp'
    pos:t='pw/2-w/2, ph/2-h/2'; position:t='absolute'
    border:t='yes'
    border-color:t='<<rarityColor>>'
    input-transparent:t='yes'
  }
  <</rarityColor>>

  // Used in recent items handler.
  <<#onClick>>
  behavior:t='button'
  on_click:t='<<onClick>>'

  pushedBorder {
    size:t='pw-4@dp, ph-4@dp'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    border:t='yes'
    border-color:t='#40404040'
    input-transparent:t='yes'
    display:t='hide'

    pushedBorder {
      size:t='pw-2@dp, ph-2@dp'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
      border:t='yes'
      border-color:t='#55555555'
      input-transparent:t='yes'
    }
  }

  hoverBorder {
    size:t='pw-4@dp, ph-4@dp'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    border:t='yes'
    border-color:t='#20202020'
    input-transparent:t='yes'
    display:t='hide'

    hoverBorder {
      size:t='pw-2@dp, ph-2@dp'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
      border:t='yes'
      border-color:t='#33333333'
      input-transparent:t='yes'
    }
  }
  <</onClick>>

  <<#interactive>>
  interactive:t='yes'
  <</interactive>>

  <<#skipNavigation>>
  skip-navigation:t='yes'
  <</skipNavigation>>

  tdiv {
    size:t='pw, ph'
    text-halign:t='center'
    <<#itemIndex>>
    id:t='shop_item_<<itemIndex>>'
    <</itemIndex>>
    css-hier-invalidate:t='yes'

    <<#itemHighlight>>
    itemHighlight {
      highlight:t='<<itemHighlight>>'
    }
    <</itemHighlight>>

    tdiv {
      size:t='pw, ph'
      overflow:t='hidden'
      css-hier-invalidate:t='yes'
      <<@layered_image>>
      <<@getLayeredImage>>
    }

    <<#contentIconData>>
    contentCorner {
      contentType:t='<<contentType>>'
      foreground-image:t='<<contentIcon>>'
    }
    <</contentIconData>>

    tdiv {
      flow:t='vertical'
      position:t='absolute'
      pos:t='-1@itemPadding, -1@itemPadding'
      <<@getWarbondShopLevelImage>>
      <<@getWarbondMedalImage>>
    }

    <<#headerText>>
    activeText {
      width:t='pw'
      top:t='10%ph-50%h'
      position:t='absolute'
      pare-text:t='yes'
      text:t='<<headerText>>'
    }
    <</headerText>>

    <<#nameText>>
    textareaNoTab {
      width:t='pw'
      top:t='50%ph-50%h'
      text-align:t='center'
      position:t='absolute'
      text:t='<<nameText>>'
    }
    <</nameText>>

    <<#unseenIcon>>
    unseenIcon {
      pos:t='pw-w, 0'
      position:t='absolute'
      value:t='<<unseenIcon>>'
      unseenText {}
    }
    <</unseenIcon>>

    itemTimerPlace{
      id:t='timePlace'
      css-hier-invalidate:t='yes'

      <<#craftTime>>
      textareaNoTab {
        id:t='craft_time'
        text:t='<<craftTime>>'
        overlayTextColor:t='goodTextColor'
      }
      <</craftTime>>

      <<#expireTime>>
      textareaNoTab {
        id:t='expire_time'
        text:t='<<expireTime>>'
        overlayTextColor:t='disabled'
      }
      <</expireTime>>
    }
    <<#amount>>
    itemAmountText {
      text:t='<<amount>>'
      <<#overlayAmountTextColor>>
      overlayTextColor:t='<<overlayAmountTextColor>>'
      <</overlayAmountTextColor>>
      <<#hasIncrasedAmountTextSize>>
      hasIncrasedAmountTextSize:t='yes'
      <</hasIncrasedAmountTextSize>>
      <<#isInTransfer>>
      animated_wait_icon {
        pos:t='-w, 38%ph-50%h'
        class:t='inTextRowAbsolute'
        background-rotation:t = '0'
      }
      <</isInTransfer>>
    }
    <</amount>>

    <<^isAllBought>>
    <<#price>>
    tdiv {
      id:t='price'
      position:t='absolute'
      left:t='-1@itemPadding'
      top:t='ph -0.5@dIco -1@dp +1@itemPadding -h/2'
      width:t='pw + 2@itemPadding'
      height:t='1@dIco'
      <<#needPriceFadeBG>>
        background-color:t='@shadeBackgroundColor2'
      <</needPriceFadeBG>>

      tdiv {
        pos:t='pw-w -2@itemPadding, 50%ph-50%h'
        position:t='relative'
        <<#havePsPlusDiscount>>
          cardImg {
            type:t='small'
            background-image:t='#ui/gameuiskin#ps_plus.svg'
            top:t='50%ph-50%h'
            position:t='relative'
            margin-right:t='0.005@scrn_tgt'
          }
        <</havePsPlusDiscount>>

        textareaNoTab {
          id:t='price'
          text:t='<<price>>'
          top:t='50%ph-50%h'
          position:t='relative'
        }
      }
    }
    <</price>>
    <</isAllBought>>

    <<#needAllBoughtIcon>>
    img{
      id:t='all_bougt_icon';
      size:t='@unlockIconSize, @unlockIconSize';
      pos:t='pw-w  -1@itemPadding +1@dp, ph -0.5@dIco -1@dp +1@itemPadding -0.6h'
      position:t='absolute'
      background-image:t='#ui/gameuiskin#favorite';
      <<^isAllBought>>display:t='hide'<</isAllBought>>
    }
    <</needAllBoughtIcon>>
    <<#needMarkIcon>>
    markIcon{
      position:t='absolute'
      color:t='<<markIconColor>>'
      text:t='<<markIcon>>'
    }
    <</needMarkIcon>>
    <<#boostEfficiency>>
    textareaNoTab {
      pos:t='0.5pw-0.5w, ph + 1@itemPadding'
      text-align:t='center'
      position:t='absolute'
      text:t='<<boostEfficiency>>'
    }
    <</boostEfficiency>>
  }

  <<#arrowNext>>
  arrowNext{
    <<#tomorrow>>colored:t='yes'<</tomorrow>>
    arrowType:t='<<arrowType>>'
  }
  <</arrowNext>>

  <<#hasFocusBorder>>
  focus_border {}
  <</hasFocusBorder>>

  <<#hasButton>>
  <<#modActionName>>
  <<#needShowActionButtonAlways>>
  showButtonAlways:t='yes'
  <</needShowActionButtonAlways>>

  hasButton:t='yes'
  Button_text {
    id:t='actionBtn'
    pos:t='50%pw-50%w, ph-h/2' //empty zone in button texture
    position:t='absolute'
    visualStyle:t='common'
    class:t='smallButton'
    text:t='<<modActionName>>'
    <<#itemIndex>>
    holderId:t='<<itemIndex>>'
    <</itemIndex>>
    on_click:t='<<^onItemAction>>onItemAction<</onItemAction>><<onItemAction>>'
    btnName:t=''
    <<#isInactive>>
    inactiveColor:t='yes'
    <</isInactive>>
    ButtonImg {
      btnName:t='A'
      showOnSelect:t='hover'
    }
  }
  <</modActionName>>
  <</hasButton>>



  <<^isTooltipByHold>>
  <<#tooltipId>>
  tooltipObj {
    id:t='tooltip_<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
  title:t='$tooltipObj';
  tooltip-float:t='<<^tooltipFloat>>horizontal<</tooltipFloat>><<tooltipFloat>>'
  <</tooltipId>>
  <</isTooltipByHold>>
}
<</items>>
