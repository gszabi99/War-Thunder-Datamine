<<#conditions>>
unlockCondition {
  height:t='1@buttonHeight'
  <<#isShowAsButton>>
  Button_text {
    scrolledText:t='yes'
    <<^hasAutoscrollText>>
    text:t='<<conditionDescription>>'
    <</hasAutoscrollText>>
    <<#hasAutoscrollText>>
    text:t=''
    width:t='pw'
    <</hasAutoscrollText>>
    skip-navigation:t='yes'
    on_click:t='onShowUnlockCondition'
    unlockId:t='<<unlockId>>'
    <<#hasAutoscrollText>>
    overflow:t='hidden'
    textarea {
      behaviour:t='OverflowScroller'
      move-pixel-per-sec:t='20*@scrn_tgt/100.0'
      move-sleep-time:t='2000'
      move-delay-time:t='2000'
      text:t='<<conditionDescription>>'
      valign:t='center'
    }
    <</hasAutoscrollText>>
  }
  <</isShowAsButton>>
  <<^isShowAsButton>>
  <<#isSimplified>>
    textarea {
    text:t='<<conditionDescription>>'
  }
  <</isSimplified>>
  <<^isSimplified>>
  overflow:t='hidden'
  textareaNoTab {
    behaviour:t='OverflowScroller'
    move-pixel-per-sec:t='20*@scrn_tgt/100.0'
    move-sleep-time:t='2000'
    move-delay-time:t='2000'
    text:t='<<conditionDescription>>'
    valign:t='center'
  }
  <</isSimplified>>
  <</isShowAsButton>>
  <<#hasUnlockImg>>
  unlockImg{}
  <</hasUnlockImg>>
  unlocked:t='<<#isUnlocked>>yes<</isUnlocked>><<^isUnlocked>>no<</isUnlocked>>'
  <<@tooltipMarkup>>
}
<</conditions>>