options always_export_initializer = true

require ecs
require net
require app

require %appGame.wt_events
require %appGame.infantry.ai.ai_aiming_common
require %appGame.infantry.es.walker_common
require %appGame.infantry.ai.covers_common
require %appGame.infantry.ai.ai_covers_common
require %appGame.infantry.ai.walker_nodes_common
require %appGame.infantry.es.squad_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums
require %appGame.infantry.es.loc_squad_common
require %appGame.infantry.es.concussion_common
require %appGame.infantry.es.capzones_common
require %appGame.infantry.es.team_common
require %appGame.infantry.ai.walker_vehicles_danger_common
require %appGame.infantry.es.level_common
require %appGame.infantry.es.squad_order_combat_common
require Covers
require CollRes
require DagorSystem
require DagorDataBlock
require math
require math.base
require math.random
require DagorMathUtils
require DagorMath
require BehNodes
require Grid
require pathfinder
require Dacoll
require DngWalkerai
require HumanPhys
require DngHuman
require vehicle
require RendInst
require Unit
require %appGame.infantry.es.pathfinder_common
require %appGame.infantry.ai.ai_recons_common
require human_net_speech.modules.human_net_speech_events
require walkerai
require %appGame.infantry.es.battle_area_common
require %appGame.infantry.es.ai_dangers_attack_debug_common
require strings


[beh_node(name="isInConcussion")]
class IsInConcussion : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let isConcussion = has_concussion_affect(beh_tree_eid(owner))
    return isConcussion ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="inConcussion")]
class InConcussion : BehNodeAdapter
  isStarted : bool = false
  def override init()
    isStarted = false

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED
    let has_concussion = has_concussion_affect(agent.eid)
    if !has_concussion
      return isStarted ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    var phys = agent.phys
    if phys == null
      return EBehResult.ER_FAILED
    if !isStarted
      isStarted = true
      phys.producedCT |> human_control_state_set_walk_speed(0f)
    return EBehResult.ER_RUNNING


[beh_node(name="chooseMaxStance")]
class ChooseMaxStanceNode : BehNodeAdapter
  def override loadFromBlk(var data : DataBlock) : void
    owner.blackBoard |> get_or_create("maxStance", STANCE_STAND)
    owner.blackBoard |> get_or_create("maxStanceOrder", STANCE_STAND)
    owner.blackBoard |> get_or_create("maxStanceOrderForce", false)
    owner.blackBoard |> get_or_create("maxStanceOrderEndTime", 0f)
    owner.blackBoard |> get_or_create("maxStanceAtLeast", STANCE_CRAWL)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let maxStanceAtLeast = owner.blackBoard |> datablock_getInt("maxStanceAtLeast", STANCE_CRAWL)
    var maxStanceOrder = owner.blackBoard |> datablock_getInt("maxStanceOrder", STANCE_STAND)
    let maxStanceOrderForce = owner.blackBoard |> datablock_getBool("maxStanceOrderForce", false)
    var resetOrder = false
    if maxStanceOrder < STANCE_STAND
      let maxStanceOrderEndTime = owner.blackBoard |> datablock_getReal("maxStanceOrderEndTime", 0f)
      if maxStanceOrderEndTime < get_sync_time()
        resetOrder = true
      elif !maxStanceOrderForce && ((get_int(eid, "walker_agent__serverAiAction") ?? int(AiAction.AI_ACTION_UNKNOWN)) == int(AiAction.AI_ACTION_MOVE))
        resetOrder = true

    if resetOrder
      maxStanceOrder = STANCE_STAND
      owner.blackBoard |> set("maxStanceOrder", maxStanceOrder)
      owner.blackBoard |> set("maxStanceOrderForce", false)

    owner.blackBoard |> set("maxStance", max(maxStanceAtLeast, maxStanceOrder))
    return EBehResult.ER_SUCCESS


[beh_node(name="isInAir")]
class IsInAirNode : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var isInAir = false
    query(beh_tree_eid(owner)) <| $ [es] (human_net_phys : HumanActor)
      isInAir = (uint(human_net_phys.phys.currentState.isInAirHistory) & uint(1)) != 0u
    return isInAir ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isSwimming")]
class IsSwimmingNode : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var isSwimming = false
    query(eid) <| $ [es] (human_net_phys : HumanActor)
      isSwimming = human_phys_state_get_is_swimming(human_net_phys.phys.currentState)
    if !isSwimming
      return EBehResult.ER_FAILED
    return EBehResult.ER_SUCCESS

[beh_node(name="isHurt")]
class IsHurt : BehNodeAdapter
  hpMinRatioThreshold : float = -1.0
  dotThreshold : float = -1.0

  def override loadFromBlk(var data : DataBlock) : void
    hpMinRatioThreshold = datablock_getReal(data, "hpMinRatioThreshold", hpMinRatioThreshold)
    dotThreshold = datablock_getReal(data, "dotThreshold", dotThreshold)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var result = EBehResult.ER_FAILED
    query(agentEid) <| $ [es] (hitpoints__hp : float;
                               hitpoints__maxHp : float;
                               hitpoints__totalDotAmount : float;
                               human_inventory__canUseMedkit : bool)
      if hitpoints__maxHp <= 0.0
        return
      if !human_inventory__canUseMedkit
        return

      if hpMinRatioThreshold >= 0.0 && hitpoints__hp / hitpoints__maxHp < hpMinRatioThreshold
        result = EBehResult.ER_SUCCESS
      elif dotThreshold >= 0.0 && hitpoints__totalDotAmount / hitpoints__maxHp > dotThreshold
        result = EBehResult.ER_SUCCESS
    return result

[beh_node(name="useMedkit")]
class UseMedkit : BehNodeAdapter
  syncDelayExtraTime : float = 0.5

  eventWasSent : bool = false
  waitTime : float = 0f

  def override loadFromBlk(var data : DataBlock) : void
    syncDelayExtraTime = data |> datablock_getReal("syncDelayExtraTime", syncDelayExtraTime)

  def override init() : void
    eventWasSent = false
    waitTime = 0f

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)

    if !eventWasSent
      eventWasSent = true
      sendEvent(eid, CmdMedkitUse())
      waitTime = syncDelayExtraTime
    else
      query(eid) <| $ [es] (human_inventory__entityToUse : EntityId; human_inventory__entityUseEnd : float)
        if has(human_inventory__entityToUse, "item__healAmount")
          waitTime = human_inventory__entityUseEnd - get_sync_time() + syncDelayExtraTime

    waitTime -= dt
    return waitTime > 0f ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS


[beh_node(name="isReadyForAction")]
class IsReadyForAction : BehNodeAdapter
  checkFence : bool = false
  fenceFailedTimeParam : int = -1

  notCrawling : bool = false

  timeKeepFail : float = 2.5
  minHeightDown : float = 0.5
  distAheadCheck : float = 1.0

  def override loadFromBlk(var data : DataBlock) : void
    checkFence = datablock_getBool(data, "checkFence", checkFence)
    if checkFence
      fenceFailedTimeParam = owner.blackBoard |> get_or_create("fenceFailedTimeParam", -1.0)
      timeKeepFail = datablock_getReal(data, "timeKeepFail", timeKeepFail)
    notCrawling = datablock_getBool(data, "notCrawling", notCrawling)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var readyForAction = true
    query(eid) <| $ [es] (human_net_phys : HumanActor; walker_agent : EntityAgent; transform : float3x4;
                          human_phys__crawlThreshold : float = -0.1; beh_tree__usingLadders : bool = false)
      assume physState = human_net_phys.phys.currentState
      if human_phys_state_get_is_swimming(physState)
        readyForAction = false
        return
      if human_phys_state_get_is_underwater(physState)
        readyForAction = false
        return
      if beh_tree__usingLadders && physState.isAttachedToLadder
        readyForAction = false
        return
      if notCrawling && physState.height < human_phys__crawlThreshold
        readyForAction = false
        return
      if checkFence && fenceFailedTimeParam >= 0
        let lastTimeFailed = owner.blackBoard |> datablock_getReal(fenceFailedTimeParam)
        if lastTimeFailed >= 0.0 && get_sync_time() < lastTimeFailed + timeKeepFail
          readyForAction = false
          return
        let pos = transform[3]
        var nextPos = float3()
        if get_agent_pathPos(walker_agent, 0, nextPos)
          if pos.y > nextPos.y + minHeightDown
            owner.blackBoard |> set(fenceFailedTimeParam, get_sync_time())
            readyForAction = false
            return
    return readyForAction ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="isIndoor")]
class isIndoorNode : BehNodeAdapter
  offset = float3(0.0, 0.3, 0.0)
  def override update(dt : float) : EBehResult
    var isIndoor = false
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      isIndoor = is_pos_indoor(transform[3] + offset)
    return isIndoor ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


def determinate_radius(phys_state : HumanPhysState)
  return determinate_stance(phys_state) == STANCE_CRAWL ? 0.7 : 0.5

[beh_node(name="validateStandPosition")]
class ValidateStandPositionNode : BehNodeAdapter
  movingTime : float = 0f
  maxMovingTime : float = 2f
  resetWishPositionThreshold : float = 1f
  wishPosParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    wishPosParam = owner.blackBoard |> get_or_create("wishPosition", agent.pos)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_SUCCESS
    var phys = agent.phys
    if phys == null
      return EBehResult.ER_SUCCESS
    var collides = 0
    var moveDir : float3
    if movingTime < maxMovingTime
      let agentRadius = determinate_radius(phys.currentState)
      for_each_entity_in_grid(ecs_hash("humans"), BSphere3(agent.pos, agentRadius), GridEntCheck.BOUNDING) <| $(eid : EntityId; pos : float3)
        if eid != agent.eid && collides <= 2
          query(eid) <| $ [es] (isAlive : bool; human_net_phys : HumanActor)
            if isAlive
              let radius = determinate_radius(human_net_phys.phys.currentState)
              if distance_sq(agent.pos, pos) <= square(radius + agentRadius)
                let dir = normalize(agent.pos - pos)
                moveDir += dir
                collides ++
    let walkDir = moveDir.xz
    if collides >= 1 && collides <= 2 && length(walkDir) > FLT_EPSILON
      let shootDir = float2(phys.producedCT.wishShootDir.x, phys.producedCT.wishShootDir.z)
      phys.producedCT |> human_control_state_set_world_walk_dir(normalize(walkDir), shootDir)
      phys.producedCT |> human_control_state_set_walk_speed(0.5)
      movingTime += dt
    elif movingTime > 0f
      let wishPos = owner.blackBoard |> datablock_getPoint3(wishPosParam)
      if distance_sq(wishPos, agent.pos) < resetWishPositionThreshold
        owner.blackBoard |> set(wishPosParam, agent.pos)
      phys.producedCT |> human_control_state_set_walk_speed(0f)
      movingTime = 0f

    return movingTime > 0f ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS


def private pick_nav_position(positions : Point3List; from_pos : float3; min_dist_sq : float; closest : bool; round_len : float; def_pos : float3)
  if empty(positions)
    return def_pos
  var points : array<float3>
  for pos in positions
    var waterLevel = 0.0
    let MAX_HEIGHT_UNDERWATER = -0.1
    if traceht_water(pos, waterLevel)
      if waterLevel - pos.y > MAX_HEIGHT_UNDERWATER
        continue
    if distance_sq(from_pos, pos) < min_dist_sq
      continue
    points |> push(pos)
  if empty(points)
    return def_pos
  if !closest
    return points[rnd_int(0, length(points) - 1)]
  var posDist = -1.0
  for pt in points
    let dist = float(int(distance(from_pos, pt) / round_len)) * round_len
    if posDist < 0.0 || dist < posDist
      posDist = dist
  var points2 : array<float3>
  for pt in points
    let dist = float(int(distance(from_pos, pt) / round_len)) * round_len
    if dist == posDist
      points2 |> push(pt)
  if empty(points2)
    return def_pos
  return points[rnd_int(0, length(points) - 1)]


[beh_node(name="updateGoalCapzone")]
class UpdateGoalCapzone : BehNodeAdapter
  outZoneEidParam : int = -1
  enemyAroundParam : int = -1

  outCrowdedParam : int = -1
  crowdedNumSquads : int = 3

  outEnemyParam : int = -1

  MAX_DIST_ENEMY_AROUND = 100.0

  def override loadFromBlk(var data : DataBlock) : void
    outZoneEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outZoneEidParam", ""), 0)
    if datablock_find_param(data, "enemyAroundParam") >= 0
      enemyAroundParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "enemyAroundParam", ""), 0)
    if datablock_find_param(data, "outCrowdedParam") >= 0
      outCrowdedParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outCrowdedParam", ""), 0)
    if datablock_find_param(data, "outEnemyParam") >= 0
      outEnemyParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outEnemyParam", ""), 0)
    crowdedNumSquads = datablock_getInt(data, "crowdedNumSquads", crowdedNumSquads)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var hasAgentInfo = false
    var agentPos = float3()
    var agentTeam = TEAM_UNASSIGNED
    var agentSquad = INVALID_ENTITY_ID
    var agentCapzoneOfInterest = INVALID_ENTITY_ID
    query(agentEid) <| $ [es] (transform : float3x4; team : int; squad_member__squad : EntityId = INVALID_ENTITY_ID)
      hasAgentInfo = true
      agentPos = transform[3]
      agentTeam = team
      agentSquad = squad_member__squad
    if !hasAgentInfo
      return EBehResult.ER_FAILED
    let agentTeamKey = string(agentTeam)
    let enemyTeamKey = string(agentTeam == 1 ? 2 : 1)
    query(agentSquad) <| $ [es] (squad__leader : EntityId)
      query(squad__leader) <| $ [es] (beh_tree__capzoneOfInterest : EntityId)
        agentCapzoneOfInterest = beh_tree__capzoneOfInterest

    let enemyAround = enemyAroundParam < 0 ? false : (owner.blackBoard |> datablock_getInt(enemyAroundParam) > 0)
    let maxEnemyAroundDistSq = enemyAround ? square(MAX_DIST_ENEMY_AROUND) : 0.0

    var bestToCaptureEid = INVALID_ENTITY_ID
    var bestToCaptureCrowd = 0
    var bestToCaptureEnemy = 0
    var bestToCaptureDistSq = -1.0
    var bestToCaptureScore = 0

    var bestToDefendEid = INVALID_ENTITY_ID
    var bestToDefendCrowd = 0
    var bestToDefendEnemy = 0
    var bestToDefendDistSq = -1.0
    var bestToDefendScore = 0

    var mySquadInZoneEid = INVALID_ENTITY_ID

    query() <| $ [es] (eid aka capzone_eid : EntityId; active : bool;
                       capzone__hasNearestNavmeshPos : bool;
                       transform aka capzone_transform : float3x4;
                       capzone__capTeam : int; capzone__progress : float;
                       capzone__owningTeam : int = TEAM_UNASSIGNED;
                       teamPresence : Object)
      if !active || !capzone__hasNearestNavmeshPos
        return
      let distSq = distance_sq(agentPos, capzone_transform[3])
      if enemyAround && distSq > maxEnemyAroundDistSq
        return

      var teamSquadsToZone = 0
      query() <| $ [es] (eid aka squad_eid : EntityId; squad__leader : EntityId)
        if squad_eid != agentSquad
          query(squad__leader) <| $ [es] (beh_tree__capzoneOfInterest : EntityId; team : int)
            if team == agentTeam
              if beh_tree__capzoneOfInterest == capzone_eid
                ++teamSquadsToZone

      var teamMatesInZone = 0
      var teamSquadsInZone = 0
      var mySquadInZone = false
      let agentTeamPresence = teamPresence[agentTeamKey]
      let myTeamInZone = agentTeamPresence != null ? get_ecs_array(agentTeamPresence) : null
      if myTeamInZone != null
        var zoneSquads : table<uint>
        teamMatesInZone = length(*myTeamInZone)
        for teamMate in *myTeamInZone
          query(get_Eid(teamMate) ?? INVALID_ENTITY_ID) <| $ [es] (squad_member__squad : EntityId)
            if squad_member__squad == agentSquad
              mySquadInZone = true
            else
              if !(zoneSquads |> key_exists(uint(squad_member__squad)))
                zoneSquads |> insert(uint(squad_member__squad))
                ++teamSquadsInZone

      if mySquadInZone
        mySquadInZoneEid = capzone_eid

      var enemyMatesInZone = 0
      let enemyTeamPresence = teamPresence[enemyTeamKey]
      let enTeamInZone = enemyTeamPresence != null ? get_ecs_array(enemyTeamPresence) : null
      if enTeamInZone != null
        enemyMatesInZone = length(*enTeamInZone)

      if capzone__owningTeam == agentTeam || is_teams_friendly(capzone__owningTeam, agentTeam)
        var score = 100 - teamSquadsToZone * 10
        if capzone__capTeam != capzone__owningTeam
          score += 50 + int(100.0 * capzone__progress)
        elif mySquadInZone
          score += 50
        score -= teamSquadsInZone * 50
        score += min(0, 300 - enemyMatesInZone * 100)
        score += max(0, int((float(2 - teamMatesInZone) * 50.0 * (square(100.0) * safeinv(distSq)))))

        if !bestToDefendEid || score > bestToDefendScore || (score == bestToDefendScore && distSq < bestToDefendDistSq)
          bestToDefendEid = capzone_eid
          bestToDefendCrowd = mySquadInZone ? (teamSquadsInZone + 1) : 0
          bestToDefendEnemy = enemyMatesInZone
          bestToDefendDistSq = distSq
          bestToDefendScore = score
      else
        var score = 100 - teamSquadsToZone * 50
        if capzone__capTeam != agentTeam
          score += max(0, int((float(2 - enemyMatesInZone) * 150.0 * (square(100.0) * safeinv(distSq)))))
          score += int(100.0 * (1.0 - capzone__progress))
        else
          score += int(100.0 * capzone__progress)
        if mySquadInZone
          score += 500

        if agentCapzoneOfInterest == capzone_eid
          score = (score * 37) / 20

        if !bestToCaptureEid || score > bestToCaptureScore || (score == bestToCaptureScore && distSq < bestToCaptureDistSq)
          bestToCaptureEid = capzone_eid
          bestToCaptureCrowd = mySquadInZone ? (teamSquadsInZone + 1) : 0
          bestToCaptureEnemy = enemyMatesInZone
          bestToCaptureDistSq = distSq
          bestToCaptureScore = score

    var resultEid = INVALID_ENTITY_ID
    var resultCrowd = 0
    var resultEnemy = 0
    if bestToCaptureEid != INVALID_ENTITY_ID && (bestToDefendEid == INVALID_ENTITY_ID || bestToCaptureScore >= bestToDefendScore)
      resultEid = bestToCaptureEid
      resultCrowd = bestToCaptureCrowd
      resultEnemy = bestToCaptureEnemy
    elif bestToDefendEid != INVALID_ENTITY_ID
      resultEid = bestToDefendEid
      resultCrowd = bestToDefendCrowd
      resultEnemy = bestToDefendEnemy

    owner.blackBoard |> set(outZoneEidParam, int(uint(resultEid)))
    if outCrowdedParam >= 0
      owner.blackBoard |> set(outCrowdedParam, resultCrowd >= 2 ? 1 : 0)
    if outEnemyParam >= 0
      owner.blackBoard |> set(outEnemyParam, resultEnemy > 0 ? 1 : 0)
    return resultEid != INVALID_ENTITY_ID ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="shouldSquadStayAtCapzone")]
