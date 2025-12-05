module ai_squad_tactical_common shared

require ecs
require app
require math.base

let
  AI_SQUAD_TACTICAL_REPLACE_TARGET_TIMEOUT = 10.0
  AI_SQUAD_TACTICAL_ACTUAL_TARGET_TIMEOUT = 15.0
  AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT = 10.0


def ai_squad_tactical_add_update_target(squad_eid : EntityId; target_eid : EntityId; update_only : bool)
  query(target_eid) <| $ [es] (transform : float3x4;
                               unit_tag__tank : Tag const?;
                               unit_tag__human : Tag const?)
    if unit_tag__human == null && unit_tag__tank == null
      return
    let targetPos = transform[3]
    query(squad_eid) <| $ [es] (squadAI_tactical__maxTargets : int;
                                squadAI_tactical__maxVehicleTargets : int;
                                var squadAI_tactical__targetsPosTime : Point4List&;
                                var squadAI_tactical__targetsEids : EidList&;
                                var squadAI_tactical__targetsAcqTime : FloatList&;
                                var squadAI_tactical__vehicleTargetsPosTime : Point4List&;
                                var squadAI_tactical__vehicleTargetsEids : EidList&;
                                var squadAI_tactical__vehicleTargetsAcqTime : FloatList&)
      let atTime = get_sync_time()

      assume maxTargets = unit_tag__human != null ? squadAI_tactical__maxTargets : squadAI_tactical__maxVehicleTargets
      assume targetsEids = unit_tag__human != null ? squadAI_tactical__targetsEids : squadAI_tactical__vehicleTargetsEids
      assume targetsPosTime = unit_tag__human != null ? squadAI_tactical__targetsPosTime : squadAI_tactical__vehicleTargetsPosTime
      assume targetsAcqTime = unit_tag__human != null ? squadAI_tactical__targetsAcqTime : squadAI_tactical__vehicleTargetsAcqTime

      for i in iter_range(targetsEids)
        if targetsEids[i] == target_eid
          targetsPosTime[i] = float4(targetPos.x, targetPos.y, targetPos.z, atTime)
          return
      if update_only
        return

      if length(targetsPosTime) < maxTargets
        targetsPosTime |> push(float4(targetPos.x, targetPos.y, targetPos.z, atTime))
        targetsEids |> push(target_eid)
        targetsAcqTime |> push(0.0)
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

      targetsPosTime[oldestIdx] = float4(targetPos.x, targetPos.y, targetPos.z, atTime)
      targetsEids[oldestIdx] = target_eid
      targetsAcqTime[oldestIdx] = 0.0


def ai_find_acqure_tactical_target(squad_eid : EntityId)
  var resultEid = INVALID_ENTITY_ID
  let atTime = get_sync_time()
  query(squad_eid) <| $ [es] (squadAI_tactical__targetsPosTime : Point4List;
                              squadAI_tactical__targetsEids : EidList;
                              var squadAI_tactical__targetsAcqTime : FloatList&)
    for i in iter_range(squadAI_tactical__targetsEids)
      if atTime > squadAI_tactical__targetsPosTime[i].w + AI_SQUAD_TACTICAL_ACTUAL_TARGET_TIMEOUT
        continue
      if atTime < squadAI_tactical__targetsAcqTime[i] 
        continue
      let targetEid = squadAI_tactical__targetsEids[i]
      if targetEid == INVALID_ENTITY_ID
        continue
      squadAI_tactical__targetsAcqTime[i] = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
      resultEid = targetEid
      return
  return resultEid

def ai_keep_acqure_tactical_target(squad_eid : EntityId; target_eid : EntityId; only_actual : bool)
  if target_eid == INVALID_ENTITY_ID
    return false
  var result = false
  let atTime = get_sync_time()
  query(squad_eid) <| $ [es] (squadAI_tactical__targetsPosTime : Point4List;
                              squadAI_tactical__targetsEids : EidList;
                              var squadAI_tactical__targetsAcqTime : FloatList&)
    for i in iter_range(squadAI_tactical__targetsEids)
      let targetEid = squadAI_tactical__targetsEids[i]
      if targetEid != target_eid
        continue
      if only_actual && atTime > squadAI_tactical__targetsPosTime[i].w + AI_SQUAD_TACTICAL_ACTUAL_TARGET_TIMEOUT
        return
      squadAI_tactical__targetsAcqTime[i] = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
      result = true
      return
  return result


def ai_predict_tactical_target_movement(squad_eid : EntityId; target_eid : EntityId; only_actual : bool)
  if target_eid == INVALID_ENTITY_ID
    return false
  var result = false
  let atTime = get_sync_time()
  query(squad_eid) <| $ [es] (squadAI_tactical__targetsPosTime : Point4List;
                              squadAI_tactical__targetsEids : EidList;
                              var squadAI_tactical__targetsAcqTime : FloatList&)
    for i in iter_range(squadAI_tactical__targetsEids)
      let targetEid = squadAI_tactical__targetsEids[i]
      if targetEid != target_eid
        continue
      if only_actual && atTime > squadAI_tactical__targetsPosTime[i].w + AI_SQUAD_TACTICAL_ACTUAL_TARGET_TIMEOUT
        return
      squadAI_tactical__targetsAcqTime[i] = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
      result = true
      
      return
  return result

def ai_find_next_move_to_hunt_tactical_target(squad_eid : EntityId; target_eid : EntityId; only_actual : bool;
                                              hunt_from_pos : float3; max_hunt_distance : float;
                                              var out_step_pos : float3&; var out_look_dir : float3&)
  if target_eid == INVALID_ENTITY_ID
    return false
  var result = false
  let atTime = get_sync_time()
  query(squad_eid) <| $ [es] (squadAI_tactical__targetsPosTime : Point4List;
                              squadAI_tactical__targetsEids : EidList;
                              var squadAI_tactical__targetsAcqTime : FloatList&)
    for i in iter_range(squadAI_tactical__targetsEids)
      let targetEid = squadAI_tactical__targetsEids[i]
      if targetEid != target_eid
        continue
      if only_actual && atTime > squadAI_tactical__targetsPosTime[i].w + AI_SQUAD_TACTICAL_ACTUAL_TARGET_TIMEOUT
        return

      var gotTarget = false
      var targetPos = float3()
      query(target_eid) <| $ [es] (transform : float3x4)
        targetPos = transform[3]
        gotTarget = true
      if !gotTarget
        return
      if distance_sq(hunt_from_pos, targetPos) > square(max_hunt_distance)
        return

      squadAI_tactical__targetsAcqTime[i] = atTime + AI_SQUAD_TACTICAL_ACQUIRE_TARGET_TIMEOUT
      result = true
      
      
      out_step_pos = float3()
      out_look_dir = float3()
      return
  return result


struct AITacticalTargetsAnalysis
  numGroups : int
  primaryGroupDir : float3
  primaryGroupNum : int
  secondaryGroupDir : float3
  secondaryGroupNum : int
  otherGroupsNum : int
  safeNoGroupsDir : float3

def ai_analyze_tactical_targets(squad_eid : EntityId; var analysis : AITacticalTargetsAnalysis&)
  analysis = AITacticalTargetsAnalysis()
  query(squad_eid) <| $ [es] (squadAI_tactical__targetsPosTime : Point4List;
                              squadAI_tactical__targetsEids : EidList)
    for i in iter_range(squadAI_tactical__targetsPosTime)
      if squadAI_tactical__targetsEids[i] == INVALID_ENTITY_ID 
        continue
      if squadAI_tactical__targetsPosTime[i].xyz == float3() 
        continue
      
