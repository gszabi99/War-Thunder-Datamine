activeText {
  text:t='<<teamName>>'
}

tdiv {
  width:t='fw'
  flow:t='vertical'

  <<#rows>>
  sessionVehicleRow {
    <<#icon>>
    tdiv {
      size:t='1@cIco, 1@cIco'
      margin-right:t='1@blockInterval'
      fontIcon20 { fonticon { text:t='<<icon>>' } }
    }
    <</icon>>
    textareaNoTab {
      text:t='<<text>>'
    }
  }
  <</rows>>
}
