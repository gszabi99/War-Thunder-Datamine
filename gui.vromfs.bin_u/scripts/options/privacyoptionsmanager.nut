from "%scripts/user/premium.nut" import havePremium
from "%scripts/options/optionsExt.nut" import set_option, get_option, registerOption
from "%scripts/options/optionsExtNames.nut" import USEROPT_DISPLAY_MY_REAL_NICK, OPTIONS_MODE_GAMEPLAY, USEROPT_DISPLAY_MY_REAL_CLAN
from "%scripts/options/options.nut" import get_gui_option_in_mode, set_gui_option_in_mode
from "%scripts/gamercard/gamercard.nut" import updateGamercards
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType

local privacyOptionsList = [
  USEROPT_DISPLAY_MY_REAL_NICK
  USEROPT_DISPLAY_MY_REAL_CLAN
]

function resetPrivacyOptionsToDefault() {
  foreach (optName in privacyOptionsList) {
    let opt = get_option(optName)
    set_option(opt.type, opt.defVal, opt)
  }
}

havePremium.subscribe(function(val) {
  if (val == false)
    resetPrivacyOptionsToDefault()
})

function fillUseroptDisplayMyRealNick(optionId, descr, _context) {
  descr.id = "display_my_real_nick"
  descr.controlType = optionControlType.CHECKBOX
  descr.controlName <- "switchbox"
  descr.value = get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY, true)
  descr.defaultValue = true
  descr.defVal <- descr.defaultValue
  descr.optionCb <- "onChangeDisplayRealNick"
  if (!havePremium.get()) {
    descr.hint = "".concat(
      loc("guiHints/display_my_real_nick"),
      "\n",
      colorize("warningTextColor", loc("mainmenu/onlyWithPremium"))
    )
    descr.trParams <- "disabledColor:t='yes';"
  }
}

function fillUseroptDisplayMyRealClan(optionId, descr, _context) {
  descr.id = "display_my_real_clan"
  descr.controlType = optionControlType.CHECKBOX
  descr.controlName <- "switchbox"
  descr.value = get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY, true)
  descr.defaultValue = true
  descr.defVal <- descr.defaultValue
  descr.optionCb <- "onChangeDisplayRealClan"
  if (!havePremium.get()) {
    descr.hint = "".concat(
      loc("guiHints/display_my_real_clan"),
      "\n",
      colorize("warningTextColor", loc("mainmenu/onlyWithPremium"))
    )
    descr.trParams <- "disabledColor:t='yes';"
  }
}

function setUseroptDisplayMyRealNick(value, _descr, optionId) {
  set_gui_option_in_mode(optionId, value, OPTIONS_MODE_GAMEPLAY)
  updateGamercards()
}

function setUseroptDisplayMyRealClan(value, _descr, optionId) {
  set_gui_option_in_mode(optionId, value, OPTIONS_MODE_GAMEPLAY)
  updateGamercards()
}

registerOption(USEROPT_DISPLAY_MY_REAL_NICK, fillUseroptDisplayMyRealNick,
  setUseroptDisplayMyRealNick)

registerOption(USEROPT_DISPLAY_MY_REAL_CLAN, fillUseroptDisplayMyRealClan,
  setUseroptDisplayMyRealClan)
