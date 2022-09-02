tdiv {
  id:t='session_obj'
  width:t='pw'
  position:t='relative'
  padding:t='0, 1@eSItemInterval'
  flow:t='horizontal'
  smallFont:t='yes'
  <<^isTourWndAvailable>>
  display:t='hide'
  <</isTourWndAvailable>>

  activeText {
    position:t='relative'
    text:t='#tournaments/schedule'
  }

  <<#sessions>>
  tdiv {
    id:t='<<sesId>>'
    textareaNoTab {
      id:t='ses_num_txt'
      left:t='1@blockInterval'
      position:t='relative'
      text:t='<<sesNum>>'
      visualStyle:t='<<#isSelected>>sessionSelected<</isSelected>><<^isSelected>>default<</isSelected>>'
    }
  }
  <</sessions>>

  tdiv{
    height:t='1@fontHeightSmall'
    max-width:t='0.7pw'
    right:t='0'
    top:t='0.5ph-0.5h'
    position:t='relative'
    flow:t='horisontal'

    img {
      id:t='session_ico'
      size:t='1@fontHeightSmall, 1@fontHeightSmall'
      top:t='0.5ph-0.5h'
      position:t='relative'
      background-image:t='#ui/gameuiskin#<<^isSesActive>>clock_tour<</isSesActive>><<#isSesActive>>play_tour<</isSesActive>>.svg'
      background-svg-size:t='1@fontHeightSmall, 1@fontHeightSmall'
    }

    textareaNoTab {
      id:t='time_txt'
      pos:t='1@blockInterval, 0.5ph-0.5h'
      position:t='relative'
      text-align:t='right'
      overlayTextColor:t='<<overlayTextColor>>'
      text:t='<<curSesTime>>'
    }
  }
}

tdiv {
  width:t='pw'
  top:t='2@eSItemInterval'
  position:t='relative'
  padding:t='0, 1@eSItemInterval'
  flow:t='vertical'
  <<^isTourWndAvailable>>
  display:t='hide'
  <</isTourWndAvailable>>

  tdiv {
    id:t='training_nest'
    width:t='pw'
    position:t='relative'
    flow:t='horizontal'
    smallFont:t='yes'

    activeText {
      position:t='relative'
      text:t='#tournaments/training'
    }

    textareaNoTab {
      id:t='training_time'
      right:t='0'
      position:t='relative'
      text-align:t='right'
      text:t='<<curTrainingTime>>'
      overlayTextColor:t='<<#isTraining>><<overlayTextColor>><</isTraining>><<^isTraining>>active<</isTraining>>'
    }
  }

  tdiv {
    id:t='start_nest'
    width:t='pw'
    position:t='relative'
    flow:t='horizontal'
    smallFont:t='yes'

    activeText {
      position:t='relative'
      text:t='#tournaments/start'
    }

    textareaNoTab {
      id:t='start_time'
      right:t='0'
      position:t='relative'
      text-align:t='right'
      text:t='<<curStartTime>>'
      overlayTextColor:t='<<#isTraining>>active<</isTraining>><<^isTraining>><<overlayTextColor>><</isTraining>>'
    }
  }
}
