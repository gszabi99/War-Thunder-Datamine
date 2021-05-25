local { hasPremium, requestPremiumStatusUpdate, reportPremiumFeatureUsage } = require("sony.user")
local { isPlatformPS5 } = require("scripts/clientState/platform.nut")
local { suggest_psplus } = require("sony.store")
local { isCrossPlayEnabled } = require("scripts/social/crossplay.nut")

local function suggestAndAllowPsnPremiumFeatures() {
  if (isPlatformPS5 && !::ps4_is_production_env() && !hasPremium()) {
    suggest_psplus(@(r) requestPremiumStatusUpdate(@(r) null))
    return false
  }
  return true
}

local function startPremiumFeatureReporting() {
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

local function enablePremiumFeatureReporting() {
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

