require ecs
require app
require net
require %appGame.infantry.es.vehicle.vehicle_events
require %appGame.infantry.es.vehicle.vehicle_seats_common


[es(tag=server, REQUIRE=vehicle_seats__seats)]
def vehicle_seats_switch_seat_request(evt : RequestVehicleChangeSeat;
                                      eid : EntityId;
                                      vehicle_seats__changeSeatCooldown : float;
                                      var vehicle_seats__changeSeatCooldownUntilTime : float&)
  if get_sync_time() < vehicle_seats__changeSeatCooldownUntilTime
    return
  vehicle_seats__changeSeatCooldownUntilTime = get_sync_time() + vehicle_seats__changeSeatCooldown
  sendEvent(eid, CmdVehicleChangeSeat(eid = evt.eid, seat = evt.seat))

def start_seat_timer(sitter_eid : EntityId;
                     cur_seat_no : int;
                     new_seat_no : int;
                     vehicle_seats__seatEids : EidList;
                     vehicle_seats_switch_time__totalSwitchTime : float)
  if new_seat_no < 0 || new_seat_no == cur_seat_no
    return
  query(vehicle_seats__seatEids[cur_seat_no]) <| $ [es] (var seats_switch_time__time : float&; var seats_switch_time__newSeatNo : int&)
    if seats_switch_time__time > 0.f
      return
    let switchMult = get_float(sitter_eid, "entity_mods__vehicleChangeSeatTimeMult") ?? 1.0
    let switchTime = vehicle_seats_switch_time__totalSwitchTime * switchMult
    seats_switch_time__time = switchTime
    seats_switch_time__newSeatNo = new_seat_no

[es(tag=server)]
def vehicle_seats_switch_seat(evt : CmdVehicleChangeSeat;
                              vehicle_seats__seatEids : EidList;
                              vehicle_seats_switch_time__totalSwitchTime : float)
  let sitterEid = evt.eid
  let newSeatNo = evt.seat
  if newSeatNo < 0
    return
  let curSeatNo = find_seat_with_owner(sitterEid, vehicle_seats__seatEids)
  if curSeatNo < 0
    return
  start_seat_timer(sitterEid, curSeatNo, newSeatNo, vehicle_seats__seatEids, vehicle_seats_switch_time__totalSwitchTime)

def request_seat_switch(sitter_eid : EntityId;
                        seat_order_no : int;
                        vehicle_seats__seatEids : EidList;
                        vehicle_seats_switch_time__totalSwitchTime : float) : bool
  var requested = false
  if seat_order_no < 0 || length(vehicle_seats__seatEids) <= seat_order_no || !(get_bool(vehicle_seats__seatEids[seat_order_no], "seats_order__canPlaceManually") ?? false)
    return requested
  if !can_enter_seat_with_only_owner_access(vehicle_seats__seatEids[seat_order_no], sitter_eid)
    return requested
  let newSeatNo = get_int(vehicle_seats__seatEids[seat_order_no], "seats_order__seatNo") ?? -1
  if newSeatNo < 0
    return requested
  let curSeatNo = find_seat_with_owner(sitter_eid, vehicle_seats__seatEids)
  if curSeatNo < 0
    return requested
  start_seat_timer(sitter_eid, curSeatNo, newSeatNo, vehicle_seats__seatEids, vehicle_seats_switch_time__totalSwitchTime)
  requested = true
  return requested

