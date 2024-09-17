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

    infoMarker {
      type:t='remainingTimeMarker'
      place:t='slotbarCountry'
      countryId:t='<<country>>'
      value:t='{"viewId": "COUNTRY_REMAINING_TIME_UNIT"}'
      display:t='hide'
      tooltip:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='{"id":"remainingTimeUnit", "ttype":"REMAINING_TIME_UNIT", "countryId": "<<country>>"}'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
    }

    <<#seenIconCfg>>
    tdiv {
      behavior:t='bhvUpdater'
      countryId:t='<<country>>'
      value:t='{"viewId": "COUNTRY_UNLOCK_MARKER"}'
      display:t='hide'

      infoMarker {
        type:t='unlockMarker'
        place:t='slotbarCountry'
        value:t='<<seenIconCfg>>'
        tooltip:t='$tooltipObj'
        tooltipObj {
          tooltipId:t='{"id":"unlockMarker", "ttype":"UNLOCK_MARKER", "countryId": "<<country>>"}'
          on_tooltip_open:t='onGenericTooltipOpen'
          on_tooltip_close:t='onTooltipObjClose'
          display:t='hide'
        }
      }
    }
    <</seenIconCfg>>

    infoMarker {
      type:t='nationBonusMarker'
      place:t='slotbarCountry'
      countryId:t='<<country>>'
      value:t='{"viewId": "COUNTRY_NATION_BONUS_MARKER"}'
      tooltip:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='{"id":"nationBonus", "ttype":"NATION_BONUSES", "countryId": "<<country>>"}'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
    }

    infoMarker {
      type:t='discountNotificationMarker'
      place:t='slotbarCountry'
      value:t='{"viewId": "COUNTRY_DISCOUNT_MARKER"}'
      countryId:t='<<country>>'
      text:t='#measureUnits/percent'
      tooltip:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='{"id":"discountsMarker", "ttype":"DISCOUNTS", "countryId": "<<country>>"}'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
    }
  }
  <</hasNotificationIcon>>
}
<</countries>>
