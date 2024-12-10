<<#isFull>>
optionsBar {
<</isFull>>
  id:t='<<id>>'
  value:t='<<value>>'
  isChanging:t='no'
  on_change_value:t='<<cb>>'

  focus_border{}

  tdiv {
    id:t='text_container'
    width:t='pw'
    position:t='absolute'
    overflow:t='hidden'
    css-hier-invalidate:t='all'

    textareaNoTab {
      id:t='<<id>>_text_value'
      text:t='<<text>>'
      autoScroll:t='yes'
    }
  }

  optionsBarsContainer {
    id:t='options_bars_container'

    <<#options>>
      <<#option>>
      fullHeightBar {
        width:t='pw/<<optionsCount>>'
        tooltip:t='<<text>>'
        tooltip-timeout:t='1'

        <<#onOptHoverFnName>>
        idx:t='<<idx>>'
        on_hover:t='<<onOptHoverFnName>>'
        <</onOptHoverFnName>>

        visibleBar {
          selected:t='<<#isSelected>>yes<</isSelected>><<^isSelected>>no<</isSelected>>'
        }
      }
      <</option>>
    <</options>>
  }

<<#isFull>>
}
<</isFull>>