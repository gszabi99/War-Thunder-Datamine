require ecs
require app
require math
require net
require Unit
require MPlayer
require %game.events
require %game.unit.unit_events
require %appGame.wt_events
require %appGame.infantry.es.team_common
require %appGame.infantry.es.capzones_common
require %appGame.infantry.es.supply_transport_common

def private supply_graph_distance(from_eid, to_eid : EntityId) : float
  var result = -1.0
  query(from_eid) <| $ [es] (transform aka from_transform : float3x4)
    query(to_eid) <| $ [es] (transform aka to_transform : float3x4)
      result = length(to_transform[3] - from_transform[3])
  return result

enum SupplyNodeTransfer
  ALLOWED
  UNDER_FIGHT
  NOT_OWNED

def private node_transfer_status(node_eid : EntityId; team : int) : SupplyNodeTransfer
  var owned = false
  var underFight = false
  query(node_eid) <| $ [es] (active : bool; capzone__owningTeam : int; teamPresence : Object)
    owned = active && capzone__owningTeam == team
    underFight = has_enemy_in_zone(teamPresence, team)
  if !owned
    return SupplyNodeTransfer.NOT_OWNED
  if underFight
    return SupplyNodeTransfer.UNDER_FIGHT
  var alliedStrongpoint = false
  var enemyStrongpoint = false
  query(node_eid) <| $ [es] (sectored_capzone__sectorEids : EidList)
    for sectorEid in sectored_capzone__sectorEids
      query(sectorEid) <| $ [es] (capzone_sector__strongpointEid : EntityId)
        let owner = strongpoint_owner(capzone_sector__strongpointEid)
        if owner == team
          alliedStrongpoint = true
        elif owner != TEAM_UNASSIGNED
          enemyStrongpoint = true
  return alliedStrongpoint && enemyStrongpoint ? SupplyNodeTransfer.UNDER_FIGHT : SupplyNodeTransfer.ALLOWED

def private reward_player(var player : MPlayer; target_eid : EntityId; kind : SupplyRewardKind; score : int)
  if score <= 0
    return
  inc_player_spawn_score(player, score)
  if target_eid != INVALID_ENTITY_ID
    send_net_event(target_eid, EventSupplyReward(kind = int(kind), score = score))

def private killer_player(killer_eid : EntityId; var target_eid : EntityId&) : MPlayer?
  target_eid = killer_eid
  let possessedByPlr = get_Eid(killer_eid, "possessedByPlr") ?? INVALID_ENTITY_ID
  if possessedByPlr != INVALID_ENTITY_ID
    return player_get_by_eid(possessedByPlr)
  let controlledByPlayer = get_Eid(killer_eid, "vehicle__controlledByPlayer") ?? INVALID_ENTITY_ID
  if controlledByPlayer != INVALID_ENTITY_ID
    return player_get_by_eid(controlledByPlayer)
  var player : MPlayer? = null
  query(killer_eid) <| $ [es] (unit__ref : UnitRef)
    if unit__ref.unit != null
      player = unit__ref.unit.myPlayer
  return player

def private cargo_push(var source_eids : EidList&; var source_teams : IntList&; var portions : FloatList&;
                       source_eid : EntityId; team : int; points : float)
  let last = length(portions) - 1
  if last >= 0 && source_eids[last] == source_eid && source_teams[last] == team
    portions[last] += points
    return
  push(source_eids, source_eid)
  push(source_teams, team)
  push(portions, points)

def private cargo_take(var source_eids : EidList&; var source_teams : IntList&; var portions : FloatList&;
                       points : float; node_eid : EntityId; team : int;
                       per_point : float; km_mult : float; stolen_mult : float) : float
  var left = points
  var reward = 0.0
  while left > 0.0 && length(portions) > 0
    let slice = min(left, portions[0])
    let km = max(supply_graph_distance(source_eids[0], node_eid), 0.0) / 1000.0
    let stolen = source_teams[0] != team
    reward += slice * per_point * (1.0 + km_mult * km) * (stolen ? stolen_mult : 1.0)
    left -= slice
    portions[0] -= slice
    if portions[0] <= 0.0
      erase(source_eids, 0)
      erase(source_teams, 0)
      erase(portions, 0)
  return reward

