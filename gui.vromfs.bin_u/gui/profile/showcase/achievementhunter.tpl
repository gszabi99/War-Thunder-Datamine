tdiv {
  id:t='achieve_container'
  position:t='relative'
  width:t='pw'
  css-hier-invalidate:t='yes'

  tdiv {
    id:t='achieve_lines'
    position:t='relative'
    width:t='pw'
    pos:t='(pw-w)/2, 0'
    flow:t='h-flow'
    flow-align:t='center'
    showInEditMode:t='no'

    <<#achievementsView>>
    image {
      size:t='<<achievSize>>, <<achievSize>>'
      margin:t='20@sf/@pf, 20@sf/@pf'
      background-repeat:t='aspect-ratio'
      background-svg-size:t='<<achievSize>>, <<achievSize>>'
      background-image:t='<<image>>'
      background-color:t='#FFFFFF'

      title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='<<tooltipId>>'
        display:t='hide'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
      }
    }
    <</achievementsView>>
  }

  tdiv {
    id:t='<<containerId>>'
    position:t='relative'
    width:t='pw'
    left:t='0'
    flow:t='h-flow'
    flow-align:t='center'
    display:t='hide'
    showInEditMode:t='yes'
    css-hier-invalidate:t='yes'
    <<#editableSlots>>

    button {
      id:t='hunter_slot_<<slotId>>'
      slotId:t='<<slotId>>'
      achiev:t='<<achiev>>'
      position:t='relative'
      size:t='<<width>>, <<height>>'
      margin:t='20@sf/@pf, 20@sf/@pf'
      background-repeat:t='aspect-ratio'
      background-svg-size:t='<<width>>, <<height>>'
      css-hier-invalidate:t='yes'
      <<#image>>
        background-image:t='<<image>>'
        background-color:t='#FFFFFF'
      <</image>>
      <<^image>>
        background-image:t=''
      <</image>>

      on_click:t='onShowcaseCustomFunc'

      title:t='$tooltipObj'
      tooltipObj {
        id:t='slot_tooltip'
        tooltipId:t='<<tooltipId>>'
        display:t='hide'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
      }

      editableSlotPlus {
        position:t='relative'
        size:t='pw, ph'
        display:t='hide'

        tdiv {
          position:t='absolute'
          size:t='5@sf/@pf, 26@sf/@pf'
          pos:t='(pw-w)/2, (ph-h)/2'
          background-color:t='#FFFFFF'
          showInEditMode:t='yes'
        }
        tdiv {
          position:t='absolute'
          size:t='26@sf/@pf, 5@sf/@pf'
          pos:t='(pw-w)/2, (ph-h)/2'
          background-color:t='#FFFFFF'
          showInEditMode:t='yes'
        }
      }

      tdiv {
        re-type:t='9rect'
        position:t='absolute'
        size:t='<<width>>, <<height>>'
        background-color:t='#FFFFFF'
        background-image:t='!ui/images/profile/stroke_medal.svg'
        background-position:t='10, 10'
        background-svg-size:t='<<width>>, <<height>>'
        background-repeat:t='expand-svg'
      }
    }
    <</editableSlots>>
  }

  tdiv {
    position:t='absolute'
    pos:t='(pw-w)/2, ph + <<scale>>*46@sf/@pf'
    size:t="<<scale>>*pw - <<scale>>*30@sf/@pf, <<scale>>*44@sf/@pf"
    background-color:t='@showcaseWhiteTransparent'

    tdiv {
      re-type:t='textarea'
      behaviour:t='textArea'
      position:t='absolute'
      font:t="tiny_text_hud"
      text:t='#unlocks/chapter/achievements'
      color:t='@showcaseGreyText'
      left:t='<<scale>>*20@sf/@pf'
      font-pixht:t='<<scale>>*24@sf/@pf \ 1'
      top:t='(ph-h)/2'
    }
    tdiv {
      position:t='absolute'
      re-type:t='textarea'
      behaviour:t='textArea'
      font:t="tiny_text_hud"
      font-pixht:t='<<scale>>*24@sf/@pf \ 1'
      text:t='<<achievStats>>'
      color:t='#FFFFFF'
      left:t='pw - w - <<scale>>*18@sf/@pf'
      top:t='(ph-h)/2'
    }
  }
}