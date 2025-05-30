<<#avatars>>
avatarImg {
  id:t='<<id>>';
  class:t='profileImg';
  selected:t='<<selected>>';

  img {
    background-image:t='<<avatarImage>>';
    position:t='relative'
    pos:t='50%pw-50%w,50%ph-50%h';

    <<^enabled>>
    tdiv {
      pos:t='0, ph-h'
      position:t='absolute'
      size:t='pw, ph/2'
      background-svg-size:t='pw, ph/2'
      background-image:t='!ui/images/profile/wnd_gradient.svg'
      background-color:t='@black'
      background-repeat:t='expand-svg'
    }

    LockedImg { statusLock:t='avatarImage' }
    <</enabled>>
  }

  <<#hasGjnIcon>>
    tdiv {
      position:t='absolute'
      pos:t='1@blockInterval + 1@lockIconInnerRightOffset, 1@avatarButtonSize + 1@blockInterval - h - 4@sf/@pf'
      size:t='1@newWidgetIconHeight, 1@newWidgetIconHeight'
      img {
        size:t='1@newWidgetIconHeight, 1@newWidgetIconHeight'
        background-image:t='#ui/gameuiskin#gc.svg';
        background-svg-size:t='1@newWidgetIconHeight, 1@newWidgetIconHeight'
        background-repeat:t='aspect-ratio';
      }
    }
  <</hasGjnIcon>>

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