def private escort_add_time(var player_eids : EidList&; var escort_time : FloatList&; player_eid : EntityId; dt : float)
  for i in iter_range(player_eids)
    if player_eids[i] == player_eid
      escort_time[i] += dt
      return
  push(player_eids, player_eid)
  push(escort_time, dt)

def private escort_restart(var player_eids : EidList&; var escort_time : FloatList&; var delivery_start : float&; start_at : float)
  clear(player_eids)
  clear(escort_time)
  delivery_start = start_at

def private pay_escorts(var player_eids : EidList&; var escort_time : FloatList&; delivery_start : float; session_score : int; escort_mult : float)
  let deliveryTime = get_sync_time() - delivery_start
  if deliveryTime <= 0.0
    return
  for playerEid, escortSeconds in player_eids, escort_time
    var escorter = player_get_by_eid(playerEid)
    if escorter == null
      continue
    var target = INVALID_ENTITY_ID
    let unit = getControlledUnit(*escorter)
    if unit != null
      target = unit.eid
    let ratio = min(escortSeconds / deliveryTime, 1.0)
    reward_player(*escorter, target, SupplyRewardKind.ESCORT, int(float(session_score) * escort_mult * ratio))

[es(tag=server)]
def supply_transport_request_es(evt : RequestSupplyTransfer;
                                var supply_transport__requestedState : int&)
  supply_transport__requestedState = int(evt.unload ? SupplyTransportState.UNLOADING : SupplyTransportState.LOADING)

