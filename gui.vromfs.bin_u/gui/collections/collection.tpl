<<#hasCollections>>
textareaNoTab {
  height:t='1@buttonHeight'
  position:t='absolute'
  pos:t='pw - 1@blockInterval - 0.5@collectionPrizeWidth - 0.5w, 1@blockInterval'
  text:t='#reward'
  enable:t='no'
}
<</hasCollections>>

<<^hasCollections>>
textareaNoTab {
  height:t='1@buttonHeight'
  position:t='relative'
  pos:t='50%pw-50%w, 50%ph-50%h'
  text-align:t='center'
  text:t='#collection/all_collections_completed'
  enable:t='no'
}
<</hasCollections>>

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