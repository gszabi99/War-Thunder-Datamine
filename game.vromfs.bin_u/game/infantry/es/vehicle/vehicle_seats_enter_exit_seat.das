require ecs
require ecs.safe
require ecs.common

require %appGame.wt_events
require %appGame.infantry.es.vehicle.vehicle_events
require %appGame.infantry.es.vehicle.vehicle_seats_common

require DngHuman
require net
require %appGame.infantry.es.team_common
require matching

[es(tag=netClient)]
def vehicle_seats_enter_exit_seat_client_es(evt : CmdAcquireVehicleSeat;
                                            eid : EntityId)
  send_net_event(eid, RequestVehicleSeat(requester = evt.requester, seat_no = evt.seat_no))


[es(tag=server, REQUIRE=vehicle_seats__seats)]
def vehicle_seats_enter_exit_seat_request_es(evt : RequestVehicleSeat;
                                             eid : EntityId)
  sendEvent(eid, CmdAcquireVehicleSeat(requester = evt.requester, seat_no = evt.seat_no))


def private attach_human_to_seat(eid : EntityId;
                                 vehicleEid : EntityId;
                                 seat__component : int;
                                 seatEid : EntityId;
                                 should_hide : bool = false)
  let hasVehicle = vehicleEid != INVALID_ENTITY_ID

  query(eid) <| $ [es] (var isInVehicle : bool&;
                        var isInVehicleHidden : bool&;
                        var human_anim__vehicleSelected : EntityId&;
                        var human_vehicle__occupiedSeatEid : EntityId&;
                        var human_vehicle__lastKnownSeatEid : EntityId?)
    isInVehicle = hasVehicle
    isInVehicleHidden = should_hide && hasVehicle
    human_anim__vehicleSelected = vehicleEid
    human_vehicle__occupiedSeatEid = seatEid
    if human_vehicle__lastKnownSeatEid != null
      *human_vehicle__lastKnownSeatEid = human_vehicle__occupiedSeatEid

  setOptional(eid, "", uint(seat__component), hasVehicle)

def can_take_seat_from_owner(requester_possessed_by_player_eid : EntityId;
                             seat__ownerEid : EntityId;
                             seat__playerEid : EntityId)
  return (!seat__ownerEid
       || !(get_bool(seat__ownerEid, "isAlive") ?? true)
       || (!!requester_possessed_by_player_eid && seat__playerEid == requester_possessed_by_player_eid))

def is_already_in_vehicle(requester : EntityId)
  return find_query() <| $ [es] (vehicle_seats__seatEids : EidList)
    for seatEid in vehicle_seats__seatEids
      if (get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID) == requester
        return true
    return false








[es(tag=server, REQUIRE_NOT=deadEntity)]
def vehicle_seats_enter_exit_seat_server_es(evt : CmdAcquireVehicleSeat;
                                            eid : EntityId;
                                            vehicle_seats__seatEids : EidList;
                                            vehicle_seats_hide_owner : BoolList;
                                            vehicle_seats__restrictToGroup : int64 = int64(INVALID_SQUAD_ID);
                                            vehicle_seats__restrictToTeam : int = TEAM_UNASSIGNED)
  let requester     = evt.requester
  let requestSeatNo = evt.seat_no

  var canUseVehicle = true
  query(requester) <| $ [es] (team : int; squad_member__playerEid : EntityId = INVALID_ENTITY_ID)
    let playerGroup = get_int64(squad_member__playerEid, "groupId") ?? int64(INVALID_SQUAD_ID)
    canUseVehicle = can_use_vehicle(team, vehicle_seats__restrictToTeam, playerGroup, vehicle_seats__restrictToGroup, eid, requester)

  if !canUseVehicle
    return

  let canTakeSeat = get_bool(requester, "human_vehicle__can_take_seat") ?? true
  if !canTakeSeat
    return

  let reqSeatEid = vehicle_seats__seatEids?[requestSeatNo] ?? INVALID_ENTITY_ID

  query(reqSeatEid) <| $ [es] (seat__component : int;
                               seat__adjacentSeat : int = -1;
                               seat__isLocked : bool = false;
                               var seat__isPlayer : bool&;
                               var seat__ownerEid : EntityId&;
                               var seat__playerEid : EntityId&;
                               var seat__squadEid : EntityId&)
    if seat__isLocked
      return
    if seat__adjacentSeat > -1
      let adjacentSeatEid = vehicle_seats__seatEids[ seat__adjacentSeat ]
      let adjacentSeatOwnerEid = get_Eid(adjacentSeatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
      if !!adjacentSeatOwnerEid && (get_bool(adjacentSeatOwnerEid, "isAlive") ?? false)
        return

    let playerEid = get_Eid(requester, "possessedByPlr") ?? INVALID_ENTITY_ID

    if !can_take_seat_from_owner(playerEid, seat__ownerEid, seat__playerEid)
      return

    if !!playerEid && is_already_in_vehicle(requester)
      return

    
    

    seat__isPlayer  = !!playerEid
    seat__ownerEid  = requester
    seat__squadEid  = get_Eid(requester, "squad_member__squad") ?? INVALID_ENTITY_ID
    seat__playerEid = !!playerEid ? playerEid : get_Eid(seat__squadEid, "squad__ownerPlayer") ?? INVALID_ENTITY_ID

    attach_human_to_seat(requester, eid, seat__component, reqSeatEid, vehicle_seats_hide_owner[ requestSeatNo ])

    
    
    

    send_enter_vehicle_event(requester, eid, requestSeatNo, true)
