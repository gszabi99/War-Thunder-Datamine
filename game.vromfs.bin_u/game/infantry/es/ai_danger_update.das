require ecs
require ecs.common
require app
require walkerai
require %appGame.infantry.es.team_common
require math
require math.base
require DagorRandom
require Dacoll
require RendInst
require CollRes
require AnimV20
require Grid
require GridCollision
require %appGame.infantry.es.ai_danger_common
require %appGame.infantry.ai.ai_weapons_common
require %appGame.infantry.es.walker_common
require SmokeOccluder
require DngHuman
require HumanPhys
require DagorMath
require DagorDebug3D

struct TargetData
  eid : EntityId
  team : int
  isAlive : bool
  isDowned : bool
  isHidden : bool
  targetPos : float3
  stance : int
  moving : int

def TargetData(eid : EntityId; team : int; target : Target; stance : int; moving : int)
  return TargetData(eid = eid,
           team = team,
           isAlive = target.isAlive,
           isDowned = target.isDowned,
           isHidden = target.isHidden,
           targetPos = target.targetPos,
           stance = stance,
           moving = moving)

def categorize_moving(move_state : HUMoveState)
  if move_state == HUMoveState.EMS_STAND
    return 0
  if move_state == HUMoveState.EMS_RUN
    return 2
  if move_state == HUMoveState.EMS_SPRINT
    return 3
  return 1

def find_danger(var agent_dangers : AgentDangers; eid : EntityId)
  for i in iter_range(agent_dangers.dangers)
    if agent_dangers.dangers[i].eid == eid
      return i
  return -1

