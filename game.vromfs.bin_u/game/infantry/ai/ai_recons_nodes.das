options always_export_initializer = true

require app
require ecs
require BehNodes
require walkerai
require DngWalkerai
require DagorDataBlock
require DagorSystem
require math.random
require math.base
require math.ang
require Dacoll
require DagorMath
require DagorRandom
require %appGame.infantry.ai.ai_recons_common
require %appGame.infantry.es.walker_common
require %appGame.infantry.es.team_common
require Mission


[beh_node(name="reportReconsThreat")]
class ReportReconsThreat : BehNodeAdapter
  posParam : int = -1
  threatLevel : float = 5.0
  threatRadius : float = 10.0
  maxThreatLevel : float = 3.0
  maxHeightOffset : float = 2.5

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    threatLevel = datablock_getReal(data, "threatLevel", threatLevel)
    threatRadius = datablock_getReal(data, "threatRadius", threatRadius)
    maxThreatLevel = datablock_getReal(data, "maxThreatLevel", maxThreatLevel)
    maxHeightOffset = datablock_getReal(data, "maxHeightOffset", maxHeightOffset)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)

    let curTime = get_sync_time()
    let maxRadiusSq = square(threatRadius)
    let threatPos = owner.blackBoard |> datablock_getPoint3(posParam)

    query() <| $ [es] (recon__team : int;
                       recon__teamEid : EntityId;
                       recon__elemData1 : IPoint4List;
                       var recon__elemData2 : Point4List&;
                       var recon__elemData4 : Point4List&;
                       recon__backTrackPosTime : Point4List;
                       recon__backTrackLast : int;
                       var recon__backTrackLen : int&)
      if recon__team != agent.teamId || recon__teamEid == INVALID_ENTITY_ID
        return

      var backUnsafe = false
      var iter = recon__backTrackLast
      let queueSize = length(recon__backTrackPosTime)
      for _i in range(recon__backTrackLen)
        assume elem = recon__backTrackPosTime[iter]
        if distance_sq(elem.xyz, threatPos) < maxRadiusSq
          backUnsafe = true
          break
        iter = (iter + queueSize - 1) % queueSize
      if backUnsafe
        recon__backTrackLen = 0

      for data1, data2, data4 in recon__elemData1, recon__elemData2, recon__elemData4
        if data1.w == 0
          continue

        let tracePos = data2.xyz
        let distSq = distance_sq(tracePos.xz, threatPos.xz)
        if distSq > maxRadiusSq
          continue
        if abs(tracePos.y - threatPos.y) > maxHeightOffset
          continue

        let threatUp = safediv(threatLevel, distSq)
        let wasThreat = calc_recon_threat(curTime, data4.w, data2.w)
        let newThreat = min(maxThreatLevel, wasThreat + threatUp)

        data4.w = curTime
        data2.w = newThreat

        try_save_recon_threat(recon__teamEid, data1.x, curTime, data4.w, data2.w)

        

    

    return EBehResult.ER_SUCCESS


