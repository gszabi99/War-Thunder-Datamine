root {
  background-color:t='@shadeBackgroundColor'

  frame {
    pos:t='50%pw-50%w, 1@minYposWindow + 0.3*(sh - 1@minYposWindow - h)';
    position:t='relative'
    class:t='wndNav'

    frame_header {
      activeText {
        caption:t='yes';
        text:t='<<?options/fonts_type>>'
      }

      Button_close { id:t = 'btn_back' }
    }

    textAreaCentered {
      width:t='0.7@sf'
      text:t='<<?fontSize/description>>'
    }

    ComboBox{
      size:t='0.3@sf, @buttonHeight'
      pos:t='50%pw-50%w, 1@blockInterval'
      position:t='relative'
      btnName:t='X'
      on_select:t='onFontsChange'
      <<@options>>
    }

    navBar {
      navMiddle {
        Button_text {
          id:t = 'btn_ok'
          text:t = '#mainmenu/btnOk'
          btnName:t='A'
          _on_click:t = 'goBack'
          ButtonImg {}
        }
      }
    }
  }
}