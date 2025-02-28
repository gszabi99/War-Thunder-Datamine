  ComboBox {
    id:t='<<id>>'
    position:t='relative'
    width:t='<<scale>>*pw - <<scale>>*50@sf/@pf'
    left:t='(pw-w)/2'
    border:t='yes'
    border-color:t='@showcaseBoxBorder'
    on_select:t='<<onSelect>>'
    <<#isSmallSize>>
    isProfileSmallSize:t='yes'
    <</isSmallSize>>

    <<#options>>
    option {
      id:t='<<id>>'
      text:t='<<text>>'
      <<#selected>>
      selected:t='yes'
      <</selected>>
      <<#isSmallSize>>
      font-pixht:t='<<scale>>*1@comboboxSmallFontPixHt'
      <</isSmallSize>>

      <<#isDisabled>>
        <<#textHint>>
          tooltip:t="<<textHint>>"
        <</textHint>>

        <<^textHint>>
          tooltip:t="$tooltipObj"

          tooltipObj {
            tooltipId:t='<<hintForDisabled>>'
            on_tooltip_open:t="onGenericTooltipOpen"
            on_tooltip_close:t="onTooltipObjClose"
            display:t='hide'
          }
        <</textHint>>
      <</isDisabled>>
    }
    <</options>>
  }