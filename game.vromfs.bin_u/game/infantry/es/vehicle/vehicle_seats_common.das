module vehicle_seats_common shared
require ecs
require ecs.safe
require ecs.common
require DagorMath

require vehicle
require %appGame.infantry.es.hero_common
require app
require net
require math.base
require Grid
require GridCollision
require AnimV20
require CollRes
require GeomNodeTree
require Unit

require %appGame.infantry.es.vehicle.vehicle_events
require %game.utils.net_utils
require HumanPhys
require %appGame.infantry.es.team_common
require matching

enum VehicleControlTypes : uint8
  VEHICLE_CONTROLS_MOVEMENT = 1 << 0
  VEHICLE_CONTROLS_TURRETS = 1 << 1
  VEHICLE_CONTROLS_CAMERA = 1 << 2

def find_seat_with_owner(owner_eid, seat_eids)
  if !owner_eid
    return -1
  return find_index_if(each(seat_eids)) <| $(seatEid) : bool
    return (get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID) == owner_eid

def find_seat_eid_with_owner(owner_eid, seat_eids) : EntityId
  let seatNo = find_seat_with_owner(owner_eid, seat_eids)
  return uint(seatNo) >= uint(length(seat_eids)) ? INVALID_ENTITY_ID : seat_eids[seatNo]

def get_seat_attach_tm(seat_eid : EntityId;
                       tree : GeomNodeTree;
                       collres : CollisionResource;
                       transform : float3x4;
                       var out_tm : float3x4)
  var res = false
  query(seat_eid) <| $ [es] (seats_attach_nodes__nodeId : int;
                             seats_attach_nodes__collNodeId : int;
                             seats_attach_nodes__ignoreAttachNodeRotation : bool;
                             seats_attach_nodes__nodeItm : float3x4;
                             seats_attach_nodes__attachTm : float3x4)
    if seats_attach_nodes__nodeId >= 0
      
      
      
      geomtree_getNodeWtmScalar(tree, seats_attach_nodes__nodeId, out_tm)
      out_tm = transform * out_tm
    elif seats_attach_nodes__collNodeId >= 0
      collres_get_collision_node_tm(collres, seats_attach_nodes__collNodeId,
                                    transform, null, out_tm)
    else
      out_tm = transform

    if seats_attach_nodes__ignoreAttachNodeRotation
      let nodePos = out_tm[3]
      out_tm = out_tm * seats_attach_nodes__nodeItm
      out_tm[3] = nodePos
    elif det(out_tm) < 0.0f
      orthonormalize(out_tm)

    out_tm = out_tm * seats_attach_nodes__attachTm
    res = true
  return res

def find_seat_no(name : string; seats : ecs::Array) : int
  if name == ""
    return -1
  for seatNo in iter_range(seats)
    let seat = get_ecs_object(seats[seatNo])
    if get_string(seat, "name", "") == name
      return seatNo
  return -1

def find_next_seat_no(name : string; seats : ecs::Array; var nextSeatNo : int&) : bool
  if name == ""
    return false
  if nextSeatNo >= length(seats)
    return false
  if nextSeatNo < 0
    nextSeatNo = -1
  for seatNo in range(nextSeatNo + 1, length(seats))
    let seat = get_ecs_object(seats[seatNo])
    if get_string(seat, "name", "") == name
      nextSeatNo = seatNo
      return true
  nextSeatNo = length(seats)
  return false


def vehicle_get_hero_seat_idx(seat_eids)
  return find_seat_with_owner(get_controlled_hero_eid(), seat_eids)




def is_hero_in_vehicle(vehicle_seats__seatEids : EidList) : bool
  return vehicle_get_hero_seat_idx(vehicle_seats__seatEids) != -1




def find_seat_order_no(seat_no : int; vehicle_seats__seatEids : EidList) : int
  var seatOrderNo = -1
  for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seats_order__seatNo : int)
      if seats_order__seatNo == seat_no
        seatOrderNo = seatNo
  return seatOrderNo

