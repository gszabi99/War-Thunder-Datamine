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
      tooltip:t="$tooltipObj"

      tooltipObj {
        tooltipId:t='<<hintForDisabled>>'
        on_tooltip_open:t="onGenericTooltipOpen"
        on_tooltip_close:t="onTooltipObjClose"
        display:t='hide'
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

tdiv {
  id:t='edit_second_title'
  left:t='(pw-w)/2'
  position:t='relative'
  flow:t='horizontal'
  display:t='hide'

  image {
    position:t='relative'
    top:t='(ph-h)/2'
    size:t='32@sf/@pf, 32@sf/@pf'
    background-color:t='@showcaseBlue'
    background-image:t='#ui/gameuiskin#all_unit_types.svg'
    background-svg-size:t='32@sf/@pf, 32@sf/@pf'
    background-repeat:t='aspect-ratio'
  }

  blankTextArea {
    id:t='edit_second_title_text'
    position:t='relative'
    padding:t='32@sf/@pf, 0'
    font:t='@fontBigBold'
    color:t='#FFFFFF'
    text:t='<<secondTitle>>'
  }

  image {
    position:t='relative'
    top:t='(ph-h)/2'
    size:t='32@sf/@pf, 32@sf/@pf'
    background-color:t='@showcaseBlue'
    background-image:t='#ui/gameuiskin#all_unit_types.svg'
    background-svg-size:t='32@sf/@pf, 32@sf/@pf'
    background-repeat:t='aspect-ratio'
  }
}
