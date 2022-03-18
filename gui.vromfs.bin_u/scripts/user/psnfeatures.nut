let { hasPremium, requestPremiumStatusUpdate, reportPremiumFeatureUsage } = require("sony.user")
let { isPlatformPS5 } = require("scripts/clientState/platform.nut")
let { suggest_psplus } = require("sony.store")
let { isCrossPlayEnabled } = require("scripts/social/crossplay.nut")
let { subscribe } = require("eventbus")


subscribe("psPlusSuggested", @(r) requestPremiumStatusUpdate(@(r) null))

let function suggestAndAllowPsnPremiumFeatures() {
  if (isPlatformPS5 && !::ps4_is_production_env() && !hasPremium()) {
    suggest_psplus("psPlusSuggested", {})
    return false
  }
  return true
}

let function startPremiumFeatureReporting() {
  if (hasPremium())
    ::periodic_task_register_ex(
      {},
      function(dt) {
        if (::is_multiplayer())
          reportPremiumFeatureUsage(isCrossPlayEnabled(), ::isPlayerDedicatedSpectator())
      },
      1,
      ::EPTF_IN_FLIGHT,
      ::EPTT_SKIP_MISSED,
      true)
}

let function enablePremiumFeatureReporting() {
  ::dagor.debug("[PLUS] enable multiplayer reporting")
  ::add_event_listener("LobbyStatusChange", function(p) {
      if (::SessionLobby.myState == ::PLAYER_IN_FLIGHT) {
        ::dagor.debug("[PLUS] start reporting")
        startPremiumFeatureReporting()
      }
    })
}

return {
  enablePremiumFeatureReporting
  suggestAndAllowPsnPremiumFeatures
  requestPremiumStatusUpdate
}