[beh_node(name="findReconLookPointsAroundAndBack")]
class FindReconLookPointsAroundAndBack : BehNodeAdapter
  outPosParam1 : int = -1
  outPosParam2 : int = -1
  outStanceParam1 : int = -1
  outStanceParam2 : int = -1
  outAmountParam : int = -1
  fromPosParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    outPosParam1 = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam1", ""), float3())
    outPosParam2 = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam2", ""), float3())
    outStanceParam1 = owner.blackBoard |> get_or_create(datablock_getStr(data, "outStanceParam1", ""), 1)
    outStanceParam2 = owner.blackBoard |> get_or_create(datablock_getStr(data, "outStanceParam2", ""), 1)
    outAmountParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outAmountParam", ""), 0)
    if datablock_find_param(data, "fromPosParam") >= 0
      fromPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "fromPosParam", ""), float3())

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)

    var fromPos = agent.pos
    if fromPosParam >= 0
      fromPos = owner.blackBoard |> datablock_getPoint3(fromPosParam)

    var backSum = float3()
    var backNow = float3()
    var backCnt = 0
    query(agent.eid) <| $ [es] (recon__backTrackPosTime : Point4List;
                                recon__backTrackLast : int;
                                recon__backTrackLen : int)
      var iter = recon__backTrackLast
      let queueSize = length(recon__backTrackPosTime)
      var gotBackNow = false
      for _i in range(recon__backTrackLen)
        let pos = recon__backTrackPosTime[iter].xyz
        if pos != fromPos
          if !gotBackNow
            gotBackNow = true
            backNow = pos
          backSum += pos
          backCnt++
        iter = (iter + queueSize - 1) % queueSize

    if backCnt > 0
      backSum /= float(backCnt)
      if backSum == fromPos
        backSum += float3(0.001, 0.0, 0.0)
    else
      var dirSin, dirCos : float
      sincos(rnd_float(0.0, TWOPI), dirSin, dirCos)
      backSum.x = fromPos.x + dirSin
      backSum.y = fromPos.y
      backSum.z = fromPos.z + dirCos
      backNow = -backSum

    var withBackNow = false
    let deltaBackAvg = backSum - fromPos
    let deltaBackNow = backNow - fromPos
    let yawBackAvg = atan2(deltaBackAvg.x, deltaBackAvg.z)
    let yawBackNow = atan2(deltaBackNow.x, deltaBackNow.z)
    let yawDelta = norm_s_ang(yawBackAvg - yawBackNow)
    if abs(yawDelta) > deg_to_rad(60.0)
      withBackNow = true

    let turnRight = rnd_float(0.0, 1.0) < 0.5
    let turnPos = turnRight ? float3(-backNow.z, backNow.y, backNow.x) : float3(backNow.z, backNow.y, -backNow.x)

    let maxRoll = withBackNow ? 5 : 2
    let roll = clamp(rnd_int(0, maxRoll), 0, maxRoll)

    var resultPos1 = float3()
    var resultPos2 = float3()
    var resultNum = 0

    if roll == 0
      resultPos1 = backSum
      resultNum = 1
    elif roll == 1
      if rnd_float(0.0, 1.0) < 0.5
        resultPos1 = backSum
        resultPos2 = turnPos
        resultNum = 2
      else
        resultPos1 = turnPos
        resultPos2 = backSum
        resultNum = 2
    elif roll == 2
      resultPos1 = turnPos
      resultNum = 1
    elif roll == 3
      resultPos1 = backNow
      resultNum = 1
    elif roll == 4
      if rnd_float(0.0, 1.0) < 0.5
        resultPos1 = backSum
        resultPos2 = backNow
        resultNum = 2
      else
        resultPos1 = backNow
        resultPos2 = backSum
        resultNum = 2
    else 
      if rnd_float(0.0, 1.0) < 0.5
        resultPos1 = turnPos
        resultPos2 = backNow
        resultNum = 2
      else
        resultPos1 = backNow
        resultPos2 = turnPos
        resultNum = 2

    owner.blackBoard |> set(outPosParam1, resultPos1)
    owner.blackBoard |> set(outPosParam2, resultPos2)
    owner.blackBoard |> set(outStanceParam1, rnd_int(1, 2))
    owner.blackBoard |> set(outStanceParam2, rnd_int(1, 2))
    owner.blackBoard |> set(outAmountParam, resultNum)

    return EBehResult.ER_SUCCESS



def extend_ang_range(rmin : float; rmax : float; ang : float) : float3
  if rmin <= rmax
    if ang >= rmin && ang <= rmax
      return float3(rmin, rmax, 0.0)
  elif ang < rmax && ang > rmin
    return float3(rmin, rmax, 0.0)
  let dmin = norm_ang(rmin - ang)
  let dmax = norm_ang(ang - rmax)
  if dmin < dmax
    return float3(ang, rmax, dmin)
  return float3(rmin, ang, dmax)

def calc_ang_range_center(rmin : float; rmax : float) : float
  if rmin < rmax
    return (rmin + rmax) * 0.5
  return norm_s_ang((rmin + rmax + TWOPI) * 0.5)


def get_ang_range_look_point(group_idx : int; group_data : array<float4>&; elems_data : array<int3>&;
                             recon_data2 : Point4List; look_from_pos : float3) : float3
  if group_idx < 0
    
    return float3()

  var limit = 32
  var cnt = 0

  var idx = int(group_data[group_idx].w)
  while idx >= 0 && limit > 0
    --limit
    assume elem = elems_data[idx]
    
    cnt++
    idx = elem.z

  if cnt <= 0
    
    return float3()

  var roll = rnd_int(0, cnt - 1)

  limit = 32
  idx = int(group_data[group_idx].w)
  while idx >= 0 && limit > 0
    --limit
    assume elem = elems_data[idx]
    if roll-- <= 0
      return recon_data2[elem.x].xyz
    idx = elem.z

  
  let tmp = look_from_pos.x * 0.0
  return float3(tmp)

