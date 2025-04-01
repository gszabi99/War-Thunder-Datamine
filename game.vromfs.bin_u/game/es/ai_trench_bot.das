options always_export_initializer = true

require ecs
require ecs.common
require app
require walkerai
require pathfinder
require BehNodes
require DagorDataBlock

require %appGame.es.team_common
require math
require math.base
require DagorRandom
require DagorMath
require Dacoll
require RendInst
require CollRes
require AnimV20
require Grid
require GridCollision


require %appGame.es.ai_danger_common
require %appGame.es.walker_common

require DngWalkerai
require DngHuman
require HumanPhys
require DagorSystem
require %appGame.es.ai_trench_bot_common
require %game.events
require Mission


[beh_node(name="traversePoint3List")]
class TraversePoint3List : BehNodeAdapter
  toParam : int
  pointsLeftParam : int
  compName : string
  compNameHash : uint

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "toParam") >= 0
      toParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toParam", ""), float3())
    if datablock_find_param(data, "pointsLeftParam") >= 0
      pointsLeftParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "pointsLeftParam", ""), 0)
    compName = datablock_getStr(data, "compName", "")
    compNameHash = ecs_hash(compName)

  def override update(dt : float) : EBehResult
    let fromEid = beh_tree_eid(owner)
    var ecsList = getRW_ecs_Point3List(fromEid, compName, compNameHash)
    if ecsList == null
      return EBehResult.ER_FAILED
    if empty(*ecsList)
      owner.blackBoard |> set(pointsLeftParam, 0)
      return EBehResult.ER_FAILED
    let idx = length(*ecsList) - 1
    let elem = (*ecsList)[idx]
    erase(*ecsList, idx)
    owner.blackBoard |> set(toParam, elem)
    owner.blackBoard |> set(pointsLeftParam, idx + 1)
    return EBehResult.ER_SUCCESS


def calc_next_spawn_delay(trench_eid : EntityId)
  var res = 0.0
  query(trench_eid) <| $ [es] (trench_bot_spawner__botCount : int;
                               trench_bot_spawner__maxBotCount : int;
                               trench_bot_spawner__spawnDelay : float2)
    assume delay = trench_bot_spawner__spawnDelay
    res = trench_bot_spawner__botCount < trench_bot_spawner__maxBotCount ? rnd_float(delay.x, delay.y) : FLT_MAX
  return res


def make_path_to_cover_impl(waypoint_eid : EntityId;
                            var path : Point3List&)
  if waypoint_eid == INVALID_ENTITY_ID
    return
  query(waypoint_eid) <| $ [es] (transform : float3x4;
                                 trench_waypoint__prevEid : EntityId;
                                 trench_waypoint__blocked : bool)
    if !trench_waypoint__blocked
      push(path, transform[3])
    make_path_to_cover_impl(trench_waypoint__prevEid, path)


def make_path_to_cover(cover_pos : float3;
                       cover_entry_pos : float3;
                       waypoint_eid : EntityId;
                       var path_to_cover : Point3List&)
  push(path_to_cover, cover_pos)
  push(path_to_cover, cover_entry_pos)
  make_path_to_cover_impl(waypoint_eid, path_to_cover)


def get_enemy_team(team : int)
  return 3 - team


