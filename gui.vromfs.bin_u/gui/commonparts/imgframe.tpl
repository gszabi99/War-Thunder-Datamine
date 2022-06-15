<<#items>>
<<#tag>><<tag>><</tag>><<^tag>>imgFrame<</tag>> {
  <<#id>>
  id:t='<<id>>'
  <</id>>
  <<#imgClass>>
  class:t='<<imgClass>>'
  <</imgClass>>
  input-transparent:t='yes'
  <<#pos>>
  pos:t='<<pos>>'
  position:t='absolute'
  <</pos>>
  <<#backlight>>
  backlight {
    unlockedObject:t='<<#unlocked>>yes<</unlocked>><<^unlocked>>no<</unlocked>>'
  }
  <</backlight>>

  <<#onClick>>
  behavior:t='button'
  on_click:t='<<onClick>>'
  focusBtnName:t='A'
  <</onClick>>

  <<#focusBorder>>
  focus_border {}
  <</focusBorder>>


  img {
    size:t='1@profileMedalSize, 1@profileMedalSize'
    <<#imgRatio>>
    max-width:t='<<imgRatio>>h'
    max-height:t='w/<<imgRatio>>'
    <</imgRatio>>
    pos:t='pw/2-w/2, ph/2-h/2'
    position:t='relative'
    background-image:t='<<image>>'
    background-svg-size:t='1@profileMedalSize, 1@profileMedalSize'
    <<^unlocked>>
      style:t='background-color:@lockedDecal;'
    <</unlocked>>
  }

  <<#topRightText>>
  textareaNoTab {
    position:t='absolute'
    pos:t='pw - w - 1@blockInterval, 0'
    hideEmptyText:t='yes'
    text:t='<<topRightText>>'
  }
  <</topRightText>>

  <<#bottomCenterText>>
  textareaNoTab {
    pos:t='pw/2-w/2, ph-h -1@blockInterval'
    position:t='absolute'
    smallFont:t='yes'
    text:t='<<bottomCenterText>>'
  }
  <</bottomCenterText>>

  <<^unlocked>>
    <<#statusLock>>
    LockedImg { statusLock:t='<<statusLock>>' }
    <</statusLock>>
  <</unlocked>>

  <<#miniIcon>>
  miniIcon {
    size:t='<<miniIconSize>>'
    position:t='absolute'
    pos:t='<<miniIconPos>>'
    background-image:t='<<miniIcon>>'
    background-color:t='<<miniIconColor>>'
    background-svg-size:t='<<miniIconSize>>'
  }
  <</miniIcon>>

  <<#tooltipId>>
  tooltipObj {
    id:t='tooltip_<<tooltipId>>'
    tooltipId:t='<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  } title:t='$tooltipObj'
  <</tooltipId>>
}
<</items>>
