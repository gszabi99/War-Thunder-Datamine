import "%sqstd/ecs.nut" as ecs
from "%scripts/dagui_library.nut" import *
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")

let defReanimationInfo = {
  isReanimationInProgress = false
  reanimationTimeTotal = 0.0
}

let defReanimationDeclineInfo = {
  isDeclineInProgress = false
  declineTimeTotal = 0.0
}

let defDeathInInfo = {
  isKnockedDown = false
  deathTimeTotal = 0.0
}

let reanimationInfo = Watched(defReanimationInfo)
let reanimationDeclineInfo = Watched(defReanimationDeclineInfo)
let deathInfo = Watched(defDeathInInfo)

reanimationInfo.subscribe(@(v) g_hud_event_manager.onHudEvent("reanimationInProgress", v))
reanimationDeclineInfo.subscribe(@(v) g_hud_event_manager.onHudEvent("reanimationDeclineInProgress", v))
deathInfo.subscribe(@(v) g_hud_event_manager.onHudEvent("deathInProgress", v))

ecs.register_es("reanimation_track_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      reanimationInfo.set({
        isReanimationInProgress = comp.human_reanimator__reanimationStartTime > 0.0
        reanimationTimeTotal = comp.human_reanimator__reanimationDuration
      })
    }
    onDestroy = function() {
      reanimationInfo.set(defReanimationInfo)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_ro=[["human_reanimator__reanimationDuration", ecs.TYPE_FLOAT]]
    comps_track=[["human_reanimator__reanimationStartTime", ecs.TYPE_FLOAT]]
  }
)

ecs.register_es("reanimation_decline_track_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      reanimationDeclineInfo.set({
        isDeclineInProgress = comp.reanimation__declineTime > 0.0
        declineTimeTotal = comp.reanimation__declineHoldDuration
      })
    }
    onDestroy = function() {
      reanimationDeclineInfo.set(defReanimationDeclineInfo)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_ro=[["reanimation__declineHoldDuration", ecs.TYPE_FLOAT]]
    comps_track=[["reanimation__declineTime", ecs.TYPE_FLOAT]]
  }
)

ecs.register_es("reanimation_death_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      deathInfo.set({
        isKnockedDown = comp.reanimation__knockedDown
        deathTimeTotal = comp.reanimation__deathTimeout
      })
    }
    onDestroy = function() {
      deathInfo.set(defDeathInInfo)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_ro=[["reanimation__deathTimeout", ecs.TYPE_FLOAT]]
    comps_track=[["reanimation__knockedDown", ecs.TYPE_BOOL]]
  }
)