def is_vehicle_with_crew(vehicle_seats__seatEids : EidList)
  for seatEid in vehicle_seats__seatEids
    let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
    if !!ownerEid
      return true
  return false

def is_vehicle_with_crew(vehicle_eid : EntityId)
  var isCrew = false
  query(vehicle_eid) <| $ [es] (vehicle_seats__seatEids : EidList)
    isCrew = is_vehicle_with_crew(vehicle_seats__seatEids)
  return isCrew

def is_vehicle_with_alive_crew(vehicle_seats__seatEids : EidList)
  for seatEid in vehicle_seats__seatEids
    if get_bool(seatEid, "seat__isOwnerAlive") ?? false
      return true
  return false

def is_vehicle_with_alive_crew(vehicle_eid : EntityId)
  var isAliveCrew = false
  query(vehicle_eid) <| $ [es] (vehicle_seats__seatEids : EidList)
    isAliveCrew = is_vehicle_with_alive_crew(vehicle_seats__seatEids)
  return isAliveCrew

def start_enter_vehicle_timer(requester : EntityId; vehicle : EntityId; enter_time : float) : bool
  if enter_time <= 0.f
    return false
  var timerStarted = false
  query(requester) <| $ [es] (possessedByPlr : EntityId;
                              var enter_vehicle__atTime : float&;
                              var enter_vehicle__vehicleEid : EntityId?;
                              entity_mods__vehicleChangeSeatTimeMult : float = 1.0)
    if !possessedByPlr
      return
    timerStarted = true
    let atTime = get_sync_time()
    if enter_vehicle__atTime > atTime
      return
    enter_vehicle__atTime = atTime + enter_time * entity_mods__vehicleChangeSeatTimeMult
    if enter_vehicle__vehicleEid != null
      *enter_vehicle__vehicleEid = vehicle
  return timerStarted

def kick_from_vehicle(eid : EntityId; vehicle_eid : EntityId; vehicle_seats__seatEids : EidList)
  for seatEid in vehicle_seats__seatEids
    if get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID == eid
      sendEventImmediate(vehicle_eid, CmdKickFromVehicle(eid = eid))
      break

def kick_all_from_vehicle(vehicle_eid : EntityId; vehicle_seats__seatEids : EidList)
  for seatEid in vehicle_seats__seatEids
    let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
    if !!ownerEid
      sendEventImmediate(vehicle_eid, CmdKickFromVehicle(eid = ownerEid))

def kick_all_players_except_owner(vehicle_eid : EntityId)
  query(vehicle_eid) <| $ [es] (ownedByPlayer : EntityId; vehicle_seats__seatEids : EidList)
    for seatEid in vehicle_seats__seatEids
      query(seatEid) <| $ [es] (seat__isPlayer : bool; seat__playerEid, seat__ownerEid : EntityId)
        if seat__isPlayer && seat__playerEid != ownedByPlayer
          sendEventImmediate(vehicle_eid, CmdKickFromVehicle(eid = seat__ownerEid))

def can_enter_seat_with_only_owner_access(seat_eid : EntityId; soldier_eid : EntityId)
  if !(get_bool(seat_eid, "seats_order__canPlaceOnlyOwner") ?? false)
    return true
  let vehicle_eid = get_Eid(seat_eid, "seat__vehicleEid") ?? INVALID_ENTITY_ID
  let vehicleOwnedSquad = get_Eid(vehicle_eid, "ownedBySquad") ?? INVALID_ENTITY_ID
  let soldierSquad = get_Eid(soldier_eid, "squad_member__squad") ?? INVALID_ENTITY_ID
  return vehicleOwnedSquad == soldierSquad

