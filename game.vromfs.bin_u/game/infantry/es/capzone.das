require ecs
require pathfinder
require DagorSystem
require DagorRandom
require math.base
require Mission
require %appGame.infantry.es.pathfinder_common


[event(unicast)]
struct InitCapzoneRadius {}


def get_respbases(var list : array<float3>; count : int = -1)
  var respawnsToFound = count
  get_respawn_points() <| $ [unused_argument(active, team)] (active, resptype, team, pos)
    if resptype == "human"
      list |> push(pos)
      respawnsToFound--
  return respawnsToFound == 0

def check_path_full(var in_out_pos : float3&; from_pos : float3; extents : float3; step_size : float; path_slope : float; reach_dist : float; reach_height : float)
  let reachDistSq = square(reach_dist)
  let maxPartial = 3
  let reachPt = in_out_pos
  var fromPt = from_pos
  var lastReachedPos = in_out_pos
  for _i in range(maxPartial)
    var reached = false
    let result = find_any_path(fromPt, reachPt, extents, step_size, path_slope, null) <| $(path)
      let len = length(path)
      if len > 1
        let DIST_EPS_SQ = square(0.01)
        var contIdx = len * 3 / 4
        while contIdx >= 1 && distance_sq(path[contIdx], path[len - 1]) < DIST_EPS_SQ
          contIdx--
        fromPt = path[contIdx]
        reached = distance_sq(reachPt.xz, path[len - 1].xz) < reachDistSq && abs(reachPt.y - path[len  - 1].y) < reach_height
        if reached
          lastReachedPos = path[len - 1]
    if result == FindPathResult.FPR_FAILED
      return false
    if reached && result == FindPathResult.FPR_FULL
      in_out_pos = lastReachedPos
      return true
  return false

def validate_pos_for_capzone(var in_out_pos : float3&; area_name : string; points_to_check : array<float3>)
  if !is_in_mission_area(in_out_pos, area_name)
    return false
  let extents = float3(1.5, FLT_MAX, 1.5)
  
  for point in points_to_check
    if check_path_full(in_out_pos, point, extents, 0.5, 0.1, 0.5, 1.0)
      return true
  return false

def get_nearest_pos(area_name : string; pos : float3; radius : float; points_to_check : array<float3>; skip_validate : bool) : MaybePos
  var nearestPos = get_lower_navmesh_pos(pos, radius) <| $(var p : float3&)
    return skip_validate || validate_pos_for_capzone(p, area_name, points_to_check)
  if nearestPos is invalid
    nearestPos = get_lower_navmesh_pos_in_radius(pos, radius) <| $(var p : float3&)
      return skip_validate || validate_pos_for_capzone(p, area_name, points_to_check)
  return nearestPos

def is_too_near(pos : float3; points : Point3List; min_dist_sq : float)
  for pt in points
    if abs(pt.y - pos.y) > 1.5
      continue
    if distance_sq(pos, pt) < min_dist_sq
      return true
  return false

