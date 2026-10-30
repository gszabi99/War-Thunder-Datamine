tdiv {
  width:t='pw'

  flow:t='h-flow'
  flow-align:t='center'
  total-input-transparent:t='yes'

  behaviour:t='posNavigator'
  navigatorShortcuts:t='yes'
  on_select:t='onSelectSlot'
  _on_activate:t='onClickUnitType'
  _on_click:t='onClickUnitType'

  <<#items>>
  firstChoiceItem {
    width:t='1@unitChoiceImageWidth'
    height:t='1@unitChoiceImageHeight'
    margin-right:t='1@countryChoiceInterval'
    tooltipText:t='<<tooltip>>'
    on_hover:t='onUnitBtnHover'
    on_unhover:t='onUnitBtnUnhover'

    <<#isLast>>isLast:t='yes'<</isLast>>
    firstChoiceImage {
      background-image:t='<<backgroundImage>>'
    }
    <<#videoPreview>>
    movie {
      movie-load='<<videoPreview>>'
      movie-autoStart:t='yes'
      movie-loop:t='yes'
    }
    <</videoPreview>>

    firstChoiceShadow {}

    firstChoiceText {
      text:t='<<text>>'
      css-hier-invalidate:t='yes'

      ButtonImg {
        size:t='40@sf/@pf, 40@sf/@pf'
        pos:t='-w-1@blockInterval, 50%ph-50%h'
        position:t='absolute'
        showOnSelect:t='yes'
        btnName:t='A'
      }
    }
    slotHoverHighlight {}
    firstChoiceSelectRect {}
  }
  <</items>>
}
