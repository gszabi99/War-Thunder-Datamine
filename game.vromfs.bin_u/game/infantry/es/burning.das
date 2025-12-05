require ecs


[es(tag=server, track=burning__isBurning)]
def burning_affect(evt : Event; eid aka owner_eid : EntityId; burning__isBurning : bool; burning__affectTemplate : string)

  let alreadyApplied = find_query() <| $ [es(REQUIRE=burning_affect)] (eid : EntityId; game_effect__attachedTo : EntityId)
    if game_effect__attachedTo != owner_eid
      return false
    if !burning__isBurning
      destroyEntity(eid)
    return true

  if !alreadyApplied && burning__isBurning
    createEntity(burning__affectTemplate) <| $(var init : ComponentsInitializer)
      set(init, "game_effect__attachedTo", owner_eid)
