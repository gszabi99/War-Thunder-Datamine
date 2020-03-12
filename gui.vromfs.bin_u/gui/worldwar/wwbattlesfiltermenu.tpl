rootUnderPopupMenu {
  on_click:t='goBack'
  on_r_click:t='goBack'
}

popup_menu {
  id:t='main_frame'
  menu_align:t='<<align>>'
  position:t='root'
  flow:t='vertical'

  <<#rows>>
  options_list {
    flow:t='vertical'
    text {
      text:t='<<title>>'
    }
    options_nest {
      include "gui/commonParts/multiSelect"
    }
  }
  <</rows>>
  popup_menu_arrow{}
}