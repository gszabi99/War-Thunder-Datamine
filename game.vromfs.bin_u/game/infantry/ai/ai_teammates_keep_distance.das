require ecs
require app
require math.base
require DagorMath
require DagorRandom
require DngWalkerai
require DagorDataBlock
require BehNodes
require Dacoll
require Grid
require GridCollision



def private is_human_after_human(agent_pos : float3; agent_dir : float3; other_transform : float3x4; distance_range : float2)
  let dir1 = agent_dir
  let dir2 = other_transform[0]
  if dir1.x * dir2.x + dir1.z * dir2.z < 0.0
    return false

  assume pos1 = agent_pos
  assume pos2 = other_transform[3]

  let dist = dir1.x * (pos2.x - pos1.x) + dir1.z * (pos2.z - pos1.z)
  if dist < distance_range.x || dist > distance_range.y
    return false

  return true

def private is_thru_circle_xz(from : float3; to : float3; thru : float3; radius : float)
  let dx = to.x - from.x
  let dz = to.z - from.z
  let tx = from.x - thru.x
  let tz = from.z - thru.z
  let a = dx * dx + dz * dz
  if a <= 0.0
    return false
  let b = 2.0 * (tx * dx + tz * dz)
  let c = tx * tx + tz * tz - radius * radius
  let d = b * b - 4.0 * a * c
  if d < 0.0
    return false
  let dd = sqrt(d)
  let t1 = (-b - dd) / (2.0 * a)
  let t2 = (-b + dd) / (2.0 * a)
  if t1 > 0.0 && t1 < t2
    return true
  return false

