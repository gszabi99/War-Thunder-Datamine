profileContentBigIcon {
  bigMedalPlace {
    pos:t='(pw-w)/2, (ph-h)/2'
    parentSize:t='yes'
    bigMedalImg {
      background-image:t='<<image>>'
      background-repeat:t='aspect-ratio'
    }
  }
}

tdiv {
  width:t='fw'
  flow:t='vertical'

  profilePageTitle {
    position:t='relative'
    text-align:t='center'
    text:t='<<title>>'
    padding-bottom:t='10@sf/@pf'
  }

  <<#hasProgress>>
  challengeDescriptionProgress {
    isProfileUnlockProgress:t='yes'
    value:t='<<unlockProgress>>'
    margin-bottom:t='16@sf/@pf'
  }
  <</hasProgress>>

  profilePageText {
    text:t='<<mainCond>>'
    overflow:t='hidden'
    width:t='pw'
    margin-top:t='@blockInterval'
    padding-bottom:t='5@sf/@pf'
    color:t='@profilePageTextColor'
  }

  profilePageText {
    text:t='<<multDesc>>'
    overflow:t='hidden'
    width:t='pw'
  }

  profilePageText {
    text:t='<<conds>>'
    overflow:t='hidden'
    width:t='pw'
    padding-top:t='4@sf/@pf'
    color:t='@profilePageTextColor'
  }

  <<#rewardText>>
  profilePageText {
    padding-top:t='4@sf/@pf'
    text:t='<<?challenge/reward>> <<rewardText>>'
    color:t='@profilePageTextColor'
  }
  <</rewardText>>

  Button_text{
    id:t='checkbox_favorites'
    position:t='relative'
    margin-top:t='13@sf/@pf'
    visualStyle:t='secondary'
    text:t='#mainmenu/UnlockAchievementsToFavorite'
    tooltip:t=''
    unlockId:t=''
    btnName:t='LT'
    isChecked:t='no'
    on_click:t='unlockToFavorites'

    ButtonImg {}
    buttonWink {}
  }
}