def spawn_trench_bot(trench_eid : EntityId)
  var success = false
  query(trench_eid) <| $ [es] (team : int;
                               transform aka spawner_transform : float3x4;
                               trench_bot_spawner__id : int;
                               trench_bot_spawner__active : bool;
                               trench_bot_spawner__blocked : bool;
                               trench_bot_spawner__botTemplate : string;
                               trench_bot_spawner__equipTemplates : StringList;
                               trench_bot_spawner__equipTemplateProbabilities : FloatList;
                               trench_bot_spawner__stormedSpawnerId : int;
                               trench_bot_spawner__stormedSpawnerEid : EntityId;
                               var trench_bot_spawner__botCount : int&;
                               var trench_bot_spawner__nextSpawnAt : float&)
    if !trench_bot_spawner__active || trench_bot_spawner__blocked
      trench_bot_spawner__nextSpawnAt = get_sync_time() + calc_next_spawn_delay(trench_eid)
      return

    var availableTrenchCoverEids : array<EntityId>
    query() <| $ [es(REQUIRE=transform)] (eid : EntityId;
                                          trench_cover__spawnerId : int;
                                          trench_cover__active : bool;
                                          trench_cover__occupied : bool;
                                          trench_cover__blocked : bool)
      if trench_cover__active && !trench_cover__occupied && !trench_cover__blocked && trench_cover__spawnerId == trench_bot_spawner__id
        push(availableTrenchCoverEids, eid)
    if empty(availableTrenchCoverEids)
      trench_bot_spawner__nextSpawnAt = get_sync_time() + calc_next_spawn_delay(trench_eid)
      return

    let chosenCoverEid = availableTrenchCoverEids[rnd_int(0, length(availableTrenchCoverEids) - 1)]
    query(chosenCoverEid) <| $ [es] (transform aka cover_transform : float3x4;
                                     trench_cover__id aka this_trench_cover__id : int;
                                     trench_cover__sideDirMode : int;
                                     trench_cover__lookAtTargetEid : EntityId;
                                     trench_cover__lookAtCrouchingOffset : float2;
                                     trench_cover__lookAtCrouchingVertOffsetRange : float2;
                                     trench_cover__entryOffset : float2;
                                     trench_cover__waypointEid : EntityId;
                                     var trench_cover__occupied : bool&)
      var stormedCoverEid = INVALID_ENTITY_ID
      var stormedCoverPosition = float3()
      var stormedCover2Position = float3()
      var stormedPosition = float3()
      let isStormedSpawnerSpawning = (get_int(trench_bot_spawner__stormedSpawnerEid, "trench_bot_spawner__maxBotCount") ?? 0) > 0
      find_query() <| $ [es(REQUIRE=transform)] (eid : EntityId;
                                                 transform : float3x4;
                                                 trench_cover__id : int;
                                                 trench_cover__spawnerId : int)
        if trench_cover__spawnerId == trench_bot_spawner__stormedSpawnerId
          if trench_cover__id == this_trench_cover__id
            stormedCoverEid = eid
            stormedCoverPosition = transform[3]
          elif isStormedSpawnerSpawning && trench_cover__id == this_trench_cover__id + 1
            stormedCover2Position = transform[3]
        return stormedCoverEid != INVALID_ENTITY_ID && (!isStormedSpawnerSpawning || stormedCover2Position != float3())
      if isStormedSpawnerSpawning && stormedCover2Position != float3()
        stormedPosition = 0.5 * (stormedCoverPosition + stormedCover2Position)
        query(stormedCoverEid) <| $ [es] (trench_cover__entryOffset aka stormed_trench_cover__entryOffset : float2;
                                          trench_cover__sideDirMode aka stormed_trench_cover__sideDirMode : int;
                                          trench_cover__lookAtCrouchingOffset aka stormed_trench_cover__lookAtCrouchingOffset : float2;
                                          trench_cover__lookAtCrouchingVertOffsetRange aka stormed_trench_cover__lookAtCrouchingVertOffsetRange : float2;
                                          trench_cover__lookAtTargetEid aka stormed_trench_cover__lookAtTargetEid : EntityId;
                                          trench_cover__waypointEid aka stormed_trench_cover__waypointEid : EntityId)
          let spawnerTm = (*get_TMatrix(trench_bot_spawner__stormedSpawnerEid, "transform"))
          let waypointTm = get_TMatrix(stormed_trench_cover__waypointEid, "transform") ?? spawnerTm
          let additionalPositions = get_additional_trench_positions(stormedPosition, waypointTm[3], chosenCoverEid, stormed_trench_cover__sideDirMode,
            stormed_trench_cover__entryOffset, stormed_trench_cover__lookAtTargetEid, stormed_trench_cover__lookAtCrouchingOffset, stormed_trench_cover__lookAtCrouchingVertOffsetRange)
          stormedPosition = additionalPositions.storm
        project_to_nearest_navmesh_point(stormedPosition, float3(3., 0.5, 3.))
      else
        stormedPosition = stormedCoverPosition
      let waypointTm = get_TMatrix(trench_cover__waypointEid, "transform") ?? spawner_transform
      let additionalPositions = get_additional_trench_positions(cover_transform[3], waypointTm[3], stormedCoverEid, trench_cover__sideDirMode,
        trench_cover__entryOffset, trench_cover__lookAtTargetEid, trench_cover__lookAtCrouchingOffset, trench_cover__lookAtCrouchingVertOffsetRange)
      trench_cover__occupied = true
      let equipTemplate = make_trench_bot_equip_template(trench_bot_spawner__equipTemplates, trench_bot_spawner__equipTemplateProbabilities)
      let templ = empty(equipTemplate) ? trench_bot_spawner__botTemplate : add_sub_template_name(trench_bot_spawner__botTemplate, equipTemplate)
      createEntity(templ) <| $(init)
        set(init, "transform", spawner_transform)
        set(init, "team", team)
        set(init, "unit_params__armyId", team)
        set(init, "spawn_immunity__timer", 0.f)
        set(init, "trench_bot__spawnerEid", trench_eid)
        set(init, "trench_bot__occupiedSpawnerEid", trench_eid)
        set(init, "trench_bot__coverEid", chosenCoverEid)
        set(init, "trench_bot__finalPosition", cover_transform[3])
        set(init, "trench_bot__lookAtPosition", additionalPositions.lookAt)
        set(init, "trench_bot__lookAtPositionCrouching", additionalPositions.lookAtCrouching)
        set(init, "trench_bot__stormedCoverEid", stormedCoverEid)
        set(init, "trench_bot__stormedPosition", stormedPosition)
        using() <| $(var path_to_cover : Point3List)
          make_path_to_cover(cover_transform[3], additionalPositions.coverEntry, trench_cover__waypointEid, path_to_cover)
          set(init, "trench_bot__pathToCover", path_to_cover)
        set(init, "beh_tree__blackboard__enemyTeam", get_enemy_team(team))
        set(init, "beh_tree__enabled", true)
      success = true

    if success
      trench_bot_spawner__botCount++
    trench_bot_spawner__nextSpawnAt = get_sync_time() + calc_next_spawn_delay(trench_eid)


