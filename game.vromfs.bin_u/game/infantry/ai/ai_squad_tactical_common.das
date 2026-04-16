module ai_squad_tactical_common shared

require ecs
require app
require math.base

let
  AI_SQUAD_TACTICAL_REPLACE_TARGET_TIMEOUT = 10.0
  AI_SQUAD_TACTICAL_ACTUAL_TARGET_TIMEOUT = 15.0
  AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT = 10.0


def ai_squad_tactical_add_update_target(squad_eid : EntityId; target_eid : EntityId; target_pos : float3; update_only : bool)
  query(target_eid) <| $ [es] (unit_tag__tank : Tag const?;
                               unit_tag__human : Tag const?)
    if unit_tag__human == null && unit_tag__tank == null
      return
    query(squad_eid) <| $ [es] (squadAI_tactical__maxTargets : int;
                                squadAI_tactical__maxVehicleTargets : int;
                                var squadAI_tactical__targetsPosTime : Point4List&;
                                var squadAI_tactical__targetsEids : EidList&;
                                var squadAI_tactical__targetsAcqByEid1 : EidList&;
                                var squadAI_tactical__targetsAcqByEid2 : EidList&;
                                var squadAI_tactical__targetsAcqTimes : Point2List&;
                                var squadAI_tactical__vehicleTargetsPosTime : Point4List&;
                                var squadAI_tactical__vehicleTargetsEids : EidList&;
                                var squadAI_tactical__vehicleTargetsAcqByEid1 : EidList&;
                                var squadAI_tactical__vehicleTargetsAcqByEid2 : EidList&;
                                var squadAI_tactical__vehicleTargetsAcqTimes : Point2List&)
      let atTime = get_sync_time()

      assume maxTargets = unit_tag__human != null ? squadAI_tactical__maxTargets : squadAI_tactical__maxVehicleTargets
      assume targetsEids = unit_tag__human != null ? squadAI_tactical__targetsEids : squadAI_tactical__vehicleTargetsEids
      assume targetsPosTime = unit_tag__human != null ? squadAI_tactical__targetsPosTime : squadAI_tactical__vehicleTargetsPosTime
      assume targetsAcqByEid1 = unit_tag__human != null ? squadAI_tactical__targetsAcqByEid1 : squadAI_tactical__vehicleTargetsAcqByEid1
      assume targetsAcqByEid2 = unit_tag__human != null ? squadAI_tactical__targetsAcqByEid2 : squadAI_tactical__vehicleTargetsAcqByEid2
      assume targetsAcqTimes = unit_tag__human != null ? squadAI_tactical__targetsAcqTimes : squadAI_tactical__vehicleTargetsAcqTimes

      for i in iter_range(targetsEids)
        if targetsEids[i] == target_eid
          targetsPosTime[i] = float4(target_pos.x, target_pos.y, target_pos.z, atTime)
          return
      if update_only
        return

      if length(targetsPosTime) < maxTargets
        targetsPosTime |> push(float4(target_pos.x, target_pos.y, target_pos.z, atTime))
        targetsEids |> push(target_eid)
        targetsAcqByEid1 |> push(INVALID_ENTITY_ID)
        targetsAcqByEid2 |> push(INVALID_ENTITY_ID)
        targetsAcqTimes |> push(float2(0.0, 0.0))
        return

      var oldestIdx = 0
      var oldestTime = targetsPosTime[0].w
      for i in iter_range(targetsEids)
        let thatTime = targetsPosTime[i].w
        if thatTime < oldestTime
          oldestIdx = i
          oldestTime = thatTime

      if atTime < oldestTime + AI_SQUAD_TACTICAL_REPLACE_TARGET_TIMEOUT
        return

      targetsPosTime[oldestIdx] = float4(target_pos.x, target_pos.y, target_pos.z, atTime)
      targetsEids[oldestIdx] = target_eid
      targetsAcqByEid1[oldestIdx] = INVALID_ENTITY_ID
      targetsAcqByEid2[oldestIdx] = INVALID_ENTITY_ID
      targetsAcqTimes[oldestIdx] = float2(0.0, 0.0)