class ShouldSquadStayAtCapzone : BehNodeAdapter
  zoneEidParam : int = -1
  MAX_DISTANCE_TO_STAY : float = 100.0
  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "zoneEidParam") >= 0
      zoneEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "zoneEidParam", ""), 0)
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let zoneEid = zoneEidParam >= 0 ? EntityId(uint(owner.blackBoard |> datablock_getInt(zoneEidParam))) : INVALID_ENTITY_ID
    var result = false
    query(agentEid) <| $ [es] (transform aka agent_transform : float3x4; squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (var squadAI_tactical__stayEid : EntityId&;
                                            var squadAI_tactical__stayTime : float2&;
                                            squadAI_tactical__stayMaxTime : float2)
        query(zoneEid) <| $ [es] (active : bool; transform aka capzone_transform : float3x4)
          if !active || distance_sq(agent_transform[3], capzone_transform[3]) > square(MAX_DISTANCE_TO_STAY)
            squadAI_tactical__stayEid = INVALID_ENTITY_ID
            squadAI_tactical__stayTime = float2()
            return
          let curTime = get_sync_time()
          if squadAI_tactical__stayEid != zoneEid
            squadAI_tactical__stayEid = zoneEid
            squadAI_tactical__stayTime.x = curTime
            squadAI_tactical__stayTime.y = squadAI_tactical__stayTime.x + rnd_float(squadAI_tactical__stayMaxTime)
            result = true
          else
            if curTime < squadAI_tactical__stayTime.y
              result = true
            else
              squadAI_tactical__stayEid = INVALID_ENTITY_ID
              squadAI_tactical__stayTime = float2()
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="setCapzoneOfInterest")]
class SetCapzoneOfInterest : BehNodeAdapter
  zoneEidParam : int = -1
  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "zoneEidParam") >= 0
      zoneEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "zoneEidParam", ""), 0)
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let zoneEid = zoneEidParam >= 0 ? EntityId(uint(owner.blackBoard |> datablock_getInt(zoneEidParam))) : INVALID_ENTITY_ID
    query(agentEid) <| $ [es] (var beh_tree__capzoneOfInterest : EntityId&)
      beh_tree__capzoneOfInterest = zoneEid
    return EBehResult.ER_SUCCESS

[beh_node(name="getCapzonePoint")]
class GetCapzonePoint : BehNodeAdapter
  outPosParam : int = -1
  zoneEidParam : int = -1
  insideCapzone : bool = false

  closestPoint : bool = true
  closestRoundLen : float = 5.0

  minDistSq : float = 0.0
  minDistChance : float = 1.0

  def override loadFromBlk(var data : DataBlock) : void
    outPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3())
    zoneEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "zoneEidParam", ""), 0)
    insideCapzone = datablock_getBool(data, "insideCapzone", insideCapzone)

    closestPoint = datablock_getBool(data, "closestPoint", closestPoint)
    closestRoundLen = datablock_getReal(data, "closestRoundLen", closestRoundLen)

    minDistSq = square(datablock_getReal(data, "minDist", 0.0))
    minDistChance = datablock_getReal(data, "minDistChance", minDistChance)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let zoneEid = EntityId(uint(owner.blackBoard |> datablock_getInt(zoneEidParam)))

    var gotPoint = false
    var pointPos = float3()

    var agentPos = float3()
    var hasAgentPos = false
    query(agentEid) <| $ [es] (transform : float3x4)
      agentPos = transform[3]
      hasAgentPos = true

    let allowNearDist = minDistChance >= 1.0 || rnd_float(0.0, 1.0) < minDistChance
    let minDistSqAllowed = allowNearDist ? minDistSq : 0.0

    if hasAgentPos
      if insideCapzone
        query(zoneEid) <| $ [es] (transform aka capzone_transform : float3x4; capzone__insideNavmeshPositions : Point3List)
          pointPos = pick_nav_position(capzone__insideNavmeshPositions, agentPos, minDistSqAllowed, closestPoint, closestRoundLen, capzone_transform[3])
          gotPoint = true
      else
        query(zoneEid) <| $ [es] (transform aka capzone_transform : float3x4; capzone__outsideNavmeshPositions : Point3List)
          pointPos = pick_nav_position(capzone__outsideNavmeshPositions, agentPos, minDistSqAllowed, closestPoint, closestRoundLen, capzone_transform[3])
          gotPoint = true

    if gotPoint
      owner.blackBoard |> set(outPosParam, pointPos)
    return gotPoint ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="getCapzoneInfo")]
class GetCapzoneInfo : BehNodeAdapter
  zoneEidParam : int = -1
  outAgentInsideParam : int = -1
  outToDefendParam : int = -1

  MIN_TIME_TO_DEFEND_EVERYTHING_SINCE_MISSION_START : float = 30.0

  def override loadFromBlk(var data : DataBlock) : void
    zoneEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "zoneEidParam", ""), 0)
    if datablock_find_param(data, "outAgentInside") >= 0
      outAgentInsideParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outAgentInside", ""), 0)
    if datablock_find_param(data, "outToDefend") >= 0
      outToDefendParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outToDefend", ""), 0)

  def override update(dt : float) : EBehResult
    var result = false
    var agentInside = false
    var toDefend = false

    let agentEid = beh_tree_eid(owner)
    let zoneEid = EntityId(uint(owner.blackBoard |> datablock_getInt(zoneEidParam)))

    query(agentEid) <| $ [es] (transform aka agent_transform : float3x4; team aka agent_team : int)
      query(zoneEid) <| $ [es] (active : bool; capzone__progress : float; capzone__capTeam : int;
                                capzone__owningTeam : int = TEAM_UNASSIGNED;
                                capzone__hasNearestNavmeshPos : bool; transform aka capzone_transform : float3x4;
                                capzone__approximateRadius = -1.0; sphere_zone__radius = 0.0)
        if !active || !capzone__hasNearestNavmeshPos
          return
        agentInside = is_pos_inside_capture_point(agent_transform[3], 0.0, capzone_transform, capzone__approximateRadius, sphere_zone__radius)
        let TO_DEFEND_CAPTURE_PROGRESS = 0.8
        let captured = (abs(1. - capzone__progress) <= TO_DEFEND_CAPTURE_PROGRESS && capzone__capTeam == agent_team) || capzone__owningTeam == agent_team
        if captured || get_sync_time() < MIN_TIME_TO_DEFEND_EVERYTHING_SINCE_MISSION_START
          toDefend = true
          result = true

    if outAgentInsideParam >= 0
      owner.blackBoard |> set(outAgentInsideParam, agentInside ? 1 : 0)
    if outToDefendParam >= 0
      owner.blackBoard |> set(outToDefendParam, toDefend ? 1 : 0)
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="shouldFocusOnCapZones")]
class ShouldFocusOnCapZones : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var result = false
    query(beh_tree_eid(owner)) <| $ [es] (team aka agent_team : int)
      if agent_team == TEAM_UNASSIGNED
        return
      find_query() <| $ [es(REQUIRE=capzone__progress)] (active : bool;
                                                         capzone__hasNearestNavmeshPos : bool;
                                                         capzone__owningTeam : int = TEAM_UNASSIGNED;
                                                         capzone__capTeam : int = TEAM_UNASSIGNED)
        if !active || !capzone__hasNearestNavmeshPos
          return false
        let isOwnedByTeamOrAlly = capzone__owningTeam == agent_team || is_teams_friendly(capzone__owningTeam, agent_team)
        let beingCapturedByEnemy = capzone__capTeam != agent_team || !is_teams_friendly(capzone__capTeam, agent_team)
        if !isOwnedByTeamOrAlly || beingCapturedByEnemy
          result = true
          return true
        return false
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="findEnemyAttackDirPos")]
class FindEnemyAttackDirPos : BehNodeAdapter
  outPosParam : int = -1
  randomizeRadius : float = 30.0
  minDist : float = 20.0

  def override loadFromBlk(var data : DataBlock)
    outPosParam  = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3())
    randomizeRadius = datablock_getReal(data, "randomizeRadius", randomizeRadius)

  def override update(dt : float) : EBehResult
    var result = false
    var resultPos = float3()
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (team aka agent_team : int; transform aka agent_transform : float3x4)
      if agent_team == TEAM_UNASSIGNED
        return

      let minDistSq = square(minDist)
      var dangerPos : array<float3>
      query() <| $ [es] (squad__leader : EntityId)
        query(squad__leader) <| $ [es] (transform aka that_transform : float3x4; team : int)
          if team != agent_team && distance_sq(agent_transform[3], that_transform[3]) > minDistSq
            dangerPos |> push(that_transform[3])

      let numPos = length(dangerPos)
      if numPos == 1
        resultPos = dangerPos[0]
        result = true
      elif numPos > 0
        let dangerIdx = rnd_int(0, numPos - 1)
        resultPos = dangerPos[dangerIdx]
        result = true
      if result
        let ofs = rnd_float(-randomizeRadius, randomizeRadius)
        let dir = normalize(resultPos - agent_transform[3])
        resultPos.x += dir.z * ofs
        resultPos.y = (resultPos.y * 0.3 + agent_transform[3].y * 0.7)
        resultPos.z -= dir.x * ofs
        owner.blackBoard |> set(outPosParam, resultPos)
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

def private find_path_full(from_pos : float3; to_pos : float3; extents : float3; step_size : float; path_slope : float;
                           reach_dist : float; reach_height : float; thru_blocked : bool; custom_nav : CustomNav const?; var out_path : array<float3>&)
  let reachDistSq = square(reach_dist)
  let maxPartial = 5
  var fromPt = from_pos
  var found = false

  let RESERVE_PATH_LEN = 64
  clear(out_path)
  var partPath : array<float3>
  out_path |> reserve(RESERVE_PATH_LEN)
  partPath |> reserve(RESERVE_PATH_LEN)

  for _i in range(maxPartial)
    clear(partPath)
    var result = FindPathResult.FPR_FAILED
    if thru_blocked
      result = find_any_path(fromPt, to_pos, extents, step_size, path_slope, custom_nav) <| $(path)
        partPath := path
    else
      result = find_path(fromPt, to_pos, extents, step_size, path_slope, custom_nav) <| $(path)
        partPath := path

    let len = length(partPath)
    if result == FindPathResult.FPR_FAILED || len <= 1
      return false

    let reached = distance_sq(to_pos.xz, partPath[len - 1].xz) < reachDistSq && abs(to_pos.y - partPath[len - 1].y) < reach_height
    if reached && result == FindPathResult.FPR_FULL
      for i in range(0, len)
        let partPos = partPath[i]
        if empty(out_path) || out_path[length(out_path) - 1] != partPos
          push(out_path, partPos)
      found = true
      break

    let keep = len * 3 / 4
    fromPt = partPath[keep]
    for i in range(0, keep + 1)
      let partPos = partPath[i]
      if empty(out_path) || out_path[length(out_path) - 1] != partPos
        push(out_path, partPos)

  return found


def private is_point_safe_from_enemies(pos : float3; agent_eid : EntityId; agent_team_id : int; check_seen_by_enemy_ai : bool)
  if !is_point_safe(pos, agent_team_id)
    return false
  if check_seen_by_enemy_ai
    let seen = find_query() <| $ [es] (agent_dangers : AgentDangers; team : int;
                                       isAlive : bool = true; isDowned : bool = false)
      if team == agent_team_id || !isAlive || isDowned
        return false
      for i in iter_range(agent_dangers.dangers)
        assume danger = agent_dangers.dangers[i]
        if danger.eid == agent_eid && danger.traceable
          return true
      return false
    if seen
      return false
  return true

[beh_node(name="isPointSafe")]
class IsPointSafe : BehNodeAdapter
  posParam : int = -1
  checkSeenByEnemyAI : bool = false

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    checkSeenByEnemyAI = datablock_getBool(data, "checkSeenByEnemyAI", checkSeenByEnemyAI)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    let pos = owner.blackBoard |> datablock_getPoint3(posParam)
    if !is_point_safe_from_enemies(pos, agent.eid, agent.teamId, checkSeenByEnemyAI)
      return EBehResult.ER_FAILED
    return EBehResult.ER_SUCCESS


def private find_blocker_entity_at_pos(pos : float3)
  var foundEid = INVALID_ENTITY_ID
  let found = find_query() <| $ [es(REQUIRE=destroyable_wall)] (eid : EntityId; ri_extra : RiExtraComponent)
    if !ri_extra.valid
      return false
    let riType = handle_to_ri_type(ri_extra.handle)
    let bb = riex_get_lbb(int(riType))
    let bb3 = BBox3(bb.bmin.xyz, bb.bmax.xyz)
    var tm : float3x4
    get_rigen_extra_matrix(ri_extra.handle, tm)
    let aabb = tm * bb3
    if !(aabb & pos)
      return false
    foundEid = eid
    return true
  return foundEid

[beh_node(name="findBlockerEntityAtPos")]
class FindBlockerEntityAtPos : BehNodeAdapter
  posParam : int = -1
  outEidParam : int = -1

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    outEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outEidParam", ""), 0)

  def override update(dt : float) : EBehResult
    let pos = owner.blackBoard |> datablock_getPoint3(posParam)
    let foundEid = find_blocker_entity_at_pos(pos)
    let found = foundEid != INVALID_ENTITY_ID
    if found
      owner.blackBoard |> set(outEidParam, int(uint(foundEid)))
    return found ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


def private get_entity_destr_wall_plant_mine_pos(agent_eid : EntityId; destr_wall_eid : EntityId;
                                                 check_agent_has_bomb : bool; var out_plantPos : float3&)
  var result = false
  query(destr_wall_eid) <| $ [es(REQUIRE=destroyable_wall)] (transform : float3x4)
    var agentPos = float3()
    var agentHasWallBomb = false
    var agentOK = false
    query(agent_eid) <| $ [es] (transform : float3x4; itemContainer : EidList const?)
      agentPos = transform[3]
      if check_agent_has_bomb && itemContainer != null
        for item in *itemContainer
          let itemGrenadeType = get_ecs_string(item, "item__grenadeType")
          if itemGrenadeType != null && *itemGrenadeType == "wall_bomb"
            agentHasWallBomb = true
      agentOK = true
    if agentOK && (!check_agent_has_bomb || agentHasWallBomb)
      let dirToAgent = normalize(x0z(transform[3] - agentPos))
      let OFFS_UP_WARDS = 0.5
      let OFFS_TO_AGENT = 0.3
      out_plantPos = transform[3] + float3(0.0, OFFS_UP_WARDS, 0.0) + dirToAgent * OFFS_TO_AGENT
      result = true
  return result

[beh_node(name="checkEntityDestrWall")]
class CheckEntityDestrWall : BehNodeAdapter
  eidParam : int = -1
  checkAgentHasBomb : bool = true
  outPlantPosParam : int = -1

  def override loadFromBlk(var data : DataBlock)
    eidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "eidParam", ""), 0)
    checkAgentHasBomb = datablock_getBool(data, "checkAgentHasBomb", checkAgentHasBomb)
    outPlantPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPlantPosParam", ""), float3())

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let entityEid = EntityId(uint(owner.blackBoard |> datablock_getInt(eidParam)))
    var plantPos = float3()
    if !get_entity_destr_wall_plant_mine_pos(agentEid, entityEid, checkAgentHasBomb, plantPos)
      return EBehResult.ER_FAILED
    owner.blackBoard |> set(outPlantPosParam, plantPos)
    return EBehResult.ER_SUCCESS


[beh_node(name="checkPlantWallMine")]
class CheckPlantWallMine : BehNodeAdapter
  eidParam : int = -1
  outPosParam : int = -1
  outNormParam : int = -1

  def override loadFromBlk(var data : DataBlock)
    eidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "eidParam", ""), 0)
    if datablock_find_param(data, "outPosParam") >= 0
      outPosParam  = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3())
    if datablock_find_param(data, "outNormParam") >= 0
      outNormParam  = owner.blackBoard |> get_or_create(datablock_getStr(data, "outNormParam", ""), float3())

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let entityEid = EntityId(uint(owner.blackBoard |> datablock_getInt(eidParam)))
    var foundPos = false
    var pos : float3
    var norm : float3
    query(agentEid) <| $ [es] (human__aimTm : float3x4;
                               human_mining_wall__plantingMaxDist : float;
                               human_mining_wall__bufferDistance : float;
                               human_mining_wall__plantingPosDistFromWall : float)
      let traceStart = human__aimTm[3] - human__aimTm[0] * 0.3
      let traceDir = normalize(human__aimTm[0] + float3(0.0, -0.3, 0.0))
      var t = human_mining_wall__plantingMaxDist + human_mining_wall__bufferDistance
      var pmid = -1
      var riDesc = RendInstDesc()
      if traceray_normalized(traceStart, traceDir, t, pmid, norm, ETF_RI, riDesc, -1) && riDesc.isValid
        let aimedAtEid = find_ri_extra_eid(riDesc.riExtraHandle)
        if aimedAtEid == entityEid
          foundPos = true
          pos = traceStart + traceDir * (t - human_mining_wall__plantingPosDistFromWall)
    if !foundPos
      return EBehResult.ER_FAILED

    if outPosParam >= 0
      owner.blackBoard |> set(outPosParam, pos)
    if outNormParam >= 0
      owner.blackBoard |> set(outNormParam, norm)
    return EBehResult.ER_SUCCESS

[beh_node(name="plantWallMine")]
class PlantWallMine : BehNodeAdapter
  eidParam : int = -1
  posParam : int = -1
  normParam : int = -1

  timer : float = -1.0
  ensureOverTime : float = 0.25

  def override loadFromBlk(var data : DataBlock)
    eidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "eidParam", ""), 0)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    normParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "normParam", ""), float3())

  def override init()
    let agentEid = beh_tree_eid(owner)
    timer = get_float(agentEid, "human_mining_wall__plantingDuration") ?? 2.0
    timer += ensureOverTime

    let entityEid = EntityId(uint(owner.blackBoard |> datablock_getInt(eidParam)))
    let pos = owner.blackBoard |> datablock_getPoint3(posParam)
    let norm = owner.blackBoard |> datablock_getPoint3(normParam)

    send_net_event(agentEid, CmdStartPlantingMineOnWall(pos = pos, norm = norm, wallEid = entityEid))

  def override update(dt : float) : EBehResult
    timer -= dt
    if timer > 0.0
      return EBehResult.ER_RUNNING
    return EBehResult.ER_SUCCESS


