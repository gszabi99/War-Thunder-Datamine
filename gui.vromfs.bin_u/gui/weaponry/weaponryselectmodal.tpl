rootUnderPopupMenu {
  on_click:t='goBack'
  on_r_click:t='goBack'
}

popup_menu {
  id:t='main_frame'
  pos:t='<<position>>'
  menu_align:t='<<align>>'
  position:t='root'

  div {
    id:t='anim_block'
    width:t='<<columns>>@modCellWidth'
    height:t='<<rows>>@modCellHeight'
    overflow:t='hidden'

    behaviour:t='basicSize'
    size-time:t='300'
    size-func:t='squareInv'
    blend-time:t='0'

    div {
      id:t='weapons_list'
      size:t='<<columns>>@modCellWidth, <<rows>>@modCellHeight'
      pos:t='pw-w, ph-h'
      position:t='absolute'

      behavior:t='posNavigator'
      navigatorShortcuts:t='active'
      moveX:t='closest'
      moveY:t='linear'

      on_activate:t = 'onChangeValue'

      value:t='<<value>>'

      <<@weaponryList>>
    }
  }
  popup_menu_arrow{}
}