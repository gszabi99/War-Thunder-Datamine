activateSelect {
  id:t='sheets_list'
  class:t='hflow'
  max-width:t='pw'
  smallFont:t='yes'

  total-input-transparent:t='yes'
  moveX:t='linear'
  moveY:t='closest'
  navigatorShortcuts:t='yes'
  on_select:t = 'onItemTypeChange'
  on_wrap_up:t='onWrapUp'
  on_wrap_down:t='onWrapDown'

  coloredTexts:t='yes'

  include "gui/commonParts/shopFilter"
}