def calc_safety_from_recons(pos_crouch : float3; pos_crawl : float3;
                            group_idx : int; group_data : array<float4>&;
                            elems_data : array<int3>&; recon_data2 : Point4List) : int
  if group_idx < 0
    return 0

  var crouchSeen = false
  var crawlSeen = false

  var limit = 32
  var ids : array<int>
  ids |> resize(limit)
  var cnt = 0

  var idx = int(group_data[group_idx].w)
  while idx >= 0 && limit > 0
    --limit
    assume elem = elems_data[idx]
    ids[cnt++] = elem.x
    idx = elem.z

  shuffle(ids)

  let MAX_TRACES = 3
  limit = min(MAX_TRACES, length(ids))
  for i in range(limit)
    assume tracePos = recon_data2[ids[i]].xyz

    let delta1 = tracePos - pos_crouch
    let dir1 = normalize(delta1)
    var dist = length(delta1)
    var norm : float3
    if !traceray_normalized(pos_crouch, dir1, dist, norm, ETF_DEFAULT)
      crouchSeen = true

    if !crouchSeen
      continue

    let delta2 = tracePos - pos_crawl
    let dir2 = normalize(delta2)
    dist = length(delta2)
    if !traceray_normalized(pos_crawl, dir2, dist, norm, ETF_DEFAULT)
      crawlSeen = true

  return !crouchSeen ? 2 : !crawlSeen ? 1 : 0


