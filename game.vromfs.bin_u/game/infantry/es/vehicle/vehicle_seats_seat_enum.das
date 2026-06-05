require ecs
require %appGame.infantry.es.vehicle.vehicle_seats_common
require AnimV20
require DagorSystem

def register_seat_enum(@shared_comp vehicle_seats__seats : Array; seat_id : int; var seat__enumVarId : int&)
  let seat = get_ecs_object(vehicle_seats__seats, seat_id)
  if seat == null
    return
  let seatEnumName = get_ecs_string(seat, "seatEnum")
  if seatEnumName == null
    return
  seat__enumVarId = animV20_add_enum_value(string(*seatEnumName))

[es(tag=render, on_appear)]
def vehicle_seats_enum_init(evt : Event;
                            seat__id : int;
                            seat__vehicleEid : EntityId;
                            var seat__enumVarId : int&)
  query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array)
    register_seat_enum(vehicle_seats__seats, seat__id, seat__enumVarId)

[es(tag=render, on_appear)]
def vehicle_seats_enum_init_from_vehicle(evt : Event; @shared_comp vehicle_seats__seats : Array;
                                         vehicle_seats__seatEids : EidList)
  for i in range(0, length(vehicle_seats__seatEids))
    query(vehicle_seats__seatEids[i]) <| $ [es] (var seat__enumVarId : int&)
      register_seat_enum(vehicle_seats__seats, i, seat__enumVarId)
