module human_context_command_camera_common shared

require ecs
require %appGame.infantry.es.battle_area_common
require DagorMathUtils
require DagorDebug3D
require DagorMath
require math.ang
require math.base
require DngHuman
require Dacoll
require PhysMat
require RendInst
require daslib/match
require strings

require Grid
require GridCollision
require CollisionTraces


let private
  ORDER_SPHERE_CAST_MASK = int(PhysLayer.EPL_ALL) & ~(int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_KINEMATIC) | int(PhysLayer.EPL_DEBRIS))

enum HumanPointOrderHeightOfSight
  CROUCHED
  STANDING
  PEEKOUT_STANDING_UP
  PEEKOUT_CROUCHED_COVER

struct TraceSightDistanceParams
  maxDist : float
  rayMatId : int
  humanEid : EntityId

def match_height_of_sight(height_of_sight : HumanPointOrderHeightOfSight)
  match height_of_sight
    if HumanPointOrderHeightOfSight.CROUCHED
      return 0.75
    if HumanPointOrderHeightOfSight.STANDING
      return 1.3
    if HumanPointOrderHeightOfSight.PEEKOUT_STANDING_UP
      return 1.5
    if HumanPointOrderHeightOfSight.PEEKOUT_CROUCHED_COVER
      return 1.1
    if _
      return 1.3

def get_human_context_command_trace_pos_dir(human_eid : EntityId; var trace_pos : float3&; var trace_dir : float3&)
  var result = false
  query(human_eid) <| $ [es] (human_weap__currentGunEid : EntityId; human_net_phys : HumanActor)
    if human_weap__currentGunEid != INVALID_ENTITY_ID
      find_query() <| $ [es] (aim_data__gunEid : EntityId; transform : float3x4)
        if aim_data__gunEid != human_weap__currentGunEid
          return false
        trace_pos = transform[3]
        trace_dir = angles_to_dir(human_net_phys.phys.currentState.prevAngles)
        result = true
        return true
  if result
    return true
  let found = find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false
    trace_pos = transform[3]
    trace_dir = transform[2]
    return true
  return found


def trace_human_context_vehicles(trace_pos : float3; trace_dir : float3; var dist : float&; full : bool)
  var intr = false
  let humanRad = 0.35
  var gotDist = dist
  using() <| $(var entities : IntersectedEntities)
    let tracePos2 = trace_pos + float3(0.0, 0.5, 0.0)
    trace_entities_in_grid(ecs_hash("vehicles"), trace_pos, trace_dir, dist, INVALID_ENTITY_ID, entities, SortIntersections.NO)
    trace_entities_in_grid(ecs_hash("vehicles"), tracePos2, trace_dir, dist, INVALID_ENTITY_ID, entities, SortIntersections.NO)
    for isect in entities
      if isect.t < gotDist
        gotDist = isect.t
        dist = max(0.0, gotDist - humanRad)
        intr = true
  if full
    if trace_entities_in_grid_by_capsule(ecs_hash("vehicles"), trace_pos, trace_dir, dist, humanRad + 0.1, INVALID_ENTITY_ID)
      intr = true
  return intr


def private calculate_ri_denied_for_context_command_point_order(ri_pool : int; var denied_pools : IntList&; need_init : bool)
  let riName = riex_getRIGenExtraName(uint(ri_pool))
  if empty(riName)
    return 2 

  var allowed = true
  query() <| $ [es] (@shared_comp human_context_command__pointOrderAllowRI : StringList;
                     @shared_comp human_context_command__pointOrderDenyRIList : StringList;
                     @shared_comp human_context_command__pointOrderDenyRIMasks : StringList)
    if need_init
      var maxIdx = 1 
      for allowRI in human_context_command__pointOrderAllowRI
        let allowRIStr = string(allowRI)
        if !empty(allowRIStr)
          maxIdx = max(maxIdx, getRIGenExtraResIdx(allowRIStr))
      for denyRI in human_context_command__pointOrderDenyRIList
        let denyRIStr = string(denyRI)
        if !empty(denyRIStr)
          maxIdx = max(maxIdx, getRIGenExtraResIdx(denyRIStr))
      if length(denied_pools) < 1 + maxIdx
        denied_pools |> resize(1 + maxIdx)
      var marked = 0
      for allowRI in human_context_command__pointOrderAllowRI
        let allowRIStr = string(allowRI)
        if !empty(allowRIStr)
          let idx = getRIGenExtraResIdx(allowRIStr)
          if idx >= 0 && idx < maxIdx
            denied_pools[idx] = 2 
            ++marked
      for denyRI in human_context_command__pointOrderDenyRIList
        let denyRIStr = string(denyRI)
        if !empty(denyRIStr)
          let idx = getRIGenExtraResIdx(denyRIStr)
          if idx >= 0 && idx < maxIdx
            denied_pools[idx] = 1 
            ++marked

    
    allowed = false
    for allowRI in human_context_command__pointOrderAllowRI
      let allowRIStr = string(allowRI)
      if allowRIStr == riName
        allowed = true
        break
    if allowed
      return

    
    allowed = true
    for denyRI in human_context_command__pointOrderDenyRIList
      let denyRIStr = string(denyRI)
      if denyRIStr == riName
        allowed = false
        break
    if !allowed
      return

    
    allowed = true
    let nameLen = length(riName)
    for denyRIMask in human_context_command__pointOrderDenyRIMasks
      let denyRIMaskStr = string(denyRIMask)
      if !empty(denyRIMaskStr)
        var maskStr = denyRIMaskStr
        var maskStart = 0
        var maskLen = length(maskStr)
        var anyStart = false
        var anyEnd = false
        if starts_with(maskStr, "*")
          anyStart = true
          maskStart = 1
          --maskLen
        if ends_with(maskStr, "*")
          anyEnd = true
          --maskLen

        maskStr = slice(maskStr, maskStart, maskStart + maskLen)
        maskLen = length(maskStr)

        let pos = find(riName, maskStr)
        if pos >= 0
          if (anyStart || pos == 0) && (anyEnd || pos + maskLen == nameLen)
            allowed = false
            break
  return allowed ? 2 : 1