[es(tag=render, REQUIRE_NOT=deadEntity, no_order)]
def trench_bot_visible_distance_update(info : ParallelUpdateFrameDelayed;
                                       trench_bot__generalState : int;
                                       var animchar__considerAsVisibleDistance : float&;
                                       trench_bot__activeStateVisibleDist = 1000.f;
                                       trench_bot__passiveStateVisibleDist = 150.f)
  animchar__considerAsVisibleDistance = trench_bot__generalState == 0 ? trench_bot__passiveStateVisibleDist : trench_bot__activeStateVisibleDist


[es(tag=server, no_order)]
def trench_bot_spawner_update(info : UpdateStageInfoAct;
                              eid : EntityId;
                              trench_bot_spawner__nextSpawnAt : float;
                              trench_bot_spawner__gridDetectorAreaEids : EidList;
                              var trench_bot_spawner__humanPresenceCode : int&;
                              var trench_bot_spawner__vehiclePresenceCode : int&)
  if trench_bot_spawner__nextSpawnAt < info.curTime
    spawn_trench_bot(eid)

  trench_bot_spawner__humanPresenceCode = 0
  trench_bot_spawner__vehiclePresenceCode = 0
  for detectorEid in trench_bot_spawner__gridDetectorAreaEids
    query(detectorEid) <| $ [es] (grid_detector_area__teamPresence : BoolList;
                                  grid_detector_area__gridType : string)
      let detectorCode = ((grid_detector_area__teamPresence[1] ? 1 : 0) | (grid_detector_area__teamPresence[2] ? 2 : 0))
      if grid_detector_area__gridType == "humans"
        trench_bot_spawner__humanPresenceCode = trench_bot_spawner__humanPresenceCode | detectorCode
      elif grid_detector_area__gridType == "vehicles"
        trench_bot_spawner__vehiclePresenceCode = trench_bot_spawner__vehiclePresenceCode | detectorCode


[es(tag=server)]
def trench_bot_timed_storm_update(info : UpdateStageInfoAct;
                                  trench_bot_timed_storm__minInterval : float;
                                  var trench_bot_timed_storm__stormAt : FloatList&;
                                  var trench_bot_timed_storm__spawnerEidPairs : IPoint2List&)
  for stormAt, eidPair in trench_bot_timed_storm__stormAt, trench_bot_timed_storm__spawnerEidPairs
    if stormAt > info.curTime
      continue
    query(EntityId(uint(eidPair.x))) <| $ [es] (team aka offender_team : int;
                                                trench_bot_spawner__id aka offender_trench_bot_spawner__id : int;
                                                trench_bot_spawner__botCount aka offender_trench_bot_spawner__botCount : int;
                                                trench_bot_spawner__maxBotCount aka offender_trench_bot_spawner__maxBotCount : int;
                                                trench_bot_spawner__minCapacityToStorm aka offender_trench_bot_spawner__minCapacityToStorm : float;
                                                trench_bot_spawner__humanPresenceCode aka offender_trench_bot_spawner__humanPresenceCode : int)
      let offenderHumanDetectorCode = get_enemy_team(offender_team) == 1 ? 1 : 2
      if (offender_trench_bot_spawner__humanPresenceCode & offenderHumanDetectorCode) != 0 || float(offender_trench_bot_spawner__botCount) / float(offender_trench_bot_spawner__maxBotCount) < offender_trench_bot_spawner__minCapacityToStorm
        stormAt = info.curTime
        return
      query(EntityId(uint(eidPair.y))) <| $ [es] (team aka defender_team : int;
                                                  trench_bot_spawner__botCount aka deffender_trench_bot_spawner__botCount : int;
                                                  trench_bot_spawner__maxBotCount aka deffender_trench_bot_spawner__maxBotCount : int;
                                                  trench_bot_spawner__minCapacityToBeStormed aka defender_trench_bot_spawner__minCapacityToBeStormed : float;
                                                  trench_bot_spawner__humanPresenceCode aka defender_trench_bot_spawner__humanPresenceCode : int)
        let defenderHumanDetectorCode = get_enemy_team(defender_team) == 1 ? 1 : 2
        if (defender_trench_bot_spawner__humanPresenceCode & defenderHumanDetectorCode) != 0 || float(deffender_trench_bot_spawner__botCount) / float(deffender_trench_bot_spawner__maxBotCount) < defender_trench_bot_spawner__minCapacityToBeStormed
          stormAt = info.curTime
          return
        trench_storm(offender_trench_bot_spawner__id)
        stormAt = info.curTime + trench_bot_timed_storm__minInterval
        swap(eidPair.x, eidPair.y)


