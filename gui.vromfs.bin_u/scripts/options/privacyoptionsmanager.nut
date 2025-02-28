from "%scripts/dagui_library.nut" import *

let { havePremium } = require("%scripts/user/premium.nut")
let { set_option, get_option } = require("%scripts/options/optionsExt.nut")
let { USEROPT_DISPLAY_MY_REAL_NICK
} = require("%scripts/options/optionsExtNames.nut")

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