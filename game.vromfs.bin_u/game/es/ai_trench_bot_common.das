module ai_trench_bot_common shared
require ecs
require DagorRandom

struct AdditionalTrenchPositions
  lookAt : float3
  lookAtCrouching : float3
  coverEntry : float3
  storm : float3


def get_additional_trench_positions(pos : float3;
                                    waypoint_pos : float3;
                                    stormed_cover_eid : EntityId;
                                    side_dir_mode : int;
                                    entry_offset : float2;
                                    look_at_target_eid : EntityId;
                                    look_at_crouching_offset : float2;
                                    look_at_crouching_vert_offset_range : float2)
  var res : AdditionalTrenchPositions

  res.lookAt = get_trench_bot_look_at_position(pos, stormed_cover_eid, look_at_target_eid)
  if res.lookAt == float3()
    res.coverEntry = pos
    res.storm = pos
    return res
  let backDir = normalize(pos - res.lookAt)
  res.storm = pos + entry_offset.x * backDir
  let sideDir = normalize(side_dir_mode == 0 ? waypoint_pos - res.storm : cross(backDir, float3(0, 1, 0)))
  res.coverEntry += res.storm + entry_offset.y * sideDir
  let sideDirSign = (rnd_int(0, 1) == 0 ? -1.0 : 1.0)
  let lookAtCrouchingVertOffset = rnd_float(look_at_crouching_vert_offset_range.x, look_at_crouching_vert_offset_range.y)
  res.lookAtCrouching = pos + backDir * look_at_crouching_offset.x + sideDir * sideDirSign * look_at_crouching_offset.y + float3(0, lookAtCrouchingVertOffset, 0)
  return res


def get_trench_bot_look_at_position(pos : float3; stormed_cover_eid : EntityId; look_at_target_eid : EntityId)
  var res = float3()

  if look_at_target_eid == INVALID_ENTITY_ID
    if stormed_cover_eid == INVALID_ENTITY_ID
      return res
    return (*get_TMatrix(stormed_cover_eid, "transform"))[3]

  query(look_at_target_eid) <| $ [es] (transform : float3x4;
                                       trench_target__isInverted : bool)
    if trench_target__isInverted
      res = 2.0 * pos - transform[3]
    else
      res = transform[3]
  return res


def trench_storm(offender_trench_bot_spawner_id : int)
  query() <| $ [es] (eid : EntityId;
                     trench_bot__spawnerEid : EntityId;
                     trench_bot__coverEid : EntityId;
                     trench_bot__stormedCoverEid : EntityId;
                     trench_bot__stormedPosition : float3;
                     var trench_bot__occupiedSpawnerEid : EntityId&;
                     var trench_bot__finalPosition : float3&;
                     var trench_bot__pathToCover : Point3List&;
                     var trench_bot__lookAtPosition : float3&;
                     var trench_bot__lookAtPositionCrouching : float3&)
    var success = false
    query(trench_bot__spawnerEid) <| $ [es] (trench_bot_spawner__id : int;
                                             trench_bot_spawner__stormedSpawnerEid : EntityId)
      success = trench_bot_spawner__id == offender_trench_bot_spawner_id
      if success
        trench_bot__occupiedSpawnerEid = trench_bot_spawner__stormedSpawnerEid
    if !success
      return
    query(trench_bot__stormedCoverEid) <| $ [es] (trench_cover__entryOffset : float2;
                                                  trench_cover__sideDirMode : int;
                                                  trench_cover__lookAtCrouchingOffset : float2;
                                                  trench_cover__lookAtCrouchingVertOffsetRange : float2;
                                                  trench_cover__lookAtTargetEid : EntityId;
                                                  trench_cover__waypointEid : EntityId)
      let spawnerTm = (*get_TMatrix(trench_bot__occupiedSpawnerEid, "transform"))
      let waypointTm = get_TMatrix(trench_cover__waypointEid, "transform") ?? spawnerTm
      let additionalPositions = get_additional_trench_positions(trench_bot__stormedPosition, waypointTm[3], trench_bot__coverEid, trench_cover__sideDirMode,
        trench_cover__entryOffset, trench_cover__lookAtTargetEid, trench_cover__lookAtCrouchingOffset, trench_cover__lookAtCrouchingVertOffsetRange)
      trench_bot__finalPosition = trench_bot__stormedPosition
      trench_bot__lookAtPosition = additionalPositions.lookAt
      trench_bot__lookAtPositionCrouching = additionalPositions.lookAtCrouching
      clear(trench_bot__pathToCover)
      push(trench_bot__pathToCover, trench_bot__finalPosition)
      addSubTemplate(eid, "moving_nav_area_reaction_enabler+trench_bot_moving_nav_area")


def make_trench_cover_id_eid_map(spawner_id : int)
  var res : table<int, EntityId>
  query() <| $ [es(REQUIRE=transform)] (eid : EntityId;
                                        trench_cover__id : int;
                                        trench_cover__spawnerId : int)
    if trench_cover__spawnerId == spawner_id
      insert(res, trench_cover__id, eid)
  return <- res
