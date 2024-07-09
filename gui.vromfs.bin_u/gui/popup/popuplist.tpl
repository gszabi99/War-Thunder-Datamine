popup_menu {
  id:t='popup_list'
  not-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  position:t='root'

  rootUnderPopupMenu {
    on_click:t='<<underPopupClick>>'
    on_r_click:t='<<underPopupDblClick>>'
    <<#clickPropagation>>
    access-key:t='no'
    <</clickPropagation>>

    DummyButton {
      btnName:t='B';
      on_click:t = 'goBack'
    }
  }

  tdiv {
    max-height:t='0.9sh'
    overflow-y:t='auto'
    flow:t='vertical'
    include "%gui/commonParts/buttonsList.tpl"
  }

  popup_menu_arrow {}
}
