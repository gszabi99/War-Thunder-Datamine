<<#tabs>>
shopFilter {
  <<#id>>id:t='<<id>>'<</id>>
  tooltip:t=''
  <<#hidden>>
  display:t='hide'
  enable:t='no'
  <</hidden>>

  <<#visualDisable>>
    inactive:t='yes'
  <</visualDisable>>

  <<#selected>>
    selected:t='yes'
  <</selected>>

  <<#holderDiffCode>>
    holderDiffCode:t='<<holderDiffCode>>'
  <</holderDiffCode>>

  <<#isWorldWarMode>>
    isWorldWarMode:t='yes'
  <</isWorldWarMode>>

  tooltip:t='<<tooltip>>'

  <<#tabImage>>
  shopFilterImg {
    background-image:t='<<tabImage>>'
    <<@tabImageParam>>
  }
  <</tabImage>>

  <<#unseenIcon>>
  unseenIcon {
    valign:t='center'
    value:t='<<unseenIcon>>'
    unseenText {}
  }
  <</unseenIcon>>

  <<@object>>

  shopFilterText {
    <<#id>>id:t='<<id>>_text'<</id>>
    text:t='<<tabName>>'
  }

  infoMarker {
    id:t='remainingPageMarker'
    type:t='remainingTimeMarker'
    place:t='inTab'
    countryId:t='<<countryId>>'
    armyId:t='<<armyId>>'
    value:t='{"viewId": "SHOP_PAGES_REMAINING_TIME_UNIT"}'
  }

  <<#seenIconCfg>>
  infoMarker {
    type:t='unlockMarker'
    place:t='inTab'
    value:t='<<seenIconCfg>>'
  }
  <</seenIconCfg>>

  infoMarker {
    type:t='nationBonusMarker'
    place:t='inTab'
    value:t='{"viewId": "SHOP_PAGES_NATION_BONUS_MARKER"}'
    countryId:t='<<countryId>>'
    armyId:t='<<armyId>>'
    tooltip:t='$tooltipObj'
    tooltipObj {
      id:t='nationBonusMarkerTooltip'
      tooltipId:t=''
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
  }

  <<#discount>>
  infoMarker {
    type:t='discountNotificationMarker'
    place:t='inTab'
    id:t='<<#discountId>><<discountId>><</discountId>><<^discountId>><<id>>_discount<</discountId>>'
    text:t='<<text>>'
    tooltip:t='<<tooltip>>'
  }
 <</discount>>

  <<#squadronExpIconId>>
  squadronExpIcon {
    id:t='<<squadronExpIconId>>'
    type:t='inTab'
    value:t='{"viewId": "SHOP_PAGES_SQUADRON_EXP_ICON"}'
    display:t='hide'
  }
  <</squadronExpIconId>>

  <<#cornerImg>>
  cornerImg {
    <<#cornerImgId>>id:t='<<cornerImgId>>'<</cornerImgId>>
    <<^cornerImgId>>id:t='cornerImg'<</cornerImgId>>
    background-image:t='<<cornerImg>>'
    <<^show>>display:t='hide'<</show>>
    <<#orderPopup>>order-popup:t='yes'<</orderPopup>>
    <<#cornerImgSmall>>
      imgSmall:t='yes'
    <</cornerImgSmall>>
    <<^cornerImgSmall>>
      <<#cornerImgTiny>>
        imgTiny:t='yes'
      <</cornerImgTiny>>
    <</cornerImgSmall>>
    <<#hasGlow>>
    cornerImgGlow {}
    <</hasGlow>>
  }
  <</cornerImg>>

  <<@navImagesText>>
}
<</tabs>>
