require ecs
require ecs.common
require app
require MPlayer
require Unit
require Grid
require GridCollision
require Mission
require Dacoll
require HumanPhys
require DngHuman
require pathfinder
require IGroundModel
require %appGame.wt_events
require DagorMath
require GeomNodeTree
require AnimV20
require math.base
require DagorRandom
require matching
require %appGame.infantry.es.vehicle.vehicle_seats_common
require %daslib/type_traits

[es(tag=server, on_event=EventEcsMissionLoaded)]
def player_spawn_init_mode(evt : Event)
  if get_mission_spawn_on_squad_mode()
    createEntity("squad_spawner_mode")

[es(REQUIRE=squad_dynamic_respawn, on_appear, tag=gameClient)]
def recreate_player_on_spawn_mode_appear(evt : Event)
  query() <| $ [es(REQUIRE=base_player_id, REQUIRE_NOT=player_spawn__eid)] (eid : EntityId)
    addSubTemplate(eid, "player_with_squad_spawner")

[es(REQUIRE=base_player_id, REQUIRE_NOT=player_spawn__eid, on_appear, tag=gameClient)]
def recreate_on_spawn_mode_player_created(evt : Event;
                                          eid : EntityId)
  find_query() <| $ [es(REQUIRE=squad_dynamic_respawn)] ()
    addSubTemplate(eid, "player_with_squad_spawner")
    return true

def set_ui_minimap_indicator_scale_for_unit_eid(unit_eid : EntityId; scale : float; highlight : bool; selected : bool)
  query(unit_eid) <| $ [es] (var unit__ref : UnitRef)
    var unit = unit__ref.unit
    var gm = unit |> as_gm()
    if gm == null
      return
    gm.uiMinimapIndicatorScale = scale
    gm.uiMinimapIndicatorHighlight = highlight
    gm.uiMinimapIndicatorRespawnSelected = selected

def set_ui_minimap_indicator_blink_for_unit_eid(unit_eid : EntityId; time : float = 0.2f)
  query(unit_eid) <| $ [es] (var unit__ref : UnitRef)
    var unit = unit__ref.unit
    setBlinkTime(*unit, time)

def set_ui_minimap_indicator_respawn_candidate_for_unit_eid(unit_eid : EntityId; is_candidate : bool)
  query(unit_eid) <| $ [es] (var unit__ref : UnitRef)
    var unit = unit__ref.unit
    var gm = unit |> as_gm()
    if gm == null
      return
    gm.uiMinimapIndicatorRespawnCandidate = is_candidate

[es(tag=gameClient, on_appear)]
def squadmates_spawn_trace_check_init(evt : Event;
                                      animchar : AnimcharBaseComponent&;
                                      var dynamic_respawn__traceNodeId : int&;
                                      dynamic_respawn__traceNodeName = "Bip01 Head")
  dynamic_respawn__traceNodeId = geomtree_findNodeIndex(*animchar.nodeTree, dynamic_respawn__traceNodeName)

[es(track=dynamic_respawn__spawnOnUnitEid, on_appear)]
def set_prev_positions_on_spawn_on_unit(evt : Event;
                                        dynamic_respawn__spawnOnUnitEid : EntityId;
                                        dynamic_respawn__prevPosCount : int = 10;
                                        var dynamic_respawn__prevPositions aka spawn_dynamic_respawn__prevPositions : Point3List&;
                                        var dynamic_respawn__curIterIdx aka spawn_dynamic_respawn__curIterIdx : int&)
  if !!dynamic_respawn__spawnOnUnitEid
    query(dynamic_respawn__spawnOnUnitEid) <| $ [es] (dynamic_respawn__prevPositions aka on_dynamic_respawn__prevPositions : Point3List;
                                                      dynamic_respawn__curIterIdx aka on_dynamic_respawn__curIterIdx : int)
      spawn_dynamic_respawn__prevPositions := on_dynamic_respawn__prevPositions
      if length(spawn_dynamic_respawn__prevPositions) > dynamic_respawn__prevPosCount
        resize(spawn_dynamic_respawn__prevPositions, dynamic_respawn__prevPosCount)
      spawn_dynamic_respawn__curIterIdx = on_dynamic_respawn__curIterIdx

