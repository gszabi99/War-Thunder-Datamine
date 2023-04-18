tdiv {
  id:t='battle_desc'
  size:t='pw, ph'
  pos:t='0, 0'; position:t='relative'
  flow:t='vertical'

  tdiv {
    size:t='pw, ph'
    position:t='absolute'

    wwBattleBackgroundBlock {
      wwBattleBackground {
        id:t='battle_background'
      }
    }

    tdiv {
      size:t='pw, ph'
      position:t='absolute'

      wwBattleBackgroundShadow { type:t='left'   }
      wwBattleBackgroundShadow { type:t='right'  }
      wwBattleBackgroundShadow { type:t='top' }
      wwBattleBackgroundShadow { type:t='bottom'; top:t='ph-h' }
    }
  }

  div {
    id:t='battle_desc_content'
    size:t='pw, ph'
    padding:t='1@framePadding'
    flow:t='vertical'

    div {
      id:t='battle_info'
      width:t='pw'
      left:t='0.5(pw-w)'
      position:t='relative'
      padding:t='1@blockInterval, 0'
      margin-top:t='0.01@scrn_tgt+0.03@wwBattleInfoScreenIncHeight'
      flow:t='vertical'

      textareaNoTab {
        width:t='pw'
        text:t='<<getFullBattleName>>'
        text-align:t='center'
        mediumFont:t='yes'
      }

      textareaNoTab {
        id:t='operation_info_text'
        left:t='50%pw-50%w'
        position:t='relative'
        text:t=''
      }

      tdiv{
        margin-top:t='1@framePadding'
        left:t='50%pw-50%w'
        flow:t='horizontal'
        position:t='relative'

        activeText {
          id:t='battle_status_text'
          position:t='relative'
          text:t=''
        }

        tdiv {
          id:t='win_chance'
          position:t='relative'
          margin-left:t='1@framePadding'
          display:t='hide'
          activeText {
            text:t='<<?worldwar/winChancePercent>><<?ui/colon>>'
            commonTextColor:t='yes'
          }
          activeText {
            id:t='win_chance_text'
            text:t=''
          }
        }
      }

      textareaNoTab {
        id:t='battle_time_text'
        left:t='50%pw-50%w'
        position:t='relative'
        text:t=''
      }

      textareaNoTab {
        position:t='relative'
        width:t='pw'
        padding:t='1@framePadding, 0'
        text:t='<<getBattleStatusDescText>>'
        text-align:t='center'
      }
    }

    tdiv {
      id:t='teams_block'
      size:t='pw, 75%ph'
      position:t='relative'
      flow:t='vertical'

      tdiv {
        width:t='pw'
        margin-bottom:t='0.15@wwBattleInfoScreenIncHeight'

        tdiv {
          id:t='team_header_info_0'
          width:t='50%pw'
        }

        tdiv {
          id:t='team_header_info_1'
          width:t='50%pw'
        }

        tdiv {
          id:t='teams_info'
          width:t='30%pw'
          height:t='1@wwArmyIco'
          pos:t='50%pw-50%w, 0.005@scrn_tgt + 1@wwSmallCountryFlagHeight'
          position:t='absolute'
          margin:t='1@blockInterval'
          display:t='hide'
          background-image:t='#ui/gameuiskin#option_select_odd'
          background-position:t='1, 5'
          background-repeat:t='expand'
          bgcolor:t='@white'

          textareaNoTab {
            id:t='number_of_players'
            width:t='pw'
            top:t='50%ph-50%h'
            position:t='relative'
            text:t=''
            text-align:t='center'
            overlayTextColor:t='active'
          }
        }
      }

      tdiv {
        id:t='teams_unis'
        size:t='pw, fh'

        tdiv {
          size:t='pw, ph'
          position:t='absolute'

          wwWindowListBackground {
            size:t='25%pw, ph'
            type:t='left'
          }
          wwWindowListBackground {
            size:t='25%pw, ph'
            left:t='pw-2w'
            position:t='relative'
            type:t='right'
          }
        }

        tdiv {
          size:t='pw, ph'

          tdiv {
            id:t='team_unit_info_0'
            width:t='35%pw'
            overflow-y:t='auto'
            scrollbarShortcuts:t='yes'
            scroll-align:t='left'
          }
          tdiv {
            id:t='team_unit_info_1'
            width:t='35%pw'
            left:t='pw-2w'
            position:t='relative'
            overflow-y:t='auto'
            scrollbarShortcuts:t='yes'
          }
        }
      }

      tdiv {
        id:t='required_crafts_block'
        width:t='pw'
        margin-top:t='1@blockInterval'
        display:t='hide'

        Button_text {
          showConsoleImage:t='no'
          text:t='#events/required_crafts_no_colon'
          reduceMinimalWidth:t='yes'
          useParentHeight:t='yes'
          noMargin:t='yes'
          isPlayerSide:t='yes'
          on_click:t = 'onShowHelp'
        }
        Button_text {
          left:t='pw-2w'
          position:t='relative'
          showConsoleImage:t='no'
          text:t='#events/required_crafts_no_colon'
          reduceMinimalWidth:t='yes'
          useParentHeight:t='yes'
          noMargin:t='yes'
          on_click:t = 'onShowHelp'
        }
      }
    }

    <<#isStarted>>
    tdiv {
      id:t='tactical_map_block'
      width:t='25%pw'
      pos:t='50%pw-50%w, ph-h-0.02@scrn_tgt-0.15@wwBattleInfoScreenIncHeight'
      position:t='absolute'
      flow:t='vertical'

      ShadowPlate {
        size:t='pw, w'
        max-width:t='1@wwBattleInfoMapMaxSize'
        pos:t='50%pw-50%w, 0'; position:t='relative'
        padding:t='1@wwBattleMapShadowPadding, 0, 1@wwBattleMapShadowPadding, 1.5@wwBattleMapShadowPadding'
        tacticalMap {
          id:t='tactical_map_single'
          size:t='pw, ph'
          display:t='hide'
        }
      }
    }
    <</isStarted>>
  }
}
