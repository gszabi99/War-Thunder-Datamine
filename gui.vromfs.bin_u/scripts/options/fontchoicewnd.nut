from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_combobox

let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
const FONT_CHOICE_SAVE_ID = "tutor/fontChange"
let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { set_option, get_option } = require("%scripts/options/optionsExt.nut")
let { USEROPT_FONTS_CSS } = require("%scripts/options/optionsExtNames.nut")
let g_font = require("%scripts/options/fonts.nut")

local wasOpened = false

let FontChoiceWnd = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/options/fontChoiceWnd.tpl"

  option = null

  static function openIfRequired() {
    if (!get_gui_handler("FontChoiceWnd").isSeen() && g_font.getAvailableFonts().len() > 1)
      handlersManager.loadHandler(get_gui_handler("FontChoiceWnd"))
  }

  static function isSeen() {
    return loadLocalAccountSettings(FONT_CHOICE_SAVE_ID, false)
  }

  static function markSeen(isMarkSeen = true) {
    return saveLocalAccountSettings(FONT_CHOICE_SAVE_ID, isMarkSeen)
  }

  function getSceneTplView() {
    this.option = get_option(USEROPT_FONTS_CSS)
    return {
      options = create_option_combobox(this.option.id, this.option.items, this.option.value, null, false)
    }
  }

  function initScreen() {
    if (!wasOpened) {
      wasOpened = true
    }
  }

  function onFontsChange(obj) {
    let newValue = obj.getValue()
    if (newValue == this.option.value)
      return

    set_option(USEROPT_FONTS_CSS, newValue, this.option)
    this.guiScene.performDelayed(this, @() handlersManager.getActiveBaseHandler().fullReloadScene())
  }

  function goBack() {
    this.markSeen(true)
    base.goBack()
  }
}
register_gui_handler("FontChoiceWnd", FontChoiceWnd)

return { FontChoiceWnd }
