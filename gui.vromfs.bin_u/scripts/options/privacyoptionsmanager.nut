let { havePremium } = require("%scripts/user/premium.nut")

local privacyOptionsList = [
  ::USEROPT_DISPLAY_MY_REAL_NICK,
  ::USEROPT_SHOW_SOCIAL_NOTIFICATIONS,
  ::USEROPT_ALLOW_ADDED_TO_CONTACTS,
  ::USEROPT_ALLOW_ADDED_TO_LEADERBOARDS
]

let function resetPrivacyOptionsToDefault() {
  foreach (optName in privacyOptionsList) {
    let opt = ::get_option(optName)
    ::set_option(opt.type, opt.defVal, opt)
  }
}

havePremium.subscribe(function(val) {
  if (val == false)
    resetPrivacyOptionsToDefault()
})