def can_change_seat_to(sitter_eid : EntityId;
                       seat_order_no : int;
                       vehicle_seats__seatEids : EidList;
                       can_replace_own_bots : bool;
                       can_replace_bots : bool;
                       can_replace_group_bots : bool;
                       vehicle_seats__changeSeatCooldownUntilTime : float) : bool
  var canChange = false
  if get_sync_time() < vehicle_seats__changeSeatCooldownUntilTime
    return canChange
  if seat_order_no < 0 || seat_order_no >= length(vehicle_seats__seatEids)
    return canChange
  let canPlaceManually = get_bool(vehicle_seats__seatEids[seat_order_no], "seats_order__canPlaceManually") ?? false
  if !canPlaceManually
    return canChange
  if !can_enter_seat_with_only_owner_access(vehicle_seats__seatEids[seat_order_no], sitter_eid)
    return canChange
  let seatNo = get_int(vehicle_seats__seatEids[seat_order_no], "seats_order__seatNo") ?? -1
  let seatEid = vehicle_seats__seatEids[seatNo]
  query(seatEid) <| $ [es] (seat__ownerEid : EntityId = INVALID_ENTITY_ID;
                            seat__isPlayer : bool = false;
                            seat__playerEid : EntityId = INVALID_ENTITY_ID;
                            seat__isLocked : bool = false;
                            seat__adjacentSeat : int = -1)
    let sitterPlayer = get_Eid(sitter_eid, "possessedByPlr") ?? INVALID_ENTITY_ID
    let realSeatOwner = get_Eid(seat__ownerEid, "possessedByPlr") ?? INVALID_ENTITY_ID 
    let isOwnerDead = has(seat__ownerEid, "deadEntity")
    canChange = !seat__isLocked && (!seat__ownerEid || isOwnerDead)
    canChange ||= can_replace_bots && !seat__isPlayer
    canChange ||= can_replace_group_bots && !seat__isPlayer 
    canChange &&= can_replace_own_bots || !seat__playerEid || isOwnerDead || seat__playerEid != sitterPlayer || sitterPlayer != realSeatOwner

    let prevSeatNo = find_seat_with_owner(sitter_eid, vehicle_seats__seatEids)
    if seat__adjacentSeat > -1 && seat__adjacentSeat != prevSeatNo
      let adjacentSeatOwner = get_Eid(vehicle_seats__seatEids[seat__adjacentSeat], "seat__ownerEid") ?? INVALID_ENTITY_ID
      canChange &&= !adjacentSeatOwner
  return canChange

[es(tag=server)]  
def vehicle_seats_switch_seat_place(evt : CmdVehiclePlaceSeat;
                                    vehicle_seats__seatEids : EidList;
                                    vehicle_seats_switch_time__totalSwitchTime : float;
                                    vehicle_seats__changeSeatCooldownUntilTime : float;
                                    vehicle_seats__canReplaceBots : bool = true;
                                    vehicle_seats__canReplaceOwnBots : bool = false;
                                    vehicle_seats__canReplaceGroupBots : bool = true)
  let sitterEid = evt.eid
  query(sitterEid) <| $ [es] (entity_mods__vehicleChangeSeatTimeMult : float = 1.0)
    let seatOrderNo = evt.seat
    if can_change_seat_to(sitterEid, seatOrderNo, vehicle_seats__seatEids, vehicle_seats__canReplaceOwnBots, vehicle_seats__canReplaceBots, vehicle_seats__canReplaceGroupBots, vehicle_seats__changeSeatCooldownUntilTime)
      let endTime = get_sync_time() + vehicle_seats_switch_time__totalSwitchTime * entity_mods__vehicleChangeSeatTimeMult
      request_seat_switch(sitterEid, seatOrderNo, vehicle_seats__seatEids, vehicle_seats_switch_time__totalSwitchTime)

def get_vehicle_control_seat(seat_eids : EidList) : int
  var resSeatNo = -1
  for seatNo, seatEid in iter_range(seat_eids), seat_eids
    var ownsControl = false
    query(seatEid) <| $ [es] (seatOwnsEntityControl : bool)
      ownsControl = seatOwnsEntityControl
    if ownsControl
      resSeatNo = seatNo
      break
  return resSeatNo

