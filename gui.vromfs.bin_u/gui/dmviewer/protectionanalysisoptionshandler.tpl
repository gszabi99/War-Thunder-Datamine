EditBox {
  id:t='filter_edit_box'
  width:t='pw'
  on_change_value:t='applyFilter'
  on_cancel_edit:t='onFilterCancel'
  text:t=''
  edit-hint:t='#contacts/search_placeholder'
}

verticalCellsOptions {
  id:t= 'options_container'
  width:t='pw'

  class:t='optionsMultiColumn'
  fullWidthOptions:t='yes'
  selfFocusBorder:t='yes'
  css-hier-invalidate:t='yes'

  moveY:t='linear'

  behavior:t='PosOptionsNavigator'
  navigatorShortcuts:t='yes'
  on_wrap_left:t='onDistanceDec'
  on_wrap_right:t='onDistanceInc'

  include "%gui/options/verticalOptions.tpl"
}

CheckBox {
  id:t='checkboxSaveChoice'
  class:t='with_textarea'
  margin:t='1@tablePad, 2@blockInterval, 0, 1@blockInterval'
  position:t='relative'
  value:t='<<#isSavedChoice>>yes<</isSavedChoice>><<^isSavedChoice>>no<</isSavedChoice>>'
  on_change_value:t='onSave'
  btnName:t='Y'
  ButtonImg {}
  CheckBoxImg {}
  textareaNoTab {
    text:t='#mainmenu/btnSaveChoice'
  }
}


