module ai_covers_common shared

require app
require ecs
require math
require math.base
require math.random
require pathfinder
require DagorMath
require Dacoll
require %appGame.infantry.es.walker_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums
require %appGame.infantry.es.team_common
require DngHuman
require walkerai
require Mission


struct FilterCoversInfo
  waterLevel : float
  waterWalkH : float

def get_filter_covers_info()
  var waterLevel = 0.0
  var waterWalkH = 0.1
  query() <| $ [es] (water__level : float;
                     water__smallWaterAIWalkHeight : float = 0.1)
    waterLevel = water__level
    waterWalkH = water__smallWaterAIWalkHeight
  return FilterCoversInfo(waterLevel = waterLevel, waterWalkH = waterWalkH)


def filter_cover(cover : Cover; var cover_desc : CoverDesc&; bbox, max_occupied, filter_info)
  if cover_desc.numUsedSlots >= length(cover_desc.slots)
    return true
  if max_occupied >= 0 && cover_desc.numUsedSlots > max_occupied
    return true

  let coverSideThreshold = 0.1
  let heightDiff = abs(cover.groundLeft.y - cover.groundRight.y)
  let groundLen = max(1.0, length_sq(cover.groundLeft - cover.groundRight))
  if heightDiff / groundLen > coverSideThreshold
    return true

  let minH = min(cover.groundLeft.y, cover.groundRight.y)
  if minH > bbox.bmax.xyz.y
    return true
  let maxH = max(cover.groundLeft.y + cover.hLeft, cover.groundRight.y + cover.hRight)
  if maxH < bbox.bmin.xyz.y
    return true

  if cover_desc.forWaterLevel != filter_info.waterLevel
    cover_desc.forWaterLevel = filter_info.waterLevel
    let groundMid = (cover.groundLeft + cover.groundRight) * 0.5
    var result = false
    traceht_water_at_time(groundMid + float3(0.0, filter_info.waterWalkH, 0.0), 0.0f, get_sync_time(), result)
    cover_desc.isUnderwater = result
  if cover_desc.isUnderwater
    return true

  return false

def get_cover_slot_pos(cover, cover_desc, slot_idx)
  let wallOffset = 0.25
  return cover_desc.slots[slot_idx].pos - cover.dir * wallOffset

def get_cover_walkout_pos(cover, side)
  let shootWallOffset = 0.35
  if side < 0
    return cover.shootLeft - cover.dir * shootWallOffset
  return cover.shootRight - cover.dir * shootWallOffset

def check_cover_pos_valid(pos)
  var newPos = pos
  if !project_to_nearest_navmesh_point(newPos, 0.5)
    return false
  let maxOffDistSq = square(0.3)
  if distance_sq(newPos, pos) > maxOffDistSq
    return false
  if abs(newPos.y - pos.y) > 0.3
    return false
  return true


def check_cover_slots_near(pos, cover_id, covers_list, covers_descs, check_radius_sq)
  assume cdesc = covers_descs[cover_id]
  if cdesc.numUsedSlots <= 0
    return false

  assume cover = covers_list[cover_id]
  let numSlots = length(cdesc.slots)
  for i in range(0, numSlots)
    if cdesc.slots[i].numUsed > 0
      let pos2 = get_cover_slot_pos(cover, cdesc, i)
      if distance_sq(pos, pos2) < check_radius_sq
        return true
  return false

def check_covers_nearby_occupied(pos, cover_id, slot_idx, covers_list, covers_descs)
  let checkRadius = 2.0
  let checkRadiusSq = square(checkRadius)

  assume cover = covers_list[cover_id]
  assume cdesc = covers_descs[cover_id]

  if cdesc.numUsedSlots > 0
    if cdesc.slots[slot_idx].numUsed > 0
      return true
    if slot_idx > 0 && cdesc.slots[slot_idx - 1].numUsed > 0
      return true
    if slot_idx > 1 && cdesc.slots[slot_idx - 2].numUsed > 0
      return true
    let numSlots = length(cdesc.slots)
    if slot_idx < numSlots - 1 && cdesc.slots[slot_idx + 1].numUsed > 0
      return true
    if slot_idx < numSlots - 2 && cdesc.slots[slot_idx + 2].numUsed > 0
      return true

  let numCovers = length(covers_list)
  assume slot = cdesc.slots[slot_idx]
  if slot.near1 >= 0 && slot.near1 < numCovers
    if check_cover_slots_near(pos, slot.near1, covers_list, covers_descs, checkRadiusSq)
      return true
  if slot.near2 >= 0 && slot.near2 < numCovers
    if check_cover_slots_near(pos, slot.near2, covers_list, covers_descs, checkRadiusSq)
      return true
  return false


