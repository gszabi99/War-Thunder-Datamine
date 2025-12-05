require ecs

[es(track=isAlive, on_appear, REQUIRE_NOT=entity__recreateToOnDeath)]
def track_is_alive(evt : Event; eid : EntityId; isAlive : bool)
  if !isAlive
    addSubTemplate(eid, "dead_entity")
  elif has(eid, "deadEntity")
    removeSubTemplate(eid, "dead_entity")