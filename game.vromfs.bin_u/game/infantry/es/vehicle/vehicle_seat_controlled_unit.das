require ecs
require ecs.common
require DagorSystem
require Unit
require MPlayer
require %game.player_events
require %appGame.infantry.es.vehicle.vehicle_seats_common



[es(tag=server, on_appear)]
def init_seat_owns_entity_control_es(evt : Event;
                                     seat__id : int;
                                     seat__vehicleEid : EntityId;
                                     var seatOwnsEntityControl : bool&)
  query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array)
    let seat = get_ecs_object(vehicle_seats__seats, seat__id)
    if seat == null
      return
    seatOwnsEntityControl = get_bool(*seat, "seatOwnsEntityControl") ?? false






[es(tag=server, track=human_vehicle__occupiedSeatEid)]
def seat_player_controlled_unit_switch_es(evt : Event;
                                          human_vehicle__occupiedSeatEid : EntityId;
                                          possessedByPlr : EntityId;
                                          human_anim__vehicleSelected : EntityId)
  if possessedByPlr == INVALID_ENTITY_ID
    return
  if human_vehicle__occupiedSeatEid == INVALID_ENTITY_ID || human_anim__vehicleSelected == INVALID_ENTITY_ID
    return
  let ownsControl = get_bool(human_vehicle__occupiedSeatEid, "seatOwnsEntityControl") ?? false
  if !ownsControl
    return
  sendEventImmediate(possessedByPlr, CmdPlayerSetControlledUnit(toEid = human_anim__vehicleSelected))

[es(tag=server, track=human_vehicle__occupiedSeatEid)]
def seat_player_relinquish_vehicle_control_es(evt : Event;
                                              eid : EntityId;
                                              human_vehicle__occupiedSeatEid : EntityId;
                                              human_anim__vehicleSelected : EntityId)
  if human_vehicle__occupiedSeatEid == INVALID_ENTITY_ID || human_anim__vehicleSelected == INVALID_ENTITY_ID
    return
  let ownsControl = get_bool(human_vehicle__occupiedSeatEid, "seatOwnsEntityControl") ?? false
  if ownsControl
    return
  let playerEid = get_Eid(human_vehicle__occupiedSeatEid, "seat__playerEid") ?? INVALID_ENTITY_ID
  if playerEid == INVALID_ENTITY_ID
    return
  var player = player_get_by_eid(playerEid)
  if player == null
    return
  let controlledUnit = getControlledUnit(*player)
  if controlledUnit == null || controlledUnit.eid != human_anim__vehicleSelected
    return
  sendEventImmediate(playerEid, CmdPlayerSetControlledUnit(toEid = eid))

[es(tag=server, track=seat__ownerEid, REQUIRE=seatOwnsEntityControl)]
def driver_seat_owner_track_es(evt : Event;
                               seat__vehicleEid : EntityId;
                               seat__ownerEid : EntityId;
                               seat__playerEid : EntityId;
                               seatOwnsEntityControl : bool)
  if !seatOwnsEntityControl
    return
  query(seat__vehicleEid) <| $ [es] (var vehicle__controlledByDriver : EntityId&;
                                     var vehicle__controlledByPlayer : EntityId&)
    vehicle__controlledByDriver = seat__ownerEid
    vehicle__controlledByPlayer = seat__playerEid

[es(tag=server, track=vehicle__controlledByDriver)]
def vehicle_reset_army_on_driver_left_es(evt : Event;
                                         var unit__ref : UnitRef&;
                                         vehicle__controlledByDriver : EntityId)
  if vehicle__controlledByDriver != INVALID_ENTITY_ID
    return
  if unit__ref.unit == null || unit__ref.unit.isDelayed
    return
  let neutralArmy = int(MultiplayerTeam.MP_TEAM_NEUTRAL)
  if unit__ref.unit.army == neutralArmy
    return
  *unit__ref.unit |> setArmy(neutralArmy)

[es(on_appear, track=human_anim__vehicleSelected)]
def human_relative_unit_track_es(evt : Event;
                                 eid : EntityId;
                                 human_anim__vehicleSelected : EntityId)
  unit_set_relative(eid, human_anim__vehicleSelected)

[es(on_appear, track=vehicle__controlledByDriver)]
def vehicle_relative_unit_track_es(evt : Event;
                                   eid : EntityId;
                                   vehicle__controlledByDriver : EntityId)
  unit_set_relative(eid, vehicle__controlledByDriver)

[es(on_appear, track=(human_vehicle__occupiedSeatEid, human_anim__vehicleSelected))]
def human_vehicle_inside_covered_track_es(evt : Event;
                                          human_anim__vehicleSelected : EntityId;
                                          human_vehicle__occupiedSeatEid : EntityId;
                                          var human_vehicle__isInsideCovered : bool&)
  var covered = false
  if human_vehicle__occupiedSeatEid != INVALID_ENTITY_ID
    query(human_anim__vehicleSelected) <| $ [es] (@shared_comp vehicle_seats__seats : Array;
                                                  vehicle_seats__seatEids : EidList)
      for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
        if seatEid == human_vehicle__occupiedSeatEid
          let seat = get_ecs_object(vehicle_seats__seats, seatNo)
          if seat != null
            covered = !(get_bool(*seat, "seatIsUncovered") ?? false)
          break
  human_vehicle__isInsideCovered = covered