def check_player_can_enter_seat(player : EntityId; seat_eid : EntityId; vehicle_seats__seatEids : EidList)
  var canEnter = false
  query(seat_eid) <| $ [es] (seat__ownerEid : EntityId = INVALID_ENTITY_ID;
                             seat__playerEid : EntityId = INVALID_ENTITY_ID;
                             seats_order__canPlaceManually : bool = true;
                             seat__isLocked : bool = false;
                             seat__adjacentSeat : int = -1)
    canEnter = (!seat__isLocked && seats_order__canPlaceManually &&
      ((seat__ownerEid == INVALID_ENTITY_ID) ||
       (seat__playerEid == player) ||
       !(get_bool(seat__ownerEid, "isAlive") ?? true)))

    let soldier_eid = get_Eid(player, "possessed") ?? INVALID_ENTITY_ID
    canEnter = canEnter && can_enter_seat_with_only_owner_access(seat_eid, soldier_eid)

    if canEnter && seat__adjacentSeat > -1
      let adjacentSeatEid = vehicle_seats__seatEids[seat__adjacentSeat]
      query(adjacentSeatEid) <| $ [es] (seat__ownerEid aka adjacent_seat__ownerEid : EntityId)
        canEnter = adjacent_seat__ownerEid == INVALID_ENTITY_ID || !(get_bool(adjacent_seat__ownerEid, "isAlive") ?? true)
  return canEnter

def find_preferred_free_seat(player : EntityId; vehicle_seats__seatEids : EidList; preferred_seat_eid : EntityId) : int
  var res = -1
  for orderSeatEid in vehicle_seats__seatEids
    let orderSeatNo = get_int(orderSeatEid, "seats_order__seatNo") ?? -1
    if orderSeatNo < 0
      continue
    let seatEid = vehicle_seats__seatEids[orderSeatNo]
    if seatEid == preferred_seat_eid && check_player_can_enter_seat(player, seatEid, vehicle_seats__seatEids)
      res = orderSeatNo
      break
  return res

def find_highest_free_seat(player : EntityId; vehicle_seats__seatEids : EidList) : int
  var res = -1
  for orderSeatEid in vehicle_seats__seatEids
    let orderSeatNo = get_int(orderSeatEid, "seats_order__seatNo") ?? -1
    if orderSeatNo < 0
      continue
    let seatEid = vehicle_seats__seatEids[orderSeatNo]
    if check_player_can_enter_seat(player, seatEid, vehicle_seats__seatEids)
      res = orderSeatNo
      break
  return res

def find_nearest_free_seat(player : EntityId;
                           requester_pos : float3;
                           look_dir : float3;
                           seat_check_offset : float;
                           seat_sphere_radius : float;
                           tree : GeomNodeTree;
                           collres : CollisionResource;
                           vehicle_tm : float3x4;
                           vehicle_seats__seatEids : EidList) : EntityId
  var bestSeatDistEid = INVALID_ENTITY_ID
  var bestSeatDistSq = -1.0f
  var bestSeatRayEid = INVALID_ENTITY_ID
  var bestSeatRayDistSq = -1.0f
  for seatEid in vehicle_seats__seatEids
    if (get_int(seatEid, "seats_order__seatNo") ?? -1) < 0
      continue
    if !check_player_can_enter_seat(player, seatEid, vehicle_seats__seatEids)
      continue
    var seatTm : float3x4
    if !get_seat_attach_tm(seatEid, tree, collres, vehicle_tm, seatTm)
      continue
    let distSq = length_sq(requester_pos - seatTm[3])
    if !bestSeatDistEid || distSq < bestSeatDistSq
      bestSeatDistEid = seatEid
      bestSeatDistSq = distSq
    var sphereCheck = rayIntersectSphereDist(requester_pos, look_dir, seatTm[3], seat_sphere_radius) >= 0.f
    if !sphereCheck
      let relPos = seatTm[3] + seatTm[1] * seat_check_offset
      sphereCheck = rayIntersectSphereDist(requester_pos, look_dir, relPos, seat_sphere_radius) >= 0.f
    if sphereCheck
      if !bestSeatRayEid || distSq < bestSeatRayDistSq
        bestSeatRayEid = seatEid
        bestSeatRayDistSq = distSq
  if bestSeatRayEid != INVALID_ENTITY_ID
    return bestSeatRayEid
  if bestSeatDistEid != INVALID_ENTITY_ID
    return bestSeatDistEid
  let highestSeatNo = find_highest_free_seat(player, vehicle_seats__seatEids)
  if highestSeatNo >= 0
    return vehicle_seats__seatEids[highestSeatNo]
  return INVALID_ENTITY_ID

