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

  text {
    behavior:t='textarea'
    text:t='<<text>>'
    <<#isLink>>
      isLink:t='yes'
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
  <<#haveWarning>>
  warning_icon {
    id:t='warning_icon'
    <<#haveDiscount>>
      pos:t='pw - w - 1@actionItemSidePadding, (ph-h)/2'
    <</haveDiscount>>
    <<^haveDiscount>>
      pos:t='pw - w, (ph-h)/2'
    <</haveDiscount>>
    color-factor:t='0'
  }
  <</haveWarning>>

  <<#haveDiscount>>
  tdiv {
    re-type:t='9rect'
    id:t='discount_image'
    position:t='absolute'
    pos:t='pw - 1@actionItemSidePadding + 1@sf/@pf, (ph-h)/2'
    size:t='1@newWidgetIconHeight, 0.7@newWidgetIconHeight'
    padding-left:t='0.2*w'
    background-image:t='#ui/gameuiskin#discount_box_thin_bg.svg'
    background-svg-size:t='1@newWidgetIconHeight, 0.7@newWidgetIconHeight'
    background-color:t='@discountBGColor'
    background-repeat:t='expand-svg'
    background-position:t='0.3@newWidgetIconHeight, 0, 0, 0'
    text:t='%'
    font:t='@fontSmall'
    color-factor:t='0'
    color:t='@discountTextColor'
    font:t='@fontNormal'
    textShade:t='yes'
  }
  <</haveDiscount>>
}
<</show>>
<</actions>>
