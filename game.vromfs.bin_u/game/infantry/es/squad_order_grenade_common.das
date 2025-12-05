module squad_order_grenade_common shared

require ecs
require math
require math.base
require DagorMath

require net

require %appGame.wt_events

require DngWeapon
require PropsManager
require DaWeaponProps
require Ballistics
require BallisticsProps
require %appGame.infantry.es.inventory_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums

require pathfinder
require Dacoll
require PhysMat

require DagorDebug3D


def private test_grenade_collision(pos1 : float3; pos2 : float3; ray_mat : int; last_trace : bool)
  let vec = pos2 - pos1
  let dist = length(vec)
  let dir = vec * safeinv(dist)
  if rayhit_normalized(pos1, dir, dist, ETF_ALL, -1)
    return true
  let GRENADE_CHECK_RADIUS = 0.42
  let LAST_TRACE_GRENADE_CHECK_RADIUS = 0.3
  let rad = last_trace ? LAST_TRACE_GRENADE_CHECK_RADIUS : GRENADE_CHECK_RADIUS
  var tmp = 0
  var queryOut = ShapeQueryOutput()
  sphere_cast_land(pos1, pos2, rad, queryOut)
  sphere_query_ri(pos1, pos2, rad, queryOut, ray_mat, null) <| $(desc : RendInstDesc; t : float)
    if desc.cellIdx == 0 && t < 0.0
      tmp += 1
    return true
  if last_trace
    return queryOut.t < 0.5
  else
    return queryOut.t < 0.999

def private check_grenade_trajectory(soldier_eid : EntityId; from_pos : float3; to_pos : float3; var out_alt_pos : float3&; grenade_eid : EntityId; draw_debug : bool)
  out_alt_pos = float3()
  if soldier_eid == INVALID_ENTITY_ID
    return false

  let MIN_DIST = 5.0
  if distance_sq(from_pos, to_pos) < square(MIN_DIST)
    return false

  var vel = 15.0
  
  query(grenade_eid) <| $ [es] (shell_props : PropsId)
    shell_start_get_props(shell_props) <| $(shellStartProps : ShellStartProps)
      vel = shellStartProps.speed
      

  query(soldier_eid) <| $ [es] (entity_mods__grenadeThrowDistMult : float)
    vel *= entity_mods__grenadeThrowDistMult

  let delta = to_pos - from_pos
  let dirXZ = delta.xz

  let lenOffset = 0.0 
  let lenXZ = length(dirXZ)
  let len = lenXZ + lenOffset

  var theta = 0.0
  if !calculate_arc_low_angle(len, delta.y, vel, theta)
    let ALT_MIN_FAR = 35.0
    if length_sq(delta) >= square(ALT_MIN_FAR)
      let ALT_LEN = 15.0
      var forwDir = normalize(delta)
      if lenXZ > 0.0
        forwDir.y += cvt(max(0.0, delta.y) / lenXZ, 0.0, 10.0, 1.0, 0.0)
        forwDir = normalize(forwDir)
      let tryToPos = from_pos + ALT_LEN * forwDir
      let tryDelta = tryToPos - from_pos
      let tryLen = length(tryDelta.xz) + lenOffset
      if calculate_arc_low_angle(tryLen, tryDelta.y, vel, theta)
        out_alt_pos = tryToPos
    return false

  
  

  var shootDir : float3
  calculate_arc_dir_by_theta(shootDir, dirXZ, theta)

  let LAST_SKIP_TIME = 0.05
  let checkTime = max(0.0, calculate_arc_time_by_theta(len, vel, theta) - LAST_SKIP_TIME)

  let rayMat = get_material_id("aimRay")

  

  let TRACE_PARTS = 16
  let timeStep = checkTime / float(TRACE_PARTS)
  var prevPoint = from_pos
  for i in range(TRACE_PARTS)
    let flyTime = timeStep * float(i + 1)
    var nextPoint : float3
    calculate_arc_point(from_pos, shootDir, vel, flyTime, nextPoint)
    if draw_debug
      draw_debug_line_buffered(prevPoint, nextPoint, E3DCOLOR(0xFFFF0000), 10000)
    if test_grenade_collision(prevPoint, nextPoint, rayMat, i == TRACE_PARTS - 1)
      if draw_debug
        draw_debug_sphere_buffered(to_pos, 0.2, E3DCOLOR(0xFFFF0000), 12, 15000)
      return false
    prevPoint = nextPoint

  if draw_debug
    prevPoint = from_pos
    for i in range(TRACE_PARTS)
      let flyTime = timeStep * float(i + 1)
      var nextPoint : float3
      calculate_arc_point(from_pos, shootDir, vel, flyTime, nextPoint)
      draw_debug_line_buffered(prevPoint, nextPoint, E3DCOLOR(0xFF00FF00), 10000)
      prevPoint = nextPoint
  return true


