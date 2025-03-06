<<#items>>
  premiumItem {
    size:t='170@sf/@pf, 250@sf/@pf'
    margin:t='3@blockInterval, 0, 0, 3@blockInterval'
    bgcolor:t='#66080A0D'
    flow:t='vertical'
    tdiv {
      size:t='170@sf/@pf, 95@sf/@pf'
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
      width:t='pw'
      text-align:t='center'
      margin-top:t='5@blockInterval'
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
      overlayTextColor:t='faded'
    }

    Button_text {
      premiumName = <<name>>
      pos:t='0.5pw-0.5w, ph-h-1@blockInterval'
      position:t='absolute'
      noMargin:t='yes'
      btnName:t='A'
      on_click:t='onBuy'
      text:t='#mainmenu/btnBuy'
      visualStyle:t='purchase'
      buttonWink{}
      buttonGlance{}
      ButtonImg {}
    }
  }
<</items>>
