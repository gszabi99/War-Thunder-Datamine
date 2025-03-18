<<#items>>
  premiumItem {
    size:t='1@premiumItemWidth, 1@premiumItemHeight'
    margin:t='0, 0, 3@blockInterval, 3@blockInterval'
    bgcolor:t='#66080A0D'
    flow:t='vertical'
    mouse-pointer-centering:t='50, 90'
    tdiv {
      size:t='pw, 95@sf/@pf'
      img {
        size:t='pw, ph'
        background-image:t='ui/images/premium/premium_item_bg'
      }

      tdiv {
        position:t='absolute'
        pos:t='0.5pw-0.5w, ph-h'
        tdiv {
        <<#digits>>
        img {
          margin-right:t='1/3@blockInterval'
          height:t='72@sf/@pf'
          width:t='<<ratioCoeff>>h'
          background-image:t='!ui/images/premium/digit_<<digit>>'
          background-repeat:t='aspect-ratio'
        }
        <</digits>>
        }
      }
    }

    textareaNoTab {
      margin-top:t='1@blockInterval'
      width:t='pw'
      text-align:t='center'
      text:t='<<days>>'
      smallFont:t='yes'
      overlayTextColor:t='active'
    }

    textareaNoTab {
      width:t='pw'
      text-align:t='center'
      margin-top:t='1@blockInterval'
      text:t='<<premiumCost>>'
      font-pixht:t='0.9@fontHeightBigBold'
      overlayTextColor:t='active'
    }

    textareaNoTab {
      margin-top:t='1@blockInterval'
      width:t='pw'
      text-align:t='center'
      text:t='<<savings>>'
      smallFont:t='yes'
      overlayTextColor:t='active'
    }

    Button_text {
      premiumName = <<name>>
      pos:t='0.5pw-0.5w, ph-h-1@blockInterval'
      position:t='absolute'
      width:t='pw-2@blockInterval'
      noMargin:t='yes'
      reduceMinimalWidth:t='yes'
      btnName:t='A'
      on_click:t='onBuy'
      text:t='#mainmenu/btnBuy'
      visualStyle:t='purchase'
      buttonWink{}
      buttonGlance{}
      ButtonImg {}
      skip-navigation:t='yes'
    }
  }
<</items>>
