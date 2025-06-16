tdiv {
  width:t='pw'
  flow:t='horizontal'
  margin-top:t='2@blockInterval'

  tdiv{
    position:t='relative'
    size:t='241@sf/@pf, 127@sf/@pf'
    bigMedalImg {
      pos:t='0.5pw-0.5w, 0.5ph-0.5h'
      size:t='pw, ph'
      background-image:t='<<image>>'
      background-svg-size:t='pw, ph'
    }
  }

  tdiv {
    width:t='fw'
    flow:t='vertical'
    padding-left:t='5@sf/@pf'
    padding-top:t='10@sf/@pf'
    tdiv {
      width:t='pw'
      img {
        background-image:t='#ui/gameuiskin#locked.svg'
        size:t='@cIco, @cIco'
        background-svg-size:t='@cIco, @cIco'
        background-repeat:t='aspect-ratio'
        display:t='<<#unlocked>>hide<</unlocked>><<^unlocked>>show<</unlocked>>'
        valign:t='center'
      }
      profilePageTitle {
        text-align:t='left'
        text:t='<<skinName>>'
        valign:t='center'
      }
    }
    tdiv {
      width:t='pw'
      flow:t='vertical'

      profilePageText {
        text:t='<<skinDesc>>'
        overflow:t='hidden'
        width:t='pw'
        margin-top:t='2@dp'
        color:t='@profilePageTextColor'
      }

      <<#hasProgress>>
      challengeDescriptionProgress {
        isProfileUnlockProgress:t='yes'
        value:t='<<unlockProgress>>'
      }
      <</hasProgress>>

      profilePageText {
        text:t='<<mainCond>>'
        overflow:t='hidden'
        width:t='pw'
        margin-top:t='@blockInterval'
        color:t='@profilePageTextColor'
      }

      profilePageText {
        text:t='<<multDesc>>'
        overflow:t='hidden'
        width:t='pw'
        color:t='@profilePageTextColor'
      }

      profilePageText {
        text:t='<<conds>>'
        overflow:t='hidden'
        width:t='pw'
        margin-top:t='@blockInterval'
        color:t='@profilePageTextColor'
      }

      profilePageText {
        text:t='<<skinPrice>>'
        width:t='pw'
        margin-top:t='7@dp'
        color:t='@profilePageTextColor'
      }
    }

    tdiv {
      flow:t='vertical'
      size:t='pw, 0'
      max-height:t='ph-@bigMedalPlaceYpos-<<ratio>>*@profileMedalSize-@modStatusCheckboxHeight-3@blockInterval'
      overflow-y:t='auto'
      total-input-transparent:t='yes'

      <<#conditions>>
      unlockCondition {
        unlocked:t='<<unlocked>>'
        profilePageText {
          text:t='<<text>>'
          color:t='@profilePageTextColor'
        }
      }
      <</conditions>>
    }
    tdiv {
      position:t='relative'
      flow:t='horizontal'
      margin-top:t='10@sf/@pf'
      left:t='-1@buttonTextPadding'
      Button_text {
        id:t = 'btn_SkinPreview'
        text:t='#mainmenu/btnPreview'
        btnName:t='L3'
        on_click:t = 'onSkinPreview'
        showButtonImageOnConsole:t='no'
        class:t='image'
        img{ background-image:t='#ui/gameuiskin#btn_preview.svg' }
        buttonWink {}
        ButtonImg {}
        visualStyle:t="secondary"
      }
      <<#canAddFav>>
      Button_text{
        id:t='checkbox_favorites'
        position:t='relative'
        visualStyle:t='secondary'
        text:t='#mainmenu/UnlockAchievementsToFavorite'
        tooltip:t=''
        on_click:t='unlockToFavorites'
        unlockId:t=''
        btnName:t='LT'
        isChecked:t='no'
        ButtonImg {}
        buttonWink {}
      }
      <</canAddFav>>
    }
  }
}