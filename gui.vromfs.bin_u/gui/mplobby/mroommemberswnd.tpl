root {
  background-color:t='@shadeBackgroundColor'

  frame {
    width:t='1@sf'
    pos:t='50%pw-50%w, 1@minYposWindow + 0.5@maxWindowHeightWithSlotbar - 0.5h'
    position:t='root'

    <<#navBar>>
    class:t='wndNav'
    <</navBar>>
    <<^navBar>>
    class:t='wnd'
    <</navBar>>

    frame_header {
      <<#headerData>>
      img {
        id:t='difficulty_img'
        size:t='1@unlockStageIconSize,1@unlockStageIconSize'
        pos:t='0,50%ph-50%h'
        position:t='relative'
        background-image:t='<<difficultyImage>>'
        tooltip:t='<<difficultyTooltip>>'
      }

      activeText {
        id:t='header'
        caption:t='yes'
        text:t='<<headerText>>'
      }
      <</headerData>>

      top_right_holder {
        hasRightIndent:t='yes'
        textareaNoTab {
          id:t='event_time'
          pos:t='0, 50%ph-50%h'
          position:t='relative'
          text:t=''
          behavior:t = 'Timer'
        }
      }

      Button_close {}
    }

    tdiv {
      id:t='teams_header'
      width:t='pw'
      css-hier-invalidate:t='yes'

      teamAImg{ margin-right:t='1@blockInterval' }
      activeText {
        id:t = 'num_teamA'
        top:t='50%ph-50%h'; position:t="relative"
      }

      tdiv { width:t='fw' }

      activeText {
        id:t = 'num_teamB'
        top:t="50%ph-50%h"; position:t="relative"
        text-align:t='right'
      }
      teamBImg{ margin-left:t='1@blockInterval' }
    }

    tdiv {
      id:t = 'players_list'
      size:t = 'pw, <<maxRows>>@rows16height'
      pos:t='0, 1@blockInterval'
      position:t='relative'
      overflow-y:t='auto'
    }

    <<#navBar>>
    navBar {
      include "gui/commonParts/navBar"
    }
    <</navBar>>
  }

  timer {
    id:t='update_timer'
    timer_handler_func:t='onUpdate'
    timer_interval_msec:t='1000'
  }
}