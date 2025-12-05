require ecs

require %appGame.wt_events


[es(REQUIRE=locked_inventory__lockPickup)]
def locked_pick_up_items_es(evt : GameEffectStateChanged; eid : EntityId)
  let excludeEid = eid
  query(evt.attachedTo) <| $ [es] (var locked__pickupItemsLockedByAffect : bool&)
    var lock = evt.activated
    lock ||= find_query() <| $ [es(REQUIRE=locked_inventory__lockPickup)] (eid, game_effect__attachedTo : EntityId)
      return eid != excludeEid && game_effect__attachedTo == evt.attachedTo
    locked__pickupItemsLockedByAffect = lock