[beh_node(name="initPeriodicTimer")]
class InitPeriodicTimer : BehNodeAdapter
  timeParam : int = -1
  timePeriod : float2 = float2(2.5, 5.)

  def override loadFromBlk(var data : DataBlock)
    timeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "timeParam", "time"), 0.)

    timePeriod = datablock_getPoint2(data, "timePeriod", float2(2.5, 5.))

  def override update(dt : float) : EBehResult
    owner.blackBoard |> set(timeParam, get_sync_time() + rnd_float(timePeriod.x, timePeriod.y))
    return EBehResult.ER_SUCCESS

[beh_node(name="periodicTimer")]
class PeriodicTimer : BehNodeAdapter
  timeParam : int = -1

  timePeriod : float2 = float2(2.5, 5.)

  def override loadFromBlk(var data : DataBlock)
    timeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "timeParam", "time"), 0.)

    timePeriod = datablock_getPoint2(data, "timePeriod", float2(2.5, 5.))

  def override update(dt : float) : EBehResult
    let prevTime = owner.blackBoard |> datablock_getReal(timeParam)

    let curTime = get_sync_time()

    if prevTime - curTime <= 0.
      owner.blackBoard |> set(timeParam, curTime + rnd_float(timePeriod.x, timePeriod.y))
      return EBehResult.ER_SUCCESS

    return EBehResult.ER_FAILED


[beh_node(name="deactivateWeapMod")]
class DeactivateWeapModNode : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (human_weap__currentGunSlot : int; human_weap__gunMods : Array)
      if human_weap__currentGunSlot < 0
        return
      let gunModEids = get_ecs_EidList(human_weap__gunMods[human_weap__currentGunSlot])
      for gunMod in *gunModEids
        query(gunMod) <| $ [es] (weapon_mod__active : bool)
          if weapon_mod__active
            sendEvent(eid, CmdWeapModActivate(slotId = human_weap__currentGunSlot, activate = false))
    return EBehResult.ER_SUCCESS


[beh_node(name="shouldEquipBuildTool")]
class ShouldEquipBuildTool : BehNodeAdapter
  targetEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", "targetParam"), 0)

  def override update(dt : float) : EBehResult
    let target = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    return has(target, "builder_preview") ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="interactWithBuildingTarget")]
class InteractWithBuildingTarget : BehNodeAdapter
  targetEidParam : int = -1
  syncDelayExtraTime : float = 0.5
  endAtTimeLimit : float = -1.0

  def override loadFromBlk(var data : DataBlock) : void
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", "targetUnitParam"), 0)
    syncDelayExtraTime = datablock_getReal(data, "syncDelayExtraTime", syncDelayExtraTime)

  def override init()
    endAtTimeLimit = -1.0

  def override exit()
    var agent = beh_tree_entity_agent(*owner)
    var phys = agent.phys
    if phys != null
      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, false)
    send_net_event(agent.eid, EventSetBuildingTarget(target = INVALID_ENTITY_ID))

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED
    var phys = agent.phys
    if phys == null
      return EBehResult.ER_SUCCESS
    let target = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    if !target
      return EBehResult.ER_SUCCESS
    if endAtTimeLimit < 0.0
      let maxInteractTime = get_float(target, "building_builder__maxTimeToBuild") ?? get_float(target, "building_destroy__maxTimeToDestroy") ?? 0.0
      endAtTimeLimit = get_sync_time() + maxInteractTime + syncDelayExtraTime

    let weapon = get_Eid(agent.eid, "human_weap__currentGunEid") ?? INVALID_ENTITY_ID
    let buildingToolSelected = has(weapon, "buildingTool")
    if buildingToolSelected
      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, true)

    if get_Eid(agent.eid, "building_action__target") ?? INVALID_ENTITY_ID != target
      if has(target, "builder_server_preview")
        if !buildingToolSelected
          return EBehResult.ER_SUCCESS 
        send_net_event(agent.eid, EventSetBuildingTarget(target = target))
      else
        send_net_event(agent.eid, EventDismantleBuilding(target = target))

    return endAtTimeLimit < get_sync_time() ? EBehResult.ER_SUCCESS : EBehResult.ER_RUNNING


def add_to_set(var set : int&; index : int)
  set |= (1 << index)

def remove_from_set(var set : int&; index : int)
  set &= ~(1 << index)

def is_in_set(set : int; index : int)
  return (set & (1 << index)) != 0


let
  SEAT_DRIVER = 0
  SEAT_MAIN_GUNNER = 1
  SEAT_LOADER = 2
  SEAT_COMMANDER = 3
  SEAT_EXTRA_GUNNER = 4
  SEAT_PLAYER_SWAP = 5

struct AgentSeatSkills
  found : bool
  driverScore : float
  gunnerScore : float
  loaderScore : float

def get_agent_seat_skills(agent_eid : EntityId) : AgentSeatSkills
  var skills : AgentSeatSkills
  query(agent_eid) <| $ [es] (driver_skills__brakingTauMult : float = 1.0;
                              driver_skills__gearChangeTimeMult : float = 1.0;
                              driver_skills__drivingSpeedThresholdMult : float = 1.0;
                              entity_mods__turretPitchMultWhenAimingYaw : float = 0.0;
                              entity_mods__canChangeShellDuringVehicleGunReload : bool = false;
                              entity_mods__vehicleReloadMult : float = 1.0)
    skills.found = true
    skills.driverScore = cvt(driver_skills__brakingTauMult * driver_skills__gearChangeTimeMult * driver_skills__drivingSpeedThresholdMult, 1.0, 0.0, 0.0, 0.9)
    skills.gunnerScore = cvt(entity_mods__turretPitchMultWhenAimingYaw, 0.0, 10.0, 0.0, 0.9)
    skills.loaderScore = cvt(entity_mods__vehicleReloadMult * (entity_mods__canChangeShellDuringVehicleGunReload ? 0.5 : 1.0), 1.0, 0.0, 0.0, 0.9)
  return skills









































def calc_ordered_score(score1 : float; score2 : float)
  if score2 > 0.0
    return 0.5 + score2 * 0.5
  elif score1 > 0.0
    return score1 * 0.5
  return 0.0

def get_seat_priority(seat_mask : int; agent_skills : AgentSeatSkills)
  if is_in_set(seat_mask, SEAT_DRIVER)
    return 6.0 + agent_skills.driverScore - calc_ordered_score(agent_skills.gunnerScore, agent_skills.loaderScore) * 0.05
  if is_in_set(seat_mask, SEAT_MAIN_GUNNER)
    return 5.0 + agent_skills.gunnerScore - calc_ordered_score(agent_skills.loaderScore, agent_skills.driverScore) * 0.05
  if is_in_set(seat_mask, SEAT_LOADER)
    return 4.0 + agent_skills.loaderScore - calc_ordered_score(agent_skills.gunnerScore, agent_skills.driverScore) * 0.05
  if is_in_set(seat_mask, SEAT_COMMANDER)
    return 3.0
  if is_in_set(seat_mask, SEAT_EXTRA_GUNNER)
    return 2.0 + agent_skills.gunnerScore - calc_ordered_score(agent_skills.loaderScore, agent_skills.driverScore) * 0.05
  if is_in_set(seat_mask, SEAT_PLAYER_SWAP)
    return 1.0
  return 0.0




























































































































































[beh_node(name="findNearestActiveBombSiteForPlanting")]
class FindNearestActiveBombSiteForPlanting : BehNodeAdapter
  bombSitePosParam : int = -1
  bombSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    bombSitePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSitePosParam", "bombSitePos"), agent.pos)
    bombSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    var bombSiteInRadiusDistSqr = 0.

    query(agent.eid) <| $ [es] (beh_tree__bombSiteInRadiusDistSqr : float)
      bombSiteInRadiusDistSqr = beh_tree__bombSiteInRadiusDistSqr

    let found = find_query() <| $ [es] (eid : EntityId;
                                        active : bool;
                                        transform : float3x4;
                                        bomb_site__plantingTeam : int;
                                        bomb_site__isPlantingOrReseting : bool;
                                        bomb_site__isBombPlanted : bool)
      if (active && agent.teamId == bomb_site__plantingTeam &&
         !bomb_site__isPlantingOrReseting && !bomb_site__isBombPlanted)
        let isNearBombSite = distance_sq(agent.pos, transform[3]) < bombSiteInRadiusDistSqr
        if isNearBombSite
          owner.blackBoard |> set(bombSitePosParam, transform[3])
          owner.blackBoard |> set(bombSiteEidParam, int(uint(eid)))
          return true
      return false

    return found ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="findNearestActiveBombSiteForDefusing")]
class FindNearestActiveBombSiteForDefusing : BehNodeAdapter
  bombSitePosParam : int = -1
  bombSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    bombSitePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSitePosParam", "bombSitePos"), agent.pos)
    bombSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    var bombSiteInRadiusDistSqr = 0.

    query(agent.eid) <| $ [es] (beh_tree__bombSiteInRadiusDistSqr : float)
      bombSiteInRadiusDistSqr = beh_tree__bombSiteInRadiusDistSqr

    let found = find_query() <| $ [es] (eid : EntityId;
                                        active : bool;
                                        transform : float3x4;
                                        bomb_site__plantingTeam : int;
                                        bomb_site__isDefusing : bool;
                                        bomb_site__isBombPlanted : bool)
      if (active && agent.teamId != bomb_site__plantingTeam &&
          bomb_site__isBombPlanted && !bomb_site__isDefusing)
        let isNearBombSite = distance_sq(agent.pos, transform[3]) < bombSiteInRadiusDistSqr
        if isNearBombSite
          owner.blackBoard |> set(bombSitePosParam, transform[3])
          owner.blackBoard |> set(bombSiteEidParam, int(uint(eid)))
          return true
      return false

    return found ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="checkPlantBombOrder")]
class CheckPlantBombOrder : BehNodeAdapter
  bombSitePosParam : int = -1
  bombSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (transform : float3x4)
      bombSitePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSitePosParam", "bombSitePos"), transform[3])
    bombSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)

    var hasPlantBombOrder = false

    query(agentEid) <| $ [es] (squad_member__orderType : int;
                               squad_member__orderPosition : float3;
                               squad_member__orderUseEntity : EntityId)
      if squad_member__orderType == int(SquadMateOrder.ESMO_PLANT_BOMB)
        owner.blackBoard |> set(bombSitePosParam, squad_member__orderPosition)
        owner.blackBoard |> set(bombSiteEidParam, int(uint(squad_member__orderUseEntity)))
        hasPlantBombOrder = true

    return hasPlantBombOrder ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="checkDefuseBombOrder")]
class CheckDefuseBombOrder : BehNodeAdapter
  bombSitePosParam : int = -1
  bombSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    bombSitePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSitePosParam", "bombSitePos"), agent.pos)
    bombSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    var hasDefuseBombOrder = false

    query(agent.eid) <| $ [es] (squad_member__orderType : int;
                                squad_member__orderPosition : float3;
                                squad_member__orderUseEntity : EntityId)
      if squad_member__orderType == int(SquadMateOrder.ESMO_DEFUSE_BOMB)
        owner.blackBoard |> set(bombSitePosParam, squad_member__orderPosition)
        owner.blackBoard |> set(bombSiteEidParam, int(uint(squad_member__orderUseEntity)))
        hasDefuseBombOrder = true

    return hasDefuseBombOrder ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
































































[beh_node(name="findPotentialEnemyDirectionEntryPoint")]
class FindPotentialEnemyDirectionEntryPoint : BehNodeAdapter
  posParam : int = -1
  minCoverHeight : float = 1.
  lookDist : float = 5.0

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "potentialEnemyPos"), float3())
    minCoverHeight = owner.blackBoard |> datablock_getReal("minCoverHeight", 1.f)

    let agentEid = beh_tree_eid(owner)
    if !(query(agentEid) <| $ [es(REQUIRE=(isAlive, isDowned,
                                                      cover_updater__heldCovers,
                                                      transform))] {})
      logerr("{agentEid}: <{getEntityTemplateName(agentEid)}> findPotentialEnemyDirectionEntryPoint requires agent.isAlive,\
        agent.isDowned, agent.cover_updater__heldCovers and agent.transform fields")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (isAlive : bool;
                                          isDowned : bool;
                                          cover_updater__heldCovers : IPoint2List;
                                          transform : float3x4)
      let isValidAgentState = isAlive && !isDowned

      if isValidAgentState && length(cover_updater__heldCovers) != 0
        let heldCoverId = cover_updater__heldCovers[0].x

        var isCoverNearWall = false
        query() <| $ [es] (covers : CoversComponent)
          isCoverNearWall = covers.list[heldCoverId].hLeft >= minCoverHeight && covers.list[heldCoverId].hRight >= minCoverHeight

        if isCoverNearWall && posParam != -1
          let to = owner.blackBoard |> datablock_getPoint3(posParam)

          let extents = float3(0.5, FLT_MAX, 0.5)
          find_path(transform[3], to, extents, 1.0, 1.0, null) <| $(data)
            if length(data) > 1
              let dir = transform[3] + normalize(data[1] - transform[3]) * lookDist
              owner.blackBoard |> set(posParam, dir)
              res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="findMoveToPointLookPos")]
class FindMoveToPointLookPos : BehNodeAdapter
  outLookPosParam : int = -1
  moveToPosParam : int = -1
  stepIndex : int = 2
  lookDist : float = 5.0

  def override loadFromBlk(var data : DataBlock) : void
    outLookPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outLookPosParam", ""), float3())
    moveToPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "moveToPosParam", ""), float3())
    stepIndex = owner.blackBoard |> datablock_getInt("stepIndex", stepIndex)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (isAlive : bool;
                                          isDowned : bool;
                                          transform : float3x4)
      if !isAlive || isDowned
        return

      let to = owner.blackBoard |> datablock_getPoint3(moveToPosParam)

      let extents = float3(0.5, FLT_MAX, 0.5)
      find_path(transform[3], to, extents, 1.0, 1.0, null) <| $(data)
        let numSteps = length(data)
        if numSteps > 1 && numSteps > stepIndex
          let idx = clamp(stepIndex, 1, numSteps - 1)
          let lookPos = transform[3] + normalize(data[idx] - transform[3]) * lookDist
          owner.blackBoard |> set(outLookPosParam, lookPos)
          res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="getRandomPointNearTarget")]
class GetRandomPointNearTarget : BehNodeAdapter
  posParam : int = -1
  targetUnitParam : int = -1

  accuracyCoef : float = 1.0
  minDistance : float = 0.1

  distToTargetRangeX : float2 = float2(0.4f, 0.8f)
  distToTargetRangeY : float2 = float2(0.1f, 0.2f)

  minHeightDiff : float = 1.5

  useGenerationByXZ : bool = true
  useGenerationByY : bool = true

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))

    targetUnitParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0)

    accuracyCoef = datablock_getReal(data, "accuracyCoef", accuracyCoef)

    distToTargetRangeX *= accuracyCoef
    distToTargetRangeY *= accuracyCoef

    useGenerationByXZ = datablock_getBool(data, "useGenerationByXZ", true)
    useGenerationByY = datablock_getBool(data, "useGenerationByY", true)

    minHeightDiff = datablock_getReal(data, "minHeightDiff", 1.5)

    query(beh_tree_eid(owner)) <| $ [es] (walker_agent__distToTargetRandomX : float2;
                                          walker_agent__distToTargetRandomY : float2)
      distToTargetRangeX = walker_agent__distToTargetRandomX * accuracyCoef
      distToTargetRangeY = walker_agent__distToTargetRandomY * accuracyCoef

  def override update(dt : float) : EBehResult
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetUnitParam)))
    if targetEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    var hasPos = false
    var pos = float3()
    query(targetEid) <| $ [es] (ai_target : Target)
      pos = ai_target.targetPos
      hasPos = true

    let agentEid = beh_tree_eid(owner)
    var hasAgent = false
    var agentShootPos = float3()
    var agentCurrDir = float3()
    query(agentEid) <| $ [es] (agent_dangers__standShootPos : float3; transform : float3x4)
      agentShootPos = agent_dangers__standShootPos
      agentCurrDir = transform[0]
      hasAgent = true

    if !hasPos || !hasAgent
      return EBehResult.ER_FAILED

    var dirToTarget = pos - agentShootPos
    if length_sq(dirToTarget) < square(minDistance)
      return EBehResult.ER_FAILED

    dirToTarget = normalize(dirToTarget)
    let multByAngle = 1.0 - (dot(agentCurrDir, dirToTarget) + 1.0) * 0.5

    if useGenerationByXZ
      let dirToRight = float3(dirToTarget.z, 0.0, -dirToTarget.x)
      let rndDistX = rnd_float(distToTargetRangeX.x, distToTargetRangeX.y)
      let sign = rnd_int(0, 99) < 50 ? 1.0 : -1.0
      pos += dirToRight * sign * rndDistX * multByAngle

    if useGenerationByY
      let rndDistY = rnd_float(distToTargetRangeY.x, distToTargetRangeY.y)
      if pos.y - agentShootPos.y >= minHeightDiff && rnd_int(0, 99) < 50
        pos.y -= rndDistY * multByAngle
      else
        pos.y += rndDistY * multByAngle

    owner.blackBoard |> set(posParam, pos)
    return EBehResult.ER_SUCCESS


