import "%sqstd/ecs.nut" as ecs
from "%scripts/dagui_library.nut" import *

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")

let def = freeze({
  isPuttingOut = false
  firePutOutFullTime = 0.0
  firePutOutElapsedTime = 0.0
})
let fireUsageInfoWatch = Watched(def)
fireUsageInfoWatch.subscribe(@(v) g_hud_event_manager.onHudEvent("firePutOutInProgress", v))

ecs.register_es("fire_put_out_track_ui", {
  [["onInit","onChange"]] = function(_eid, comp) {
    if (!comp.burning__isPuttingOut || comp.burning__force  <= 0.0 || comp.burning__maxForce <= 0.0) {
     fireUsageInfoWatch.set(def)
     return
    }
    let fullTime = comp.burning__maxForce / comp.burning__putOutForce
    fireUsageInfoWatch.set({
      isPuttingOut = comp.burning__isPuttingOut
      firePutOutFullTime = fullTime
      firePutOutElapsedTime = fullTime - comp.burning__force / comp.burning__putOutForce
    })
  },
  onDestroy = @() fireUsageInfoWatch.set(def)
},
{
  comps_track = [
    ["burning__isPuttingOut",  ecs.TYPE_BOOL]
  ]
  comps_ro = [
      ["burning__force", ecs.TYPE_FLOAT],
      ["burning__putOutForce", ecs.TYPE_FLOAT],
      ["burning__maxForce", ecs.TYPE_FLOAT],
    ]
  comps_rq = ["hero"]
  comps_no = ["deadEntity"]
})
