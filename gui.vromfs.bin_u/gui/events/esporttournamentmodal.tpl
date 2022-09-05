root {
  bgrStyle:t='fullScreenWnd'
  blur {}
  blur_foreground {}

  frame {
    id:t='wnd_eSportTournament'
    width:t='@rw'
    height:t='sh-@bottomMenuPanelHeight'
    pos:t='0.5pw-0.5w, 0.5ph-0.5h-0.5@bottomMenuPanelHeight'
    position:t='absolute'
    class:t='wndNav'
    fullScreenSize:t='yes'

    frame_header {
      Breadcrumb {
        Button_text {
          _on_click:t='goBack'
          visualStyle:t='noBgr'
          img {}
          btnText { id:t='back_scene_name' }
        }
      }

      Button_close { id:t = 'btn_back' }
      navBar {}
    }
    tdiv {// CONTENT
      size:t='fw, 1@eSEventContentHeight'
      position:t='relative'
      flow:t='vertical'
      tdiv {
        size:t='1@eSDayBgrWidth, 1@eSDayBgrHeight'
        top:t='-h'
        left:t='0.5pw-0.5w'
        position:t='relative'
        img {
          size:t='pw, ph'
          left:t='0.5pw-0.5w'
          position:t='absolute'
          background-repeat:t='repeat-x'
          background-image:t='#ui/gameuiskin#header_grey.png'
        }
        textareaNoTab {
          id:t='rank_txt'
          top:t='0.5ph-0.5h'
          position:t='absolute'
          padding:t='1@eSBtnTextPadding, 0'
          text:t='<<rank>>'
        }
        textareaNoTab{
          pos:t='0.25pw, 0.5ph-0.5h'
          position:t='absolute'
          text:t='|'
        }
        textareaNoTab {
          id:t='type_txt'
          pos:t='0.5pw-0.5w, 0.5ph-0.5h'
          position:t='absolute'
          padding:t='1@eSBtnTextPadding, 0'
          text:t='<<tournamentType>>'
        }
        textareaNoTab{
          pos:t='0.75pw, 0.5ph-0.5h'
          position:t='absolute'
          text:t='|'
        }
        textareaNoTab {
          id:t='battle_day'
          pos:t='pw-w, 0.5ph-0.5h'
          position:t='absolute'
          padding:t='1@eSBtnTextPadding, 0'
          text:t='<<battleDay>>'
        }
      }
      tdiv {
        size:t='(648@sf/@pf) \ 1, 1@eSEventHeaderHeight'
        pos:t='0.5pw-0.5w, -1@eSDayBgrHeight'
        position:t='relative'
      // COLORED HEADER BGR
        tdiv {
          size:t='pw, ph'
          left:t='0.5pw-0.5w'
          position:t='absolute'
          img {
            id:t='h_left'
            size:t='24@dp, ph'
            position:t='relative'
            background-saturate:t='<<#isFinished>>0<</isFinished>><<^isFinished>>1<</isFinished>>'
            background-image:t='#ui/gameuiskin#<<armyId>>_header_left.png'
          }
          img {
            id:t='h_center'
            size:t='pw-48@dp, ph'
            position:t='relative'
            background-saturate:t='<<#isFinished>>0<</isFinished>><<^isFinished>>1<</isFinished>>'
            background-repeat:t='repeat-x'
            background-image:t='#ui/gameuiskin#<<armyId>>_header_cenral.png'
          }
          img {
            id:t='h_right'
            size:t='24@dp, ph'
            position:t='relative'
            background-saturate:t='<<#isFinished>>0<</isFinished>><<^isFinished>>1<</isFinished>>'
            background-image:t='#ui/gameuiskin#<<armyId>>_header_right.png'
          }
        }
        textareaNoTab {
          id:t='header_txt'
          pos:t='0.5pw-0.5w, 0.5ph-0.5h'
          position:t='absolute'
          bigBoldFont:t='yes'
          text:t='<<tournamentName>>'
        }
      }
      // COUNTRIES
      tdiv {
        height:t='1@eSItemIcoSize'
        pos:t='0.5pw-0.5w, -0.5h'
        position:t='relative'
        <<#countries>>
        tdiv {
          size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
          pos:t='<<xPos>>*(0.8w)-<<halfLen>>*w, 0'
          position:t='absolute'
          img {
            size:t='1.5@eSItemIcoSize, 1.5@eSItemIcoSize'
            pos:t='0.5pw-0.5w+5@dp, 0.5ph-0.5h'
            position:t='absolute'
            background-image:t='#ui/gameuiskin#flag_shadow.png'
            background-svg-size:t='1.5@eSItemIcoSize, 1.5@eSItemIcoSize'
          }
          img {
            size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
            position:t='absolute'
            background-image:t='<<icon>>'
            background-svg-size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
          }
        }
        <</countries>>
      }
      tdiv {
        height:t='fh'
        left:t='0.5pw-0.5w'
        position:t='relative'
        padding:t='0, 1@eSItemPadding'
        flow:t='horizontal'
        tdiv {// LEFT
          size:t='1@eSEventBtnWidth+4@eSItemPadding, ph'
          position:t='relative'
          padding-right:t='2@eSItemPadding'
          flow:t='vertical'
          tdiv {
            tdiv {
              id:t='my_tournament_img'
              size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
              top:t='0.5ph-0.5h'
              position:t='relative'
              background-image:t='#ui/gameuiskin#tournament_my.svg'
              background-svg-size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
              background-color:t='@sessionSelectedColor'

              <<^isMyTournament>>
              display:t='hide'
              <</isMyTournament>>
            }
            textareaNoTab {
              bigBoldFont:t='yes'
              text:t='#tournaments/about'
            }
          }

          tdiv {
            id:t='item_desc'
            size:t='pw, ph-1@eSItemButtonHeight-3@eSItemPadding'
            position:t='relative'
            flow:t='vertical'
            css-hier-invalidate:t='yes'
            div {
              size:t='pw, ph'
              overflow-y:t='auto'
              flow:t='vertical'
              scrollbarShortcuts:t='yes'
              tdiv {
                width:t='pw'
                padding:t='0, 0, 0, 1@blockInterval'
                flow:t='horizontal'
                textareaNoTab {
                  id:t='event_desc_text'
                  width:t='pw'
                  text:t='<<descTxt>>'
                }
              }

              tdiv {
                width:t='pw'
                position:t='relative'
                flow:t='vertical'

                <<#days>>
                tdiv {
                  width:t='pw'
                  position:t='relative'
                  padding:t='0, 1@blockInterval'
                  flow:t='vertical'
                  collapsed:t='<<collapsed>>'

                  fullSizeCollapseBtn {
                    size:t='pw, ph'
                    total-input-transparent:t='yes'
                    css-hier-invalidate:t='yes'
                    on_click:t='onCollapse'
                    collapse_header:t='yes'
                    activeText{}
                    ButtonImg {}
                    text {
                      position:t='relative'
                      top:t='0.5ph-0.5h'
                      text:t='<<chapterName>>'
                      style:t='color:@sessionSelectedColor;'
                    }

                    tdiv {
                      right:t='0'
                      position:t='relative'
                      flow:t='horizontal'
                      <<#dayCountries>>
                      img {
                        size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
                        margin-right:t='1@blockInterval'
                        position:t='relative'
                        background-image:t='<<icon>>'
                        background-svg-size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
                      }
                      <</dayCountries>>
                    }
                  }

                  <<#items>>
                  tdiv {
                    padding-left:t='1@eSItemPadding'
                    position:t='relative'
                    flow:t='horizontal'
                    <<#isCollapsed>>
                    display:t='hide'
                    <</isCollapsed>>

                    img {
                      size:t='@checkboxSize, @checkboxSize'
                      background-image:t='<<image>>'
                      background-svg-size:t='@checkboxSize, @checkboxSize'
                      shopItemType:t='<<shopItemType>>'
                    }

                    textareaNoTab {
                      pos:t='1@blockInterval, 0.5ph-0.5h'
                      position:t='relative'
                      text:t='<<text>>'
                      smallFont:t='yes'
                    }
                  }
                  <</items>>
                }
                <</days>>
              }
            }
          }
        }
        tdiv {// CENTER
          size:t='1@eSItemWidth, ph'
          flow:t='vertical'
          position:t='relative'
          include "%gui/events/eSportScheduler"

          tdiv {
            id:t='wait_time_block'
            width:t='1@eSItemWidth'
            position:t='relative'
            padding:t='1@eSItemPadding'
            display:t='hide'
            flow:t='vertical'

            textAreaCentered {
              id:t='waitText'
              pos:t="0.5pw-0.5w, 0.5ph-0.5h"
              position:t="relative"
              text-align:t='center'
              class:t='active'
              text:t=''
            }

            animated_wait_icon {
              id:t='queue_wait_icon'
              pos:t="0.5pw-0.5w, 0.5ph-0.5h"
              position:t="relative"
              background-rotation:t = '0'
            }
          }

          tdiv {
            left:t='0.5pw-0.5w'
            bottom:t='2@eSItemPadding-1@buttonMargin'
            position:t='relative'
            Button_text {
              id:t='action_btn'
              width:t='1@eSEventBtnWidth'
              visualStyle:t='tournament_battle'
              inactiveColor:t='no'
              text:t = ''
              display:t='hide'
              _on_click:t = 'onBtnAction'
              btnName:t='X'
              ButtonImg {}
            }
            Button_text {
              id:t='leave_btn'
              width:t='1@eSEventBtnWidth'
              visualStyle:t='tournament_battle'
              isCancel:t='yes'
              text:t = '#mainmenu/btnCancel'
              display:t='hide'
              _on_click:t = 'onLeaveEvent'
              btnName:t='X'
              ButtonImg {}
            }
          }
        }
        tdiv {// RIGHT
          size:t='1@eSEventBtnWidth+4@eSItemPadding, ph'
          position:t='relative'
          flow:t='vertical'
          Button_text {
            id:t='leaderboard_obj'
            width:t='1@eSEventBtnWidth'
            left:t='pw-w'
            position:t='relative'
            visualStyle:t='tournament'
            bigFont:t='yes'
            text:t = '<<lbBtnTxt>>'
            enable:t='no'
            display:t='hide'
            inactiveColor:t='yes'
            on_click:t = 'onLeaderboard'
            btnName:t='L3'
            ButtonImg {}
            img {
              background-image:t='#ui/gameuiskin#tournament_leaderboard.svg'
            }
          }
          tdiv {
            id:t='top_nest'
            width:t='1@eSEventBtnWidth'
            left:t='pw-w'
            position:t='relative'
            padding:t='1@eSItemPadding'
            flow:t='vertical'
          }
          Button_text {
            id:t='rewards_btn'
            width:t='1@eSEventBtnWidth'
            left:t='pw-w'
            bottom:t='2@eSItemPadding'
            position:t='relative'
            visualStyle:t='tournament'
            bigFont:t='yes'
            text:t = '<<rewardsBtnTxt>>'
            <<^hasRewardBtn>>
            enable:t='no'
            display:t='hide'
            <</hasRewardBtn>>
            on_click:t = 'onReward'
            btnName:t='R3'
            ButtonImg {}
          }
        }
      }
    }
  }

  gamercard_div {
    id:t='chapter_gamercard'
    include '%gui/gamercardBottomPanel.blk'
  }
}

timer
{
  id:t='update_timer'
  timer_handler_func:t='onTimer'
  timer_interval_msec:t='1000'
}