def enter_vehicle_now(requester : EntityId; vehicle : EntityId; requestSeatNo : int)
  if !is_server()
    return
  query(vehicle) <| $ [es] (vehicle_seats__seatEids : EidList)
    let seatEid = vehicle_seats__seatEids[requestSeatNo]
    let curOwner = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
    if !(get_bool(curOwner, "isAlive") ?? true)
      kick_from_vehicle(curOwner, vehicle, vehicle_seats__seatEids)
    sendEvent(vehicle, CmdAcquireVehicleSeat(requester = requester, seat_no = requestSeatNo))

def enter_vehicle(requester : EntityId; player_eid : EntityId; vehicle : EntityId; vehicle_seats__seatEids : EidList; enter_time : float; requestSeatEid : EntityId; var outRequestSeatEid : EntityId?)
  var requestSeatNo = find_preferred_free_seat(player_eid, vehicle_seats__seatEids, requestSeatEid)
  if requestSeatNo < 0
    requestSeatNo = find_highest_free_seat(player_eid, vehicle_seats__seatEids)
  if requestSeatNo < 0
    return
  if !start_enter_vehicle_timer(requester, vehicle, enter_time)
    enter_vehicle_now(requester, vehicle, requestSeatNo)
  elif outRequestSeatEid != null
    *outRequestSeatEid = vehicle_seats__seatEids[requestSeatNo]

def cancel_exit_timer(requester : EntityId) : bool
  var res = true
  query(requester) <| $ [es] (var exit_vehicle__atTime : float?)
    if exit_vehicle__atTime == null || *exit_vehicle__atTime < get_sync_time()
      res = false
      return
    *exit_vehicle__atTime = -1.f
  return res

def start_exit_vehicle_timer(requester : EntityId; exit_time : float) : bool
  if exit_time <= 0.f
    return false
  var timerStarted = false
  query(requester) <| $ [es] (possessedByPlr : EntityId;
                              var exit_vehicle__atTime : float&;
                              entity_mods__vehicleChangeSeatTimeMult : float = 1.0)
    if !possessedByPlr
      return
    exit_vehicle__atTime = get_sync_time() + exit_time * entity_mods__vehicleChangeSeatTimeMult
    timerStarted = true
  return timerStarted

def exit_vehicle_now(requester : EntityId; vehicle : EntityId)
  if is_server()
    sendEvent(vehicle, CmdKickFromVehicle(eid = requester))

def exit_vehicle(requester : EntityId; vehicle : EntityId; exit_time : float)
  if cancel_exit_timer(requester)
    return
  if !start_exit_vehicle_timer(requester, exit_time)
    exit_vehicle_now(requester, vehicle)

def vehicle_has_owner_around(vehiclePos : float3; ownedBySquad : EntityId; distance : float) : bool
  return !!find_entity_in_grid(ecs_hash("humans"), BSphere3(vehiclePos, distance), GridEntCheck.BOUNDING) <| $(humanEid : EntityId)
    var found = false
    ecs::query(humanEid) <| $ [es(REQUIRE_NOT=deadEntity)] (squad_member__squad : ecs::EntityId)
      found = ownedBySquad == squad_member__squad
    return found

def is_vehicle_contain_owner(ownerEid : EntityId;
                             vehicle_seats__seatEids : EidList)
  for seatEid in vehicle_seats__seatEids
    if ownerEid == get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
      return true
  return false

def send_enter_vehicle_event(incomer : EntityId; vehicle : EntityId; seat_no : int; enter : bool)
  let recipients <- enum_connections_near_entity(vehicle)
  send_net_event(incomer, EventEnterVehicle(incomer = incomer, vehicle = vehicle, seat_no = seat_no, enter = enter), recipients)
  send_net_event(vehicle, EventEnterVehicle(incomer = incomer, vehicle = vehicle, seat_no = seat_no, enter = enter), recipients)