def private is_spawn_pos_banned_by_capzone(pos : float3; margin : float) : bool
  if !get_mission_forbid_spawn_on_squadmates_in_capzones()
    return false
  return is_pos_within_any_capzone_radius(pos, margin)

[es(REQUIRE=squad_dynamic_respawn, on_event=ParallelUpdateFrameDelayed)]
def save_dynamic_respawn_positions(evt : Event)
  query() <| $ [es] (unit__ref : UnitRef;
                     human_net_phys : HumanActor;
                     dynamic_respawn__posDiffCacheSaveSq : float;
                     dynamic_respawn__capzoneMargin : float = 10.;
                     dynamic_respawn__prevPosCount : int;
                     var dynamic_respawn__curIterIdx : int&;
                     var dynamic_respawn__prevPositions : Point3List&)
    let unit = unit__ref.unit
    if !unit.isAlive || unit.isDelayed || unit.isLoading
      return

    assume currentState = human_net_phys.phys.currentState
    var tm : float3x4
    currentState.location |> location_toTM(tm)
    let humanPos = tm[3] + float3(0., 1., 0.)

    if length(dynamic_respawn__prevPositions) < dynamic_respawn__prevPosCount
      if is_spawn_pos_banned_by_capzone(humanPos, dynamic_respawn__capzoneMargin)
        return
      resize(dynamic_respawn__prevPositions, dynamic_respawn__prevPosCount)
      dynamic_respawn__curIterIdx = 0
      for spawn in dynamic_respawn__prevPositions
        spawn = humanPos
      return

    for i in range(dynamic_respawn__prevPosCount)
      let distSq = length_sq(dynamic_respawn__prevPositions[(dynamic_respawn__curIterIdx + i) % dynamic_respawn__prevPosCount] - humanPos)
      if distSq < dynamic_respawn__posDiffCacheSaveSq
        return

    if is_spawn_pos_banned_by_capzone(humanPos, dynamic_respawn__capzoneMargin)
      return

    dynamic_respawn__curIterIdx = (dynamic_respawn__curIterIdx + 1) % dynamic_respawn__prevPosCount
    dynamic_respawn__prevPositions[dynamic_respawn__curIterIdx] = humanPos


def private copy_vehicle_spawn_positions_from(source_eid : EntityId;
                                              vehicle_pos : float3;
                                              max_dist_sq : float;
                                              var positions : Point3List&) : bool
  var copied = false
  query(source_eid) <| $ [es] (dynamic_respawn__prevPositions aka source_dynamic_respawn__prevPositions : Point3List)
    for trailPos in source_dynamic_respawn__prevPositions
      let horzDistSq = length_sq(float3(trailPos.x, vehicle_pos.y, trailPos.z) - vehicle_pos)
      if horzDistSq < square(3.5) || horzDistSq > max_dist_sq
        continue
      var pos = trailPos
      if !project_to_nearest_navmesh_point(pos, float3(1.5, 3., 1.5))
        continue
      let spawnPos = pos + float3(0., 1., 0.)
      var isDup = false
      for prev in positions
        if length_sq(prev - spawnPos) < square(1.5)
          isDup = true
          break
      if !isDup
        push(positions, spawnPos)
    copied = length(positions) > 0
  return copied

[es(REQUIRE=squad_dynamic_respawn, on_event=ParallelUpdateFrameDelayed)]
def save_dynamic_respawn_vehicle_positions(evt : Event)
  query() <| $ [es] (unit__ref : UnitRef;
                     vehicle_seats__seatEids : EidList;
                     vehicle__controlledByDriver : EntityId;
                     dynamic_respawn__vehiclePointsUpdatePeriod : float = 1.;
                     dynamic_respawn__vehiclePointsMaxDist : float = 25.;
                     var dynamic_respawn__vehiclePointsNextUpdateAtTime : float&;
                     var dynamic_respawn__curIterIdx : int&;
                     var dynamic_respawn__prevPositions : Point3List&)
    let curTime = get_sync_time()
    if dynamic_respawn__vehiclePointsNextUpdateAtTime > curTime
      return
    dynamic_respawn__vehiclePointsNextUpdateAtTime = curTime + dynamic_respawn__vehiclePointsUpdatePeriod
    clear(dynamic_respawn__prevPositions)
    dynamic_respawn__curIterIdx = 0
    let unit = unit__ref.unit
    if !unit.isAlive || unit.isDelayed || unit.isLoading
      return
    let vehiclePos = unit.pos
    let maxDistSq = square(dynamic_respawn__vehiclePointsMaxDist)
    if !copy_vehicle_spawn_positions_from(vehicle__controlledByDriver, vehiclePos, maxDistSq, dynamic_respawn__prevPositions)
      for seatEid in vehicle_seats__seatEids
        let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
        if ownerEid == INVALID_ENTITY_ID || ownerEid == vehicle__controlledByDriver || !(get_bool(ownerEid, "isAlive") ?? false)
          continue
        if copy_vehicle_spawn_positions_from(ownerEid, vehiclePos, maxDistSq, dynamic_respawn__prevPositions)
          break