[es(tag=server, no_order)]
def supply_transport_update_es(info : UpdateStageInfoAct;
                               eid aka transport_eid : EntityId;
                               isAlive : bool;
                               unit__ref : UnitRef;
                               vehicle__controlledByPlayer : EntityId;
                               vehicle__controlledByDriver : EntityId;
                               vehicle_seats__seatEids : EidList;
                               supply_transport__pointsCapacity : float;
                               supply_transport__loadRatePerSecond : float;
                               supply_transport__unloadRatePerSecond : float;
                               supply_transport__updatePeriod : float;
                               supply_transport__standStillSpeed : float;
                               supply_reward__unloadPerPoint : float;
                               supply_reward__routeMultPerKm : float;
                               supply_reward__stolenMult : float;
                               supply_reward__returnEmpty : int;
                               supply_reward__escortMult : float;
                               var supply_transport__nextUpdateAt : float&;
                               var supply_transport__points : float&;
                               var supply_transport__state : int&;
                               var supply_transport__requestedState : int&;
                               var supply_transport__team : int&;
                               var supply_transport__cargoSourceEids : EidList&;
                               var supply_transport__cargoSourceTeams : IntList&;
                               var supply_transport__cargoPortions : FloatList&;
                               var supply_transport__returnRewardPending : bool&;
                               var supply_transport__rewardCarry : float&;
                               var supply_transport__sessionScore : int&;
                               var supply_transport__deliveryStartAt : float&;
                               var supply_transport__escortPlayerEids : EidList&;
                               var supply_transport__escortTime : FloatList&)
  if supply_transport__nextUpdateAt < 0.0
    supply_transport__nextUpdateAt = info.curTime + supply_transport__updatePeriod
    return
  if info.curTime < supply_transport__nextUpdateAt
    return
  supply_transport__nextUpdateAt += supply_transport__updatePeriod
  let dt = supply_transport__updatePeriod
  var state = int(SupplyTransportState.IDLE)
  var hint = int(SupplyTransportHint.NONE)
  let unit = unit__ref.unit
  var player = player_get_by_eid(vehicle__controlledByPlayer)
  if player != null
    if supply_transport__team != int(player.team)
      supply_transport__returnRewardPending = false
      supply_transport__team = int(player.team)
      escort_restart(supply_transport__escortPlayerEids, supply_transport__escortTime, supply_transport__deliveryStartAt, supply_transport__points > 0.0 ? get_sync_time() : -1.0)
  if isAlive && supply_transport__deliveryStartAt >= 0.0
    for seatEid in vehicle_seats__seatEids
      let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
      if ownerEid == INVALID_ENTITY_ID || ownerEid == vehicle__controlledByDriver
        continue
      query(ownerEid) <| $ [es] (isAlive aka owner_isAlive : bool; possessedByPlr : EntityId; team aka owner_team : int)
        if owner_isAlive && possessedByPlr != INVALID_ENTITY_ID && owner_team == supply_transport__team
          escort_add_time(supply_transport__escortPlayerEids, supply_transport__escortTime, possessedByPlr, dt)
  if !(isAlive && unit != null && player != null && unit.speed < supply_transport__standStillSpeed)
    supply_transport__requestedState = int(SupplyTransportState.IDLE)
  else
    let team = int(player.team)
    let pos = unit.pos.xz
    let capacity = supply_transport__pointsCapacity
    var points = supply_transport__points
    var reward = 0.0
    if supply_transport__requestedState != int(SupplyTransportState.IDLE)
      let unload = supply_transport__requestedState == int(SupplyTransportState.UNLOADING)
      find_query() <| $ [es] (eid aka node_eid : EntityId;
                              supply_node__supplyTransportArea : string;
                              supply_node__maxPoints : float;
                              var supply_node__points : float&)
        if !in_area(supply_node__supplyTransportArea, pos)
          return false
        let status = node_transfer_status(node_eid, team)
        if status == SupplyNodeTransfer.UNDER_FIGHT
          hint = int(SupplyTransportHint.UNDER_FIGHT)
        if status != SupplyNodeTransfer.ALLOWED
          return true
        if unload
          let give = min(min(supply_transport__unloadRatePerSecond * dt, points), supply_node__maxPoints - supply_node__points)
          if give > 0.0
            supply_node__points += give
            points -= give
            reward += cargo_take(supply_transport__cargoSourceEids, supply_transport__cargoSourceTeams, supply_transport__cargoPortions, give, node_eid, team, supply_reward__unloadPerPoint, supply_reward__routeMultPerKm, supply_reward__stolenMult)
            state = int(SupplyTransportState.UNLOADING)
          elif points > 0.0
            hint = int(SupplyTransportHint.NODE_FULL)
        else
          let take = min(min(supply_transport__loadRatePerSecond * dt, capacity - points), supply_node__points)
          if take > 0.0
            supply_node__points -= take
            points += take
            state = int(SupplyTransportState.LOADING)
        return true
      if state == int(SupplyTransportState.IDLE)
        supply_transport__requestedState = int(SupplyTransportState.IDLE)
    find_query() <| $ [es(REQUIRE=supplyBase)] (eid aka base_eid : EntityId;
                                                team aka base_team : int;
                                                supply_graph__name : string;
                                                supply_base__loadArea : string)
      if base_team != team
        return false
      if supply_transport__returnRewardPending && points <= 0.0 && in_area(supply_graph__name, pos)
        supply_transport__returnRewardPending = false
        reward_player(*player, transport_eid, SupplyRewardKind.RETURN, supply_reward__returnEmpty)
        pay_escorts(supply_transport__escortPlayerEids, supply_transport__escortTime, supply_transport__deliveryStartAt, supply_reward__returnEmpty, supply_reward__escortMult)
        escort_restart(supply_transport__escortPlayerEids, supply_transport__escortTime, supply_transport__deliveryStartAt, -1.0)
      if !in_area(supply_base__loadArea, pos)
        return false
      if points >= capacity
        return true
      let loaded = min(points + supply_transport__loadRatePerSecond * dt, capacity) - points
      points += loaded
      cargo_push(supply_transport__cargoSourceEids, supply_transport__cargoSourceTeams, supply_transport__cargoPortions, base_eid, team, loaded)
      escort_restart(supply_transport__escortPlayerEids, supply_transport__escortTime, supply_transport__deliveryStartAt, get_sync_time())
      state = int(SupplyTransportState.LOADING)
      return true
    if reward > 0.0
      supply_transport__returnRewardPending = true
      supply_transport__rewardCarry += reward
      let pay = int(supply_transport__rewardCarry)
      if pay > 0
        supply_transport__rewardCarry -= float(pay)
        inc_player_spawn_score(*player, pay)
        supply_transport__sessionScore += pay
    if points >= capacity && supply_transport__points < capacity
      hint = int(SupplyTransportHint.LOADED)
    elif points <= 0.0 && supply_transport__points > 0.0
      hint = int(SupplyTransportHint.UNLOADED)
    supply_transport__points = points
  if state != int(SupplyTransportState.UNLOADING) && supply_transport__state == int(SupplyTransportState.UNLOADING)
    if supply_transport__sessionScore > 0
      pay_escorts(supply_transport__escortPlayerEids, supply_transport__escortTime, supply_transport__deliveryStartAt, supply_transport__sessionScore, supply_reward__escortMult)
      send_net_event(transport_eid, EventSupplyReward(kind = int(SupplyRewardKind.UNLOAD), score = supply_transport__sessionScore))
      supply_transport__sessionScore = 0
    if supply_transport__points <= 0.0
      escort_restart(supply_transport__escortPlayerEids, supply_transport__escortTime, supply_transport__deliveryStartAt, supply_transport__returnRewardPending ? get_sync_time() : -1.0)
  if supply_transport__state != state
    supply_transport__state = state
  if hint != int(SupplyTransportHint.NONE)
    send_net_event(transport_eid, EventSupplyTransportHint(hint = hint))

