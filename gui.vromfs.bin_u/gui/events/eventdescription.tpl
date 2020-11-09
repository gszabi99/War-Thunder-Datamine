tdiv {
  id:t='event_desc'
  pos:t='0,0'
  position:t='relative'
  size:t='fw, ph'
  flow:t='vertical'
  css-hier-invalidate:t='yes'

  tdiv {
    position:t='relative'
    pos:t='50%pw-50%w, 0'

    img {
      id:t='difficulty_img'
      size:t='1@unlockStageIconSize,1@unlockStageIconSize'
      pos:t='0,50%ph-50%h'
      position:t='relative'
      tooltip:t=''
      background-image:t=''
      tooltip:t=''
    }

    activeText {
      id:t='event_name'
      position:t='relative'
      pos:t='0, 0'
      text:t=''
      caption:t='yes'
    }
  }
  div {
    size:t='pw, fh'
    overflow-y:t='auto'
    flow:t='vertical'
    scrollbarShortcuts:t='yes'

    tdiv { //info texts
      width:t='pw'

      tdiv { //left info
        width:t='fw'
        flow:t='vertical'

        tdiv {
          activeText{
            text:t='#multiplayer/difficulty'
            style:t='color:@commonTextColor'
          }

          activeText {
            id:t='event_difficulty'
            text:t=''
          }
        }

        tdiv {
          id:t='event_players_range'

          activeText {
            id:t='event_players_range_label'
            text:t=''
            style:t='color:@commonTextColor'
          }

          activeText {
            id:t='event_players_range_text'
            text:t=''
          }
        }

        tdiv {
          id:t='clan_event'

          activeText {
            text:t='#events/clan_only'
          }

          cardImg {
            margin-left:t='5*@sf/@pf_outdated'
            type:t='tiny'
            background-image:t='#ui/gameuiskin#btn_help.svg'
            tooltip:t='#events/clan_event_help'
          }
        }

        activeText {
          id:t='allow_switch_clan'
          text:t=''
          style:t='color:@commonTextColor'
        }

        textareaNoTab {
          id:t='event_desc_text'
          width:t='pw'
          text:t=''
        }
      }

      tdiv { //right info
        flow:t='vertical'

        textareaNoTab {
          id:t='event_time'
          text:t=''
          pos:t='pw-w, 0'
          position:t='relative'
          behavior:t = 'Timer'
        }

        textareaNoTab {
          id:t='event_time_limit'
          text:t=''
          pos:t='pw-w, 0'
          position:t='relative'
        }

        textareaNoTab {
          id:t='cost_desc'
          pos:t='pw-w, 0'; position:t='relative'
          padding-left:t='@unlockIconSize'
          text-align:t='right'
          text:t=''

          img {
            id:t='bought_ticket_img'
            size:t='@unlockIconSize, @unlockIconSize'
            pos:t='0, -0.2h'; position:t='absolute'
            background-image:t='#ui/gameuiskin#favorite'
            display:t='hide'
          }
        }
        Button_text {
          id:t='rewards_list_btn'
          pos:t='pw-w, 0'
          position:t='relative'
          text:t='#mainmenu/rewardsList'
          _on_click:t='onRewardsList'
          btnName:t='start'
          display:t='hide'
          enable:t='no'
          ButtonImg{}
        }
        Button_text {
          id:t='players_list_btn'
          pos:t='pw-w, 0'
          position:t='relative'
          text:t='#multiplayer/btnPlayers'
          _on_click:t='onPlayersList'
          btnName:t='start'
          display:t='hide'
          enable:t='no'
          ButtonImg{}
        }
      }
    }
    tdiv {
      width:t='pw'
      height:t='fh'
      min-height:t='1@eventTacticalMapSize + 3@leaderboardTrHeight + 0.02@sf + 1@buttonHeight'
      padding-top:t='0.01@scrn_tgt';

      frameBlock {
        id:t='tactical-map'
        position:t='relative'
        width:t='@eventTacticalMapSize'
        height:t='ph'
        padding:t='3*@sf/@pf_outdated'
        margin-right:t='0.01@scrn_tgt'
        flow:t='vertical'

        img{
          id:t='multiple_mission'
          size:t='95%pw,95%pw'
          max-height:t='w'
          max-width:t='h'
          pos:t='50%pw-50%w, 2*@sf/@pf_outdated'
          position:t='relative'
          display:t='hide'
        }
        tacticalMap {
          id:t='tactical_map_single'
          size:t='pw,fh'
          max-width:t='h'
          max-height:t='w'
          pos:t='50%pw-50%w, 2*@sf/@pf_outdated'
          position:t='relative'
          display:t='hide'
        }
        tdiv {
          id:t='lb_wrap'
          width:t='pw+4*@sf/@pf_outdated'
          height:t='3@leaderboardTrHeight + 0.02@sf + 1@buttonHeight'
          pos:t='-2*@sf/@pf_outdated, 0.005@sf'
          position:t='relative'
          padding:t='2'
          padding-top:t='0.005@sf'
          flow:t='vertical'

          animated_wait_icon {
            id:t = 'msgWaitAnimation'
            position:t='absolute'
            height:t='ph'
            pos:t='50%pw-50%w,50%ph-50%h'
            background-rotation:t = '0'
          }
          table {
            id:t = 'lb_table'
            width:t='pw'
            class:t='lbTable'
            text-valign:t='center'
            text-halign:t='center'
            _on_dbl_click:t='onOpenEventLeaderboards'
          }

          Button_text {
            id:t='leaderboards_btn'
            _on_click:t='onOpenEventLeaderboards'
            text:t='#mainmenu/titleLeaderboards'
            position:t='relative'
            pos:t='0.5*pw - 0.5*w, 0.005@sf'
            display:t='hide'
            btnName:t='Y'

            ButtonImg{}
          }
        }
      }

      //teams and chat block
      frameBlock {
        size:t='fw, ph'
        flow:t='vertical'

        chapterSeparator {
          id:t='teams_separator'
          position:t='absolute'
          pos:t='pw/2-w/2, ph/2 - h/2'
        }

        //teams info
        tdiv {
          size:t='pw, fh'
          padding:t='3*@sf/@pf_outdated'
          overflow-y:t='auto'
          scrollbarShortcuts:t='yes'

          tdiv {
            id:t='teamA'
            width:t='0.5fw'
            flow:t='vertical'
            padding:t='1@blockInterval'

            activeText {
              id:t='team_title'
              text:t='#events/teamA'
            }

            tdiv {
              id:t='countries'
            }

            textareaNoTab {
              id:t='players_count'
              width:t='pw'
              hideEmptyText:t='yes'
              text:t=''
            }

            tdiv {
              id:t='allowed_unit_types'
              flow:t='vertical'
              margin-bottom:t='0.01@sf'

              activeText {
                id:t='allowed_unit_types_text'
                text:t='#events/all_units_allowed'
              }
            }
            tdiv {
              id:t='required_crafts'
              flow:t='vertical'

              activeText {
                text:t='#events/required_crafts'
              }
            }
            tdiv {
              id:t='allowed_crafts'
              flow:t='vertical'

              activeText {
                text:t='#events/allowed_crafts';
              }
            }

            tdiv {
              id:t='forbidden_crafts'
              flow:t='vertical'

              activeText {
                text:t='#events/forbidden_crafts'
              }
            }
          }

          tdiv { width:t='@chapterSeparatorSize' }

          tdiv {
            id:t='teamB'
            pos:t='1@blockInterval'
            width:t='0.5fw'
            flow:t='vertical'
            padding:t='1@blockInterval'

            activeText {
              id:t='team_title'
              text:t='#events/teamB'
            }

            tdiv {
              id:t='countries'
            }

            textareaNoTab {
              id:t='players_count'
              width:t='pw'
              hideEmptyText:t='yes'
              font-bold:t='@fontSmall'
              text:t=''
            }

            tdiv {
              id:t='allowed_unit_types'
              flow:t='vertical'
              margin-bottom:t='0.01@sf'

              activeText {
                id:t='allowed_unit_types_text'
                text:t='#events/all_units_allowed'
              }
            }

            tdiv {
              id:t='required_crafts'
              flow:t='vertical'

              activeText {
                text:t='#events/required_crafts'
              }
            }

            tdiv {
              id:t='allowed_crafts'
              flow:t='vertical'

              activeText {
                text:t='#events/allowed_crafts'
              }
            }

            tdiv {
              id:t='forbidden_crafts'
              flow:t='vertical'

              activeText {
                text:t='#events/forbidden_crafts'
              }
            }
          }
        }
      }
    }
  }
}
