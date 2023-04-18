<<#itemButtons>>
<<#hasToBattleButton>>
Button_text {
  id:t='slotBtn_battle'
  class:t='battle'
  noMargin:t='yes'
  text:t=''
  css-hier-invalidate:t='yes'
  on_click:t='<<toBattleButtonAction>>'
  navButtonFont:t='yes'
  showConsoleImage:t='no'

  buttonWink {
    _transp-timer:t='0'
  }

  buttonGlance {}

  pattern {
    type:t='bright_texture'
  }

  textarea {
    id:t='slotBtn_battle_text'
    font-bold:t='@fontTiny'
    text:t=''
  }
}
<</hasToBattleButton>>

tdiv {
  height:t='@dIco'
  pos:t='0.002@scrn_tgt, ph-h-0.005@scrn_tgt'
  position:t='absolute'
  input-transparent:t='yes'

<<#specIconBlock>>
specIconBlock {
  <<#specTypeIcon>>
  tooltip:t='<<specTypeTooltip>>'
  shopTrainedImg {
    background-image:t='<<specTypeIcon>>'
  }
  <</specTypeIcon>>
  <<#showWarningIcon>>
  warningIcon {
    tooltip:t='#mainmenu/selectCrew/haveMoreQualified/tooltip'
  }
  <</showWarningIcon>>
}
<</specIconBlock>>

<<#hasRepairIcon>>
repairIcon {
  _transp-timer:t='0'
}
<</hasRepairIcon>>

<<#weaponsStatus>>
weaponsIcon {
  id:t='weapons_icon'
  _transp-timer:t='0'
  weaponsStatus:t='<<weaponsStatus>>'
}
<</weaponsStatus>>
}

<<#hasRentIcon>>
rentIcon {
  id:t='rent_icon'
  <<#hasRentProgress>>
  progress {
    id:t='rent_progress'
    sector-angle-1:t='<<rentProgress>>'
  }
  <</hasRentProgress>>
  icon {}
}
<</hasRentIcon>>

<</itemButtons>>
