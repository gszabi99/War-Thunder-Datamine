from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/options/optionsExt.nut" import set_option, get_option
from "%scripts/options/optionsExtNames.nut" import USEROPT_FONTS_CSS
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_combobox
from "%scripts/options/fonts.nut" import getAvailableFonts

const FONT_CHOICE_SAVE_ID = "tutor/fontChange"
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

local wasOpened = false

let FontChoiceWnd = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/options/fontChoiceWnd.tpl"

  option = null

  static function openIfRequired() {
    if (!get_gui_handler("FontChoiceWnd").isSeen() && getAvailableFonts().len() > 1)
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

return freeze({ FontChoiceWnd })
