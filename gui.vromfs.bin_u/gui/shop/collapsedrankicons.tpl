tdiv {
  flow:t='horizontal'
  pos:t='0, ph-h-4@sf/@pf'
  position:t='absolute'
  width:t='pw-2*@shop_width - 2@modArrowWidth'
  padding-left:t='2@modArrowWidth'

  <<#icons>>
    <<#hasNationBonus>>
    nationBonusRankIcon{
      id:t='nation_bonus'
      flow:t='horizontal'
      isNationBonusOver:t=<<isNationBonusOver>>
      img{
        id:t='icon'
        position:t='relative'
        size:t='0.8@discountBoxHeight, 1@discountBoxHeight'
      }
      shopCollapsedIconText {
        id:t='count_text'
        position:t='relative'
        top:t='(ph-h)/2 + 1@sf/@pf'
        text:t='<<battlesRemain>>'
        input-transparent:t='yes'
      }
      title:t='$tooltipObj'
      tooltipObj {
        id:t='bonus_tooltip'
        tooltipId:t='<<nationBonusTooltipId>>'
        display:t='hide'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
      }
    }
    <</hasNationBonus>>
    <<#discounts>>
      tdiv {
        float:t='horizontal'
        tooltip:t='<<unitsNames>>'

        shopCollapsedDiscountIcon {
          text:t='-<<discount>>%'
        }
        shopCollapsedIconText {
          position:t='relative'
          top:t='(ph-h)/2 + 1@sf/@pf'
          text:t='×<<count>>'
          input-transparent:t='yes'
        }
      }
    <</discounts>>

    <<#objectivesCount>>
      tdiv {
        float:t='horizontal'
        tooltip:t='<<objectivesUnits>>'

        img{
          position:t='relative'
          size:t='1@discountBoxHeight, 1@discountBoxHeight'
          background-image:t='#ui/gameuiskin#unlock_icon.svg'
          background-svg-size:t='1@discountBoxHeight, 1@discountBoxHeight'
          background-repeat:t='expand-svg'
        }
        shopCollapsedIconText {
          position:t='relative'
          top:t='(ph-h)/2 + 1@sf/@pf'
          text:t='×<<objectivesCount>>'
          input-transparent:t='yes'
        }
      }
    <</objectivesCount>>
    tdiv {
      behavior:t='bhvUpdater'
      flow:t='horizontal'
      isForPremium:t='no'
      position:t='relative'
      countryId:t='<<country>>'
      rank:t='<<rank>>'
      armyId:t='<<armyId>>'
      tooltip = ""
      value:t='{"viewId": "SHOP_RANK_REMAINING_TIME_UNIT"}'
      img{
        position:t='relative'
        size:t='1@discountBoxHeight, 1@discountBoxHeight'
        background-image:t='#ui/gameuiskin#timer_icon.svg'
        background-svg-size:t='w, 1@discountBoxHeight'
        background-position:t='7@sf/@pf, 7@sf/@pf, 3@sf/@pf, 3@sf/@pf'
        background-repeat:t='expand-svg'
      }
      shopCollapsedIconText {
        id:t='count_text'
        position:t='relative'
        top:t='(ph-h)/2 + 1@sf/@pf'
        text:t='×<<objectivesCount>>'
        input-transparent:t='yes'
      }
    }
  <</icons>>
}

tdiv {
  flow:t='horizontal'
  pos:t='pw, ph-h-4@sf/@pf'
  position:t='absolute'
  width:t='2*@shop_width'
  padding-left:t='1@modArrowWidth'

  <<#premIcons>>
    <<#discounts>>
      tdiv {
        float:t='horizontal'
        tooltip:t='<<unitsNames>>'

        shopCollapsedDiscountIcon {
          text:t='-<<discount>>%'
        }
        shopCollapsedIconText {
          position:t='relative'
          top:t='(ph-h)/2 + 1@sf/@pf'
          text:t='×<<count>>'
          input-transparent:t='yes'
        }
      }
    <</discounts>>

    <<#objectivesCount>>
      tdiv {
        float:t='horizontal'
        tooltip:t='<<objectivesUnits>>'

        img{
          position:t='relative'
          size:t='1@discountBoxHeight, 1@discountBoxHeight'
          background-image:t='#ui/gameuiskin#unlock_icon.svg'
          background-svg-size:t='1@discountBoxHeight, 1@discountBoxHeight'
          background-repeat:t='expand-svg'
        }
        shopCollapsedIconText {
          position:t='relative'
          top:t='(ph-h)/2 + 1@sf/@pf'
          text:t='×<<objectivesCount>>'
          input-transparent:t='yes'
        }
      }
    <</objectivesCount>>
    tdiv {
      behavior:t='bhvUpdater'
      flow:t='horizontal'
      isForPremium:t='yes'
      position:t='relative'
      countryId:t='<<country>>'
      rank:t='<<rank>>'
      armyId:t='<<armyId>>'
      value:t='{"viewId": "SHOP_RANK_REMAINING_TIME_UNIT"}'
      tooltip = ""

      img{
        position:t='relative'
        size:t='1@discountBoxHeight, 1@discountBoxHeight'
        background-image:t='#ui/gameuiskin#timer_icon.svg'
        background-svg-size:t='w, 1@discountBoxHeight'
        background-position:t='7@sf/@pf, 7@sf/@pf, 3@sf/@pf, 3@sf/@pf'
        background-repeat:t='expand-svg'
      }
      shopCollapsedIconText {
        id:t='count_text'
        position:t='relative'
        top:t='(ph-h)/2 + 1@sf/@pf'
        text:t='×<<objectivesCount>>'
        input-transparent:t='yes'
      }
    }
  <</premIcons>>
}
