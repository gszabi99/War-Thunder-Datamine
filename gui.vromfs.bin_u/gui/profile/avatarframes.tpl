<<#avatarFrames>>
avatarImg {
  id:t='<<id>>'
  class:t='profileImg'
  selected:t='<<selected>>'

  img {
    background-image:t='<<frameImage>>'
    position:t='relative'
    pos:t='50%pw-50%w,50%ph-50%h'

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

  <<#tooltipId>>
  title:t='$tooltipObj'
  tooltipObj {
    tooltipId:t='<<tooltipId>>'
    display:t='hide'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
  }
  <</tooltipId>>
}
<</avatarFrames>>
