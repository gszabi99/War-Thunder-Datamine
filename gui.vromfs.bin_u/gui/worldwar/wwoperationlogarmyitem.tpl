armyBlock {
  id:t=''
  behavior:t='button'
  display:t='hide'
  armyId:t=''
  selected:t='no'
  isForceHovered:t='no'
  on_click:t = 'onClickArmy'
  focusBtnName:t='A'
  showConsoleImage:t='no'
  on_hover:t='onHoverArmyItem'
  on_unhover:t='onHoverLostArmyItem'

  armyIcon {
    id:t="army_icon"
    team:t='blue'
    isBelongsToMyClan:t='no'
    battleDescriptionIconSize:t='small'

    entrenchIcon {
      id:t="army_entrench_icon"
      size:t='1@mIco, 1@mIco'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
      background-image:t='#ui/gameuiskin#army_defense'
      background-color:t='@armyEntrencheColor'
      display:t='hide'
    }

    background {
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
      background-image:t='#ui/gameuiskin#ww_army'
      foreground-image:t='#ui/gameuiskin#ww_select_army'
    }

    armyUnitType {
      id:t="army_unit_text"
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
      battleDescriptionIconSize:t='small'
    }
  }
}
