root {
  blur {}
  blur_foreground {}
  type:t="big"

  tdiv {
    width:t='1@gameModeSelectWindowWidth'
    max-width:t='1@rw'
    height:t='1@rh'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='relative'
    flow:t='vertical'

    tdiv {
      width:t='pw'
      max-height:t='ph'
      top:t='50%ph-50%h'
      position:t='relative'
      flow:t='vertical'

      textareaNoTab {
        text:t='#mainmenu/gameModeChoice'
        overlayTextColor:t='active'
        height:t='0.04@scrn_tgt'
      }

      gameModeSelect {
        id:t='game_mode_select'
        width:t='pw'
        max-height:t='ph - 1@frameFooterHeight - 0.04@scrn_tgt'
        pos:t='50%pw-50%w, 0'
        position:t='relative'
        flow:t='vertical'
        overflow-y:t='auto'

        generalGameModes {
          id:t='general_game_modes';
          behavior:t='posNavigator';
          navigatorShortcuts:t='yes';
          clearOnFocusLost:t='no'
          moveX:t='linear';
          moveY:t='closest';
          on_activate:t='onGameModeActivate';
          on_select:t='onGameModeGamepadSelect'
        }
      }

      tdiv {
        size:t='1@gameModeSelectWindowWidth - 1@scrollBarSize - 2@gameModeSelectWindowBlockMargin, 1@frameFooterHeight'
        position:t='relative'
        left:t='1@gameModeSelectWindowBlockMargin'
        navBar {
          class:t='relative'
          isTransparent:t='yes'

          navLeft {
            Button_text {
              id:t='cluster_select_button'
              on_click:t='onOpenClusterSelect'
              btnName:t='X'
              refuseOpenHoverMenu:t='no'
              class:t='image'
              standardTextBtnWidth:t='yes'
              isColoredImg:t='yes'

              img {
                id:t='cluster_select_button_icon'
                margin-right:t='3@sf/@pf'
                background-image:t='#ui/gameuiskin#urgent_warning.svg'
                wink:t='no'
                display:t='hide'
              }
              textarea {
                id:t='cluster_select_button_text'
                height:t='ph'
                width:t='fw'
                text:t='#options/cluster'
                pare-text:t='yes'
                input-transparent:t='yes'
                class:t='buttonText'
                leftAligned:t='no'
              }
              ButtonImg {}
            }

            Button_text {
              id:t='event_description_console_button'
              text:t='#mainmenu/titleEventDescription'
              btnName:t='L3'
              on_click:t='onGamepadEventDescription'
              display:t='hide'
              enable:t='no'

              ButtonImg {}
            }

            Button_text {
              id:t='map_preferences_console_button'
              position:t='relative'
              pos:t='1@blockInterval, 0.5@blockInterval'
              on_click:t='onMapPreferences'
              display:t='hide'
              enable:t='no'
              btnName:t='Y'
              ButtonImg {}
            }

            Button_text {
              id:t='night_battles_console_button'
              position:t='relative'
              pos:t='1@blockInterval, 0.5@blockInterval'
              class:t='image'
              btnName:t='RB'
              on_click:t='onNightBattles'
              display:t='hide'
              enable:t='no'
              ButtonImg {}
              img { background-image:t='#ui/gameuiskin#night_battles.svg' }
            }
          }

          navRight {
            Button_text {
              id:t='wiki_link'
              isLink:t='yes'
              isFeatured:t='yes'
              link:t='#url/wiki_matchmaker'
              on_click:t='onMsgLink'
              display:t='hide'
              enable:t='no'

              btnText{
                text:t='#profile/wiki_matchmaking'
                underline{}
              }
              btnName:t='R3'
              ButtonImg {}
            }

            Button_text {
              id:t='back_button'
              text:t = '#mainmenu/btnBack'
              _on_click:t = 'goBack'
              btnName:t='B'
              ButtonImg {}
            }
          }
        }
      }
    }
  }

  timer {
    id:t='game_modes_timer'
    timer_handler_func:t='onTimerUpdate'
    timer_interval_msec:t='1000'
  }
}