[es(tag=server)]
def trench_bot_storm_on_zone_captured_debug(evt : EventZoneCaptured)
  debug("EventZoneCaptured: {evt.areaId} {evt.army} {evt.wasArmy}")


[es(tag=server)]
def trench_bot_storm_on_zone_captured(evt : EventZoneCaptured;
                                      team : int;
                                      trench_bot_spawner__id : int;
                                      trench_bot_spawner__stormOnCapturedAreaNames : StringList)
  for areaName in trench_bot_spawner__stormOnCapturedAreaNames
    debug("EventZoneCaptured: {evt.areaId} {evt.army} {evt.wasArmy} | testing against spawner {trench_bot_spawner__id} ({areaName})")
    if evt.areaId == get_area_id(string(areaName)) && int(evt.army) == team
      debug("Trench storm started, trench_bot_spawner__id = {trench_bot_spawner__id}")
      trench_storm(trench_bot_spawner__id)


[es(tag=server, no_order)]
def trench_bot_general_state(info : UpdateStageInfoAct;
                             transform : float3x4;
                             trench_bot__finalPosition : float3;
                             trench_bot__spawnerEid : EntityId;
                             trench_bot__occupiedSpawnerEid : EntityId;
                             var trench_bot__generalState : int&;
                             trench_bot__distanceToOtherSpawnerThreshold : float = 5.0)
  if trench_bot__generalState == 3
    return
  if trench_bot__occupiedSpawnerEid == trench_bot__spawnerEid
    trench_bot__generalState = 0
  elif distance_sq(transform[3], trench_bot__finalPosition) >= square(trench_bot__distanceToOtherSpawnerThreshold)
    let zoneIdCapture = get_int(trench_bot__spawnerEid, "trench_bot_spawner__stormOnZoneIdCapture") ?? -1
    if zoneIdCapture < 0
      trench_bot__generalState = 1
    else
      trench_bot__generalState = 2
  else
    trench_bot__generalState = 3


def detach_trench_bot(eid : EntityId)
  query(eid) <| $ [es] (trench_bot__spawnerEid : EntityId;
                        var trench_bot__coverEid : EntityId&)
    query(trench_bot__coverEid) <| $ [es] (var trench_cover__occupied : bool&)
      trench_cover__occupied = false
    trench_bot__coverEid = INVALID_ENTITY_ID
    query(trench_bot__spawnerEid) <| $ [es] (var trench_bot_spawner__botCount : int&;
                                             var trench_bot_spawner__nextSpawnAt : float&)
      trench_bot_spawner__botCount--
      trench_bot_spawner__nextSpawnAt = min(trench_bot_spawner__nextSpawnAt, get_sync_time() + calc_next_spawn_delay(trench_bot__spawnerEid))


def calc_unit_tm_and_oobb(tm : float3x4; var unit_tm : float3x4&; var oobb : BBox3&)
  unit_tm = tm
  let xLen = length(unit_tm[0])
  let yLen = length(unit_tm[1])
  let zLen = length(unit_tm[2])
  unit_tm[0] /= xLen
  unit_tm[1] /= yLen
  unit_tm[2] /= zLen
  let extents = float3(xLen, yLen, zLen)
  oobb = BBox3(-0.5 * extents, 0.5 * extents)


[es(tag=server, on_appear, REQUIRE=trench_bot)]
def trench_bot_on_appear(evt : Event;
                         var walker_agent : EntityAgent&)
  query() <| $ [es] (transform : float3x4;
                     trench_nav_area__id : int;
                     trench_nav_area__weight : float2)
    var tm : float3x4
    var oobb = BBox3()
    calc_unit_tm_and_oobb(transform, tm, oobb)
    walker_agent_nav_areaUpdateBox(walker_agent, trench_nav_area__id, tm, oobb,
                                   trench_nav_area__weight.x, trench_nav_area__weight.y, false)


