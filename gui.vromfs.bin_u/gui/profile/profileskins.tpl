tdiv {
  width:t='pw'
  flow:t='horizontal'
  margin-top:t='2@blockInterval'

  tdiv{
    position:t='relative'
    width:t='241@sf/@pf'
    height:t='ph'
    bigMedalPlace {
      left:t='(pw-w)/2'
      parentSize:t='true'
      bigMedalImg {
        max-height:t='<<ratio>>*h'
        max-width:t='<<ratio>>*w'
        background-image:t='<<image>>'
        status:t='<<status>>'
      }
    }
  }

  tdiv {
    size:t='fw'
    flow:t='vertical'
    padding-left:t='5@sf/@pf'
    padding-top:t='10@sf/@pf'

    profilePageTitle {
      text-align:t='left'
      text:t='<<unitName>>, <<skinName>>'
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