tdiv {
  id:t='ready_reinforcements_block'
  padding:t='1@framePadding'
  width:t='pw'
  flow:t='vertical'
  background-color:t='@objectiveHeaderBackground'

  tdiv {
    id:t='ready_label'
    flow:t='vertical'

    textareaNoTab {
      pos:t='0, 0'
      position:t='relative'
      text:t='#worldwar/state/reinforcement_ready'
      overlayTextColor:t='active'
      smallFont:t='yes'
    }
  }

  ReinforcementsRadioButtonsList {
    id:t='ready_reinforcements_list'
    width:t='pw'
    flow:t='h-flow'
    flow-align:t='left'
  }

  div {
    id:t='deploy_hint_nest'
    margin-top:t='1@blockInterval'
    display:t='hide'
    include "%gui/worldWar/wwControlHelp"
  }

  textareaNoTab {
    id:t='no_ready_reinforcements_text'
    text:t='#worldwar/noreadyreinforcements'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    overlayTextColor:t='faded'
  }
}

tdiv {
  id:t='coming_reinforcements_block'
  padding:t='1@framePadding'
  width:t='pw'
  flow:t='vertical'

  textareaNoTab {
    id:t='arrival_speed_text'
    text:t=''
    smallFont:t='yes'
  }

  ReinforcementsRadioButtonsList {
    id:t='reinforcements_list'
    behavior:t = 'Timer'
    width:t='pw'
    flow:t='h-flow'
    flow-align:t='left'
  }
}

textareaNoTab {
  id:t='no_reinforcements_text'
  text:t='#worldwar/noreinforcements'
  pos:t='50%pw-50%w, 0.02@scrn_tgt'
  position:t='relative'
  overlayTextColor:t='faded'
}
