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
      height:t='<<headerBackgroundImageHeight>>'
      max-height:t='<<headerBackgroundImageMaxHeight>>'
      background-image:t='<<headerBackgroundImage>>'
      background-repeat:t='aspect-ratio'

      tdiv{
        position:t='absolute'
        pos:t='pw -w/2, 0'
        size:t='<<bgCornersShadowSize>>'
        background-image:t='!ui/gameuiskin#debriefing_bg_grad@@ss'
        bgcolor:t='#111823'
      }
      tdiv{
        position:t='absolute'
        pos:t='-w/2, 0'
        size:t='<<bgCornersShadowSize>>'
        background-image:t='!ui/gameuiskin#debriefing_bg_grad@@ss'
        bgcolor:t='#111823'
      }

      tdiv {
        width:t='1@rw'
        pos:t='0.5pw-0.5w, 1@bh'
        position:t='absolute'
        tdiv {
          position:t='absolute'
          pos:t='pw-w-1@buttonCloseHeight, 0'

          Button_text {
            id:t='gc_warpoints'
            visualStyle:t='noFrame'
            tooltip:t='#mainmenu/warpoints'
            showBonusPersonal:t=''
            showBonusCommon:t=''
            _on_click:t='onOnlineShopLions'

            img {
              isFirstLeft:t='yes'
              size:t='@cIco, @cIco'
              background-image:t='#ui/gameuiskin#shop_warpoints.svg'
              background-svg-size:t='@cIco, @cIco'
            }

            btnText {
              id:t='gc_balance'
              min-width:t='0.05@sf'
              pos:t='1@blockInterval, 50%ph-50%h'
              position:t='relative'
              text-align:t='left'
            }

            BonusCorner {bonusType:t='personal'}
            BonusCorner {bonusType:t='common'}
            chapterSeparator {
              position:t='absolute'
              pos:t='pw, 0'
            }
          }

          Button_text {
            id:t='gc_eagles'
            visualStyle:t='noFrame'
            tooltip:t='#mainmenu/gold'
            _on_click:t='onOnlineShopEagles'

            img {
              isFirstLeft:t='yes'
              size:t='@cIco, @cIco'
              background-image:t='#ui/gameuiskin#shop_warpoints_premium.svg'
              background-svg-size:t='@cIco, @cIco'
            }

            btnText {
              id:t='gc_gold'
              min-width:t='0.05@sf'
              pos:t='1@blockInterval, 50%ph-50%h'
              position:t='relative'
              text-align:t='left'
            }
            chapterSeparator {
              position:t='absolute'
              pos:t='pw, 0'
            }
          }
        }
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

          <<@chestNameTextParams>>
        }
        textareaNoTab {
          id:t='time_expired_value'
          position:t='absolute'
          mediumFont:t="yes"
          overlayTextColor:t='gray'
          css-hier-invalidate:t='yes'

          <<@timeExpiredTextParams>>
        }
      }

      tdiv {
        id:t='chest_preview'
        size:t='0.7ph, 0.7ph'
        pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
        position:t='absolute'
      }

      tdiv {
        id:t='prizes_list'
        pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
        position:t='absolute'
        display:t='hide'
      }

      tdiv {
        id:t='chest_out_anim'
        size:t='0.7ph, 0.7ph'
        pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
        position:t='absolute'
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
          id:t='use_amount_controls'
          halign:t='center'
          margin-top:t='6@blockInterval'
          margin-left:t='7@sf/@pf'
          flow:t='horizontal'

          Button_text {
            id:t='use_amount_decrease_btn'
            square:t='yes';
            text:t = '-'
            on_click:t='onUseAmountDecrease'
            inactiveColor:t='yes'
            margin-right:t='1@blockInterval'
          }

          slider {
            id:t='use_amount_slider'
            pos:t='0, 50%ph-50%h'
            position:t='relative'
            margin:t='0.5@sliderThumbWidth + 1@blockInterval, 0'
            min:t='1'
            style:t='width:180@sf/@pf'
            on_change_value:t='onUseAmountSliderChange'

            focus_border {}
            sliderButton {}
          }

          textareaNoTab {
            id:t='use_amount_text'
            valign:t='center'
            margin-right:t='1@blockInterval'
            min-width:t='26@sf/@pf'
          }

          Button_text {
            id:t='use_amount_increase_btn'
            square:t='yes';
            text:t ='+'
            on_click:t='onUseAmountIncrease'
            inactiveColor:t='yes'

          }

          Button_text {
            id:t='use_amount_max_btn'
            text:t = '#profile/maximumExp'
            on_click:t = 'onSetMaxUseAmount'
            inactiveColor:t='yes'
            sliderButtonText:t='yes'
          }
        }

      tdiv {
        size:t='389@sf/@pf, 78@sf/@pf'
        pos:t='0.5pw - 0.5w, 0'
        position:t='relative'
        margin-top:t='20@sf/@pf'

        Button_text {
          id:t='skip_anim'
          display:t='hide'
          halign:t='center'
          valign:t='center'
          text:t = '#msgbox/btn_skip'
          on_click:t='onSkipAnimations'
          btnName:t='B'
        }

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
          display:t='hide'
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
  gamercard_div {}
}

timer {
  id:t='update_timer'
  timer_handler_func:t='onTimer'
  timer_interval_msec:t='1000'
}