[es(tag=server, REQUIRE=human, after=after_net_phys_sync)]
def server_ai_human_teammate_keep_distance(info : UpdateStageInfoAct;
                                           eid aka agent_eid : EntityId;
                                           team aka agent_team : int;
                                           beh_tree__enabled : bool;
                                           var walker_agent__keepDistanceTimer : float&;
                                           walker_agent__keepDistanceTimes : float2 = float2(0.1, 0.1);
                                           walker_agent__waitSquadMemberRunningTime : float2 = float2(0.1, 0.15);
                                           walker_agent__waitSquadMemberOnLadderTime : float2 = float2(1.5, 2.5);
                                           walker_agent__scanSquadMemberDist : float = 2.0;
                                           walker_agent__waitSquadMemberDist : float2 = float2(-0.2, 1.6))
  if !beh_tree__enabled || agent_team < 1
    return

  walker_agent__keepDistanceTimer -= info.dt
  if walker_agent__keepDistanceTimer > 0.0
    return
  walker_agent__keepDistanceTimer = rnd_float(walker_agent__keepDistanceTimes.x, walker_agent__keepDistanceTimes.y)

  query(agent_eid) <| $ [es] (var walker_agent aka agent_walker_agent : EntityAgent&;
                              beh_tree aka agent_beh_tree : BehaviourTree;
                              transform aka agent_transform : float3x4;
                              beh_tree__usingLadders aka agent_beh_tree__usingLadders : bool = false;
                              squad_member__squad : EntityId = INVALID_ENTITY_ID)
    let curTime = get_sync_time()
    if curTime < agent_walker_agent.waitMoveTime || curTime < agent_walker_agent.fixMoveTime
      return
    if agent_beh_tree__usingLadders
      return

    var leftTraces = 3

    var wishPos = float3()
    var tryWishPos = false
    var hasWishPos = false
    let wishPositionName = "wishPosition"

    var agentLeaderEid = INVALID_ENTITY_ID
    query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
      agentLeaderEid = squad__leader

    let predictTime = 0.1
    let agentPos = agent_transform[3] + agent_walker_agent.velocity * predictTime

    let checkRadius = walker_agent__scanSquadMemberDist
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(agentPos, checkRadius), GridEntCheck.BOUNDING) <| $(human_eid : EntityId)
      if human_eid == agent_eid
        return
      query(human_eid) <| $ [es(REQUIRE=human)] (transform aka human_transform : float3x4; team aka human_team : int)
        if agent_team != human_team
          return
        let humanPos = human_transform[3]
        let distBetweenSq = distance_sq(agentPos, humanPos)
        if distBetweenSq > square(walker_agent__scanSquadMemberDist)
          return
        let MID_HEIGHT = 0.5
        if agentPos.y + MID_HEIGHT < humanPos.y || humanPos.y + MID_HEIGHT < agentPos.y
          return

        if !tryWishPos
          tryWishPos = true
          let wishPositionParam = datablock_find_param(agent_beh_tree.blackBoard, wishPositionName)
          if wishPositionParam >= 0
            wishPos = datablock_getPoint3(agent_beh_tree.blackBoard, wishPositionParam)
            hasWishPos = true

        let WALK_THRU_RADIUS = 0.71
        let WALK_THRU_DIST_SQ = square(0.85)
        let WALK_INTO_DIST_SQ = square(WALK_THRU_RADIUS)

        let isCloseForThru = distBetweenSq < WALK_THRU_DIST_SQ

        let agentDir = length_sq(agent_walker_agent.velocity) <= 0.01 ? agent_transform[0] : normalize(agent_walker_agent.velocity)

        let isInto = hasWishPos && agentLeaderEid == human_eid && distance_sq(wishPos, humanPos) < square(WALK_INTO_DIST_SQ)
        let isThru = !isInto && isCloseForThru && hasWishPos && is_thru_circle_xz(agentPos, wishPos, humanPos, WALK_THRU_RADIUS)
        let isAfter = !isInto && is_human_after_human(agentPos, agentDir, human_transform, walker_agent__waitSquadMemberDist)

        if !isAfter && !isInto && !isThru
          return

        query(human_eid) <| $ [es] (walker_agent aka human_walker_agent : EntityAgent;
                                    beh_tree__usingLadders : bool = false)
          var waitTime = float2(0.0, 0.0)
          if beh_tree__usingLadders
            waitTime = walker_agent__waitSquadMemberOnLadderTime
          elif isInto
            agent_walker_agent.failMoveTime = curTime + 1.0
          elif isThru
            let HIGH_AROUND_VEL = 2.5
            let moveSpeed = cvt(length_sq(human_walker_agent.velocity), 0.0, square(HIGH_AROUND_VEL), 1.0, 0.0)
            if moveSpeed > 0.1
              let delta = humanPos - agentPos
              let midPos = (agentPos + humanPos) * 0.5
              var forwDir = agent_walker_agent.velocity
              if length_sq(forwDir) <= 0.01 || dot(forwDir, wishPos - midPos) < 0.0
                forwDir = delta
              forwDir = normalize(x0z(forwDir))
              var sideDir = float3(forwDir.z, 0.0, -forwDir.x)
              if dot(float3(delta.z, 0.0, -delta.z), wishPos - midPos) < 0.0
                sideDir = -sideDir

              
              

              if leftTraces > 0
                --leftTraces
                let dist = 1.0
                let rayPos = humanPos + float3(0.0, 1.0, 0.0)
                if rayhit_normalized(rayPos, sideDir, dist, ETF_DEFAULT, -1)
                  sideDir = -sideDir
              sideDir = normalize(sideDir * 0.7 + forwDir * 0.3)

              

              let reachDir = normalize(wishPos - humanPos)
              if dot(reachDir, sideDir) < 0.0
                sideDir = normalize(wishPos - agent_transform[3])

              let WALK_AROUND_TIME = 0.67
              let MAX_SIDE_SPEED = 0.7
              agent_walker_agent.fixMoveTime = curTime + WALK_AROUND_TIME
              agent_walker_agent.fixMoveDir = sideDir
              agent_walker_agent.fixMoveSpeed = min(moveSpeed, MAX_SIDE_SPEED)
          else
            let MIN_PVEL_SQ = 1.5
            if length_sq(agent_walker_agent.velocity) > MIN_PVEL_SQ
              let MIN_CVEL_SQ = 2.5
              if length_sq(human_walker_agent.velocity) > MIN_CVEL_SQ
                waitTime = walker_agent__waitSquadMemberRunningTime
          if waitTime.y > 0.0
            agent_walker_agent.waitMoveTime = curTime + rnd_float(waitTime.x, waitTime.y)
