titleTextArea {
  text-align:t='center'
  text:t='<<unitName>>'
}

titleTextArea {
  text-align:t='center'
  text:t='<<skinName>>'
}

tdiv {
  size:t='pw, fh'
  flow:t='vertical'

  bigMedalPlace {
    bigMedalImg {
      max-height:t='<<ratio>>*h'
      max-width:t='<<ratio>>*w'
      background-image:t='<<image>>'
      status:t='<<status>>'
    }
  }

  tdiv {
    padding-left:t='@unlockConditionHeaderLeftPadding'
    margin-top:t='2@blockInterval'
    width:t='pw'
    flow:t='vertical'

    textareaNoTab {
      text:t='<<skinDesc>>'
      overflow:t='hidden'
      width:t='pw'
      smallFont:t='yes'
      margin-top:t='2@dp'
    }

    <<#hasProgress>>
    challengeDescriptionProgress {
      value:t='<<unlockProgress>>'
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

    textareaNoTab {
      text:t='<<skinPrice>>'
      width:t='pw'
      smallFont:t='yes'
      margin-top:t='7@dp'
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
      textarea {
        text:t='<<text>>'
      }
    }
    <</conditions>>
  }

  <<#canAddFav>>
  tdiv {
    padding-left:t='@unlockConditionHeaderLeftPadding'
    margin-top:t='2@blockInterval'

    CheckBox {
      id:t='checkbox_favorites'
      text:t='#mainmenu/UnlockAchievementsToFavorite'
      smallFont:t='yes'
      tooltip:t=''
      on_change_value:t='unlockToFavorites'
      unlockId:t=''
      btnName:t='Y'
      ButtonImg {}
      CheckBoxImg {}
    }
  }
  <</canAddFav>>
}