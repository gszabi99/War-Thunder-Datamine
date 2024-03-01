groupBottom {
  id:t='group_<<groupName>>_bottom_info'
  width:t='pw'
  padding-bottom:t='@blockInterval'
  flow:t='vertical'
  display:t='hide'

  <<#playerButton>>
  buttonPlayer {
    width:t='pw'
    tooltip:t='<<tooltip>>'
    on_click:t='<<callback>>'
    isButton:t='yes'
    btnText {
      text:t='<<name>>'
    }
    img {
      background-image:t='<<icon>>'
    }
  }
  <</playerButton>>

  textareaNoTab {
    id:t='group_<<groupName>>_total_text'
    width:t='pw'
    padding:t='0, @blockInterval, @blockInterval, 0'
    text:t='<<totalContacts>>'
    smallFont:t='yes'
    color:t='@commonTextColor'
    color-factor:t='180'
    talign:t='right'
  }
}