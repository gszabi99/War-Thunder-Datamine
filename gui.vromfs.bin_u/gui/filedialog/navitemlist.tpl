<<#items>>
  <<#isChapter>>chapter<</isChapter>><<^isChapter>>mission<</isChapter>>_item_unlocked {
    id:t = '<<id>>'
    <<#isSelected>>
    selected:t = 'yes'
    <</isSelected>>

    img {
      id:t = 'icon_<<id>>'
      medalIcon:t = 'yes'
      background-image:t = '<<itemIcon>>'
    }

    missionDiv {
      css-hier-invalidate:t = 'yes'
      mission_item_text {
        id:t = 'txt_<<id>>'
        text:t = '<<itemText>>'
      }
    }
  }
<</items>>
