tdiv {
  id:t='airfield_object'
  size:t='pw, fh'
  flow:t='vertical'

  tdiv {
    id:t='airfields_list'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    flow:t='h-flow'
  }

  tdiv {
    id:t='airfield_block'
    size:t='pw, fh'
    flow:t='vertical'
    display:t='hide'

    textareaNoTab {
      id:t='airfield_info_text'
      width:t='pw'
      background-color:t='@objectiveHeaderBackground'
      padding:t='0, 1@framePadding'
      margin-bottom:t='1@dp'
      smallFont:t='yes'
      text-align:t='center'
      text:t=''
    }

    tdiv {
      size:t='pw, 1@mIco+2@framePadding'
      margin-bottom:t='1@dp'
      background-color:t='@objectiveHeaderBackground'

      tdiv {
        height:t='ph'
        left:t='50%pw-50%w'
        position:t='relative'

        textareaNoTab {
          id:t='free_formations_text'
          top:t='50%ph-50%h'
          position:t='relative'
          text-align:t='right'
          text:t=''
        }
        FormationRadioButtonsList {
          id:t='free_formations'
          behavior:t = 'Timer'
          top:t='50%ph-50%h'
          position:t='relative'
        }
      }
    }

    text {
      id:t='alert_text'
      width:t='pw'
      padding:t='0, 1@framePadding'
      margin-bottom:t='1@dp'
      background-color:t='@objectiveHeaderBackground'
      smallFont:t='yes'
      text-align:t='center'
      text:t='#worldwar/airfield/not_enough_units_to_send'
      overlayTextColor:t='warning'
    }

    tdiv {
      id:t='control_help'
      width:t='pw'
      background-color:t='@objectiveHeaderBackground'

      include "gui/worldWar/wwControlHelp"
    }

    tdiv {
      size:t='pw, fh'
      overflow-y:t='auto'
      scrollbarShortcuts:t='yes'
      padding-left:t='1@framePadding'

      FormationRadioButtonsList {
        id:t='cooldowns_list'
        behavior:t = 'Timer'
        pos:t='0, 0.01@scrn_tgt'
        position:t='relative'
        width:t='pw'
        flow:t='h-flow'
        flow-align:t='left'
      }
    }
  }
}