def can_bot_replace_seat_owner(owner_eid : EntityId)
  return !owner_eid || has(owner_eid, "deadEntity")

def can_take_adjacent_seat(seat_eid : EntityId)
  var res = false
  query(seat_eid) <| $ [es] (seat__ownerEid : EntityId)
    res = can_bot_replace_seat_owner(seat__ownerEid)
  return res

























































def is_gun_slot_allowed_to_hold_gun_in_hatch(slot : int)
  return slot < int(HUWeaponSlots.EWS_MELEE) || slot == int(HUWeaponSlots.EWS_GRENADE)



























def get_vehicle_owner(vehicle_eid : EntityId)
  var res = INVALID_ENTITY_ID
  query(vehicle_eid) <| $ [es] (ownedByPlayer : EntityId)
    query(ownedByPlayer) <| $ [es] (possessed : EntityId)
      res = possessed
  return res








def can_use_vehicle(player_team : int; restrict_to_team : int; player_group : int64; vehicle_group : int64; vehicle_eid : EntityId; soldier_eid : EntityId)
  return ((restrict_to_team == TEAM_UNASSIGNED || is_teams_friendly(player_team, restrict_to_team)) &&
    (vehicle_group == int64(INVALID_SQUAD_ID) || player_group == vehicle_group)) && !is_vehicle_locked_for_entity(soldier_eid, vehicle_eid)

def is_vehicle_locked_for_entity(soldier_eid : EntityId; vehicle_eid : EntityId)
  var locked = false
  query(vehicle_eid) <| $ [es(REQUIRE=vehicle__onlyOwnerSquadCanUse)] (ownedBySquad : EntityId)
    query(soldier_eid) <| $ [es] (squad_member__squad : EntityId; human_anim__vehicleSelected : EntityId)
      locked = human_anim__vehicleSelected != vehicle_eid && squad_member__squad != ownedBySquad
  return locked

def swap_seats(seat1, seat2 : EntityId)
  query(seat1) <| $ [es] (seat__component : int; var seat__isPlayer aka seat__isPlayer_1 : bool&;
                          var seat__ownerEid aka seat__ownerEid_1, seat__playerEid aka seat__playerEid_1, seat__squadEid aka seat__squadEid_1 : EntityId&)

    let wasSeat1OwnerEid = seat__ownerEid
    let seatComponent1   = uint(seat__component)

    query(seat2) <| $ [es] (seat__component : int; var seat__ownerEid, seat__playerEid, seat__squadEid : EntityId&; var seat__isPlayer : bool&)
      let wasSeat2OwnerEid = seat__ownerEid
      swap(seat__ownerEid_1, seat__ownerEid)
      swap(seat__squadEid_1, seat__squadEid)
      swap(seat__playerEid_1, seat__playerEid)
      swap(seat__isPlayer_1, seat__isPlayer)

      query(wasSeat1OwnerEid) <| $ [es] (var human_vehicle__occupiedSeatEid : EntityId&; var human_vehicle__lastKnownSeatEid : EntityId?)
        human_vehicle__occupiedSeatEid = seat2
        if human_vehicle__lastKnownSeatEid != null
          *human_vehicle__lastKnownSeatEid = human_vehicle__occupiedSeatEid
      query(wasSeat2OwnerEid) <| $ [es] (var human_vehicle__occupiedSeatEid : EntityId&; var human_vehicle__lastKnownSeatEid : EntityId?)
        human_vehicle__occupiedSeatEid = seat1
        if human_vehicle__lastKnownSeatEid != null
          *human_vehicle__lastKnownSeatEid = human_vehicle__occupiedSeatEid

      if has(wasSeat1OwnerEid, "", seatComponent1) && has(wasSeat1OwnerEid, "", uint(seat__component))
        set(wasSeat1OwnerEid, "", seatComponent1, false)
        set(wasSeat1OwnerEid, "", uint(seat__component), true)
      if has(wasSeat2OwnerEid, "", seatComponent1) && has(wasSeat2OwnerEid, "", uint(seat__component))
        set(wasSeat2OwnerEid, "", uint(seat__component), false)
        set(wasSeat2OwnerEid, "", seatComponent1, true)