def private check_human_context_command_soldier_at_pos(pos : float3; var trace_handle : TraceMeshFaces?)
  var tmp = 0
  let CHECK_RADIUS = 0.35
  let CHECK_LOW_DH = 0.15
  let CHECK_HEIGHT1 = CHECK_RADIUS + 1.50
  let CHECK_HEIGHT2 = CHECK_RADIUS + CHECK_LOW_DH

  
  let rad = CHECK_RADIUS
  var queryOut = ShapeQueryOutput()
  let pos1 = pos + float3(0.0, CHECK_HEIGHT1, 0.0)
  let pos2 = pos + float3(0.0, CHECK_HEIGHT2, 0.0)
  sphere_cast_land(pos1, pos2, rad, queryOut)
  
  sphere_query_ri(pos1, pos2, rad, queryOut, -1, trace_handle) <| $(desc : RendInstDesc; t : float)
    if desc.cellIdx == 0 && t < 0.0
      tmp += 1
    return true
  if abs(queryOut.t - 1.0) > 0.001
    return false

  
  var traceVehDist = 1.5
  let traceVehDir = float3(0.0, 1.0, 0.0)
  if trace_human_context_vehicles(pos2, traceVehDir, traceVehDist, true)
    return false

  
  let STAND_RADIUS = 0.25
  let CHECK_DOWN_HT = CHECK_LOW_DH + 0.25
  let traceDownPos1 = pos + float3(0.0, CHECK_LOW_DH, 0.0)
  let traceDownPos2 = traceDownPos1 + float3(STAND_RADIUS, 0.0, -STAND_RADIUS * 0.5)
  let traceDownPos3 = traceDownPos1 + float3(STAND_RADIUS * 0.5, 0.0, STAND_RADIUS)
  var traceDownHt = CHECK_DOWN_HT
  if !tracedown_normalized(traceDownPos1, traceDownHt, ETF_ALL)
    return false
  traceDownHt = CHECK_DOWN_HT
  if !tracedown_normalized(traceDownPos2, traceDownHt, ETF_ALL)
    return false
  traceDownHt = CHECK_DOWN_HT
  if !tracedown_normalized(traceDownPos3, traceDownHt, ETF_ALL)
    return false

  
  var anyDenied = false
  let CHECK_HEIGHT3 = 0.0
  let pos3 = pos + float3(0.0, CHECK_HEIGHT3, 0.0)
  let rad2 = CHECK_RADIUS * 1.0
  query() <| $ [es] (var human_context_command__pointOrderDeniedRIPools : IntList&)
    assume deniedPools = human_context_command__pointOrderDeniedRIPools
    sphere_query_ri(pos2, pos3, rad2, queryOut, -1, trace_handle) <| $(desc : RendInstDesc; t : float)
      if anyDenied
        return true
      if !desc.isValid || !desc.isRiExtra
        return true
      let riPool = int(handle_to_ri_type(desc.riExtraHandle))
      if riPool >= 0
        let needInit =  length(deniedPools) == 0
        if riPool >= length(deniedPools)
          deniedPools |> resize(1 + riPool)
        if deniedPools[riPool] == 0
          deniedPools[riPool] = calculate_ri_denied_for_context_command_point_order(riPool, deniedPools, needInit)
        if deniedPools[riPool] == 1
          
          
          
          anyDenied = true
      tmp = int(t)
      return true
  if anyDenied
    return false

  return true

def validate_human_context_command_pos(pos : float3; soldier_eid : EntityId)
  var result = false
  query(soldier_eid) <| $ [es] (team : int)
    result = has_active_human_battle_area_at(pos, team)
  if result
    query() <| $ [es(REQUIRE=human_context_point_order_common)] (var trace_mesh_faces : TraceMeshFaces?)
      if !check_human_context_command_soldier_at_pos(pos, trace_mesh_faces)
        result = false
  return result

def update_human_context_trace_cache(pos : float3; hor_extends : float; vert_extends : float; var trace_handle : TraceMeshFaces&)
  var traceHandleBbox : bbox3f
  traceHandleBbox.bmax.xyz = pos
  traceHandleBbox.bmin.xyz = pos
  let traceHandleExpands = float3(hor_extends, vert_extends, hor_extends)
  let physmapExpands = hor_extends
  validate_trace_cache(traceHandleBbox, traceHandleExpands, physmapExpands, trace_handle)