def squad_order_throw_grenade_execute(squad_eid : EntityId; grenade_type : string; order_type : int;
                                      order_pos : float3; order_dir : float3; order_alt_pos : float3)
  let drawDebug = find_query() <| $ [es] (debug__ai_grenades : bool)
    return debug__ai_grenades

  if !squad_order_throw_grenade_variants(squad_eid, grenade_type, order_type, order_pos, order_dir, order_alt_pos, drawDebug)
    query(squad_eid) <| $ [es] (squad__leader : EntityId)
      send_net_event(squad__leader, CmdHeroLogEvent(event = "squad_order_canceled", text = "squad_orders/no_way_to_throw_grenade_nobody_can_reach"))

def squad_order_throw_grenade_variants(squad_eid : EntityId; grenade_type : string; order_type : int;
                                       order_pos : float3; order_dir : float3; order_alt_pos : float3;
                                       draw_debug : bool)
  var justToPos = order_pos
  if order_dir != float3()
    let DIST_THROW_IN_1 = 0.7
    if squad_order_throw_grenade(squad_eid, grenade_type, order_type, order_pos - order_dir * DIST_THROW_IN_1, draw_debug)
      if draw_debug
        draw_debug_sphere_buffered(order_pos - order_dir * DIST_THROW_IN_1, 0.25, E3DCOLOR(0xFFFFFFFF), 12, 15000)
      return true
    let DIST_THROW_IN_2 = 0.2
    if squad_order_throw_grenade(squad_eid, grenade_type, order_type, order_pos - order_dir * DIST_THROW_IN_2, draw_debug)
      if draw_debug
        draw_debug_sphere_buffered(order_pos - order_dir * DIST_THROW_IN_2, 0.25, E3DCOLOR(0xFFFF00FF), 12, 15000)
      return true
    justToPos = order_alt_pos

  if justToPos != float3()
    var height = 1.85
    if tracedown_normalized(justToPos, height, ETF_ALL)
      let EPS_HT = 0.05
      justToPos -= float3(0.0, max(EPS_HT, height - EPS_HT), 0.0)
      if squad_order_throw_grenade(squad_eid, grenade_type, order_type, justToPos, draw_debug)
        if draw_debug
          draw_debug_sphere_buffered(justToPos, 0.25, E3DCOLOR(0xFF00FF00), 12, 15000)
        return true
      var dist = 1.0
      var norm : float3
      let dirUp = float3(0.0, 1.0, 0.0)
      if !traceray_normalized(justToPos, dirUp, dist, norm, ETF_ALL)
        justToPos.y += dist
        if squad_order_throw_grenade(squad_eid, grenade_type, order_type, justToPos, draw_debug)
          if draw_debug
            draw_debug_sphere_buffered(justToPos, 0.25, E3DCOLOR(0xFFFFFF00), 12, 15000)
          return true
    else
      if squad_order_throw_grenade(squad_eid, grenade_type, order_type, justToPos, draw_debug)
        if draw_debug
          draw_debug_sphere_buffered(justToPos, 0.25, E3DCOLOR(0xFF00FFFF), 12, 15000)
        return true

  return false

