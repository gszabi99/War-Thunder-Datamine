from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "sony.user" import hasPremium, requestPremiumStatusUpdate, reportPremiumFeatureUsage
from "sony.store" import suggest_psplus
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import ps4_is_production_env, periodic_task_register_ex
from "%scripts/dagui_library.nut" import *
from "%globalScripts/playerStateConsts.nut" import *
from "%globalScripts/periodicTaskConsts.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { isPlatformPS5 } = require("%scripts/clientState/platform.nut")
let { isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")
let { getSessionLobbyMyState } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { isPlayerDedicatedSpectator } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")

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
          reportPremiumFeatureUsage(isCrossPlayEnabled(), isPlayerDedicatedSpectator())
      },
      1,
      EPTF_IN_FLIGHT,
      EPTT_SKIP_MISSED,
      true)
}

function enablePremiumFeatureReporting() {
  log("[PLUS] enable multiplayer reporting")
  add_event_listener("LobbyStatusChange", function(_p) {
      if (getSessionLobbyMyState() == PLAYER_IN_FLIGHT) {
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
