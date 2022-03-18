<<#items>>
expandable {
  id:t='<<#performActionId>><<performActionId>><</performActionId>><<^performActionId>><<id>><</performActionId>>'
  type:t='battleTask'
  <<^isOnlyInfo>>
    <<#action>> on_click:t='<<action>>' <</action>>
    <<#hoverAction>> on_hover:t='<<hoverAction>>' <</hoverAction>>
  <</isOnlyInfo>>
  task_id:t='<<id>>'

  <<#taskStatus>>
  battleTaskStatus:t='<<taskStatus>>'
  <</taskStatus>>

  fullSize:t='yes'
  selImg {
    <<#isSmallText>>
    smallFont:t='yes'
    <</isSmallText>>
    header {
      width:t='pw'

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

      textareaNoTab {
        text:t='<<title>>'
        top:t='50%ph-50%h'
        width:t='fw'
        position:t='relative'
        overlayTextColor:t='active'

        <<#isLowWidthScreen>>
        normalFont:t='yes'
        <</isLowWidthScreen>>
      }
      <<#isFavorite>>
      CheckBox {
        id:t='checkbox_favorites'
        unlockId :t='<<id>>'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        showOnSelect:t='hover'
        text:t='#mainmenu/UnlockAchievementsToFavorite'
        value:t='<<isFavorite>>'
        on_change_value:t='unlockToFavorites'
        btnName:t=''
        skip-navigation:t='yes'
        display:t = 'hide'
        enable:t='no'
        CheckBoxImg{}
        ButtonImg{
          showOnSelect:t='hover'
          btnName:t='A'
        }
      }
      <</isFavorite>>
      <<#taskHeaderCondition>>
      textareaNoTab {
        text:t='<<taskHeaderCondition>>'
        overlayTextColor:t='active'
        top:t='50%ph-50%h'
        position:t='relative'
        overlayTextColor:t='active'

        <<#isLowWidthScreen>>
        normalFont:t='yes'
        <</isLowWidthScreen>>
      }
      <</taskHeaderCondition>>

      <<#taskStatus>>
        statusImg {}
      <</taskStatus>>
    }

    hiddenDiv {
      width:t='pw'
      flow:t='vertical'
      <<#isOnlyInfo>> showHidden:t='yes' <</isOnlyInfo>>

      <<^isOnlyInfo>>
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
              background-image:t='#ui/gameuiskin#sound_on.svg'
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
      <</isOnlyInfo>>

      <<@description>>

      <<#reward>>
      tdiv {
        left:t='pw-w'
        position:t='relative'
        flow:t='vertical'
        textareaNoTab {
          max-width:t='fw'
          removeParagraphIndent:t='yes';
          text:t='<<rewardText>>'
          overlayTextColor:t='active'
          text-align:t='right'
        }
        <<@itemMarkUp>>
      }
      <</reward>>

      <<^isOnlyInfo>>
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
          btnName:t='Y'
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
          btnName:t='Y'
          visualStyle:t='secondary'
          buttonWink {}
          ButtonImg {
           showOnSelect:t='hover'
          }
        }
        <</canGetReward>>
      }
      <</isOnlyInfo>>
    }

    expandImg {
      id:t='expandImg'
      height:t='0.01@scrn_tgt'
      width:t='2h'
      pos:t='50%pw-50%w, ph-h'; position:t='absolute'
      background-image:t='#ui/gameuiskin#expand_info'
      background-color:t='@premiumColor'
      <<#isOnlyInfo>> hideExpandImg:t='yes' <</isOnlyInfo>>
    }
  }

  fgLine {}
}
<</items>>
