<<#countries>>
id:t='side_<<side>>'
countryId:t='<<countryId>>'
width:t='0.35pw'
<<^isLeftAligned>>right<</isLeftAligned>><<#isLeftAligned>>left<</isLeftAligned>>:t='0.1pw'
position:t='relative'
flow:t='vertical'
css-hier-invalidate:t='yes'
total-input-transparent:t='yes'

conflictCountry {
  size:t='pw, 0.84pw'  /*0.16pw it is alfa canal on bottom of flag icon*/
  flow:t='vertical'
  css-hier-invalidate:t='yes'

  textareaNoTab {
    pos:t='0.5pw-0.5w, 1@blockInterval'
    position:t='relative'
    text:t='<<countryNameText>>'
  }

  img {
    pos:t='0.5pw-0.5w, -0.14pw'
    position:t='relative'
    size:t='pw, pw'
    background-image:t='<<countryIcon>>'
    background-svg-size:t='pw, pw'
  }

  focus_border {}
}

Button_text {
  id:t='btn_find_operation'
  countryId:t='<<countryId>>'
  pos:t='0.5pw-0.5w, 2@blockInterval'
  position:t='relative'
  class:t='battle'
  text:t='#worldwar/find_operation'
  navButtonFont:t='yes'
  hasConsoleImage:t='yes'
  on_click:t='onFindOperationBtn'

  pattern{}
  buttonWink { _transp-timer:t='0' }
  buttonGlance {}
  ButtonImg {
    btnName:t='X'
    showOnSelect:t='yes'
  }
  btnText {
    text:t='#worldwar/find_operation'
  }
}

Button_text {
  id:t='btn_back_operation'
  countryId:t='<<countryId>>'
  pos:t='0.5pw-0.5w, 2@blockInterval'
  position:t='relative'
  class:t='battle'
  text:t='#worldwar/backOperation'
  navButtonFont:t='yes'
  hasConsoleImage:t='yes'
  display:t='hide'
  enable:t='no'
  on_click:t='onBackOperation'
  pattern{}
  buttonWink { _transp-timer:t='0' }
  buttonGlance {}
  ButtonImg {
    btnName:t='LT'
    showOnSelect:t='yes'
  }
  btnText {
    id:t='btn_back_operation_text'
    text:t='#worldwar/backOperation'
  }
}

Button_text {
  id:t='btn_join_queue'
  countryId:t='<<countryId>>'
  pos:t='0.5pw-0.5w, 2@blockInterval'
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
  pos:t='0.5pw-0.5w, 2@blockInterval'
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
  pos:t='0.5pw-0.5w, 2@blockInterval'
  position:t='relative'
  class:t='battle'
  text:t='#worldwar/joinOperation'
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
      text:t='#worldwar/joinOperation'
    }
  }
}

<</countries>>
