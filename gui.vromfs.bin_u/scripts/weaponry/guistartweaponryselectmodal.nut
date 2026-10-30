from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
























return function guiStartWeaponrySelectModal(config) {
  loadHandler(get_gui_handler("WeaponrySelectModal"), config)
}