[beh_node(name="getRandomPointAroundTarget")]
class GetRandomPointAroundTarget : BehNodeAdapter
  posParam : int = -1
  targetUnitId : int = -1
  targetUnitParam : int = -1
  radiusRange : float2 = float2(1.0)
  awayMinRadius : float = 5.0
  minDistanceFromAllies : float = 0.0
  minDistanceFromAlliesSq : float = 0.0
  maxTries : int = 10

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))
    targetUnitParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0)
    radiusRange = data |> datablock_getPoint2("radiusRange", radiusRange)
    awayMinRadius = data |> datablock_getReal("awayMinRadius", awayMinRadius)
    minDistanceFromAllies = data |> datablock_getReal("minDistanceFromAllies", minDistanceFromAllies)
    minDistanceFromAlliesSq = square(minDistanceFromAllies)
    maxTries = data |> datablock_getInt("maxTries", maxTries)

  def override init()
    targetUnitId = owner.blackBoard |> datablock_getInt(targetUnitParam)

  def override update(dt : float) : EBehResult
    if targetUnitId == 0
      return EBehResult.ER_FAILED

    var targetPos = float3()
    var hasTargetPos = false
    query(EntityId(uint(targetUnitId))) <| $ [es] (ai_target : Target)
      targetPos = ai_target.targetPos
      hasTargetPos = true
    if !hasTargetPos
      return EBehResult.ER_FAILED

    var agentShootPos = float3()
    var hasAgentPos = false
    query(beh_tree_eid(owner)) <| $ [es] (agent_dangers__standShootPos : float3)
      agentShootPos = agent_dangers__standShootPos
      hasAgentPos = true
    if !hasAgentPos
      return EBehResult.ER_FAILED

    var agentTeam = TEAM_UNASSIGNED
    query(beh_tree_eid(owner)) <| $ [es] (team : int)
      agentTeam = team

    for _i in range(maxTries)
      var pos = targetPos
      let angle = rnd_float(0.0, TWOPI)
      let dist = rnd_float(radiusRange.x, radiusRange.y)
      pos.x += cos(angle) * dist
      pos.z += sin(angle) * dist

      let deltaFromAgent = pos.xz - agentShootPos.xz
      let distToAgentSq = dot(deltaFromAgent, deltaFromAgent)
      if distToAgentSq < square(awayMinRadius)
        let dirFromAgent = normalize(deltaFromAgent)
        pos.x = agentShootPos.x + dirFromAgent.x * awayMinRadius
        pos.z = agentShootPos.z + dirFromAgent.y * awayMinRadius

      if minDistanceFromAllies > 0.0
        var numAllies = 0
        for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, minDistanceFromAllies), GridEntCheck.BOUNDING) <| $(human_eid : EntityId)
          query(human_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (isAlive : bool;
                                                              transform : float3x4;
                                                              team : int = TEAM_UNASSIGNED;
                                                              isInVehicleHidden : bool = false)
            if !isAlive || isInVehicleHidden
              return
            if distance_sq(transform[3], pos) > minDistanceFromAlliesSq
              return
            if team == agentTeam
              ++numAllies
        if numAllies > 0
          continue

      owner.blackBoard |> set(posParam, pos)
      return EBehResult.ER_SUCCESS
    return EBehResult.ER_FAILED


[beh_node(name="isLookingToPos")]
class IsLookingToPos : BehNodeAdapter
  posParam : int = -1
  offAngle : float = 5.0

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    offAngle = datablock_getReal(data, "offAngle", offAngle)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var result = false
    query(agentEid) <| $ [es] (agent_dangers__standShootPos : float3; walker_agent : EntityAgent)
      let delta = owner.blackBoard |> datablock_getPoint3(posParam) - agent_dangers__standShootPos
      let wishDir = normalize(delta)
      if dot(walker_agent.shootDir, wishDir) >= cos(deg_to_rad(offAngle))
        result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="isPointInDirection")]
class IsPointInDirection : BehNodeAdapter
  posParam : int = -1
  fromPosParam : int = -1
  dirPosParam : int = -1
  angle : float = 10.0

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    fromPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "fromPosParam", ""), float3())
    dirPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "dirPosParam", ""), float3())
    angle = datablock_getReal(data, "angle", angle)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var result = false
    let fromPos = owner.blackBoard |> datablock_getPoint3(fromPosParam)
    let baseDir = normalize(owner.blackBoard |> datablock_getPoint3(dirPosParam) - fromPos)
    let toPosDir = normalize(owner.blackBoard |> datablock_getPoint3(posParam) - fromPos)
    if dot(toPosDir, baseDir) >= cos(deg_to_rad(angle))
      result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="rotateToPoint")]
class RotateToPoint : BehNodeAdapter
  posParam : int = -1
  angleParam : int = -1
  aimSpeedCoef : float = 1.0
  aimViscosityCoef : float = 1.0
  pitchRange : float2 = float2(-90.0, 90.0)

  maxSimAngle : float2 = float2(-1.0, -1.0)
  delaySimTime : float2 = float2(0.32, 0.48)
  minSimAngle : float = 0.0
  minSimSpeedCoef : float = 1.0

  walker_agent__aimVelocity : float2 = float2()
  lookFromPos : float3 = float3()

  wishAimingSpeed : float = 16.
  vertAimingCoef : float = 1.0
  wishDir : float3

  simState : int = 0
  simTimer : float = 0.0
  simAngles : float2 = float2(0.0, 0.0)

  strafeChance : float = 0.0
  strafeTimes : float2 = float2(0.0, 0.0)
  strafeTimer : float = 0.0
  strafeSpeed : float = 1.0
  strafeDir : float = 0.0

  forwBackChance : float = 0.0
  forwBackDir : float = 0.0

  moveApplied : bool = false

  minRotateStopDist : float = 1.5

  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "posParam") >= 0
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))
    elif datablock_find_param(data, "angleParam") >= 0
      angleParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "angleParam", ""), 0.)
    aimSpeedCoef = data |> datablock_getReal("aimSpeedCoef", aimSpeedCoef)
    aimViscosityCoef = data |> datablock_getReal("aimViscosityCoef", aimViscosityCoef)
    pitchRange = data |> datablock_getPoint2("pitchRange", pitchRange)
    maxSimAngle = deg_to_rad(data |> datablock_getPoint2("maxSimAngle", maxSimAngle))
    delaySimTime = data |> datablock_getPoint2("delaySimTime", delaySimTime)
    minSimAngle = deg_to_rad(data |> datablock_getReal("minSimAngle", minSimAngle))
    minSimSpeedCoef = data |> datablock_getReal("minSimSpeedCoef", minSimSpeedCoef)
    strafeChance = data |> datablock_getReal("strafeChance", strafeChance)
    strafeTimes = data |> datablock_getPoint2("strafeTimes", strafeTimes)
    strafeSpeed = data |> datablock_getReal("strafeSpeed", strafeSpeed)
    forwBackChance = data |> datablock_getReal("forwBackChance", forwBackChance)

  def override init()
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (agent_dangers__standShootPos : float3;
                               walker_agent : EntityAgent;
                               walker_agent__minMaxAimSpeed : float2;
                               walker_agent__minMaxDist : float2)
      lookFromPos = walker_agent.shootFrom[STANCE_STAND]
      assume minMaxDist = walker_agent__minMaxDist
      assume minMaxAimSpeed = walker_agent__minMaxAimSpeed
      assume agentShootPos = agent_dangers__standShootPos
      if posParam >= 0
        let toPos = owner.blackBoard |> datablock_getPoint3(posParam)
        let delta = toPos - agentShootPos
        let dist = length(delta)
        let ratio = (minMaxAimSpeed.y - minMaxAimSpeed.x) * safeinv(minMaxDist.y - minMaxDist.x)
        wishAimingSpeed = clamp(minMaxAimSpeed.y - ratio * (dist - minMaxDist.x), minMaxAimSpeed.x, minMaxAimSpeed.y)
        wishAimingSpeed = deg_to_rad(wishAimingSpeed)
        wishDir = normalize(delta)
        let anglesAt = dir_to_angles(walker_agent.shootDir)
        var anglesTo = dir_to_angles(wishDir)
        let clampedPitch = clamp(anglesTo.y, deg_to_rad(pitchRange.x), deg_to_rad(pitchRange.y))
        if anglesTo.y != clampedPitch
          anglesTo.y = clampedPitch
          wishDir = angles_to_dir(anglesTo)
        vertAimingCoef = safediv(abs(anglesTo.y - anglesAt.y), abs(norm_s_ang(anglesTo.x - anglesAt.x)))
        vertAimingCoef = min(vertAimingCoef * 2.0, 1.0)
        if toPos == float3()
          wishDir = float3()
      else
        wishAimingSpeed = deg_to_rad(minMaxAimSpeed.x)
        vertAimingCoef = 1.0
        let turnAngle = (angleParam >= 0) ? (owner.blackBoard |> datablock_getReal(angleParam)) : 0.0
        if abs(turnAngle) < 0.0001
          wishDir = float3()
        else
          let shootDir = walker_agent.shootDir
          let angleDir = atan2(shootDir.z, shootDir.x) + turnAngle
          wishDir.x = cos(angleDir)
          wishDir.y = shootDir.y * 0.5
          wishDir.z = sin(angleDir)
          wishDir = normalize(wishDir)
    simState = 0
    strafeTimer = 0.0
    strafeDir = 0.0
    forwBackDir = rnd_float(0.0, 1.0) < forwBackChance ? (rnd_float(0.0, 1.0) < 0.5 ? -1.0 : 1.0) : 0.0
    moveApplied = false

  def simHumanAiming(dt : float; cur_angles : float2; wish_angles : float2; var out_turn_dir : float3&)
    if maxSimAngle.x <= 0.0
      return
    var recalc = false
    if simState == 0
      recalc = true
      simState = 1
    elif simState == 1
      if abs(norm_s_ang(cur_angles.x - simAngles.x)) <= 0.05
        simTimer = rnd_float(delaySimTime.x, delaySimTime.y)
        simState = 2
    elif simState == 2
      simTimer -= dt
      if simTimer < 0.0
        recalc = true
        simState = 1
    if recalc
      var deltaYaw = norm_s_ang(wish_angles.x - cur_angles.x)
      let absDeltaYaw = abs(deltaYaw)
      var forceDiv = false

      if absDeltaYaw > PI * 0.25 && minSimSpeedCoef < 0.49
        let ang1 = norm_s_ang(cur_angles.x + deltaYaw * 0.5)
        let dir1 = angles_to_dir(float2(ang1, 0.0))
        var dist = minRotateStopDist
        if rayhit_normalized(lookFromPos, dir1, dist, ETF_ALL, -1)
          
          let invDeltaYaw = -sign(deltaYaw) * (TWOPI - absDeltaYaw)
          let ang2 = norm_s_ang(cur_angles.x + invDeltaYaw * 0.5)
          let dir2 = angles_to_dir(float2(ang2, 0.0))
          dist = minRotateStopDist
          if !rayhit_normalized(lookFromPos, dir2, dist, ETF_ALL, -1)
            deltaYaw = invDeltaYaw
            forceDiv = true

      let maxAngle = rnd_float(maxSimAngle.x, maxSimAngle.y)
      if absDeltaYaw > maxAngle || forceDiv
        let ratio = forceDiv ? min(1.1, maxAngle / absDeltaYaw) : min(1.1, (0.5 + (1.0 - maxAngle / absDeltaYaw)) * 0.5)
        simAngles.x = norm_s_ang(cur_angles.x + deltaYaw * ratio)
        simAngles.y = lerp(cur_angles.y, wish_angles.y, ratio)
      else
        simState = 3
    if simState < 3
      out_turn_dir = angles_to_dir(simAngles)

  def override update(dt : float) : EBehResult
    if length_sq(wishDir) < 1e-3
      return EBehResult.ER_SUCCESS

    var res = EBehResult.ER_FAILED
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (var human_net_phys : HumanActor&;
                               walker_agent__gunAimOffsetCompensation : float;
                               walker_agent__breathOffsetCompensation : float;
                               walker_agent__aimViscosity : float;
                               walker_agent__velViscosity : float;
                               walker_agent__velFactor : float)
      assume phys = human_net_phys.phys
      let curAngles = dir_to_angles(phys.producedCT.wishShootDir)
      let wishAngles = dir_to_angles(wishDir)
      var turnDir = wishDir

      if maxSimAngle.x > 0.0
        simHumanAiming(dt, curAngles, wishAngles, turnDir)

      let absDeltaYaw = abs(curAngles.x - wishAngles.x)
      if absDeltaYaw <= 0.05 && abs(curAngles.y - wishAngles.y) <= 0.05
        phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, false)
        res = EBehResult.ER_SUCCESS
        return

      var speedCoef = aimSpeedCoef
      if minSimAngle > 0.0 && absDeltaYaw < minSimAngle
        speedCoef = minSimSpeedCoef

      let nowDir = phys.producedCT.wishShootDir
      var dir = calc_wish_approach_vel(dt, wishAimingSpeed * speedCoef, nowDir, turnDir,
                                       walker_agent__gunAimOffsetCompensation,
                                       walker_agent__breathOffsetCompensation,
                                       walker_agent__aimViscosity * aimViscosityCoef,
                                       walker_agent__velViscosity * aimViscosityCoef,
                                       walker_agent__velFactor,
                                       phys.currentState.gunAimOffset,
                                       phys.currentState.breathOffset,
                                       walker_agent__aimVelocity)

      let dy = dir.y - nowDir.y
      dir.y = nowDir.y + dy * vertAimingCoef

      phys.producedCT |> human_control_state_set_wish_shoot_dir(dir)
      phys.producedCT |> human_control_state_set_wish_look_dir(dir)
      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, true)
      phys.producedCT |> human_control_state_set_lean_position(0.f)

      if forwBackDir != 0.0
        let walkDir = float3(dir.x, 0.0, dir.z) * forwBackDir
        phys.producedCT |> human_control_state_set_world_walk_dir(normalize(walkDir.xz), dir.xz)
        phys.producedCT |> human_control_state_set_walk_speed(1.0)
        moveApplied = true
      elif strafeTimes.x > 0.0
        strafeTimer -= dt
        if strafeTimer <= 0.0
          strafeTimer = rnd_float(strafeTimes.x, strafeTimes.y)
          if rnd_float(0.0, 1.0) < strafeChance
            if strafeDir == 0.0
              strafeDir = rnd_float(0.0, 1.0) < 0.5 ? -1.0 : 1.0
            else
              strafeDir = -strafeDir
          else
            strafeDir = 0.0
        let walkDir = float3(dir.z, 0.0, -dir.x) * strafeDir
        phys.producedCT |> human_control_state_set_world_walk_dir(normalize(walkDir.xz), dir.xz)
        phys.producedCT |> human_control_state_set_walk_speed(abs(strafeDir) * strafeSpeed)
        moveApplied = true

      res = EBehResult.ER_RUNNING

    return res

  def override exit()
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (var walker_agent : EntityAgent&)
      walker_agent.aiming.aimVelocity *= 0.0
    if moveApplied
      query(agentEid) <| $ [es] (var human_net_phys : HumanActor&)
        assume phys = human_net_phys.phys
        phys.producedCT |> human_control_state_set_walk_speed(0.0)


[beh_node(name="changeLean")]
class ChangeLean : BehNodeAdapter
  leanTo : float = 0.0
  leanToParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "leanToParam") >= 0
      leanToParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "leanToParam", ""), 0.0)
    else
      leanTo = datablock_getReal(data, "leanTo", 0.0)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (var human_net_phys : HumanActor&)
      assume phys = human_net_phys.phys
      if leanToParam >= 0
        let lean = leanToParam >= 0 ? owner.blackBoard |> datablock_getReal(leanToParam) : leanTo
        phys.producedCT |> human_control_state_set_lean_position(lean)
    return EBehResult.ER_SUCCESS

[beh_node(name="wasAttackedRecently")]
class WasAttackedRecently : BehNodeAdapter
  targetEidParam : int = -1
  minElapsedTime : float = 5.

  def override loadFromBlk(var data : DataBlock) : void
    minElapsedTime = datablock_getReal(data, "minElapsedTime", 5.)
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED

    query(beh_tree_eid(owner)) <| $ [es] (agent_dangers__lastHitReactionTime : float;
                                          agent_dangers__lastBulletReactionTime : float)
      let curTime = get_sync_time()

      if (curTime - agent_dangers__lastHitReactionTime < minElapsedTime)
        res = EBehResult.ER_SUCCESS
        return

      if (curTime - agent_dangers__lastBulletReactionTime < minElapsedTime)
        res = EBehResult.ER_SUCCESS
        return

    return res


[beh_node(name="walkerClimb")]
class WalkerClimb : BehNodeAdapter
  duration : float = 1.
  curTime : float = 0.

  def override loadFromBlk(var data : DataBlock) : void
    duration = data |> datablock_getReal("duration", duration)

  def override init()
    curTime = get_sync_time()

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED

    query(beh_tree_eid(owner)) <| $ [es] (human_net_phys__isUnderwater : bool;
                                          human_net_phys__isInAir : bool;
                                          human_net_phys__isClimbing : bool;
                                          human_net_phys__isSwimming : bool;
                                          var human_net_phys : HumanActor)
      if !(human_net_phys.phys.producedCT |> is_control_bit_set(HumanPhysControlType.HCT_JUMP))
        if (!human_net_phys__isUnderwater &&
            !human_net_phys__isInAir &&
            !human_net_phys__isClimbing &&
            !human_net_phys__isSwimming)
          human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_JUMP, true)

      if curTime + duration <= get_sync_time()
        human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_JUMP, false)
        res = EBehResult.ER_SUCCESS
      else
        res = EBehResult.ER_RUNNING

    return res

  def override exit()
    curTime = 0.
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_JUMP, false)


