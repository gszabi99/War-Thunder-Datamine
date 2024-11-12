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
    display:t='hide'

    <<#options>>
    option {
      id:t='<<id>>'
      text:t='<<text>>'
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
  display:t='hide'
}