[es(tag=server)]
def vehicle_seats_switch_driver_seat(evt : CmdVehiclePlaceDriverSeat;
                                     vehicle_seats__seatEids : EidList;
                                     vehicle_seats_switch_time__totalSwitchTime : float)
  let sitterEid = evt.eid
  let seatOrderNo = get_vehicle_control_seat(vehicle_seats__seatEids)
  request_seat_switch(sitterEid, seatOrderNo, vehicle_seats__seatEids, vehicle_seats_switch_time__totalSwitchTime)

def send_change_seat_net_msg(vehicle_eid : EntityId;
                             sitter_eid : EntityId;
                             seat_order_no : int;
                             vehicle_seats__seatEids : EidList;
                             vehicle_seats__changeSeatCooldown : float;
                             var vehicle_seats__changeSeatCooldownUntilTime : float&) : bool
  var seatNo = -1
  if (seat_order_no >= 0 && length(vehicle_seats__seatEids) > seat_order_no &&
      (get_bool(vehicle_seats__seatEids[seat_order_no], "seats_order__canPlaceManually") ?? false) &&
      can_enter_seat_with_only_owner_access(vehicle_seats__seatEids[seat_order_no], sitter_eid))
    seatNo = get_int(vehicle_seats__seatEids[seat_order_no], "seats_order__seatNo") ?? -1
  if seatNo < 0
    return false
  send_net_event(vehicle_eid, RequestVehicleChangeSeat(eid = sitter_eid, seat = seatNo))
  vehicle_seats__changeSeatCooldownUntilTime = get_sync_time() + vehicle_seats__changeSeatCooldown
  return true

[es(tag=netClient)]
def vehicle_seats_switch_seat_requester(evt : CmdVehiclePlaceSeat;
                                        eid : EntityId;
                                        vehicle_seats__seatEids : EidList;
                                        vehicle_seats_switch_time__totalSwitchTime : float;
                                        vehicle_seats__changeSeatCooldown : float;
                                        var vehicle_seats__changeSeatCooldownUntilTime : float&;
                                        vehicle_seats__canReplaceBots : bool = true;
                                        vehicle_seats__canReplaceOwnBots : bool = false;
                                        vehicle_seats__canReplaceGroupBots : bool = true)
  let sitterEid = evt.eid
  query(sitterEid) <| $ [es(REQUIRE=hero)] (entity_mods__vehicleChangeSeatTimeMult : float = 1.0)
    let seatOrderNo = evt.seat
    if can_change_seat_to(sitterEid, seatOrderNo, vehicle_seats__seatEids, vehicle_seats__canReplaceOwnBots, vehicle_seats__canReplaceBots, vehicle_seats__canReplaceGroupBots, vehicle_seats__changeSeatCooldownUntilTime)
      let endTime = get_sync_time() + vehicle_seats_switch_time__totalSwitchTime * entity_mods__vehicleChangeSeatTimeMult
      send_change_seat_net_msg(eid, sitterEid, seatOrderNo, vehicle_seats__seatEids, vehicle_seats__changeSeatCooldown, vehicle_seats__changeSeatCooldownUntilTime)
      setOptional(eid, "vehicle__sniperModeEnabled", false)

[es(tag=netClient)]
def vehicle_seats_request_driver_seat(evt : CmdVehiclePlaceDriverSeat;
                                      eid : EntityId;
                                      vehicle_seats__seatEids : EidList;
                                      vehicle_seats__changeSeatCooldown : float;
                                      var vehicle_seats__changeSeatCooldownUntilTime : float&)
  let sitterEid = evt.eid
  let seatOrderNo = get_vehicle_control_seat(vehicle_seats__seatEids)
  send_change_seat_net_msg(eid, sitterEid, seatOrderNo, vehicle_seats__seatEids, vehicle_seats__changeSeatCooldown, vehicle_seats__changeSeatCooldownUntilTime)
  setOptional(eid, "vehicle__sniperModeEnabled", false)

