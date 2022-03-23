popup_menu {
  pos:t='<<posX>>, <<posY>>-h-1@blockInterval'
  position:t='relative'
  flow:t='vertical'
  not-input-transparent:t='yes'

  rootUnderPopupMenu {
    on_click:t='<<underPopupClick>>'
    on_r_click:t='<<underPopupDblClick>>'
  }

  include "%gui/commonParts/buttonsList"
}