[es(tag=server, no_order)]
def ai_danger_update_alertness(act : UpdateStageInfoAct)
  var targets : table<uint; TargetData>
  query() <| $ [es(REQUIRE_NOT=ai_target__autoGunTarget)] (eid : EntityId; ai_target : Target; team : int;
                                                           human_net_phys : HumanActor const?; vehicle_seats__seatEids : EidList const?)
    var stance = STANCE_STAND
    var targetTeam = team
    var moving = 0
    if human_net_phys != null
      assume currentState = human_net_phys.phys.currentState
      stance = determinate_stance(currentState)
      moving = categorize_moving(currentState.moveState)
    if vehicle_seats__seatEids != null && team == TEAM_UNASSIGNED
      for seatEid in *vehicle_seats__seatEids
        query(seatEid) <| $ [es] (seat__ownerEid : EntityId)
          query(seat__ownerEid) <| $ [es] (team aka passenger_team : int)
            targetTeam = passenger_team
    var targetData = TargetData(eid, targetTeam, ai_target, stance, moving)
    targets.emplace(uint(eid), targetData)

  query() <| $ [es] (eid : EntityId;
                     isAlive : bool; team : int;
                     beh_tree__enabled : bool = true;
                     beh_tree__limitedMode : int = 0;
                     isInVehicle : bool = false;
                     squad_member__squad : EntityId = INVALID_ENTITY_ID;
                     var agent_dangers : AgentDangers;
                     agent_dangers__standShootPos : float3;
                     agent_dangers__standShootDir : float3;
                     agent_dangers__maxDangerDist : float;
                     var agent_dangers__nextDangersCheckTime : float&;
                     alertness_calc__distCoef : float2;
                     alertness_calc__inFrustumCoef : float2;
                     alertness_calc__frustumCoef : float3;
                     alertness_calc__frustumOffset : float2;
                     alertness_calc__crouchCoef : float;
                     alertness_calc__crawlCoef : float;
                     alertness_calc__downedCoef : float;
                     alertness_calc__inVehicleCoef : float;
                     agent_dangers__targetAirplanePilots : bool;
                     agent_dangers__checkTimes = float2(0.3, 0.7);
                     agent_dangers__checkTimeSimplified : float2 = float2(0.5, 0.7);
                     agent_dangers__checkTimeTestPerf : float2 = float2(0.8, 1.2);
                     agent_dangers__frustumAngle = 40.;
                     agent_dangers__frustumAngleCosMovingCoefs = float3(0.75, 0.25, -0.1);
                     agent_dangers__keepDangerEid : EntityId = INVALID_ENTITY_ID;
                     agent_dangers__keepDangerToTime : float = 0.;
                     agent_dangers__blindDistance = 200.)

    if !isAlive || !beh_tree__enabled
      clear(agent_dangers.dangers)
      return
    if act.curTime < agent_dangers__nextDangersCheckTime
      return

    var checkTime : float
    if beh_tree__limitedMode > 0
      let simplifiedTime = beh_tree__limitedMode == 1 ? agent_dangers__checkTimeSimplified : agent_dangers__checkTimeTestPerf
      checkTime = act.curTime + rnd_float(simplifiedTime.x, simplifiedTime.y)
    else
      checkTime = act.curTime + rnd_float(agent_dangers__checkTimes.x, agent_dangers__checkTimes.y)
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
        if squad__leader == eid
          
          checkTime = act.curTime + rnd_float(agent_dangers__checkTimes.x, agent_dangers__checkTimes.x + agent_dangers__checkTimes.y * 0.5)
    agent_dangers__nextDangersCheckTime = checkTime

    let frustumMinCos = cos(deg_to_rad(agent_dangers__frustumAngle))

    var i = length(agent_dangers.dangers)
    while --i >= 0
      assume danger = agent_dangers.dangers[i]
      if !(targets |> key_exists(uint(danger.eid)))
        
        agent_dangers.dangers |> erase(i)

    for target in values(targets)
      let dangerIdx = find_danger(agent_dangers, target.eid)
      if !target.isAlive || target.isHidden || is_teams_friendly(team, target.team) || target.eid == eid || target.team == TEAM_UNASSIGNED
        if dangerIdx >= 0
          
          erase(agent_dangers.dangers, dangerIdx)
        continue

      if !agent_dangers__targetAirplanePilots
        var isInAirplane = false
        query(target.eid) <| $ [es] (human_anim__vehicleSelected : EntityId)
          query(human_anim__vehicleSelected) <| $ [es(REQUIRE=unit_tag__aircraft)]
            isInAirplane = true

        if isInAirplane
          if dangerIdx >= 0
            
            erase(agent_dangers.dangers, dangerIdx)
          continue

      let targetDir = target.targetPos - agent_dangers__standShootPos
      let dist = length(targetDir)
      if dist > agent_dangers__blindDistance
        if target.eid == agent_dangers__keepDangerEid && act.curTime < agent_dangers__keepDangerToTime
          pass 
        else
          if dangerIdx >= 0
            
            erase(agent_dangers.dangers, dangerIdx)
          continue

      var frustumAngleCoef = 1.0
      if target.moving > 0
        if target.moving == 1
          frustumAngleCoef = agent_dangers__frustumAngleCosMovingCoefs.x
        if target.moving == 2
          frustumAngleCoef = agent_dangers__frustumAngleCosMovingCoefs.y
        if target.moving == 3
          frustumAngleCoef = agent_dangers__frustumAngleCosMovingCoefs.z

      let frustumCos = dot(normalize(targetDir), agent_dangers__standShootDir)
      let inFrustum = frustumCos >= frustumMinCos * frustumAngleCoef
      let inVehicleCoef = isInVehicle ? alertness_calc__inVehicleCoef : 1.
      let alertness = calc_target_alertness(dist, inFrustum, frustumCos, target.stance, target.isDowned,
                                            agent_dangers__maxDangerDist, alertness_calc__distCoef,
                                            alertness_calc__inFrustumCoef, alertness_calc__frustumCoef, alertness_calc__frustumOffset,
                                            alertness_calc__crouchCoef, alertness_calc__crawlCoef, alertness_calc__downedCoef,
                                            inVehicleCoef)
      if alertness <= 0.0
        if dangerIdx >= 0
          
          erase(agent_dangers.dangers, dangerIdx)
      else
        if dangerIdx >= 0
          assume danger = agent_dangers.dangers[dangerIdx]
          danger.distance = dist
          danger.alertness = alertness
          if !inFrustum
            danger.inFrustumTime = -1f
          elif danger.inFrustumTime < 0f
            danger.inFrustumTime = act.curTime
          
        else
          using() <| $(var newDanger : Danger#)
            newDanger.eid = target.eid
            newDanger.inFrustumTime = inFrustum ? act.curTime : -1.
            newDanger.distance = dist
            newDanger.alertness = alertness
            push_clone(agent_dangers.dangers, newDanger)
            

[es(tag=server, on_appear)]
def ai_danger_update_time_init(evt : Event; eid : EntityId; agent_dangers__initialDangersTraceCheckTime : float = 1.0;
                               var agent_dangers__nextDangersTraceTime : float&)
  agent_dangers__nextDangersTraceTime = get_sync_time() + agent_dangers__initialDangersTraceCheckTime * eid_frnd(eid)

def get_shoot_ray_mat(human_attached_gun__attachedGunEid, human_weap__currentGunEid : EntityId)
  var res = -1
  let gunEid = human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid
  query(gunEid) <| $ [es] (gun__aimRayMatId : int)
    res = gun__aimRayMatId
  return res

[es(tag=server, after=(ai_target_es, ai_target_transform_es))]
def ai_danger_trace_targets(act : UpdateStageInfoAct; eid : EntityId; isAlive : bool;
                            transform aka agent_transform : float3x4;
                            var agent_dangers : AgentDangers;
                            agent_dangers__standShootPos : float3;
                            agent_dangers__standShootDir : float3;
                            beh_tree__enabled : bool = true;
                            beh_tree__limitedMode : int = 0;
                            var agent_dangers__nextDangersTraceTime : float&;
                            danger_calc__aiCoef : float2;
                            danger_calc__avoidBulletsNearTime : float;
                            danger_calc__onShootLineMode : bool = false;
                            danger_calc__onShootLineCoefs : float2 = float2(0.5, 2.0);
                            danger_calc__onShootLineDists : float4 = float4(0.0, 35.0, 2.0, 5.0);
                            danger_calc__primaryPredictTime : float = 1.0;
                            danger_calc__primaryPredictVels : float2 = float2(0.0, 5.0);
                            danger_calc__primaryDangerCoef : float = 3.0;
                            danger_calc__keepPrimaryTime : float = 1.5;
                            danger_calc__lastShootCoef : float2;
                            danger_calc__noiseCoef : float2;
                            danger_calc__lastBulletNearbyCoef : float2;
                            agent_dangers__nextDangersTraceCheckTime : float = 0.1;
                            agent_dangers__nextDangersTraceCheckTimeSimplified : float = 0.15;
                            agent_dangers__nextDangersTraceCheckTimeTestPerf : float = 0.7;
                            var human_stat_tracking__targetTracesCount : int?;
                            agent_dangers__minTraceableRatio : float = 3.7;
                            agent_dangers__retraceDists : float2 = float2(10f, 90f);
                            agent_dangers__retraceTimes : float2 = float2(0.3, 30f);
                            agent_dangers__maxDangerDist : float = 100f;
                            agent_dangers__distAlwaysTraceable : float = 0.7;
                            agent_dangers_calc__dangerMeterMult : float = 1f;
                            agent_dangers__hmapTraceOffset : float3 = float3(0., 0., 0.);
                            agent_dangers__keepDangerEid : EntityId = INVALID_ENTITY_ID;
                            agent_dangers__keepDangerToTime : float = 0.;
                            agent_dangers__forceTraceTargetWaitTime : float;
                            var agent_dangers__traceMultipoints : IPoint2List&;
                            var agent_dangers__traceMultipointsLast : int&;
                            agent_dangers__traceMultipointsMax : int = 4;
                            agent_dangers__traceMultipointMaxDistance : float = 50.0;
                            var agent_dangers__forceTraceTargetToTime : float&;
                            var agent_dangers__forceTraceTargetEid1 : EntityId&;
                            var agent_dangers__forceTraceTargetEid2 : EntityId&;
                            var agent_dangers__debugTraceds : int4&;
                            squad_member__squad aka agent__squad_member__squad : EntityId = INVALID_ENTITY_ID;
                            human_attached_gun__attachedGunEid = INVALID_ENTITY_ID;
                            human_weap__currentGunEid = INVALID_ENTITY_ID;
                            var human_stat_tracking__totalDangers : float?)
  if !isAlive || !beh_tree__enabled || length(agent_dangers.dangers) == 0 || act.curTime < agent_dangers__nextDangersTraceTime
    return

  var checkTime = agent_dangers__nextDangersTraceCheckTime
  if beh_tree__limitedMode > 0
    checkTime = beh_tree__limitedMode == 1 ? agent_dangers__nextDangersTraceCheckTimeSimplified : agent_dangers__nextDangersTraceCheckTimeTestPerf
  agent_dangers__nextDangersTraceTime += checkTime

  let agentEid = eid
  let fromPos = agent_dangers__standShootPos
  let flags = (ETF_ALL) & ~(ETF_LMESH | ETF_HEIGHTMAP)
  var maxRatio = 0f
  var traceTo = INVALID_ENTITY_ID

  let sideDir = cross(agent_dangers__standShootDir, agent_transform[1])

  var nearestShootLineDanger = -1
  var nearestShootLineDist = -1.0
  var nearestShootLinePos = float3()

  var targets : array<tuple<ai_target : Target const?; dangerMeter : float, corrTargetPos : float3>>
  reserve(targets, length(agent_dangers.dangers))
  for dangerIdx, danger in iter_range(agent_dangers.dangers), agent_dangers.dangers
    var found = false
    query(danger.eid) <| $ [es(REQUIRE=ai_target)] (ai_target : Target const?; ai_target__noiseLevel = 0.;
                                                    beh_tree__enabled : bool = false;
                                                    ai_target__vertCorr : float3 = float3())
      found = true
      let corrTargetPos = calc_corrected_target_pos(fromPos, ai_target.targetPos, ai_target__vertCorr)
      

      var shootLineCoef = 0.0
      if danger_calc__onShootLineMode && ai_target != null
        let targetDelta = corrTargetPos - fromPos
        let forwDist = dot(targetDelta, agent_dangers__standShootDir)
        if forwDist > 0.0 && forwDist < danger_calc__onShootLineDists.y
          let horzDist = dot(targetDelta, sideDir)
          let dists = danger_calc__onShootLineDists
          let sideDist = cvt(forwDist, dists.x, dists.y, dists.z, dists.w)
          let horzCoef = 1.0 - clamp(abs(horzDist) * safeinv(sideDist), 0.0, 1.0)
          shootLineCoef = horzCoef
          
          
          if shootLineCoef > 0.0
            if shootLineCoef > danger_calc__onShootLineCoefs.x || danger.traceable
              danger.primarySinceTime = act.curTime
              if nearestShootLineDist < 0.0 || forwDist < nearestShootLineDist
                nearestShootLineDanger = dangerIdx
                nearestShootLineDist = forwDist
                nearestShootLinePos = corrTargetPos

      let farTarget = danger.eid == agent_dangers__keepDangerEid && act.curTime < agent_dangers__keepDangerToTime
      let distCutOff = farTarget ? danger.distance : agent_dangers__maxDangerDist
      let potentialDangerMeter = calc_danger(act.curTime, distCutOff, danger, *ai_target, ai_target__noiseLevel, beh_tree__enabled,
                                             danger_calc__aiCoef, danger_calc__avoidBulletsNearTime, shootLineCoef, danger_calc__onShootLineCoefs.y,
                                             danger_calc__lastShootCoef, danger_calc__noiseCoef, danger_calc__lastBulletNearbyCoef)
      targets |> emplace((ai_target, potentialDangerMeter, corrTargetPos))
      let primaryK = (danger.primarySinceTime >= 0.0 && act.curTime < danger.primarySinceTime + danger_calc__keepPrimaryTime) ? danger_calc__primaryDangerCoef : 1.0
      let ratio = calc_traceable_ratio(act.curTime, potentialDangerMeter, danger) * primaryK
      if ratio > maxRatio
        maxRatio = ratio
        traceTo = danger.eid
    if !found
      targets |> emplace(tuple<Target const?; float; float3>())

  if nearestShootLineDanger >= 0
    agent_dangers.dangers[nearestShootLineDanger].lastTraceTime = 0.0
    

  let VERY_CLOSE_DISTANCE = 5.5
  var veryCloseTracesLeft = 2

  var numTracesDone = 0
  agent_dangers__debugTraceds.xyz = int3(0, 0, 0)
  agent_dangers__debugTraceds.x = int(uint(INVALID_ENTITY_ID))
  agent_dangers__debugTraceds.y = int(uint(INVALID_ENTITY_ID))
  agent_dangers__debugTraceds.z = int(uint(INVALID_ENTITY_ID))

  var nextForceTarget = false
  for i in iter_range(agent_dangers.dangers)
    assume danger = agent_dangers.dangers[i]
    let ai_target = targets[i].ai_target
    let potentialDangerMeter = targets[i].dangerMeter
    if ai_target == null || !ai_target.isAlive || ai_target.isHidden
      danger.dangerMeter = 0f
      danger.noiseMeter = 0f
      continue
    let traceByRatio = maxRatio >= agent_dangers__minTraceableRatio
    var retraceTimeCalculated = agent_dangers__retraceTimes.y
    if beh_tree__limitedMode == 0 && !traceByRatio
      retraceTimeCalculated = cvt(danger.distance, agent_dangers__retraceDists.x, agent_dangers__retraceDists.y, agent_dangers__retraceTimes.x, agent_dangers__retraceTimes.y)
    let traceByRetrace = traceByRatio ? false : (act.curTime - danger.lastTraceTime > retraceTimeCalculated)
    let traceByRetraceForced = beh_tree__limitedMode == 0 && traceByRetrace
    let traceByTraceTo = danger.eid == traceTo && (traceByRatio || traceByRetrace)
    let traceByVeryCloseUnseen = !danger.traceable && danger.distance < VERY_CLOSE_DISTANCE && veryCloseTracesLeft > 0
    let traceByForcedTarget = act.curTime < agent_dangers__forceTraceTargetToTime && danger.eid == agent_dangers__forceTraceTargetEid1
    if traceByTraceTo || traceByVeryCloseUnseen || traceByForcedTarget || traceByRetraceForced
      if !traceByTraceTo && !traceByForcedTarget && !traceByRetraceForced
        --veryCloseTracesLeft
      var corrTargetPos = targets[i].corrTargetPos
      var deltaToTarget = corrTargetPos - fromPos
      if danger.primarySinceTime >= 0.0
        let targetVel = length(ai_target.velocity)
        let minVelToPredict = 0.1
        if targetVel > minVelToPredict
          let predictVel = clamp(targetVel, danger_calc__primaryPredictVels.x, danger_calc__primaryPredictVels.y)
          deltaToTarget += normalize(ai_target.velocity) * predictVel * danger_calc__primaryPredictTime
      danger.lastTraceTime = act.curTime
      var dir = normalize(deltaToTarget)
      let lmeshTracePos = fromPos + agent_dangers__hmapTraceOffset
      if human_stat_tracking__targetTracesCount != null
        (*human_stat_tracking__targetTracesCount)++

      agent_dangers__debugTraceds.z = agent_dangers__debugTraceds.y
      agent_dangers__debugTraceds.y = agent_dangers__debugTraceds.x
      agent_dangers__debugTraceds.x = int(uint(danger.eid))

      var collides = true
      let t = min(length(deltaToTarget), danger.distance)
      if t < agent_dangers__distAlwaysTraceable
        collides = false
      else
        var isTargetHuman = false
        var horzAlts = float3()
        query(danger.eid) <| $ [es] (human : Tag const?; ai_target__horzAlts : float3)
          isTargetHuman = human != null
          horzAlts = ai_target__horzAlts
        let mpID = int(uint(danger.eid))
        let mpCount = length(agent_dangers__traceMultipoints)
        var mpIndex = -1
        if isTargetHuman
          for mpIter in range(0, mpCount)
            if agent_dangers__traceMultipoints[mpIter].x == mpID
              mpIndex = mpIter
              break
          if horzAlts.x == 1.0
            let mpVariant = (mpIndex >= 0 ? agent_dangers__traceMultipoints[mpIndex].y : 0) % 3
            if mpVariant > 0
              let dirRt = float3(dir.z, 0.0, -dir.x)
              let sideOffs = (mpVariant == 1 ? 1.0 : -1.0) * dirRt * horzAlts.z
              corrTargetPos = lerp(corrTargetPos, ai_target.targetPos, horzAlts.y) + sideOffs
              deltaToTarget = corrTargetPos - fromPos
              dir = normalize(deltaToTarget)
              

        ++numTracesDone
        let shootRayMat = get_shoot_ray_mat(human_attached_gun__attachedGunEid, human_weap__currentGunEid)
        collides = (rayhit_normalized_lmesh(lmeshTracePos, dir, danger.distance) ||
                    rayhit_normalized(fromPos, dir, danger.distance, flags, shootRayMat) ||
                    traceTransparencyRayRIGenNormalized(fromPos, dir, danger.distance, 0.01) ||
                    rayhit_smoke_occluders(fromPos, corrTargetPos))
        collides ||= rayhit_entities_in_grid(ecs_hash("vehicles"), fromPos, dir, t, danger.eid)
        if !collides
          find_entity_in_grid(ecs_hash("humans"), fromPos, dir, t, 0.0, GridEntCheck.BOUNDING) <| $(objEid : EntityId)
            if !collides && objEid != danger.eid && objEid != agentEid
              query(objEid) <| $ [es] (transform aka obj_transform : float3x4; collres : CollisionResource; animchar : AnimcharBaseComponent;
                                       squad_member__squad aka obj__squad_member__squad : EntityId = INVALID_ENTITY_ID)
                if agent__squad_member__squad == INVALID_ENTITY_ID || agent__squad_member__squad != obj__squad_member__squad
                  collides = collres_rayhit(collres, obj_transform, animchar.nodeTree, fromPos, dir, t)
            return collides

        if collides && isTargetHuman && danger.distance < agent_dangers__traceMultipointMaxDistance
          if mpIndex >= 0
            agent_dangers__traceMultipoints[mpIndex].y += 1
          elif mpCount < agent_dangers__traceMultipointsMax
            agent_dangers__traceMultipoints |> push(int2(mpID, 1))
          else
            assume iter = agent_dangers__traceMultipointsLast
            iter = (iter + 1) % agent_dangers__traceMultipointsMax
            agent_dangers__traceMultipoints[iter] = int2(mpID, 1)

      if !danger.traceable && !collides
        if !nextForceTarget  && danger.eid == agent_dangers__forceTraceTargetEid1
          agent_dangers__forceTraceTargetEid1 = INVALID_ENTITY_ID
          nextForceTarget = true
        let MAX_DISTANCE_FORCE_TRACE_BACK = 50.0
        let CHANCE_DISTANCE_FORCE_TRACE_BACK = 25.0
        if danger.distance < MAX_DISTANCE_FORCE_TRACE_BACK
          if danger.distance < CHANCE_DISTANCE_FORCE_TRACE_BACK
            add_agent_dangers_forced_target(danger.eid, eid)
          elif danger.distance < rnd_float(CHANCE_DISTANCE_FORCE_TRACE_BACK, MAX_DISTANCE_FORCE_TRACE_BACK)
            add_agent_dangers_forced_target(danger.eid, eid)

      danger.traceable = !collides
      if !danger.traceable && danger.primarySinceTime >= 0.0 && danger.primarySinceTime > danger_calc__keepPrimaryTime * 0.5
        danger.primarySinceTime = -1.0
      

      
      
      
      
      
      
      

    danger.dangerMeter = danger.traceable ? potentialDangerMeter : 0.
    danger.dangerMeter *= agent_dangers_calc__dangerMeterMult
    if danger.dangerMeter > 0.0 && danger.dangerMeter < 0.101
      danger.dangerMeter = 0.101

    danger.noiseMeter = potentialDangerMeter

  if nextForceTarget
    agent_dangers__forceTraceTargetToTime = act.curTime + agent_dangers__forceTraceTargetWaitTime
    agent_dangers__forceTraceTargetEid1 = agent_dangers__forceTraceTargetEid2
    agent_dangers__forceTraceTargetEid2 = INVALID_ENTITY_ID

  if numTracesDone > 0
    agent_dangers__debugTraceds.w += 1
    query() <| $ [es] (var global_danger_traces_count : int&; var global_danger_traces_time0 : float&)
      if global_danger_traces_time0 < 0.0
        global_danger_traces_time0 = get_sync_time()
      global_danger_traces_count += numTracesDone

  if human_stat_tracking__totalDangers != null
    *human_stat_tracking__totalDangers += float(length(agent_dangers.dangers)) * agent_dangers__nextDangersTraceCheckTime
