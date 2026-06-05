require ecs
require %appGame.wt_events
require %appGame.infantry.es.vehicle.vehicle_events
require %appGame.infantry.es.vehicle.vehicle_seats_common
require %appGame.infantry.es.team_common

require matching
require net
require Unit


[es(REQUIRE_NOT=deadEntity)]
def vehicle_seats_es_enter_exit(evt : CmdUse;
                                eid : EntityId;
                                var unit__ref : UnitRef;
                                ownedByPlayer aka vehicle_ownedByPlayer : EntityId;
                                vehicle_seats__seatEids : EidList;
                                vehicle_seats__restrictToGroup : int64 = int64(INVALID_SQUAD_ID);
                                vehicle_seats__exitTime : float = 0.f;
                                vehicle_seats__enterTime : float = 0.f;
                                vehicle_seats__restrictToTeam : int = TEAM_UNASSIGNED;
                                vehicle__isPlayerCanEnter : bool = true;
                                vehicle__isPlayerCanEnterBlocked : int = 0;
                                vehicle__isPlayerCanExit : bool = true;
                                vehicle__isPlayerExitAutoBlocked : bool = false;
                                vehicle__otherPlayersCanEnter = true)
  var unit = unit__ref.unit
  if !unit.isAlive || unit.isDelayed
    return

  let requester = evt.requesterEid
  query(requester) <| $ [es] (var human_vehicle__requestSeatEid : EntityId?;
                              team : int;
                              isInVehicle : bool;
                              squad_member__playerEid : EntityId;
                              human__aimTm : float3x4;
                              human_vehicle__can_take_seat : bool = true;
                              human_use_object__lockVehicleUse : bool = false)
    if !isInVehicle && !vehicle__otherPlayersCanEnter && squad_member__playerEid != vehicle_ownedByPlayer
      send_net_event(requester, CmdHeroLogEvent(event = "can_not_vehicle_use", text = "hint/vehicle/lockUse"))
      return

    let canEnter = can_enter_vehicle(vehicle__isPlayerCanEnterBlocked, vehicle__isPlayerCanEnter)
    if !isInVehicle && !canEnter
      send_net_event(requester, CmdHeroLogEvent(event = "can_not_vehicle_use", text = "hint/vehicle/lockUse"))
      return

    let playerGroup = get_int64(squad_member__playerEid, "groupId") ?? int64(INVALID_SQUAD_ID)
    if !can_use_vehicle(team, vehicle_seats__restrictToTeam, playerGroup, vehicle_seats__restrictToGroup, eid, requester)
      return

    if can_exit_vehicle(vehicle__isPlayerExitAutoBlocked, vehicle__isPlayerCanExit) && find_seat_with_owner(requester, vehicle_seats__seatEids) >= 0
      exit_vehicle(requester, eid, vehicle_seats__exitTime)
    elif canEnter && human_vehicle__can_take_seat && !human_use_object__lockVehicleUse
      enter_vehicle(requester, human__aimTm[3], eid, vehicle_seats__seatEids, vehicle_seats__enterTime, human_vehicle__requestSeatEid)


















[es(on_event=EventEntityDied)]
def vehicle_seats_client_exit_on_die_es(evt : Event; eid : EntityId; isInVehicle : bool)
  if isInVehicle
    cancel_exit_timer(eid)
