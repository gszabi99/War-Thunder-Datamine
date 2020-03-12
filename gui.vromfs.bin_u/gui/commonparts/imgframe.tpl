<<#items>>
<<#tag>><<tag>><</tag>><<^tag>>imgFrame<</tag>> {
  <<#id>>
  id:t='<<id>>'
  <</id>>
  <<#imgClass>>
  class:t='<<imgClass>>'
  <</imgClass>>
  input-transparent:t='yes'

  <<#backlight>>
  backlight {
    unlockedObject:t='<<#unlocked>>yes<</unlocked>><<^unlocked>>no<</unlocked>>'
  }
  <</backlight>>

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
    <<^unlocked>>
      style:t='background-color:@lockedDecal;'
    <</unlocked>>
  }

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