def private trace_human_context_pos_down(var pos : float3&; full : bool; ray_mat_id : int; var trace_handle : TraceMeshFaces?)
  let SAFE_RADIUS = 0.3 
  pos.y += SAFE_RADIUS  
  let DOWN_HEIGHT = 100.0
  var height = DOWN_HEIGHT
  var norm : float3
  if !tracedown_normalized_with_mat_id(pos, height, norm, ETF_ALL, ray_mat_id, trace_handle)
    return false
  pos.y -= height
  if full
    if !check_human_context_command_soldier_at_pos(pos, trace_handle)
      return false
  return true

def private trace_human_context_pos_over(var out_pos : float3&; trace_pos : float3; trace_dir : float3;
                                         max_len : float; traced_len : float; ray_mat_id : int; var trace_handle : TraceMeshFaces?)
  var norm : float3
  let hzDir = normalize(x0z(trace_dir))
  let vAng = atan2(trace_dir.y, length(hzDir))
  let vAng2 = vAng - deg_to_rad(5.0)
  let upDir = float3(0, 1, 0)
  let newDir = hzDir * cos(vAng2) + upDir * sin(vAng2)
  var len = max_len
  if !traceray_normalized(trace_pos, newDir, len, norm, ETF_ALL)
    return false
  if len > traced_len
    return false
  
  
  for i in range(10)
    var pos = trace_pos + trace_dir * (len + 0.5 + 0.1 * float(i))
    
    pos.y -= 0.5
    if trace_human_context_pos_down(pos, true, ray_mat_id, trace_handle)
      if abs(pos.y - trace_pos.y) < 1.0
        out_pos = pos
        return true
  return false


def get_human_context_order_trace_params(human_eid : EntityId; var out_max_dist : float&; var out_ray_mat_id : int&)
  var result = false
  out_max_dist = 100.0
  out_ray_mat_id = -1
  query(human_eid) <| $ [es] (squad_member__squad : EntityId;
                              var human_context_command__rayMatId : int&)
    result = true
    query(squad_member__squad) <| $ [es] (squad__maxOrderDistance : float; squad__orderDistanceSub : float)
      out_max_dist = min(out_max_dist, squad__maxOrderDistance - squad__orderDistanceSub)

    if human_context_command__rayMatId < 0
      query(human_eid) <| $ [es] (human_context_command__rayMat : string)
        human_context_command__rayMatId = get_material_id(human_context_command__rayMat)
    out_ray_mat_id = human_context_command__rayMatId
  return result

def private find_closest_outside_bbox_pos(ri_desc : RendInstDesc; pos : float3; trace_pos : float3; soldier_radius : float;
                                          var correctedPos : float3&)
  let riBbox = getRIGenBBox(RendInstDesc(ri_desc.riExtraHandle))
  let riTm = getRIGenMatrix(RendInstDesc(ri_desc.riExtraHandle))
  let invRiTm = inverse(riTm)
  let localPos = invRiTm * pos
  if riBbox & localPos
    let localTracePos = invRiTm * trace_pos
    let localDirXZ = normalize(x0z(localTracePos - localPos))
    let bmin = riBbox.boxMin
    let bmax = riBbox.boxMax

    let d0 = localPos.x - bmin.x
    let d1 = bmax.x - localPos.x
    let d2 = localPos.z - bmin.z
    let d3 = bmax.z - localPos.z

    let n0 = float3(1.0, 0.0, 0.0)
    let n1 = float3(-1.0, 0.0, 0.0)
    let n2 = float3(0.0, 0.0, 1.0)
    let n3 = float3(0.0, 0.0, -1.0)

    let dd0 = (dot(localDirXZ, n0) < 0.0) ? d0 : VERY_BIG_NUMBER
    let dd1 = (dot(localDirXZ, n1) < 0.0) ? d1 : VERY_BIG_NUMBER
    let dd2 = (dot(localDirXZ, n2) < 0.0) ? d2 : VERY_BIG_NUMBER
    let dd3 = (dot(localDirXZ, n3) < 0.0) ? d3 : VERY_BIG_NUMBER

    var minDist = dd0
    var minIdx = 0
    if dd1 < minDist
      minDist = dd1; minIdx = 1
    if dd2 < minDist
      minDist = dd2; minIdx = 2
    if dd3 < minDist
      minDist = dd3; minIdx = 3

    var localProj = localPos
    if minIdx == 0
      localProj.x = bmin.x - soldier_radius
    elif minIdx == 1
      localProj.x = bmax.x + soldier_radius
    elif minIdx == 2
      localProj.z = bmin.z - soldier_radius
    else
      localProj.z = bmax.z + soldier_radius
    correctedPos = riTm * localProj
    return true
  return false

