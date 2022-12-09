<<#operationLogRow>>
tdiv {
  id:t=''
  width:t='pw'
  flow:t='vertical'
  display:t='hide'

  tdiv {
    id:t='date'
    position:t='relative'
    width:t='pw'
    height:t='1@logBlockHeaderHeight'
    background-color:t='@objectiveHeaderBackground'
    margin-bottom:t='0.01@scrn_tgt'

    textareaNoTab {
      id:t='date_text'
      width:t='pw'
      padding-left:t='0.01@scrn_tgt'
      valign:t='center'
    }
  }

  tdiv {
    width:t='pw'

    cardImg {
      id:t='log_icon'
      pos:t='1@framePadding, 1@framePadding'
      position:t='relative'
      type:t='veryTiny'
      logCategoryName:t=''
      background-image:t='#ui/gameuiskin#icon_type_log_army.png'
    }

    textareaNoTab {
      id:t='log_time'
      position:t='relative'
      width:t='@wwLogTimeColumnWidth'
      padding-right:t='0.4@framePadding'
      text-align:t='right'
      tooltip:t=''
    }

    textareaNoTab {
      id:t='log_zone'
      position:t='relative'
      width:t='@wwLogZoneColumnWidth'
      text-align:t='center'
      isYourZone:t='yes'
      on_hover:t='onHoverZoneName'
      on_unhover:t='onHoverLostZoneName'
    }

    tdiv {
      id:t='log_body'
      width:t='fw'
      margin-bottom:t='1@framePadding'
      flow:t='h-flow'
      padding-left:t='0.002@scrn_tgt'

      textareaNoTab {
        id:t='army'
        width:t='1@wwArmySmallIconWidth'
        margin-right:t='1@framePadding'
        text:t=' '

        tdiv {
          id:t='army_container'
          top:t='50%ph-50%h'
          position:t='absolute'
          include "%gui/worldWar/wwOperationLogArmyItem.tpl"
        }
      }

      textareaNoTab {
        id:t='log_text'
        position:t='relative'
        tooltip:t=''
      }

      tdiv {
        id:t='battle'

        textareaNoTab {
          id:t='army_side_1'
          width:t='1@wwArmySmallIconWidth'
          behavior:t='button'
          armyId:t=''
          focusBtnName:t='A'
          showConsoleImage:t='no'
          on_click:t = 'onClickArmy'
          text:t=' '

          tdiv {
            id:t='army_side_1_container'
            top:t='50%ph-50%h'
            position:t='absolute'
            <<#battleArmy>>
            include "%gui/worldWar/wwOperationLogArmyItem.tpl"
            <</battleArmy>>
          }
        }

        textareaNoTab {
          width:t='@wwArmySmallIconWidth'
          text:t=' '

          wwBattleIcon{
            id:t='battle_icon'
            status:t=''
            battleId:t=''
            behavior:t='button'
            on_click:t ='onClickBattle'
            on_hover:t='onHoverBattle'
            on_unhover:t='onHoverLostBattle'

            title:t='$tooltipObj'
            tooltipObj {
              id:t='battle_icon_tooltip'
              on_tooltip_open:t='onGenericTooltipOpen'
              on_tooltip_close:t='onTooltipObjClose'
              display:t='hide'
            }
          }
        }

        textareaNoTab {
          id:t='army_side_2'
          width:t='1@wwArmySmallIconWidth'
          behavior:t='button'
          armyId:t=''
          focusBtnName:t='A'
          showConsoleImage:t='no'
          on_click:t = 'onClickArmy'
          text:t=' '

          tdiv {
            id:t='army_side_2_container'
            top:t='50%ph-50%h'
            position:t='absolute'
            <<#battleArmy>>
            include "%gui/worldWar/wwOperationLogArmyItem.tpl"
            <</battleArmy>>
          }
        }
      }

      <<#damagedArmy>>
      tdiv {
        id:t='damaged_army_<<idx>>'
        margin-left:t='1@framePadding'

        textareaNoTab {
          id:t='army_casualties'
          text:t=''
        }

        textareaNoTab {
          width:t='1@wwArmySmallIconWidth'
          text:t=' '

          tdiv {
            id:t='army_container'
            top:t='50%ph-50%h'
            position:t='relative'
            include "%gui/worldWar/wwOperationLogArmyItem.tpl"
          }
        }
      }
      <</damagedArmy>>
    }
  }
}
<</operationLogRow>>
