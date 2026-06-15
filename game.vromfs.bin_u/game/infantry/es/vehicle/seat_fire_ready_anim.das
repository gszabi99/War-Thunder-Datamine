require ecs
require ecs.common
require DagorSystem
require AnimV20
require %appGame.infantry.es.vehicle.vehicle_seats_common

def private set_seat_owner_anim_state(seatEid)
  query(seatEid) <| $ [es] (seat__ownerEid : EntityId;
                            seat_anim__fireReadyUpper : string;
                            seat_anim__fireReadyLower : string)
    query(seat__ownerEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                     var human_vehicle_anim__fireReadyUpperId : int&;
                                     var human_vehicle_anim__fireReadyLowerId : int&)
      let animGraph = animchar.animGraph
      if animGraph == null
        return
      human_vehicle_anim__fireReadyUpperId = *animGraph |> anim_graph_getStateIdx(seat_anim__fireReadyUpper)
      human_vehicle_anim__fireReadyLowerId = *animGraph |> anim_graph_getStateIdx(seat_anim__fireReadyLower)

      if human_vehicle_anim__fireReadyUpperId < 0
        logerr("Anim state '{seat_anim__fireReadyUpper}' not found in '{getEntityTemplateName(seat__ownerEid)}'")
      if human_vehicle_anim__fireReadyLowerId < 0
        logerr("Anim state '{seat_anim__fireReadyLower}' not found in '{getEntityTemplateName(seat__ownerEid)}'")

[es(tag=server, on_appear)]
def seat_fire_ready_anim_init_es(evt : Event;
                                 seat__id : int;
                                 seat__vehicleEid : EntityId;
                                 var seat_anim__fireReadyUpper : das_string;
                                 var seat_anim__fireReadyLower : das_string)
  query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array)
    let seat = get_ecs_object(vehicle_seats__seats[seat__id])
    if seat != null
      let defUpper = string(seat_anim__fireReadyUpper)
      let defLower = string(seat_anim__fireReadyLower)
      seat_anim__fireReadyUpper := get_string(seat, "seatFireReadyAnimUpper", defUpper)
      seat_anim__fireReadyLower := get_string(seat, "seatFireReadyAnimLower", defLower)

[es(tag=render, track=seat__ownerEid, REQUIRE=seat__ownerEid, on_appear)]
def seat_human_fire_ready_anim_init_es(evt : Event; eid : EntityId)
  set_seat_owner_anim_state(eid)

[es(tag=render, track=human_anim__vehicleSelected, on_appear)]
def human_fire_ready_seat_anim_init_es(evt : Event;
                                       eid : EntityId;
                                       human_anim__vehicleSelected : EntityId)
  query(human_anim__vehicleSelected) <| $ [es] (vehicle_seats__seatEids : EidList)
    let seatEid = find_seat_eid_with_owner(eid, vehicle_seats__seatEids)
    set_seat_owner_anim_state(seatEid)

[es(tag=render, on_appear)]
def vehicle_seat_owners_fire_ready_anim_init_es(evt : Event; vehicle_seats__seatEids : EidList)
  for seatEid in vehicle_seats__seatEids
    set_seat_owner_anim_state(seatEid)
