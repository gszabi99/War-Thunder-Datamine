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
          btnText {
            id:t='back_scene_name'
            text:t='#mainmenu/tournaments'
          }
        }
      }

      tdiv {
        id:t='battle_nest'
        left:t='pw-w-1@buttonCloseHeight-1@blockInterval'
        position:t='relative'
        flow:t='horizontal'
        <<^isActive>>
        display:t='hide'
        <</isActive>>
        img {
          size:t='1@fontHeightNormal, 1@fontHeightNormal'
          pos:t='1@blockInterval, 0.5ph-0.5h'
          position:t='relative'
          background-image:t='#ui/gameuiskin#tournament_battles.svg'
          background-svg-size:t='1@fontHeightNormal, 1@fontHeightNormal'
        }
        textareaNoTab {
          id:t='battle_num'
          pos:t='1@blockInterval, 0.5ph-0.5h'
          position:t='relative'
          normalBoldFont:t='yes'
          text:t='<<battlesNum>>'
        }
        img {//!!!FIX Layered icon need
          size:t='1@eSItemDivisionWidth, 1@eSItemDivisionHeight'
          pos:t='1@blockInterval, 0.5ph-0.5h'
          position:t='relative'
          background-image:t='<<divisionImg>>'
          background-svg-size:t='1@eSItemDivisionWidth, 1@eSItemDivisionHeight'
          <<#isFinished>>
          background-saturate:t='0'
          <</isFinished>>
        }
      }
      Button_close { id:t = 'btn_back' }
      navBar {}
    }
    tdiv {// CONTENT
      size:t='fw, ph'
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
          id:t='battle_day'
          pos:t='0.5pw-0.5w, 0.5ph-0.5h'
          position:t='absolute'
          padding:t='1@eSBtnTextPadding, 0'
          text:t='<<battleDay>>'
        }
        textareaNoTab{
          pos:t='0.75pw, 0.5ph-0.5h'
          position:t='absolute'
          text:t='|'
        }
        textareaNoTab {
          id:t='type_txt'
          pos:t='pw-w, 0.5ph-0.5h'
          position:t='absolute'
          padding:t='1@eSBtnTextPadding, 0'
          text:t='<<tournamentType>>'
        }
      }
      tdiv {
        size:t='(648@sf/@pf) \ 1, (108@sf/@pf) \ 1'
        pos:t='0.5pw-0.5w, -1@eSDayBgrHeight'
        position:t='relative'
      // HEADER COLORED BGR
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
      include "%gui/events/eSportScheduler"
      tdiv {
        id:t='queue_progress'
        left:t='0.5pw-0.5w'
        position:t='relative'
        width:t='1@eSEventBtnWidth'
        display:t='hide'
      }
      Button_text {
        id:t='join_btn'
        width:t='1@eSEventBtnWidth'
        left:t='0.5pw-0.5w'
        bottom:t='1@bottomMenuPanelHeight+h+1@eSItemInterval'
        position:t='relative'
        visualStyle:t='tournament_battle'
        text:t = '#events/join_event'
        display:t='<<#isFinished>>hide<</isFinished>><<^isFinished>>show<</isFinished>>'
        _on_click:t = 'onJoinEvent'
        ButtonImg {}
      }
      Button_text {
        id:t='leave_btn'
        width:t='1@eSEventBtnWidth'
        left:t='0.5pw-0.5w'
        bottom:t='1@bottomMenuPanelHeight+h+1@eSItemInterval'
        position:t='relative'
        visualStyle:t='tournament_battle'
        isCancel:t='yes'
        text:t = '#mainmenu/btnCancel'
        display:t='hide'
        _on_click:t = 'onLeaveEvent'
        ButtonImg {}
      }
    }
  }
}

timer
{
  id:t='update_timer'
  timer_handler_func:t='onTimer'
  timer_interval_msec:t='1000'
}
