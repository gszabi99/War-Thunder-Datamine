blur {}
blur_foreground {}

expandable {
  id:t='<<performActionId>>'
  <<#action>> on_click:t='<<action>>' <</action>>

  fullSize:t='yes'
  headerBg {
    battlePassStamp{
      pos:t='1@blockInterval, 0.5@blockInterval'
      position:t='absolute'
    }

    tdiv {
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
  }

  <<#rewards>>
  reward {
    <<#id>>
      id:t='<<id>>'
    <</id>>
    behaviour:t='bhvUpdateByWatched'
    value:t='<<hasRewardValue>>'
    padding-left:t='1@blockInterval'
    display:t='hide'
    img {
      size:t='@cIco, @cIco'
      pos:t='0, ph/2-h/2'
      background-image:t='<<rewardIcon>>'
      background-svg-size:t='@cIco, @cIco'
    }
    tdiv {
      width:t='fw'
      overflow:t='hidden'
      textareaNoTab {
        id:t='promo_reward_text'
        text:t='<<rewardText>>'
        behaviour:t='OverflowScroller'
        move-pixel-per-sec:t='20*@scrn_tgt/100.0'
        move-sleep-time:t='1000'
        move-delay-time:t='1000'
      }
    }
  }
  <</rewards>>
  timer {
    id:t='expired_timer'
    timer_handler_func:t ='updateExpiredTime'
    timer_interval_msec:t='1000'
  }
}
