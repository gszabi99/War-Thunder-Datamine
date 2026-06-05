require ecs
require ecs.common
require vehicle
require PhysVars
require %appGame.infantry.es.hero_common
require %appGame.infantry.es.vehicle.vehicle_seats_common
require ecs.safe

[es(on_appear)]
def vehicle_seats_hide_owner_init_es(evt : Event;
                                     @shared_comp vehicle_seats__seats : Array;
                                     var vehicle_seats_hide_owner : BoolList)
  let seatsCount = length(vehicle_seats__seats)
  resize(vehicle_seats_hide_owner, seatsCount)
  for seatNo in range(0, seatsCount)
    let seat = get_ecs_object(vehicle_seats__seats[seatNo])
    vehicle_seats_hide_owner[seatNo] = get_bool(seat, "shouldHideOwner") ?? false


[es(no_order, tag=server, REQUIRE=isInVehicle)]
def vehicle_seats_hide_owners_es(info : UpdateStageInfoAct;
                                 eid : EntityId;
                                 human_anim__vehicleSelected : EntityId;
                                 var isInVehicleHidden : bool&)
  ecs::query(human_anim__vehicleSelected) <| $ [es] (vehicle_seats__seatEids : EidList; vehicle_seats_hide_owner : BoolList)
    let seatNo = find_seat_with_owner(eid, vehicle_seats__seatEids)
    if seatNo < 0
      return

    query(vehicle_seats__seatEids[seatNo]) <| $ [es] (seats_hatch_nodes__isValid : bool = false; seats_hatch_nodes__openPos : float = 0.f; seat__isPlayer : bool = false)
      let hasHatch = seats_hatch_nodes__isValid
      let isHatchClosed = hasHatch && seats_hatch_nodes__openPos <= 0.f
      let isPlayer = seat__isPlayer
      let canHide = !isPlayer || !hasHatch || isHatchClosed
      isInVehicleHidden = canHide && vehicle_seats_hide_owner[seatNo]


















[es(tag=render, REQUIRE=hero, on_disappear)]
def vehicle_seats_show_owners_local_on_disapper(evt : Event; var isInVehicleHiddenLocal : bool&)
  isInVehicleHiddenLocal = false
