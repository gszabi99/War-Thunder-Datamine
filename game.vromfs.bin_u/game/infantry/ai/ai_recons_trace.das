require app
require ecs
require math
require math.base
require DagorMath
require DagorMathUtils
require DagorRandom
require Covers
require Dacoll
require %game.events
require %appGame.infantry.ai.ai_recons_common
require DngHuman
require DagorSystem











def recon_trace(pos1 : float3; pos2 : float3; var stoppers : Point4List&; var iter : int&; var stats : int3&)
  var dir = pos2 - pos1
  let len = length(dir)
  var dist = len
  dir *= safeinv(len)

  stats.x += 1

  let lenSq = square(len)
  for stop in stoppers
    let sp = stop.xyz
    let dk = dot(dir, sp - pos1)
    if dk > 0.0
      let pt = pos1 + dir * dk
      if distance_sq(pt, sp) < stop.w
        if lenSq > distance_sq(pos1, sp)
          stats.y += 1
          return false

  var norm : float3
  if !traceray_normalized(pos1, dir, dist, norm, ETF_ALL)
    return true

  let pt = pos1 + dir * dist
  let MIN_DIST_SQ = square(1.5)
  let MAX_DIST_SQ = square(15.0)
  let distSq = distance_sq(pos1, pt)
  if distSq > MIN_DIST_SQ && distSq < MAX_DIST_SQ
    assume stop = stoppers[iter]
    let STOPPER_RADIUS = 0.35

    stop.x = pt.x
    stop.y = pt.y
    stop.z = pt.z
    stop.w = square(STOPPER_RADIUS)

    iter = (iter + 1) % length(stoppers)
    stats.z += 1

  return len < dist


def recon_elem_find(key : int; buckets : IntList; elem_data1 : IPoint4List)
  let hash = calc_recon_hash(key)
  let bkt = hash % length(buckets)
  var idx = buckets[bkt]
  while idx >= 0
    if elem_data1[idx].x == key
      return true
    idx = elem_data1[idx].z
  return false

def recon_elem_add(key : int; var buckets : IntList&; var elem_data1 : IPoint4List&; covers : CoversComponent;
                   elem_data2 : Point4List; elem_data4 : Point4List; pos : float3;
                   look_from_pos : float3; look_by_dir : float3; del_behind : bool;
                   team_eid : EntityId; cur_time : float; focus_dist : float)
  var nidx = -1
  for i in iter_range(elem_data1)
    if elem_data1[i].w == int(ReconType.FREE)
      nidx = i
      break
  if nidx < 0
    var tmpPos = float3()
    for i in iter_range(elem_data1)
      let data1 = elem_data1[i]
      if data1.w == int(ReconType.CORNER)
        assume extra = covers.coverExtra[data1.x]
        if !get_recon_corner_trace_pos(tmpPos, extra.pos, extra.info, look_from_pos)
          nidx = i
          try_save_recon_threat(team_eid, key, cur_time, elem_data4[nidx].w, elem_data2[nidx].w)
          recon_elem_del(nidx, buckets, elem_data1)
          break
    if nidx < 0
      let focusDistSq = square(focus_dist)
      var minScore = -abs(distance_sq(pos, look_from_pos) - focusDistSq)
      for i in iter_range(elem_data1)
        let score = -abs(distance_sq(elem_data2[i].xyz, look_from_pos) - focusDistSq)
        if score < minScore || (del_behind && !is_recon_in_fov(elem_data2[i].xyz, look_from_pos, look_by_dir))
          minScore = min(score, minScore)
          nidx = i
      if nidx < 0
        return -1
      try_save_recon_threat(team_eid, key, cur_time, elem_data4[nidx].w, elem_data2[nidx].w)
      recon_elem_del(nidx, buckets, elem_data1)

  let hash = calc_recon_hash(key)
  let bkt = hash % length(buckets)

  assume data1 = elem_data1[nidx]
  data1.x = key
  data1.y = -1
  data1.z = buckets[bkt]
  data1.w = 0

  buckets[bkt] = nidx
  if data1.z >= 0
    elem_data1[data1.z].y = nidx
  return nidx

