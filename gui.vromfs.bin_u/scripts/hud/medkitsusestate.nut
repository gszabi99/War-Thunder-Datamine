import "%sqstd/ecs.nut" as ecs
from "%scripts/dagui_library.nut" import *

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")


let medkitUsageInfo = freeze({
  isMedkitUsing = false
  entityUseTotalTime = 0.0
})
let medkitUsageInfoWatch = Watched(medkitUsageInfo)
medkitUsageInfoWatch.subscribe(@(v) g_hud_event_manager.onHudEvent("selfHealingInProgress", v))

let tourniquetUsageInfo = freeze({
  isTourniquetUsing = false
  entityUseTotalTime = 0.0
})
let tourniquetUsageInfoWatch = Watched(tourniquetUsageInfo)
tourniquetUsageInfoWatch.subscribe(@(v) g_hud_event_manager.onHudEvent("selfTourniquetInProgress", v))

let isTourniquetQuery = ecs.SqQuery("isTourniquetQuery", { comps_rq = ["item__tourniquet"] })

ecs.register_es("medkit_self_usage_track_ui", {
  [["onInit","onChange"]] = function(_eid, comp) {
    if (comp.human_inventory__entityUseEnd == -1.0) {
      medkitUsageInfoWatch.set(medkitUsageInfo)
      tourniquetUsageInfoWatch.set(tourniquetUsageInfo)
      return
    }

    let entityToUse = comp["human_inventory__entityToUse"]
    let isUsing = entityToUse != ecs.INVALID_ENTITY_ID
    let totalTime = comp.human_inventory__entityUseEnd - comp.human_inventory__entityUseStart
    let isTourniquet = isUsing && isTourniquetQuery(entityToUse, @(...) true)

    if (isTourniquet) {
      tourniquetUsageInfoWatch.set({
        isTourniquetUsing = true
        entityUseTotalTime = totalTime
      })
      if (comp["total_kits__selfHeal"] > 0)
        medkitUsageInfoWatch.set({
          isMedkitUsing = true
          entityUseTotalTime = 0.0
        })
    }
    else {
      tourniquetUsageInfoWatch.set(tourniquetUsageInfo)
      medkitUsageInfoWatch.set({
        isMedkitUsing = isUsing
        entityUseTotalTime = totalTime
      })
    }
  },
  onDestroy = function() {
    medkitUsageInfoWatch.set(medkitUsageInfo)
    tourniquetUsageInfoWatch.set(tourniquetUsageInfo)
  }
},
{
  comps_track = [
    ["human_inventory__entityUseStart", ecs.TYPE_FLOAT, -1.0],
    ["human_inventory__entityUseEnd", ecs.TYPE_FLOAT, -1.0],
    ["human_inventory__entityToUse", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID]
  ],
  comps_ro = [
    ["total_kits__selfHeal", ecs.TYPE_INT, 0]
  ],
  comps_rq = [ "watchedByPlr" ]
})