def squad_order_throw_grenade(squad_eid : EntityId; grenade_type : string; order_type : int; order_pos : float3; draw_debug : bool)
  var squadMemberEid = INVALID_ENTITY_ID
  var fromPos = float3()
  let toPos = order_pos

  var idxs : array<int>
  var eids : array<EntityId>
  var gids : array<EntityId>
  var dsqs : array<float>
  query(squad_eid) <| $ [es] (squad__allMembers : EidList; squad__leader : EntityId)
    let numMembers = length(squad__allMembers)
    idxs |> reserve(numMembers)
    eids |> reserve(numMembers)
    gids |> reserve(numMembers)
    dsqs |> reserve(numMembers)
    for memberEid in squad__allMembers
      if memberEid == squad__leader
        continue
      query(memberEid) <| $ [es] (isAlive : bool;
                                  isDowned : bool;
                                  transform : float3x4;
                                  itemContainer : EidList;
                                  squad_member__isPersonalOrder : bool;
                                  squad_member__orderType : int)
        if isAlive && !isDowned && (!squad_member__isPersonalOrder || !is_squad_mate_order_action(squad_member__orderType))
          let grenadeEid = find_grenade_of_type(itemContainer, grenade_type)
          if grenadeEid != INVALID_ENTITY_ID
            let distSq = distance_sq(toPos, transform[3])
            idxs |> push(length(idxs))
            eids |> push(memberEid)
            gids |> push(grenadeEid)
            dsqs |> push(distSq)
  idxs |> sort() <| $(left; right)
    return dsqs[left] < dsqs[right]

  let heightOffset = 1.55
  let heightOffsetVec = float3(0.0, heightOffset, 0.0)

  var altOutEid = INVALID_ENTITY_ID
  var altOutPos = float3()
  var altOutFrom = float3()

  let MAX_STEPS = 20
  let stepLen = 0.5
  let FORW_DIST = 5.0
  let forwStepLen = FORW_DIST / float(MAX_STEPS)
  for alt in range(0, 1 + MAX_STEPS * 4)
    let kind = alt > 0 ? (1 + ((alt - 1) & 3)) : 0
    let steps = alt > 0 ? 1 + ((alt - 1) / 4) : 0
    var toForw = 0.0
    var toSide = 0.0
    if kind <= 2
      toSide = float(steps) * stepLen * (kind == 1 ? -1.0 : 1.0)
      toForw = float(steps) * forwStepLen
    elif kind > 2
      toForw = float(steps) * stepLen * (kind == 3 ? -1.0 : 1.0)
    for i in iter_range(idxs)
      let idx = idxs[i]
      let memberEid = eids[idx]
      var memberPos = float3()
      query(memberEid) <| $ [es] (transform : float3x4)
        memberPos = transform[3]
      let grenadeEid = gids[idx]
      let throwDir = normalize(x0z(toPos - memberPos))
      let strafeDir = float3(-throwDir.z, 0.0, throwDir.x)
      fromPos = memberPos + throwDir * toForw + strafeDir * toSide
      if steps > 0
        if draw_debug
          draw_debug_sphere_buffered(fromPos, 0.1, E3DCOLOR(0xFF0000FF), 12, 15000)
        let extents = float3(0.1, FLT_MAX, 0.1)
        var hasPath = false
        find_path(memberPos, fromPos, extents, 0.5, 1.0) <| $(path)
          let numPoints = length(path)
          if numPoints <= 1
            return
          fromPos = path[numPoints - 1]
          hasPath = true
        if !hasPath
          continue
      var altPos = float3()
      if check_grenade_trajectory(memberEid, fromPos + heightOffsetVec, toPos, altPos, grenadeEid, draw_debug)
        squadMemberEid = memberEid
        break
      if altOutEid == INVALID_ENTITY_ID && altPos != float3()
        var tmpPos = float3()
        if check_grenade_trajectory(memberEid, fromPos + heightOffsetVec, altPos, tmpPos, grenadeEid, false)
          altOutEid = memberEid
          altOutPos = altPos
          altOutFrom = fromPos
    if squadMemberEid != INVALID_ENTITY_ID
      break

  if squadMemberEid != INVALID_ENTITY_ID
    send_net_event(squadMemberEid, RequestPersonalSquadMateOrder(orderType = order_type, orderPosition = fromPos, orderToPosition = toPos))
    return true

  if altOutEid != INVALID_ENTITY_ID
    send_net_event(altOutEid, RequestPersonalSquadMateOrder(orderType = order_type, orderPosition = altOutFrom, orderToPosition = altOutPos))
    return true

  return false