def init_nearest_pos(eid : EntityId;
                     transform : float3x4;
                     capture_zone__name : string;
                     sphere_zone__radius : float;
                     capzone__approximateRadius : float;
                     points_to_check : array<float3>;
                     var capzone__hasNearestNavmeshPos : bool&;
                     var capzone__nearestNavmeshPos : float3&;
                     var capzone__insideNavmeshPositions : Point3List&;
                     var capzone__outsideNavmeshPositions : Point3List&;
                     capzone__extendOutsideNavMeshPositionsRadius : float;
                     capzone__minDistBetweenNavPoints : float;
                     capzone__maxInNavPoints : int;
                     capzone__maxOutNavPoints : int;
                     may_fail : bool = false)
  clear(capzone__insideNavmeshPositions)
  clear(capzone__outsideNavmeshPositions)

  capzone__hasNearestNavmeshPos = false
  let radius = sphere_zone__radius > 0.0 ? sphere_zone__radius : capzone__approximateRadius > 0.0 ? capzone__approximateRadius : 0.5 * min(length(transform[0]), length(transform[2]))

  let basePos = transform[3]
  var pos = get_nearest_pos(capture_zone__name, basePos, min(0.6f, radius), points_to_check, false)
  if pos is invalid
    pos = get_nearest_pos(capture_zone__name, basePos, min(4f, radius), points_to_check, false)
  capzone__hasNearestNavmeshPos = pos is pos
  if capzone__hasNearestNavmeshPos
    capzone__nearestNavmeshPos = pos as pos
  else
    if !may_fail
      logerr("can't find nearest navmesh position for capzone {capture_zone__name} <{getEntityTemplateName(eid)}> at {basePos}")
    pos = get_nearest_pos(capture_zone__name, basePos, min(0.6f, radius), points_to_check, true)
    if pos is invalid
      pos = get_nearest_pos(capture_zone__name, basePos, min(4f, radius), points_to_check, true)
    capzone__hasNearestNavmeshPos = true
    capzone__nearestNavmeshPos = basePos
    if pos is pos
      capzone__nearestNavmeshPos = pos as pos

  let projRadius = 1.5
  let distToPath = float3(0.5, FLT_MAX, 0.5)
  let stepSize = 0.5
  let pathSlop = 0.25

  let center = capzone__nearestNavmeshPos
  let inRadius  = radius
  let outRadius = inRadius + radius + capzone__extendOutsideNavMeshPositionsRadius
  let projExtents = float3(projRadius, FLT_MAX, projRadius)
  let minDistSq = square(capzone__minDistBetweenNavPoints)

  let tryCountCoef = 5
  let maxTries = max(capzone__maxInNavPoints, capzone__maxOutNavPoints) * tryCountCoef
  var leftIntPoints = capzone__maxInNavPoints
  var leftExtPoints = capzone__maxOutNavPoints

  let heightFloor = 2.0
  let heightOffset = -1.5
  let maxFloors = 3

  for _i in range(maxTries)
    if leftIntPoints <= 0 && leftExtPoints <= 0
      break

    if leftIntPoints > 0
      let px = center.x + rnd_float(-inRadius, inRadius)
      let pz = center.z + rnd_float(-inRadius, inRadius)
      let ph = heightFloor * float(rnd_int(0, maxFloors - 1))
      var inPos = float3(px, center.y + heightOffset + ph, pz)

      var tryNum = 5
      while tryNum-- > 0
        if project_to_nearest_navmesh_point_avoid_obstacles(inPos, projExtents)
          if !is_too_near(inPos, capzone__insideNavmeshPositions, minDistSq)
            if is_in_mission_area(inPos, capture_zone__name)
              if find_path(center, inPos, distToPath, stepSize, pathSlop) == FindPathResult.FPR_FULL
                push(capzone__insideNavmeshPositions, inPos)
                --leftIntPoints
                break
        var dx, dz : float; sincos(rnd_float(0.0, TWOPI), dx, dz)
        let dd = rnd_float(1.0, 2.0)
        inPos = float3(px + dx * dd, center.y + ph, pz + dz * dd)

    if leftExtPoints > 0
      let px = center.x + rnd_float(-outRadius, outRadius)
      let pz = center.z + rnd_float(-outRadius, outRadius)
      var outPos = float3(px, 0.0, pz)

      if project_to_nearest_navmesh_point_avoid_obstacles(outPos, projExtents)
        if !is_too_near(outPos, capzone__outsideNavmeshPositions, minDistSq)
          if !is_in_mission_area(outPos, capture_zone__name)
            if find_path(center, outPos, distToPath, stepSize, pathSlop) == FindPathResult.FPR_FULL
              push(capzone__outsideNavmeshPositions, outPos)
              --leftExtPoints

  if length(capzone__insideNavmeshPositions) == 0
    push(capzone__insideNavmeshPositions, center)
  if length(capzone__outsideNavmeshPositions) == 0
    push(capzone__outsideNavmeshPositions, center)

  sendEvent(eid, InitCapzoneRadius())