def ai_squad_tactical_add_update_target(squad_eid : EntityId; target_eid : EntityId; update_only : bool)
  query(target_eid) <| $ [es] (transform : float3x4)
    ai_squad_tactical_add_update_target(squad_eid, target_eid, transform[3], update_only)


def ai_squad_tactical_has_recent_target(squad_eid : EntityId; target_eid : EntityId; timeout : float)
  var result = false
  query(target_eid) <| $ [es] (unit_tag__tank : Tag const?;
                               unit_tag__human : Tag const?)
    if unit_tag__human == null && unit_tag__tank == null
      return
    query(squad_eid) <| $ [es] (squadAI_tactical__targetsEids : EidList;
                                squadAI_tactical__targetsPosTime : Point4List;
                                squadAI_tactical__vehicleTargetsEids : EidList;
                                squadAI_tactical__vehicleTargetsPosTime : Point4List)
      let atTime = get_sync_time()
      assume targetsEids = unit_tag__human != null ? squadAI_tactical__targetsEids : squadAI_tactical__vehicleTargetsEids
      assume targetsPosTime = unit_tag__human != null ? squadAI_tactical__targetsPosTime : squadAI_tactical__vehicleTargetsPosTime
      for i in iter_range(targetsEids)
        if targetsEids[i] == target_eid && atTime < targetsPosTime[i].w + timeout
          result = true
          break
  return result


def ai_check_has_tactical_targets_to_acquire(squad_eid : EntityId; max_actual_time : float; allow_already_acquired : bool)
  var result = false
  query(squad_eid) <| $ [es] (squadAI_tactical__targetsPosTime : Point4List;
                              squadAI_tactical__targetsEids : EidList;
                              squadAI_tactical__targetsAcqTimes : Point2List)
    let atTime = get_sync_time()
    let actualTime = max_actual_time < 0.0 ? AI_SQUAD_TACTICAL_ACTUAL_TARGET_TIMEOUT : max_actual_time
    for i in iter_range(squadAI_tactical__targetsEids)
      if atTime > squadAI_tactical__targetsPosTime[i].w + actualTime
        continue
      let targetEid = squadAI_tactical__targetsEids[i]
      if targetEid == INVALID_ENTITY_ID
        continue
      if !allow_already_acquired
        var alreadyAcquired = true
        if atTime > squadAI_tactical__targetsAcqTimes[i].x
          alreadyAcquired = false
        elif atTime > squadAI_tactical__targetsAcqTimes[i].y
          alreadyAcquired = false
        if alreadyAcquired
          continue
      result = true
      break
  return result