[beh_node(name="findReconLookPointsFromTracing")]
class FindReconLookPointsFromTracing : BehNodeAdapter
  outPosParam1 : int = -1
  outPosParam2 : int = -1
  outPosParam3 : int = -1
  outAmountParam : int = -1
  outThreatParam : int = -1

  outLookStanceParam : int = -1
  outHideStanceParam : int = -1

  outHideMoveParam : int = -1
  outHideMoveToPosParam : int = -1
  outHideReturnPosParam : int = -1

  minReconDistance : float = 2.0
  maxDangerDistance : float = 100.0
  maxDangersAmount : int = 5
  maxAngleToDangerDeg : float = 50.0
  maxAngleToDangerCos : float = 0.64

  enemySideThreatCoef = 2.0
  backtrackThreatCoef = 0.7
  backtrackCloseRadius = 3.5
  backtrackCloseRadiusSq : float = -1.0

  minThreatToLook : float = 0.25

  def override loadFromBlk(var data : DataBlock) : void
    outPosParam1 = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam1", ""), float3())
    outPosParam2 = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam2", ""), float3())
    outPosParam3 = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam3", ""), float3())
    outAmountParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outAmountParam", ""), 0)
    outThreatParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outThreatParam", ""), 0)

    outLookStanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outLookStanceParam", ""), 2)
    outHideStanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outHideStanceParam", ""), 1)

    outHideMoveParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outHideMoveParam", ""), 0)
    outHideMoveToPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outHideMoveToPosParam", ""), float3())
    outHideReturnPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outHideReturnPosParam", ""), float3())

    minThreatToLook = datablock_getReal(data, "minThreatToLook", minThreatToLook)

    backtrackCloseRadiusSq = square(backtrackCloseRadius)

    maxAngleToDangerDeg = datablock_getReal(data, "maxAngleToDangerDeg", maxAngleToDangerDeg)
    maxAngleToDangerCos = cos(deg_to_rad(maxAngleToDangerDeg))

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    let curTime = get_sync_time()

    let MAX_GROUPS = 4
    var groupData : array<float4> 
    var elemsData : array<int3>   

    groupData |> resize(MAX_GROUPS)
    for group in groupData
      group.w = -1.0

    var lookFromStandPos = agent.pos + float3(0.0, 1.5, 0.0)
    var lookFromCrouchPos = agent.pos + float3(0.0, 1.1, 0.0)
    var lookFromCrawlPos = agent.pos + float3(0.0, 0.3, 0.0)

    var avgEnemyRespawnPos = float3()
    var avgEnemyRespawnsCount = 0
    get_respawn_points() <| $(active, respType, team, respPos)
      if !active || team == agent.teamId || team == TEAM_UNASSIGNED || respType != "human"
        return
      avgEnemyRespawnPos += respPos
      avgEnemyRespawnsCount++
    if avgEnemyRespawnsCount > 0
      avgEnemyRespawnPos /= float(avgEnemyRespawnsCount)

    let MAX_DANGER_DIST_SQ = square(maxDangerDistance)
    var dangerPositions : array<float3>
    dangerPositions |> reserve(maxDangersAmount)
    find_query() <| $ [es] (mean_pos__pos : float3; mean_pos__team : int)
      if mean_pos__team != agent.teamId && distance_sq(mean_pos__pos, agent.pos) < MAX_DANGER_DIST_SQ
        dangerPositions |> push(mean_pos__pos)
        if length(dangerPositions) >= maxDangersAmount
          return true
      return false
    if empty(dangerPositions)
      find_query() <| $ [es(REQUIRE=human_net_phys)] (team : int; transform : float3x4; eid : EntityId)
        let pos = transform[3]
        if eid != agent.eid && team == agent.teamId && distance_sq(pos, agent.pos) < MAX_DANGER_DIST_SQ
          dangerPositions |> push(pos)
          if length(dangerPositions) >= maxDangersAmount
            return true
        return false

    var gotAgent = false
    query(agent.eid) <| $ [es] (recon__team : int;
                                recon__teamEid : EntityId;
                                recon__elemData1 : IPoint4List;
                                recon__elemData2 : Point4List;
                                recon__elemData4 : Point4List;
                                walker_agent : EntityAgent;
                                recon__backTrackPosTime : Point4List;
                                recon__backTrackLast : int;
                                recon__backTrackLen : int)
      if recon__team != agent.teamId || recon__teamEid == INVALID_ENTITY_ID
        return
      gotAgent = true

      lookFromStandPos = walker_agent.shootFrom[STANCE_STAND]
      lookFromCrouchPos = walker_agent.shootFrom[STANCE_CROUCH]
      lookFromCrawlPos = walker_agent.shootFrom[STANCE_CRAWL]

      let MAX_MERGE_ANG_DIST_RAD = deg_to_rad(30.0)
      let MAX_GROUP_ANG_RANGE_RAD = deg_to_rad(90.0)

      let amount = length(recon__elemData1)
      elemsData |> resize(amount)

      let MIN_RECON_DIST_SQ = square(minReconDistance)
      for i in range(amount)
        let data1 = recon__elemData1[i]
        if data1.w == 0
          continue

        let data2 = recon__elemData2[i]
        let data4 = recon__elemData4[i]

        let tracePos = data2.xyz
        let delta = tracePos - lookFromStandPos
        if length_sq(delta) < MIN_RECON_DIST_SQ
          continue

        var tryLookThere = false
        for dangerPos in dangerPositions
          let toDanger = normalize(dangerPos - lookFromStandPos)
          if dot(delta, toDanger) > maxAngleToDangerCos
            tryLookThere = true
            break
        if !tryLookThere
          continue

        let yaw = norm_s_ang(atan2(delta.x, delta.z))
        

        var fitGroup = -1
        var fitRange = float3()
        for groupIdx in iter_range(groupData)
          assume group = groupData[groupIdx]
          if group.w < 0.0
            continue
          let merged = extend_ang_range(group.x, group.y, yaw)
          
          if merged.z >= 0.0 && merged.z < MAX_MERGE_ANG_DIST_RAD && (fitGroup < 0 || merged.z < fitRange.z)
            if norm_ang(merged.y - merged.x) < MAX_GROUP_ANG_RANGE_RAD
              
              fitGroup = groupIdx
              fitRange = merged
              if merged.z == 0.0
                break

        

        var threatEst = calc_recon_threat(curTime, data4.w, data2.w)

        if recon__backTrackLen > 0
          var alongBacktrack = false
          var iter = recon__backTrackLast
          let queueSize = length(recon__backTrackPosTime)
          for _i in range(recon__backTrackLen)
            assume elem = recon__backTrackPosTime[iter]
            if distance_sq(elem.xyz, tracePos) < backtrackCloseRadiusSq
              alongBacktrack = true
              break
            iter = (iter + queueSize - 1) % queueSize
          if alongBacktrack
            threatEst *= backtrackThreatCoef

        if avgEnemyRespawnsCount > 0 && dot(delta, avgEnemyRespawnPos - lookFromStandPos) > 0.0
          threatEst *= enemySideThreatCoef

        if fitGroup < 0
          for groupIdx in iter_range(groupData)
            assume group = groupData[groupIdx]
            if group.w < 0.0
              fitGroup = groupIdx
              fitRange = float3(yaw, yaw, 0.0)
              break
          if fitGroup < 0
            var minThreat = threatEst
            for groupIdx in iter_range(groupData)
              assume group = groupData[groupIdx]
              if group.z < minThreat
                fitGroup = groupIdx
                fitRange = float3(yaw, yaw, 0.0)
                minThreat = group.z
            if fitGroup >= 0
              groupData[fitGroup] = float4(yaw, yaw, threatEst, -1.0)
          
        if fitGroup < 0
          continue

        assume group = groupData[fitGroup]
        group.x = fitRange.x
        group.y = fitRange.y
        group.z = max(group.z, threatEst)
        elemsData[i].x = i
        elemsData[i].y = data1.x
        elemsData[i].z = int(group.w)
        group.w = float(i)

        

    if !gotAgent
      return EBehResult.ER_FAILED

    for groupIdx in iter_range(groupData)
      assume group = groupData[groupIdx]
      if group.w < minThreatToLook
        group.w = 0.0
        group.z = -1.0

    groupData |> sort() <| $(left; right)
      return left.z > right.z

    let groupForw = groupData[0].z > 0.0 ? 0 : -1
    if groupForw < 0
      return EBehResult.ER_FAILED

    var groupBack = -1
    var groupSide1 = -1
    var groupSide2 = -1

    let forwCenterYaw = calc_ang_range_center(groupData[0].x, groupData[0].y)

    var bestBackDeltaYaw = PI * 0.75
    for groupIdx in iter_range(groupData)
      assume group = groupData[groupIdx]
      if group.w >= 0.0 && groupIdx != groupForw
        let centerYaw = calc_ang_range_center(group.x, group.y)
        let deltaYaw = norm_s_ang(centerYaw - forwCenterYaw)
        let absDeltaYaw = abs(deltaYaw)
        if absDeltaYaw > bestBackDeltaYaw
          groupBack = groupIdx
          bestBackDeltaYaw = absDeltaYaw

    for groupIdx in iter_range(groupData)
      assume group = groupData[groupIdx]
      if group.w >= 0.0 && groupIdx != groupForw && groupIdx != groupBack
        if groupSide1 == -1
          groupSide1 = groupIdx
        elif groupSide2 == -1
          groupSide2 = groupIdx

    var success = true
    query(agent.eid) <| $ [es] (recon__elemData2 : Point4List)
      let safeForw = calc_safety_from_recons(lookFromCrouchPos, lookFromCrawlPos, groupForw, groupData, elemsData, recon__elemData2)
      let safeBack = calc_safety_from_recons(lookFromCrouchPos, lookFromCrawlPos, groupBack, groupData, elemsData, recon__elemData2)
      let safeSide1 = calc_safety_from_recons(lookFromCrouchPos, lookFromCrawlPos, groupSide1, groupData, elemsData, recon__elemData2)
      let safeSide2 = calc_safety_from_recons(lookFromCrouchPos, lookFromCrawlPos, groupSide2, groupData, elemsData, recon__elemData2)

      var safeAll = 2
      if safeForw <= 0 || (groupBack >= 0 && safeBack <= 0) || (groupSide1 >= 0 && safeSide1 <= 0) || (groupSide2 >= 0 && safeSide2 <= 0)
        safeAll = 0
      elif safeForw <= 1 || (groupBack >= 0 && safeBack <= 1) || (groupSide1 >= 0 && safeSide1 <= 1) || (groupSide2 >= 0 && safeSide2 <= 1)
        safeAll = 1

      if safeAll == 0
        var found = false
        
        
        found = true
        owner.blackBoard |> set(outHideMoveParam, 0)
        owner.blackBoard |> set(outHideMoveToPosParam, float3())
        owner.blackBoard |> set(outHideReturnPosParam, float3())
        if !found
          success = false
          return

      owner.blackBoard |> set(outLookStanceParam, safeAll == 2 ? 2 : 1)
      owner.blackBoard |> set(outHideStanceParam, safeAll == 2 ? 1 : 0)

      if groupBack < 0
        if groupSide2 < 0
          if groupSide1 < 0
            owner.blackBoard |> set(outPosParam1, get_ang_range_look_point(groupForw, groupData, elemsData, recon__elemData2, lookFromStandPos))
            owner.blackBoard |> set(outAmountParam, 1)
            owner.blackBoard |> set(outThreatParam, 0)
          else
            owner.blackBoard |> set(outPosParam1, get_ang_range_look_point(groupForw, groupData, elemsData, recon__elemData2, lookFromStandPos))
            owner.blackBoard |> set(outPosParam2, get_ang_range_look_point(groupSide1, groupData, elemsData, recon__elemData2, lookFromStandPos))
            owner.blackBoard |> set(outAmountParam, 2)
            owner.blackBoard |> set(outThreatParam, 1)
        else
          let roll = rnd_float(0.0, 1.0) < 0.5
          owner.blackBoard |> set(outPosParam2, get_ang_range_look_point(roll ? groupSide1 : groupSide2, groupData, elemsData, recon__elemData2, lookFromStandPos))
          owner.blackBoard |> set(outPosParam1, get_ang_range_look_point(groupForw, groupData, elemsData, recon__elemData2, lookFromStandPos))
          owner.blackBoard |> set(outPosParam3, get_ang_range_look_point(roll ? groupSide2 : groupSide1, groupData, elemsData, recon__elemData2, lookFromStandPos))
          owner.blackBoard |> set(outAmountParam, 3)
          owner.blackBoard |> set(outThreatParam, 2)
          
      else
        if groupSide2 < 0
          if groupSide1 < 0
            owner.blackBoard |> set(outPosParam1, get_ang_range_look_point(groupForw, groupData, elemsData, recon__elemData2, lookFromStandPos))
            owner.blackBoard |> set(outPosParam2, get_ang_range_look_point(groupBack, groupData, elemsData, recon__elemData2, lookFromStandPos))
            owner.blackBoard |> set(outAmountParam, 2)
            owner.blackBoard |> set(outThreatParam, 1)
            
          else
            owner.blackBoard |> set(outPosParam1, get_ang_range_look_point(groupForw, groupData, elemsData, recon__elemData2, lookFromStandPos))
            owner.blackBoard |> set(outPosParam2, get_ang_range_look_point(groupSide1, groupData, elemsData, recon__elemData2, lookFromStandPos))
            owner.blackBoard |> set(outPosParam3, get_ang_range_look_point(groupBack, groupData, elemsData, recon__elemData2, lookFromStandPos))
            owner.blackBoard |> set(outAmountParam, 3)
            owner.blackBoard |> set(outThreatParam, 3)
            
        else
          owner.blackBoard |> set(outPosParam1, get_ang_range_look_point(groupForw, groupData, elemsData, recon__elemData2, lookFromStandPos))
          owner.blackBoard |> set(outAmountParam, 1)
          owner.blackBoard |> set(outThreatParam, 3)

    return success ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="setNextReconFocusDist")]
class SetNextReconFocusDist : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    query(agent.eid) <| $ [es] (var recon__scanFocusDist : float&;
                                recon__scanFocusDists : float4)
      assume dist = recon__scanFocusDist
      assume dists = recon__scanFocusDists
      if dist == dists.x
        dist = dists.y
      elif dist == dists.y
        dist = dists.z
      elif dist == dists.z
        dist = dists.w
      else
        dist = dists.x
    return EBehResult.ER_SUCCESS


[beh_node(name="decrementNonZeroIntVar")]
class DecrementNonZeroIntVar : BehNodeAdapter
  param : int = -1
  def override loadFromBlk(var data : DataBlock) : void
    param = owner.blackBoard |> get_or_create(datablock_getStr(data, "param", ""), 0)
  def override update(dt : float) : EBehResult
    let counter = owner.blackBoard |> datablock_getInt(param)
    if counter <= 0
      return EBehResult.ER_FAILED
    owner.blackBoard |> set(param, counter - 1)
    return EBehResult.ER_SUCCESS






