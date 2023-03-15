<<#subunlocks>>
tdiv {
  width:t='pw/2-1'
  padding-top:t='@blockInterval'
  padding-right:t='@blockInterval'

  img {
    size:t='0.6*@unlockIconSize, 0.6*@unlockIconSize'
    position:t='relative'
    <<#isUnlocked>>
    background-image:t='#ui/gameuiskin#favorite'
    background-position:t='0, -2@dp, 0, 2@dp'
    <</isUnlocked>>
  }

  textareaNoTab {
    text:t='<<title>>'
    smallFont:t='yes'
    <<^isUnlocked>>
    overlayTextColor:t='faded'
    <</isUnlocked>>
    width:t='fw'
    position:t='relative'
    pos:t='0, 50%(ph-h)'
    margin-left:t='@blockInterval'
  }
}
<</subunlocks>>