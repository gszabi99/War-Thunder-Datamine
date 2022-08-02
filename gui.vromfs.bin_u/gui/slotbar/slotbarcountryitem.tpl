<<#countries>>
shopFilter {
  id:t='header_country<<countryIdx>>'
  height:t='ph'
  class:t='slotsHeader'
  countryId:t='<<country>>'
  tooltip:t='<<tooltipText>>'
  <<^isEnabled>>
  enable:t='no'
  <</isEnabled>>

  img {
    id:t='hdr_image'
    size:t='@cIco, @cIco'
    top:t='0.5(ph-h)'
    position:t='relative'
    background-image:t='<<countryIcon>>'
    background-svg-size:t='@cIco, @cIco'
  }

  <<#bonusData>>
  bonusNoFrame {
    background-image:t='<<background-image>>'
    bonusType:t='<<bonusType>>'
    tooltip:t='<<tooltip>>'
  }
  <</bonusData>>

  slotsCountryText {
    class:t='full'
    text:t='#<<country>>'
  }
  slotsCountryText {
    display:t='hide'
    class:t='short'
    text:t='#<<country>>/short'
  }

  <<#hasNotificationIcon>>
  tdiv {
    position:t='absolute'
    size:t='pw, ph'

    remainingTimeIconInSlotbar {
      behavior:t='bhvUpdater'
      countryId:t='<<country>>'
      value:t='{"viewId": "COUNTRY_REMAINING_TIME_UNIT"}'
      display:t='hide'
      tooltip:t=''
      remainingTimeTimerIcon {
        id:t='remainingTimeTimerIcon'
        halign:t='center'
        display:t='hide'
      }
    }

    discountIcon {
      countryId:t='<<country>>'
      value:t='{"viewId": "COUNTRY_DISCOUN_ICON"}'
      text:t='#measureUnits/percent'
      tooltip:t='#discount/notification'
      type:t='slotbarCountry'
    }

    squadronExpIcon {
      countryId:t='<<country>>'
      value:t='{"viewId": "COUNTRY_SQUADRON_EXP_ICON"}'
      type:t='slotbarCountry'
      display:t='hide'
    }

    <<#seenIconCfg>>
    tdiv {
      behavior:t='bhvUpdater'
      countryId:t='<<country>>'
      value:t='{"viewId": "COUNTRY_UNLOCK_MARKER"}'
      display:t='hide'
      size:t='fw, ph'

      unlockMarker {
        type:t='slotbarCountry'
        value:t='<<seenIconCfg>>'
      }
    }
    <</seenIconCfg>>
  }
  <</hasNotificationIcon>>
}
<</countries>>
