import "%sqstd/ecs.nut" as ecs
from "%rGui/globals/ui_library.nut" import *

let { localTeam } = require("%rGui/missionState.nut")





let { watchedTable2TableOfWatched } = require("%sqstd/frp.nut")

let whDefValue = freeze({
  watchedHeroEid = ecs.INVALID_ENTITY_ID
  watchedHeroTeam = 0
})
let whState = mkWatched(persist, "watchedHero", whDefValue)
let whStateSetValue = @(v) whState.set(v)

let { watchedHeroEid, watchedHeroTeam } = watchedTable2TableOfWatched(whState)

let watchedHeroPlayerEid = mkWatched(persist, "watchedHeroPlayerEid", ecs.INVALID_ENTITY_ID)
let watchedHeroPlayerEidSetValue = @(v) watchedHeroPlayerEid.set(v)


let watchedTeam = Computed(@() watchedHeroEid.get() != ecs.INVALID_ENTITY_ID ? watchedHeroTeam.get() : localTeam.get())

ecs.register_es("watched_hero_player_eid_es", {
  [["onInit","onChange"]] = function(_, _eid, comp){
    let w = comp["possessedByPlr"] ?? ecs.INVALID_ENTITY_ID
    watchedHeroPlayerEidSetValue(w)
  }
  onDestroy = @() watchedHeroPlayerEidSetValue(ecs.INVALID_ENTITY_ID)
}, {comps_track=[["possessedByPlr", ecs.TYPE_EID]],comps_rq=[["watchedByPlr", ecs.TYPE_EID]]})


ecs.register_es("watched_hero_eid_es", {
  onInit = function(_, eid, comp) {
    log("watchedHeroEid:" eid)
    whStateSetValue({
      watchedHeroEid = eid
      watchedHeroTeam = comp.team
    })
  }
  onDestroy = function(_, eid, _comp) {
    if (watchedHeroEid.get() == eid)
      whStateSetValue(whDefValue)
  }
}, {comps_rq=[["watchedByPlr", ecs.TYPE_EID]], comps_ro = [["team", ecs.TYPE_INT, 0]]})


return {
  watchedHeroEid,
  watchedHeroPlayerEid,
  watchedTeam
}