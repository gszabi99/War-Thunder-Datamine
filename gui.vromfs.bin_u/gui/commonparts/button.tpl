<<#isHyperlink>>
  button {
    talign:t='left'
    on_click:t='onMsgLink'

    <<#acccessKeyName>>
      height:t="1@buttonHeight"
      btnName:t=<<acccessKeyName>>
      showConsoleImg:t='yes'
      ButtonImg {}
    <</acccessKeyName>>

    underline{}
<</isHyperlink>>

<<^isHyperlink>>
  Button_text {
  <<#funcName>>
    <<#delayed>>_<</delayed>>on_click:t='<<funcName>>'
  <</funcName>>
  <<^funcName>>
    <<#onClick>>
      <<#delayed>>_<</delayed>>on_click:t='<<onClick>>'
    <</onClick>>
  <</funcName>>
<</isHyperlink>>

  id:t='<<id>>'
  text:t='<<text>>'
  tooltip:t='<<tooltip>>'
  css-hier-invalidate:t='yes'
  <<#isHidden>>
    display:t='hide'
    enable:t='no'
  <</isHidden>>
  <<#isEmptyButton>>
    enable:t='no'
    inactive:t='yes'
  <</isEmptyButton>>

  <<#visualStyle>>
    visualStyle:t='<<visualStyle>>'
  <</visualStyle>>
  <<#isColoredImg>>
    isColoredImg:t='<<isColoredImg>>'
  <</isColoredImg>>

  <<^isToBattle>>
    <<#style>>
      style:t='<<style>>'
    <</style>>
    <<#class>>
      class:t='<<class>>'
    <</class>>
    <<#buttonClass>>
      class:t='<<buttonClass>>'
    <</buttonClass>>
  <</isToBattle>>

  buttonWink {}
  buttonGlance {}

  <<#isToBattle>>
    class:t='battle'
    <<^titleButtonFont>>
      navButtonFont:t='yes'
    <</titleButtonFont>>
    <<#titleButtonFont>>
      style:t='height:1@battleButtonHeight;'
    <</titleButtonFont>>
    pattern{}
    btnText {
      id:t='<<id>>_text'
      text:t='<<text>>'
    }
  <</isToBattle>>

  <<#link>>
    link:t='<<link>>'
    <<#isLink>>
      isLink:t='yes'
      <<#isFeatured>>
        isFeatured:t='yes'
        hideText:t='yes'
      <</isFeatured>>

      btnText {
        id:t='<<id>>_text'
        position:t='relative'
        pos:t='50%pw-50%w, 50%ph-50%h'
        <<^isFeatured>>
          hideText:t='yes'
        <</isFeatured>>

        text:t='<<text>>'
        font:t='@fontNormal'
        css-hier-invalidate:t='yes'
        underline{}
      }
    <</isLink>>
  <</link>>

  <<#shortcut>>
    btnName:t='<<shortcut>>'
    ButtonImg {
      <<#showOnSelect>>
        showOnSelect:t='<<showOnSelect>>'
      <</showOnSelect>>
      <<#btnName>>
        btnName:t='<<btnName>>'
      <</btnName>>
    }
  <</shortcut>>

  <<@actionParamsMarkup>>

  <<#image>>
    btnImage { background-image:t='<<image>>' }
  <</image>>

  <<#img>>
    img { background-image:t='<<img>>' }
  <</img>>

  additionalIconsDiv {
    input-transparent:t='yes'
    css-hier-invalidate:t='yes'

    <<#newIconWidget>>
      tdiv {
        id:t='<<id>>_new_icon'
        display:t='hide'
        tooltip:t='#mainmenu/<<id>>_new_items'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        <<@newIconWidget>>
      }
    <</newIconWidget>>

    <<#unseenIcon>>
    unseenIcon {
      id:t='<<id>>_new_icon'
      value:t='<<unseenIcon>>'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      noMargin:t='yes'
    }
    <</unseenIcon>>

    <<#needDiscountIcon>>
    discount_notification {
      id:t='<<id>>_discount'
      display:t='hide'
      type:t='line'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
    }
    <</needDiscountIcon>>
  }
}
