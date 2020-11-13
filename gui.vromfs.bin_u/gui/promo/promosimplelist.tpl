<<#list>>
promoButton {
  id:t = '<<id>>'
  type:t= 'simpleList'

  textareaFade {
    height:t='1@arrowButtonHeight'

    textarea {
      id:t='<<id>>_text'
      text:t='<<text>>'

      <<#notifyNew>>
      newIconWidget {
        id:t='<<id>>_new_icon_widget_container';
        position:t='absolute'
        pos:t='-w, 50%ph-50%h'
      }
      <</notifyNew>>
    }

    img {
      id:t='<<id>>_icon'
      size:t='ph, ph'
      background-image:t='<<icon>>'
      background-repeat:t='aspect-ratio'
    }

    <<#hasWaitAnim>>
    animated_wait_icon {
      id:t = 'wait_icon_<<id>>'
      pos:t='pw + 0.01@scrn_tgt, 50%ph-50%h'
      position:t='absolute'
      class:t='missionBox'
      background-rotation:t = '0'
    }
    <</hasWaitAnim>>
  }
}
<</list>>