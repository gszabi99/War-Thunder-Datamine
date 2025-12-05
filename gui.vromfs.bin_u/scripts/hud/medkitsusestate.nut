import "%sqstd/ecs.nut" as ecs
from "%scripts/dagui_library.nut" import *

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")


let medkitUsageInfo = freeze({
  isMedkitUsing = false
  entityUseTotalTime = 0.0
})
let medkitUsageInfoWatch = Watched(medkitUsageInfo)
medkitUsageInfoWatch.subscribe(@(v) g_hud_event_manager.onHudEvent("selfHealingInProgress", v))


ecs.register_es("medkit_self_usage_track_ui", {
  [["onInit","onChange"]] = function(_eid, comp) {
    if (comp.human_inventory__entityUseEnd == -1.0) {
      medkitUsageInfoWatch.set(medkitUsageInfo)
      return
    }

    medkitUsageInfoWatch.set({
      isMedkitUsing = comp["human_inventory__entityToUse"] != ecs.INVALID_ENTITY_ID
      entityUseTotalTime = comp.human_inventory__entityUseEnd - comp.human_inventory__entityUseStart
    })
  },
  onDestroy = @() medkitUsageInfoWatch.set(medkitUsageInfo)
},
{
  comps_track = [
    ["human_inventory__entityUseStart", ecs.TYPE_FLOAT, -1.0],
    ["human_inventory__entityUseEnd", ecs.TYPE_FLOAT, -1.0],
    ["human_inventory__entityToUse", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID]
  ],
  comps_rq = [ "watchedByPlr" ]
})