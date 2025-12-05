require ecs
require %game.events

require %appGame.wt_events

def try_add_aircraft_trouble_score(offender_eid : EntityId; victim_eid : EntityId; score : float)
  var victimTeam = -1
  query(victim_eid) <| $ [es] (team : int)
    victimTeam = team
  var aggressorEid = offender_eid
  var aggressorTeam = -1
  query(offender_eid) <| $ [es] (team : int)
    aggressorTeam = team
  query(offender_eid) <| $ [es] (human_anim__vehicleSelected : EntityId)
    aggressorEid = human_anim__vehicleSelected
  if aggressorTeam < 1
    query(aggressorEid) <| $ [es] (team : int)
      aggressorTeam = team
  if aggressorTeam == victimTeam
    return
  query(aggressorEid) <| $ [es(REQUIRE=airplane)] (var aircraft__troubleScore : float&)
    aircraft__troubleScore += score

[es(tag=server)]
def aircraft_kills_entity_es(evt : EventEntityDied; eid : EntityId)
  try_add_aircraft_trouble_score(evt.offender, eid, 1.0)

[es(tag=server)]
def aircraft_damages_entity_es(evt : EventOnMetaPartDamage; eid : EntityId)
  try_add_aircraft_trouble_score(evt.offender, eid, 0.5)
