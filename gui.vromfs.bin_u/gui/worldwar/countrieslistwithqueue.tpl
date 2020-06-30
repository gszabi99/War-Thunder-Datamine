<<#countries>>
id:t='side_<<side>>'
countryId:t='<<countryId>>'
width:t='0.35pw'
<<^isLeftAligned>>right<</isLeftAligned>><<#isLeftAligned>>left<</isLeftAligned>>:t='0.1pw'
position:t='relative'
padding:t='1@blockInterval, 0'
flow:t='vertical'
css-hier-invalidate:t='yes'
total-input-transparent:t='yes'

focus_border {}

textarea {
  pos:t='0.5pw-0.5w, 0'
  position:t='relative'
  text:t='<<countryNameText>>'
}

img {
  pos:t='0.5pw-0.5w, 0'
  position:t='relative'
  size:t='pw, pw'
  background-image:t='<<countryIcon>>'
  background-svg-size:t='pw, pw'
}

Button_text {
  id:t='btn_join_battles'
  countryId:t='<<countryId>>'
  pos:t='0.5pw-0.5w, 0'
  position:t='relative'
  class:t='battle'
  text:t='#worldwar/btnJoinBattle'
  navButtonFont:t='yes'
  hasConsoleImage:t='yes'
  on_click:t='onBattlesBtnClick'

  pattern{}
  buttonWink { _transp-timer:t='0' }
  buttonGlance {}
  ButtonImg {
    btnName:t='X'
    showOnSelect:t='yes'
  }
  btnText {
    text:t='#worldwar/btnJoinBattle'
  }
}

Button_text {
  id:t='btn_join_queue'
  countryId:t='<<countryId>>'
  pos:t='0.5pw-0.5w, 1@blockInterval'
  position:t='relative'
  class:t='battle'
  text:t='#worldwar/btnCreateOperation'
  navButtonFont:t='yes'
  hasConsoleImage:t='yes'
  on_click:t='onJoinQueue'

  pattern{}
  buttonWink { _transp-timer:t='0' }
  buttonGlance {}
  ButtonImg {
    btnName:t='Y'
    showOnSelect:t='yes'
  }
  btnText {
    text:t='#worldwar/btnCreateOperation'
  }
}

Button_text {
  id:t='btn_leave_queue'
  pos:t='0.5pw-0.5w, 1@blockInterval'
  position:t='relative'
  class:t='battle'
  text:t='#worldwar/btnLeaveQueue'
  navButtonFont:t='yes'
  isCancel:t='yes'
  hasConsoleImage:t='yes'
  display:t='hide'
  enable:t='no'
  on_click:t='onLeaveQueue'

  pattern{}
  buttonWink { _transp-timer:t='0' }
  buttonGlance {}
  ButtonImg {
    btnName:t='Y'
    showOnSelect:t='yes'
  }
  btnText {
    id:t='btn_leave_queue_text'
    text:t='#worldwar/btnLeaveQueue'
  }
}

Button_text {
  id:t='btn_join_clan_operation'
  countryId:t='<<countryId>>'
  width:t='1@bigButtonWidth'
  pos:t='0.5pw-0.5w, 1@blockInterval'
  position:t='relative'
  class:t='battle'
  text:t='#events/join_event'
  navButtonFont:t='yes'
  hasConsoleImage:t='yes'
  display:t='hide'
  enable:t='no'
  on_click:t='onJoinClanOperation'
  pattern{}
  buttonWink { _transp-timer:t='0' }
  buttonGlance {}
  ButtonImg {
    btnName:t='Y'
    showOnSelect:t='yes'
  }
  btnContent {
    cardImg {
      id:t='is_clan_participate_img'
      margin-right:t='@blockInterval'
      background-image:t='#ui/gameuiskin#lb_victories_battles.svg'
      display:t='hide'
    }
    btnText {
      id:t='btn_join_operation_text'
      text:t='#events/join_event'
    }
  }
}
<</countries>>