def trace_human_context_command_order_pos(var out_pos : float3&; human_eid : EntityId;
                                          trace_pos : float3; trace_dir : float3; active_tracing : bool; var trace_handle : TraceMeshFaces?)
  var maxLen : float; var rayMat : int
  if !get_human_context_order_trace_params(human_eid, maxLen, rayMat)
    return false
  var res = false

  var len = maxLen
  var pmid : int
  var norm : float3
  var riDesc = RendInstDesc()
  if traceray_normalized(trace_pos, trace_dir, len, pmid, norm, ETF_ALL, riDesc, rayMat)
    trace_human_context_vehicles(trace_pos, trace_dir, len, false)

    let tracedLen = len
    let BACK_FROM_TRACED = 0.05
    len = max(len - BACK_FROM_TRACED, 0.0)

    
    

    let SOLDIER_RADIUS = 0.35
    let HIGHER_ABOVE = 0.1
    let pos = trace_pos + trace_dir * len + float3(0.0, HIGHER_ABOVE, 0.0)

    var correctedPos = float3()
    var hasCorrectedDeniedRiPos = false
    query() <| $ [es] (human_context_command__traceHandleResetDist : float;
                       var human_context_command__traceHandlePosCached : float3&;
                       var human_context_command__pointOrderDeniedRIPools : IntList&)
      assume deniedPools = human_context_command__pointOrderDeniedRIPools
      if !riDesc.isValid || !riDesc.isRiExtra
        return
      let riPool = int(handle_to_ri_type(riDesc.riExtraHandle))
      if riPool >= 0
        let needInit = length(deniedPools) == 0
        if riPool >= length(deniedPools)
          deniedPools |> resize(1 + riPool)
        if deniedPools[riPool] == 0
          deniedPools[riPool] = calculate_ri_denied_for_context_command_point_order(riPool, deniedPools, needInit)
        if deniedPools[riPool] == 1
          hasCorrectedDeniedRiPos = find_closest_outside_bbox_pos(riDesc, pos, trace_pos, SOLDIER_RADIUS, correctedPos)
      if distance_sq(pos, human_context_command__traceHandlePosCached) > square(human_context_command__traceHandleResetDist)
        let traceCachePos = pos + float3(0.0, 0.5, 0.0)
        update_human_context_trace_cache(traceCachePos, 4.5, 2.0, *trace_handle)
        human_context_command__traceHandlePosCached = pos

    let MAX_STEPS = active_tracing ? 15 : 1
    let STEP_DIST = 0.2
    let correctedPosIsNear = hasCorrectedDeniedRiPos && distance_sq(correctedPos.xz, pos.xz) < square(STEP_DIST * float(MAX_STEPS))
    let checkPos = hasCorrectedDeniedRiPos ? correctedPos : pos
    let inDir = normalize(x0z(trace_dir))
    let rtDir = float3(trace_dir.z, 0.0, -trace_dir.x)
    let mixDir1 = inDir * 0.9 + rtDir * 0.5
    let mixDir2 = inDir * 0.9 - rtDir * 0.5
    if active_tracing && (!hasCorrectedDeniedRiPos || correctedPosIsNear)
      for i in range(MAX_STEPS)
        let offs = STEP_DIST * float(i)
        out_pos = checkPos - inDir * (SOLDIER_RADIUS + offs)
        if trace_human_context_pos_down(out_pos, true, rayMat, trace_handle)
          res = true
          break
        out_pos = checkPos - mixDir1 * (SOLDIER_RADIUS + offs)
        if trace_human_context_pos_down(out_pos, true, rayMat, trace_handle)
          res = true
          break
        out_pos = checkPos - mixDir2 * (SOLDIER_RADIUS + offs)
        if trace_human_context_pos_down(out_pos, true, rayMat, trace_handle)
          res = true
          break
    if !res
      for i in range(MAX_STEPS)
        out_pos = pos - inDir * (SOLDIER_RADIUS + 0.1 * float(i))
        if trace_human_context_pos_down(out_pos, false, rayMat, trace_handle)
          res = true
          break

    if res && active_tracing 
      let lookDir = normalize(out_pos - trace_pos)
      let dist = distance(trace_pos, out_pos)
      len = dist
      let DIST_EPS = 0.01
      if traceray_normalized(trace_pos, lookDir, len, pmid, norm, ETF_ALL, riDesc, rayMat)
        if len < dist - DIST_EPS
          var overPos : float3
          if trace_human_context_pos_over(overPos, trace_pos, trace_dir, maxLen, tracedLen, rayMat, trace_handle)
            out_pos = overPos
            res = true
  if !res && active_tracing
    if trace_human_context_pos_over(out_pos, trace_pos, trace_dir, maxLen, FLT_MAX, rayMat, trace_handle)
      res = true

  return res


def trace_human_context_command_first_ahead_object_eid(human_eid : EntityId; trace_pos : float3; trace_dir : float3; var out_dist : float&)
  var maxLen : float; var rayMat : int
  if !get_human_context_order_trace_params(human_eid, maxLen, rayMat)
    return INVALID_ENTITY_ID
  return trace_human_context_command_first_ahead_object_eid(trace_pos, trace_dir, maxLen, rayMat, human_eid, out_dist)

