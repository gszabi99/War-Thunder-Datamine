tdiv {
  id:t='battle_desc'
  pos:t='0,0'
  position:t='relative'
  width:t='fw'
  flow:t='vertical'
  css-hier-invalidate:t='yes'

  textareaNoTab {
    width:t='pw'
    padding:t='1@framePadding, 0, 1@framePadding, 1@framePadding'
    text:t='<<getFullBattleName>>'
    text-align:t='center'
    mediumFont:t='yes'
  }

  tdiv {
    size:t='pw, fh'
    flow:t='vertical'

/**************Status Panel**************/
    tdiv {
      width:t='pw'
      background-color:t='@objectiveHeaderBackground'

      tdiv {
        top:t='50%ph-50%h'
        position:t='relative'
        padding:t='1@framePadding'

        wwBattleIcon{
          id:t='battle_icon'
          status:t='<<getStatus>>'
          isTooltipIcon:t='yes'
        }
      }

      tdiv {
        width:t='fw'
        top:t='50%ph-50%h'
        position:t='relative'
        flow:t='vertical'

        <<#showBattleStatus>>
        tdiv {
          id:t='battle_status'
          width:t='pw'
          activeText {
            text:t='<<?worldwar/battleStatus>><<?ui/colon>>'
            commonTextColor:t='yes'
          }
          activeText {
            id:t='battle_status_text'
            width:t='fw'
            text:t=''
            parseTags:t='yes'
          }
        }
        <</showBattleStatus>>

        tdiv {
          id:t='battle_timer'
          width:t='pw'
          <<^hasBattleDurationTime>>
          display:t='hide'
          <</hasBattleDurationTime>>
          activeText {
            id:t='battle_timer_desc'
            text:t=''
            commonTextColor:t='yes'
          }
          activeText {
            id:t='battle_timer_value'
            text:t=''
          }
        }

        tdiv {
          id:t='win_chance'
          width:t='pw'
          display:t='hide'
          activeText {
            text:t='<<?worldwar/winChancePercent>><<?ui/colon>>'
            commonTextColor:t='yes'
          }
          activeText {
            id:t='win_chance_text'
            width:t='fw'
            text:t=''
          }
        }
      }
    }

/**************Teams Panel**************/
    teamInfoPanel {
      size:t='pw, fh'

      <<#teamBlock>>
      tdiv {
        id:t='<<teamName>>'
        width:t='50%pw'
        flow:t='vertical'
        padding-left:t='2@framePadding'
        padding-bottom:t='2@framePadding'
        padding-top:t='1@framePadding'

        tdiv {
          <<#armies>>
          cardImg {
            background-image:t='<<countryIcon>>'
            top:t='50%ph-50%h'
            position:t='relative'
            margin-left:t='1@framePadding'
            margin-right:t='2@framePadding'
          }
          <</armies>>
          activeText { text:t='<<teamSizeText>>' }
        }

        <<#armies>>
        tdiv {
          height:t='<<maxSideArmiesNumber>>@mIco'
          flow:t='vertical'

          <<@armyViews>>
        }
        <</armies>>

        <<#haveUnitsList>>
        tdiv {
          width:t='pw'
          flow:t='vertical'

          activeText {
            id:t='allowed_unit_types_text'
            text:t='#worldwar/available_crafts'
          }

          <<@unitsList>>
        }
        <</haveUnitsList>>

        <<#haveAIUnitsList>>
        tdiv {
          width:t='pw'
          flow:t='vertical'
          margin-top:t='0.01@sf'

          textareaNoTab {
            text:t='#worldwar/unit/controlledByAI'
            overlayTextColor:t='disabled'
          }

          <<@aiUnitsList>>
        }
        <</haveAIUnitsList>>
      }
      <</teamBlock>>

      blockSeparator {}
    }

    <<^isAutoBattle>>
    include "%gui/worldWar/wwControlHelp.tpl"
    <</isAutoBattle>>
  }
}