def recon_elem_del(idx : int; var buckets : IntList&; var elem_data1 : IPoint4List&)
  assume data1 = elem_data1[idx]

  if data1.y >= 0
    elem_data1[data1.y].z = data1.z
  else
    let hash = calc_recon_hash(data1.x)
    let bkt = hash % length(buckets)
    buckets[bkt] = data1.z

  if data1.z >= 0
    elem_data1[data1.z].y = data1.y

  data1.w = int(ReconType.FREE)

















def recon_update_backtrack_es(eid : EntityId; cur_time : float)
  query(eid) <| $ [es] (recon__maxBacktrack : int;
                        recon__backtrackMinDist : float = 1.0;
                        recon__backtrackMaxTime : float = 10.0;
                        var recon__backTrackPosTime : Point4List&;
                        var recon__backTrackLast : int&;
                        var recon__backTrackLen : int&;
                        transform : float3x4)
    var queueSize = length(recon__backTrackPosTime)
    if queueSize == 0
      if recon__maxBacktrack <= 0
        return
      recon__backTrackPosTime |> resize(recon__maxBacktrack)
      queueSize = recon__maxBacktrack

    while recon__backTrackLen > 1
      let firstIdx = (recon__backTrackLast + queueSize - recon__backTrackLen + 1) % queueSize
      assume firstElem = recon__backTrackPosTime[firstIdx]
      if cur_time < firstElem.w + recon__backtrackMaxTime
        break
      recon__backTrackLen--

    let curPos = transform[3]
    if recon__backTrackLen > 0
      assume lastElem = recon__backTrackPosTime[recon__backTrackLast]
      let lastPos = lastElem.xyz
      if distance_sq(lastPos.xz, curPos.xz) < square(recon__backtrackMinDist) && abs(lastPos.y - curPos.y) < 1.0
        lastElem = float4(lastPos.x, lastPos.y, lastPos.z, cur_time)
        return

    if recon__backTrackLen >= queueSize
      recon__backTrackLen = queueSize - 1
    recon__backTrackLast = (recon__backTrackLast + 1) % queueSize

    assume newElem = recon__backTrackPosTime[recon__backTrackLast]
    newElem = float4(curPos.x, curPos.y, curPos.z, cur_time)
    recon__backTrackLen++












