let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
























return function guiStartWeaponrySelectModal(config) {
  loadHandler(gui_handlers.WeaponrySelectModal, config)
}