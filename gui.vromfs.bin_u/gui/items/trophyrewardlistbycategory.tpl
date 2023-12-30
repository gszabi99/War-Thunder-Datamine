rootUnderPopupMenu {
  on_click:t='goBack'
  on_r_click:t='goBack'
  input-transparent:t='yes'
}

popup_menu {
  id:t='main_frame'
  size:t='1@itemInfoWidth, 1@rh'
  position:t='root'
  pos:t='sw-1@bw-w, 1@bh'
  total-input-transparent:t='yes'
  flow:t='vertical'

  Button_close {
    _on_click:t='goBack'
    smallIcon:t='yes'
  }

  textAreaCentered {
    id:t='header_text'
    width:t='pw'
    overlayTextColor:t='active'
    text:t='<<headerText>>'
  }

  tdiv {
    size:t='pw, @itemsSeparatorSize'
    background-color:t='@frameSeparatorColor'
    margin-top:t='1@blockInterval'
  }

  div {
    size:t='pw, fh'
    flow:t='vertical'
    <<@contentData>>
  }
}