[beh_node(name="moveByDir")]
class MoveByDir : BehNodeAdapter
  duration : float = 1.
  curTime : float = 0.

  endPosParam : int = -1
  lookPosParam : int = -1
  lookLocked : bool = false

  distThreshold : float = 0.5
  distSprintMin : float = 3.5

  strafeAlong : bool = false
  strafeInSquad : bool = false
  strafeDir : float = 0.0

  traceNavExtents = float3(0.2)
  traceNavMeshDist : float = 0.0

  moveFailed : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    duration = data |> datablock_getReal("duration", duration)

    distThreshold = data |> datablock_getReal("distThreshold", distThreshold)
    distSprintMin = data |> datablock_getReal("distSprintMin", distSprintMin)

    endPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "endPos", ""), float3())

    if datablock_find_param(data, "lookPosParam") >= 0
      lookPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lookPosParam", ""), float3())
    lookLocked = datablock_getBool(data, "lookLocked", lookLocked)

    strafeAlong = datablock_getBool(data, "strafeAlong", strafeAlong)
    strafeInSquad = datablock_getBool(data, "strafeInSquad", strafeInSquad)

    traceNavMeshDist = datablock_getReal(data, "traceNavMeshDist", traceNavMeshDist)

  def override init()
    curTime = get_sync_time()
    moveFailed = false

    if strafeAlong
      strafeDir = rnd_float(0.0, 1.0) < 0.5 ? -1.0 : 1.0

    if traceNavMeshDist > 0.0
      moveFailed = true
      let agentEid = beh_tree_eid(owner)
      query(agentEid) <| $ [es] (transform : float3x4)
        let curPos = transform[3]
        let endPos = owner.blackBoard |> datablock_getPoint3(endPosParam)
        let deltaPos = endPos - curPos

        var moveDir = deltaPos
        if strafeAlong
          moveDir = float3(moveDir.z, 0.0, -moveDir.x) * strafeDir
        moveDir.y = 0.0

        moveFailed = false
        var hitPos = float3()
        moveDir = normalize(moveDir)
        var toPos = curPos + moveDir * traceNavMeshDist
        if traceray_navmesh(curPos, toPos, traceNavExtents, hitPos)
          strafeDir = -strafeDir
          toPos = curPos - moveDir * traceNavMeshDist
          if traceray_navmesh(curPos, toPos, traceNavExtents, hitPos)
            moveFailed = true

        if strafeAlong && strafeInSquad && !moveFailed
          query(agentEid) <| $ [es] (squad_member__squad : EntityId)
            query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
              if squad__leader != agentEid
                query(squad__leader) <| $ [es] (transform aka leader_transform : float3x4; isAlive : bool; isDowned : bool)
                  if isAlive && !isDowned
                    let SQUAD_STRAFE_CHECK_DIST = 1.0
                    let SQUAD_STRAFE_MAX_AHEAD = 15.0
                    let SQUAD_LEADER_SIGHT_DIST = 0.7
                    let checkPos = curPos + moveDir * SQUAD_STRAFE_CHECK_DIST
                    let leaderPos = leader_transform[3]
                    let localPos = checkPos - leaderPos
                    let leaderDir = normalize(x0z(leader_transform[0]))
                    let distAhead = dot(leaderDir, localPos)
                    if distAhead > 0.0 && distAhead < SQUAD_STRAFE_MAX_AHEAD
                      let leaderRt = float3(leaderDir.z, 0.0, -leaderDir.x)
                      let distToLeaderSight = dot(leaderRt, localPos)
                      if abs(distToLeaderSight) < SQUAD_LEADER_SIGHT_DIST
                        moveFailed = true

  def override update(dt : float) : EBehResult
    if moveFailed
      return EBehResult.ER_FAILED
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor;
                                          transform : float3x4)
      assume phys = human_net_phys.phys

      let curPos = transform[3]
      let endPos = owner.blackBoard |> datablock_getPoint3(endPosParam)

      let deltaPos = endPos - curPos
      let deltaLenSq = length_sq(deltaPos)
      if deltaLenSq < square(distThreshold)
        phys.producedCT |> human_control_state_set_walk_speed(0.)
        phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SPRINT, false)
        res = EBehResult.ER_SUCCESS
        return

      var moveDir = deltaPos
      if strafeAlong
        moveDir = float3(moveDir.z, 0.0, -moveDir.x) * strafeDir

      var lookDir = normalize(deltaPos)
      if !lookLocked
        if lookPosParam >= 0
          let lookPos = owner.blackBoard |> datablock_getPoint3(lookPosParam)
          lookDir = normalize(lookPos - curPos)

        phys.producedCT |> human_control_state_set_wish_shoot_dir(normalize(float3(lookDir.x, 0., lookDir.z)))
        phys.producedCT |> human_control_state_set_wish_look_dir(normalize(float3(lookDir.x, 0., lookDir.z)))
      else
        lookDir = phys.producedCT.wishLookDir

      phys.producedCT |> human_control_state_set_world_walk_dir(normalize(moveDir.xz), lookDir.xz)
      phys.producedCT |> human_control_state_set_walk_speed(1.)

      let canSprint = deltaLenSq > square(distSprintMin)
      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SPRINT, canSprint)

      if curTime + duration <= get_sync_time()
        phys.producedCT |> human_control_state_set_walk_speed(0.)
        phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SPRINT, false)

        res = EBehResult.ER_SUCCESS
      else
        res = EBehResult.ER_RUNNING

    return res

  def override exit()
    curTime = 0.
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor)
      human_net_phys.phys.producedCT |> human_control_state_set_walk_speed(0.)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SPRINT, false)


[beh_node(name="chooseRandomStance")]
class ChooseRandomStance : BehNodeAdapter
  stanceParam : int = -1

  minStance : int = STANCE_CRAWL
  maxStance : int = STANCE_STAND

  def override loadFromBlk(var data : DataBlock) : void
    stanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "stanceParam", ""), 0)
    minStance = datablock_getInt(data, "minStance", STANCE_CRAWL)
    maxStance = datablock_getInt(data, "maxStance", STANCE_STAND)

  def override update(dt : float) : EBehResult
    owner.blackBoard |> set(stanceParam, rnd_int(minStance, maxStance))
    return EBehResult.ER_SUCCESS


[beh_node(name="calcDistance")]
class CalcDistance : BehNodeAdapter
  endPosParam   : int = -1
  startPosParam : int = -1
  distanceParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    endPosParam   = owner.blackBoard |> get_or_create(datablock_getStr(data, "endPosParam", ""), float3(0., 0., 0.))
    startPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "startPosParam", ""), float3(0., 0., 0.))

    distanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "distanceParam", ""), 0.)

  def override update(dt : float) : EBehResult
    let distance = distance(owner.blackBoard |> datablock_getPoint3(startPosParam),
      owner.blackBoard |> datablock_getPoint3(endPosParam))

    owner.blackBoard |> set(distanceParam, distance)

    return EBehResult.ER_SUCCESS


[beh_node(name="giveAmmo")]
class GiveAmmo : BehNodeAdapter
  varId : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    varId = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0.)

  def override update(dt : float) : EBehResult
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(varId)))
    owner.blackBoard |> set(varId, 0)

    let agentEid = beh_tree_eid(owner)

    query(targetEid) <| $ [es] (transform aka target_transform : float3x4;
                                human_use_object__thresholdDist : float = 12.f)
      query(agentEid) <| $ [es] (transform aka agent_transform : float3x4)
        if length_sq(target_transform[3] - agent_transform[3]) > square(human_use_object__thresholdDist)
          return

        let pathSlop = 0.25
        let distToPath = 1.
        let extents = float3(distToPath, FLT_MAX, distToPath)

        if find_path(target_transform[3], agent_transform[3], extents, distToPath, pathSlop) != FindPathResult.FPR_FULL
          return

        if is_server()
          sendEvent(agentEid, CmdUse(requesterEid = targetEid))
        else
          sendEvent(targetEid, HumanUseObjectRequest(objectEid = agentEid))

    return EBehResult.ER_SUCCESS


[beh_node(name="getAgentAIPos")]
class GetAgentAIPos : BehNodeAdapter
  outPosParam : int = -1
  outDirParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "outPosParam") >= 0
      outPosParam  = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3())
    if datablock_find_param(data, "outDirParam") >= 0
      outDirParam  = owner.blackBoard |> get_or_create(datablock_getStr(data, "outDirParam", ""), float3())

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if outPosParam >= 0
      owner.blackBoard |> set(outPosParam, agent.pos)
      query(agent.eid) <| $ [es] (transform : float3x4)
        owner.blackBoard |> set(outPosParam, transform[3])
    if outDirParam >= 0
      owner.blackBoard |> set(outDirParam, float3())
      query(agent.eid) <| $ [es] (transform : float3x4)
        owner.blackBoard |> set(outDirParam, transform[0])
    return EBehResult.ER_SUCCESS



let GetPointAroundAIPos_cosMxSide = fixed_array<float>(-0.2588190451, -0.2588190451, -0.50000000000, -0.50000000000,  0.,  0.)
let GetPointAroundAIPos_sinMxSide = fixed_array<float>(+0.9659258262, -0.9659258262, -0.86602540378, +0.86602540378,  1., -1.)
let GetPointAroundAIPos_cosMxForw = fixed_array<float>(+0.9659258262, +0.9659258262, +0.86602540378, +0.86602540378,  1.,  1.)
let GetPointAroundAIPos_sinMxForw = fixed_array<float>(+0.2588190451, -0.2588190451, -0.50000000000, +0.50000000000,  0.,  0.)

[beh_node(name="getPointAroundAIPos")]
class GetPointAroundAIPos : BehNodeAdapter
  dirParam     : int = -1
  outPosParam  : int = -1
  forwPosParam : int = -1
  resetParam   : int = -1
  fromPosParam : int = -1
  toPosParam   : int = -1

  counter    : int = 0
  radius     : float = 1.5

  initPos  : float3
  initDir  : float3
  stepDist : float
  sideCoef : float

  def override loadFromBlk(data : DataBlock) : void
    dirParam     = owner.blackBoard |> get_or_create(datablock_getStr(data, "dirParam", ""), float3(0.0))
    outPosParam  = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3(0.0))
    forwPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "forwPosParam", ""), float3(0.0))
    resetParam   = owner.blackBoard |> get_or_create(datablock_getStr(data, "resetAIPointsGeneratorParam", ""), 0)
    fromPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "fromPosParam", ""), float3(0.0))
    toPosParam   = owner.blackBoard |> get_or_create(datablock_getStr(data, "toPosParam", ""), float3(0.0))
    radius       = datablock_getReal(data, "radius", 1.5)

  def override init()
    if counter == 0 || owner.blackBoard |> datablock_getInt(resetParam) != 0
      owner.blackBoard |> set(resetParam, 0)
      let agent = beh_tree_entity_agent(*owner)
      initDir = normalize(x0z(owner.blackBoard |> datablock_getPoint3(dirParam)))
      initPos = agent.pos
      counter = 0

      let fromPos = owner.blackBoard |> datablock_getPoint3(fromPosParam)
      let wishPos = owner.blackBoard |> datablock_getPoint3(toPosParam)

      let dist = length(wishPos - initPos)
      stepDist = min(dist, radius)

      let dir = normalize(wishPos - fromPos)
      let norm = float2(dir.z, -dir.x)
      let offs = dot(norm, initPos.xz) - dot(norm, fromPos.xz)
      sideCoef = offs < 0.0 ? 1.0 : -1.0

  def override update(dt : float) : EBehResult
    if length_sq(initDir) < 1e-3
      counter = 0
      return EBehResult.ER_FAILED

    let count = length(GetPointAroundAIPos_cosMxSide)
    if counter >= count
      counter = 0
      return EBehResult.ER_FAILED

    let id = counter

    let ndx = initDir.x * GetPointAroundAIPos_cosMxSide[id] - initDir.z * GetPointAroundAIPos_sinMxSide[id] * sideCoef
    let ndz = initDir.x * GetPointAroundAIPos_sinMxSide[id] * sideCoef + initDir.z * GetPointAroundAIPos_cosMxSide[id]
    let newPos = initPos + float3(ndx, 0.0, ndz) * stepDist
    if outPosParam >= 0
      owner.blackBoard |> set(outPosParam, newPos)

    if forwPosParam >= 0
      let fdx = initDir.x * GetPointAroundAIPos_cosMxForw[id] - initDir.z * GetPointAroundAIPos_sinMxForw[id] * sideCoef
      let fdz = initDir.x * GetPointAroundAIPos_sinMxForw[id] * sideCoef + initDir.z * GetPointAroundAIPos_cosMxForw[id]
      let forwPos = newPos + float3(fdx, 0.0, fdz) * stepDist
      owner.blackBoard |> set(forwPosParam, forwPos)

    ++counter
    return EBehResult.ER_SUCCESS


[beh_node(name="findCoverAroundPoint")]
class FindCoverAroundPoint : BehNodeAdapter
  centerParam   : int = -1
  coverPosParam : int = -1
  maxDistParam  : int = -1

  radius     : float = 5.0
  minDist    : float = 0.0

  possibleCosAngle   : float = 0.5
  possibleAngleParam : int = -1

  invertToCenter : bool = false

  keepOldCoverChance : float = 0.9

  maxOccupied  : int = -1
  traceVisible : bool = false

  avoidLeaderActing : LeaderActingInfo

  def override loadFromBlk(var data : DataBlock) : void
    radius = datablock_getReal(data, "radius", 5.)
    minDist = datablock_getReal(data, "minDist", 0.0)

    let possibleAngle = datablock_getReal(data, "possibleAngle", 90.)
    possibleCosAngle  = cos(deg_to_rad(possibleAngle))
    if datablock_find_param(data, "possibleAngleParam") >= 0
      possibleAngleParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "possibleAngleParam", ""), 90.)

    let agent = beh_tree_entity_agent(*owner)
    centerParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "centerParam", ""), agent.pos)
    coverPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverPosParam", ""), agent.pos)
    let maxDistParamName = datablock_getStr(data, "radiusParam", "")
    if maxDistParamName != ""
      maxDistParam = owner.blackBoard |> get_or_create(maxDistParamName, radius)

    keepOldCoverChance = datablock_getReal(data, "keepOldCoverChance", 0.6)

    maxOccupied = datablock_getInt(data, "maxOccupied", maxOccupied)
    traceVisible = datablock_getBool(data, "traceVisible", traceVisible)

  def override init()
    if possibleAngleParam >= 0
      possibleCosAngle = cos(deg_to_rad(datablock_getReal(owner.blackBoard, possibleAngleParam)))

    let agentEid = beh_tree_eid(owner)
    avoidLeaderActing = get_squad_leader_acting_for_agent(agentEid)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let visibleMap = get_global_visible_covers_map()

    let agentEid = beh_tree_eid(owner)
    query() <| $ [es] (var covers : CoversComponent&)
      query(agentEid) <| $ [es] (walker_agent : EntityAgent;
                                 team : int = TEAM_UNASSIGNED;
                                 squad_member__squad : EntityId = INVALID_ENTITY_ID;
                                 var cover_updater__heldCovers : IPoint2List&)
        var prevCoverId = int2(-1, 0)
        if length(cover_updater__heldCovers) > 0
          prevCoverId = cover_updater__heldCovers[0]

        var allowTight = false
        query(squad_member__squad) <| $ [es] (squad__formationSpread : int)
          if squad__formationSpread == int(SquadFormationSpread.ESFN_CLOSEST)
            allowTight = true

        reset_covers(covers, cover_updater__heldCovers)

        let centerPos = owner.blackBoard |> datablock_getPoint3(centerParam)

        let maxDist = maxDistParam >= 0 ? (owner.blackBoard |> datablock_getReal(maxDistParam)) : radius
        let maxDistSq = square(maxDist)
        let minDistSq = square(minDist)

        var box : bbox3f
        box.bmax.xyz = centerPos + float3(maxDist, 2.5f, maxDist)
        box.bmin.xyz = centerPos - float3(maxDist, 0.5f, maxDist)

        let midPos = walker_agent.pos * 0.3 + centerPos * 0.7
        let likelyKeepCover = rnd_float(0.0, 1.0) < keepOldCoverChance

        let traceStartPos = centerPos + float3(0.0, 1.0, 0.0)
        let traceHeightUp = float3(0.0, 0.5, 0.0)

        var bestDistSq = FLT_MAX
        var bestCoverId = int2(-1, 0)
        var bestScore = 0
        var bestTight = true
        var bestOKDir = false
        var bestFound = false

        var dangerPoints : array<float3>
        get_danger_points(dangerPoints, agentEid, team, walker_agent.pos, 0.0, 2.0)

        let filterInfo = get_filter_covers_info()
        covers_box_cull(covers, box) <| $ [unused_argument(tm)] (id : int;
                                                                 tm : mat44f#)
          if bestFound
            return
          if tm.col3.xyz == float3() 
            return
          if team != TEAM_UNASSIGNED && glob_vis_covers_map_has_other_teams(visibleMap, id, team)
            return

          assume cover     = covers.list[id]
          assume coverDesc = covers.coverDescs[id]
          if filter_cover(cover, coverDesc, box, maxOccupied, filterInfo)
            return

          let numSlots = length(coverDesc.slots)
          let isPrevCover = prevCoverId.x == id && likelyKeepCover

          var slotBestCoverId = int2(id, -1)
          var slotBestDistSq = bestDistSq
          var slotBestScore = bestScore
          var slotBestTight = bestTight
          var slotBestOKDir = bestOKDir
          for i in range(0, numSlots)
            if coverDesc.slots[i].numUsed > 0
              continue
            let isPrevCoverSlot = isPrevCover && i == prevCoverId.y
            let coverSlotPosBase = get_cover_slot_pos(cover, coverDesc, i)
            if is_conflict_with_squad_leader_acting(avoidLeaderActing, coverSlotPosBase, agentEid)
              continue
            let isTight = !allowTight && check_covers_nearby_occupied(coverSlotPosBase, id, i, covers.list, covers.coverDescs)
            let goodDir = check_cover_pos_vs_points(coverSlotPosBase, cover.dir, dangerPoints)
            if isTight && !slotBestTight && !isPrevCoverSlot
              continue
            let isBetterByDir = goodDir && !slotBestOKDir
            let isBetterByTight = !isTight && slotBestTight
            let isBetter = isPrevCoverSlot || isBetterByTight || isBetterByDir
            let extraScore = (isPrevCoverSlot ? 50 : 0) + (isTight ? 0 : 50) + (goodDir ? 101 : 0)
            let score = eval_cover_score_stay(cover, coverDesc, i) * 100 + extraScore
            if score < slotBestScore && !isBetter
              continue
            let coverSlotPos = coverSlotPosBase + traceHeightUp
            let coverSlotOfs = coverSlotPos - traceStartPos
            let cosAngle = dot(cover.dir, normalize(float3(coverSlotOfs.x, 0.0, coverSlotOfs.z))) * (invertToCenter ? -1.0 : 1.0)
            if cosAngle < possibleCosAngle
              continue
            let distToCenterSq = length_sq(coverSlotOfs)
            let distFromAgentSq = distance_sq(midPos, coverSlotPos)
            if distToCenterSq < minDistSq || distToCenterSq > maxDistSq
              continue
            if distFromAgentSq > slotBestDistSq && score == slotBestScore && !isBetter
              continue
            if !is_point_safe(coverSlotPos, team)
              continue
            if traceVisible && !isPrevCoverSlot
              let dir = normalize(coverSlotOfs)
              let t1 = length(coverSlotOfs)
              let t2 = t1
              if rayhit_normalized(traceStartPos, dir, t1, ETF_ALL, -1)
                let rayPos = traceStartPos + traceHeightUp
                if rayhit_normalized(rayPos, dir, t2, ETF_ALL, -1)
                  continue
            slotBestDistSq = distFromAgentSq
            slotBestCoverId = int2(id, i)
            slotBestScore = score
            slotBestTight = isTight
            slotBestOKDir = goodDir
            if isPrevCoverSlot && !isTight
              bestDistSq = slotBestDistSq
              bestCoverId = slotBestCoverId
              bestScore = slotBestScore
              bestTight = slotBestTight
              bestOKDir = slotBestOKDir
              bestFound = true
              return
          if slotBestCoverId.y != -1
            assume cover2     = covers.list[slotBestCoverId.x]
            assume coverDesc2 = covers.coverDescs[slotBestCoverId.x]
            let coverAIPos = get_cover_slot_pos(cover2, coverDesc2, slotBestCoverId.y)
            if check_cover_pos_valid(coverAIPos)
              bestDistSq = slotBestDistSq
              bestCoverId = slotBestCoverId
              bestScore = slotBestScore
              bestTight = slotBestTight
              bestOKDir = slotBestOKDir

        if bestCoverId.x != -1
          assume cover     = covers.list[bestCoverId.x]
          assume coverDesc = covers.coverDescs[bestCoverId.x]

          push(cover_updater__heldCovers, bestCoverId)
          coverDesc.slots[bestCoverId.y].numUsed += 1
          if coverDesc.slots[bestCoverId.y].numUsed == 1
            coverDesc.numUsedSlots += 1

          let coverAIPos = get_cover_slot_pos(cover, coverDesc, bestCoverId.y)
          owner.blackBoard |> set(coverPosParam, coverAIPos)
          res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="onceUntilReset")]
class OnceUntilResetNode : BehNodeAdapter
  isDone : bool = false

  def override reset() : void
    isDone = false

  def override update(dt : float) : EBehResult
    if isDone
      return EBehResult.ER_FAILED
    isDone = true
    return EBehResult.ER_SUCCESS