def trace_human_context_command_first_ahead_object_eid(trace_pos : float3; trace_dir : float3; trace_max_len : float;
                                                       ray_mat : int; ignore_eid : EntityId; var out_dist : float&)
  var retEid = INVALID_ENTITY_ID
  var retDist = FLT_MAX
  var pmid : int
  var norm : float3
  let d = trace_max_len < 0.0 ? 100.0 : trace_max_len
  var t : float = d
  using() <| $(var desc : RendInstDesc#)
    if traceray_normalized(trace_pos, trace_dir, t, pmid, norm, ETF_ALL, desc, ray_mat)
      retDist = t
      let handle = desc.riExtraHandle
      if handle != RIEX_HANDLE_NULL
        let riEid = find_ri_extra_eid(handle)
        if riEid != INVALID_ENTITY_ID && riEid != ignore_eid
          retEid = riEid
  using() <| $(var intersections : IntersectedEntities)
    trace_entities_in_grid(ecs_hash("humans"), trace_pos, trace_dir, t, ignore_eid, intersections, SortIntersections.NO)
    trace_entities_in_grid(ecs_hash("vehicles"), trace_pos, trace_dir, t, ignore_eid, intersections, SortIntersections.NO)
    for isect in intersections
      if get_bool(isect.eid, "animchar__visible") ?? true
        if isect.t < retDist
          retEid = isect.eid
          retDist = isect.t
  if retEid == INVALID_ENTITY_ID
    using() <| $(var desc : RendInstDesc#)
      t = d
      if traceray_normalized(trace_pos, trace_dir, t, pmid, norm, ETF_ALL, desc, -1)
        retDist = t
        let handle = desc.riExtraHandle
        if handle != RIEX_HANDLE_NULL
          let riEid = find_ri_extra_eid(handle)
          if riEid != INVALID_ENTITY_ID && riEid != ignore_eid
            retEid = riEid
  out_dist = retDist
  return retEid

def trace_human_context_corner_peek(target_pos : float3; target_dir : float3; var out_cover_pos : float3&; var out_peek_dir : float3&)
  let LEAN_DIST = 0.35
  let TRACE_SIGHT_DIST = 2.5
  let TRACE_SIGHT_RADIUS = 0.2
  let TRACE_SIGHT_HEIGHT = 1.0
  let TRACE_COVER_DIST = 0.75
  let TRACE_COVER_STRAFE_BACK_DIST = 0.3
  let TRACE_COVER_RADIUS = 0.1

  let lookDir = normalize(x0z(target_dir))
  let strafeLeftDir = float3(-lookDir.z, 0, lookDir.x)
  let leanPosLeft = target_pos + strafeLeftDir * LEAN_DIST + float3(0, 1, 0) * TRACE_SIGHT_HEIGHT
  let leanPosRight = target_pos - strafeLeftDir * LEAN_DIST + float3(0, 1, 0) * TRACE_SIGHT_HEIGHT

  var queryOut = ShapeQueryOutput()
  let leftLeanPossible = !sphere_cast(leanPosLeft, leanPosLeft + lookDir * TRACE_SIGHT_DIST, TRACE_SIGHT_RADIUS, queryOut)
  queryOut = ShapeQueryOutput()
  let rightLeanPossible = !sphere_cast(leanPosRight, leanPosRight + lookDir * TRACE_SIGHT_DIST, TRACE_SIGHT_RADIUS, queryOut)
  if leftLeanPossible == rightLeanPossible
    return false

  let coverDir = leftLeanPossible ? -strafeLeftDir : strafeLeftDir
  let coverTracePos = target_pos - lookDir * TRACE_COVER_STRAFE_BACK_DIST + float3(0, 1, 0) * TRACE_SIGHT_HEIGHT
  let coverPos = coverTracePos + coverDir * TRACE_COVER_DIST
  queryOut = ShapeQueryOutput()
  let canStrafeToCover = !sphere_cast(coverTracePos, coverPos, TRACE_SIGHT_RADIUS, queryOut)
  if !canStrafeToCover
    return false
  queryOut = ShapeQueryOutput()
  let isCoverSafe = sphere_cast(coverPos, coverPos + lookDir, TRACE_COVER_RADIUS, queryOut)
  if !isCoverSafe
    return false

  out_cover_pos = coverTracePos + coverDir * TRACE_COVER_DIST
  out_peek_dir = lookDir
  return true

def draw_human_context_command_sight_distance(target_pos : float3; target_dir : float3; traced_dist : float; crouched : bool)
  let TRACE_HEIGHT = crouched ? 0.75 : 1.3
  let TRACE_RADIUS = 0.2
  let tracePos = target_pos + float3(0.0, TRACE_HEIGHT, 0.0)
  let showDist = traced_dist < 0.0 ? 100.0 : traced_dist

  let STEP = 0.25
  for i in range(15)
    var dist = float(i + 1) * STEP
    if dist >= showDist
      dist = showDist
    draw_debug_sphere_buffered(tracePos + target_dir * dist, TRACE_RADIUS, E3DCOLOR(0x330000FF), 12, 10)
    if dist >= showDist
      break

def trace_human_context_command_sight_distance(trace_params : TraceSightDistanceParams; target_pos : float3; target_dir : float3; trace_dist : float;
                                               height_of_sight : HumanPointOrderHeightOfSight; var trace_handle : TraceMeshFaces&; trace_radius = 0.2)
  let traceHeight = match_height_of_sight(height_of_sight)
  let tracePos = target_pos + float3(0.0, traceHeight, 0.0)

  var queryOut = ShapeQueryOutput()
  let tracePosTo = tracePos + target_dir * trace_dist
  if sphere_cast_ex_ref_trace_handle(tracePos, tracePosTo, trace_radius, queryOut, trace_params.rayMatId, trace_handle, ORDER_SPHERE_CAST_MASK)
    var dist = max(0.0, queryOut.t * trace_dist)
    if traceHeight < 1.0
      trace_human_context_vehicles(tracePos, target_dir, dist, false)
    return dist
  if traceHeight < 1.0
    var dist = trace_dist
    if trace_human_context_vehicles(tracePos, target_dir, dist, false)
      return dist
  return -1.0

def private hcc_scan_ray(var out_dir_dist : float4&; trace_pos : float3; trace_dir : float3; trace_rt : float3;
                         yaw_deg : float; pitch_deg : float; min_dist : float; max_dist : float; ray_mat : int)
  var ck, sk : float
  sincos(deg_to_rad(yaw_deg), sk, ck)
  var dir = trace_dir * ck + trace_rt * sk

  if pitch_deg != 0.0
    let trace_up = cross(trace_dir, trace_rt)
    sincos(deg_to_rad(pitch_deg), sk, ck)
    dir = dir * ck + trace_up * sk

  var pmid : int
  var norm : float3
  var riDesc = RendInstDesc()

  var dist = max_dist
  if !traceray_normalized(trace_pos, dir, dist, pmid, norm, ETF_ALL, riDesc, ray_mat)
    dist = FLT_MAX
  if min_dist > 0.0 && dist < min_dist
    dist = dist

  out_dir_dist.x = dir.x
  out_dir_dist.y = dir.y
  out_dir_dist.z = dir.z
  out_dir_dist.w = dist

def private hcc_test_grenade_pos(pos : float3; dir : float3; ray_mat : int)
  let GRENADE_CHECK_RADIUS = 0.2
  let GRENADE_FLY_DISTANCE = 3.0

  let rad = GRENADE_CHECK_RADIUS
  let pos1 = pos - dir * GRENADE_FLY_DISTANCE
  let pos2 = pos + dir * GRENADE_FLY_DISTANCE
  var tmp = 0
  var queryOut = ShapeQueryOutput()
  sphere_cast_land(pos1, pos2, rad, queryOut)
  sphere_query_ri(pos1, pos2, rad, queryOut, ray_mat, null) <| $(desc : RendInstDesc; t : float)
    if desc.cellIdx == 0 && t < 0.0
      tmp += 1
    return true
  if abs(queryOut.t - 1.0) > 0.001
    return false
  return true

def trace_human_context_command_grenade_pos(var out_pos : float3&; var out_dir : float3&; draw_debug : bool;
                                            human_eid : EntityId; trace_pos : float3; trace_dir : float3)
  let result = true  
  out_pos = float3() 
  out_dir = float3() 

  var maxLen : float; var rayMat : int
  if !get_human_context_order_trace_params(human_eid, maxLen, rayMat)
    return false

  var cdist = FLT_MAX
  query(human_eid) <| $ [es] (human_context_command__pointOrderMaxDistGrenade = 30.0)
    maxLen = min(maxLen, human_context_command__pointOrderMaxDistGrenade)

    let minDist = 5.0
    let maxDist = maxLen

    let trace_rt = normalize(float3(trace_dir.z, 0.0, -trace_dir.x))

    var central : float4
    hcc_scan_ray(central, trace_pos, trace_dir, trace_rt, 0.0, 0.0, minDist, maxDist, rayMat)
    cdist = central.w

    out_pos = trace_pos + central.xyz * min(central.w, maxLen)
    out_dir = float3()

    let DIVS = 8
    let STEPS = 16

    var scans : array<float4>
    resize(scans, DIVS * STEPS)

    let stepAng = 1.0

    let divStepAng = TWOPI / float(DIVS)
    for div in range(DIVS)
      for step in range(STEPS)
        let divAng = float(div - step / 2) * divStepAng - (float(step % 2) * divStepAng * 0.5)
        var ck, sk : float; sincos(divAng, sk, ck)

        let distAng = float(1 + step) * stepAng
        let yawDeg = distAng * ck
        let pitchDeg = distAng * sk

        var scan : float4
        hcc_scan_ray(scan, trace_pos, trace_dir, trace_rt, yawDeg, pitchDeg, minDist, maxDist, rayMat)

        
        
        
        

        scans[div * STEPS + step] = scan

    let ROWS = STEPS * 2 - 1

    var cntrs : array<float3>
    var norms : array<float3>
    resize(cntrs, DIVS * ROWS)
    resize(norms, DIVS * ROWS)

    let div3 = 1.0 / 3.0
    for div in range(DIVS)
      for row in range(ROWS)
        let idx = div * ROWS + row
        let degen = row > 20 && (((row % 2) == 0) || ((idx % 2) == 1))
        if degen
          cntrs[idx] = float3()
          norms[idx] = float3()
          continue
        let step1 = row > 0 ? ((row - 1) / 2) : -1
        let step2 = step1 + 1
        let even = (row % 2) == 0
        let ndiv = (div + 1) % DIVS
        let base = div * STEPS
        let nbase = ndiv * STEPS
        let i1 = (step1 < 0) ? -1 : (base + step1)
        let i2 = even ? (base + step2) : (nbase + step2)
        let i3 = even ? (nbase + step2) : (nbase + step1)
        let s1 = i1 >= 0 ? scans[i1] : central
        let s2 = i2 >= 0 ? scans[i2] : central
        let s3 = i3 >= 0 ? scans[i3] : central
        if s1.w == FLT_MAX || s2.w == FLT_MAX || s3.w == FLT_MAX
          cntrs[idx] = float3()
          norms[idx] = float3()
          continue
        let zThreshold = 1.0
        if abs(s1.w - s2.w) > zThreshold || abs(s1.w - s3.w) > zThreshold || abs(s2.w - s3.w) > zThreshold
          cntrs[idx] = float3()
          norms[idx] = float3()
          continue
        let p1 = trace_pos + s1.xyz * s1.w
        let p2 = trace_pos + s2.xyz * s2.w
        let p3 = trace_pos + s3.xyz * s3.w
        cntrs[idx] = (p1 + p2 + p3) * div3
        norms[idx] = normalize(cross(p3 - p1, p2 - p1))

        
        
        
        
        

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    var cluss : array<int>
    
    resize(cluss, DIVS * ROWS)
    
    for i in range(DIVS * ROWS)
      cluss[i] = -1
      

    
    var clustSumP : array<float3>
    var clustSumN : array<float3>
    var clustCount : array<int>
    var clustNearPt : array<float3>

    let MIN_CLUSTERS = 16
    
    reserve(clustSumP, MIN_CLUSTERS)
    reserve(clustSumN, MIN_CLUSTERS)
    reserve(clustCount, MIN_CLUSTERS)
    reserve(clustNearPt, MIN_CLUSTERS)

    let dotThreshold = 0.92
    let ddThreshold = 0.15

    var all = false
    var lim = 10
    while !all && lim-- > 0
      all = true
      for div in range(DIVS)
        for row in range(ROWS)
          let idx = div * ROWS + row
          let norm = norms[idx]
          if norm == float3()
            continue
          if cluss[idx] < 0
            all = false
            let cntr = cntrs[idx]

            var clust = -1
            var dbest = -1.0
            var cbest = -1.0
            for ci in iter_range(clustCount)
              let invCountCoef = 1.0 / float(clustCount[ci])
              let cpos = clustSumP[ci] * invCountCoef
              let cnorm = clustSumN[ci] * invCountCoef
              let dd = dot(cnorm, cntr) - dot(cnorm, cpos)
              let dp = dot(norm, cnorm)
              if abs(dd) < ddThreshold && dp > dotThreshold
                if clust < 0 || (dd < dbest && dp < cbest)
                  clust = ci
                  dbest = dd
                  cbest = dp

            if clust >= 0
              cluss[idx] = clust
              
              
              clustSumP[clust] += cntr
              clustSumN[clust] += norm
              clustCount[clust] += 1
              let distSq = distance_sq(cntr, trace_pos)
              let curDistSq = distance_sq(clustNearPt[clust], trace_pos)
              if distSq < curDistSq
                clustNearPt[clust] = cntr
            else
              clust = length(clustCount)
              
              clustSumP |> push(cntr)
              clustSumN |> push(norm)
              clustCount |> push(1)
              clustNearPt |> push(cntr)
              cluss[idx] = clust
              

    var cntrCluss : array<bool>
    resize(cntrCluss, length(clustCount))
    for div in range(DIVS)
      let clust = cluss[div * ROWS]
      if clust >= 0
        cntrCluss[clust] = true

    var bestClust = -1
    var bestValue = FLT_MAX
    var bestNorm = float3()
    var bestPos = float3()
    let MIN_POINTS_IN_CLUSTER = 5
    for ci in iter_range(clustCount)
      if cntrCluss[ci]
        continue
      let numPts = clustCount[ci]
      if numPts < MIN_POINTS_IN_CLUSTER
        continue
      let invCountCoef = 1.0 / float(numPts)
      let cnorm = clustSumN[ci] * invCountCoef
      if abs(cnorm.y) > 0.7 || dot(cnorm, trace_dir) < -0.2
        continue
      let nearPt = clustNearPt[ci]
      let value = float(numPts) / distance_sq(trace_pos, nearPt)
      if bestClust < 0 || value > bestValue
        bestClust = ci
        bestValue = value
        bestNorm = cnorm
        bestPos = clustSumP[ci] * invCountCoef

    if bestClust < 0
      for ci in iter_range(clustCount)
        let numPts = clustCount[ci]
        if numPts < MIN_POINTS_IN_CLUSTER
          continue
        let invCountCoef = 1.0 / float(numPts)
        let cnorm = clustSumN[ci] * invCountCoef
        if abs(cnorm.y) > 0.7
          continue
        let nearPt = clustNearPt[ci]
        let value = float(numPts) / distance_sq(trace_pos, nearPt)
        if bestClust < 0 || value > bestValue
          bestClust = ci
          bestValue = value
          bestNorm = cnorm
          bestPos = clustNearPt[ci]

    if bestClust >= 0
      let P = -dot(bestNorm, trace_pos - bestPos)
      let Q = dot(bestNorm, trace_dir)
      if abs(Q) > 0.0001
        let t = P / Q
        if t > 0.0
          let gotPos = trace_pos + trace_dir * t
          if distance_sq(trace_pos, gotPos) < distance_sq(trace_pos, out_pos)
            let gotDir = bestNorm
            if dot(trace_dir, gotDir) < 0.0
              
              

              let up1 = float3(0.0, 0.1, 0.0)
              let up2 = float3(0.0, 0.2, 0.0)

              if hcc_test_grenade_pos(gotPos, gotDir, rayMat)
                out_pos = gotPos
                out_dir = gotDir
              elif hcc_test_grenade_pos(gotPos + up1, gotDir, rayMat)
                out_pos = gotPos + up1 + up1
                out_dir = gotDir
              elif hcc_test_grenade_pos(gotPos + up2, gotDir, rayMat)
                out_pos = gotPos + up2 + up1
                out_dir = gotDir

              
              
              
              
              

    for div in range(DIVS)
      for row in range(ROWS)
        let idx = div * ROWS + row
        if norms[idx] == float3()
          continue

        if draw_debug && cluss[idx] == bestClust
          draw_debug_sphere_buffered(cntrs[idx], 0.05, E3DCOLOR(0xFFFF0000), 12, 10)

        if draw_debug
          let pt1 = cntrs[idx]
          let pt2 = cntrs[idx] + norms[idx] * 0.08
          let pt3 = cntrs[idx] + norms[idx] * 0.1
          draw_debug_line_buffered(pt1, pt3, E3DCOLOR(0xFF0000FF), 10)
          draw_debug_line_buffered(pt2, pt3, E3DCOLOR(0xFF00FFFF), 10)

        
        
        
        
        
        
        

  if cdist == FLT_MAX
    let FORWARD_DISTANCE = 50.0
    out_pos = trace_pos + trace_dir * FORWARD_DISTANCE
    out_dir = -normalize(x0z(trace_dir))

  if draw_debug
    draw_debug_line_buffered(out_pos - out_dir * 0.5, out_pos + out_dir * 0.5, E3DCOLOR(0xFF00FF00), 10)
    draw_debug_sphere_buffered(out_pos - out_dir * 0.5, 0.05, E3DCOLOR(0xFF00FF00), 12, 10)
    draw_debug_sphere_buffered(out_pos - out_dir * 0.5 * 1.1, 0.03, E3DCOLOR(0xFF00FF00), 8, 10)
    draw_debug_sphere_buffered(out_pos - out_dir * 0.5 * 1.2, 0.02, E3DCOLOR(0xFF00FF00), 6, 10)
  return result


def trace_human_context_command_sphere(trace_pos, trace_dir : float3; pos : float3; radius : float; var out_dist : float&) : bool
  let dcenter = trace_pos - pos
  let b = 2.0f * dot(dcenter, trace_dir)
  let c = dot(dcenter, dcenter) - radius * radius
  let d = b * b - 4.0 * c
  if (d < 0.0f)
    return false
  let sq = sqrt(d)
  let v0 = (-b - sq) * 0.5
  let v1 = (-b + sq) * 0.5
  if v0 >= 0.0
    if v1 >= 0.0
      out_dist = min(v0, v1)
      return true
    out_dist = v1
  elif v1 >= 0.0
    out_dist = v0
    return true
  return false

def get_human_context_soldier_selection_sphere(soldier_eid : EntityId; var out_pos : float3&; var out_rad : float&)
  var result = false
  query(soldier_eid) <| $ [es] (isAlive : bool; isDowned : bool; human_net_phys : HumanActor; transform : float3x4)
    if !isAlive || isDowned
      return
    result = true
    let standState = human_net_phys.phys.currentState.standState
    if standState == HUStandState.ESS_STAND
      out_pos = transform[3] + float3(0.0, 1.2, 0.0) + transform[0] * 0.2
      out_rad = 0.55
    elif standState == HUStandState.ESS_CROUCH
      out_pos = transform[3] + float3(0.0, 0.6, 0.0) + transform[0] * 0.3
      out_rad = 0.55
    elif standState == HUStandState.ESS_CRAWL
      out_pos = transform[3] + float3(0.0, 0.0, 0.0) + transform[0] * 0.5
      out_rad = 0.6
    else
      out_pos = transform[3] + float3(0.0, 1.0, 0.0)
      out_rad = 1.8
  return result

def trace_human_context_command_squad_mate(var out_eid : EntityId&; human_eid : EntityId; trace_pos : float3; trace_dir : float3)
  out_eid = INVALID_ENTITY_ID
  var bestDist = FLT_MAX
  query(human_eid) <| $ [es] (squad_member__squad : EntityId)
    query(squad_member__squad) <| $ [es] (squad__allMembers : EidList)
      for memberEid in squad__allMembers
        if memberEid != human_eid
          var matePos = float3()
          var mateRad = 0.0
          if get_human_context_soldier_selection_sphere(memberEid, matePos, mateRad)
            
            var dist : float
            if trace_human_context_command_sphere(trace_pos, trace_dir, matePos, mateRad, dist)
              if dist > 0.0 && dist < bestDist
                out_eid = memberEid
                bestDist = dist
  return out_eid != INVALID_ENTITY_ID
