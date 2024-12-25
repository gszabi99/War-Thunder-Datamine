<<#options>>
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
      font-pixht:t='<<scale>>*22@sf/@pf \ 1'

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


tdiv {
  position:t='relative'
  margin-top:t='<<scale>>*20@sf/@pf'
  <<#isSmallSize>>
  min-height:t='25@sf/@pf'
  <</isSmallSize>>
  <<^isSmallSize>>
  min-height:t='@baseTrHeight - 4@dp'
  <</isSmallSize>>
  width:t='pw'
  css-hier-invalidate:t='yes'

  ComboBox {
    id:t='showcase_gamemodes'
    position:t='absolute'
    width:t='<<scale>>*pw - <<scale>>*50@sf/@pf'
    left:t='(pw-w)/2'
    border:t='yes'
    border-color:t='@showcaseBoxBorder'
    on_select:t='onShowcaseGameModeSelect'
    <<#isSmallSize>>
    isProfileSmallSize:t='yes'
    <</isSmallSize>>
  }
}

tdiv {
  position:t='absolute'
  top:t='(ph-h)/2'
  width:t='pw'
  flow:t='vertical'

  blankTextArea {
    position:t='relative'
    left:t='(pw-w)/2'
    font:t='@fontMedium'
    font-pixht:t='<<scale>>*27@sf/@pf \ 1'
    color:t='@showcaseGreyText'
    text:t=' '
    input-transparent:t='yes'
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
      size:t='<<scale>>*32@sf/@pf, <<scale>>*32@sf/@pf'
      background-color:t='@showcaseBlue'
      background-image:t='#ui/gameuiskin#all_unit_types.svg'
      background-svg-size:t='<<scale>>*32@sf/@pf, <<scale>>*32@sf/@pf'
      background-repeat:t='aspect-ratio'
    }

    blankTextArea {
      id:t='edit_second_title_text'
      position:t='relative'
      padding:t='<<scale>>*32@sf/@pf, 0'
      font:t='@fontBigBold'
      font-pixht:t='(<<scale>>*38@sf/@pf) \ 1'
      color:t='#FFFFFF'
      text:t='<<secondTitle>>'
    }

    image {
      position:t='relative'
      top:t='(ph-h)/2'
      size:t='<<scale>>*32@sf/@pf, <<scale>>*32@sf/@pf'
      background-color:t='@showcaseBlue'
      background-image:t='#ui/gameuiskin#all_unit_types.svg'
      background-svg-size:t='<<scale>>*32@sf/@pf, <<scale>>*32@sf/@pf'
      background-repeat:t='aspect-ratio'
    }
  }
}
