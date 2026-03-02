require ecs

[es(track=isAlive, on_appear)]
def track_is_alive(evt : Event;
                   eid : EntityId;
                   isAlive : bool;
                   reanimation__available : bool = false)
  if !isAlive
    if has(eid, "entity__recreateToOnDeath") && !reanimation__available
      return
    addSubTemplate(eid, "dead_entity")
  elif has(eid, "deadEntity")
    removeSubTemplate(eid, "dead_entity")
