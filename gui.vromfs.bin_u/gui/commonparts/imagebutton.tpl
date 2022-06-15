<<#buttons>>
imgButton {
  id:t='<<id>>';
  width:t='<<ratio>>@decalIconHeight + ((<<ratio>> - 1)@decalItemMargin)';
  min-height:t='1@decalIconHeight';
  min-width:t='1@decalIconHeight';
  margin:t='1@decalItemMargin'

  <<^tooltipId>>
  <<#tooltipText>>
    tooltip:t='<<tooltipText>>'
  <</tooltipText>>
  <</tooltipId>>
  <<#tooltipId>><<#isTooltipByHold>>
    tooltipId:t='<<tooltipId>>'
    on_pushed = "::gcb.delayedTooltipPush"
    on_hold_start = "::gcb.delayedTooltipHoldStart"
    on_hold_stop = "::gcb.delayedTooltipHoldStop"
    on_hover:t='::gcb.delayedTooltipHover'
    on_unhover:t='::gcb.delayedTooltipHover'
  <</isTooltipByHold>><</tooltipId>>

  <<#unlocked>> unlocked:t='yes'; <</unlocked>>
  <<#highlighted>> highlighted:t='yes' <</highlighted>>

  <<#onClick>> on_click:t='<<onClick>>' <</onClick>>
  <<#onDblClick>> on_dbl_click:t='<<onDblClick>>' <</onDblClick>>

  pushedBg {}
  hoverBg {}

  <<^emptySlot>>
    <<#image>>
    img {
      background-image:t='<<image>>'
      max-height:t='1.0/<<ratio>>pw'
      max-width:t='<<ratio>>pw'
      height:t='ph';
      width:t='pw';
      pos:t='50%pw-50%w, 50%ph-50%h';
      position:t='relative';
      background-repeat:t='aspect-ratio';
      background-svg-size:t='pw, ph'
    }
    <</image>>
  <</emptySlot>>

  <<^unlocked>>
    <<#statusLock>>
    LockedImg {
       statusLock:t='<<statusLock>>'
      <<#lockCountryImg>> background-image:t='<<lockCountryImg>>' <</lockCountryImg>>
    }
    <</statusLock>>
  <</unlocked>>

  <<#unitLocked>>
    textareaNoTab {
      text-shade:t='yes'
      pos:t='pw-w-4, ph-h';
      position:t='absolute';
      text:t='<<unitLocked>>'
      mediumFont:t='yes'
      overlayTextColor:t='bad'
    }
  <</unitLocked>>

  <<#unlocked>>
  <<#emptySlot>>
    textAreaCentered {
      valign:t='center'
      width:t='pw';
      smallFont:t='yes'
      text:t='#ui/empty'
    }
  <</emptySlot>>
  <</unlocked>>

  <<#cost>>
    contentCorner {
      side:t='right'
      textareaNoTab {
        text:t='<<cost>>'
        smallFont:t='yes';
        padding:t='3@dp,6@dp,3@dp,3@dp';
      }
    }
  <</cost>>

  <<#showLimit>>
    textareaNoTab {
      textShade:t='yes'
      pos:t='pw-w-2@dp, ph-h-2@dp'
      position:t='absolute';
      text:t='<<leftAmount>>/<<limit>>'
      smallFont:t='yes';
      padding:t='3@dp,6@dp,3@dp,3@dp';
      <<#isMax>>
        overlayTextColor:t='bad'
      <</isMax>>
    }
  <</showLimit>>

  <<#rarityColor>>
  rarityBorder {
    size:t='pw-4@dp, ph-4@dp'
    pos:t='pw/2-w/2, ph/2-h/2'
    border-color:t='<<rarityColor>>'
  }
  <</rarityColor>>

  focus_border{}

  <<#leftBottomButtonCb>>
  contentCorner {
    side:t='left'
    pos:t=<<^rarityColor>>'0, ph-h'<</rarityColor>><<#rarityColor>>'2@dp, ph-h-2@dp'<</rarityColor>>
    Button_text {
      holderId:t='<<leftBottomButtonHolderId>>'
      tooltip:t='<<leftBottomButtonTooltip>>'
      class:t='image'
      imgSize:t='small'
      visualStyle:t='noFrame'
      showConsoleImage:t='no'
      img { background-image:t='<<leftBottomButtonImg>>' }
      on_click:t='<<leftBottomButtonCb>>'
      skip-navigation:t='yes'
    }
  }
  <</leftBottomButtonCb>>

  <<^emptySlot>>
    <<#onDeleteClick>>
      Button_close {
        smallIcon:t='yes'
        tooltip:t='#msgbox/btn_delete'
        have_shortcut:t='no'
        on_click:t='<<onDeleteClick>>'
      }
    <</onDeleteClick>>
  <</emptySlot>>

  <<#tooltipId>>
  <<^isTooltipByHold>>
    tooltipObj {
      tooltipId:t='<<tooltipId>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      max-width:t='8*@decalIconHeight+10*@sf/@pf_outdated'
      smallFont:t='yes';
      display:t='hide';

      <<#tooltipOffset>>
      style:t='tooltip-screen-offset:<<tooltipOffset>>;';
      <</tooltipOffset>>
    }
    title:t='$tooltipObj';
    tooltip-float:t='horizontal';
  <</isTooltipByHold>>
  <</tooltipId>>
}
<</buttons>>
