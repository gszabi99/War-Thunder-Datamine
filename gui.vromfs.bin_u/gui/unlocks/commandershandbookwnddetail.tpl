<<#items>>
tdiv {
  width:t='pw'
  flow:t='vertical'
  padding:t='@framePadding'

  textareaNoTab {
    text:t='<<assignment>>'
    smallFont:t='yes'
    overlayTextColor:t='disabled'
  }

  textareaNoTab {
    text:t='<<title>>'
    normalBoldFont:t='yes'
    margin-top:t='1@blockInterval'
    overlayTextColor:t='unlockHeader'
  }

  // description: text before the video, the video in place, then text after it
  // Text chunks carry {{ID_*}} shortcuts, so use bhvHint
  tdiv {
    id:t='cmh_desc_before'
    width:t='pw'
    margin-top:t='1@blockInterval'
    behaviour:t='bhvHint'
    value:t='<<descBefore>>'
    isWrapInRowAllowed:t='yes'
    flow-align:t='left'
  }

  <<#hasVideo>>
  tdiv {
    width:t='pw'
    margin-top:t='1@blockInterval'
    movie {
      width:t='pw'
      height:t='0.5625*w' // 9/16
      movie-load:t='<<videoPath>>'
      movie-autoStart:t='yes'
      movie-loop:t='yes'
    }
  }
  <</hasVideo>>

  <<#hasDescAfter>>
  tdiv {
    id:t='cmh_desc_after'
    width:t='pw'
    margin-top:t='1@blockInterval'
    behaviour:t='bhvHint'
    value:t='<<descAfter>>'
    isWrapInRowAllowed:t='yes'
    flow-align:t='left'
  }
  <</hasDescAfter>>

  <<#hasProgress>>
  battleTaskProgress {
    width:t='pw'
    margin-top:t='1@blockInterval'
    max:t='<<maxVal>>'
    value:t='<<curVal>>'
  }
  <</hasProgress>>

  textareaNoTab {
    text:t='<<requirements>>'
    width:t='pw'
    margin-top:t='1@blockInterval'
    smallFont:t='yes'
    hideEmptyText:t='yes'
  }

  profilePageText {
    id:t='reward'
    text:t=''
    margin-top:t='1@blockInterval'
    max-width:t='pw'
    pare-text:t='yes'
    color:t='@profilePageTextColor'
  }

  tdiv {
    width:t='pw'
    flow:t='horizontal'
    margin-top:t='1@blockInterval'

    Button_text {
      id:t='manual_open_button'
      visualStyle:t='purchase'
      on_click:t='onManualOpenUnlock'
      unlockId:t=''
      text:t='#items/getRewardShort'
      btnName:t='Y'
      buttonWink {}
      ButtonImg {}
    }

    <<#hasFavButton>>
    Button_text {
      id:t='checkbox_favorites'
      text:t='#mainmenu/UnlockAchievementsToFavorite'
      on_click:t='unlockToFavorites'
      unlockId:t=''
      visualStyle:t='secondary'
      btnName:t='LT'
      margin-left:t='1@blockInterval'
      buttonWink {}
      ButtonImg {}
      isChecked:t='no'
    }
    <</hasFavButton>>
  }
}
<</items>>
