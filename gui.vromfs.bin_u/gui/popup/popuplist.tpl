popup_menu {
  id:t='popup_list'
  not-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  position:t='root'
  flow:t='vertical'

  rootUnderPopupMenu {
    on_click:t='<<underPopupClick>>'
    on_r_click:t='<<underPopupDblClick>>'
  }

  include "%gui/commonParts/buttonsList.tpl"
  popup_menu_arrow {}
}
