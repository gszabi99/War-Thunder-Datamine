tdiv {
  id:t='<<containerId>>'
  position:t='relative'
  flow:t='vertical'
  left:t='(pw-w)/2'
  css-hier-invalidate:t='yes'

  tdiv {
    flow:t='horizontal'
    margin-bottom:t='14@sf/@pf'
    css-hier-invalidate:t='yes'
    tdiv {
      position:t='relative'
      size:t='50@sf/@pf, 40@sf/@pf'
      css-hier-invalidate:t='yes'

      CheckBox {
        id:t='all_checkbox'
        position:t='relative'
        pos:t='(pw-w)/2 + 2@sf/@pf, (ph - h)/2'
        display:t='hide'
        showInEditMode:t='yes'
        on_change_value:t='onShowcaseCustomFunc'
        CheckBoxImg{}
        ButtonImg{}
      }
    }
  <<#flags>>
    tdiv {
      id:t='<<flagId>>'
      position:t='relative'
      size:t='44@sf/@pf, 40@sf/@pf'
      margin-left:t='14@sf/@pf'
      background-image:t='<<flag>>'
      background-color:t='<<flagColor>>'
      background-svg-size:t='44@sf/@pf, 40@sf/@pf'
      background-repeat:t='aspect-ratio'
    }
  <</flags>>
  }

  <<#stats>>
  tdiv {
    id:t=<<lineIdx>>
    flow:t='horizontal'
    margin:t='0, 7@sf/@pf'
    css-hier-invalidate:t='yes'
    background-color:t='<<lineBgColor>>'

    <<^isLineEnabled>>
      display:t='hide'
      showInEditMode:t='yes'
      isLineEnabled:t='no'
    <</isLineEnabled>>

    <<#isLineEnabled>>
      isLineEnabled:t='yes'
    <</isLineEnabled>>

    img {
      position:t='relative'
      size:t='36@sf/@pf, 36@sf/@pf'
      top:t='(ph-h)/2'
      margin-left:t='14@sf/@pf'
      background-color:t='#FFFFFF'
      background-image:t='<<unitTypeIcon>>'
      background-svg-size:t='36@sf/@pf, 36@sf/@pf'
      background-repeat:t='aspect-ratio'
    }

    <<#values>>
    tdiv {
      width:t='44@sf/@pf'
      min-height:t='40@sf/@pf'
      margin-left:t='14@sf/@pf'
      flow:t='vertical'
      css-hier-invalidate:t='yes'

      CheckBox {
        id:t='<<checkboxId>>'
        position:t='relative'
        left:t='(pw-w)/2 + 2@sf/@pf'
        display:t='hide'
        value:t='<<isValEnabled>>'
        showInEditMode:t='yes'
        <<^isCheckboxEnabled>>
        enable:t='no'
        <</isCheckboxEnabled>>
        on_change_value:t='onShowcaseCustomFunc'
        CheckBoxImg{}
        ButtonImg{}
      }
      blankTextArea {
        position:t='relative'
        left:t='(pw-w)/2'
        font:t='@fontSmall'
        font-pixht:t='22@sf/@pf \ 1'
        text-align:t='center'
        display:t='hide'
        color:t='@white'
        text:t='<<valInEditMode>>'
        showInEditMode:t='yes'
        input-transparent:t='yes'
      }
      blankTextArea {
        position:t='relative'
        pos:t='(pw-w)/2, (ph-h)/2'
        font:t='@fontSmall'
        font-pixht:t='22@sf/@pf \ 1'
        text-align:t='center'
        color:t='@white'
        text:t='<<value>>'
        showInEditMode:t='no'
        input-transparent:t='yes'
      }
    }
    <</values>>
  }
  <</stats>>

  tdiv {
    position:t='absolute'
    top:t='ph + <<scale>>*46@sf/@pf'
    size:t='pw, <<scale>>*44@sf/@pf'
    background-color:t='@showcaseWhiteTransparent'

    tdiv {
      re-type:t='textarea'
      behaviour:t='textArea'
      position:t='absolute'
      font:t="tiny_text_hud"
      text:t='#profile/elite_units_own'
      color:t='#7C8389'
      left:t='<<scale>>*20@sf/@pf'
      font-pixht:t='<<scale>>*24@sf/@pf \ 1'
      top:t='(ph-h)/2'
    }
    tdiv {
      id:t='<<eliteUnitsCountLabelId>>'
      re-type:t='textarea'
      behaviour:t='textArea'
      position:t='absolute'
      font:t="tiny_text_hud"
      font-pixht:t='<<scale>>*24@sf/@pf \ 1'
      text:t='<<elitUnitsCounts>>'
      color:t='#FFFFFF'
      left:t='pw - w - <<scale>>*18@sf/@pf'
      top:t='(ph-h)/2'
    }
    tooltip:t='#ace_of_spades/elite_vehicles_tooltip'
  }
}