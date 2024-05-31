<<#units>>

wishedItem{
  id:t=<<unitName>>
  css-hier-invalidate:t='yes'
  <<^isFirst>>
  margin-top:t='2@blockInterval'
  <</isFirst>>
  tdiv {
    position:t='relative'
    height:t='ph'
    width:t='540/294h'
    img {
      position:t='absolute'
      size:t='0.4pw, 0.4ph'
      background-image:t='<<countryImage>>'
    }
    img {
      top:t='ph-h'
      position:t='absolute'
      size:t='pw, 0.5pw'
      background-image:t='<<unitImage>>'
    }
  }
  tdiv {
    size:t='fw, ph'
    margin:t='2@blockInterval'
    css-hier-invalidate:t='yes'
    tdiv {
      size:t='pw, ph'
      css-hier-invalidate:t='yes'
      tdiv {
        flow:t='vertical'
        width:t='pw'
        pos:t='0, 0.5ph - 0.5h'
        position:t='absolute'
        activeText {
          position:t='relative'
          normalBoldFont:t='yes'
          text:t='<<unitFullName>>'
        }
        textareaNoTab {
          position:t='relative'
          margin-top:t='1@blockInterval'
          smallFont:t='yes'
          text:t='<<unitType>>'
        }
        tdiv {
          position:t='relative'
          margin-top:t='1@blockInterval'
          tdiv {
            tooltip:t='#shop/age/tooltip'
            textareaNoTab {
              smallFont:t='yes'
              text:t='<<unitAgeHeader>>'
            }
            textareaNoTab {
              overlayTextColor:t='active'
              smallFont:t='yes'
              text:t='<<unitAge>>'
            }
          }
          tdiv {
            tooltip:t='#shop/battle_rating/tooltip'
            margin-left:t='1@blockInterval'
            textareaNoTab {
              smallFont:t='yes'
              text:t='<<unitRatingHeader>>'
            }
            textareaNoTab {
              overlayTextColor:t='active'
              smallFont:t='yes'
              text:t='<<unitRating>>'
            }
          }
        }
        <<#hasComment>>
        textareaNoTab {
          margin-top:t='0.5@blockInterval'
          position:t='relative'
          smallFont:t='yes'
          max-width:t='0.7pw'
          text:t='<<comment>>'
        }
        <</hasComment>>
      }
    }
    tdiv {
      pos:t='pw-w, 0'
      height:t='@trashButtonHeight'
      position:t='absolute'
      flow:t='horizontal'
      css-hier-invalidate:t='yes'
      textareaNoTab {
        smallFont:t='yes'
        text:t='<<time>>'
        valign:t='center'
        margin-right:t='0.5@blockInterval'
      }
      <<#hasTrashBin>>
      Button_text {
        type:t='trashBin'
        not-input-transparent:t='yes'
        enableOn:t='select'
        on_click:t='onItemRemove'
        showButtonImageOnConsole:t='yes'
        class:t='image'
        btnName:t='RB'
        ButtonImg {
          showOnSelect:t='yes'
        }
        img{ background-image:t='#ui/gameuiskin#icon_trash_bin.svg' }
        top:t='center'
        unit:t=<<unitName>>
      }
      <</hasTrashBin>>
    }

    tdiv {
      pos:t='pw-w, ph-h'
      position:t='absolute'
      css-hier-invalidate:t='yes'
      <<#hasShopButton>>
      Button_text {
        enableOn:t='select'
        not-input-transparent:t='yes'
        text:t='#mainmenu/btnOrder'
        on_click:t='onShopBuy'
        showButtonImageOnConsole:t='no'
        class:t='image'
        visualStyle:t='purchase'
        skip-navigation:t='yes'
        noMargin:t='yes'
        buttonWink{}
        buttonGlance{}
        btnName:t='X'
        ButtonImg {
          showOnSelect:t='yes'
        }
        img{ background-image:t='#ui/gameuiskin#store_icon.svg' }
        unit:t=<<unitName>>
      }
      <</hasShopButton>>
      <<#hasBuyButton>>
      Button_text {
        enableOn:t='select'
        not-input-transparent:t='yes'
        on_click:t='onBuy'
        hideText:t='yes'
        css-hier-invalidate:t='yes'
        showButtonImageOnConsole:t='no'
        visualStyle:t='purchase'
        skip-navigation:t='yes'
        noMargin:t='yes'
        buttonWink{}
        buttonGlance{}
        btnName:t='X'
        ButtonImg {
          showOnSelect:t='yes'
        }
        textarea {
          id:t='btn_buy_text'
          class:t='buttonText'
          text:t='<<priceText>>'
        }
        unit:t=<<unitName>>
      }
      <</hasBuyButton>>
      <<#hasMarketPlaceButton>>
      Button_text {
        enableOn:t='select'
        not-input-transparent:t='yes'
        text:t='#msgbox/btn_find_on_marketplace'
        on_click:t='onMarketplaceFindUnit'
        showButtonImageOnConsole:t='no'
        visualStyle:t='secondary'
        skip-navigation:t='yes'
        class:t='image'
        noMargin:t='yes'
        buttonWink{}
        img{ background-image:t='#ui/gameuiskin#gc.svg' }
        btnName:t='X'
        ButtonImg {
          showOnSelect:t='yes'
        }
        unit:t=<<unitName>>
      }
      <</hasMarketPlaceButton>>
      <<#hasUseCouponButton>>
      Button_text {
        enableOn:t='select'
        not-input-transparent:t='yes'
        text:t='#item/consume/coupon'
        on_click:t='onUseCoupon'
        showButtonImageOnConsole:t='no'
        visualStyle:t='secondary'
        skip-navigation:t='yes'
        class:t='image'
        noMargin:t='yes'
        buttonWink{}
        img{ background-image:t='#ui/gameuiskin#gc.svg' }
        btnName:t='X'
        ButtonImg {
          showOnSelect:t='yes'
        }
        unit:t=<<unitName>>
      }
      <</hasUseCouponButton>>
      <<#hasConditionsButton>>
      Button_text {
        enableOn:t='select'
        not-input-transparent:t='yes'
        text:t='#sm_conditions'
        on_click:t='onShowConditions'
        showButtonImageOnConsole:t='no'
        visualStyle:t='secondary'
        skip-navigation:t='yes'
        buttonWink{}
        buttonGlance{}
        ButtonImg {}
        btnName:t='X'
        unit:t=<<unitName>>
      }
      <</hasConditionsButton>>
      <<#hasGiftButton>>
      Button_text {
        enableOn:t='select'
        not-input-transparent:t='yes'
        text:t='#wishlist/btnGift'
        on_click:t='onGiftBuy'
        showButtonImageOnConsole:t='no'
        class:t='image'
        visualStyle:t='purchase'
        skip-navigation:t='yes'
        noMargin:t='yes'
        buttonWink{}
        btnName:t='X'
        ButtonImg {
          showOnSelect:t='yes'
        }
        buttonGlance{}
        img{ background-image:t='#ui/gameuiskin#store_icon.svg' }
        unit:t=<<unitName>>
      }
      <</hasGiftButton>>
    }
  }
  <<#hasFocusBorder>>
  focus_border {}
  <</hasFocusBorder>>
}
<</units>>