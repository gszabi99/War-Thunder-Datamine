root {
  type:t='big'
  blur {}
  blur_foreground {}

  tdiv {
    pos:t='0.5pw-0.5w, 0'
    position:t='absolute'
    size:t='1@swOrRwInVr, sh'
    background-color:t='#CC111821'
    flow:t='vertical'
    img { //top content
      width:t='pw'
      height:t='512.0/2420w'
      max-height:t='0.43ph'
      background-image:t='<<headerBackgroundImage>>'
      background-repeat:t='aspect-ratio'

      tdiv{
        position:t='absolute'
        pos:t='pw -w/2, 0'
        size:t='3((sw - 1@swOrRwInVr) $max (sw - 2420.0*0.43sh/512)), sh'
        background-image:t='!ui/gameuiskin#debriefing_bg_grad@@ss'
        bgcolor:t='#111823'
      }
      tdiv{
        position:t='absolute'
        pos:t='-w/2, 0'
        size:t='3((sw - 1@swOrRwInVr) $max (sw - 2420.0*0.43sh/512)), sh'
        background-image:t='!ui/gameuiskin#debriefing_bg_grad@@ss'
        bgcolor:t='#111823'
      }

      tdiv {
        width:t='1@rw'
        pos:t='0.5pw-0.5w, 1@bh'
        position:t='absolute'
        Button_close {
          id:t='btn_close'
          on_click:t=goBack
        }
      }

      img {
        width:t='748@sf/@pf'
        height:t='194.0/748w'
        pos:t='pw/2 - w/2, ph - h/2'
        position:t='absolute'
        background-image:t='<<chestNameBackgroundImage>>'
        background-repeat:t='aspect-ratio'

        textareaNoTab {
          width:t='0.5pw'
          pos:t='0.17pw, 0.4ph-0.5h'
          position:t='absolute'
          text:t='<<chestName>>'
          bigBoldFont:t='yes'
          overlayTextColor:t='active'
          text-align:t='center'
        }
        textareaNoTab {
          id:t='time_expired_value'
          pos:t='0.75pw, 0.4ph-0.5h'
          position:t='absolute'
          mediumFont:t="yes"
          overlayTextColor:t='gray'
          css-hier-invalidate:t='yes'
        }
      }

      tdiv {
        id:t='chest_preview'
        size:t='h, 0.7ph'
        pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
        position:t='absolute'

        img {
          id:t='chest_background_blink_anim'
          size:t='1.5pw, w'
          pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
          position:t='absolute'
          background-svg-size:t='1.5pw, w'
          background-image:t='!#ui/gameuiskin#circle_gradient_white.avif'
          wink:t='no'
          display:t='hide'
        }

        <<@chestIcon>>

        tdiv {
          id:t='open_chest_animation'
          pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
          size:t='1@chestRewardWidth, 1@chestRewardHeight'
          position:t='absolute'
          overflow:t='visible'
          behaviour:t='Timer'

          include "%gui/items/chestOpenAnim.blk"
        }
      }
      
      tdiv {
        id:t='prizes_list'
        pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
        position:t='absolute'
        display:t='hide'
      }
    }

    tdiv { //bottom content
      size:t='pw, fh'
      padding-top:t='40@sf/@pf'
      flow:t='vertical'

      Button_text {
        pos:t='0.5pw - 0.5w, 0'
        position:t='relative'
        noMargin:t='yes'
        visualStyle:t='noBgr'
        on_click:t='onShowRewards'
        btnName:t='Y'
        ButtonImg{}

        btnText { id:t='contains_items_txt' }
        img {
          position:t='relative'
          top:t='0.5ph-0.5h'
          size:t='1@buttonHeight, 1@buttonHeight'
          background-svg-size:t='1@buttonHeight, 1@buttonHeight'
          background-image:t='#ui/gameuiskin#chat_icon_attention.avif'
        }
      }

      tdiv {
        size:t='389@sf/@pf, 78@sf/@pf'
        pos:t='0.5pw - 0.5w, 0'
        position:t='relative'
        margin-top:t='20@sf/@pf'

        Button_text{
          id:t='btn_buy'
          size:t='0, ph'
          pos:t='0.5pw - 0.5w, 0'
          position:t='relative'
          hideText:t='yes'
          btnName:t='X'
          visualStyle:t='purchase'
          parentWidth:t='yes'
          on_click:t = 'onBuy'
          buttonWink{}
          buttonGlance{}
          textarea{
            id:t='btn_buy_text'
            class:t='buttonText'
          }
          ButtonImg {}
          enable:t='no'
          display:t='hide'
        }

        Button_text {
          id:t='btn_open'
          size:t='0, ph'
          pos:t='0.5pw - 0.5w, 0'
          position:t='relative'
          hideText:t='yes'
          btnName:t='X'
          class:t='battle'
          parentWidth:t='yes'
          on_click:t = 'onOpen'
          pattern{}
          buttonWink { _transp-timer:t='0' }
          buttonGlance {}
          btnText {
            id:t='btn_open_text'
            text:t = '#item/consume'
          }
          ButtonImg {}
          enable:t='no'
          display:t='hide'
        }

        animated_wait_icon {
          id:t='wait_image'
          pos:t='0.5pw-0.5w, 0.5ph-0.5h'
          position:t='relative'
          background-rotation:t='0'
        }
      }

      tdiv {
        id:t='userstat_rewards_nest'
        size:t='pw, fh'
        behaviour:t='bhvUpdateByWatched'
        padding-top:t='40@sf/@pf'
        flow:t='vertical'

        activeText {
          id:t='progress_text'
          pos:t='pw/2-w/2, 0'
          position:t='relative'
        }

        textareaNoTab {
          id:t='progress_desc'
          pos:t='pw/2-w/2, 1@blockInterval'
          position:t='relative'
        }

        tdiv {
          id:t='rewards_list'
          pos:t='pw/2-w/2, 0.5@dIco'
          position:t='relative'
        }

        Button_text {
          id:t='reward_btn'
          pos:t='pw/2-w/2, 0'
          position:t='relative'
          text:t = '#items/getReward'
          btnName:t='RB'
          visualStyle:t='secondary'
          on_click:t = 'onReceiveRewards'
          buttonWink{}
          ButtonImg {}
        }
      }
    }
  }
}

timer {
  id:t='update_timer'
  timer_handler_func:t='onTimer'
  timer_interval_msec:t='1000'
}
