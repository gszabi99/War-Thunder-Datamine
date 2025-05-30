from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType

let { havePremium } = require("%scripts/user/premium.nut")
let { set_option, get_option, registerOption } = require("%scripts/options/optionsExt.nut")
let { USEROPT_DISPLAY_MY_REAL_NICK, OPTIONS_MODE_GAMEPLAY
} = require("%scripts/options/optionsExtNames.nut")
let { get_gui_option_in_mode, set_gui_option_in_mode } = require("%scripts/options/options.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")

local privacyOptionsList = [
  USEROPT_DISPLAY_MY_REAL_NICK
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

function setUseroptDisplayMyRealNick(value, _descr, optionId) {
  set_gui_option_in_mode(optionId, value, OPTIONS_MODE_GAMEPLAY)
  updateGamercards()
}

registerOption(USEROPT_DISPLAY_MY_REAL_NICK, fillUseroptDisplayMyRealNick,
  setUseroptDisplayMyRealNick)
