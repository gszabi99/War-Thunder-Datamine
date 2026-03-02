require ecs
require ecs.common
require app
require MPlayer
require Unit
require Grid
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

[es(tag=gameClient, on_appear)]
def squadmates_spawn_trace_check_init(evt : Event;
                                      animchar : AnimcharBaseComponent&;
                                      var dynamic_respawn__traceNodeId : int&;
                                      dynamic_respawn__traceNodeName = "Bip01 Head")
  dynamic_respawn__traceNodeId = geomtree_findNodeIndex(*animchar.nodeTree, dynamic_respawn__traceNodeName)

[es(REQUIRE=squad_dynamic_respawn, on_event=ParallelUpdateFrameDelayed)]
def save_dynamic_respawn_positions(evt : Event)
  query() <| $ [es] (unit__ref : UnitRef;
                     human_net_phys : HumanActor;
                     dynamic_respawn__posDiffCacheSaveSq : float;
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
      resize(dynamic_respawn__prevPositions, dynamic_respawn__prevPosCount)
      dynamic_respawn__curIterIdx = 0
      for spawn in dynamic_respawn__prevPositions
        spawn = humanPos
      return

    for i in range(dynamic_respawn__prevPosCount)
      let distSq = length_sq(dynamic_respawn__prevPositions[(dynamic_respawn__curIterIdx + i) % dynamic_respawn__prevPosCount] - humanPos)
      if distSq < dynamic_respawn__posDiffCacheSaveSq
        return

    dynamic_respawn__curIterIdx = (dynamic_respawn__curIterIdx + 1) % dynamic_respawn__prevPosCount
    dynamic_respawn__prevPositions[dynamic_respawn__curIterIdx] = humanPos


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


[es(tag=gameClient, on_event=ParallelUpdateFrameDelayed)]
def squadmates_spawn_position(evt : Event;
                              is_local : bool;
                              base_player_id : int;
                              var player_spawn__eid : EntityId&)
  if is_local
    return
  let player = player_get_by_id(base_player_id)
  if player == null || !player.isInHeroSquad
    return

  let ownedUnit = getOwnedUnit(*player)
  if ownedUnit != null && (ownedUnit.isHuman || ownedUnit.isTank)
    if !player_spawn__eid
      player_spawn__eid = createEntity("squad_dynamic_respawn") <| $(var init : ComponentsInitializer)
        set(init, "transform", ownedUnit.unitTm)
        set(init, "dynamic_respawn__active", ownedUnit.isAlive && !ownedUnit.isDelayed)
        set(init, "dynamic_respawn__unitEid", ownedUnit.eid)
        set(init, "dynamic_respawn__playerId", base_player_id)
    else
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

[es(REQUIRE=human)]
def squadmates_spawn_calculation_and_verify(var evt : EventCalcAndVerifySpawnTm;
                                            var dynamic_respawn__spawnOnUnitEid : EntityId?;
                                            dynamic_respawn__vehicleDistTraces : float;
                                            dynamic_respawn__humanDist : float;
                                            dynamic_respawn__vehicleFallbackOffset : float3)
  let spawnOnEid = evt.spawnOnEid
  evt.verified = false

  if !get_mission_spawn_on_squad_mode()
    if dynamic_respawn__spawnOnUnitEid != null
      *dynamic_respawn__spawnOnUnitEid = INVALID_ENTITY_ID
    return

  ecs::query(spawnOnEid) <| $ [es] (unit__ref : UnitRef;
                                    dynamic_respawn__onUnitAllowed : bool = true;
                                    dynamic_respawn__onUnitCanBlockSpawn : bool = false;
                                    dynamic_respawn__prevPositions : Point3List const?)
    let unit = unit__ref.unit
    if !unit.isAlive || unit.isDelayed || (!dynamic_respawn__onUnitAllowed && dynamic_respawn__onUnitCanBlockSpawn)
      return
    if unit.isHuman
      evt.spawnTm = unit.unitTm
      var verifyDebugDeltaSq = FLT_MAX
      let requestPosCorrectly = length(evt.requestPos) > 0.f 
      if dynamic_respawn__prevPositions != null && requestPosCorrectly
        for pos in *dynamic_respawn__prevPositions
          let distSq = length_sq(pos - evt.requestPos)
          if distSq < verifyDebugDeltaSq
            verifyDebugDeltaSq = distSq
          if distSq < 100.f 
            evt.verified = true
            evt.spawnTm[3] = evt.requestPos 
            print("[SPSQUAD] Spawn squadmate invis req (distance {length(evt.spawnTm[3] - unit.unitTm[3])}) verify delta {sqrt(distSq)}")
            break
      if !evt.verified
        var resPos : float3
        if find_random_point_around_circle(unit.unitTm[3], dynamic_respawn__humanDist, resPos)
          evt.spawnTm[3] = resPos
        dropObjectOnNavmesh(evt.spawnTm, 2.5, 1.)
        evt.verified = true
        if dynamic_respawn__prevPositions != null
          if !requestPosCorrectly
            print("[SPSQUAD] Player can't find invis point for spawn")
          else
            print("[SPSQUAD] Spawn squadmate invis FAIL POS: {evt.requestPos} verifyDebugDelta {sqrt(verifyDebugDeltaSq)}")

    elif unit.isTank
      evt.spawnTm = unit.unitTm
      let traceSpawnPoints = [float3(-1., 0., 0.), float3(0., 0., 1.), float3(0., 0., -1.)]
      let yExt = float3(0., 1., 0.)
      let pos = unit.pos + yExt
      for traceDir in traceSpawnPoints
        var t = dynamic_respawn__vehicleDistTraces
        var norm : float3
        if !traceray_normalized(pos, traceDir, t, norm, ETF_ALL | ETF_RI_PHYS)
          evt.verified = true
          evt.spawnTm = unit.unitTm
          evt.spawnTm[3] = evt.spawnTm[3] + traceDir * t
          dropObjectOnNavmesh(evt.spawnTm, 1.5, 1.)
          break
      if !evt.verified
        evt.spawnTm = unit.unitTm
        var resPos : float3
        if find_random_point_around_circle(unit.unitTm[3], dynamic_respawn__vehicleDistTraces, resPos)
          evt.spawnTm[3] = resPos
        else
          evt.spawnTm[3] = evt.spawnTm[3] + dynamic_respawn__vehicleFallbackOffset 
  if dynamic_respawn__spawnOnUnitEid != null
    *dynamic_respawn__spawnOnUnitEid = evt.verified ? spawnOnEid : INVALID_ENTITY_ID