//checked for plus_string
from "%scripts/dagui_library.nut" import *


let FONT_CHOICE_SAVE_ID = "tutor/fontChange"
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { set_option } = require("%scripts/options/optionsExt.nut")
let { USEROPT_FONTS_CSS } = require("%scripts/options/optionsExtNames.nut")

local wasOpened = false

gui_handlers.FontChoiceWnd <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/options/fontChoiceWnd.tpl"

  option = null

  static function openIfRequired() {
    if (!gui_handlers.FontChoiceWnd.isSeen() && ::g_font.getAvailableFonts().len() > 1)
      handlersManager.loadHandler(gui_handlers.FontChoiceWnd)
  }

  static function isSeen() {
    return ::load_local_account_settings(FONT_CHOICE_SAVE_ID, false)
  }

  static function markSeen(isMarkSeen = true) {
    return ::save_local_account_settings(FONT_CHOICE_SAVE_ID, isMarkSeen)
  }

  function getSceneTplView() {
    this.option = ::get_option(USEROPT_FONTS_CSS)
    return {
      options = ::create_option_combobox(this.option.id, this.option.items, this.option.value, null, false)
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