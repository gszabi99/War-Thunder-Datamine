<<#options>>
  ComboBox {
    id:t='<<id>>'
    position:t='relative'
    width:t='pw - 50@sf/@pf'
    left:t='(pw-w)/2'
    border:t='yes'
    border-color:t='@showcaseBoxBorder'
    on_select:t='<<onSelect>>'
    margin-bottom:t='25@sf/@pf'

    <<#options>>
    option {
      id:t='<<id>>'
      text:t='<<text>>'
      <<#selected>>
      selected:t='yes'
      <</selected>>

      <<#isDisabled>>
      isDisabled:t='yes'
      not-input-transparent:t='yes'

      tdiv {
        position:t='absolute'
        size:t='pw, ph'
        interactive:t='no'
        tooltip:t="$tooltipObj"
        input-transparent:t='no'
        not-input-transparent:t='yes'

        tooltipObj {
          tooltipId:t='<<hintForDisabled>>'
          on_tooltip_open:t="onGenericTooltipOpen"
          on_tooltip_close:t="onTooltipObjClose"
          display:t='hide'
        }
      }
      <</isDisabled>>
    }
    <</options>>
  }
<</options>>

ComboBox {
  id:t='showcase_gamemodes'
  position:t='absolute'
  width:t='pw - 50@sf/@pf'
  left:t='(pw-w)/2'
  top:t='115@sf/@pf'
  border:t='yes'
  border-color:t='@showcaseBoxBorder'
  on_select:t='onShowcaseGameModeSelect'
  margin-bottom:t='25@sf/@pf'
}