[es(tag=server, on_appear, REQUIRE=trenchObstacle)]
def trench_obstacle_init(evt : Event;
                         transform : float3x4)
  var tm : float3x4
  var oobb = BBox3()
  calc_unit_tm_and_oobb(transform, tm, oobb)


[es(tag=server, on_disappear, REQUIRE_NOT=deadEntity)]
def trench_bot_on_disappear(evt : Event;
                            eid : EntityId)
  detach_trench_bot(eid)


[es(tag=server, on_event=EventLevelLoaded)]
def trenches_init(evt : Event)
  var spawnerIdEidMap : table<int, EntityId>
  var detectorIdEidMap : table<int, EntityId>
  var targetIdEidMap : table<int, EntityId>
  var coverIdEidMap : table<string, EntityId>
  var waypointIdEidMap : table<string, EntityId>
  query() <| $ [es(REQUIRE=transform)] (eid : EntityId;
                                        trench_bot_spawner__id : int)
    if trench_bot_spawner__id < 0
      return
    insert(spawnerIdEidMap, trench_bot_spawner__id, eid)
  query() <| $ [es(REQUIRE=transform)] (eid : EntityId;
                                        grid_detector_area__id : int)
    if grid_detector_area__id < 0
      return
    insert(detectorIdEidMap, grid_detector_area__id, eid)
  query() <| $ [es(REQUIRE=transform)] (eid : EntityId;
                                        trench_target__id : int)
    if trench_target__id < 0
      return
    insert(targetIdEidMap, trench_target__id, eid)
  query() <| $ [es(REQUIRE=transform)] (eid : EntityId;
                                        trench_waypoint__spawnerId : int;
                                        trench_waypoint__id : int)
    if trench_waypoint__id < 0
      return
    insert(waypointIdEidMap, "{trench_waypoint__spawnerId}:{trench_waypoint__id}", eid)
  trench_bot_spawner_init(spawnerIdEidMap, detectorIdEidMap)
  trench_bot_timed_storm_init(spawnerIdEidMap)
  trench_cover_init(spawnerIdEidMap, targetIdEidMap) 
  query() <| $ [es(REQUIRE=transform)] (eid : EntityId;
                                        trench_cover__spawnerId : int;
                                        trench_cover__id : int)
    if trench_cover__id < 0
      return
    insert(coverIdEidMap, "{trench_cover__spawnerId}:{trench_cover__id}", eid)
  trench_waypoint_init(waypointIdEidMap, coverIdEidMap, spawnerIdEidMap)


def trench_bot_spawner_init(var spawner_id_eid_map : table<int, EntityId>;
                            var detector_id_eid_map : table<int, EntityId>)
  query() <| $ [es] (eid : EntityId;
                     trench_bot_spawner__stormedSpawnerId : int;
                     trench_bot_spawner__gridDetectorAreaIds : IntList;
                     trench_bot_spawner__equipTemplates : StringList;
                     var trench_bot_spawner__equipTemplateWeights : FloatList&;
                     var trench_bot_spawner__equipTemplateProbabilities : FloatList&;
                     var trench_bot_spawner__nextSpawnAt : float&;
                     var trench_bot_spawner__stormedSpawnerEid : EntityId&;
                     var trench_bot_spawner__gridDetectorAreaEids : EidList&)
    if length(trench_bot_spawner__equipTemplateWeights) != length(trench_bot_spawner__equipTemplates)
      resize(trench_bot_spawner__equipTemplateWeights, length(trench_bot_spawner__equipTemplates))
      logerr("length of trench_bot_spawner__equipTemplateWeights is not equal to length of trench_bot_spawner__equipTemplates")
    clear(trench_bot_spawner__equipTemplateProbabilities)
    var totalWeight = 0.0
    for weight in trench_bot_spawner__equipTemplateWeights
      totalWeight += weight
    var accumProb = 0.0
    for weight in trench_bot_spawner__equipTemplateWeights
      accumProb += weight / totalWeight
      push(trench_bot_spawner__equipTemplateProbabilities, accumProb)
    trench_bot_spawner__nextSpawnAt = get_sync_time() + calc_next_spawn_delay(eid)
    trench_bot_spawner__stormedSpawnerEid = get_value(spawner_id_eid_map, trench_bot_spawner__stormedSpawnerId)
    for id in trench_bot_spawner__gridDetectorAreaIds
      push(trench_bot_spawner__gridDetectorAreaEids, get_value(detector_id_eid_map, id))


