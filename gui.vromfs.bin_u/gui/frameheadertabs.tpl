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

  <<#seenIconCfg>>
  infoMarker {
    type:t='unlockMarker'
    place:t='inTab'
    value:t='<<seenIconCfg>>'
    tooltip:t='$tooltipObj'
    tooltipObj {
      tooltipId:t='{"id":"unlockMarker", "ttype":"UNLOCK_MARKER", "countryId": "<<countryId>>", "armyId": "<<armyId>>"}'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
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

  infoMarker {
    id:t='remainingPageMarker'
    type:t='remainingTimeMarker'
    place:t='inTab'
    countryId:t='<<countryId>>'
    armyId:t='<<armyId>>'
    value:t='{"viewId": "SHOP_PAGES_REMAINING_TIME_UNIT"}'
    tooltip:t='$tooltipObj'
    tooltipObj {
      tooltipId:t='{"id":"remainingTimeUnit", "ttype":"REMAINING_TIME_UNIT", "countryId": "<<countryId>>", "armyId": "<<armyId>>"}'
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
    tooltip:t='$tooltipObj'
    tooltipObj {
      tooltipId:t='{"id":"discountsMarker", "ttype":"DISCOUNTS", "countryId": "<<countryId>>", "armyId": "<<armyId>>"}'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
  }
 <</discount>>

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