def find_next_seat(vehicle_seats__seatEids : EidList; human_eid : EntityId) : int
  var nextSeat = -1
  for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
    let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
    if ownerEid == human_eid
      var nextSeatNo = get_int(seatEid, "seat__nextSeatNo") ?? -1
      if nextSeatNo < 0
        break
      while true
        if nextSeatNo == seatNo
          break
        let nextOwnerEid = get_Eid(vehicle_seats__seatEids[nextSeatNo], "seat__ownerEid") ?? INVALID_ENTITY_ID
        if nextOwnerEid == INVALID_ENTITY_ID
          nextSeat = nextSeatNo
          break
        else
          nextSeatNo = get_int(vehicle_seats__seatEids[nextSeatNo], "seat__nextSeatNo") ?? -1
  return nextSeat

[es(tag=netClient, REQUIRE=vehicle_seats__seats)]
def vehicle_seats_switch_seat_requester_next(evt : CmdVehiclePlaceNextSeat;
                                             vehicle_seats__seatEids : EidList;
                                             eid : EntityId)
  let sitterEid = evt.eid
  let seatNo = find_next_seat(vehicle_seats__seatEids, sitterEid)
  if seatNo < 0
    return
  send_net_event(eid, RequestVehicleChangeSeat(eid = sitterEid, seat = seatNo))
  setOptional(eid, "vehicle__sniperModeEnabled", false)

[es(tag=server)]
def vehicle_seats_switch_seat_next(evt : CmdVehiclePlaceNextSeat; vehicle_seats__seatEids : EidList; vehicle_seats_switch_time__totalSwitchTime : float)
  let sitterEid = evt.eid
  let newSeatNo = find_next_seat(vehicle_seats__seatEids, sitterEid)
  let curSeatNo = find_seat_with_owner(sitterEid, vehicle_seats__seatEids)
  if newSeatNo < 0 || curSeatNo < 0
    return
  start_seat_timer(sitterEid, curSeatNo, newSeatNo, vehicle_seats__seatEids, vehicle_seats_switch_time__totalSwitchTime)

[es(tag=server)]
def vehicle_seats_swap(evt : CmdVehicleSwapSeats; vehicle_seats__seatEids : EidList)
  swap_seats(vehicle_seats__seatEids[evt.seatNo1], vehicle_seats__seatEids[evt.seatNo2])

[es(tag=server, no_order)]
def vehicle_seats_switch_timer(info : UpdateStageInfoAct; vehicle_seats__seatEids : EidList)
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__ownerEid : EntityId; var seats_switch_time__time : float&; var seats_switch_time__newSeatNo : int&)
      if seats_switch_time__time < 0.
        return

      seats_switch_time__time -= info.dt
      if seats_switch_time__time >= 0.
        return

      if !!seat__ownerEid
        change_seat(seat__ownerEid, seats_switch_time__newSeatNo, vehicle_seats__seatEids)

      seats_switch_time__time = -1.f
      seats_switch_time__newSeatNo = -1

[es(tag=server)]
def vehicle_seats_stop_switch_timer_if_occupied(evt : EventEnterVehicle; vehicle_seats__seatEids : EidList)
  if !evt.enter
    return
  let incomerIndex = find_seat_with_owner(evt.incomer, vehicle_seats__seatEids)
  if incomerIndex < 0
    return
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (var seats_switch_time__time : float&; var seats_switch_time__newSeatNo : int&)
      if seats_switch_time__newSeatNo == incomerIndex
        seats_switch_time__newSeatNo = -1
        seats_switch_time__time = -1.f

[es]
def last_vehicle_tracker(evt : EventEnterVehicle;
                         var vehicle__lastEid : EntityId&;
                         var vehicle__lastTime : float&)
  vehicle__lastEid = evt.vehicle
  vehicle__lastTime = get_sync_time()

[es(tag=gameClient)]
def disable_sniper_mode_on_enter_exit_vehicle(evt : EventEnterVehicle;
                                              var vehicle__sniperModeEnabled : bool&)
  vehicle__sniperModeEnabled = false
