import "%sqstd/ecs.nut" as ecs
from "%globalScripts/logs.nut" import wlog, log
from "%appGlobals/controlledHeroEid.nut" import controlledHeroEid
from "dasevents" import EventPlayerOwnedUnitChanged, EventPlayerControlledUnitChanged
from "mission" import get_local_mplayer

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