[beh_node(name="findDangerousBomb")]
class FindDangerousBomb : BehNodeAdapter
  bombDangerousRadius : float = 15.
  bombDangerousTime : float = 3.
  dangerPosParam : int = -1
  radiusSquare : float = 0.

  def override loadFromBlk(var data : DataBlock) : void
    dangerPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "dangerPosParam", ""), float3())
    bombDangerousRadius = data |> datablock_getReal("bombDangerousRadius", bombDangerousRadius)
    bombDangerousTime = data |> datablock_getReal("bombDangerousTime", bombDangerousTime)
    radiusSquare = square(bombDangerousRadius)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let botTransform = get_TMatrix(ownerEid, "transform")
    let botPos = (*botTransform)[3]

    let found = find_query() <| $ [es] (bomb_site__timeToExplosionLeft : float;
                                        transform : float3x4)
      let bombPos = transform[3]
      if bomb_site__timeToExplosionLeft > 0. && bomb_site__timeToExplosionLeft < bombDangerousTime && distance_sq(bombPos, botPos) < radiusSquare
        owner.blackBoard |> set(dangerPosParam, bombPos)
        return true
      return false
    if found
      return EBehResult.ER_SUCCESS
    return EBehResult.ER_FAILED

[beh_node(name="findSafeFromBombPos")]
class FindSafeFromBombPos : BehNodeAdapter
  bombDangerousRadius : float = 15.
  dangerPosParam : int = -1
  safePosParam : int = -1
  radiusSquare : float = 0.

  def override loadFromBlk(var data : DataBlock) : void
    dangerPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "dangerPosParam", ""), float3())
    safePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "safePosParam", ""), float3())
    bombDangerousRadius = data |> datablock_getReal("bombDangerousRadius", bombDangerousRadius)
    radiusSquare = square(bombDangerousRadius)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    let bombPos = owner.blackBoard |> datablock_getPoint3(dangerPosParam)
    let oldSafePos = owner.blackBoard |> datablock_getPoint3(safePosParam)
    if distance_sq(oldSafePos, bombPos) > square(bombDangerousRadius)
      return EBehResult.ER_SUCCESS

    let dir = normalize(agent.pos - bombPos)
    let dirAngle = safe_asin(dir.y)
    let angles = fixed_array(0., -PI / 8., PI / 8., -PI / 4., PI / 4.)
    var newSafePos : float3
    var found = false

    for angle in angles
      let newDirAngle = dirAngle + angle
      newSafePos = bombPos + float3(sin(newDirAngle), 0.f, cos(newDirAngle)) * bombDangerousRadius * 1.2
      project_to_nearest_navmesh_point(newSafePos, 0.5)
      let extents = float3(0.5, FLT_MAX, 0.5)
      find_path(agent.pos, newSafePos, extents, 1.f, 0.25f) <| $(path)
        for pathPos in path
          if distance_sq(pathPos, bombPos) < square(bombDangerousRadius)
            continue
          if !has_active_human_battle_area_at(newSafePos, agent.teamId)
            break
          newSafePos = pathPos
          found = true
          break
      if found
        owner.blackBoard |> set(safePosParam, newSafePos)
        return EBehResult.ER_SUCCESS
    return EBehResult.ER_FAILED


[beh_node(name="findWayBackToNavmesh")]
class FindWayBackToNavmesh : BehNodeAdapter
  radius = 3.0
  heightHalfOffset = 1.0
  traceHeight = 1.0
  outPosParam : int = -1
  angleStep : float = 30.0
  currentPolyIndex : int = 0
  currentTraceIndex : int = 0
  traceDist : float

  def override loadFromBlk(data : DataBlock) : void
    outPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3(0.0))
    angleStep = data |> datablock_getReal("angleStep", angleStep)

  def override init()
    currentPolyIndex = -1
    currentTraceIndex = 0
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          var walker_agent__getBackToNavmeshPolys : UInt64List&;
                                          var walker_agent__getBackToNavmeshTraces : Point3List&)
      walker_agent__getBackToNavmeshPolys |> clear()
      walker_agent__getBackToNavmeshTraces |> clear()
      find_polys_in_circle(transform[3], radius, heightHalfOffset) <| $(polyRefs)
        for polyRef in polyRefs
          walker_agent__getBackToNavmeshPolys |> push(polyRef)
      shuffle(walker_agent__getBackToNavmeshPolys)

  def override exit()
    query(beh_tree_eid(owner)) <| $ [es] (var walker_agent__getBackToNavmeshPolys : UInt64List&;
                                          var walker_agent__getBackToNavmeshTraces : Point3List&)
      walker_agent__getBackToNavmeshPolys |> clear()
      walker_agent__getBackToNavmeshTraces |> clear()

  def collect_traces_for_poly(agent_pos : float3; poly_ref : uint64; var res : Point3List&; var dist : float&)
    var triangle : NavMeshTriangle
    if get_triangle_by_poly(dtPolyRef(poly_ref), triangle)
      var minAzimuth = TWOPI
      var maxAzimuth = -TWOPI
      var maxDistSq = 0.0
      for vertex in fixed_array<float3>(triangle.p0, triangle.p1, triangle.p2)
        let azimuth = dir_to_angles(vertex - agent_pos).x
        minAzimuth = min(minAzimuth, azimuth)
        maxAzimuth = max(maxAzimuth, azimuth)
        maxDistSq = max(maxDistSq, distance_sq(agent_pos, vertex))
      dist = sqrt(maxDistSq)
      if maxAzimuth - minAzimuth > PI
        let shiftedMax = minAzimuth + TWOPI
        minAzimuth = maxAzimuth
        maxAzimuth = shiftedMax
      let halfArc = (maxAzimuth - minAzimuth) * 0.5
      let arcCenterAngle = minAzimuth + halfArc
      res |> push(angles_to_dir(float2(arcCenterAngle, 0.0)))
      res |> push(angles_to_dir(float2(minAzimuth, 0.0)))
      res |> push(angles_to_dir(float2(maxAzimuth, 0.0)))
      for i in range(halfArc / angleStep)
        res |> push(angles_to_dir(float2(arcCenterAngle + angleStep * float(i + 1), 0.0)))
        res |> push(angles_to_dir(float2(arcCenterAngle - angleStep * float(i + 1), 0.0)))

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    var res = EBehResult.ER_FAILED
    query(agent.eid) <| $ [es] (walker_agent__getBackToNavmeshPolys : UInt64List;
                                var walker_agent__getBackToNavmeshTraces : Point3List&)
      if currentPolyIndex >= length(walker_agent__getBackToNavmeshPolys)
        return

      if currentTraceIndex >= length(walker_agent__getBackToNavmeshTraces)
        walker_agent__getBackToNavmeshTraces |> clear()
        currentTraceIndex = 0

        ++currentPolyIndex
        if currentPolyIndex < length(walker_agent__getBackToNavmeshPolys)
          let polyRef = walker_agent__getBackToNavmeshPolys[currentPolyIndex]
          collect_traces_for_poly(agent.pos, polyRef, walker_agent__getBackToNavmeshTraces, traceDist)
          shuffle(walker_agent__getBackToNavmeshTraces)
        res = EBehResult.ER_RUNNING
        return

      let traceStart = agent.pos + float3(0., traceHeight, 0.)
      let traceDir = walker_agent__getBackToNavmeshTraces[currentTraceIndex]
      ++currentTraceIndex
      if !rayhit_normalized(traceStart, traceDir, traceDist, ETF_DEFAULT, -1)
        owner.blackBoard |> set(outPosParam, agent.pos + traceDir * traceDist)
        res = EBehResult.ER_SUCCESS
        return
      res = EBehResult.ER_RUNNING

    return res

[beh_node(name="isOnNavmesh")]
class IsOnNavmesh : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    let extents = 0.1
    var pos = agent.pos
    if project_to_nearest_navmesh_point(pos, extents) && abs(pos.y - agent.pos.y) < 0.5
      return EBehResult.ER_SUCCESS
    return EBehResult.ER_FAILED


[beh_node(name="forceDoor")]
class ForceDoor : BehNodeAdapter
  lockedDoorEidParam : int = -1
  forceDoorTimeout : float = 5.0
  forceDoorEndTime : float = 0.0

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "lockedDoorEidOutParam") >= 0
      lockedDoorEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lockedDoorEidOutParam", ""), 0)
    forceDoorTimeout = data |> datablock_getReal("forceDoorTimeout", forceDoorTimeout)

  def override init() : void
    forceDoorEndTime = get_sync_time() + forceDoorTimeout

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let doorEid = EntityId(uint(owner.blackBoard |> datablock_getInt(lockedDoorEidParam)))
    var res = EBehResult.ER_FAILED
    if get_sync_time() < forceDoorEndTime
      query(doorEid) <| $ [es] (door__isLocked : bool; door__isBreaking : bool)
        if door__isBreaking
          res = EBehResult.ER_RUNNING
        else
          if door__isLocked
            send_net_event(agentEid, CmdStartBreakingDoor(doorEid = doorEid))
          res = door__isLocked ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS
    return res


[beh_node(name="isAgentEid")]
class IsAgentEid : BehNodeAdapter
  eidVal : int = 0
  def override loadFromBlk(var data : DataBlock)
    eidVal = datablock_getInt(data, "eid", 0)
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let checkEid = EntityId(uint(eidVal))
    return agentEid == checkEid ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="getSquadGoal")]
class getSquadGoal : BehNodeAdapter
  outGoalTypeParam : int = -1
  outGoalEidParam : int = -1

  def override loadFromBlk(var data : DataBlock)
    outGoalTypeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outGoalTypeParam", ""), 0)
    outGoalEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outGoalEidParam", ""), 0)

  def override update(dt : float) : EBehResult
    var done = false
    owner.blackBoard |> set(outGoalTypeParam, 0)
    owner.blackBoard |> set(outGoalEidParam, 0)
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (squadAI_tactical__goalType : int; squadAI_tactical__goalEid : EntityId)
        owner.blackBoard |> set(outGoalTypeParam, squadAI_tactical__goalType)
        owner.blackBoard |> set(outGoalEidParam, int(uint(squadAI_tactical__goalEid)))
        done = true
    return done ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="setSquadGoal")]
class setSquadGoal : BehNodeAdapter
  goalType : int = -1
  goalTypeParam : int = -1
  goalEidParam : int = -1
  resetAction : bool = false

  def override loadFromBlk(var data : DataBlock)
    goalType = datablock_getInt(data, "goalType", goalType)
    if datablock_find_param(data, "goalTypeParam") >= 0
      goalTypeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "goalTypeParam", ""), 0)
    if datablock_find_param(data, "goalEidParam") >= 0
      goalEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "goalEidParam", ""), 0)
    resetAction = datablock_getBool(data, "resetAction", resetAction)

  def override update(dt : float) : EBehResult
    var done = false
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId)
      if goalType >= 0 || goalTypeParam >= 0
        query(squad_member__squad) <| $ [es] (var squadAI_tactical__goalType : int&; var squadAI_tactical__goalEid : EntityId&)
          let outGoalType = goalTypeParam < 0 ? goalType : owner.blackBoard |> datablock_getInt(goalTypeParam)
          let outGoalEid = (goalEidParam >= 0) ? EntityId(uint(owner.blackBoard |> datablock_getInt(goalEidParam))) : INVALID_ENTITY_ID
          squadAI_tactical__goalType = outGoalType
          squadAI_tactical__goalEid = outGoalEid
          done = true
      if resetAction
        query(squad_member__squad) <| $ [es] (var squadAI_tactical__actionType : int&)
          squadAI_tactical__actionType = -1
    return done ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="tryFindSquadPathToGoalPoint")]
class TryFindSquadPathToGoalPoint : BehNodeAdapter
  pointParam : int = -1
  findThruBlocked : bool = false
  allowPartialAsLastChance : bool = false

  notTooBack : bool = false
  maxBackDist : float = 0.0
  outWasTooBackParam : int = -1

  def override loadFromBlk(var data : DataBlock)
    pointParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "pointParam", ""), float3())
    findThruBlocked = datablock_getBool(data, "findThruBlocked", findThruBlocked)
    allowPartialAsLastChance = datablock_getBool(data, "allowPartialAsLastChance", allowPartialAsLastChance)

    notTooBack = datablock_getBool(data, "notTooBack", notTooBack)
    maxBackDist = datablock_getReal(data, "maxBackDist", maxBackDist)
    if datablock_find_param(data, "outWasTooBackParam") >= 0
      outWasTooBackParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outWasTooBackParam", ""), 0)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var agentPos = float3()
    var agentSquad = INVALID_ENTITY_ID
    var agentTeam = TEAM_UNASSIGNED
    var hasAgentInfo = false
    query(agentEid) <| $ [es] (transform : float3x4; squad_member__squad : EntityId; team : int)
      agentPos = transform[3]
      agentSquad = squad_member__squad
      agentTeam = team
      hasAgentInfo = true
    if !hasAgentInfo || agentSquad == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    let fromPos = agentPos
    let destPos = owner.blackBoard |> datablock_getPoint3(pointParam)

    var path : array<float3>
    let extents = float3(1.5, FLT_MAX, 1.5)
    var customNav : CustomNav const? = null
    find_query() <| $ [es] (team__id : int; walker_custom_nav : CustomNav const?)
      if team__id != agentTeam && walker_custom_nav != null
        customNav = walker_custom_nav
        return true
      return false
    if !find_path_full(fromPos, destPos, extents, 0.5, 0.25, 0.5, 1.0, findThruBlocked, customNav, path)
      if !allowPartialAsLastChance || empty(path)
        return EBehResult.ER_FAILED
    let len = length(path)
    if len <= 1
      return EBehResult.ER_FAILED

    query(agentSquad) <| $ [es] (var squadAI_tactical__path : Point3List&)
      clear(squadAI_tactical__path)
      resize(squadAI_tactical__path, len)
      for i in range(len)
        squadAI_tactical__path[i] = path[i]

    var tooBack = false
    if notTooBack
      var atPos = path[0]
      var backDist = 0.0
      for i in range(1, len)
        let nextPos = path[i]
        let delta = nextPos - atPos
        if dot(delta, nextPos - path[0]) < 0.0
          backDist += length(delta)
        atPos = nextPos
      tooBack = maxBackDist > 0.0 && backDist > maxBackDist
    if outWasTooBackParam >= 0
      owner.blackBoard |> set(outWasTooBackParam, tooBack ? 1 : 0)

    return EBehResult.ER_SUCCESS

[beh_node(name="getValidatedSquadPathAction")]
class GetValidatedSquadPathAction : BehNodeAdapter
  outActionTypeParam : int = -1
  outActionTargetEidParam : int = -1
  outActionPosFromParam : int = -1
  outActionPosLookParam : int = -1
  outActionPosToParam : int = -1
  checkTimeout : bool = true

  REACH_POS_DISTANCE = 10.0
  REACH_POS_MAXDIST = 100.0

  DEF_LOOK_DIST = 100.0

  def override loadFromBlk(var data : DataBlock)
    if datablock_find_param(data, "outActionTypeParam") >= 0
      outActionTypeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outActionTypeParam", ""), -1)
    if datablock_find_param(data, "outActionTargetEidParam") >= 0
      outActionTargetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outActionTargetEidParam", ""), 0)
    if datablock_find_param(data, "outActionPosFromParam") >= 0
      outActionPosFromParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outActionPosFromParam", ""), float3())
    if datablock_find_param(data, "outActionPosLookParam") >= 0
      outActionPosLookParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outActionPosLookParam", ""), float3())
    if datablock_find_param(data, "outActionPosToParam") >= 0
      outActionPosToParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outActionPosToParam", ""), float3())
    checkTimeout = datablock_getBool(data, "checkTimeout", checkTimeout)

  def reset_action(squad_eid : EntityId)
    query(squad_eid) <| $ [es] (var squadAI_tactical__actionType : int&;
                                var squadAI_tactical__path : Point3List&)
      squadAI_tactical__actionType = -1
      clear(squadAI_tactical__path)
    return false

  def override update(dt : float) : EBehResult
    var done = false
    owner.blackBoard |> set(outActionTypeParam, -1)
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId; transform : float3x4)
      query(squad_member__squad) <| $ [es] (var squadAI_tactical__actionType : int&;
                                            squadAI_tactical__actionTargetEid : EntityId;
                                            squadAI_tactical__actionPosFrom : float3;
                                            squadAI_tactical__actionPosDir : float3;
                                            squadAI_tactical__actionPosTo : float3;
                                            squadAI_tactical__actionTimeout : float)
        if squadAI_tactical__actionType < 0
          done = false
          return
        if checkTimeout && squadAI_tactical__actionTimeout >= 0.0 && get_sync_time() >= squadAI_tactical__actionTimeout
          done = reset_action(squad_member__squad)
          return
        let distSq = distance_sq(transform[3], squadAI_tactical__actionPosFrom)
        if distSq > square(REACH_POS_MAXDIST)
          done = reset_action(squad_member__squad)
          return
        if squadAI_tactical__actionType == 0 
          if distSq < square(REACH_POS_DISTANCE)
            squadAI_tactical__actionType = -1
            done = false
            return
        if outActionTypeParam >= 0
          owner.blackBoard |> set(outActionTypeParam, squadAI_tactical__actionType)
        if outActionTargetEidParam >= 0
          owner.blackBoard |> set(outActionTargetEidParam, int(uint(squadAI_tactical__actionTargetEid)))
        if outActionPosFromParam >= 0
          owner.blackBoard |> set(outActionPosFromParam, squadAI_tactical__actionPosFrom)
        if outActionPosLookParam >= 0
          owner.blackBoard |> set(outActionPosLookParam, squadAI_tactical__actionPosFrom + squadAI_tactical__actionPosDir * DEF_LOOK_DIST)
        if outActionPosToParam >= 0
          owner.blackBoard |> set(outActionPosToParam, squadAI_tactical__actionPosTo)
        done = true
    return done ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="buildSquadPathNextAdvanceAction")]
