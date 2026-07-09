require ecs
require app
require %appGame.infantry.es.vehicle.vehicle_events

[es(tag=server, track=isAlive)]
def vehicle_seat_owner_alive_status_es(evt : Event;
                                       eid : EntityId;
                                       isAlive : bool;
                                       human_vehicle__occupiedSeatEid : EntityId)
  query(human_vehicle__occupiedSeatEid) <| $ [es] (seat__ownerEid : EntityId;
                                                   var seat__isOwnerAlive : bool&)
    if seat__ownerEid == eid && seat__isOwnerAlive != isAlive
      seat__isOwnerAlive = isAlive


[es(tag=server, on_disappear)]
def vehicle_seat_owner_disappear_es(evt : Event;
                                    eid : EntityId;
                                    human_vehicle__occupiedSeatEid : EntityId)
  query(human_vehicle__occupiedSeatEid) <| $ [es] (var seat__ownerEid : EntityId&;
                                                   var seat__playerEid : EntityId&;
                                                   var seat__squadEid : EntityId&;
                                                   var seat__isPlayer : bool&;
                                                   var seat__isOwnerAlive : bool&)
    if seat__ownerEid != eid
      return
    seat__ownerEid = INVALID_ENTITY_ID
    seat__playerEid = INVALID_ENTITY_ID
    seat__squadEid = INVALID_ENTITY_ID
    seat__isPlayer = false
    seat__isOwnerAlive = false


[es(tag=server, track=isAlive)]
def vehicle_seat_owner_kick_on_death_es(evt : Event;
                                        eid : EntityId;
                                        isAlive : bool;
                                        human_anim__vehicleSelected : EntityId;
                                        human_vehicle__occupiedSeatEid : EntityId)
  if isAlive || human_vehicle__occupiedSeatEid == INVALID_ENTITY_ID || human_anim__vehicleSelected == INVALID_ENTITY_ID
    return
  sendEvent(human_anim__vehicleSelected, CmdKickFromVehicle(eid = eid))