[es(tag=server, REQUIRE=squad_dynamic_respawn, on_event=ParallelUpdateFrameDelayed)]
def check_dynamic_respawn_blocked_conditions(evt : Event)
  query() <| $ [es] (eid : EntityId;
                     transform aka spawn_transform : float3x4;
                     team aka spawn_team : int;
                     dynamic_respawn__onUnitAllowed : bool;
                     hitpoints__lastHitAtTime : float;
                     dynamic_respawn__lastHitEnemyAtTime : float;
                     dynamic_respawn__minDistToEnemy : float const?;
                     dynamic_respawn__lastEnemyHitTimeDelta : float const?;
                     dynamic_respawn__lastHitTimeDelta : float const?;
                     dynamic_respawn__updatePeriod : float = 1.f;
                     var dynamic_respawn_nextUpdateAtTime : float&)
    var res = true
    let curTime = get_sync_time()
    if dynamic_respawn_nextUpdateAtTime > curTime
      return
    else
      dynamic_respawn_nextUpdateAtTime = curTime + dynamic_respawn__updatePeriod * eid_frnd(eid)

    if dynamic_respawn__lastHitTimeDelta != null
      res &&= *dynamic_respawn__lastHitTimeDelta < (curTime - hitpoints__lastHitAtTime)
    if dynamic_respawn__lastEnemyHitTimeDelta != null
      res &&= *dynamic_respawn__lastEnemyHitTimeDelta < (curTime - dynamic_respawn__lastHitEnemyAtTime)

    if res && dynamic_respawn__minDistToEnemy != null
      for_each_entity_in_grid(ecs_hash("humans"), BSphere3(spawn_transform[3], *dynamic_respawn__minDistToEnemy), GridEntCheck.BOUNDING) <| $(enemy_eid : EntityId)
        if enemy_eid == eid || !res
          return
        query(enemy_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (transform aka enemy_transform : float3x4;
                                                            team aka enemy_team : int)
          if spawn_team == enemy_team
            return
          if length_sq(enemy_transform[3] - spawn_transform[3]) < square(*dynamic_respawn__minDistToEnemy)
            res = false
    if dynamic_respawn__onUnitAllowed != res
      set(eid, "dynamic_respawn__onUnitAllowed", res)


def private collect_extra_spawn_players(var extra_spawn_players : array<int>&)
  find_query() <| $ [es] (is_local : bool;
                          dynamic_respawn__extraSpawnPlayers : IntList)
    if !is_local
      return false
    for pid in dynamic_respawn__extraSpawnPlayers
      extra_spawn_players |> push(pid)
    return true

def private is_extra_spawn_player(player_id : int; extra_spawn_players : array<int>) : bool
  for pid in extra_spawn_players
    if pid == player_id
      return true
  return false

def private is_in_local_squad(p : MPlayer; local_player : MPlayer) : bool
  return p.squadId != INVALID_SQUAD_ID && p.squadId == local_player.squadId

def private refresh_extra_spawn_players(local_player_id : int; var extra_players : IntList&)
  let maxCount = get_mission_spawn_on_players_count()
  if maxCount <= 0
    return
  let localPlayer = player_get_by_id(local_player_id)
  if localPlayer == null
    return
  let localTeam = localPlayer.team

  var kept : array<int>
  for pid in extra_players
    let p = player_get_by_id(pid)
    if p != null && p.team == localTeam && !is_in_local_squad(*p, *localPlayer) && !p.isSpectator
      kept |> push(pid)
  if length(kept) != length(extra_players)
    extra_players |> clear()
    for pid in kept
      extra_players |> push(pid)

  var squadmatesCount = 0
  var candidates : array<int>
  query() <| $ [es(REQUIRE=player_spawn__eid)] (base_player_id aka candidate_base_player_id : int)
    let p = player_get_by_id(candidate_base_player_id)
    if p == null || p.isLocal || p.isSpectator || p.team != localTeam
      return
    if is_in_local_squad(*p, *localPlayer)
      squadmatesCount++
      return
    for pid in extra_players
      if pid == candidate_base_player_id
        return
    candidates |> push(candidate_base_player_id)

  let maxExtraCount = max(maxCount - squadmatesCount, 0)
  if length(extra_players) > maxExtraCount
    extra_players |> resize(maxExtraCount)
  while length(extra_players) < maxExtraCount && length(candidates) > 0
    let pick = rnd_int(0, length(candidates) - 1)
    extra_players |> push(candidates[pick])
    candidates[pick] = candidates[length(candidates) - 1]
    candidates |> pop()

[es(tag=gameClient, on_event=ParallelUpdateFrameDelayed)]
def extra_spawn_players_respawn_screen_open(evt : Event;
                                            is_local : bool;
                                            base_player_id : int;
                                            var dynamic_respawn__extraSpawnPlayers : IntList&;
                                            var dynamic_respawn__extraSpawnInRespawnScreen : bool&)
  if !is_local
    return
  let inRespawnScreen = is_respawn_screen()
  if inRespawnScreen && !dynamic_respawn__extraSpawnInRespawnScreen
    refresh_extra_spawn_players(base_player_id, dynamic_respawn__extraSpawnPlayers)
  dynamic_respawn__extraSpawnInRespawnScreen = inRespawnScreen

[es(tag=gameClient, REQUIRE=dynamic_respawn__extraSpawnPlayers, on_appear)]
def extra_spawn_players_on_player_appear(evt : Event)
  find_query() <| $ [es] (is_local : bool;
                          base_player_id : int;
                          var dynamic_respawn__extraSpawnPlayers : IntList&)
    if !is_local
      return false
    refresh_extra_spawn_players(base_player_id, dynamic_respawn__extraSpawnPlayers)
    return true

[es(tag=gameClient, REQUIRE=squad_dynamic_respawn, on_event=ParallelUpdateFrameDelayed)]
def squadmates_spawn_position(evt : Event)
  var extraSpawnPlayers : array<int>
  collect_extra_spawn_players(extraSpawnPlayers)
  let spawnOnPlayersCount = get_mission_spawn_on_players_count()
  let localPlayer = player_get_local()
  query() <| $ [es] (is_local : bool;
                     base_player_id : int;
                     var player_spawn__eid : EntityId&)
    if is_local
      return
    let player = player_get_by_id(base_player_id)
    if player == null
      return
    let canSpawnOnPlayer = player.isInHeroSquad || is_extra_spawn_player(base_player_id, extraSpawnPlayers)
    let isExtraSpawnCandidate = canSpawnOnPlayer && !player.isInHeroSquad
    let isLocalTeamPlayer = localPlayer != null && player.team == localPlayer.team
    let needSpawnerEntity = canSpawnOnPlayer || (spawnOnPlayersCount > 0 && isLocalTeamPlayer)

    let ownedUnit = getOwnedUnit(*player)
    if needSpawnerEntity && ownedUnit != null && (ownedUnit.isHuman || has(ownedUnit.eid, "vehicle_seats__seatEids"))
      if !player_spawn__eid
        player_spawn__eid = createEntity("squad_dynamic_respawn") <| $(var init : ComponentsInitializer)
          set(init, "transform", ownedUnit.unitTm)
          set(init, "dynamic_respawn__active", canSpawnOnPlayer && ownedUnit.isAlive && !ownedUnit.isDelayed)
          set(init, "dynamic_respawn__unitEid", ownedUnit.eid)
          set(init, "dynamic_respawn__playerId", base_player_id)
        set_ui_minimap_indicator_respawn_candidate_for_unit_eid(ownedUnit.eid, isExtraSpawnCandidate)
      elif !canSpawnOnPlayer
        query(player_spawn__eid) <| $ [es] (var dynamic_respawn__active : bool&;
                                            var dynamic_respawn__unitEid : EntityId&;
                                            dynamic_respawn__minimapScale : float)
          dynamic_respawn__active = false
          if dynamic_respawn__unitEid != INVALID_ENTITY_ID
            set_ui_minimap_indicator_scale_for_unit_eid(dynamic_respawn__unitEid, dynamic_respawn__minimapScale, false, false)
            set_ui_minimap_indicator_respawn_candidate_for_unit_eid(dynamic_respawn__unitEid, false)
            dynamic_respawn__unitEid = INVALID_ENTITY_ID
      else
        set_ui_minimap_indicator_respawn_candidate_for_unit_eid(ownedUnit.eid, isExtraSpawnCandidate)
        query(player_spawn__eid) <| $ [es] (var dynamic_respawn__active : bool&;
                                            var dynamic_respawn__blocked : bool&;
                                            var dynamic_respawn__unitEid : EntityId&;
                                            var transform : float3x4&;
                                            var dynamic_respawn__minimapScaleInited : bool&;
                                            dynamic_respawn__selected : bool;
                                            dynamic_respawn__highlight : bool;
                                            dynamic_respawn__minimapScale : float;
                                            dynamic_respawn__minimapSelectedScale : float)
          dynamic_respawn__active = ownedUnit.isAlive && !ownedUnit.isDelayed
          let respawnOnUnitAllowed = !(get_bool(ownedUnit.eid, "dynamic_respawn__onUnitAllowed") ?? true)
          let canBlockSpawn = get_bool(ownedUnit.eid, "dynamic_respawn__onUnitCanBlockSpawn") ?? false
          dynamic_respawn__blocked = canBlockSpawn && !respawnOnUnitAllowed
          if is_respawn_screen() && respawnOnUnitAllowed
            set_ui_minimap_indicator_blink_for_unit_eid(ownedUnit.eid)
          transform = ownedUnit.unitTm
          let scale = dynamic_respawn__selected ? dynamic_respawn__minimapSelectedScale : dynamic_respawn__minimapScale
          if dynamic_respawn__unitEid != ownedUnit.eid
            set_ui_minimap_indicator_scale_for_unit_eid(dynamic_respawn__unitEid, 1., dynamic_respawn__highlight, false)
            set_ui_minimap_indicator_respawn_candidate_for_unit_eid(dynamic_respawn__unitEid, false)
            set_ui_minimap_indicator_scale_for_unit_eid(ownedUnit.eid, scale, dynamic_respawn__highlight, dynamic_respawn__selected)
            dynamic_respawn__unitEid = ownedUnit.eid
          elif !dynamic_respawn__minimapScaleInited
            dynamic_respawn__minimapScaleInited = true
            set_ui_minimap_indicator_scale_for_unit_eid(dynamic_respawn__unitEid, scale, dynamic_respawn__highlight, dynamic_respawn__selected)
    elif !!player_spawn__eid
      query(player_spawn__eid) <| $ [es] (var dynamic_respawn__active : bool&;
                                          var dynamic_respawn__unitEid : EntityId&;
                                          dynamic_respawn__minimapScale : float)
        dynamic_respawn__active = false
        set_ui_minimap_indicator_scale_for_unit_eid(dynamic_respawn__unitEid, dynamic_respawn__minimapScale, false, false)
        set_ui_minimap_indicator_respawn_candidate_for_unit_eid(dynamic_respawn__unitEid, false)
        dynamic_respawn__unitEid = INVALID_ENTITY_ID

[es(tag=gameClient, on_disappear)]
def squadmates_spawn_position_destroy(evt : Event;
                                      var player_spawn__eid : EntityId&)
  destroyEntity(player_spawn__eid)
  player_spawn__eid = INVALID_ENTITY_ID

[es(tag=gameClient, track=(dynamic_respawn__selected, dynamic_respawn__highlight))]
def squadmates_spawn_selected(evt : Event;
                              dynamic_respawn__selected : bool;
                              dynamic_respawn__highlight : bool;
                              dynamic_respawn__unitEid : EntityId;
                              dynamic_respawn__minimapScale : float;
                              dynamic_respawn__minimapSelectedScale : float)
  let scale = dynamic_respawn__selected ? dynamic_respawn__minimapSelectedScale : dynamic_respawn__minimapScale
  set_ui_minimap_indicator_scale_for_unit_eid(dynamic_respawn__unitEid, scale, dynamic_respawn__highlight, dynamic_respawn__selected)


[es(on_event=EventResetSpawnOnUnitEid)]
def squadmates_spawn_calculation_reset(evt : Event;
                                       var dynamic_respawn__spawnOnUnitEid : EntityId&)
  dynamic_respawn__spawnOnUnitEid = INVALID_ENTITY_ID

[es(track=dynamic_respawn__spawnOnUnitEid, on_appear)]
def set_phys_height_on_spawn_selected(evt : Event;
                                      var human_input__standState : int?;
                                      var human_net_phys aka base_human_net_phys : HumanActor;
                                      dynamic_respawn__spawnOnUnitEid : EntityId)
  assume ct = base_human_net_phys.phys.producedCT
  assume aCt = base_human_net_phys.phys.appliedCT
  assume baseCurState = base_human_net_phys.phys.currentState
  assume basePrevState = base_human_net_phys.phys.previousState
  if !!dynamic_respawn__spawnOnUnitEid
    query(dynamic_respawn__spawnOnUnitEid) <| $ [es] (human_net_phys aka spawn_human_net_phys : HumanActor)
      assume spawnCurState = spawn_human_net_phys.phys.currentState
      basePrevState.moveState = spawnCurState.moveState
      baseCurState.moveState = spawnCurState.moveState
      basePrevState.height = spawnCurState.height
      baseCurState.height = spawnCurState.height
      let isCrouch = spawnCurState.isCrouch
      let isCrawl = spawnCurState.isCrawl
      aCt |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, isCrouch)
      aCt |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, isCrawl)
      ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, isCrouch)
      ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, isCrawl)
      if human_input__standState != null
        if isCrawl
          *human_input__standState = int(HumanPhysControlType.HCT_CRAWL)
        elif isCrouch
          *human_input__standState = int(HumanPhysControlType.HCT_CROUCH)
        else
          *human_input__standState = 0
  else
    if human_input__standState != null
      *human_input__standState = 0
    aCt |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, false)
    aCt |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, false)
    ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, false)
    ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, false)
    basePrevState.height = 1.f
    baseCurState.height = 1.f