class BuildSquadPathNextAdvanceAction : BehNodeAdapter
  outActionPosFromParam : int = -1

  useRecons : bool = true
  useReconsParam : int = -1

  ACTION_ADVANCE_FORWARD : int = 0
  TIMEOUT_ADVANCE_FORWARD : float = 20.0
  TIMEOUT_ADVANCE_FORWARD_BLOCKED : float = 15.0

  ACTION_PLANT_DESTR_WALL : int = 1
  TIMEOUT_PLANT_MINE : float = 25.0

  ACTION_ADVANCE_CORNER_1 : int = 2
  TIMEOUT_ADVANCE_CORNER_1 : float = 10.0

  def override loadFromBlk(var data : DataBlock)
    if datablock_find_param(data, "outActionPosFromParam") >= 0
      outActionPosFromParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outActionPosFromParam", ""), float3())
    useRecons = data |> datablock_getBool("useRecons", useRecons)
    if datablock_find_param(data, "useReconsParam") >= 0
      useReconsParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "useReconsParam", ""), 0)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var agentPos = float3()
    var agentSquad = INVALID_ENTITY_ID
    var agentTeam = TEAM_UNASSIGNED
    var hasAgentInfo = false
    query(agentEid) <| $ [es] (transform : float3x4; squad_member__squad : EntityId; team : int = TEAM_UNASSIGNED)
      agentPos = transform[3]
      agentSquad = squad_member__squad
      agentTeam = team
      hasAgentInfo = true
    if !hasAgentInfo
      return EBehResult.ER_FAILED

    let detailStep = 0.5
    let advanceDistRange = float2(30.0, 40.0)
    let advanceDist = rnd_float(advanceDistRange.x, advanceDistRange.y)
    let stopAtBlocked = true

    var found = false
    var foundPos = float3()
    var foundPrevPos = float3()
    var foundBlocked = false

    query(agentSquad) <| $ [es] (var squadAI_tactical__path : Point3List&)
      assume path = squadAI_tactical__path
      let len = length(path)
      if len <= 1
        return
      var foundIdx = 0

      var atPos = path[0]
      var prevPos = atPos
      var distLeft = advanceDist
      for i in range(1, len)
        var nextPos = path[i]
        let delta = nextPos - atPos
        var dist = length(delta)
        if dist <= 0.0
          atPos = nextPos
          continue
        if distLeft < dist
          nextPos = lerp(atPos, nextPos, distLeft / dist)
          dist = distLeft
          distLeft = 0.0
        else
          distLeft -= dist
        
        if stopAtBlocked
          let steps = max(1, int(floor((dist + detailStep * 0.5) / detailStep)))
          for step in range(0, steps)
            let pos = lerp(atPos, nextPos, float(step + 1) / float(steps))
            
            var triangle : NavMeshTriangle
            if get_triangle_by_pos_ex(NM_MAIN, pos, 0.1, triangle)
              var flags : uint16
              get_poly_flags_ex(NM_MAIN, triangle.polyRef, flags)
              if (uint(flags) & uint(PolyFlag.POLYFLAG_BLOCKED)) != 0u
                found = true
                foundIdx = i
                foundPos = pos
                foundPrevPos = prevPos
                foundBlocked = true
                
                break
            prevPos = pos
          if found
            break
        if distLeft <= 0.0 || i == len - 1
          found = true
          foundIdx = i
          foundPos = nextPos
          foundPrevPos = nextPos
          foundBlocked = false
          break
        prevPos = atPos
        atPos = nextPos

      if found && !is_point_safe(foundPos, agentTeam)
        var distFromStart = 0.0
        for i in range(1, foundIdx + 1)
          distFromStart += distance(path[i - 1], path[i])

        let searchDist = 30.0
        let minDistFromStart = 15.0
        let maxBackwardsPossible = max(0.0, distFromStart - minDistFromStart)
        let searchBackwardsDist = min(searchDist, maxBackwardsPossible)
        var foundSafe = false
        var backwardDist = 0.0
        var bIdx = foundIdx

        while !foundSafe && bIdx > 0 && backwardDist < searchBackwardsDist
          let p0 = path[bIdx]
          let p1 = path[bIdx - 1]
          let segLen = distance(p0, p1)
          if backwardDist + segLen > searchBackwardsDist
            let remain = searchBackwardsDist - backwardDist
            let pos = lerp(p0, p1, safediv(remain, segLen))
            backwardDist = searchBackwardsDist
            if is_point_safe(pos, agentTeam)
              foundSafe = true
              foundIdx = bIdx
              foundPos = pos
              break
          else
            backwardDist += segLen
            if is_point_safe(p1, agentTeam)
              foundSafe = true
              foundIdx = bIdx
              foundPos = p1
              break
          bIdx -= 1

        if !foundSafe
          var fIdx = foundIdx
          var forwardDist = 0.0
          while !foundSafe && fIdx < len - 1 && forwardDist < searchDist
            let p0 = path[fIdx]
            let p1 = path[fIdx + 1]
            let segLen = distance(p0, p1)
            if forwardDist + segLen > searchDist
              let remain = searchDist - forwardDist
              let pos = lerp(p0, p1, safediv(remain, segLen))
              forwardDist = searchDist
              if is_point_safe(pos, agentTeam)
                foundSafe = true
                foundIdx = fIdx
                foundPos = pos
                break
            else
              forwardDist += segLen
              if is_point_safe(p1, agentTeam)
                foundSafe = true
                foundPos = p1
                foundIdx = fIdx
                break
            fIdx += 1

      if !found
        return

      let tryRecons = (useReconsParam >= 0) ? (owner.blackBoard |> datablock_getInt(useReconsParam) > 0) : useRecons;
      if tryRecons && check_corner_action(agentPos, path, foundIdx, length(path), agentSquad, foundPos, agentTeam)
        if length(path) < 2
          found = false
        else
          found = true
          foundBlocked = false
          if outActionPosFromParam >= 0
            owner.blackBoard |> set(outActionPosFromParam, foundPos)
        return

      for _j in range(foundIdx)
        path |> erase(0)
      if length(path) < 2
        found = false
        return

      found = false
      query(agentSquad) <| $ [es] (var squadAI_tactical__actionType : int&;
                                   var squadAI_tactical__actionTargetEid : EntityId&;
                                   var squadAI_tactical__actionPosFrom : float3&;
                                   var squadAI_tactical__actionPosDir : float3&;
                                   var squadAI_tactical__actionPosTo : float3&;
                                   var squadAI_tactical__actionTimeout : float&)
        if foundBlocked
          let blockerEid = find_blocker_entity_at_pos(foundPos)
          if blockerEid != INVALID_ENTITY_ID
            let checkAgentHasBomb = true
            var plantPos = float3()
            if get_entity_destr_wall_plant_mine_pos(agentEid, blockerEid, checkAgentHasBomb, plantPos)
              squadAI_tactical__actionType = ACTION_PLANT_DESTR_WALL
              squadAI_tactical__actionTargetEid = blockerEid
              squadAI_tactical__actionPosFrom = foundPrevPos
              squadAI_tactical__actionPosDir = float3()
              squadAI_tactical__actionPosTo = plantPos
              squadAI_tactical__actionTimeout = get_sync_time() + TIMEOUT_PLANT_MINE
              found = true
              
        if !found
          squadAI_tactical__actionType = ACTION_ADVANCE_FORWARD
          squadAI_tactical__actionTargetEid = INVALID_ENTITY_ID
          squadAI_tactical__actionPosFrom = foundPos
          squadAI_tactical__actionPosDir = float3()
          squadAI_tactical__actionPosTo = foundPos
          squadAI_tactical__actionTimeout = get_sync_time() + TIMEOUT_ADVANCE_FORWARD
          if foundBlocked
            squadAI_tactical__actionTimeout = get_sync_time() + TIMEOUT_ADVANCE_FORWARD_BLOCKED
          found = true
          

        if found
          if outActionPosFromParam >= 0
            owner.blackBoard |> set(outActionPosFromParam, squadAI_tactical__actionPosFrom)

    return found ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

  def walk_seg_intersects_recon_danger_zone(prev_pos : float3; next_pos : float3;
                                            min_radius_sq : float; max_radius_sq : float;
                                            pos : float3; dir1 : float3; dir2 : float3;
                                            var out_look_dir : float3&)
    let MAX_HEIGHT_DOWN = 3.5
    if prev_pos.y < pos.y - MAX_HEIGHT_DOWN && next_pos.y < pos.y - MAX_HEIGHT_DOWN
      return false
    let MAX_HEIGHT_UP = 3.5
    if prev_pos.y > pos.y + MAX_HEIGHT_UP && next_pos.y > pos.y + MAX_HEIGHT_UP
      return false

    let MIN_DIST_SQ = min_radius_sq
    let MAX_DIST_SQ = max_radius_sq
    let distSq1 = distance_sq(prev_pos, pos)
    let distSq2 = distance_sq(next_pos, pos)
    if distSq1 < MIN_DIST_SQ || distSq2 < MIN_DIST_SQ
      return false
    if distSq1 > MAX_DIST_SQ && distSq2 > MAX_DIST_SQ
      return false

    let nx1 = -dir1.z; let nz1 = dir1.x; let add1 = -(nx1 * pos.x + nz1 * pos.z)
    let nx2 = dir2.z; let nz2 = -dir2.x; let add2 = -(nx2 * pos.x + nz2 * pos.z)
    let was1 = nx1 * prev_pos.x + nz1 * prev_pos.z + add1 > 0.0
    let was2 = nx2 * prev_pos.x + nz2 * prev_pos.z + add2 > 0.0
    if was1 == was2
      return false
    if was1
      let now2 = nx2 * next_pos.x + nz2 * next_pos.z + add2 > 0.0
      if now2
        out_look_dir = dir2
        return true
      return false
    let now1 = nx1 * next_pos.x + nz1 * next_pos.z + add1 > 0.0
    if now1
      out_look_dir = dir1
      return true
    return false

  def check_corner_action(agent_pos : float3; var path : Point3List&;
                          max_idx : int; total_num_idx : int;
                          agent_squad : EntityId; var out_found_pos : float3&;
                          agent_team : int)
    if empty(path)
      return false

    let MIN_RADIUS = cvt(float(total_num_idx), 25.0, 75.0, 0.5, 3.0)
    let MAX_RADIUS = 50.0
    let CLOSE_RADIUS = 3.5

    let pathStart = path[0]
    let pathTo = path[max_idx]
    let pathEnd = path[length(path) - 1]
    let pathCenter = (pathStart + pathTo) * 0.5
    let scanRadius = distance(pathCenter, pathStart) + MAX_RADIUS

    var dangerPos : array<float3>
    query() <| $ [es] (squad__leader : EntityId)
      query(squad__leader) <| $ [es] (transform : float3x4; team : int)
        if team != agent_team
          dangerPos |> push(transform[3])
    dangerPos |> push(pathEnd)

    let MIN_RADIUS_SQ = square(MIN_RADIUS)
    let MAX_RADIUS_SQ = square(MAX_RADIUS)
    let CLOSE_RADIUS_SQ = square(CLOSE_RADIUS)

    let COS_18 = 0.95
    let COS_30 = 0.87
    let COS_60 = 0.50

    
    
    
    
    
    

    let MAX_STEPS_AHEAD = 32
    let MAX_RECONS_AROUND = 500

    var stopIdx = -1
    var stopPos = float3()
    var stopDir = float3()
    var limitIdx = min(MAX_STEPS_AHEAD, max_idx)
    var fullRecons = MAX_RECONS_AROUND
    scan_recons_corners(pathCenter, scanRadius) <| $(pos : float3; dir1 : float3; dir2 : float3)
      if fullRecons > 0
        --fullRecons
      
      var idx = 1
      var prevPos = path[0]
      var mmm = 0
      while idx < limitIdx
        ++mmm
        let nextPos = path[idx]
        var lookDir = float3()
        if distance_sq(agent_pos, nextPos) > MIN_RADIUS_SQ && (fullRecons > 0 || distance_sq(nextPos, pos) < CLOSE_RADIUS_SQ)
          if walk_seg_intersects_recon_danger_zone(prevPos, nextPos, MIN_RADIUS_SQ, MAX_RADIUS_SQ, pos, dir1, dir2, lookDir)
            let forwCoef = dot(normalize(pathTo - prevPos), lookDir)
            if forwCoef < COS_18
              if forwCoef > COS_60 || dot(normalize(pathEnd - prevPos), lookDir) > COS_18
                var anyGood = false
                if rnd_float(0.0, 1.0) < 0.1
                  anyGood = true
                else
                  for dangerPt in dangerPos
                    if dot(normalize(dangerPt - prevPos), lookDir) > COS_30
                      anyGood = true
                      break
                if anyGood
                  let fromPos = nextPos + float3(0.0, 1.5, 0.0)
                  let tracePos = pos - (dir1 * 0.1 + dir2 * 0.1) + float3(0.0, 1.5, 0.0)
                  let traceDir = normalize(tracePos - fromPos)
                  let traceDist = 15.0
                  
                  if !rayhit_normalized(fromPos, traceDir, traceDist, ETF_ALL, -1)
                    if stopIdx < 0 || idx < stopIdx
                      
                      
                      
                      stopIdx = idx
                      stopPos = pos
                      stopDir = lookDir
                      limitIdx = min(limitIdx, idx + 2)
                    break
        prevPos = nextPos
        ++idx
      
      
      
      
    
    
    if stopIdx < 0
      return false

    var result = false
    query(agent_squad) <| $ [es] (var squadAI_tactical__actionType : int&;
                                  var squadAI_tactical__actionTargetEid : EntityId&;
                                  var squadAI_tactical__actionPosFrom : float3&;
                                  var squadAI_tactical__actionPosDir : float3&;
                                  var squadAI_tactical__actionPosTo : float3&;
                                  var squadAI_tactical__actionTimeout : float&)
      squadAI_tactical__actionType = ACTION_ADVANCE_CORNER_1
      squadAI_tactical__actionTargetEid = INVALID_ENTITY_ID
      squadAI_tactical__actionPosFrom = path[max(1, stopIdx - 5)]
      squadAI_tactical__actionPosDir = stopDir
      squadAI_tactical__actionPosTo = path[stopIdx]
      squadAI_tactical__actionTimeout = get_sync_time() + TIMEOUT_ADVANCE_CORNER_1
      

      
      
      

      out_found_pos = path[stopIdx - 1]
      for _j in range(stopIdx)
        path |> erase(0)
      result = true

      
      
      
    return result

[beh_node(name="displayDebugMarker")]
class DisplayDebugMarker : BehNodeAdapter
  showTime : float = 1.0
  thinkMark : string
  lookColorIdx : int = -1

  posParam : int = -1
  posMark : string
  sphereRadius : float = 0.0
  sphereColorIdx : int = -1

  forTeam : int = -1
  bySingle : int = -1
  byEid : int = 0

  ADD_DEBUG_MARKERS_ENABLED : bool = false

  def override loadFromBlk(data : DataBlock) : void
    showTime = datablock_getReal(data, "showTime", showTime)
    thinkMark = datablock_getStr(data, "thinkMark", thinkMark)
    lookColorIdx = datablock_getInt(data, "lookColorIdx", lookColorIdx)

    if datablock_find_param(data, "posParam") >= 0
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    posMark = datablock_getStr(data, "posMark", posMark)
    sphereRadius = datablock_getReal(data, "sphereRadius", sphereRadius)
    sphereColorIdx = datablock_getInt(data, "sphereColorIdx", sphereColorIdx)
    forTeam = datablock_getInt(data, "forTeam", forTeam)
    bySingle = datablock_getInt(data, "bySingle", bySingle)
    byEid = datablock_getInt(data, "byEid", byEid)

  def add_squad_ai_debug_element(squad_eid : EntityId; elem_type : int; elem_p1 : float3; elem_p2 : float3;
                                 elem_text : string; elem_cidx : int; elem_end_time : float; cur_time : float)
    query(squad_eid) <| $ [es] (squadAIDebug__maxDraws : int = 64;
                                var squadAIDebug__drawTypes : IntList&;
                                var squadAIDebug__drawPoint1 : Point3List&;
                                var squadAIDebug__drawPoint2 : Point3List&;
                                var squadAIDebug__drawTexts : StringList&;
                                var squadAIDebug__drawColorIdx : IntList&;
                                var squadAIDebug__drawEndTimes : FloatList&)
      var freeIdx = -1
      for idx, endTime in iter_range(squadAIDebug__drawEndTimes), squadAIDebug__drawEndTimes
        if cur_time > endTime
          freeIdx = idx
          break
      if freeIdx < 0
        let num = length(squadAIDebug__drawEndTimes)
        if num >= squadAIDebug__maxDraws
          return
        freeIdx = num
        squadAIDebug__drawTypes |> push(-1)
        squadAIDebug__drawPoint1 |> push(float3())
        squadAIDebug__drawPoint2 |> push(float3())
        squadAIDebug__drawTexts |> push("")
        squadAIDebug__drawColorIdx |> push(-1)
        squadAIDebug__drawEndTimes |> push(0.0)

      squadAIDebug__drawTypes[freeIdx] = elem_type
      squadAIDebug__drawPoint1[freeIdx] = elem_p1
      squadAIDebug__drawPoint2[freeIdx] = elem_p2
      squadAIDebug__drawTexts[freeIdx] := elem_text
      squadAIDebug__drawColorIdx[freeIdx] = elem_cidx
      squadAIDebug__drawEndTimes[freeIdx] = elem_end_time

  def override update(dt : float) : EBehResult
    if !ADD_DEBUG_MARKERS_ENABLED
      return EBehResult.ER_SUCCESS
    if showTime <= 0.0
      return EBehResult.ER_SUCCESS

    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId; team : int; transform : float3x4)
      if forTeam >= 1 && team != forTeam
        return
      if byEid != 0
        if int(uint(agentEid)) != byEid && int(uint(squad_member__squad)) != byEid
          return
      if bySingle >= 0
        var matched = false
        query(squad_member__squad) <| $ [es] (var squadAIDebug__singleId : int&)
          if squadAIDebug__singleId < 0
            query() <| $ [es] (var squadsAIDebug__nextSingleId : int&)
              squadAIDebug__singleId = squadsAIDebug__nextSingleId
              squadsAIDebug__nextSingleId += 1
          if bySingle == squadAIDebug__singleId
            matched = true
        if !matched
          return

      let curTime = get_sync_time()

      if !empty(thinkMark)
        let posOverAgent = transform[3] + float3(0.0, 2.0, 0.0)
        add_squad_ai_debug_element(squad_member__squad, 2, posOverAgent, float3(), thinkMark, -1, curTime + showTime, curTime)

      if posParam >= 0
        let posTarget = owner.blackBoard |> datablock_getPoint3(posParam)
        if lookColorIdx >= 0
          let posLookAgent = transform[3] + float3(0.0, 1.5, 0.0)
          let posToTarget = posTarget + float3(0.0, 1.5, 0.0)
          add_squad_ai_debug_element(squad_member__squad, 0, posLookAgent, posToTarget, "", lookColorIdx, curTime + showTime, curTime)

        if sphereRadius > 0.0 && sphereColorIdx >= 0
          add_squad_ai_debug_element(squad_member__squad, 1, posTarget, float3(sphereRadius, curTime, 0.0), "", sphereColorIdx, curTime + showTime, curTime)

        if !empty(posMark)
          let posOverTarget = posTarget + float3(0.0, 2.0, 0.0)
          add_squad_ai_debug_element(squad_member__squad, 2, posOverTarget, float3(), posMark, -1, curTime + showTime, curTime)

    return EBehResult.ER_SUCCESS

