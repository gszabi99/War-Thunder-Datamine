textareaNoTab {
  height:t='1@buttonHeight'
  position:t='absolute'
  pos:t='pw - 1@blockInterval - 0.5@collectionPrizeWidth - 0.5w, 1@blockInterval'
  text:t='#reward'
  enable:t='no'
}

<<#collections>>
<<#title>>
textareaNoTab {
  width:t='pw'
  height:t='1@buttonHeight'
  position:t='absolute'
  pos:t='<<titlePos>>'
  text:t='<<title>>'
  enable:t='no'
}
<</title>>

include "gui/commonParts/imgFrame"
<</collections>>