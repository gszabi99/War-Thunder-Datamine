import "%sqstd/ecs.nut" as ecs
from "%rGui/globals/ui_library.nut" import *

let plantSites = Watched({})

function mkSiteState(eid, comp) {
  return {
    eid
    pos = ecs.obsolete_dbg_get_comp_val(eid, "transform", null)?.getcol(3)
    iconIdx = comp.plant_site__iconIdx
    isActive = comp.active
    isPlanted = comp.bomb_site__isBombPlanted
    plantingTeam = comp.bomb_site__plantingTeam
    explosionTimeEnd = comp.bomb_site__explosionTimeEnd
    explosionTimerPausedAtTime = comp.bomb_site__explosionTimerPausedAtTime
  }
}

ecs.register_es("plant_site_ui_state_es",
  {
    [["onInit", "onChange"]] = @(_evt, eid, comp) plantSites.mutate(@(v) v[eid] <- mkSiteState(eid, comp))
    onDestroy = @(_evt, eid, _comp) plantSites.mutate(@(v) v.$rawdelete(eid))
  },
  {
    comps_rq = ["plantSite"]
    comps_ro = [
      ["bomb_site__plantingTeam", ecs.TYPE_INT],
    ]
    comps_track = [
      ["plant_site__iconIdx", ecs.TYPE_INT],
      ["active", ecs.TYPE_BOOL],
      ["bomb_site__isBombPlanted", ecs.TYPE_BOOL],
      ["bomb_site__explosionTimeEnd", ecs.TYPE_FLOAT],
      ["bomb_site__explosionTimerPausedAtTime", ecs.TYPE_FLOAT],
    ]
  }
)

let plantSitesList = Computed(function() {
  let list = plantSites.get().values()
  list.sortby(@(a) a.iconIdx)
  return list
})

return freeze({
  plantSites
  plantSitesList
})
