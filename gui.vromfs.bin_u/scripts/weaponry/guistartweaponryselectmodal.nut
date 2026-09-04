let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
























return function guiStartWeaponrySelectModal(config) {
  loadHandler(get_gui_handler("WeaponrySelectModal"), config)
}