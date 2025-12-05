require ecs
require app
require math.base
require DagorMath
require DagorDebug3D
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.loc_squad_common
require %appGame.infantry.es.squad_order_common
require %appGame.infantry.es.walker_common
require DngWalkerai
require DagorRandom
require pathfinder
require DngHuman
require Dacoll

require %appGame.infantry.ai.ai_covers_common
require Covers


def private get_stance_from_phys(human_net_phys : HumanActor)
  let standState = human_net_phys.phys.currentState.standState
  if standState == HUStandState.ESS_STAND
    return 2
  if standState == HUStandState.ESS_CROUCH
    return 1
  if standState == HUStandState.ESS_CRAWL || standState == HUStandState.ESS_DOWNED
    return 0
  return STANCE_CROUCH

def private intersect_move_xz(p1 : float3; p2 : float3; q1 : float3; q2 : float3; radius : float)
  let dp = x0z(p2 - p1)
  let dq = x0z(q2 - q1)
  let pv = normalize(dp)
  let qv = normalize(dq)
  let dvx = pv.x - qv.x
  let dvz = pv.z - qv.z
  let dvxOff = abs(dvx) < 0.0001
  let dvzOff = abs(dvz) < 0.0001
  if dvxOff && dvzOff
    return -1.0
  var tx = -1.0
  var tz = -1.0
  if !dvxOff
    tx = (q1.x - p1.x) / dvx
  if !dvzOff
    tz = (q1.z - p1.z) / dvz
  var t = -1.0
  if dvxOff
    if abs(p1.x - q1.x) < 0.01
      t = tz
  elif dvzOff
    if abs(p1.z - q1.z) < 0.01
      t = tx
  else
    if abs(tx - tz) < 0.001
      t = tx
  if t < 0.0
    return -1.0
  let pt1 = x0z(p1) + pv * t
  let pt2 = x0z(q1) + qv * t
  let distSq = distance_sq(pt1, pt2)
  return distSq < square(radius * 2.0) ? (t / length(dp)) : -1.0


def private is_squad_member_should_follow_leader(squad_member__isPersonalOrder : bool; squad_member__orderType : int)
  return !squad_member__isPersonalOrder || !is_squad_mate_order_positional(squad_member__orderType)

def private generate_new_positions_on_leader_change(leader_pos : float3; var squad__followLeaderPositions : Point4List&;
                                                    gen_step : float; dist_too_far : float)
  let maxDistReuse = dist_too_far - gen_step

  var minDist = -1.0
  var maxDist = -1.0
  var maxPos = float3()
  let numFollowPos = length(squad__followLeaderPositions)
  for i in range(0, numFollowPos)
    let pos = squad__followLeaderPositions[i].xyz
    let dist = distance(pos, leader_pos)
    if dist < minDist || minDist < 0.0
      minDist = dist
    if dist > maxDist
      maxDist = dist
      maxPos = pos
  if minDist < maxDistReuse || maxDist < 0.0
    return

  let humanRadius = 0.3
  let extents = float3(humanRadius, FLT_MAX, humanRadius)
  find_path(maxPos, leader_pos, extents, 1.0, 0.25) <| $(path)
    let numPoints = length(path)
    if numPoints <= 1
      return
    var pathDist = 0.0
    for j in range(0, numPoints - 1)
      pathDist += distance(x0z(path[j]), x0z(path[j + 1]))
    let maxNumGenPos = int(pathDist / gen_step)
    if maxNumGenPos <= 0
      return
    var genIdx = numFollowPos - 1
    var distAt = gen_step
    var pathAt = numPoints
    while pathAt > 1 && genIdx >= 0
      --pathAt
      assume pos1 = path[pathAt]
      assume pos2 = path[pathAt - 1]
      let dist = distance(pos1, pos2)
      if dist <= 0.0
        continue
      while distAt <= dist && genIdx >= 0
        var genPos = lerp(pos1, pos2, distAt / dist)
        let projExtents = float3(1.5, 1.0, 1.5)
        var projectedPos = genPos
        if project_to_nearest_navmesh_point_no_obstacles(projectedPos, projExtents)
          genPos = projectedPos
        squad__followLeaderPositions[genIdx--] = float4(genPos, 0.0)
        distAt += gen_step
      distAt -= dist


