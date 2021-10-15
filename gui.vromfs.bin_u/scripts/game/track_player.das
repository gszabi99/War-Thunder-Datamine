require ecs

[es (track=playerNo, on_event=(EventEntityCreated, EventComponentsAppear))]
def track_players_es(evt: Event; eid: EntityId; playerNo: int)
  if playerNo >= 0 && !has(eid, "playerUnit")
    addSubTemplate(eid, "player_unit")
  elif playerNo < 0 && has(eid, "playerUnit")
    removeSubTemplate(eid, "player_unit")
