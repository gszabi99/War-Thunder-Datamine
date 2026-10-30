require ecs

[es(track=isAlive, on_appear)]
def track_is_alive(evt : Event;
                   eid : EntityId;
                   isAlive : bool;
                   reanimation__available : bool = false;
                   entity__deadSubTemplate : string = "dead_entity")
  if !isAlive
    if has(eid, "entity__recreateToOnDeath") && !reanimation__available
      return
    addSubTemplate(eid, entity__deadSubTemplate)
  elif has(eid, "deadEntity")
    removeSubTemplate(eid, entity__deadSubTemplate)