def trench_bot_timed_storm_init(var spawner_id_eid_map : table<int, EntityId>)
  query() <| $ [es] (trench_bot_timed_storm__minInterval : float;
                     trench_bot_timed_storm__spawnerIdPairs : IPoint2List&;
                     var trench_bot_timed_storm__spawnerEidPairs : IPoint2List&;
                     var trench_bot_timed_storm__stormAt : FloatList&)
    for idPair in trench_bot_timed_storm__spawnerIdPairs
      let eid1 = get_value(spawner_id_eid_map, idPair.x)
      if eid1 == INVALID_ENTITY_ID
        logerr("trench_bot_timed_storm_init: trench_bot_spawner with id {idPair.x} does not exist")
        clear(trench_bot_timed_storm__spawnerEidPairs)
        clear(trench_bot_timed_storm__stormAt)
        return
      let eid2 = get_value(spawner_id_eid_map, idPair.y)
      if eid2 == INVALID_ENTITY_ID
        logerr("trench_bot_timed_storm_init: trench_bot_spawner with id {idPair.y} does not exist")
        clear(trench_bot_timed_storm__spawnerEidPairs)
        clear(trench_bot_timed_storm__stormAt)
        return
      push(trench_bot_timed_storm__spawnerEidPairs, int2(int(uint(eid1)), int(uint(eid2))))
      push(trench_bot_timed_storm__stormAt, trench_bot_timed_storm__minInterval)

    if rnd_int(0, 1) == 1
      for eidPair in trench_bot_timed_storm__spawnerEidPairs
        swap(eidPair.x, eidPair.y)


def trench_cover_init(var spawner_id_eid_map : table<int, EntityId>;
                      var target_id_eid_map : table<int, EntityId>)
  query() <| $ [es] (trench_cover__spawnerId : int;
                     trench_cover__lookAtTargetId : int;
                     var trench_cover__spawnerEid : EntityId&;
                     var trench_cover__lookAtTargetEid : EntityId&)
    trench_cover__spawnerEid = get_value(spawner_id_eid_map, trench_cover__spawnerId)
    trench_cover__lookAtTargetEid = get_value(target_id_eid_map, trench_cover__lookAtTargetId)
  query() <| $ [es] (trench_bot_spawner__id : int;
                     trench_bot_spawner__coverIdAssignmentDir : float3)
    if trench_bot_spawner__coverIdAssignmentDir == float3()
      return
    var coverEidShiftMap : array<tuple<eid : EntityId; shift : float>>
    query() <| $ [es] (eid : EntityId;
                       transform aka cover_transform : float3x4;
                       trench_cover__spawnerId : int)
      if trench_cover__spawnerId != trench_bot_spawner__id
        return
      let shift = dot(trench_bot_spawner__coverIdAssignmentDir, cover_transform[3])
      push(coverEidShiftMap, (eid, shift))
    sort(coverEidShiftMap) <| $(a, b)
      return a.shift < b.shift
    for elem, i in coverEidShiftMap, iter_range(coverEidShiftMap)
      query(elem.eid) <| $ [es] (var trench_cover__id : int&)
        trench_cover__id = i


def trench_waypoint_init(var waypoint_id_eid_map : table<string, EntityId>;
                         var cover_id_eid_map : table<string, EntityId>;
                         var spawner_id_eid_map : table<int, EntityId>)
  query() <| $ [es(REQUIRE=transform)] (trench_waypoint__id : int;
                                        trench_waypoint__spawnerId : int;
                                        trench_waypoint__coverIdFrom : int;
                                        trench_waypoint__coverIdTo : int)
    if trench_waypoint__coverIdFrom < 0 || trench_waypoint__coverIdTo < 0
      return
    for coverId in range(trench_waypoint__coverIdFrom, trench_waypoint__coverIdTo + 1)
      let coverEid = get_value(cover_id_eid_map, "{trench_waypoint__spawnerId}:{coverId}")
      query(coverEid) <| $ [es] (var trench_cover__waypointId : int&)
        if trench_cover__waypointId < 0
          trench_cover__waypointId = trench_waypoint__id
  query() <| $ [es(REQUIRE=transform)] (trench_waypoint__spawnerId : int;
                                        trench_waypoint__prevId : int;
                                        var trench_waypoint__prevEid : EntityId&;
                                        var trench_waypoint__spawnerEid : EntityId&)
    trench_waypoint__prevEid = get_value(waypoint_id_eid_map, "{trench_waypoint__spawnerId}:{trench_waypoint__prevId}")
    trench_waypoint__spawnerEid = get_value(spawner_id_eid_map, trench_waypoint__spawnerId)
  query() <| $ [es(REQUIRE=transform)] (trench_cover__spawnerId : int;
                                        trench_cover__waypointId : int;
                                        var trench_cover__waypointEid : EntityId&)
    trench_cover__waypointEid = get_value(waypoint_id_eid_map, "{trench_cover__spawnerId}:{trench_cover__waypointId}")


