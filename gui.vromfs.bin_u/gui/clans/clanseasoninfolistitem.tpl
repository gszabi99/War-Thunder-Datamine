<<#rewardsList>>
expandable {
  id:t='<<id>>'
  width:t='pw'

  selImg {
    width:t='pw'
    flow:t='vertical'

    tdiv {
      width:t='pw'
      padding:t='12@sf/@pf_outdated'

      layeredIconContainer {
        size:t='@profileUnlockIconSize, @profileUnlockIconSize'
        pos:t='0, ph/2-h/2'
        position:t='relative'
        overflow:t='hidden'
        <<@medalIcon>>
      }

      tdiv {
        pos:t='12@sf/@pf_outdated, 0'
        position:t='relative'
        flow:t='vertical'

        activeText { caption:t='yes'; text:t='<<title>>' }
        textareaNoTab { text:t='<<gold>>' }

       <<#hasUniqueClantags>>
        textareaNoTab { text:t='<<?clan/clan_tag_decoration>><<?ui/colon>>' }
        tdiv {
          width:t='pw'
          flow:t='h-flow'

          <<#uniqueClantags>>
          tdiv {
            margin-right:t='5@sf/@pf_outdated, 0'
            tooltip:t='<<tooltip>>'
            activeText { text:t='<<start>>' }
            activeText { style:t='color:@commonTextColor'; text:t='<<tag>>' }
            activeText { text:t='<<end>>' }
          }
          <</uniqueClantags>>
        }
       <</hasUniqueClantags>>
      }

      <<#hasUniqueDecals>>
      tdiv {
        width:t='fw'
        flow:t='vertical'
        tdiv {
          max-width:t='pw'
          pos:t='pw/2-w/2'
          position:t='relative'
          flow:t='h-flow'

          <<#uniqueDecals>>
          img {
            size:t='<<ratio>>@profileUnlockIconSize, 1@profileUnlockIconSize'
            background-image:t='<<image>>'
            background-repeat:t='aspect-ratio'
            interactive:t='yes'
            <<#tooltipId>>
            title:t='$tooltipObj'
            tooltipObj {
              tooltipId:t='<<tooltipId>>'
              display:t='hide'
              on_tooltip_open:t='onGenericTooltipOpen'
              on_tooltip_close:t='onTooltipObjClose'
            }
            <</tooltipId>>
          }
          <</uniqueDecals>>
        }
      }
      <</hasUniqueDecals>>

      text {
        pos:t='pw-w, 6@sf/@pf_outdated'
        position:t='absolute'
        smallFont:t='yes'
        text:t='<<condition>>'
      }
    }

    <<#hasBonuses>>
    tdiv {
      id:t='bonuses_panel'
      width:t='pw'
      flow:t='vertical'
      padding:t='12@sf/@pf_outdated'; padding-top:t='-12@sf/@pf_outdated'
      display:t='hide'
      toggled:t='no'

      textareaNoTab { text:t='<<?clan/season_award/desc/lower_places_awards_included>><<?ui/colon>>' }

      <<#hasBonusClantags>>
      textareaNoTab { text:t='<<?clan/clan_tag_decoration>><<?ui/colon>>' }
      tdiv {
        width:t='pw'
        flow:t='h-flow'
        <<#bonusClantags>>
        tdiv {
          margin-right:t='5@sf/@pf_outdated, 0'
          tooltip:t='<<tooltip>>'
          activeText { text:t='<<start>>' }
          activeText { style:t='color:@commonTextColor'; text:t='<<tag>>' }
          activeText { text:t='<<end>>' }
        }
        <</bonusClantags>>
      }
      <</hasBonusClantags>>

      <<#hasBonusDecals>>
      textareaNoTab { text:t='<<?decals>><<?ui/colon>>' }
      tdiv {
        width:t='pw'
        flow:t='h-flow'
        <<#bonusDecals>>
        img {
          size:t='<<ratio>>@profileUnlockIconSize, 1@profileUnlockIconSize'
          background-image:t='<<image>>'
          background-repeat:t='aspect-ratio'
          <<#tooltipId>>
          title:t='$tooltipObj'
          tooltipObj {
            tooltipId:t='<<tooltipId>>'
            display:t='hide'
            on_tooltip_open:t='onGenericTooltipOpen'
            on_tooltip_close:t='onTooltipObjClose'
          }
          <</tooltipId>>
        }
        <</bonusDecals>>
      }
      <</hasBonusDecals>>
    }

    hoverButton {
      id:t='show_bonuses_btn'
      position:t='relative'
      left:t='0.5@scrn_tgt-0.5w'
      text:t='<<?clan/season_award/desc/lower_places_awards_included>><<?ui/ellipsis>>'
      tooltip:t='<<?mainmenu/btnExpand>>'
      on_click:t='onShowBonuses'
      isTextBtn:t='yes'
      interactive:t='yes'
      css-hier-invalidate:t='yes'
      ButtonImg{
        position:t='relative'
        left:t='-w-1@blockInterval'
        showOnSelect:t='hover'
        btnName:t='A'
      }
    }
    <</hasBonuses>>
  }
}
<</rewardsList>>