def private recon_update_agent(agent_eid : EntityId)
  query(agent_eid) <| $ [es] (eid : EntityId;
                              isAlive : bool = false;
                              isDowned : bool = false;
                              recon__enabled : bool;
                              var recon__nextUpdateTime : float&;
                              var recon__nextRetraceTime : float&;
                              recon__updateTimePeriod : float2;
                              recon__retraceTimePeriod : float)
    if !recon__enabled || !isAlive || isDowned
      return

    let curTime = get_sync_time()
    if curTime < recon__nextRetraceTime && curTime < recon__nextUpdateTime
      return

    recon_update_backtrack_es(eid, curTime)

    query(eid) <| $ [es] (team : int;
                          var recon__team : int&;
                          var recon__teamEid : EntityId&;
                          recon__maxStoppers : int;
                          recon__maxBuckets : int;
                          recon__maxElements : int;
                          var recon__stoppers : Point4List&;
                          var recon__nextStopper : int&;
                          var recon__buckets : IntList&;
                          var recon__elemData1 : IPoint4List;
                          var recon__elemData2 : Point4List;
                          var recon__elemData3 : Point4List;
                          var recon__elemData4 : Point4List;
                          var recon__cycle : int&;
                          var recon__iterators : int3&;
                          recon__scanHeights : float2;
                          recon__scanDistances : float4;
                          recon__scanFocusDist : float;
                          recon__maxScannedPerUpdate : int2;
                          recon__maxTracedPerUpdate : int2;
                          recon__maxOffsetNoRetrace : float;
                          var recon__stats : int3&;
                          transform : float3x4;
                          human_net_phys : HumanActor;
                          beh_tree__enabled : bool)
      if length(recon__elemData1) <= 0
        resize(recon__stoppers, recon__maxStoppers)
        resize(recon__buckets, recon__maxBuckets)
        for bucket in recon__buckets
          bucket = -1
        resize(recon__elemData1, recon__maxElements)
        for elem in recon__elemData1
          elem = int4(-1, -1, -1, 0)
        resize(recon__elemData2, recon__maxElements)
        resize(recon__elemData3, recon__maxElements)
        resize(recon__elemData4, recon__maxElements)

      if team >= 1 && recon__team != team
        recon__team = team
        recon__teamEid = INVALID_ENTITY_ID
        query() <| $ [es] (eid aka recon_team_eid : EntityId; recon_team__id : int)
          if recon_team__id == team
            recon__teamEid = recon_team_eid
        if recon__teamEid == INVALID_ENTITY_ID
          let forTeamId = team
          var resultEid = INVALID_ENTITY_ID
          query() <| $ [es] (recon__team aka that_recon__team : int&; recon__teamEid aka that_recon__teamEid : EntityId&)
            if that_recon__team == forTeamId && that_recon__teamEid != INVALID_ENTITY_ID
              
              resultEid = that_recon__teamEid
          recon__teamEid = resultEid
        if recon__teamEid == INVALID_ENTITY_ID
          recon__teamEid = createEntity("modern_team_ai_recons") <| $(var init)
            init |> set("recon_team__id", team)

      if curTime > recon__nextRetraceTime
        recon__nextRetraceTime = curTime + recon__retraceTimePeriod

        let agentPos = transform[3]
        let lookByDir = human_net_phys.phys.appliedCT.wishLookDir
        let lookFromPos = agentPos + float3(0.0, RECON_TRACEH, 0.0)
        let maxOffsSq = square(recon__maxOffsetNoRetrace)

        query() <| $ [es] (covers : CoversComponent)
          var found = -1
          let amount = length(recon__elemData1)
          for _i in range(amount)
            let idx = recon__iterators.x % amount
            recon__iterators.x += 1

            let data1 = recon__elemData1[idx]
            if data1.w == 0
              continue

            let wasAgentPos = recon__elemData4[idx].xyz
            if distance_sq(agentPos, wasAgentPos) < maxOffsSq
              if is_recon_in_fov(recon__elemData2[idx].xyz, lookFromPos, lookByDir)
                assume posThreat = recon__elemData2[idx]
                assume tracedFrom = recon__elemData4[idx]
                if fade_recon_threat(curTime, tracedFrom.w, posThreat.w)
                  try_save_recon_threat(recon__teamEid, data1.x, curTime, tracedFrom.w, posThreat.w)
              continue

            if found < 0
              found = idx
          if found >= 0
            var dropIt = false
            let foundKey = recon__elemData1[found].x
            assume extra = covers.coverExtra[foundKey]
            var tracePos = float3()
            
            if !get_recon_corner_trace_pos(tracePos, extra.pos, extra.info, lookFromPos)
              dropIt = true
            elif !recon_trace(lookFromPos, tracePos, recon__stoppers, recon__nextStopper, recon__stats)
              dropIt = true

            assume posThreat = recon__elemData2[found]
            assume tracedFrom = recon__elemData4[found]
            if !dropIt
              posThreat.x = tracePos.x
              posThreat.y = tracePos.y
              posThreat.z = tracePos.z
              tracedFrom.x = agentPos.x
              tracedFrom.y = agentPos.y
              tracedFrom.z = agentPos.z
              if is_recon_in_fov(tracePos, lookFromPos, lookByDir)
                if fade_recon_threat(curTime, tracedFrom.w, posThreat.w)
                  try_save_recon_threat(recon__teamEid, foundKey, curTime, tracedFrom.w, posThreat.w)
            else
              try_save_recon_threat(recon__teamEid, foundKey, curTime, tracedFrom.w, posThreat.w)
              recon_elem_del(found, recon__buckets, recon__elemData1)

      if curTime > recon__nextUpdateTime
        recon__nextUpdateTime = curTime + rnd_float(recon__updateTimePeriod.x, recon__updateTimePeriod.y)

        let agentPos = transform[3]

        let isHuman = !beh_tree__enabled 
        var focusDist = recon__scanFocusDist
        if isHuman
          focusDist = (0.5 + sin(curTime * 0.5) * 0.5) * recon__scanDistances.y

        let lookByDir = human_net_phys.phys.appliedCT.wishLookDir
        let lookFromPos = agentPos + float3(0.0, RECON_TRACEH, 0.0)

        let forwOffs = recon__iterators.z == 0 ? recon__scanDistances.x : recon__scanDistances.z
        let maxDist = recon__iterators.z == 0 ? recon__scanDistances.y : recon__scanDistances.w
        

        let excludeFirst = recon__iterators.z == 1
        let excludeCenter = agentPos + transform[0] * recon__scanDistances.x
        let excludeDistSq = square(recon__scanDistances.y)

        var box : bbox3f
        let boxCenter = agentPos + transform[0] * forwOffs
        box.bmax.xyz = boxCenter + float3(maxDist, recon__scanHeights.y, maxDist)
        box.bmin.xyz = boxCenter + float3(-maxDist, recon__scanHeights.x, -maxDist)

        var isMoving = false
        query(eid) <| $ [es] (human_net_phys : HumanActor)
          isMoving = human_net_phys.phys.currentState.moveState != HUMoveState.EMS_STAND

        var leftScans = !isMoving ? recon__maxScannedPerUpdate.x : recon__maxScannedPerUpdate.y
        var leftTraces = !isMoving ? recon__maxTracedPerUpdate.x : recon__maxTracedPerUpdate.y

        query() <| $ [es] (var covers : CoversComponent&)
          let numCovers = length(covers.list)
          let numExtra = length(covers.coverExtra)
          if numExtra != numCovers
            return

          var amount = 0
          var filtered = 0
          var stop = false
          covers_box_cull(covers, box) <| $ [unused_argument(tm)] (id : int; tm : mat44f#)
            if stop
              return

            amount += 1
            if amount <= recon__iterators.y
              return

            assume extra = covers.coverExtra[id]
            let reconType = recon_type(extra.info)
            if !recon_flag(extra.info, RCXI_FLAG_CONTAINS) || reconType != int(ReconType.CORNER)
              recon__iterators.y += 1
              filtered += 1
              return

            
            
            
            
            

            if excludeFirst && distance_sq(excludeCenter, extra.pos) < excludeDistSq
              recon__iterators.y += 1
              filtered += 1
              return

            var tracePos = float3()
            if !get_recon_corner_trace_pos(tracePos, extra.pos, extra.info, lookFromPos)
              recon__iterators.y += 1
              filtered += 1
              return

            if isHuman && !is_recon_in_fov(tracePos, lookFromPos, lookByDir)
              recon__iterators.y += 1
              filtered += 1
              return

            if leftScans <= 0
              stop = true
              return
            leftScans -= 1

            if recon_elem_find(id, recon__buckets, recon__elemData1)
              recon__iterators.y += 1
              return

            if leftTraces <= 0
              stop = true
              return
            leftTraces -= 1
            recon__iterators.y += 1

            if recon_trace(lookFromPos, tracePos, recon__stoppers, recon__nextStopper, recon__stats)
              let idx = recon_elem_add(id, recon__buckets, recon__elemData1, covers,
                                      recon__elemData2, recon__elemData4, tracePos,
                                      lookFromPos, lookByDir, isHuman,
                                      recon__teamEid, curTime, focusDist)
              if idx >= 0
                recon__elemData1[idx].w = reconType

                assume data2 = recon__elemData2[idx]
                data2.x = tracePos.x
                data2.y = tracePos.y
                data2.z = tracePos.z
                data2.w = 1.0 

                let loadedThreat = try_load_recon_threat(recon__teamEid, id, curTime)
                if loadedThreat >= 0.0
                  data2.w = loadedThreat

                recon__elemData3[idx] = get_recon_corner_dirs_packed(extra.info)

                assume data4 = recon__elemData4[idx]
                data4.x = agentPos.x
                data4.y = agentPos.y
                data4.z = agentPos.z
                data4.w = curTime

          if recon__iterators.y >= amount
            recon__iterators.y = 0
            if recon__scanDistances.w > 0.0
              recon__iterators.z = (recon__iterators.z == 0) ? 1 : 0
            if recon__iterators.z == 0
              recon__cycle += 1

          
          
