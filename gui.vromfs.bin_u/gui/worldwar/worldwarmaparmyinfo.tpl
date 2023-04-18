tdiv {
  size:t='1@wwMapPanelInfoWidth, ph'
  flow:t='vertical'

  ownerPanel {
    size:t='pw, 1@ownerPanelHeight'
    margin:t='0, 1@framePadding'

    tdiv {
      size:t='pw/3, ph'
      cardImg {
        pos:t='50%pw-50%w, 50%ph-50%h'
        position:t='relative'
        background-image:t='<<getCountryIcon>>'
      }
    }

    tdiv {
      size:t='pw/3, ph'
      tdiv {
        pos:t='50%pw-50%w, 0'
        position:t='relative'
        height:t='ph'
        armyIcon {
          pos:t='0, 50%ph-50%h'
          position:t='relative'
          team:t='<<getTeamColor>>'
          <<#isBelongsToMyClan>>
            isBelongsToMyClan:t='yes'
          <</isBelongsToMyClan>>
          background {
            background-image:t='#ui/gameuiskin#ww_army'
            foreground-image:t='#ui/gameuiskin#ww_select_army'
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
          }
          armyUnitType {
            text:t='<<getUnitTypeCustomText>>'
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
          }
          <<#showArmyGroupText>>
          armyGroupText {
            text:t='<<getArmyGroupIdx>>'
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
          }
          <</showArmyGroupText>>
        }
        textareaNoTab {
          top:t='50%ph-50%h'
          position:t='relative'
          padding-left:t='1@blockInterval'
          text:t='#worldwar/<<getMapObjectName>>'
        }
        textareaNoTab {
          top:t='50%ph-50%h'
          position:t='relative'
          padding-left:t='1@blockInterval'
          text:t='<<getZoneName>>'
          hideEmptyText:t='yes'
        }
      }
    }

    tdiv {
      size:t='pw/3, ph'
      clanTag {
        pos:t='50%pw-50%w, 50%ph-50%h'
        position:t='relative'
        hideEmptyText:t='yes'
        text:t='<<clanTag>>'
      }
    }
  }

  statusPanel {
    size:t='pw, 1@statusPanelHeight'
    background-color:t='@objectiveHeaderBackground'
    <<#needSmallSize>>needSmallSize:t='yes'<</needSmallSize>>

    <<#isFormation>>
      block {
        activeText {
          id:t='army_count'
          tooltip:t='<<getUnitsIconTooltip>>'
          text:t='<<getUnitsCountTextIcon>>'
        }
      }
      block {
        activeText {
          id:t='army_morale'
          tooltip:t='<<getMoraleIconTooltip>>'
          text:t='<<getMoralText>>'
          blockSeparator{}
        }
      }
    <</isFormation>>
    <<^isFormation>>
      block {
        hasTimer:t='yes'
        activeText {
          id:t='army_status_time'
          tooltip:t='<<getActionStatusIconTooltip>>'
          text:t='<<getActionStatusTimeText>>'
        }
      }
      block {
        activeText {
          id:t='army_count'
          tooltip:t='<<getUnitsIconTooltip>>'
          text:t='<<getUnitsCountTextIcon>>'
          blockSeparator{}
        }
      }
      <<#hasArtilleryAbility>>
        block {
          activeText {
            id:t='army_ammo'
            tooltip:t='<<getAmmoTooltip>>'
            text:t='<<getAmmoText>>'
            blockSeparator{}
          }
        }
        block {
          hasTimer:t='yes'
          activeText {
            id:t='army_ammo_refill_time'
            tooltip:t='<<getAmmoRefillTimeTooltip>>'
            text:t='<<getAmmoRefillTime>>'
            blockSeparator{}
          }
        }
      <</hasArtilleryAbility>>
      <<^isArtillery>>
        block {
          activeText {
            id:t='army_morale'
            tooltip:t='<<getMoraleIconTooltip>>'
            text:t='<<getMoralText>>'
            blockSeparator{}
          }
        }
        block {
          hasTimer:t='yes'
          activeText {
            id:t='army_return_time'
            tooltip:t='<<getArmyReturnTimeTooltip>>'
            text:t='<<getAirFuelLastTime>>'
            blockSeparator{}
          }
        }
      <</isArtillery>>
    <</isFormation>>
  }

  armyAlertPanel {
    size:t='pw, 0.03@sf'
    margin-top:t='1'
    isAlert:t='no'
    <<^getArmyInfoText>>
      display:t='hide'
    <</getArmyInfoText>>
    textarea {
      id:t='army_info_text'
      pos:t='0, 50%ph-50%h';
      position:t='relative'
      text-align:t='center'
      width:t='pw'
      smallFont:t='yes'
      overlayTextColor:t='silver'
      text:t='<<getArmyInfoText>>'
    }
  }

  armyAlertPanel {
    size:t='pw, 0.03@sf'
    margin-top:t='1'
    isAlert:t='<<isAlert>>'
    <<^getArmyAlertText>>
      display:t='hide'
    <</getArmyAlertText>>
    textarea {
      id:t='army_alert_text'
      pos:t='0, 50%ph-50%h';
      position:t='relative'
      text-align:t='center'
      width:t='pw'
      smallFont:t='yes'
      overlayTextColor:t='silver'
      text:t='<<getArmyAlertText>>'
    }
  }

  armyGroup {
    id:t='<<name>>'
    width:t='pw'

    <<@unitsList>>
  }
}
