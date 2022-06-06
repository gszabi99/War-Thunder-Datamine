<<#items>>
eSItemDiv {
  id:t='<<eventId>>'
  on_click:t='onEvent'
  <<^isVisible>>
  display:t='hide'
  <</isVisible>>
  // CONTENT TOP
  tdiv {
    size:t='pw, 1@eSItemBgrHeight'
    top:t='1@eSItemBgrTopPos'
    position:t='absolute'
    padding:t='1@eSItemPadding, 0'
    flow:t='vertical'

    img {
      id:t='item_bgr'
      size:t='pw, ph'
      position:t='absolute'
      background-image:t='<<itemBgr>>'
      background-svg-size:t='pw, ph'
      background-saturate:t='<<#isFinished>>0<</isFinished>><<^isFinished>>1<</isFinished>>'
    }

    tdiv {
      max-width:t='pw'
      pos:t='0.5pw-0.5w, 4@eSItemInterval'
      position:t='relative'
      autoScrollText:t='yes'
      overflow:t='hidden'
      css-hier-invalidate:t='yes'

      textarea {
        position:t='relative'
        auto-scroll:t='medium'
        smallFont:t='yes'
        text-align:t='center'
        text:t='<<battleDate>>'
      }
    }

    textareaNoTab {
      id:t='battle_day'
      left:t='0.5pw-0.5w'
      position:t='relative'
      text:t='<<battleDay>>'
    }

    <<#isActive>>
    tdiv {
      id:t='battle_nest'
      left:t='0.5pw-0.5w'
      position:t='relative'
      flow:t='horizontal'
      img {
        size:t='1@fontHeightNormal, 1@fontHeightNormal'
        top:t='0.5ph-0.5h'
        position:t='relative'
        background-image:t='#ui/gameuiskin#tournament_battles.svg'
        background-svg-size:t='1@fontHeightNormal, 1@fontHeightNormal'
      }

      textareaNoTab {
        id:t='battle_num'
        left:t='1@blockInterval'
        position:t='relative'
        normalBoldFont:t='yes'
        text:t='<<battlesNum>>'
      }
    }
    <</isActive>>
    <<#isFinished>>
    img {
      id:t='leaderboard_img'
      size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
      pos:t='0.5pw-0.5w, 4@eSItemInterval'
      position:t='relative'
      background-image:t='#ui/gameuiskin#tournament_leaderboard.svg'
      background-svg-size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
    }

    Button_text {
      id:t='leaderboard_btn'
      width:t='0.8pw'
      pos:t='0.5pw-0.5w, 1@eSItemInterval'
      position:t='relative'
      visualStyle:t='tournament'
      bigFont:t='yes'
      text:t = '#tournaments/leaderboard'
      on_click:t = 'onLeaderboard'
      btnName:t='Y'
      ButtonImg {}
    }
    <</isFinished>>
    <<#isActive>>
    <<#sessionTime>>
    tdiv {
      id:t='session_nest'
      width:t='pw'
      position:t='relative'
      padding-bottom:t='2@eSItemInterval'
      flow:t='horizontal'
      smallFont:t='yes'

      textareaNoTab {
        position:t='relative'
        text:t='#tournaments/session'
      }
      <<#sessions>>
      textareaNoTab {
        id:t='<<sesId>>'
        position:t='relative'
        text:t='<<sesNum>>'
        visualStyle:t='<<#isSelected>>sessionSelected<</isSelected>><<^isSelected>><</isSelected>>'
      }
      <</sessions>>

      tdiv{
        height:t='1@fontHeightSmall'
        max-width:t='0.7pw'
        right:t='0'
        position:t='relative'
        flow:t='horisontal'

        img {
          id:t='session_ico'
          size:t='1@fontHeightSmall, 1@fontHeightSmall'
          top:t='0.5ph-0.5h'
          position:t='relative'
          background-image:t='#ui/gameuiskin#<<^isSesActive>>clock_tour<</isSesActive>><<#isSesActive>>play_tour<</isSesActive>>.svg'
          background-svg-size:t='1@fontHeightSmall, 1@fontHeightSmall'
        }

        textareaNoTab {
          id:t='session_timer'
          pos:t='1@blockInterval, 0.5ph-0.5h'
          position:t='relative'
          text-align:t='right'
          text:t='<<sessionTime>>'
        }
      }
    }
    <</sessionTime>>
    <<#trainingTime>>
    tdiv {
      id:t='training_nest'
      width:t='pw'
      position:t='relative'
      flow:t='horizontal'
      smallFont:t='yes'

      textareaNoTab {
        position:t='relative'
        text:t='#tournaments/training'
      }

      textareaNoTab {
        id:t='training_time'
        right:t='0'
        position:t='relative'
        text-align:t='right'
        text:t='<<trainingTime>>'
      }
    }
    <</trainingTime>>
    <<#startTime>>
    tdiv {
      id:t='start_nest'
      width:t='pw'
      position:t='relative'
      flow:t='horizontal'
      smallFont:t='yes'

      textareaNoTab {
        position:t='relative'
        text:t='#tournaments/start'
      }

      textareaNoTab {
        id:t='start_time'
        right:t='0'
        position:t='relative'
        text-align:t='right'
        text:t='<<startTime>>'
      }
    }
    <</startTime>>
    <</isActive>>
  }
  itemUnderline {
    top:t='1@eSItemHeight+1@eSItemMargin'
    position:t='absolute'
    height:t='1@eSItemMargin'
  }
  // HEADER
  tdiw {
    size:t='pw, 1@eSItemPNGHeaderHeight'
    position:t='absolute'
    smallFont:t='yes'
    img {
      size:t='pw, ph'
      position:t='absolute'
      background-image:t='<<headerImg>>'
      background-svg-size:t='pw, ph'
    }
    //!!!FIX 1.75@eSItemInterval & eSItemPNGHeaderHeight after PNG will be cutten
    textareaNoTab {
      pos:t='1@eSItemPadding, 1.75@eSItemInterval+0.5@eSItemHeaderHeight-0.5h'
      position:t='absolute'
      text:t='<<rank>>'
    }
    textareaNoTab {
      pos:t='0.5pw-0.5w, 1.75@eSItemInterval+0.5@eSItemHeaderHeight-0.5h'
      position:t='absolute'
      text:t='<<tournamentType>>'
    }
    img {//!!!FIX Layered icon need
      size:t='1@eSItemDivisionWidth, 1@eSItemDivisionHeight'
      top:t='1@eSItemInterval'
      right:t='1@eSItemPadding'
      position:t='absolute'
      background-image:t='<<divisionImg>>'
      background-svg-size:t='1@eSItemDivisionWidth, 1@eSItemDivisionHeight'
      <<#isFinished>>
      background-saturate:t='0'
      <</isFinished>>
    }
  }
  // // CONTENT BOTTOM
  tdiv {
    width:t='0.7pw'
    pos:t='1@eSItemPadding, 1@tournamentNameTextPos-h'
    flow:t='h-flow'
    position:t='absolute'
    padding-bottom:t='1@eSItemPadding'
    <<#countries>>
    img {
      size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
      position:t='relative'
      margin:t='1@eSItemInterval'
      margin-left:t='0'
      background-image:t='<<icon>>'
      background-svg-size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
    }
    <</countries>>
  }

  textareaNoTab {
    width:t='0.8pw'
    pos:t='1@eSItemPadding, 1@tournamentNameTextPos'
    position:t='absolute'
    padding-bottom:t='1@eSItemPadding'
    mediumFont:t='yes'
    text:t='<<tournamentName>>'
  }

  textareaNoTab {
    left:t='1@eSItemPadding'
    bottom:t='1@eSItemPadding'
    position:t='absolute'
    smallFont:t='yes'
    text:t='<<vehicleType>>'
  }
  <<#isMyTournament>>
  img {
    size:t='1@eSItemCornerSize, 1@eSItemCornerSize'
    pos:t='pw-w, ph-h'
    position:t='absolute'
    background-image:t='#ui/gameuiskin#tournament_my_corner.svg'
    background-svg-size:t='1@eSItemCornerSize, 1@eSItemCornerSize'
  }

  img {
    size:t='0.7@eSItemIcoSize, 1@eSItemIcoSize'
    right:t='1@eSItemInterval'
    bottom:t='1@eSItemInterval'
    position:t='absolute'
    background-image:t='#ui/gameuiskin#tournament_my.svg'
    background-svg-size:t='0.7@eSItemIcoSize, 1@eSItemIcoSize'
  }
  <</isMyTournament>>
}
<</items>>