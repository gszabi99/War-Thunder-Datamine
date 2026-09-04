import "%appGlobals/timeLoc.nut" as timeBase
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "chard" import getPremiumSavedTimeMinutes
from "dagor.workcycle" import setTimeout, clearTimer
from "console" import register_command
from "%scripts/dagui_natives.nut" import entitlement_expires_in, shop_get_premium_account_ent_name
from "%scripts/dagui_library.nut" import *

let { getExpireText } = require("%scripts/time.nut")


const PREM_TIMER_ID = "timer_premium_update"

let haveProfilePremium = Watched(null)
let forcePremium = Watched(null)

let getTimerUpdateTime = @(expTime) expTime * timeBase.TIME_MINUTE_IN_SECONDS

function getRemainingPremiumTime() {
  let lastSubscription = max(0, entitlement_expires_in(shop_get_premium_account_ent_name()))
  return lastSubscription + getPremiumSavedTimeMinutes()
}

function updatePremium() {
  let premiumExpireTimeMinutes = getRemainingPremiumTime()
  haveProfilePremium.set(premiumExpireTimeMinutes > 0)

  clearTimer(PREM_TIMER_ID)
  if (haveProfilePremium.get())
    setTimeout(getTimerUpdateTime(premiumExpireTimeMinutes), updatePremium, PREM_TIMER_ID)
}

function resetInfo() {
  haveProfilePremium.set(null)
  clearTimer(PREM_TIMER_ID)
}

addListenersWithoutEnv({
  ProfileUpdated = @(_) updatePremium()
  SignOut = @(_) resetInfo()
})

register_command(@() forcePremium.set(true), "premium.forceOn")
register_command(@() forcePremium.set(false), "premium.forceOff")
register_command(@() forcePremium.set(null), "premium.forceReset")

register_command(function() {
  let entName = shop_get_premium_account_ent_name()
  let lastSubscription = max(0, entitlement_expires_in(entName))
  if (entName == "PremiumAccount") {
    log($"subscriptionPremium: 0, normalPremium: { getExpireText(lastSubscription) }")
    return
  }
  log($"subscriptionPremium: { getExpireText(lastSubscription) }, normalPremium: { getExpireText(getPremiumSavedTimeMinutes()) }")
}, "premium.remaining")

return {
  havePremium = Computed(@() forcePremium.get() != null
    ? forcePremium.get()
    : haveProfilePremium.get()
  )

  getRemainingPremiumTime
}