[es(tag=server)]
def supply_transport_dead_es(evt : EventUnitBecameDead;
                             var supply_transport__sessionScore : int&;
                             var supply_transport__state : int&;
                             eid aka transport_eid : EntityId;
                             supply_reward__escortMult : float;
                             var supply_transport__deliveryStartAt : float&;
                             var supply_transport__escortPlayerEids : EidList&;
                             var supply_transport__escortTime : FloatList&)
  if supply_transport__sessionScore > 0
    pay_escorts(supply_transport__escortPlayerEids, supply_transport__escortTime, supply_transport__deliveryStartAt, supply_transport__sessionScore, supply_reward__escortMult)
    send_net_event(transport_eid, EventSupplyReward(kind = int(SupplyRewardKind.UNLOAD), score = supply_transport__sessionScore))
    supply_transport__sessionScore = 0
  supply_transport__state = int(SupplyTransportState.IDLE)
  escort_restart(supply_transport__escortPlayerEids, supply_transport__escortTime, supply_transport__deliveryStartAt, -1.0)

[es(tag=server)]
def supply_transport_destroyed_es(evt : EventOnUnitDead;
                                  supply_transport__team : int;
                                  supply_reward__destroyLoaded : int;
                                  supply_reward__destroyPerPoint : float;
                                  supply_transport__points : float)
  if supply_transport__points > 0.0 && evt.killer_eid != INVALID_ENTITY_ID
    let killerTeam = get_int(evt.killer_eid, "team") ?? TEAM_UNASSIGNED
    if killerTeam != TEAM_UNASSIGNED && killerTeam != supply_transport__team
      var targetEid = INVALID_ENTITY_ID
      var killer = killer_player(evt.killer_eid, targetEid)
      if killer != null
        reward_player(*killer, targetEid, SupplyRewardKind.DESTROY, supply_reward__destroyLoaded + int(supply_transport__points * supply_reward__destroyPerPoint))