[es(tag=server, on_appear, REQUIRE=vehicle_net_phys)]
def vehicle_nav_area_init(evt : Event; eid : EntityId)
  if (find_query() <| $ [es(REQUIRE=enableVehicleNavArea)] () => true)
    addSubTemplate(eid, "moving_nav_area")


def update_moving_nav_areas_impl(eid : EntityId;
                                 transform : float3x4;
                                 moving_nav_area__radius : float2;
                                 moving_nav_area__weight : float2;
                                 var walker_agent : EntityAgent&)
  let walkerAgentsAreaId = int(uint(eid))
  walker_agent_nav_areaUpdateCylinder(walker_agent, walkerAgentsAreaId, transform[3], moving_nav_area__radius,
      moving_nav_area__weight.x, moving_nav_area__weight.y, true)


def clear_moving_nav_areas_impl(eid : EntityId;
                                var walker_agent : EntityAgent&)
  let walkerAgentsAreaId = int(uint(eid))
  walker_agent_nav_areaRemove(walker_agent, walkerAgentsAreaId)


[es(tag=server, on_appear, REQUIRE=(deadEntity, moving_nav_area__disableOnDeath))]
def clear_moving_nav_area_on_death(evt : Event;
                                   eid : EntityId)
  query() <| $ [es(REQUIRE=enableMovingNavAreaReaction, REQUIRE_NOT=deadEntity)] (var walker_agent : EntityAgent&)
    clear_moving_nav_areas_impl(eid, walker_agent)


[es(tag=server, on_disappear, REQUIRE=movingNavArea)]
def clear_moving_nav_area_on_disappear(evt : Event;
                                       eid : EntityId)
  query() <| $ [es(REQUIRE=enableMovingNavAreaReaction, REQUIRE_NOT=deadEntity)] (var walker_agent : EntityAgent&)
    clear_moving_nav_areas_impl(eid, walker_agent)


[es(tag=server)]
def update_moving_nav_areas_on_motion(info : UpdateStageInfoAct;
                                      eid : EntityId;
                                      transform : float3x4;
                                      moving_nav_area__deltaPositionThreshold : float;
                                      moving_nav_area__radius : float2;
                                      moving_nav_area__weight : float2;
                                      moving_nav_area__disableOnDeath : Tag const?;
                                      deadEntity : Tag const?;
                                      var moving_nav_area__lastPosition : float3&)
  if distance_sq(transform[3], moving_nav_area__lastPosition) < square(moving_nav_area__deltaPositionThreshold) || (moving_nav_area__disableOnDeath != null && deadEntity != null)
    return
  moving_nav_area__lastPosition = transform[3]
  query() <| $ [es(REQUIRE=enableMovingNavAreaReaction, REQUIRE_NOT=deadEntity)] (var walker_agent : EntityAgent&)
    update_moving_nav_areas_impl(eid, transform, moving_nav_area__radius, moving_nav_area__weight, walker_agent)


[es(tag=server, on_appear, REQUIRE=enableMovingNavAreaReaction, REQUIRE_NOT=deadEntity)]
def update_moving_nav_areas_on_bot_appear(info : Event;
                                          eid aka walker_eid : EntityId;
                                          var walker_agent : EntityAgent&)
  query() <| $ [es] (eid aka moving_nav_area_eid : EntityId;
                     transform : float3x4;
                     moving_nav_area__radius : float2;
                     moving_nav_area__weight : float2;
                     moving_nav_area__disableOnDeath : Tag const?;
                     deadEntity : Tag const?)
    if (moving_nav_area__disableOnDeath != null && deadEntity != null) || moving_nav_area_eid == walker_eid
      return
    update_moving_nav_areas_impl(eid, transform, moving_nav_area__radius, moving_nav_area__weight, walker_agent)


[es(tag=server, on_disappear, REQUIRE=enableMovingNavAreaReaction, REQUIRE_NOT=deadEntity)]
def clear_moving_nav_areas_on_bot_disappear_or_death(info : Event;
                                                     var walker_agent : EntityAgent&)
  query() <| $ [es(REQUIRE=movingNavArea)] (eid : EntityId)
    clear_moving_nav_areas_impl(eid, walker_agent)


[es(tag=server)]
def check_grid_detector_area(info : UpdateStageInfoAct;
                             transform : float3x4;
                             grid_detector_area__gridType : string;
                             grid_detector_area__updateInterval : float;
                             var grid_detector_area__nextUpdateAt : float&;
                             var grid_detector_area__teamPresence : BoolList&;
                             grid_detector_area__teamCount : int = 2)
  if grid_detector_area__nextUpdateAt > info.curTime
    return
  grid_detector_area__nextUpdateAt = info.curTime + grid_detector_area__updateInterval

  for presence in grid_detector_area__teamPresence
    presence = false

  var tm : float3x4
  var oobb = BBox3()
  calc_unit_tm_and_oobb(transform, tm, oobb)

  var teamsPresent = 0
  find_entity_in_grid(ecs_hash(grid_detector_area__gridType), tm, oobb, GridEntCheck BOUNDING) <| $(objEid : EntityId)
    query(objEid) <| $ [es(REQUIRE_NOT=deadEntity)] (team : int)
      if team < 1
        return
      if !grid_detector_area__teamPresence[team]
        grid_detector_area__teamPresence[team] = true
        teamsPresent++
    return teamsPresent >= grid_detector_area__teamCount


