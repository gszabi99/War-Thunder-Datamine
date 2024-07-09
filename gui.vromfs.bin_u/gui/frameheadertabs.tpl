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

  <<#squadronExpIconId>>
  squadronExpIcon {
    id:t='<<squadronExpIconId>>'
    type:t='inTab'
    value:t='{"viewId": "SHOP_PAGES_SQUADRON_EXP_ICON"}'
    display:t='hide'
  }
  <</squadronExpIconId>>

  <<#remainingTimeUnitPageMarker>>
  remainingTimeUnitPageMarker {
    behavior:t='bhvUpdater'
    id:t='remainingPageMarker'
    countryId:t='<<countryId>>'
    armyId:t='<<armyId>>'
    value:t='{"viewId": "SHOP_PAGES_REMAINING_TIME_UNIT"}'
    display:t='hide'
  }
  <</remainingTimeUnitPageMarker>>

  <<#seenIconCfg>>
  unlockMarker {
    type:t='inTab'
    value:t='<<seenIconCfg>>'
  }
  <</seenIconCfg>>

  <<#discount>>
  discount {
    id:t='<<#discountId>><<discountId>><</discountId>><<^discountId>><<id>>_discount<</discountId>>'
    type:t='inTab'
    text:t='<<text>>'
    tooltip:t='<<tooltip>>'
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
