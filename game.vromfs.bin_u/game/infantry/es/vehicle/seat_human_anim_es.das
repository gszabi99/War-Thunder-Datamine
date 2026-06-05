require ecs
require ecs.common
require DagorSystem
require AnimV20
require %appGame.infantry.es.vehicle.vehicle_seats_common


def set_seat_owner_anim_state(seatEid)
  query(seatEid) <| $ [es] (seat__ownerEid : EntityId;
                            seat_anim__upper : string;
                            seat_anim__lower : string;
                            seat_anim__maxStandHeight : float = 1.)
    query(seat__ownerEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                     var human_vehicle_anim__maxStandHeight : float&;
                                     var human_vehicle_anim__upperId : int&;
                                     var human_vehicle_anim__lowerId : int&)
      let animGraph = animchar.animGraph
      if animGraph == null
        return
      human_vehicle_anim__upperId = *animGraph |> anim_graph_getStateIdx(seat_anim__upper)
      human_vehicle_anim__lowerId = *animGraph |> anim_graph_getStateIdx(seat_anim__lower)
      human_vehicle_anim__maxStandHeight = seat_anim__maxStandHeight

      if human_vehicle_anim__upperId < 0
        logerr("Anim state '{seat_anim__upper}' not found in '{getEntityTemplateName(seat__ownerEid)}'")
      if human_vehicle_anim__lowerId < 0
        logerr("Anim state '{seat_anim__lower}' not found in '{getEntityTemplateName(seat__ownerEid)}'")

[es(tag=server, on_appear)]
def seat_anim_init_es(evt : Event;
                      seat__id : int;
                      seat__vehicleEid : EntityId;
                      var seat_anim__upper : das_string;
                      var seat_anim__lower : das_string)
  query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array)
    let seat = get_ecs_object(vehicle_seats__seats[seat__id])
    if seat != null
      let defUpper = string(seat_anim__upper)
      let defLower = string(seat_anim__lower)
      seat_anim__upper := get_string(seat, "seatAnimUpper", defUpper)
      seat_anim__lower := get_string(seat, "seatAnimLower", defLower)


[es(track=(seat__ownerEid, seat_anim__upper, seat_anim__lower), REQUIRE=(seat__ownerEid, seat_anim__upper, seat_anim__lower), on_appear)]
def seat_human_anim_init_es(evt : Event; eid : EntityId)
  set_seat_owner_anim_state(eid)


[es(track=human_anim__vehicleSelected, on_appear)]
def human_seat_anim_init_es(evt : Event;
                            eid : EntityId;
                            human_anim__vehicleSelected : EntityId)
  query(human_anim__vehicleSelected) <| $ [es] (vehicle_seats__seatEids : EidList)
    let seatEid = find_seat_eid_with_owner(eid, vehicle_seats__seatEids)
    set_seat_owner_anim_state(seatEid)


[es(on_appear)]
def vehicle_seat_owners_anim_init_es(evt : Event; vehicle_seats__seatEids : EidList)
  for seatEid in vehicle_seats__seatEids
    set_seat_owner_anim_state(seatEid)