def make_trench_bot_equip_template(trench_bot_spawner__equipTemplates : StringList;
                                   trench_bot_spawner__equipTemplateProbabilities : FloatList)
  let weaponRand = rnd_float(0.0, 1.0)
  var tmpl = ""
  for prob, i in trench_bot_spawner__equipTemplateProbabilities, iter_range(trench_bot_spawner__equipTemplateProbabilities)
    if weaponRand < prob
      tmpl += "{trench_bot_spawner__equipTemplates[i]}"
      break
  return tmpl


def is_point_blocked_by_vehicle(pos : float3; radius : float)
  let eid = find_entity_in_grid(ecs_hash("vehicles"), BSphere3(pos, radius), GridEntCheck.BOUNDING) <| $ [unused_argument(objEid)] (objEid : EntityId)
    return true
  return eid != INVALID_ENTITY_ID


def is_point_blocked_by_friendly_humans(pos : float3; radius : float; point_team : int; friendly_humans_blockage_count : int)
  var friendlyHumanCount = 0
  find_entity_in_grid(ecs_hash("humans"), BSphere3(pos, radius), GridEntCheck.BOUNDING) <| $(objEid : EntityId)
    query(objEid) <| $ [es(REQUIRE_NOT=deadEntity)] (team aka obj_team : int)
      if point_team == obj_team
        friendlyHumanCount++
    return friendlyHumanCount >= friendly_humans_blockage_count
  return friendlyHumanCount >= friendly_humans_blockage_count


[es(tag=server)]
def check_waypoint_and_spawner_blockage(info : UpdateStageInfoAct;
                                        transform aka waypoint_transform : float3x4;
                                        trench_waypoint__spawnerEid : EntityId;
                                        trench_waypoint__prevEid : EntityId;
                                        trench_waypoint__blockCheckInterval : float;
                                        trench_waypoint__vehicleBlockageRadius : float;
                                        trench_waypoint__friendlyHumanBlockageRadius : float;
                                        trench_waypoint__friendlyHumanBlockageCount : int;
                                        var trench_waypoint__nextBlockCheckAt : float&;
                                        var trench_waypoint__blocked : bool&)
  if trench_waypoint__nextBlockCheckAt > info.curTime
    return
  trench_waypoint__nextBlockCheckAt = info.curTime + trench_waypoint__blockCheckInterval

  query(trench_waypoint__spawnerEid) <| $ [es] (team : int; var trench_bot_spawner__blocked : bool&)
    trench_waypoint__blocked = is_point_blocked_by_vehicle(waypoint_transform[3], trench_waypoint__vehicleBlockageRadius)
    if trench_waypoint__prevEid == INVALID_ENTITY_ID
      if !trench_waypoint__blocked
        trench_waypoint__blocked = is_point_blocked_by_friendly_humans(waypoint_transform[3], trench_waypoint__friendlyHumanBlockageRadius, team, trench_waypoint__friendlyHumanBlockageCount)
      trench_bot_spawner__blocked = trench_waypoint__blocked


[es(tag=server, after=check_waypoint_and_spawner_blockage)]
def check_cover_blockage(info : UpdateStageInfoAct;
                         transform aka cover_transform : float3x4;
                         trench_cover__spawnerEid : EntityId;
                         trench_cover__blockCheckInterval : float;
                         trench_cover__vehicleBlockageRadius : float;
                         var trench_cover__nextBlockCheckAt : float&;
                         var trench_cover__blocked : bool&;
                         var trench_cover__blockedInt : int&)
  if trench_cover__nextBlockCheckAt > info.curTime
    return
  trench_cover__nextBlockCheckAt = info.curTime + trench_cover__blockCheckInterval

  query(trench_cover__spawnerEid) <| $ [es] (trench_bot_spawner__blocked : bool;
                                             trench_bot_spawner__maxBotCount : int)
    if trench_bot_spawner__maxBotCount <= 0
      return
    trench_cover__blocked = trench_bot_spawner__blocked || is_point_blocked_by_vehicle(cover_transform[3], trench_cover__vehicleBlockageRadius)
    trench_cover__blockedInt = trench_cover__blocked ? 1 : 0
