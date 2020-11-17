<<#items>>
blur {}
blur_foreground {}

<<^isShowNameInHeader>>
headerBg {
  <<#headerAction>>on_click:t='<<headerAction>>'<</headerAction>>

  battlePassStamp{
    pos:t='1@blockInterval, 0.5@blockInterval'
    position:t='absolute'
  }

  <<#seasonLvlValue>>
  tdiv {
    id:t='season_lvl'
    behaviour:t='bhvUpdateByWatched'
    height:t='ph'
    left:t='1@arrowButtonWidth-w'
    position:t='relative'
    value:t='<<seasonLvlValue>>'

    textareaNoTab {
      top:t='0.5ph-0.5h'
      position:t='relative'
      text:t='#mainmenu/rank'
      margin-right:t='1@blockInterval'
      normalBoldFont:t='yes'
    }

    battlePassFlag {
      top:t='0.5ph-0.5h'
      position:t='relative'
      flagSize:t='small'

      textareaNoTab {
        id:t='flag_text'
        text:t=''
      }
    }
  }
  <</seasonLvlValue>>
}
<</isShowNameInHeader>>

expandable {
  id:t='<<performActionId>>'
  type:t='battleTask'
  <<#action>> on_click:t='<<action>>' <</action>>
  task_id:t='<<id>>'

  <<#taskStatus>>
  battleTaskStatus:t='<<taskStatus>>'
  <</taskStatus>>

  <<#showAsUsualPromoButton>>
    setStandartWidth:t='yes'
  <</showAsUsualPromoButton>>

  fullSize:t='yes'
  <<#isShowNameInHeader>>headerBg {}<</isShowNameInHeader>>
  selImg {
    header {
      position:t='relative'
      <<^headerWidth>>left:t='pw-w'<</headerWidth>>
      padding-right:t='1@blockInterval'
      <<#taskStatus>>
        statusImg {}
      <</taskStatus>>


      <<#newIconWidget>>
      tdiv {
        id:t='new_icon_widget_<<id>>'
        valign:t='center'
        <<@newIconWidget>>
      }
      <</newIconWidget>>

      <<#taskDifficultyImage>>
      cardImg {
        type:t='medium'
        background-image:t='<<taskDifficultyImage>>'
      }
      <</taskDifficultyImage>>
      <<#headerWidth>>width:t='<<headerWidth>>'<</headerWidth>>
      tdiv {
        width:t='pw'
        position:t='relative'
        top:t='0.5ph-0.5h'
        autoScrollText:t='yes'
        overflow:t='hidden'
        css-hier-invalidate:t='yes'
        textareaNoTab {
          text:t='<<title>>'
          position:t='relative'
          auto-scroll:t='medium'

          <<^showAsUsualPromoButton>>
            <<#isLowWidthScreen>>
              normalFont:t='yes'
            <</isLowWidthScreen>>
          <</showAsUsualPromoButton>>
        }
      }

      <<#refreshTimer>>
        textareaNoTab {
          id:t='tasks_refresh_timer'
          behavior:t='Timer'
          top:t='50%ph-50%h'
          position:t='relative'
          text:t=''
        }
      <</refreshTimer>>
    }

    tdiv {
      width:t='pw'
      flow:t='vertical'
      <<#isShowNameInHeader>>padding-top:t='1@blockInterval'<</isShowNameInHeader>>

      <<#taskImage>>
      img {
        width:t='pw'
        height:t='0.33*w'
        margin-top:t='0.005@scrn_tgt'
        background-image:t='<<taskImage>>'
        border:t='yes';
        border-color:t='@black' //Not a forgotten string, by design.

        <<#taskPlayback>>
        ShadowPlate {
          pos:t='pw-w, ph-h'
          position:t='absolute'
          padding:t='1@framePadding'
          playbackCheckbox {
            id:t='<<id>>_sound'
            task_id:t='<<id>>'
            on_change_value:t='switchPlaybackMode'
            playback:t='<<taskPlayback>>'
            downloading:t='<<#isPlaybackDownloading>>yes<</isPlaybackDownloading>><<^isPlaybackDownloading>>no<</isPlaybackDownloading>>'
            btnName:t='LB'
            ButtonImg{}
            descImg {
              background-image:t='#ui/gameuiskin#sound_on'
            }
            animated_wait_icon {
              background-rotation:t = '0'
            }
            playbackImg{}
          }
        }
        <</taskPlayback>>
      }
      <</taskImage>>

      <<@description>>

      <<#reward>>
      tdiv {
        left:t='pw-w'
        position:t='relative'
        textarea {
          max-width:t='fw'
          removeParagraphIndent:t='yes';
          text:t='<<rewardText>>'
          overlayTextColor:t='active'
        }
        <<@itemMarkUp>>
      }
      <</reward>>

      tdiv {
        width:t='pw'

        //Suppose that at a moment will be shown only one of two below buttons
        //So pos pw-w would not move recieve_reward button outside of window
        <<#canReroll>>
        Button_text {
          id:t = 'btn_reroll'
          task_id:t='<<id>>'
          visualStyle:t='purchase'
          text:t = '#battletask/reroll'
          on_click:t = 'onTaskReroll'
          hideText:t='yes'
          btnName:t='X'
          buttonGlance{}
          buttonWink{}
          ButtonImg {}
          textarea{
            id:t='btn_reroll_text';
            class:t='buttonText';
          }
        }
        <</canReroll>>

        <<#canGetReward>>
        Button_text {
          id:t = 'btn_recieve_reward'
          task_id:t='<<id>>'
          pos:t='pw-w, 0'
          position:t='relative'
          text:t = '#mainmenu/battleTasks/receiveReward'
          on_click:t = 'onGetRewardForTask'
          btnName:t='R3'
          visualStyle:t='secondary'
          buttonWink {}
          ButtonImg{}
        }
        <</canGetReward>>
      }
    }

    expandImg {
      id:t='expandImg'
      height:t='0.01@scrn_tgt'
      width:t='2h'
      pos:t='50%pw-50%w, ph-h'; position:t='absolute'
      background-image:t='#ui/gameuiskin#expand_info'
      background-color:t='@premiumColor'
    }

    <<#easyDailyTaskProgressValue>>
    battlePassInfoWatch {
      id:t='easy_daily_task_progress'
      css-hier-invalidate:t='yes'
      value:t='<<easyDailyTaskProgressValue>>'
      textareaNoTab {
        id:t='text'
        tinyFont:t='yes'
      }
      icon {}
    }
    <</easyDailyTaskProgressValue>>
    <<#mediumDailyTaskProgressValue>>
    battlePassInfoWatch {
      id:t='medium_daily_task_progress'
      css-hier-invalidate:t='yes'
      value:t='<<mediumDailyTaskProgressValue>>'
      textareaNoTab {
        id:t='text'
        tinyFont:t='yes'
      }
      icon {}
    }
    <</mediumDailyTaskProgressValue>>

    <<#otherTasksNumText>>
      textareaNoTab {
        text:t='<<otherTasksNumText>>'
        position:t='relative'
        pos:t='pw-w, 0'
        hideEmptyText:t='yes'
      }
    <</otherTasksNumText>>

    <<#leftSpecialTasksBoughtCountValue>>
    battlePassInfoWatch {
      id:t='left_special_tasks_bought_count'
      value:t='<<leftSpecialTasksBoughtCountValue>>'
      textareaNoTab {
        id:t='text'
        left:t='pw-w'
        position:t='relative'
      }
    }
    <</leftSpecialTasksBoughtCountValue>>

    <<#warbondLevelPlace>>
      progressBoxPlace {
        id:t='progress_box_place'
        left:t='pw-w - 0.4@warbondShopLevelItemHeight'
        position:t='relative'
        margin:t='0, 0.015@scrn_tgt'
        size:t='75%pw, 1@warbondShopLevelProgressHeight'

        <<@warbondLevelPlace>>
      }
    <</warbondLevelPlace>>

    <<#newItemsAvailable>>
      tdiv {
        width:t='pw'
        flow:t='vertical'
        margin:t='0, 0.01@scrn_tgt'
        <<#isConsoleMode>>
          tdiv {
            left:t='pw-w'
            position:t='relative'
            <<#unseenIcon>>
            unseenIcon {
              value:t='<<unseenIcon>>'
              valign:t='center'
              noMargin:t='yes'
              tooltip = '#mainmenu/newItemsAvailable'
              unseenText {}
            }
            <</unseenIcon>>
            textarea {
              text:t='#mainmenu/newItemsAvailable'
              overlayTextColor:t='warning'
            }
          }
        <</isConsoleMode>>
        <<^isConsoleMode>>
          Button_text {
            id:t = 'btn_warbond_shop'
            left:t='pw-w'
            position:t='relative'
            valign:t = 'center'
            on_click:t = 'onWarbondsShop'
            visualStyle:t='secondary'
            tooltip:t='#mainmenu/newItemsAvailable'
            buttonWink {}
            <<#unseenIcon>>
            unseenIcon {
              value:t='<<unseenIcon>>'
              valign:t='center'
              noMargin:t='yes'
              tooltip = '#mainmenu/newItemsAvailable'
              unseenText {}
            }
            <</unseenIcon>>
            text {
              text:t = '#mainmenu/btnWarbondsShop'
            }
          }
        <</isConsoleMode>>
      }
    <</newItemsAvailable>>
  }
}

