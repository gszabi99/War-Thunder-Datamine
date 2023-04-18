Button_text {
  id:t='action_btn'
  noMargin:t='yes'
  text:t='<<actionText>>'
  btnName:t='R3'
  on_click:t='onAction'
  ButtonImg {}
}

popup_menu {
  id:t='selector_obj'
  width:t='3.5@buttonWidth'
  top:t='-h-1@blockInterval'
  position:t='absolute'
  display:t='hide'
  enable:t='no'
  flow:t='horizontal'
  not-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  order-popup:t='yes'

  rootUnderPopupMenu {
    on_click:t='onUnderPopupClick'
    on_r_click:t='onUnderPopupClick'
  }

  dummy { // To avoid close menu on click outside of button but inside area
    size:t='pw, ph'
    position:t='absolute'
  }

  tdiv {
    width:t='pw'
    flow:t='vertical'
    <<#rows>>
    tdiv {
      width:t='pw'
      position:t='relative'
      padding-bottom:t='1@blockInterval'
      flow:t='horizontal'

      textareaNoTab {
        left:t='1@blockInterval'
        position:t='relative'
        text:t='<<title>>'
      }

      ComboBox {
        width:t='1@navBarBattleButtonMinWidth'
        right:t='0'
        position:t='relative'
        on_select:t='onSelect'
        on_cancel_edit:t='onSelect'
        <<@options>>
      }
    }
    <</rows>>

    rowSeparator {}

    tdiv {
      width:t='pw'
      top:t='-1@blockInterval'
      position:t='relative'
      flow:t='horisontal'
      Button_text {
        top:t='0.5ph-0.5h'
        position:t='relative'
        text:t='#mainmenu/btnCancel'
        btnName:t='LT'
        on_click:t='onCancel'
        ButtonImg {}
      }
      Button_text {
        right:t='0'
        top:t='0.5ph-0.5h'
        position:t='relative'
        class:t='battle'
        text:t='#mainmenu/btnApply'
        navButtonFont:t='yes'
        hasConsoleImage:t='yes'
        on_click:t='onApply'
        pattern{}
        buttonWink { _transp-timer:t='0' }
        buttonGlance {}
        ButtonImg {
          btnName:t='RT'
        }
        btnText {
          text:t='#mainmenu/btnApply'
        }
      }
    }
  }
}