def private is_spawn_pos_blocked_by_vehicle(pos : float3) : bool
  let fromPos = pos + float3(0., 6., 0.)
  let traceDir = float3(0., -1., 0.)
  var t = 6.5
  return trace_entities_in_grid_by_capsule(ecs_hash("vehicles"), fromPos, traceDir, t, 0.35, INVALID_ENTITY_ID)

def private try_spawn_into_free_seat(soldier_eid : EntityId; vehicle_eid : EntityId; var spawn_tm : float3x4&) : int
  var seatNo = -1
  query(vehicle_eid) <| $ [es] (unit__ref : UnitRef;
                                vehicle_seats__seatEids : EidList)
    let unit = unit__ref.unit
    if !unit.isAlive || unit.isDelayed
      return
    seatNo = find_free_passenger_seat_no(soldier_eid, vehicle_seats__seatEids)
    if seatNo < 0
      return
    spawn_tm = unit.unitTm
    enter_vehicle_now(soldier_eid, vehicle_eid, seatNo)
  return seatNo

[unused_argument(dynamic_respawn__capzoneMargin), es(REQUIRE=human)]
def squadmates_spawn_calculation_and_verify(var evt : EventCalcAndVerifySpawnTm;
                                            eid : EntityId;
                                            var dynamic_respawn__spawnOnUnitEid : EntityId?;
                                            dynamic_respawn__vehicleDistTraces : float;
                                            dynamic_respawn__humanDist : float;
                                            dynamic_respawn__vehicleFallbackOffset : float3;
                                            dynamic_respawn__fallbackMinDistToUnitSq : float = 225.;
                                            dynamic_respawn__capzoneMargin : float = 10.)
  let spawnOnEid = evt.spawnOnEid

  if !has(spawnOnEid, "unit__ref")
    return

  evt.verified = false

  if !get_mission_spawn_on_squad_mode()
    if dynamic_respawn__spawnOnUnitEid != null
      *dynamic_respawn__spawnOnUnitEid = INVALID_ENTITY_ID
    return

  ecs::query(spawnOnEid) <| $ [es] (unit__ref : UnitRef;
                                    dynamic_respawn__onUnitAllowed : bool = true;
                                    dynamic_respawn__onUnitCanBlockSpawn : bool = false;
                                    dynamic_respawn__prevPositions : Point3List const?;
                                    human_anim__vehicleSelected : EntityId const?;
                                    vehicle_seats__seatEids : EidList const?)
    let unit = unit__ref.unit
    if !unit.isAlive || unit.isDelayed || (!dynamic_respawn__onUnitAllowed && dynamic_respawn__onUnitCanBlockSpawn)
      print("[SPSQUAD] spawn on unit {spawnOnEid} rejected: alive={unit.isAlive} delayed={unit.isDelayed} allowed={dynamic_respawn__onUnitAllowed} canBlock={dynamic_respawn__onUnitCanBlockSpawn}")
      return
    let unitPos = unit.unitTm[3]
    if unit.isHuman
      let vehicleEid = human_anim__vehicleSelected ?? INVALID_ENTITY_ID
      if vehicleEid != INVALID_ENTITY_ID
        let seatNo = try_spawn_into_free_seat(eid, vehicleEid, evt.spawnTm)
        if seatNo >= 0
          evt.verified = true
          print("[SPSQUAD] spawn unit {eid} on passenger {spawnOnEid} VERIFIED seatNo={seatNo} vehicle={vehicleEid} unitPos=({unitPos})")
          return
      evt.spawnTm = unit.unitTm
      var verifyDebugDeltaSq = FLT_MAX
      let requestPosCorrectly = length(evt.requestPos) > 0.f 
      if dynamic_respawn__prevPositions != null && requestPosCorrectly && !is_spawn_pos_banned_by_capzone(evt.requestPos, dynamic_respawn__capzoneMargin) && !is_spawn_pos_blocked_by_vehicle(evt.requestPos)
        for pos in *dynamic_respawn__prevPositions
          let distSq = length_sq(pos - evt.requestPos)
          if distSq < verifyDebugDeltaSq
            verifyDebugDeltaSq = distSq
          if distSq < 100.f 
            evt.verified = true
            evt.spawnTm[3] = evt.requestPos 
            print("[SPSQUAD] spawn unit {eid} on human {spawnOnEid} VERIFIED requestPos=({evt.requestPos}) unitPos=({unitPos}) dist={length(evt.spawnTm[3] - unitPos)} verifyDelta={sqrt(distSq)}")
            break
      if !evt.verified
        var posForSearch = unitPos
        if dynamic_respawn__prevPositions != null && length(*dynamic_respawn__prevPositions) > 0
          var closestDistSq = FLT_MAX
          for pos in *dynamic_respawn__prevPositions
            let dSq = length_sq(pos - unitPos)
            if dSq >= dynamic_respawn__fallbackMinDistToUnitSq && dSq < closestDistSq
              closestDistSq = dSq
              posForSearch = pos
        var resPos : float3
        let foundNavmesh = find_random_point_around_circle(posForSearch, dynamic_respawn__humanDist, resPos)
        if foundNavmesh
          evt.spawnTm[3] = resPos
        dropObjectOnNavmesh(evt.spawnTm, 2.5, 1.)
        if is_spawn_pos_banned_by_capzone(evt.spawnTm[3], dynamic_respawn__capzoneMargin) || is_spawn_pos_blocked_by_vehicle(evt.spawnTm[3])
          print("[SPSQUAD] spawn unit {eid} on human {spawnOnEid} FALLBACK REJECTED (capzone or blocked by vehicle) fallbackPos=({evt.spawnTm[3]}) unitPos=({unitPos})")
          return
        evt.verified = true
        let fallbackPos = evt.spawnTm[3]
        if dynamic_respawn__prevPositions != null
          if !requestPosCorrectly
            print("[SPSQUAD] spawn unit {eid} on human {spawnOnEid} FALLBACK (no client invis point) unitPos=({unitPos}) fallbackPos=({fallbackPos}) navmesh={foundNavmesh}")
          else
            print("[SPSQUAD] spawn unit {eid} on human {spawnOnEid} FALLBACK (verify failed) requestPos=({evt.requestPos}) unitPos=({unitPos}) fallbackPos=({fallbackPos}) closestDelta={sqrt(verifyDebugDeltaSq)} navmesh={foundNavmesh}")

    elif vehicle_seats__seatEids != null
      let seatNo = try_spawn_into_free_seat(eid, spawnOnEid, evt.spawnTm)
      if seatNo >= 0
        evt.verified = true
        print("[SPSQUAD] spawn unit {eid} on transport {spawnOnEid} VERIFIED seatNo={seatNo} unitPos=({unitPos})")
      else
        evt.spawnTm = unit.unitTm
        let requestPosCorrectly = length(evt.requestPos) > 0.f 
        if dynamic_respawn__prevPositions != null && requestPosCorrectly && !is_spawn_pos_banned_by_capzone(evt.requestPos, dynamic_respawn__capzoneMargin) && !is_spawn_pos_blocked_by_vehicle(evt.requestPos)
          for pos in *dynamic_respawn__prevPositions
            if length_sq(pos - evt.requestPos) < 100.f 
              evt.verified = true
              evt.spawnTm[3] = evt.requestPos
              print("[SPSQUAD] spawn unit {eid} on transport {spawnOnEid} VERIFIED nearby (no free seat, client invis point) requestPos=({evt.requestPos}) unitPos=({unitPos})")
              break
        if !evt.verified && dynamic_respawn__prevPositions != null && length(*dynamic_respawn__prevPositions) > 0
          let pick = rnd_int(0, length(*dynamic_respawn__prevPositions) - 1)
          let fallbackPos = (*dynamic_respawn__prevPositions)[pick]
          if !is_spawn_pos_banned_by_capzone(fallbackPos, dynamic_respawn__capzoneMargin) && !is_spawn_pos_blocked_by_vehicle(fallbackPos)
            evt.verified = true
            evt.spawnTm[3] = fallbackPos
            print("[SPSQUAD] spawn unit {eid} on transport {spawnOnEid} FALLBACK nearby (no free seat, server candidate) fallbackPos=({fallbackPos}) unitPos=({unitPos})")
        if !evt.verified
          let traceSpawnPoints = [float3(-1., 0., 0.), float3(0., 0., 1.), float3(0., 0., -1.)]
          let yExt = float3(0., 1., 0.)
          let pos = unit.pos + yExt
          for traceDir in traceSpawnPoints
            var t = dynamic_respawn__vehicleDistTraces
            var norm : float3
            if !traceray_normalized(pos, traceDir, t, norm, ETF_ALL | ETF_RI_PHYS)
              evt.spawnTm = unit.unitTm
              evt.spawnTm[3] = evt.spawnTm[3] + traceDir * t
              dropObjectOnNavmesh(evt.spawnTm, 1.5, 1.)
              if is_spawn_pos_blocked_by_vehicle(evt.spawnTm[3])
                continue
              evt.verified = true
              print("[SPSQUAD] spawn unit {eid} on transport {spawnOnEid} VERIFIED nearby (no free seat) traceDir=({traceDir}) finalPos=({evt.spawnTm[3]}) unitPos=({unitPos})")
              break
        if !evt.verified
          evt.spawnTm = unit.unitTm
          var resPos : float3
          if find_random_point_around_circle(unitPos, dynamic_respawn__vehicleDistTraces, resPos)
            evt.spawnTm[3] = resPos
            print("[SPSQUAD] spawn unit {eid} on transport {spawnOnEid} FALLBACK (navmesh, no free seat) fallbackPos=({resPos}) unitPos=({unitPos})")
          else
            evt.spawnTm[3] = evt.spawnTm[3] + dynamic_respawn__vehicleFallbackOffset 
            print("[SPSQUAD] spawn unit {eid} on transport {spawnOnEid} FALLBACK (offset, no free seat) fallbackPos=({evt.spawnTm[3]}) unitPos=({unitPos})")
  if dynamic_respawn__spawnOnUnitEid != null
    *dynamic_respawn__spawnOnUnitEid = evt.verified ? spawnOnEid : INVALID_ENTITY_ID