[es(tag=server)]
def squad_follow_leader_update_es(info : ParallelUpdateFrameDelayed;
                                  eid aka squad_eid : EntityId;
                                  squad__followLeaderGenPeriod : float;
                                  var squad__followLeaderGenTimer : float&)
  if squad__followLeaderGenTimer >= 0.0
    squad__followLeaderGenTimer += info.dt
    if squad__followLeaderGenTimer < squad__followLeaderGenPeriod
      return

  var leaderPos = float3()
  var leaderStance = STANCE_CROUCH
  var leaderVelocity = 0.0
  var hasLeaderInfo = false

  var followPositionsChanged = false
  query(squad_eid) <| $ [es] (squad__leader : EntityId;
                              squad__followLeaderGenMinDist : float = 1.5;
                              squad__followLeaderMaxPositions : int = 10;
                              var squad__followLeaderPositions : Point4List&;
                              var squad__followLeaderPositionsForEid : EntityId&;
                              var squad__followLeaderPositionsLastPos : float3&;
                              var squad__followLeaderPositionsTryByEid : EntityId&)
    let reachDistSq = square(squad__followLeaderGenMinDist)
    query(squad__leader) <| $ [es] (transform : float3x4; human_net_phys : HumanActor; human_net_phys__isClimbing : bool)
      assume currentState = human_net_phys.phys.currentState
      let isInAir = (uint(currentState.isInAirHistory) & uint(1)) != 0u
      let isSwimming = (uint(currentState.states) & uint(StateFlag.ST_SWIM)) != 0u
      let isClimbing = human_net_phys__isClimbing
      let isAtLadder = currentState.isAttachedToLadder
      if isInAir || isSwimming || isClimbing || isAtLadder
        return

      leaderPos = transform[3]
      leaderStance = get_stance_from_phys(human_net_phys)
      leaderVelocity = length(currentState.velocity)
      hasLeaderInfo = true

      
      
      
      leaderPos.y += 0.3

      let MAX_DIST_USE_FAR_STEPS = squad__followLeaderGenMinDist * 2.0
      let MAX_HEIGHT_DIFF_FAR = 3.5
      var leaderTooFar = false
      if !empty(squad__followLeaderPositions)
        let prevPos = squad__followLeaderPositions[length(squad__followLeaderPositions) - 1].xyz
        if distance_sq(leaderPos, prevPos) > square(MAX_DIST_USE_FAR_STEPS) || abs(leaderPos.y - prevPos.y) > MAX_HEIGHT_DIFF_FAR
          leaderTooFar = true
          

      if squad__leader != squad__followLeaderPositionsForEid || leaderTooFar
        if squad__leader != squad__followLeaderPositionsTryByEid
          
          squad__followLeaderPositionsTryByEid = squad__leader
          squad__followLeaderPositionsLastPos = leaderPos
        let lastPos = squad__followLeaderPositionsLastPos
        if distance_sq(leaderPos, lastPos) < reachDistSq
          
          return
        
        generate_new_positions_on_leader_change(leaderPos, squad__followLeaderPositions, squad__followLeaderGenMinDist, MAX_DIST_USE_FAR_STEPS)
        squad__followLeaderPositionsTryByEid = INVALID_ENTITY_ID
        squad__followLeaderPositionsLastPos = leaderPos
        squad__followLeaderPositionsForEid = squad__leader
        followPositionsChanged = true
        return

      var ptsLen = length(squad__followLeaderPositions)
      if ptsLen > 0
        let lastPos = squad__followLeaderPositionsLastPos
        if distance_sq(leaderPos, lastPos) < reachDistSq
          
          return
        if ptsLen >= squad__followLeaderMaxPositions
          squad__followLeaderPositions |> erase(0)

        ptsLen = length(squad__followLeaderPositions)
        query() <| $ [es] (var covers : CoversComponent&)
          let TRY_ENHANCE_POINTS = 3
          let COVER_SCAN_RADIUS = 2.9
          let REACH_DIST_LESS_SQ = square(squad__followLeaderGenMinDist * 0.75)
          for j in range(TRY_ENHANCE_POINTS)
            let ptIdx = ptsLen - 1 - j
            if ptIdx < 0
              break
            assume enhancePos = squad__followLeaderPositions[ptIdx]
            assume prevPos = ptIdx > 0 ? squad__followLeaderPositions[ptIdx - 1].xyz : float3()
            if enhancePos.w == 0.0
              enhancePos.w = -1.0
              var box : bbox3f
              box.bmax.xyz = enhancePos.xyz + float3(COVER_SCAN_RADIUS, 0.5f, COVER_SCAN_RADIUS)
              box.bmin.xyz = enhancePos.xyz - float3(COVER_SCAN_RADIUS, 0.5f, COVER_SCAN_RADIUS)
              var bestCoverPos = float3()
              var bestCoverDistSq = square(COVER_SCAN_RADIUS)
              covers_box_cull(covers, box) <| $(cover_id : int; tm : mat44f#)
                if tm.col3.xyz == float3() 
                  return
                assume cover = covers.list[cover_id]
                assume cdesc = covers.coverDescs[cover_id]
                let numSlots = length(cdesc.slots)
                for i in range(0, numSlots)
                  if cdesc.slots[i].numUsed > 0
                    continue
                  let coverSlotPos = get_cover_slot_pos(cover, cdesc, i)
                  let coverDistSq = distance_sq(lastPos.xyz, coverSlotPos)
                  let tryNewPos = lerp(enhancePos.xyz, coverSlotPos, 0.75)
                  if coverDistSq < bestCoverDistSq && distance_sq(leaderPos, tryNewPos) > REACH_DIST_LESS_SQ
                    if prevPos == float3() || distance_sq(prevPos, tryNewPos) > REACH_DIST_LESS_SQ
                      var hitPos = float3()
                      let traceNavExtents = float3(0.2)
                      if !traceray_navmesh(enhancePos.xyz, tryNewPos, traceNavExtents, hitPos)
                        bestCoverPos = tryNewPos
                        bestCoverDistSq = coverDistSq
              if bestCoverPos != float3()
                enhancePos = float4(bestCoverPos, 1.0)

      squad__followLeaderPositions |> push(float4(leaderPos, 0.0))
      squad__followLeaderPositionsLastPos = leaderPos
      squad__followLeaderPositionsForEid = squad__leader
      followPositionsChanged = true

  if !hasLeaderInfo
    return
  let LEADER_VELOCITY_MAX = 6.0
  let REGEN_PERIOUD_MIN = 0.7
  let REGEN_PERIOUD_MAX = 2.5
  let regenPeriod = cvt(leaderVelocity, 0.0, LEADER_VELOCITY_MAX, REGEN_PERIOUD_MAX, REGEN_PERIOUD_MIN)
  if !followPositionsChanged && squad__followLeaderGenTimer >= 0.0 && squad__followLeaderGenTimer < regenPeriod
    return
  squad__followLeaderGenTimer = rnd_float(0.0, squad__followLeaderGenPeriod)

  query(squad_eid) <| $ [es] (squad__leader : EntityId;
                              squad__allMembers : EidList;
                              var squad__followLeaderPositions : Point4List&;
                              var squad__followLookSideTimer : float&;
                              var squad__followLookSideLastTime : float&;
                              squad__followLookSideTime : float = 2.5;
                              squad__followLookSideTimes : float4 = float4(0.25, 1.2, 1.2, 0.25))
    
    
    
    
    

    let numMembers = length(squad__allMembers)
    if numMembers <= 1
      return

    let STAY_DISTANCE_H_TO_LEADER = 2.0
    let STAY_DISTANCE_XZ_TO_LEADER = 4.5
    let STAY_DISTANCE_XZ_TO_LEADER_SQ = square(STAY_DISTANCE_XZ_TO_LEADER)
    let FAR_DISTANCE_H_TO_LEADER = 5.0
    let FAR_DISTANCE_XZ_TO_LEADER = 15.0
    let FAR_DISTANCE_XZ_TO_LEADER_SQ = square(FAR_DISTANCE_XZ_TO_LEADER)
    var atLeastOneNear = false
    var shouldUpdate = false
    for memberEid in squad__allMembers
      if memberEid == squad__leader
        continue
      query(memberEid) <| $ [es] (squad_member__isPersonalOrder : bool;
                                  squad_member__orderType : int;
                                  transform : float3x4;
                                  var squad_member__followLeader : bool&;
                                  var squad_member__followLeaderPos : float3&;
                                  var squad_member__followLeaderDir : float3&;
                                  var squad_member__followLeaderStance : int&;
                                  var squad_member__followLeaderRun : bool&;
                                  var squad_member__followLeaderLast : bool&)
        if is_squad_member_should_follow_leader(squad_member__isPersonalOrder, squad_member__orderType)
          let memberPos = transform[3]
          let distSq = length_sq(x0z(memberPos - leaderPos))
          let deltaH = abs(memberPos.y - leaderPos.y)
          if distSq < STAY_DISTANCE_XZ_TO_LEADER_SQ && deltaH < STAY_DISTANCE_H_TO_LEADER
            atLeastOneNear = true
          if distSq > FAR_DISTANCE_XZ_TO_LEADER_SQ || deltaH > FAR_DISTANCE_H_TO_LEADER
            shouldUpdate = true

          if !squad_member__followLeader
            squad_member__followLeader = true
            let oldDistSq = length_sq(x0z(squad_member__followLeaderPos - leaderPos))
            let oldDeltaH = abs(squad_member__followLeaderPos.y - leaderPos.y)
            if oldDistSq > FAR_DISTANCE_XZ_TO_LEADER_SQ || oldDeltaH > FAR_DISTANCE_H_TO_LEADER
              squad_member__followLeaderPos = transform[3]
              squad_member__followLeaderDir = transform[0]
            squad_member__followLeaderStance = min(STANCE_CROUCH, leaderStance)
            squad_member__followLeaderRun = false
            squad_member__followLeaderLast = false
            shouldUpdate = true
        else
          squad_member__followLeader = false
    if atLeastOneNear && !shouldUpdate
      return

    let reserveWhoLen = length(squad__allMembers)

    var ptsLen = length(squad__followLeaderPositions)
    let MIN_DIST_TO_LEADER = 2.0
    let MIN_DIST_TO_LEADER_SQ = square(MIN_DIST_TO_LEADER)
    var maxIdx = ptsLen - 1
    for j in range(ptsLen)
      let distSq = distance_sq(squad__followLeaderPositions[j].xyz, leaderPos)
      if distSq < MIN_DIST_TO_LEADER_SQ
        maxIdx = min(maxIdx, max(0, j - 1))
    var dropIdx = maxIdx + 1
    var sortPts = false
    while dropIdx < ptsLen && ptsLen > reserveWhoLen
      if distance_sq(squad__followLeaderPositions[dropIdx].xyz, leaderPos) > MIN_DIST_TO_LEADER_SQ
        squad__followLeaderPositions |> erase(dropIdx)
        --ptsLen
        if ptsLen == reserveWhoLen
          sortPts = true
      else
        ++dropIdx
    if sortPts
      var pts : array<float4>
      pts |> reserve(length(squad__followLeaderPositions))
      for ptIdx in iter_range(squad__followLeaderPositions)
        pts |> push(squad__followLeaderPositions[ptIdx])
      pts |> sort() <| $(left; right)
        return distance_sq(leaderPos, left.xyz) > distance_sq(leaderPos, right.xyz)
      for ptIdx in iter_range(squad__followLeaderPositions)
        squad__followLeaderPositions[ptIdx] = pts[ptIdx]

    let useLen = maxIdx + 1
    if ptsLen <= 1
      return

    var whos : array<EntityId>
    var froms : array<float3>
    var dests : array<int>
    whos |> reserve(numMembers)
    froms |> reserve(numMembers)
    dests |> reserve(numMembers)

    for memberEid in squad__allMembers
      if memberEid == squad__leader
        continue
      query(memberEid) <| $ [es] (squad_member__isPersonalOrder : bool; squad_member__orderType : int; transform : float3x4)
        if is_squad_member_should_follow_leader(squad_member__isPersonalOrder, squad_member__orderType)
          let memberPos = transform[3]
          whos |> push(memberEid)
          froms |> push(memberPos)

          var bestDest = -1
          var bestDistSq = FLT_MAX
          for j in range(useLen)
            assume pos = squad__followLeaderPositions[j]
            if pos.w >= 1.0
              let distSq = distance_sq(memberPos, pos.xyz)
              if distSq < bestDistSq
                bestDest = j
                bestDistSq = distSq
          if bestDest == -1
            bestDistSq = FLT_MAX
            for j in range(useLen)
              assume pos = squad__followLeaderPositions[j]
              let distSq = distance_sq(memberPos, pos.xyz)
              if distSq < bestDistSq
                bestDest = j
                bestDistSq = distSq
          if bestDest == -1
            bestDest = 0
          dests |> push(bestDest) 

    let whoLen = length(whos)

    var sorted : array<int>
    sorted |> reserve(whoLen)
    for i in iter_range(whos)
      sorted |> push(i)
    sorted |> sort() <| $(left; right)
      if dests[left] == dests[right]
        return distance_sq(leaderPos, froms[left]) < distance_sq(leaderPos, froms[right])
      return dests[left] > dests[right]

    var useIdx = useLen - 1
    if useIdx <= 0
      useIdx = min(whoLen - 1, ptsLen - 1)

    if useIdx >= whoLen && squad__followLeaderPositions[useIdx].w <= 0.0
      let MAX_NO_COVER = 2
      var withCoverIdx = -1
      for j in range(min(useIdx, MAX_NO_COVER))
        let idx = useIdx - 1 - j
        if squad__followLeaderPositions[idx].w >= 0.0
          withCoverIdx = idx
          break
      if withCoverIdx >= 0 && withCoverIdx >= whoLen - 1
        useIdx = withCoverIdx

    var gots : array<int>
    var blok : array<int>
    var blkr : array<float>
    var blks : array<int>
    gots |> reserve(whoLen)
    blok |> reserve(whoLen)
    blkr |> reserve(whoLen)
    blks |> reserve(whoLen)

    let HUMAN_RADIUS = 0.3

    var sortedIdx = 0
    while sortedIdx < whoLen
      let whoIdx = sorted[sortedIdx++]
      if useIdx >= 0 && useIdx < useLen
        let pos1a = froms[whoIdx]
        let pos1b = squad__followLeaderPositions[useIdx].xyz

        blok |> clear()
        blkr |> clear()
        blks |> clear()
        for gotIdx in iter_range(gots)
          let gotWhoIdx = gots[gotIdx]
          let gotWhoDest = dests[gotWhoIdx]
          let pos2a = froms[gotWhoIdx]
          let pos2b = squad__followLeaderPositions[gotWhoDest].xyz
          let ratio = intersect_move_xz(pos1a, pos1b, pos2a, pos2b, HUMAN_RADIUS)
          if ratio >= 0.0
            blok |> push(gotWhoIdx)
            blkr |> push(ratio)
            blks |> push(length(blks))

        var assignIdx = useIdx
        if length(blks) > 0
          blks |> sort() <| $(left; right)
            return blkr[left] < blkr[right]
          for k in iter_range(blks)
            let blokIdx = blks[k]
            let intrWhoIdx = blok[blokIdx]
            let intrWhoDest = dests[intrWhoIdx]
            dests[intrWhoIdx] = assignIdx
            assignIdx = intrWhoDest

        dests[whoIdx ] = assignIdx
        useIdx = max(0, useIdx - 1)
        gots |> push(whoIdx)

        if useIdx >= whoLen - sortedIdx && squad__followLeaderPositions[useIdx].w <= 0.0
          var withCoverIdx = -1
          let MAX_NO_COVER = 2
          for j in range(min(useIdx, MAX_NO_COVER))
            let idx = useIdx - 1 - j
            if squad__followLeaderPositions[idx].w >= 0.0
              withCoverIdx = idx
              break
          if withCoverIdx >= 0 && withCoverIdx >= whoLen - sortedIdx - 1
            useIdx = withCoverIdx

        
        
        
        
        
      else
        dests[whoIdx] = -1

    sorted |> clear()
    sorted |> reserve(whoLen)
    for i in iter_range(whos)
      sorted |> push(i)
    sorted |> sort() <| $(left; right)
      let d1 = dests[left]
      let d2 = dests[right]
      if d1 < 0 && d2 < 0
        return left < right
      if d1 < 0 || d2 < 0
        return d2 < 0
      if dests[left] == dests[right]
        return distance_sq(leaderPos, froms[left]) < distance_sq(leaderPos, froms[right])
      return dests[left] > dests[right]

    var running = true
    let MIN_RUNNING_DIST = 5.0
    let MIN_RUNNING_DIST_SQ = square(MIN_RUNNING_DIST)

    let curTime = get_sync_time()
    let deltaTime = max(0.0, curTime - squad__followLookSideLastTime)
    squad__followLookSideLastTime = curTime
    let lookTimes = squad__followLookSideTimes
    squad__followLookSideTimer += cvt(deltaTime, lookTimes.x, lookTimes.y, lookTimes.z, lookTimes.w)
    while squad__followLookSideTimer > squad__followLookSideTime
      squad__followLookSideTimer -= squad__followLookSideTime
    let lookSideNorm = safediv(squad__followLookSideTimer, squad__followLookSideTime)
    let lookSidePhase = (lookSideNorm - float(int(lookSideNorm)))

    var lookSide = lookSidePhase < 0.5 ? 0 : 1
    

    sortedIdx = 0
    while sortedIdx < whoLen
      let whoIdx = sorted[sortedIdx++]
      let memberEid = whos[whoIdx]
      query(memberEid) <| $ [es] (var squad_member__followLeader : bool&;
                                  var squad_member__followLeaderPos : float3&;
                                  var squad_member__followLeaderDir : float3&;
                                  var squad_member__followLeaderStance : int&;
                                  var squad_member__followLeaderRun : bool&;
                                  var squad_member__followLeaderLast : bool&;
                                  squad_member__isPersonalOrder : bool;
                                  walker_agent : EntityAgent)
        let posIdx = dests[whoIdx]
        if posIdx >= 0
          let destPos = squad__followLeaderPositions[posIdx].xyz
          if running && distance_sq(froms[whoIdx], destPos) < MIN_RUNNING_DIST_SQ
            running = false
          elif curTime < walker_agent.waitMoveTime || curTime < walker_agent.fixMoveTime
            running = false

          squad_member__followLeader = true
          squad_member__followLeaderPos = destPos
          squad_member__followLeaderStance = min(STANCE_CROUCH, leaderStance)
          squad_member__followLeaderRun = running
          squad_member__followLeaderLast = false

          let projExtents = float3(1.5, 1.0, 1.5)
          var projectedPos = squad_member__followLeaderPos + float3(0.0, -0.5, 0.0)
          if project_to_nearest_navmesh_point_avoid_obstacles(projectedPos, projExtents)
            if projectedPos.y - squad_member__followLeaderPos.y < 1.0
              squad_member__followLeaderPos = projectedPos
        else
          squad_member__followLeader = true
          squad_member__followLeaderPos = float3()
          squad_member__followLeaderStance = STANCE_CROUCH
          squad_member__followLeaderRun = running
          squad_member__followLeaderLast = false

        let LOOK_SIDE_FORW_COEF = 0.4
        let LOOK_TRACE_DIST = 3.5

        let dirToLeader = normalize(x0z(leaderPos - squad_member__followLeaderPos))
        if sortedIdx == whoLen
          squad_member__followLeaderDir = -dirToLeader
          squad_member__followLeaderLast = true
        elif lookSide == 0
          squad_member__followLeaderDir = float3(dirToLeader.z, 0.0, -dirToLeader.x)
          squad_member__followLeaderDir = lerp(squad_member__followLeaderDir, dirToLeader, LOOK_SIDE_FORW_COEF)
          squad_member__followLeaderDir = normalize(squad_member__followLeaderDir)

          let dist = LOOK_TRACE_DIST
          let rayPos = squad_member__followLeaderPos + float3(0.0, 1.0, 0.0)
          if !rayhit_normalized(rayPos, squad_member__followLeaderDir, dist, ETF_DEFAULT, -1)
            lookSide = 1
          else
            squad_member__followLeaderDir = float3(-dirToLeader.z, 0.0, dirToLeader.x)
            squad_member__followLeaderDir = lerp(squad_member__followLeaderDir, dirToLeader, LOOK_SIDE_FORW_COEF)
            squad_member__followLeaderDir = normalize(squad_member__followLeaderDir)
        else
          squad_member__followLeaderDir = float3(-dirToLeader.z, 0.0, dirToLeader.x)
          squad_member__followLeaderDir = lerp(squad_member__followLeaderDir, dirToLeader, LOOK_SIDE_FORW_COEF)
          squad_member__followLeaderDir = normalize(squad_member__followLeaderDir)

          let dist = LOOK_TRACE_DIST
          let rayPos = squad_member__followLeaderPos + float3(0.0, 1.0, 0.0)
          if !rayhit_normalized(rayPos, squad_member__followLeaderDir, dist, ETF_DEFAULT, -1)
            lookSide = 0
          else
            squad_member__followLeaderDir = float3(dirToLeader.z, 0.0, -dirToLeader.x)
            squad_member__followLeaderDir = lerp(squad_member__followLeaderDir, dirToLeader, LOOK_SIDE_FORW_COEF)
            squad_member__followLeaderDir = normalize(squad_member__followLeaderDir)

        if !squad_member__isPersonalOrder
          let distSq = distance_sq(froms[whoIdx], squad_member__followLeaderPos)
          let FAST_REACT_DIST = 1.2
          if distSq > square(FAST_REACT_DIST)
            query(memberEid) <| $ [es] (var squad_member__makeReaction : das_string&)
              squad_member__makeReaction := "follow_leader"
