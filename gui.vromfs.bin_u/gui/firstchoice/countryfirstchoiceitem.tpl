div {
  id:t='country_choice_list_box';
  width:t='pw'
  flow:t='h-flow'
  total-input-transparent:t='yes'

  behaviour:t='posNavigator'
  navigatorShortcuts:t='active'
  on_select:t='onSelectCountry';
  _on_activate:t='onEnterChoice'
  _on_click:t='onEnterChoice'

  <<#countries>>
  firstChoiceItem {
    width:t='@countryChoiceImageWidth'
    class:t='country'

    firstChoiceImage {
      background-image:t='<<backgroundImage>>'
    }

    <<#isLocked>>
    enable:t='no';
    img {
      background-image:t='#ui/gameuiskin#locked';
      position:t='absolute';
      size:t='@mIco, @mIco';
    }
    <</isLocked>>

    <<#lockText>>
    textAreaCentered {
      width:t='pw - 2@countryChoiceInterval'
      pos:t='50%pw-50%w, @countryChoiceImageHeight -  h - @countryChoiceInterval'
      position:t='absolute'
      smallFont:t='yes'
      text:t='<<lockText>>'
    }
    <</lockText>>

    img {
      size:t='@cIco, @cIco'
      position:t='absolute'
      pos:t='pw - w -  @countryChoiceInterval, @countryChoiceInterval'

      background-image:t='#ui/gameuiskin#btn_help.svg'
      background-svg-size:t='@cIco, @cIco'
      tooltip:t='<<desription>>'
      hide_when_tooltip_empty:t='yes'
    }

    firstChoiceText {
      text:t='<<countryName>>'
      css-hier-invalidate:t='yes'

      ButtonImg {
        size:t='40@sf/@pf, 40@sf/@pf'
        pos:t='50%ph-50%w, 50%ph-50%h'
        position:t='absolute'
        showOnSelect:t='yes'
        btnName:t='A'
      }
    }
  }
  <</countries>>
}
