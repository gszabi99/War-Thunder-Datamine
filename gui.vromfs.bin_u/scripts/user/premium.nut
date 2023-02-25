//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let timeBase = require("%scripts/timeLoc.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { register_command } = require("console")

let PREM_TIMER_ID = "timer_premium_update"

let haveProfilePremium = Watched(null)
let forcePremium = Watched(null)

let getTimerUpdateTime = @(expTime) expTime * timeBase.TIME_MINUTE_IN_SECONDS

let function updatePremium() {
  let premAccName = ::shop_get_premium_account_ent_name()
  let premiumExpireTimeMinutes = ::entitlement_expires_in(premAccName)

  haveProfilePremium(premiumExpireTimeMinutes > 0)

  clearTimer(PREM_TIMER_ID)
  if (haveProfilePremium.value)
    setTimeout(getTimerUpdateTime(premiumExpireTimeMinutes), updatePremium, PREM_TIMER_ID)
}

let function resetInfo() {
  haveProfilePremium(null)
  clearTimer(PREM_TIMER_ID)
}

addListenersWithoutEnv({
  ProfileUpdated = @(_) updatePremium()
  SignOut = @(_) resetInfo()
})

register_command(@() forcePremium(true), "premium.forceOn")
register_command(@() forcePremium(false), "premium.forceOff")
register_command(@() forcePremium(null), "premium.forceReset")

return {
  havePremium = Computed(@() forcePremium.value != null
    ? forcePremium.value
    : haveProfilePremium.value
  )
}