import "%sqstd/ecs.nut" as ecs

let { EventPlayerOwnedUnitChanged, EventPlayerControlledUnitChanged } = require("dasevents")
let { get_local_mplayer } = require("mission")
let {wlog, log} = require("%globalScripts/logs.nut")
let { controlledHeroEid } = require("%appGlobals/controlledHeroEid.nut")

wlog(controlledHeroEid, "controlled: ")












ecs.register_es("controlled_hero_eid_init_es", {
  [["onInit", "onDestroy", "onChange"]] = function(_eid, comp){
    if (get_local_mplayer()?.id == comp.base_player_id)
      controlledHeroEid.set(comp.possessed)
  }
}, {comps_track=[["possessed", ecs.TYPE_EID]], comps_ro=[["base_player_id", ecs.TYPE_INT]]})


ecs.register_es("controlled_hero_eid_es", {
  [[EventPlayerOwnedUnitChanged, EventPlayerControlledUnitChanged]] = function(evt, _eid, _comp){
    if (evt.playerId == get_local_mplayer()?.id) {
      let e = evt.toEid
      log($"controlledHeroEid = {e}")
      controlledHeroEid.set(e)
    }
  }
}, {})

return {
  controlledHeroEid
}