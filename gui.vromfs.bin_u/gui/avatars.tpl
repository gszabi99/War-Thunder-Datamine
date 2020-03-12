<<#avatars>>
Button_text {
  id:t='<<id>>';
  class:t='profileImg';
  selected:t='<<selected>>';
  <<#enabled>>
  enabled:t='yes';
  on_click:t='onImageChoose';
  <</enabled>>
  <<^enabled>>
  enabled:t='no';
  <</enabled>>

  img {
    background-image:t='<<avatarImage>>';
    position:t='relative'
    pos:t='50%pw-50%w,50%ph-50%h';
  }

  <<#unseenIcon>>
  unseenIcon {
    pos:t='4@dp, 4@dp'
    position:t='absolute'
    value:t='<<unseenIcon>>'
  }
  <</unseenIcon>>

  <<#haveCustomTooltip>>
  title:t='$tooltipObj'
  tooltipObj {
    tooltipId:t='<<id>>'
    display:t='hide'
    on_tooltip_open:t='onImageTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
  }
  <</haveCustomTooltip>>
  <<^haveCustomTooltip>>
  <<#tooltipId>>
  title:t='$tooltipObj'
  tooltipObj {
    tooltipId:t='<<tooltipId>>'
    display:t='hide'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
  }
  <</tooltipId>>
  <</haveCustomTooltip>>
}
<</avatars>>
