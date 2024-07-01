tdiv {
  id:t='battle_results'
  size:t='pw, ph'
  flow:t='vertical'

  debrBlock {
    width:t='pw'
    padding:t='1@debrPad'

    tdiv {
      size:t='pw, 1@wwSmallCountryFlagHeight'
      pos:t='0, 1@debrPad'
      position:t='absolute'

      textareaNoTab {
        pos:t='pw/2-w/2, ph/2-h/2'
        position:t='absolute'
        text:t='<<getBattleResultText>>'
        mediumFont:t='yes'
      }

      <<#isBattleResultsIgnored>>
      textareaNoTab {
        max-width:t='pw-120@sf/@pf_outdated'
        pos:t='pw/2-w/2, ph'
        position:t='absolute'
        text-align:t='center'
        text:t='#worldwar/operation_complete_battle_results_ignored'
        overlayTextColor:t='userlog'
      }
      <</isBattleResultsIgnored>>
    }

    <<#teamBlock>>
    tdiv {
      size:t='50%pw'
      flow:t='vertical'

      img{
        position:t='relative'
        iconType:t='small_country'
        <<^invert>>pos:t='0, 0'<</invert>>
        <<#invert>>pos:t='pw-w, 0'<</invert>>
        background-image:t='<<countryIcon>>'
      }

      <<#armies>>
      tdiv {
        size:t='pw, 1@mIco'
        margin-top:t='0.005@scrn_tgt'
        <<^invert>>flow-align:t='left'<</invert>>
        <<#invert>>flow-align:t='right'<</invert>>

        <<#armyView>>
        <<#invert>>
        textareaNoTab {
          valign:t='center'
          caption:t='yes'
          text:t='<<getTextAfterIcon>>'
        }
        <</invert>>
        armyIcon {
          team:t='<<getTeamColor>>'
          <<#isBelongsToMyClan>>
          isBelongsToMyClan:t='yes'
          <</isBelongsToMyClan>>

          background {
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
            background-image:t='#ui/gameuiskin#ww_army'
            foreground-image:t='#ui/gameuiskin#ww_select_army'
          }
          armyUnitType {
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
            text:t='<<getUnitTypeCustomText>>'
          }
        }
        <<^invert>>
        textareaNoTab {
          valign:t='center'
          caption:t='yes'
          text:t='<<getTextAfterIcon>>'
        }
        <</invert>>
        <</armyView>>
      }

      tdiv {
        width:t='pw'
        <<^invert>>flow-align:t='left'<</invert>>
        <<#invert>>flow-align:t='right'<</invert>>

        textareaNoTab {
          tinyFont:t='yes'
          text:t='<<armyStateText>>'
        }
      }
      <</armies>>
    }
    <</teamBlock>>

    debrSeparator { class:t='bottom' }
  }

  tdiv {
    id:t='ww_battle_results_scroll_block'
    size:t='pw, fh'
    overflow-y:t='auto'
    scrollbarShortcuts:t='yes'

    <<#teamBlock>>
    <<#statistics>>
    debrBlock {
      width:t='pw/2'
      min-height:t='ph'
      padding:t='1@debrPad'
      flow:t='vertical'

      tdiv {
        width:t='pw'

        textareaNoTab {
          width:t='0.4pw'
          text:t=''
        }
        textareaNoTab {
          width:t='0.2pw'
          text-align:t='center'
          text:t='#debriefing/ww_engaged'
        }
        textareaNoTab {
          width:t='0.2pw'
          text-align:t='center'
          text:t='#debriefing/ww_casualties'
        }
        textareaNoTab {
          width:t='0.2pw'
          text-align:t='center'
          text:t='#debriefing/ww_left'
        }
      }

      tdiv {
        size:t='pw, @tableIcoSize'
      }

      <<#unitTypes>>
      tdiv {
        width:t='pw'

        textareaNoTab {
          width:t='0.4pw'
          pos:t='0, ph/2-h/2'
          position:t='relative'
          pare-text:t='yes'
          text:t='<<name>>'
        }

        <<#row>>
          textareaNoTab {
            width:t='0.2pw'
            pos:t='0, ph/2-h/2'
            position:t='relative'
            text-align:t='center'
            text:t='<<col>>'
            <<#tooltip>>
            tooltip:t='<<tooltip>>'
            <</tooltip>>
          }
        <</row>>
      }
      <</unitTypes>>

      tdiv {
        size:t='pw, @tableIcoSize'
      }

      <<#units>>
      tdiv {
        width:t='pw'

        tdiv {
          width:t='0.4pw'
          pos:t='0, ph/2-h/2'
          position:t='relative'

          include "%gui/worldWar/worldWarArmyInfoUnitString.tpl"
        }

        <<#row>>
          textareaNoTab {
            width:t='0.2pw'
            pos:t='0, ph/2-h/2'
            position:t='relative'
            text-align:t='center'
            text:t='<<col>>'
            <<#tooltip>>
            tooltip:t='<<tooltip>>'
            <</tooltip>>
          }
        <</row>>
      }
      <</units>>

      <<#invert>>
      debrSeparator { class:t='left' }
      <</invert>>
    }
    <</statistics>>
    <</teamBlock>>
  }
}
