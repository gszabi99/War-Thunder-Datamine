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

      activeText {
        position:t='relative'
        auto-scroll:t='medium'
        smallFont:t='yes'
        text-align:t='center'
        text:t='<<battleDate>>'
      }
    }

    activeText {
      id:t='battle_day'
      left:t='0.5pw-0.5w'
      position:t='relative'
      text:t='<<battleDay>>'
    }

    tdiv {
      id:t='battle_nest'
      left:t='0.5pw-0.5w'
      position:t='relative'
      flow:t='horizontal'
      <<^isTourWndAvailable>>
      display:t='hide'
      <</isTourWndAvailable>>
      img {
        size:t='1@fontHeightNormal, 1@fontHeightNormal'
        top:t='0.5ph-0.5h'
        position:t='relative'
        background-image:t='#ui/gameuiskin#tournament_battles.svg'
        background-svg-size:t='1@fontHeightNormal, 1@fontHeightNormal'
      }

      activeText {
        id:t='battle_num'
        left:t='1@blockInterval'
        position:t='relative'
        normalBoldFont:t='yes'
        text:t='<<battlesNum>>'
      }
    }
    include "%gui/events/eSportSession"

    tdid {
      id:t='leaderboard_obj'
      width:t='pw'
      flow:t='vertical'
      <<^isFinished>>
      display:t='hide'
      <</isFinished>>
      img {
        size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
        pos:t='0.5pw-0.5w, 4@eSItemInterval'
        position:t='relative'
        background-image:t='#ui/gameuiskin#tournament_leaderboard.svg'
        background-svg-size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
      }

      Button_text {
        width:t='0.8pw'
        pos:t='0.5pw-0.5w, 1@eSItemInterval'
        position:t='relative'
        visualStyle:t='tournament'
        bigFont:t='yes'
        text:t= '<<lbBtnTxt>>'
        eventId:t='<<eventId>>'
        on_click:t = 'onLeaderboard'
        btnName:t='Y'
        ButtonImg {}
      }

    }
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
    activeText {
      pos:t='1@eSItemPadding, 0.5@eSItemBgrTopPos-0.5@eSItemMargin'
      position:t='absolute'
      text:t='<<rank>>'
    }
    activeText {
      pos:t='0.5pw-0.5w, 0.5@eSItemBgrTopPos-0.5@eSItemMargin'
      position:t='absolute'
      text:t='<<tournamentType>>'
    }

    tdiv {
      id:t='rating_nest'
      height:t='1@eSRatingIco'
      right:t='1@eSItemPadding'
      position:t='absolute'
      flow:t='horizontal'
      display:t='hide'
      img {
        size:t='ph, ph'
        top:t='3@dp'
        position:t='relative'
        background-image:t="#ui/gameuiskin#lb_elo_rating.svg"
        background-svg-size:t='ph, ph'
      }

      activeText {
        id:t='rating_txt'
        top:t='0.5@eSItemBgrTopPos-0.5@eSItemMargin'
        position:t='relative'
        smallFont:t='yes'
        text:t=''
      }
    }
  }
  // COUNTRIES
  tdiv {
    width:t='0.7pw'
    pos:t='1@eSItemPadding, 1@tournamentNameTextPos-h'
    flow:t='h-flow'
    position:t='absolute'
    padding-bottom:t='1@eSItemPadding'
    <<#countries>>
    tdiv {
      size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
      position:t='relative'
      margin:t='1@eSItemInterval'
      margin-left:t='0'
      img {
        size:t='2@eSItemIcoSize, 2@eSItemIcoSize'
        pos:t='0.5pw-0.5w+5@dp, 0.5ph-0.5h'
        position:t='absolute'
        background-image:t='#ui/gameuiskin#flag_shadow.png'
        background-svg-size:t='2@eSItemIcoSize, 2@eSItemIcoSize'
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

  activeText {
    width:t='0.8pw'
    pos:t='1@eSItemPadding, 1@tournamentNameTextPos'
    position:t='absolute'
    padding-bottom:t='1@eSItemPadding'
    mediumFont:t='yes'
    text:t='<<tournamentName>>'
  }

  activeText {
    left:t='1@eSItemPadding'
    bottom:t='1@eSItemPadding'
    position:t='absolute'
    smallFont:t='yes'
    text:t='<<vehicleType>>'
  }

  tdiv {
    id:t='my_tournament_img'
    size:t='1@eSItemCornerSize, 1@eSItemCornerSize'
    pos:t='pw-w, ph-h'
    position:t='absolute'
    <<^isMyTournament>>
    display:t='hide'
    <</isMyTournament>>
    img {
      size:t='pw, ph'
      position:t='absolute'
      background-image:t='#ui/gameuiskin#tournament_my_corner.svg'
      background-svg-size:t='pw, ph'
    }

    img {
      size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
      right:t='0'
      bottom:t='1@eSItemInterval'
      position:t='absolute'
      background-image:t='#ui/gameuiskin#tournament_my.svg'
      background-svg-size:t='1@eSItemIcoSize, 1@eSItemIcoSize'
    }
  }
}
<</items>>