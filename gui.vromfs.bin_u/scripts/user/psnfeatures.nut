from "%scripts/dagui_natives.nut" import ps4_is_production_env, periodic_task_register_ex
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { hasPremium, requestPremiumStatusUpdate, reportPremiumFeatureUsage } = require("sony.user")
let { isPlatformPS5 } = require("%scripts/clientState/platform.nut")
let { suggest_psplus } = require("sony.store")
let { isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")
let { eventbus_subscribe } = require("eventbus")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")


eventbus_subscribe("psPlusSuggested", @(_r) requestPremiumStatusUpdate(@(_r) null))

function suggestAndAllowPsnPremiumFeatures() {
  if (isPlatformPS5 && !ps4_is_production_env() && !hasPremium()) {
    suggest_psplus("psPlusSuggested", {})
    return false
  }
  return true
}

function startPremiumFeatureReporting() {
  if (hasPremium())
    periodic_task_register_ex(
      {},
      function(_dt) {
        if (is_multiplayer())
          reportPremiumFeatureUsage(isCrossPlayEnabled(), ::isPlayerDedicatedSpectator())
      },
      1,
      EPTF_IN_FLIGHT,
      EPTT_SKIP_MISSED,
      true)
}

function enablePremiumFeatureReporting() {
  log("[PLUS] enable multiplayer reporting")
  add_event_listener("LobbyStatusChange", function(_p) {
      if (::SessionLobby.getMyState() == PLAYER_IN_FLIGHT) {
        log("[PLUS] start reporting")
        startPremiumFeatureReporting()
      }
    })
}

return {
  enablePremiumFeatureReporting
  suggestAndAllowPsnPremiumFeatures
  requestPremiumStatusUpdate
}

