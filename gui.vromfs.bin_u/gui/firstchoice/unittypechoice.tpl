div {
  id:t='unit_type_list_box';
  width:t='pw'

  flow:t="h-flow"
  flow-align:t='center'
  total-input-transparent:t='yes'

  behaviour:t='posNavigator'
  navigatorShortcuts:t='yes'
  on_select:t='onSelectUnitType';
  _on_activate:t='onEnterChoice'
  _on_click:t='onEnterChoice'

  <<#unitTypeItems>>
  firstChoiceItem {
    width:t='@unitChoiceImageWidth'
    tooltip:t='<<tooltip>>'
    class:t='unit'

    firstChoiceImage {
      background-image:t='<<backgroundImage>>'

      <<#videoPreview>>
      movie {
        movie-load='<<videoPreview>>'
        movie-autoStart:t='yes'
        movie-loop:t='yes'
      }
      <</videoPreview>>
    }

    firstChoiceText {
      text:t='<<text>>'
      css-hier-invalidate:t='yes'

      ButtonImg {
        size:t='40@sf/@pf, 40@sf/@pf'
        pos:t='50%ph-50%w, 50%ph-50%h'
        position:t='absolute'
        showOnSelect:t='yes'
        btnName:t='A'
      }
    }

    img {
      size:t='@cIco, @cIco'
      position:t='absolute'
      pos:t='pw - w -  @countryChoiceInterval, @countryChoiceInterval'

      background-image:t='#ui/gameuiskin#btn_help.svg'
      background-svg-size:t='@cIco, @cIco'
      tooltip:t='<<desription>>'
      hide_when_tooltip_empty:t='yes'
    }
  }
  <</unitTypeItems>>
}
