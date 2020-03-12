ww_map_item {
  class:t='header'
  isReflected:t='yes'

  textareaNoTab{
    id:t='header_text'
    position:t='relative'
    top:t='0.5(ph-h)'
    padding-left:t='1@framePadding'
    text:t='<<titleText>>'
    input-transparent:t='yes'
    overlayTextColor:t='silver'
    caption:t='yes'
  }
}

table {
  width:t='pw'
  margin-left:t='1@blockInterval'
  class:t='lbTable'
  <<#rows>>
    <<@row>>
  <</rows>>
}

tdiv {
  width:t='pw'
  padding-bottom:t='1@framePadding'
  css-hier-invalidate:t='yes'

  Button_text {
    id:t='btn_open_leaderboard'
    position:t='relative'
    left:t='0.5(pw-w)'
    text:t='#mainmenu/titleLeaderboards'
    lb_mode:t='<<lbMode>>'
    <<#isDayLb>>
      is_day_lb:t='<<isDayLb>>'
    <</isDayLb>>
    on_click:t='onOpenLeaderboard'

    hasConsoleImage:t='yes'
    ButtonImg {
      showOnSelect:t='yes'
      btnName:t='RB'
    }
  }
}
