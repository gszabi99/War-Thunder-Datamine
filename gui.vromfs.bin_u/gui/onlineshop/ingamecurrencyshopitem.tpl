<<#items>>
ingameCurrencyShopItem {
  id:t='<<id>>'
  size:t='@ingameCurrencyShopItemWidth, @ingameCurrencyShopItemHeight'
  margin:t='@ingameCurrencyShopItemMargin'
  background-color:t='#242b34'
  border='no'
  border-color:t= '#464F5A'
  border-offset='-1@dp'
  mouse-pointer-centering:t='80, 90'
  css-hier-invalidate:t='yes'
  total-input-transparent:t='yes'
  flow:t='vertical'

  itemHeader {
    size:t='pw, 70@sf/@pf'
    padding-right:t='12@sf/@pf'
    padding-bottom:t='2@sf/@pf'

    img {
      size:t='pw, ph'
      position:t='absolute'
      background-image:t='<<itemHeaderImg>>'
    }

    tdiv {
      position:t='relative'
      bottom:t='0'
      right:t='0'

      <<#digits>>
      img {
        width:t='<<ratio>>*52@sf/@pf'
        height:t='52@sf/@pf'
        <<#needSpace>>
        margin-left:t='14@sf/@pf'
        <</needSpace>>
        <<^needSpace>>
        margin-left:t='2@sf/@pf'
        <</needSpace>>
        background-image:t='<<src>>'
        background-repeat:t='aspect-ratio'
      }
      <</digits>>
    }
  }

  itemContent {
    size:t='pw,fh'
    padding-right:t='12@sf/@pf'
    padding-top:t='4@sf/@pf'
    css-hier-invalidate:t='yes'
    flow:t='vertical'

    <<#itemIcon>>
    img {
      position:t='absolute'
      pos:t='0, ph-h'
      size:t='158@sf/@pf,158@sf/@pf'
      background-image:t='<<itemIcon>>'
      background-repeat:t='aspect-ratio'
    }
    <</itemIcon>>

    textareaNoTab {
      width:t='pw'
      text:t='<<amount>>'
      isAmount:t='yes'
      smallFont:t='yes'
      text-align:t='right'
    }

    textareaNoTab {
      width:t='pw'
      text:t='<<cost>>'
      text-align:t='right'
      overlayTextColor='active'
      bigBoldFont:t='yes'
    }

    textareaNoTab {
      width:t='pw'
      text:t='<<savingText>>'
      smallFont:t='yes'
      overlayTextColor='active'
      text-align:t='right'
    }

    Button_text {
      id:t='buttonBuy' //Need for find object in scene for automated tests
      owner:t='<<id>>'
      position:t='absolute'
      pos:t='pw-w-12@sf/@pf, ph-h-12@sf/@pf'
      noMargin:t='yes'
      showOn:t='hoverOrPcSelect'
      btnName:t='A'
      on_click:t='onCurrencyBuy'

      <<^externalLink>>
      text:t='#mainmenu/btnBuy';
      visualStyle:t='purchase'
      buttonWink{}
      buttonGlance{}
      <</externalLink>>

      <<#externalLink>>
      text:t='';
      externalLink:t='yes';
      activeText {
        text:t='#mainmenu/btnBuy';
        underline {}
      }
      <</externalLink>>
      ButtonImg {}
    }
  }
}
<</items>>