module squad_common shared
require ecs
require pathfinder
require DngWalkerai
require math
require math.base
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums

struct SquadPos
  p : float3
  isValidPt : bool

def find_best_squad_pos_impl(leader_tm : float3x4; offset : float3; min_distance : float; forceSpread; swim) : SquadPos
  let extents = float3(0.8, FLT_MAX, 0.8)
  let projExtents = float3(0.8, 2.5, 0.8)
  var center = leader_tm[3]
  if !swim
    pathfinder::project_to_nearest_navmesh_point_no_obstacles(center, projExtents)

  var wishPosition = SquadPos(p = leader_tm * offset, isValidPt = true)
  var resPos = wishPosition
  if !swim
    wishPosition.isValidPt = pathfinder::project_to_nearest_navmesh_point_no_obstacles(wishPosition.p, projExtents)
    pathfinder::traceray_navmesh(center, wishPosition.p, extents, resPos.p)
    resPos.isValidPt = wishPosition.isValidPt
  if length_sq(offset) < FLT_EPSILON
    return resPos

  var positions = fixed_array<SquadPos>(wishPosition, wishPosition, wishPosition)
  var currentOffset = offset
  for iter in range(0, 2)
    let distSq = distance_sq(resPos.p, center)
    if distSq >= square(min_distance) && distSq <= 2f * length_sq(currentOffset)
      return resPos
    currentOffset = float3(1 << (iter + 1)) * offset
    wishPosition.p = leader_tm * currentOffset
    wishPosition.isValidPt = true
    if !swim
      wishPosition.isValidPt = pathfinder::project_to_nearest_navmesh_point_no_obstacles(wishPosition.p, projExtents)
      pathfinder::traceray_navmesh(center, wishPosition.p, extents, resPos.p)
      resPos.isValidPt = wishPosition.isValidPt
    positions[iter + 1] = wishPosition

  if !forceSpread
    return SquadPos(p = center, isValidPt = true)

  for iter, pos in range(0, 2), positions
    let distSq = distance_sq(pos.p, center)
    currentOffset = float3(1 << (iter + 1)) * offset
    if distSq >= square(min_distance) && distSq <= 2f * length_sq(currentOffset)
      return pos
  return resPos

def find_best_squad_pos(leader_tm : float3x4; offset : float3; min_distance : float; forceSpread = false; swim = false) : float3
  return find_best_squad_pos_impl(leader_tm, offset, min_distance, forceSpread, swim).p

def find_best_squad_pos(leader : EntityId; order_type : int; regroup_pos : float3; offset : float3; min_distance : float) : SquadPos
  var targetTm = IDENT_TM
  var swim = false

  let followLead = order_type == int(SquadOrder.ESO_FOLLOW_ME)
  query(leader) <| $ [es] (transform : float3x4; human_net_phys__isSwimming : bool = false)
    if followLead
      targetTm = transform
    swim = human_net_phys__isSwimming
  targetTm[3] = regroup_pos

  var res = find_best_squad_pos_impl(targetTm, offset, min_distance, followLead, swim)
  if !followLead
    res.isValidPt = true
  return res
