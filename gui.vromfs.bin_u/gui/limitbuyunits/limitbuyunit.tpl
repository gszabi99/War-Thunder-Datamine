<<#units>>
limitBuyUnit {
  id:t=<<unitName>>
  timeEnd:t='<<timeEnd>>'
  size:t='1@limitBuyUnitWidth, 1@limitBuyUnitHeight'
  css-hier-invalidate:t='yes'
  <<#hasActionButton>>
  hasActionButton:t='yes'
  <</hasActionButton>>
  tdiv {
    halign:t='center'
    valign:t='center'
    size:t='1@limitBuyUnitContentWidth, 1@limitBuyUnitContentHeight'
    background-svg-size:t='1@limitBuyUnitContentWidth, 1@limitBuyUnitContentHeight'
    background-image:t='!ui/images/limitBuyUnits/limitBuyUnitGradient.avif'
    bgcolor:t='#FFFFFF'
    flow:t='vertical'
    css-hier-invalidate:t='yes'
    img {
      position:t='absolute'
      size:t='1@limitBuyUnitContentWidth, 178@sf/@pf'
      background-svg-size:t='1@limitBuyUnitContentWidth, 178@sf/@pf'
      background-image:t='!ui/images/limitBuyUnits/limitBuyUnitBackground.avif'
      bgcolor:t='#FFFFFF'
    }
    tdiv {
      position:t='relative'
      size:t='pw, 42@sf/@pf - 0.5@blockInterval'
      margin-top:t='0.5@blockInterval'
      <<#timeFinal>>
      textareaNoTab {
        halign:t='center'
        input-transparent:t='yes'
        text:t='<<timeFinal>>'
      }
      <</timeFinal>>
      <<#timeLeft>>
      tdiv {
        position:t='absolute'
        halign:t='center'
        img {
          size:t='@sIco, @sIco'
          background-svg-size:t='@sIco, @sIco'
          background-image:t='#ui/gameuiskin#timer_icon.svg'
          margin-right:t='1@blockInterval'
          valign:t='center'
        }
        text {
          id:t='timeLeft'
          overlayTextColor:t='gold'
          text:t='<<timeLeft>>'
        }
      }
      <</timeLeft>>
    }
    tooltipLink {
      position:t='relative'
      width:t='300/350pw'
      halign:t='center'
      tdiv {
        position:t='relative'
        width:t='pw'
        halign:t='center'
        flow:t='vertical'
        tdiv {
          position:t='relative'
          size:t='pw, 0.5w'
          halign:t='center'
          img {
            position:t='absolute'
            size:t='0.41pw, 0.45ph'
            background-image:t='<<countryImage>>'
          }
          img {
            top:t='ph-h'
            position:t='absolute'
            size:t='pw, ph'
            background-image:t='<<unitImage>>'
          }
          hoverButton {
            unitName:t=<<unitName>>
            position:t='absolute'
            pos:t='pw-w, ph-h'
            tooltip:t='#mainmenu/btnPreview'
            on_click:t='onPreviewUnit'
            on_hover:t='onHoverPreviewBtn'
            no_text:t='yes'
            icon { background-image:t='#ui/gameuiskin#btn_preview.svg' }
          }
        }
        textareaNoTab {
          position:t='relative'
          halign:t='center'
          input-transparent:t='yes'
          overlayTextColor:t='active'
          text:t='<<unitFullName>>'
        }
        <<#isTooltipByHold>>
        tooltipId:t='<<tooltipId>>'
        <</isTooltipByHold>>
        <<^isTooltipByHold>>
        tooltipObj {
          tooltipId:t='<<tooltipId>>'
          on_tooltip_open:t='onGenericTooltipOpen'
          on_tooltip_close:t='onTooltipObjClose'
          display:t='hide'
        }

        tooltip-float:t='horizontal'
        title:t='$tooltipObj'
        <</isTooltipByHold>>
      }
    }
    tdiv {
      halign:t='center'
      width:t='0.95pw'
      overflow:t='hidden'

      textAreaCentered {
        position:t='relative'
        min-width:t='pw'
        text-align:t='center'
        input-transparent:t='yes'
        text:t='<<unitType>>'
        scrolled:t='yes'
      }
    }
    tdiv {
      position:t='relative'
      halign:t='center'
      tdiv {
        tooltip:t='#shop/age/tooltip'
        textareaNoTab {
          input-transparent:t='yes'
          text:t='<<unitAgeHeader>>'
        }
        textareaNoTab {
          overlayTextColor:t='active'
          input-transparent:t='yes'
          text:t='<<unitAge>>'
        }
      }
      tdiv {
        tooltip:t='#shop/battle_rating/tooltip'
        margin-left:t='2@blockInterval'
        textareaNoTab {
          text:t='<<unitRatingHeader>>'
          input-transparent:t='yes'
        }
        textareaNoTab {
          overlayTextColor:t='active'
          input-transparent:t='yes'
          text:t='<<unitRating>>'
        }
      }
    }

    pricePlace {
      position:t='absolute'
      pos:t='0, ph-h'
      size:t='pw, 58@sf/@pf'
      css-hier-invalidate:t='yes'
      input-transparent:t='yes'
      <<#hasDiscount>>
      img {
        position:t='absolute'
        left:t='pw-w'
        size:t='234@sf/@pf, 58@sf/@pf'
        background-svg-size:t='234@sf/@pf, 58@sf/@pf'
        background-image:t='!ui/images/limitBuyUnits/discountBackground.avif'
      }
      textareaNoTab {
        left:t='pw-w-1@blockInterval'
        position:t='absolute'
        valign:t='center'
        overlayTextColor:t='active'
        input-transparent:t='yes'
        text:t='<<discountText>>'
      }
      <</hasDiscount>>
      tdiv {
        size:t='pw, ph'
        position:t='absolute'
        <<^hasDiscount>>
        textareaNoTab {
          halign:t='center'
          valign:t='center'
          input-transparent:t='yes'
          text:t='<<priceText>>'
        }
        <</hasDiscount>>
        <<#hasDiscount>>
        tdiv {
          halign:t='center'
          valign:t='center'
          textareaNoTab {
            css-hier-invalidate:t='yes'
            input-transparent:t='yes'
            text=<<newPrice>>
            margin-right:t='1@blockInterval'
          }
          textareaNoTab {
            css-hier-invalidate:t='yes'
            input-transparent:t='yes'
            text=<<oldPrice>>
            tdiv {
              size:t='pw, 1@sf/@pf'
              valign:t='center'
              background-color:t='@borderInnerColor'
            }
          }
        }
        <</hasDiscount>>
      }
    }

    buttonPlace {
      position:t='absolute'
      pos:t='0, ph-h'
      size:t='pw, 58@sf/@pf'
      css-hier-invalidate:t='yes'
      input-transparent:t='yes'

      <<#hasShopButton>>
      Button_text {
        halign:t='center'
        valign:t='center'
        input-transparent:t='yes'
        text:t='#mainmenu/btnOrder'
        on_click:t='onShopBuy'
        showButtonImageOnConsole:t='no'
        class:t='image'
        visualStyle:t='purchase'
        skip-navigation:t='yes'
        enableOn:t='hover'
        noMargin:t='yes'
        buttonWink{}
        buttonGlance{}
        btnName:t='X'
        unit:t=<<unitName>>
        ButtonImg {}
        img{ background-image:t='#ui/gameuiskin#store_icon.svg' }
      }
      <</hasShopButton>>
      <<#hasBuyButton>>
      Button_text {
        halign:t='center'
        valign:t='center'
        input-transparent:t='yes'
        on_click:t='onBuy'
        hideText:t='yes'
        css-hier-invalidate:t='yes'
        showButtonImageOnConsole:t='no'
        visualStyle:t='purchase'
        skip-navigation:t='yes'
        enableOn:t='hover'
        noMargin:t='yes'
        buttonWink{}
        buttonGlance{}
        btnName:t='X'
        unit:t=<<unitName>>
        unitCostGold:t='<<unitCostGold>>'
        unitCostWp:t='<<unitCostWp>>'
        ButtonImg {}
        textarea {
          id:t='btn_buy_text'
          class:t='buttonText'
          text:t='<<priceText>>'
        }
      }
      <</hasBuyButton>>

    }
    <<#hasFocusBorder>>
    focus_border {}
    <</hasFocusBorder>>
  }
}
<</units>>