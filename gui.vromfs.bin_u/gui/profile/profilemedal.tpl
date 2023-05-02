titleTextArea {
  text-align:t='center'
  text:t='<<title>>'
}

bigMedalPlace {
  double:t='yes'
  bigMedalImg {
    background-image:t='<<image>>'
    background-repeat:t='aspect-ratio'
  }
}

tdiv {
  margin-top:t='2@blockInterval'
  padding-left:t='10@blockInterval'
  width:t='pw'
  flow:t='vertical'

  <<#hasProgress>>
  challengeDescriptionProgress {
    value:t='<<unlockProgress>>'
    thin:t='yes'
  }
  <</hasProgress>>

  textareaNoTab {
    text:t='<<mainCond>>'
    overflow:t='hidden'
    width:t='pw'
    smallFont:t='yes'
    margin-top:t='@blockInterval'
  }

  textareaNoTab {
    text:t='<<multDesc>>'
    overflow:t='hidden'
    width:t='pw'
    smallFont:t='yes'
  }

  textareaNoTab {
    text:t='<<conds>>'
    overflow:t='hidden'
    width:t='pw'
    smallFont:t='yes'
    margin-top:t='@blockInterval'
  }

  <<#rewardText>>
  textareaNoTab {
    smallFont:t='yes'
    margin-top:t='7@dp'
    text:t='<<?challenge/reward>> <<rewardText>>'
  }
  <</rewardText>>
}