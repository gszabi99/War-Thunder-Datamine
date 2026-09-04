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
    imgGradient {
      pos:t='0, ph-h'
      size:t='pw, ph/2'
      background-color:t='@black'
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
