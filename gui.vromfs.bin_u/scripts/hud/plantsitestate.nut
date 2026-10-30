import "%sqstd/ecs.nut" as ecs
from "%scripts/dagui_library.nut" import *
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")


let defPlantSiteInfo = {
  isActive = false
  isDefusing = false
  actionEndTime = -1.0
  actionDuration = 0.0
}

let plantSiteInfo = Watched(defPlantSiteInfo)
plantSiteInfo.subscribe(@(v) g_hud_event_manager.onHudEvent("plantSiteInProgress", v))


ecs.register_es("plant_site_track_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      plantSiteInfo.set({
        isActive = comp.human_plant_site__actionEndTime > 0.0
        isDefusing = comp.human_plant_site__isDefusing
        actionEndTime = comp.human_plant_site__actionEndTime
        actionDuration = comp.human_plant_site__actionDuration
      })
    }
    onDestroy = function() {
      plantSiteInfo.set(defPlantSiteInfo)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_no=["isReplayObserved"]
    comps_ro=[
      ["human_plant_site__isDefusing", ecs.TYPE_BOOL],
      ["human_plant_site__actionDuration", ecs.TYPE_FLOAT]
    ]
    comps_track=[["human_plant_site__actionEndTime", ecs.TYPE_FLOAT]]
  }
)
