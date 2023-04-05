<<#isPromo>>
smallFont:t='yes'
<</isPromo>>
<<#taskDescription>>
textareaNoTab {
  id:t='taskDescription'
  max-width:t='pw'
  <<#isPromo>>
  text-align:t='right'
  left:t='pw-w'
  position:t='relative'
  <</isPromo>>
  text:t='<<taskDescription>>'
}
<</taskDescription>>

<<#needShowProgressBar>>
progressDiv {
  left:t='pw-w'
  position:t='relative'
  margin-top:t='0.005@sf'
  battleTaskProgress {
    top:t='50%ph-50%h'
    position:t='relative'
    width:t='0.4@arrowButtonWidth'
    value:t='<<progressBarValue>>'
  }
}
<</needShowProgressBar>>

<<#taskConditionsList>>
unlockCondition {
  unlocked:t='<<#unlocked>>yes<</unlocked>><<^unlocked>>no<</unlocked>>'
  unlockImg{}
  textareaNoTab {
    text:t='<<text>>'
  }
}
<</taskConditionsList>>

<<#taskUnlocksList>>
tdiv {
  width:t='pw'
  class:t='header'
  <<^isOnlyInfo>>
  Button_text {
    task_id:t='<<id>>'
    class:t='image'
    imgSize:t='small'
    showConsoleImage:t='no'
    img { background-image:t='#ui/gameuiskin#btn_help.svg' }
    on_click:t='onViewBattleTaskRequirements'
  }
  <</isOnlyInfo>>
  textareaNoTab {
    id:t='taskUnlocksListPrefix'
    text:t='<<taskUnlocksListPrefix>>'
    top:t='50%ph-50%h'
    position:t='relative'
    padding-left:t='0.005@scrn_tgt'
  }
}
tdiv {
  id:t='taskUnlocksList'
  width:t='pw'
  flow:t='h-flow'
  padding-left:t='0.02@scrn_tgt'

  <<#taskUnlocks>>
    tdiv {
      width:t='pw'
      <<#isEven>>
        background-color:t='@evenTrColor'
      <</isEven>>
      unlockCondition {
        valign:t='center'
        style:t='width:pw'
        unlocked:t='<<#isUnlocked>>yes<</isUnlocked>><<^isUnlocked>>no<</isUnlocked>>'
        textareaNoTab {
          text:t='<<text>> <<unlockProgressDesc>>'
          overlayTextColor:t='commonTextColor'
        }
        <<#isProgressBarVisible>>
        battleTaskProgress {
          value:t='<<progressBarValue>>'
        }
        <</isProgressBarVisible>>
        <<#isUnlocked>>
          unlockImg{}
        <</isUnlocked>>
        <<@tooltipMarkup>>
      }
      <<#isAddToFavVisible>>
      CheckBox {
        position:t='absolute'
        pos:t='pw-w-@unlockHeaderIconSize, 50%ph-50%h'
        unlockId:t='<<unlockId>>'
        value:t='<<toFavoritesCheckboxVal>>'
        text:t='#mainmenu/UnlockAchievementsToFavorite'
        on_change_value:t='unlockToFavorites'

        CheckBoxImg{}
        ButtonImg{}
      }
      <</isAddToFavVisible>>
  }
  <</taskUnlocks>>

  <<#taskStreaks>>
    textareaNoTab {
      text:t='<<text>>'
      overlayTextColor:t='<<overlayTextColor>>'
      <<@tooltipMarkup>>
    }
  <</taskStreaks>>
}
<</taskUnlocksList>>

<<#taskSpecialDescription>>
textareaNoTab {
  id:t='task_timer_text'
  behavior:t='Timer'
  padding-top:t='0.03@scrn_tgt'
  width:t='pw'
  <<#isPromo>>
  text-align:t='right'
  <</isPromo>>
  text:t='<<taskSpecialDescription>>'
}
<</taskSpecialDescription>>

<<#doneTasksTable>>
  <<#rows>>
    table {
      width:t='pw'
      baseRow:t='yes'
      text-valign:t='center'
      total-input-transparent:t='yes'
      <<@rows>>
    }
  <</rows>>

  <<^rows>>
    textAreaCentered {
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
      text:t='#mainmenu/battleTasks/noHistory'
    }
  <</rows>>
<</doneTasksTable>>