def get_danger_points(var points : array<float3>&; agent_eid, agent_team, agent_pos, aware_radius, aware_time)
  clear(points)

  var userPoint = float3()
  var userPointTime = -1.0
  query() <| $ [es] (transform : float3x4; userPointOwner : EntityId; timer__start : float)
    if timer__start > userPointTime
      query(userPointOwner) <| $ [es] (team : int)
        if is_teams_friendly(agent_team, team)
          userPointTime = timer__start
          userPoint = transform[3]
  if userPointTime > -1.0
    push(points, userPoint)
    return

  let minNoiseLevel = 0.5
  let enoughDangers = 5
  query(agent_eid) <| $ [es] (agent_dangers : AgentDangers)
    for danger in agent_dangers.dangers
      if minNoiseLevel <= 0.0 || danger.traceable || danger.noiseMeter >= minNoiseLevel
        query(danger.eid) <| $ [es] (ai_target : Target; isAlive : bool)
          if isAlive
            push(points, ai_target.targetPos)
      if length(points) > enoughDangers
        break
  if !empty(points)
    return

  if aware_radius > 0.0
    let curTime = get_sync_time()
    query() <| $ [es] (transform : float3x4; team : int; human_weap__lastShotAtTime : float)
      if !is_teams_friendly(team, agent_team) && curTime - human_weap__lastShotAtTime < aware_time
        if distance_sq(transform[3], agent_pos) < square(aware_radius)
          push(points, transform[3])
  if !empty(points)
    return

  query() <| $ [es] (mean_pos__pos : float3; mean_pos__team : int)
    if mean_pos__pos != float3() && !is_teams_friendly(mean_pos__team, agent_team)
      push(points, mean_pos__pos)
  if !empty(points)
    return

  get_respawn_points() <| $ [unused_argument(respType)] (active, respType, team, respPos)
    if active && !is_teams_friendly(team, agent_team)
      push(points, respPos)

def check_cover_pos_vs_points(pos, dir, points)
  if empty(points)
    return true
  for pt in points
    let dir2 = normalize(x0z(pt) - x0z(pos))
    if dot(dir, dir2) > 0.1
      return true
  return false


enum CoverAttackType
  NONE            = 0
  CROUCH_TO_STAND = 1
  CRAWL_TO_CROUCH = 2
  CRAWL_TO_STAND  = 3
  WALKOUT_LEFT    = 4
  WALKOUT_RIGHT   = 5
  PRONE_DOWN      = 6
  STAND_STRAFES   = 7
  COUNT           = 8

let cover_attk_max_stances = fixed_array<int>(2, 2, 1, 2, 2, 2, 1, 2)
let cover_attk_min_stances = fixed_array<int>(1, 2, 1, 2, 1, 1, 1, 1)
let cover_hide_max_stances = fixed_array<int>(2, 1, 0, 0, 2, 2, 1, 2)
let cover_hide_min_stances = fixed_array<int>(1, 1, 0, 0, 1, 1, 1, 1)

def get_cover_attack_stance(attack_type)
  let idx = int(attack_type)
  if idx >= 0 && idx < int(CoverAttackType.COUNT)
    return rnd_int(0, 100) < 50 ? cover_attk_max_stances[idx] : cover_attk_min_stances[idx]
  return STANCE_STAND

def get_cover_hide_stance(attack_type)
  let idx = int(attack_type)
  if idx >= 0 && idx < int(CoverAttackType.COUNT)
    return rnd_int(0, 100) < 50 ? cover_hide_max_stances[idx] : cover_hide_min_stances[idx]
  return STANCE_CROUCH