def change_seat(human_eid : EntityId; newSeatNo : int; vehicle_seats__seatEids : EidList)
  if !human_eid || newSeatNo < 0
    return

  var curvel = float3()
  var maxvel = -1.0
  query(human_eid) <| $ [es] (maxVehicleVelocityCanReEnter : float; human_anim__vehicleSelected : EntityId)
    query(human_anim__vehicleSelected) <| $ [es] (net_phys__currentStateVelocity : float3 = float3())
      curvel = net_phys__currentStateVelocity
    maxvel = maxVehicleVelocityCanReEnter
  let canChangeRoomNow = maxvel < 0.0 || length_sq(curvel) < maxvel * maxvel

  for seatEid in vehicle_seats__seatEids
    let oldSeatOwnerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
    let oldRoomSpace = get_int(seatEid, "seat__roomSpace") ?? -1
    if oldSeatOwnerEid == human_eid
      let newSeatEid = vehicle_seats__seatEids[newSeatNo]
      let newRoomSpace = get_int(newSeatEid, "seat__roomSpace") ?? -1
      let newSeatOwnerEid = get_Eid(newSeatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
      let newSeatOwnerIsPlayer = get_bool(newSeatEid, "seat__isPlayer") ?? false
      
      if (canChangeRoomNow || newRoomSpace == oldRoomSpace || newRoomSpace < 0 || oldRoomSpace < 0) && (!newSeatOwnerEid || !newSeatOwnerIsPlayer || has(newSeatOwnerEid, "deadEntity"))
        swap_seats(seatEid, newSeatEid)
      return

def detach_human_from_seat(eid : EntityId; seat__component : int)
  query(eid) <| $ [es] (var isInVehicle : bool&;
                        var isInVehicleHidden : bool&;
                        var human_anim__vehicleSelected : EntityId&;
                        var human_vehicle__occupiedSeatEid : EntityId&)
    isInVehicle = false
    isInVehicleHidden = false
    human_anim__vehicleSelected = INVALID_ENTITY_ID
    human_vehicle__occupiedSeatEid = INVALID_ENTITY_ID

  setOptional(eid, "", uint(seat__component), false)

def can_enter_vehicle(vehicle__isPlayerCanEnterBlocked : int; vehicle__isPlayerCanEnter : bool)
  return vehicle__isPlayerCanEnterBlocked == 0 && vehicle__isPlayerCanEnter

def can_exit_vehicle(vehicle__isPlayerExitAutoBlocked : bool; vehicle__isPlayerCanExit : bool)
  return !vehicle__isPlayerExitAutoBlocked && vehicle__isPlayerCanExit

def find_best_leader_in_vehicle(squad_eid : EntityId; vehicle_eid : EntityId)
  var minScore = INT_MAX
  var bestEntity = INVALID_ENTITY_ID

  query(squad_eid) <| $ [es] (squad__allMembers : EidList)
    query(vehicle_eid) <| $ [es] (@shared_comp vehicle_seats__seats : Array;
                                  vehicle_seats__seatEids : EidList;
                                  vehicle_seats__seatPriorities : StringList)
      for squarMemberEid in squad__allMembers
        query(squarMemberEid) <| $ [es(REQUIRE_NOT=deadEntity)] (human_anim__vehicleSelected : EntityId)
          if human_anim__vehicleSelected != vehicle_eid
            return
          let seatId = find_seat_with_owner(squarMemberEid, vehicle_seats__seatEids)
          if seatId < 0
            return
          let seatName = (vehicle_seats__seats[seatId] as Object)?.name ?? ""
          var score = find_index(vehicle_seats__seatPriorities, seatName)
          if score < 0
            score = length(vehicle_seats__seatPriorities)
          if score < minScore
            minScore = score
            bestEntity = squarMemberEid

  return bestEntity