def ai_find_acqure_tactical_target(var out_last_pos : float3&; squad_eid : EntityId; for_pos : float3; max_actual_time : float;
                                   allow_already_acquired : bool; acquire_by_eid : EntityId)
  var resultEid = INVALID_ENTITY_ID
  var resultPos = float3()
  query(squad_eid) <| $ [es] (squadAI_tactical__targetsPosTime : Point4List;
                              squadAI_tactical__targetsEids : EidList;
                              var squadAI_tactical__targetsAcqByEid1 : EidList&;
                              var squadAI_tactical__targetsAcqByEid2 : EidList&;
                              var squadAI_tactical__targetsAcqTimes : Point2List&)
    let atTime = get_sync_time()
    let actualTime = max_actual_time < 0.0 ? AI_SQUAD_TACTICAL_ACTUAL_TARGET_TIMEOUT : max_actual_time
    var acqEid = INVALID_ENTITY_ID
    var acqPos = float3()
    var acqBestDistSq = -1.0
    var bestDistSq = -1.0
    var bestIdx = -1
    for i in iter_range(squadAI_tactical__targetsEids)
      if atTime > squadAI_tactical__targetsPosTime[i].w + actualTime
        continue
      let targetEid = squadAI_tactical__targetsEids[i]
      if targetEid == INVALID_ENTITY_ID
        continue
      let targetPos = squadAI_tactical__targetsPosTime[i].xyz
      let targetDistSq = length_sq(targetPos - for_pos)

      var alreadyAcquired = true
      if atTime > squadAI_tactical__targetsAcqTimes[i].x
        alreadyAcquired = false
      elif atTime > squadAI_tactical__targetsAcqTimes[i].y
        alreadyAcquired = false
      if alreadyAcquired
        if allow_already_acquired && (acqBestDistSq < 0.0 || targetDistSq < acqBestDistSq)
          acqEid = targetEid
          acqPos = targetPos
          acqBestDistSq = targetDistSq
        continue
      if bestIdx < 0 || targetDistSq < bestDistSq
        resultEid = targetEid
        resultPos = targetPos
        bestDistSq = targetDistSq
        bestIdx = i
    if bestIdx >= 0
      if acquire_by_eid != INVALID_ENTITY_ID
        let i = bestIdx
        if squadAI_tactical__targetsAcqByEid1[i] == acquire_by_eid
          squadAI_tactical__targetsAcqTimes[i].x = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
          squadAI_tactical__targetsAcqByEid1[i] = acquire_by_eid
        elif squadAI_tactical__targetsAcqByEid2[i] == acquire_by_eid
          squadAI_tactical__targetsAcqTimes[i].y = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
          squadAI_tactical__targetsAcqByEid2[i] = acquire_by_eid
        elif atTime > squadAI_tactical__targetsAcqTimes[i].x
          squadAI_tactical__targetsAcqTimes[i].x = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
          squadAI_tactical__targetsAcqByEid1[i] = acquire_by_eid
        elif atTime > squadAI_tactical__targetsAcqTimes[i].y
          squadAI_tactical__targetsAcqTimes[i].y = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
          squadAI_tactical__targetsAcqByEid2[i] = acquire_by_eid
    elif acqEid != INVALID_ENTITY_ID
      resultEid = acqEid
      resultPos = acqPos
  out_last_pos = resultPos
  return resultEid

def ai_reacqure_tactical_target(squad_eid : EntityId; target_eid : EntityId; only_actual : bool; acquire_by_eid : EntityId)
  if target_eid == INVALID_ENTITY_ID || acquire_by_eid == INVALID_ENTITY_ID
    return false
  var result = false
  let atTime = get_sync_time()
  query(squad_eid) <| $ [es] (squadAI_tactical__targetsPosTime : Point4List;
                              squadAI_tactical__targetsEids : EidList;
                              var squadAI_tactical__targetsAcqByEid1 : EidList&;
                              var squadAI_tactical__targetsAcqByEid2 : EidList&;
                              var squadAI_tactical__targetsAcqTimes : Point2List&)
    for i in iter_range(squadAI_tactical__targetsEids)
      let targetEid = squadAI_tactical__targetsEids[i]
      if targetEid != target_eid
        continue
      if only_actual && atTime > squadAI_tactical__targetsPosTime[i].w + AI_SQUAD_TACTICAL_ACTUAL_TARGET_TIMEOUT
        return
      if squadAI_tactical__targetsAcqByEid1[i] == acquire_by_eid
        squadAI_tactical__targetsAcqTimes[i].x = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
        squadAI_tactical__targetsAcqByEid1[i] = acquire_by_eid
        result = true
      elif squadAI_tactical__targetsAcqByEid2[i] == acquire_by_eid
        squadAI_tactical__targetsAcqTimes[i].y = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
        squadAI_tactical__targetsAcqByEid2[i] = acquire_by_eid
        result = true
      elif atTime > squadAI_tactical__targetsAcqTimes[i].x
        squadAI_tactical__targetsAcqTimes[i].x = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
        squadAI_tactical__targetsAcqByEid1[i] = acquire_by_eid
        result = true
      elif atTime > squadAI_tactical__targetsAcqTimes[i].y
        squadAI_tactical__targetsAcqTimes[i].y = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
        squadAI_tactical__targetsAcqByEid2[i] = acquire_by_eid
        result = true
      return
  return result