[beh_node(name="setDebugSym")]
class SetDebugSym : BehNodeAdapter
  symB : int = -1
  idxB : int = -1
  symA : int = -1
  idxA : int = -1
  idxR : int = -1

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "beh") >= 0
      let str = data |> datablock_getStr("beh", "")
      let len = length(str)
      if len > 0
        symB = character_at(str, 0)
        idxB = to_int(slice(str, 1, len))

    if datablock_find_param(data, "act") >= 0
      let str = data |> datablock_getStr("act", "")
      let len = length(str)
      if len > 0
        symA = character_at(str, 0)
        idxA = to_int(slice(str, 1, len))

    idxR = data |> datablock_getInt("r", 0)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    query(agent.eid) <| $ [es] (var beh_tree__debugSym1 : int3&;
                                var beh_tree__debugSym2 : int3&;
                                var beh_tree__debugSym3 : int3&;
                                var beh_tree__debugSymU : int3&)
      if symB > 0
        beh_tree__debugSym1.x = symB
        beh_tree__debugSym1.y = idxB
        beh_tree__debugSym1.z = 0
        beh_tree__debugSym2.x = 0
        beh_tree__debugSymU.x += 1
      if symA > 0
        
        beh_tree__debugSym1.z = symA
        beh_tree__debugSym2.x = idxA
        beh_tree__debugSymU.y += 1
      if idxR > 0
        
        if idxR == abs(beh_tree__debugSym2.y)
          beh_tree__debugSym2.y = -beh_tree__debugSym2.y
        else
          beh_tree__debugSym2.y = idxR
        beh_tree__debugSym2.z = beh_tree__debugSym1.x
        beh_tree__debugSym3.x = beh_tree__debugSym1.y
        beh_tree__debugSym3.y = beh_tree__debugSym1.z
        beh_tree__debugSym3.z = beh_tree__debugSym2.x
        beh_tree__debugSymU.z += 1
    return EBehResult.ER_SUCCESS


def ai_switch_behavior_to(agentEid : EntityId; switchTo : string)
  createEntity("ai_switch_behavior") <| $(init)
    init |> set("ai_switch_behavior__agentEid", agentEid)
    init |> set("ai_switch_behavior__switchTo", switchTo)

[es(tag=server, on_appear)]
def ai_switch_behavior_es(evt : Event;
                          eid : EntityId;
                          ai_switch_behavior__agentEid : EntityId;
                          ai_switch_behavior__switchTo : string)
  if ai_switch_behavior__switchTo == ""
    logerr("Could not switch behaviour to \"\"")
    destroyEntity(eid)
    return
  query(ai_switch_behavior__agentEid) <| $ [es] (var beh_tree__node : das_string&)
    beh_tree__node := ai_switch_behavior__switchTo
    reload_squad_mate_beh_tree(ai_switch_behavior__agentEid)
  destroyEntity(eid)

[beh_node(name="switchAIBehavior")]
class SwitchAIBehavior : BehNodeAdapter
  switchTo : string
  def override loadFromBlk(data : DataBlock) : void
    switchTo = datablock_getStr(data, "to", "")
  def override update(dt : float) : EBehResult
    ai_switch_behavior_to(beh_tree_eid(owner), switchTo)
    return EBehResult.ER_SUCCESS


[beh_node(name="isSquadLeaderInVehicle")]
class IsSquadLeaderInVehicle : BehNodeAdapter
  vehicleEidOutParam : int = -1
  checkIsInSameVehicle : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    checkIsInSameVehicle = datablock_getBool(data, "checkIsInSameVehicle", checkIsInSameVehicle)
    if datablock_find_param(data, "vehicleEidOutParam") >= 0
      vehicleEidOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "vehicleEidOutParam", ""), 0)

  def override update(dt : float) : EBehResult
    let soldierEid = beh_tree_eid(owner)

    var leaderVehicleEid = INVALID_ENTITY_ID
    var isSquadLeaderInVehicle = false
    query(soldierEid) <| $ [es] (squad_member__squad : EntityId;
                                 human_anim__vehicleSelected aka hero_human_anim__vehicleSelected : EntityId)
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
        query(squad__leader) <| $ [es] (isInVehicle : bool;
                                        human_anim__vehicleSelected aka leader_human_anim__vehicleSelected : EntityId)
          isSquadLeaderInVehicle = isInVehicle
          if checkIsInSameVehicle && isInVehicle
            isSquadLeaderInVehicle = leader_human_anim__vehicleSelected == hero_human_anim__vehicleSelected
          if isSquadLeaderInVehicle
            leaderVehicleEid = leader_human_anim__vehicleSelected

    if vehicleEidOutParam >= 0
      owner.blackBoard |> set(vehicleEidOutParam, int(uint(leaderVehicleEid)))

    return isSquadLeaderInVehicle ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED















[beh_node(name="stopSpeed")]
class StopSpeed : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (var human_net_phys : HumanActor&)
      human_net_phys.phys.producedCT |> human_control_state_set_walk_speed(0.0)
    return EBehResult.ER_SUCCESS


[beh_node(name="findDangerHostileVehicle")]
class FindDangerHostileVehicle : BehNodeAdapter
  outSafePosParam : int = -1
  outEscapeTypeParam : int = -1
  wishPosParam : int = -1
  vehicleParams : VehicleDangerZoneParams = VehicleDangerZoneParams()
  turretParams : TurretDangerZoneParams = TurretDangerZoneParams()
  wishPosMaxDist : float = 30.0 
  escapeRadius : float = 15.0 

  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "outSafePosParam") >= 0
      outSafePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outSafePosParam", ""), float3())
    if datablock_find_param(data, "outEscapeTypeParam") >= 0
      outEscapeTypeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outEscapeTypeParam", ""), -1)
    if datablock_find_param(data, "wishPosParam") >= 0
      wishPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "wishPosParam", "wishPosition"), float3())

    wishPosMaxDist = datablock_getReal(data, "wishPosMaxDist", wishPosMaxDist)
    escapeRadius = datablock_getReal(data, "escapeRadius", escapeRadius)

    vehicleParams.maxSpeed = datablock_getReal(data, "vehicleMaxSpeed", vehicleParams.maxSpeed) 
    vehicleParams.minSpeed = datablock_getReal(data, "vehicleMinSpeed", vehicleParams.minSpeed) 
    vehicleParams.effectiveSpeedExp = datablock_getReal(data, "vehicleEffectiveSpeedExp", vehicleParams.effectiveSpeedExp)
    vehicleParams.maxPath = datablock_getReal(data, "vehicleMaxPath", vehicleParams.maxPath) 
    vehicleParams.maxDeviationAngle = datablock_getReal(data, "vehicleMaxDeviationAngle", vehicleParams.maxDeviationAngle) 
    vehicleParams.drivingTime = datablock_getReal(data, "vehicleDrivingTime", vehicleParams.drivingTime) 
    turretParams.maxDeviationAngle = datablock_getReal(data, "turretMaxDeviationAngle", turretParams.maxDeviationAngle) 
    turretParams.maxShootDistance = datablock_getReal(data, "turretMaxShootDistance", turretParams.maxShootDistance) 

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var isInDanger = false

    query(agentEid) <| $ [es] (team : int; transform : float3x4; walker_agent : EntityAgent)
      let playerTeam = team
      let agentPos = transform[3]

      var vehicleDatas : array<VehicleDangerZoneData>
      var turretDatas : array<TurretDangerZoneData>
      gather_danger_vehicle_and_turret_data(agentPos, playerTeam, vehicleParams, turretParams, vehicleDatas, turretDatas)
      if length(vehicleDatas) == 0
        return

      var dangerPos = agentPos
      isInDanger = is_agent_in_vehicle_danger_zones(dangerPos, vehicleDatas, turretDatas)

      var checkPositions : array<float3>
      if !isInDanger
        get_agent_path(walker_agent) <| $(path)
          let numPoints = length(path)
          if numPoints <= 1
            return
          let distThreshold = 1.0
          if distance_sq(path[numPoints - 1], path[0]) < square(distThreshold)
            return
          let pathCheckPointCount = 3
          let pathCheckInterval = 5.0
          var accumulatedDist = 0.0
          var nextCheckDist = pathCheckInterval
          var found = false
          for j in range(numPoints - 1)
            assume pt1 = path[j]
            assume pt2 = path[j + 1]
            let segmentVec = pt2 - pt1
            let segmentDist = length(segmentVec)
            while accumulatedDist + segmentDist >= nextCheckDist
              let t = (nextCheckDist - accumulatedDist) / segmentDist
              let checkPos = pt1 + segmentVec * t
              checkPositions |> push(checkPos)
              if length(checkPositions) >= pathCheckPointCount
                found = true
                break
              nextCheckDist += pathCheckInterval
            if found
              break
            accumulatedDist += segmentDist
          if length(checkPositions) < pathCheckPointCount
            checkPositions |> push(path[numPoints - 1])

        for pos in checkPositions
          if is_agent_in_vehicle_danger_zones(pos, vehicleDatas)
            isInDanger = true
            dangerPos = pos
            break

      if isInDanger && outSafePosParam >= 0 && wishPosParam >= 0
        let wishPos = owner.blackBoard |> datablock_getPoint3(wishPosParam)
        var outEscapeType = DangerEscapeType.ESCAPE_HIDE
        let safePos = find_safe_point_from_vehicles(agentPos, dangerPos, wishPos, escapeRadius, vehicleDatas, turretDatas, outEscapeType)
        if safePos != float3()
          owner.blackBoard |> set(outSafePosParam, safePos)
          if outEscapeTypeParam >= 0
            owner.blackBoard |> set(outEscapeTypeParam, int(outEscapeType))

    return isInDanger ? EBehResult ER_SUCCESS : EBehResult ER_FAILED

[beh_node(name="findAttackVehicleTargetForOrder")]
class FindAttackVehicleTargetForOrder : BehNodeAdapter
  outTargetVehicleEidParam : int = -1
  outExecutorEidParam : int = -1
  outShootPosFromParam : int = -1
  outShootPosToParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "outTargetVehicleEidParam") >= 0
      outTargetVehicleEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outTargetVehicleEidParam", ""), int(uint(INVALID_ENTITY_ID)))
    if datablock_find_param(data, "outExecutorEidParam") >= 0
      outExecutorEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outExecutorEidParam", ""), int(uint(INVALID_ENTITY_ID)))
    if datablock_find_param(data, "outShootPosFromParam") >= 0
      outShootPosFromParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outShootPosFromParam", ""), float3())
    if datablock_find_param(data, "outShootPosToParam") >= 0
      outShootPosToParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outShootPosToParam", ""), float3())

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var foundTarget = false
    var executorEid = INVALID_ENTITY_ID
    var shootPosFrom = float3()
    var shootPosTo = float3()
    query(agentEid) <| $ [es] (transform aka agent_transform : float3x4; squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (squadAI_tactical__vehicleTargetsEids : EidList; squad__allMembers : EidList; squad__leader : EntityId)
        var candidates : array<EntityId>
        if !find_attack_vehicle_squad_candidates(squad__allMembers, squad__leader, true, false, candidates)
          return

        var bestDistSq = FLT_MAX
        var bestEid = INVALID_ENTITY_ID
        for targetEid in squadAI_tactical__vehicleTargetsEids
          query(targetEid) <| $ [es(REQUIRE=unit_tag__tank)] (transform aka target_transform : float3x4; unit__ref : UnitRef)
            let unit = unit__ref.unit
            if unit != null && unit.isAlive
              let distSq = distance_sq(agent_transform[3], target_transform[3])
              if distSq < bestDistSq && find_attack_vehilce_executor_and_positions(candidates, targetEid, executorEid, shootPosTo, shootPosFrom)
                bestDistSq = distSq
                bestEid = targetEid

        if bestEid != INVALID_ENTITY_ID
          if outTargetVehicleEidParam >= 0
            owner.blackBoard |> set(outTargetVehicleEidParam, int(uint(bestEid)))
          if outExecutorEidParam >= 0
            owner.blackBoard |> set(outExecutorEidParam, int(uint(executorEid)))
          if outShootPosFromParam >= 0
            owner.blackBoard |> set(outShootPosFromParam, shootPosFrom)
          if outShootPosToParam >= 0
            owner.blackBoard |> set(outShootPosToParam, shootPosTo)
          foundTarget = true

    return foundTarget ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="giveOrder")]
class GiveOrder : BehNodeAdapter
  orderType : string = ""
  orderUseEntityEidParam : int = -1
  executorEidParam : int = -1
  shootPosFromParam : int = -1
  shootPosToParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    orderType = datablock_getStr(data, "orderType", orderType)
    if datablock_find_param(data, "orderUseEntityEidParam") >= 0
      orderUseEntityEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "orderUseEntityEidParam", ""), int(uint(INVALID_ENTITY_ID)))
    if datablock_find_param(data, "executorEidParam") >= 0
      executorEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "executorEidParam", ""), int(uint(INVALID_ENTITY_ID)))
    if datablock_find_param(data, "shootPosFromParam") >= 0
      shootPosFromParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "shootPosFromParam", ""), float3())
    if datablock_find_param(data, "shootPosToParam") >= 0
      shootPosToParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "shootPosToParam", ""), float3())

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var orderUseEntity = INVALID_ENTITY_ID
    var executorEid = INVALID_ENTITY_ID
    var shootPosFrom = float3()
    var shootPosTo = float3()
    if orderUseEntityEidParam >= 0
      orderUseEntity = EntityId(uint(owner.blackBoard |> datablock_getInt(orderUseEntityEidParam)))
    if executorEidParam >= 0
      executorEid = EntityId(uint(owner.blackBoard |> datablock_getInt(executorEidParam)))
    if shootPosFromParam >= 0
      shootPosFrom = owner.blackBoard |> datablock_getPoint3(shootPosFromParam)
    if shootPosToParam >= 0
      shootPosTo = owner.blackBoard |> datablock_getPoint3(shootPosToParam)

    if orderType == "attack_vehicle"
      let vehicleTransform = get_TMatrix(orderUseEntity, "transform") ?? IDENT_TM
      let localPosTo = inverse(vehicleTransform) * shootPosTo
      send_net_event(executorEid, RequestPersonalSquadMateOrder(orderType = int(SquadMateOrder.ESMO_ATTACK_VEHICLE), orderPosition = shootPosFrom, orderToPosition = localPosTo, orderUseEntity = orderUseEntity))
      return EBehResult.ER_SUCCESS

    return EBehResult.ER_FAILED


[beh_node(name="isAgentPlayerBot")]
class IsAgentPlayerBot : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var isBot = false
    query(beh_tree_eid(owner)) <| $ [es] (squad_member__playerEid : EntityId)
      query(squad_member__playerEid) <| $ [es(REQUIRE=playerIsBot)] ()
        isBot = true
    return isBot ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isPossessedAgent")]
class IsPossessedAgent : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var result = false
    query(beh_tree_eid(owner)) <| $ [es] (possessedByPlr : EntityId)
      if possessedByPlr != INVALID_ENTITY_ID
        result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="extinguish")]
class Extinguish : BehNodeAdapter
  eventSent : bool = false

  def override init()
    eventSent = false

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    if !eventSent
      eventSent = true
      send_net_event(eid, CmdPutOutFireStart())

    let burning = get_bool(eid, "burning__isBurning") ?? false
    return burning ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS

[beh_node(name="speak")]
class SpeakNode : BehNodeAdapter
  phrase : string
  srcParamId : int = -1   
  aboutParamId : int = -1 
  timeMinMax : float2 = float2(0, 0)
  nextTime : float = 0.0
  isEffect : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    phrase = datablock_getStr(data, "phrase", "")
    if phrase == ""
      isEffect = true
      phrase = datablock_getStr(data, "effect", "")
    timeMinMax = datablock_getPoint2(data, "timeMinMax", timeMinMax)
    if datablock_find_param(data, "sourceParam") >= 0
      srcParamId = owner.blackBoard |> get_or_create(datablock_getStr(data, "sourceParam", ""), int(uint(INVALID_ENTITY_ID)))
    if datablock_find_param(data, "aboutParam") >= 0
      aboutParamId = owner.blackBoard |> get_or_create(datablock_getStr(data, "aboutParam", ""), int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    if timeMinMax.y > 0.0 && timeMinMax.y >= timeMinMax.x
      let cur = get_sync_time()
      if cur < nextTime
        return EBehResult.ER_SUCCESS
      nextTime = cur + rnd_float(timeMinMax.x, timeMinMax.y)

    if srcParamId >= 0
      var ok = false
      query(EntityId(uint(srcParamId))) <| $ [es] (ai_target : Target)
        if ai_target.isAlive
          ok = true
      if !ok
        return EBehResult.ER_FAILED

    if aboutParamId >= 0
      let aboutEid = EntityId(uint(aboutParamId))
      sendEvent(beh_tree_eid(owner), CmdRequestHumanSpeechAbout(phrase = phrase, aboutEid = aboutEid))
    elif isEffect
      sendEvent(beh_tree_eid(owner), CmdRequestHumanVoiceEffect(phrase = phrase))
    else
      sendEvent(beh_tree_eid(owner), CmdRequestHumanSpeech(phrase = phrase, listener = INVALID_ENTITY_ID, exceptPossessed = INVALID_ENTITY_ID))

    return EBehResult.ER_SUCCESS


[beh_node(name="waitForLeaderChangeOrStop")]
class WaitForLeaderChangeOrStop : BehNodeAdapter
  stopMinTime : float = 1.0

  stopTimer : float = 0.0
  wasMoving : bool = false
  wasLeaderEid : uint = uint(0)
  wasMaxDistSq : float = 0.0

  def override loadFromBlk(var data : DataBlock) : void
    stopMinTime = datablock_getReal(data, "stopMinTime", stopMinTime)

  def override init()
    stopTimer = 0.0
    wasMoving = true

    wasLeaderEid = uint(0)
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId; transform aka agent_transform : float3x4)
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
        if squad__leader != agentEid
          query(squad__leader) <| $ [es] (transform aka leader_transform : float3x4)
            wasLeaderEid = uint(squad__leader)
            wasMaxDistSq = distance_sq(agent_transform[3], leader_transform[3])

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_SUCCESS

    let MIN_LEADER_VELOCITY = 0.01

    var hasLeader = false
    var isMoving = false
    var curDistSq = 0.0

    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId; transform aka agent_transform : float3x4)
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
        if squad__leader == agentEid
          return
        if wasLeaderEid != uint(squad__leader)
          return
        query(squad__leader) <| $ [es] (human_net_phys : HumanActor; transform aka leader_transform : float3x4)
          hasLeader = true
          curDistSq = distance_sq(agent_transform[3], leader_transform[3])
          assume currentState = human_net_phys.phys.currentState
          let leaderVelocity = length(currentState.velocity)
          if leaderVelocity > MIN_LEADER_VELOCITY
            isMoving = true

    if isMoving && curDistSq > wasMaxDistSq
      wasMaxDistSq = curDistSq
      stopTimer = 0.0

    stopTimer += dt
    if hasLeader && stopTimer < stopMinTime
      result = EBehResult.ER_RUNNING

    return result