def check_cover_attack(attack_type, cover, cover_slot_pos, walker_agent, target_pos)
  let attackStance = get_cover_attack_stance(attack_type)
  let heightUp = walker_agent.shootFrom[attackStance] - walker_agent.pos

  var attackPos = cover_slot_pos + heightUp
  if attack_type == CoverAttackType.WALKOUT_LEFT
    attackPos = get_cover_walkout_pos(cover, -1) + heightUp
  elif attack_type == CoverAttackType.WALKOUT_RIGHT
    attackPos = get_cover_walkout_pos(cover, 1) + heightUp

  let ofs = target_pos - attackPos
  let dir = normalize(ofs)
  let maxDist = 8.0
  let maxDistSq = square(maxDist)
  var dist = length_sq(ofs) > maxDistSq ? maxDist : length(ofs)
  var norm : float3
  return dist < VERY_SMALL_NUMBER || !traceray_normalized(attackPos, dir, dist, norm, ETF_ALL)

def check_cover_safe(cover_slot_pos, target_pos)
  let heightUp = float3(0.0, 0.6, 0.0)
  let hidePos = cover_slot_pos + heightUp

  let ofs = target_pos - hidePos
  let dir = normalize(ofs)
  var dist = length(ofs)
  var norm : float3
  return dist > VERY_SMALL_NUMBER && traceray_normalized(hidePos, dir, dist, norm, ETF_ALL)

def check_move_to_cover_along_fire_line(fromPos, toPos, enemyPos)
  let dir1 = normalize(enemyPos - fromPos)
  let dir2 = normalize(toPos - fromPos)
  return abs(dot(dir1, dir2)) > 0.75

def check_cover_near_enemies(pos, radius, agent_eid)
  var result = false
  let radiusSq = square(radius)
  let radiusOut = radius * 3.0
  let heightUp = 0.6
  let heightMax = pos.y + heightUp + 1.5
  let heightMin = pos.y + heightUp - 1.0
  let xzPos = float3(pos.x, 0.0, pos.z)
  query(agent_eid) <| $ [es] (agent_dangers : AgentDangers)
    for danger in agent_dangers.dangers
      if danger.distance > radiusOut
        continue
      query(danger.eid) <| $ [es] (transform : float3x4)
        let dangerPos = transform[3]
        if dangerPos.y > heightMin && dangerPos.y < heightMax
          if distance_sq(float3(dangerPos.x, 0.0, dangerPos.z), xzPos) < radiusSq
            result = true
      if result
        break
  return result


def eval_cover_attack_type_and_score(cover, desc, slot; var out_type : CoverAttackType&)
  let numSlots = length(desc.slots)
  if desc.slots[slot].numUsed > 0
    out_type = CoverAttackType.NONE
    return 0
  let isWalkoutCover = cover.hasLeftPos || cover.hasRightPos
  if cover.hLeft > 1.25 
    if isWalkoutCover
      if cover.hasLeftPos && slot == 0
        out_type = CoverAttackType.WALKOUT_LEFT
        return 3
      if cover.hasRightPos && slot == numSlots - 1
        out_type = CoverAttackType.WALKOUT_RIGHT
        return 3
    return 0
  let isHalfCover = !isWalkoutCover && cover.shootLeft != float3()
  if cover.hLeft > 0.50 
    if isHalfCover
      out_type = CoverAttackType.CROUCH_TO_STAND
      return 3
    return 0
  if isHalfCover 
    out_type = CoverAttackType.CRAWL_TO_CROUCH 
    return 2
  out_type = CoverAttackType.PRONE_DOWN 
  return 1

def eval_cover_score_stay(cover, desc, slot)
  let numSlots = length(desc.slots)
  if desc.slots[slot].numUsed > 0
    return 0
  let freeEnough = desc.numUsedSlots < (numSlots + 1) / 2
  let isWalkoutCover = cover.hasLeftPos || cover.hasRightPos
  if cover.hLeft > 1.25 
    if isWalkoutCover
      if cover.hasLeftPos && slot == 0
        return 2 
      if cover.hasRightPos && slot == numSlots - 1
        return 2 
      if numSlots <= 2
        return 0
    return desc.numUsedSlots == 0 ? 3 : freeEnough ? 2 : 0
  let isHalfCover = !isWalkoutCover && cover.shootLeft != float3()
  if cover.hLeft > 0.50 
    if isHalfCover
      return 5 
    return desc.numUsedSlots == 0 ? 3 : freeEnough ? 2 : 0
  if !isHalfCover 
    return 1
  return freeEnough ? 4 : 3


