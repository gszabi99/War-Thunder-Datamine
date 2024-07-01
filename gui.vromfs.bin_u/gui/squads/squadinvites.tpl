<<#items>>
emptyButton {
  id:t='squad_invite_<<id>>'
  class:t='squadWidgetInvite'
  uid:t='<<id>>'
  title:t='$tooltipObj'
  total-input-transparent:t='yes'
  on_click:t='onMemberClicked'
  on_r_click:t='onMemberClicked'

  memberIcon {
    value:t='<<pilotIcon>>'
  }

  animated_wait_icon {
    background-rotation:t='0'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
  }

  tooltipObj {
    uid:t='<<id>>'
    on_tooltip_open:t='onContactTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
}
<</items>>