require ecs

[es(tag=server, track=isAlive)]
def vehicle_seat_owner_alive_status_es(evt : Event;
                                       eid : EntityId;
                                       isAlive : bool;
                                       human_vehicle__occupiedSeatEid : EntityId)
  query(human_vehicle__occupiedSeatEid) <| $ [es] (seat__ownerEid : EntityId;
                                                   var seat__isOwnerAlive : bool&)
    if seat__ownerEid == eid && seat__isOwnerAlive != isAlive
      seat__isOwnerAlive = isAlive