enum LeaderActing
  LEADER_BUILDING = 1
  LEADER_AIMSHOOT = 2

struct LeaderActingInfo
  leaderEid : EntityId
  actingFlags : int

def get_squad_leader_acting(squad_leader_eid : EntityId) : LeaderActingInfo
  var leaderEid = INVALID_ENTITY_ID
  var actingFlags = 0
  if !!squad_leader_eid
    leaderEid = squad_leader_eid
    query(squad_leader_eid) <| $ [es] (human_net_phys : HumanActor;
                                       squad_member__playerEid : EntityId;
                                       building_action__target : EntityId;
                                       building_action__lastActionAtTime : float)
      if !!building_action__target && building_action__lastActionAtTime >= 0.0
        actingFlags |= int(LeaderActing.LEADER_BUILDING)
      else
        let aim = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM)
        let shoot = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT)
        if (aim || shoot) && !has(squad_member__playerEid, "playerIsBot")
          actingFlags |= int(LeaderActing.LEADER_AIMSHOOT)
  if actingFlags == 0
    leaderEid = INVALID_ENTITY_ID
  return LeaderActingInfo(leaderEid = leaderEid, actingFlags = actingFlags)

def get_squad_leader_acting_for_agent(agent_eid : EntityId) : LeaderActingInfo
  var leaderEid = INVALID_ENTITY_ID
  query(agent_eid) <| $ [es] (squad_member__squad : EntityId)
    query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
      if !!squad__leader && squad__leader != agent_eid
        leaderEid = squad__leader
  return get_squad_leader_acting(leaderEid)

def is_conflict_with_squad_leader_acting(leader_acting_info : LeaderActingInfo; pos : float3; agent_eid : EntityId)
  var isConflict = false

  if (leader_acting_info.actingFlags & int(LeaderActing.LEADER_AIMSHOOT)) != 0
    let minDist = 0.5
    let maxDist = 15.0
    let checkHeight = 2.0
    let maxSideAtOneMeter = 0.1
    query(leader_acting_info.leaderEid) <| $ [es] (transform : float3x4)
      let leaderY = transform[3].y
      if pos.y > leaderY + checkHeight || pos.y + checkHeight < leaderY
        return
      var vpos = transform[3]
      vpos.y = pos.y
      if distance_sq(vpos, pos) < square(minDist)
        isConflict = true
        return
      let dx = pos.x - vpos.x
      let dz = pos.z - vpos.z
      let ahead = transform[0].x * dx + transform[0].z * dz
      if ahead < minDist || ahead > maxDist
        return
      let side = (-transform[0].z) * dx + transform[0].x * dz
      let sideByDist = side / ahead
      if abs(sideByDist) < maxSideAtOneMeter
        isConflict = true

  if (leader_acting_info.actingFlags & int(LeaderActing.LEADER_BUILDING)) != 0
    let awayRadius = 1.0
    let awayHeight = 2.0
    query(leader_acting_info.leaderEid) <| $ [es] (building_action__target : EntityId)
      query(building_action__target) <| $ [es] (transform : float3x4;
                                                buildingBoxMin : float3;
                                                buildingBoxMax : float3)
        var tm = float3x4()
        tm[0] = float3(1.0, 0.0, 0.0)
        tm[1] = float3(0.0, 1.0, 0.0)
        tm[2] = float3(0.0, 0.0, 1.0)
        tm[3] = pos
        let ptMin = float3(-awayRadius, 0.0f, -awayRadius)
        let ptMax = float3(awayRadius, awayHeight, awayRadius)
        let box = BBox3(ptMin, ptMax)
        if check_bbox3_intersection(box, tm, BBox3(buildingBoxMin, buildingBoxMax), transform)
          var blocking = true
          query(agent_eid) <| $ [es] (squad_member__orderType : int)
            if squad_member__orderType == int(SquadMateOrder.ESMO_BUILD)
              blocking = false
          if blocking
            isConflict = true

  return isConflict