collapsedContainer {
  <<#hasCollapsedText>>width:t='1@arrowButtonWidth+1@contentRightPadding'<</hasCollapsedText>>
  <<#collapsedAction>>
  on_click:t='<<collapsedAction>>Collapsed'
  focusBtnName:t='A'
  shortcut-on-hover:t='yes'
  <</collapsedAction>>

  <<^isEmptyTask>>
  shortInfoBlock {
    position:t='relative'
    left:t='pw-w'
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
    <<#shortInfoBlockWidth>>width:t='<<shortInfoBlockWidth>>'<</shortInfoBlockWidth>>
    tdiv {
      width:t='fw'
      position:t='relative'
      top:t='0.5ph-0.5h'    
      overflow:t='hidden'
      css-hier-invalidate:t='yes'
      shortHeaderText {
        text:t='<<collapsedText>>'
        auto-scroll:t='medium'
      }
    }

    shortHeaderIcon {
      <<#hasMarginCollapsedIcon>>margin-left:t='1@blockInterval'<</hasMarginCollapsedIcon>>
      text:t='<<collapsedIcon>>'
    }
  }
  <</isEmptyTask>>

  <<#needShowProgressBar>>
  progressDiv {
    left:t='pw-w'
    position:t='relative'
    margin:t='0.005@sf'
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
baseToggleButton {
  id:t='<<id>>_toggle'
  pos:t='pw-w-1@blockInterval'
  on_click:t='onToggleItem'
  type:t='right'
  directionImg {}
}

<<#isShowRadioButtons>>
  RadioButtonList {
    position:t='relative'
    pos:t='pw-w, 0'
    on_select:t = 'onSelectDifficultyBattleTasks'

    <<#radioButtons>>
    RadioButton {
      difficultyGroup:t='<<difficultyGroup>>'
      tooltip:t='<<difficultyLocName>>'
      <<#selected>>
      selected:t='yes'
      <</selected>>
      RadioButtonImg{}
      <<#radioButtonImage>>
      RadioButtonDescImg {
        background-image:t='<<radioButtonImage>>';
      }
      <</radioButtonImage>>
    }
    <</radioButtons>>
  }
<</isShowRadioButtons>>
<</items>>