[es(tag=server, on_appear, REQUIRE_NOT=moveable_capzone)]
def capzone_init_nearest_navmesh_point(evt : Event;
                                       eid : EntityId;
                                       transform : float3x4;
                                       capture_zone__name : string;
                                       sphere_zone__radius : float = 0.0;
                                       capzone__approximateRadius : float = 0.0;
                                       var capzone__hasNearestNavmeshPos : bool&;
                                       var capzone__nearestNavmeshPos : float3&;
                                       var capzone__insideNavmeshPositions : Point3List&;
                                       var capzone__outsideNavmeshPositions : Point3List&;
                                       capzone__extendOutsideNavMeshPositionsRadius : float = 0.0;
                                       capzone__minDistBetweenNavPoints : float = 2.5;
                                       capzone__maxInNavPoints : int = 20;
                                       capzone__maxOutNavPoints : int = 30)
  if (find_query() <| $ [es(REQUIRE=navmeshDisabler)] () => true)
    return
  if pathfinder_is_loaded()
    var respbases : array<float3>
    get_respbases(respbases)
    init_nearest_pos(eid, transform, capture_zone__name, sphere_zone__radius, capzone__approximateRadius, respbases,
                     capzone__hasNearestNavmeshPos, capzone__nearestNavmeshPos,
                     capzone__insideNavmeshPositions, capzone__outsideNavmeshPositions,
                     capzone__extendOutsideNavMeshPositionsRadius, capzone__minDistBetweenNavPoints,
                     capzone__maxInNavPoints, capzone__maxOutNavPoints,
                      true) 

[es(tag=server, on_event=EventLevelLoaded)]
def capzone_init_all_nearest_navmesh_points(evt : Event)
  if (find_query() <| $ [es(REQUIRE=navmeshDisabler)] () => true)
    return
  var respbases : array<float3>
  get_respbases(respbases)
  query() <| $ [es(REQUIRE_NOT=moveable_capzone)] (eid : EntityId;
                                                   transform : float3x4;
                                                   capture_zone__name : string;
                                                   sphere_zone__radius : float = 0.0;
                                                   capzone__approximateRadius : float = 0.0;
                                                   var capzone__hasNearestNavmeshPos : bool&;
                                                   var capzone__nearestNavmeshPos : float3&;
                                                   var capzone__insideNavmeshPositions : Point3List&;
                                                   var capzone__outsideNavmeshPositions : Point3List&;
                                                   capzone__extendOutsideNavMeshPositionsRadius : float = 0.0;
                                                   capzone__minDistBetweenNavPoints : float = 2.5;
                                                   capzone__maxInNavPoints : int = 20;
                                                   capzone__maxOutNavPoints : int = 30)
    init_nearest_pos(eid, transform, capture_zone__name, sphere_zone__radius, capzone__approximateRadius, respbases,
                     capzone__hasNearestNavmeshPos, capzone__nearestNavmeshPos,
                     capzone__insideNavmeshPositions, capzone__outsideNavmeshPositions,
                     capzone__extendOutsideNavMeshPositionsRadius, capzone__minDistBetweenNavPoints,
                     capzone__maxInNavPoints, capzone__maxOutNavPoints)

[es(tag=server)]
def init_capzone_radius(evt : InitCapzoneRadius; transform : float3x4;
                        sphere_zone__radius : float = 0.0; capzone__approximateRadius : float = 0.0;
                        capzone__hasNearestNavmeshPos : bool; capzone__nearestNavmeshPos : float3;
                        var capzone__minRadius : float&)
  capzone__minRadius = sphere_zone__radius > 0.0 ? sphere_zone__radius : capzone__approximateRadius > 0.0 ? capzone__approximateRadius : 0.5 * min(transform[0] |> length(), transform[2] |> length())
  if capzone__hasNearestNavmeshPos
    capzone__minRadius = max(0f, capzone__minRadius - length(transform[3].xz - capzone__nearestNavmeshPos.xz))





