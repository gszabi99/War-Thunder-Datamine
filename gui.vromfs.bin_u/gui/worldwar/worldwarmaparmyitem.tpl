<<#army>>
  armyBlock {
    battleDescription:t='yes'
    id:t='<<getId>>'
    <<#customWidth>>
      width:t='<<customWidth>>'
    <</customWidth>>
    <<#isInvert>>
    left:t='pw-w'; position:t='relative'
    <</isInvert>>
    <<#markSurrounded>>
      <<#getGroundSurroundingTime>>
        surrounded:t='yes'
      <</getGroundSurroundingTime>>
    <</markSurrounded>>
    <<#hasFormationData>>
      formationType:t='<<formationType>>'
      formationId:t='<<getFormationID>>'
    <</hasFormationData>>
    <<#delimetrRightPadding>>
      padding-right:t='<<delimetrRightPadding>>'
    <</delimetrRightPadding>>
    armyName:t='<<name>>'
    clanId:t='<<clanId>>'
    <<#isArmyAlwaysUnhovered>>
      canBeHovered:t='no'
    <</isArmyAlwaysUnhovered>>
    <<^isArmyAlwaysUnhovered>>
      canBeHovered:t='yes'
    <</isArmyAlwaysUnhovered>>
    <<#addArmySelectCb>>
      on_change_value:t = '<<#customCbName>><<customCbName>><</customCbName>><<^customCbName>>onChangeArmyValue<</customCbName>>'
    <</addArmySelectCb>>
    <<^addArmySelectCb>>
      <<#addArmyClickCb>>
        behavior:t='button'
        on_click:t = '<<#customCbName>><<customCbName>><</customCbName>><<^customCbName>>onClickArmy<</customCbName>>'
      <</addArmyClickCb>>
    <</addArmySelectCb>>
    <<#isGroupItem>>
      on_hover:t='onHoverArmyItem'
      on_unhover:t='onHoverLostArmyItem'

      <<^hideTooltip>>
        <<#getTooltipId>>
          title:t='$tooltipObj'
          tooltipObj {
            tooltipId:t='<<getTooltipId>>'
            on_tooltip_open:t='onGenericTooltipOpen'
            on_tooltip_close:t='onTooltipObjClose'
            display:t='hide'
            type:t='dark'
          }
        <</getTooltipId>>
      <</hideTooltip>>
    <</isGroupItem>>
    <<^isGroupItem>>
      <<#isHoveredItem>>
      on_hover:t='onHoverArmyItem'
      on_unhover:t='onHoverLostArmyItem'
      <</isHoveredItem>>
    <</isGroupItem>>

    armyIcon {
      <<#battleDescriptionIconSize>>
        battleDescriptionIconSize:t='<<battleDescriptionIconSize>>'
      <</battleDescriptionIconSize>>
      team:t='<<getTeamColor>>'
      <<#isBelongsToMyClan>>
        isBelongsToMyClan:t='yes'
      <</isBelongsToMyClan>>
      <<#isEntrenched>>
      entrenchIcon {
        pos:t='50%pw-50%w, 50%ph-50%h'
        position:t='absolute'
        background-image:t='#ui/gameuiskin#army_defense'
        background-color:t='@armyEntrencheColor'
      }
      <</isEntrenched>>
      background {
        background-image:t='#ui/gameuiskin#ww_army'
        foreground-image:t='#ui/gameuiskin#ww_select_army'
        pos:t='50%pw-50%w, 50%ph-50%h'
        position:t='absolute'
      }
      <<#reqUnitTypeIcon>>
        armyUnitType {
          width:t='pw'
          top:t='50%ph-50%h'
          position:t='absolute'
          text:t='<<getUnitTypeCustomText>>'
          text-align:t='center'
        <<#battleDescriptionIconSize>>
          battleDescriptionIconSize:t='<<battleDescriptionIconSize>>'
        <</battleDescriptionIconSize>>
        }
      <</reqUnitTypeIcon>>
      <<#showArmyGroupText>>
        armyGroupText {
          text:t='<<getArmyGroupIdx>>'
          pos:t='50%pw-50%w, 50%ph-50%h'
          position:t='absolute'
        }
      <</showArmyGroupText>>
    }

    <<#hasTextAfterIcon>>
      textAfterIcon {
        <<#battleDescriptionIconSize>>
          battleDescriptionIconSize:t='<<battleDescriptionIconSize>>'
        <</battleDescriptionIconSize>>
        pos:t='2@dp, 50%ph-50%h'
        position:t='relative'
        hideEmptyText:t='yes'
        text:t='<<getTextAfterIcon>>'
      }
    <</hasTextAfterIcon>>

    <<#isArmyReady>>
      canDeploy:t='yes'
    <</isArmyReady>>
    <<^isArmyReady>>
      arrivalTime {
        id:t='arrival_time_text'
        pos:t='1@framePadding, 50%ph-50%h'
        position:t='relative'
        hideEmptyText:t='yes'
        width:t='0.09@sf'
        text:t='<<getReinforcementArrivalTime>>'
      }
    <</isArmyReady>>

    <<#needShortInfoText>>
    <<#reqUnitTypeIcon>>
    activeText {
      top:t='50%ph-50%h'
      position:t='relative'
      padding-left:t='1@framePadding'
      text:t='<<getShortInfoText>>'
    }
    <</reqUnitTypeIcon>>
    <</needShortInfoText>>
  }
  <<#getHasVersusText>>
  activeText {
    top:t='50%ph-50%h'
    position:t='relative'
    margin:t='1@framePadding, 0'
    text:t='#country/VS'
  }
  <</getHasVersusText>>
  tdiv{
    position:t='relative'
    left:t='-1@headerIndent'
    include "gui/worldWar/wwArmyManagersStat"
  }
<</army>>
