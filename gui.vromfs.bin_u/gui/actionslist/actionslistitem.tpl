<<#actions>>
<<#show>>

<<#isLink>>
button {
<</isLink>>

<<^isLink>>
actionListItem {
<</isLink>>

  id:t='<<actionName>>'
  behavior:t='button';

  on_click:t='onAction';

  <<#disabled>>
  enable:t='no'
  <</disabled>>

  <<#icon>>
  icon {
    <<#iconRotation>>
      rotation:t = '<<iconRotation>>'
    <</iconRotation>>
    background-image:t='<<icon>>';
    color-factor:t='0'
  }
  <</icon>>

  <<#haveWarning>>
  warning_icon {
    id:t='warning_icon'
    color-factor:t='0'
  }
  <</haveWarning>>
  text {
    behavior:t='textarea';
    text:t='<<text>>';
    <<#isLink>>
      isLink:t='yes';
      underline {
        color-factor:t='0'
      }
    <</isLink>>
    <<#isWarning>>
      isWarning:t='yes';
    <</isWarning>>
    <<#isObjective>>
      isObjective:t='yes'
    <</isObjective>>
    color-factor:t='0'
  }
  <<#isShowDragAndDropIcon>>
  tooltip:t='#slotbar/dragUnitHint'
  dragAndDropIcon {
    css-hier-invalidate:t='yes'
    margin-left:t='0.5@blockInterval'
    flow:t='horizontal'
    text {
      text:t=' ('
    }
    icon {
      background-image:t='#ui/gameuiskin#dnd_icon.svg'
    }
    text {
      text:t=')'
    }
  }
  <</isShowDragAndDropIcon>>
  <<#haveDiscount>>
  discount_notification {
    id:t='discount_image';
    type:t='line'
    color-factor:t='0'
  }
  <</haveDiscount>>
}
<</show>>
<</actions>>
