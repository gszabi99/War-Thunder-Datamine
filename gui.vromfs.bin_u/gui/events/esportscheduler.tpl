tdiv {
  id:t='scheduler_obj'
  width:t='1@eSItemWidth'
  left:t='0.5pw-0.5w'
  position:t='relative'
  padding:t='2@eSItemInterval, 1@eSItemInterval'
  <<#isFinished>>
  display:t='hide'
  <</isFinished>>
  flow:t='vertical'
  // HEADER
  img {
    size:t='pw, 1@fontHeightNormal+2@eSItemInterval'
    position:t='absolute'
    background-repeat:t='repeat-x'
    background-image:t='#ui/gameuiskin#header_grey.png'
  }

  tdiv {
    width:t='pw'
    position:t='relative'
    flow:t='horizontal'
    smallFont:t='yes'
    textareaNoTab {
      position:t='relative'
      text:t='#tournaments/schedule'
    }

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
  <<#sessions>>
  tdiv {
    id:t='<<sesId>>'
    width:t='pw'
    top:t='2@eSItemInterval'
    position:t='relative'
    padding-bottom:t='1@eSItemInterval'
    flow:t='horizontal'

    img {
      id:t='scheduler_bgr'
      size:t='pw+4@eSItemInterval, ph-1@eSItemInterval'
      left:t='0.5pw-0.5w'
      position:t='absolute'
      background-color:t='@sessionScheduleColor'
    }

    textareaNoTab {
      id:t='ses_num_txt'
      width:t='50@sf/@pf'
      pos:t='-10@sf/@pf-2@eSItemInterval, 0.5ph-0.5h'
      position:t='relative'
      text:t='<<sesNum>>'
      text-align:t='right'
      visualStyle:t='<<#isSelected>>sessionSelected<</isSelected>><<^isSelected>><</isSelected>>'
    }
    tdiv {
      width:t='pw'
      position:t='relative'
      padding:t='2@eSItemInterval, 1@eSItemInterval'
      flow:t='vertical'

      tdiv {
        id:t='training_nest'
        width:t='pw'
        position:t='relative'
        flow:t='horizontal'
        smallFont:t='yes'

        textareaNoTab {
          position:t='relative'
          text:t='#tournaments/training'
        }

        textareaNoTab {
          id:t='training_time'
          right:t='0'
          position:t='relative'
          text-align:t='right'
          text:t='<<trainingTime>>'
          <<#isSelected>>
          <<#isTraining>>
          overlayTextColor:t='<<overlayTextColor>>'
          <</isTraining>>
          <</isSelected>>
        }
      }
      tdiv {
        id:t='start_nest'
        width:t='pw'
        position:t='relative'
        flow:t='horizontal'
        smallFont:t='yes'

        textareaNoTab {
          position:t='relative'
          text:t='#tournaments/start'
        }

        textareaNoTab {
          id:t='start_time'
          right:t='0'
          position:t='relative'
          text-align:t='right'
          text:t='<<startTime>>'
          <<#isSelected>>
          <<^isTraining>>
          overlayTextColor:t='<<overlayTextColor>>'
          <</isTraining>>
          <</isSelected>>
        }
      }
    }
  }
  <</sessions>>
}
