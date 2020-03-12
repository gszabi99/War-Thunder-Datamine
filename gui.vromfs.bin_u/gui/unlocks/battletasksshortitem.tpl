<<#items>>
tdiv {
  padding:t='1@blockInterval'
  flow:t='vertical'
  shortInfoBlock {
    <<#taskStatus>>
      battleTaskStatus:t='<<taskStatus>>'
      statusImg {}
    <</taskStatus>>
    <<#taskDifficultyImage>>
      cardImg {
        type:t='medium'
        background-image:t='<<taskDifficultyImage>>'
      }
    <</taskDifficultyImage>>
    shortHeaderText { text:t='<<title>>' }

    <<#shouldRefreshTimer>>
      textareaNoTab {
        id:t='tasks_refresh_timer'
        behavior:t='Timer'
        top:t='50%ph-50%h'
        position:t='relative'
        text:t=''
      }
    <</shouldRefreshTimer>>

    <<^needShowProgressBar>>
      <<#needShowProgressValue>>
        shortHeaderText { text:t=' (<<progressValue>>/<<progressMaxValue>>) ' }
      <</needShowProgressValue>>
    <</needShowProgressBar>>
  }

  <<#needShowProgressBar>>
  progressDiv {
    position:t='relative'
    margin-bottom:t='0.005@sf'
    battleTaskProgress {
      top:t='50%ph-50%h'
      position:t='relative'
      width:t='0.4@arrowButtonWidth'
      value:t='<<progressBarValue>>'
    }
    <<#needShowProgressValue>>
    textarea {
      text:t='( <<progressValue>> / <<progressMaxValue>> )'
      smallFont:t='yes'
      overlayTextColor:t='disabled'
    }
    <</needShowProgressValue>>
  }
  <</needShowProgressBar>>

  <<#canGetReward>>
  Button_text {
    id:t = 'btn_recieve_reward'
    task_id:t='<<id>>'
    position:t='relative'
    text:t = '#mainmenu/battleTasks/receiveReward'
    on_click:t = 'onGetRewardForTask'
    btnName:t='R3'
    visualStyle:t='secondary'
    buttonWink {}
    ButtonImg{}
  }
  <</canGetReward>>

  <<#getTooltipId>>
    title:t='$tooltipObj'
    tooltipObj {
      tooltipId:t='<<getTooltipId>>'
      display:t='hide'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
    }
  <</getTooltipId>>
}
<</items>>
