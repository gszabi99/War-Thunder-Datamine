options always_export_initializer = true

require app
require ecs
require math
require math.base
require math.random
require DagorMath
require DagorMathUtils
require Unit
require Weapon
require %game.utils.utils_common
require Covers
require Dacoll
require BehNodes
require HumanPhys
require DngHuman
require walkerai
require pathfinder
require DngWalkerai
require DagorDataBlock
require %appGame.infantry.es.team_common
require %appGame.infantry.ai.covers_common
require %appGame.infantry.ai.ai_covers_common
require %appGame.infantry.ai.walker_nodes_common
require DagorSystem


[beh_node(name="getCoverPosAndDir")]
class GetCoverPosAndDir : BehNodeAdapter
  coverIndexParam : int = -1
  coverSlotParam : int = -1

  outPosParam : int = -1
  outLeftPosParam : int = -1
  outRightPosParam : int = -1

  lookRandAngle : float = 90.0
  lookDistance : float = 100.0
  lookHeight : float = 1.0
  outLookPosParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    coverIndexParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverIndexParam", ""), -1)
    coverSlotParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverSlotParam", ""), -1)

    if datablock_find_param(data, "outPosParam") >= 0
      outPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3())
    if datablock_find_param(data, "outLeftPosParam") >= 0
      outLeftPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outLeftPosParam", ""), float3())
    if datablock_find_param(data, "outRightPosParam") >= 0
      outRightPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outRightPosParam", ""), float3())

    lookRandAngle = data |> datablock_getReal("lookRandAngle", lookRandAngle)
    lookRandAngle = deg_to_rad(lookRandAngle)

    if datablock_find_param(data, "outLookPosParam") >= 0
      outLookPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outLookPosParam", ""), float3())

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query() <| $ [es] (covers : CoversComponent)
      let coverIndex = owner.blackBoard |> datablock_getInt(coverIndexParam)
      if coverIndex < 0 || coverIndex >= length(covers.list)
        return
      assume coverDesc = covers.coverDescs[coverIndex]
      let coverSlot = owner.blackBoard |> datablock_getInt(coverSlotParam)
      if coverSlot < 0 || coverSlot >= length(coverDesc.slots)
        return
      assume cover = covers.list[coverIndex]
      let pos = get_cover_slot_pos(cover, coverDesc, coverSlot)
      if outPosParam >= 0
        owner.blackBoard |> set(outPosParam, pos)
      if outLeftPosParam >= 0
        owner.blackBoard |> set(outLeftPosParam, get_cover_walkout_pos(cover, -1))
      if outRightPosParam >= 0
        owner.blackBoard |> set(outRightPosParam, get_cover_walkout_pos(cover, 1))
      if outLookPosParam >= 0
        var s, c : float
        sincos(gfrnd() * lookRandAngle - lookRandAngle * 0.5, s, c)
        let right = float3(cover.dir.z, 0.0, -cover.dir.x)
        let lookDir = cover.dir * c + right * s
        owner.blackBoard |> set(outLookPosParam, pos + float3(0.0, lookHeight, 0.0) + lookDir * lookDistance)
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="increaseDangerLevel")]
class IncreaseDangerLevel : BehNodeAdapter
  dangerLevelParam : int = -1
  targetEidParam : int = -1
  factorCoef : float = 0.33

  def override loadFromBlk(data : DataBlock) : void
    dangerLevelParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "paramName", "dangerLevel"), 0.0)
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)
    factorCoef = datablock_getReal(data, "factorCoef", factorCoef)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)

    var agentIsAlive = true
    var agentIsDowned = false
    query(agent.eid) <| $ [es] (isAlive : bool; isDowned : bool)
      agentIsAlive = isAlive
      agentIsDowned = isDowned
    if !agentIsAlive
      return EBehResult.ER_SUCCESS

    var agentTeam = TEAM_UNASSIGNED
    query(agent.eid) <| $ [es] (team : int)
      agentTeam = team

    var factor = 0.0
    var dist = 0.0
    var grenade = false

    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    query(targetEid) <| $ [es] (ai_target : Target;
                                team : int = TEAM_UNASSIGNED;
                                unit__ref aka target_unit__ref : UnitRef const?;
                                human_parachute__isDeployed : bool const?;
                                human_net_phys : HumanActor const?;
                                unit_tag__tank : Tag const?)
      if !ai_target.isAlive || ai_target.isHidden
        return

      let targetTeam = team
      if targetTeam == agentTeam
        return

      let targetUnit = target_unit__ref.unit
      var targetHasTurrets = false
      if targetUnit != null && targetUnit.isVehicle
        let wc = targetUnit.weap
        if length(wc.turret) > 0
          targetHasTurrets = true

      factor = targetHasTurrets ? 2.0 : 1.0
      factor *= ai_target.useVehicle != uint(INVALID_ENTITY_ID) ? 0.5 : 1.0
      factor *= ai_target.isDowned ? 0.25 : 1.0
      let isTargetOnParachute = human_parachute__isDeployed != null ? *human_parachute__isDeployed : false
      if isTargetOnParachute
        factor *= 0.25

      let toTarget = ai_target.targetPos - agent.pos
      dist = length(toTarget)

      if human_net_phys != null
        assume currentState = human_net_phys.phys.currentState
        let gunDir = currentState.gunDir
        let cosCoef = dot(normalize(toTarget), normalize(gunDir))
        if cosCoef < 0.0
          factor *= square(cosCoef)
        else
          factor *= 0.0
      elif targetHasTurrets
        let targetTm = targetUnit.unitTm
        let wc = targetUnit.weap
        var maxTurretCoef = 0.0
        var maxTurretsToLook = 3
        for turret in wc.turret
          let weapon = get_weapon(wc.Weapons, int(turret.triggerNo), int(turret.weaponIndex))
          if weapon == null
            continue
          let gun = as_gun(weapon)
          if gun == null
            continue
          let hasMoreCartridges = gun.currentBulletSet.bulletsCartridge > 1
          let isNowEmpty = gun.currentBulletSet.bulletsCount == 0
          if gun.isInoperable || (!hasMoreCartridges && isNowEmpty)
            continue
          var turretCoef = 0.0
          var gunTm : float3x4
          weapon_calcShootTm(weapon, targetTm, gunTm)
          let gunDir = gunTm[0]
          let cosCoef = dot(normalize(toTarget), normalize(gunDir))
          if cosCoef < 0.0
            turretCoef = square(cosCoef)
          maxTurretCoef = max(maxTurretCoef, turretCoef)
          maxTurretsToLook -= 1
          if maxTurretsToLook <= 0
            break
        factor *= 0.5 + maxTurretCoef * 0.5
      else
        factor *= 0.1

      grenade = unit_tag__tank != null
      if targetUnit != null && targetUnit.isTank
        grenade = true

    let enemyReload = check_human_reload(targetEid)
    if enemyReload < 0
      factor *= 0.25
    elif enemyReload > 0
      factor *= 0.5

    if !grenade && check_human_reload(agent.eid) != 0
      dist = 0.0 

    if agentIsDowned
      factor = 2.0 

    factor *= factorCoef

    if factor > 0.001
      let addup = factor * cvt(dist, 0.0, 300.0, 1.0, 0.3)
      let wasDangerLevel = owner.blackBoard |> datablock_getReal(dangerLevelParam)
      let newDangerLevel = min(wasDangerLevel + addup, 2.0) 
      
      
      if newDangerLevel > wasDangerLevel
        owner.blackBoard |> set(dangerLevelParam, newDangerLevel)

    return EBehResult.ER_SUCCESS

[beh_node(name="decreaseDangerLevel")]
class DecreaseDangerLevel : BehNodeAdapter
  dangerLevelParam : int = -1
  decreaseCoef : float = 0.5

  def override loadFromBlk(data : DataBlock) : void
    dangerLevelParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "paramName", "dangerLevel"), 0.0)
    decreaseCoef = datablock_getReal(data, "decreaseCoef", decreaseCoef)

  def override update(dt : float) : EBehResult
    let wasDangerLevel = owner.blackBoard |> datablock_getReal(dangerLevelParam)
    let newDangerLevel = wasDangerLevel * decreaseCoef
    
    
    if newDangerLevel < wasDangerLevel
      owner.blackBoard |> set(dangerLevelParam, newDangerLevel)
    return EBehResult.ER_SUCCESS


[beh_node(name="chooseMinMaxStancesForCoverAttack")]
class ChooseMinMaxStancesForCoverAttack : BehNodeAdapter
  coverAttackParam : int = -1
  coverAttackTypeParam : int = -1
  maxStanceParam : int = -1
  minStanceParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    coverAttackParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverAttackParam", "coverAttack"), 0)
    coverAttackTypeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverAttackTypeParam", "coverAttackType"), 0)
    maxStanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "maxStanceParam", "maxStance"), 2)
    minStanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "minStanceParam", "minStance"), 0)

  def override update(dt : float) : EBehResult
    let coverAttack = owner.blackBoard |> datablock_getInt(coverAttackParam)
    if coverAttack <= 0
      return EBehResult.ER_FAILED
    let coverAttackType = owner.blackBoard |> datablock_getInt(coverAttackTypeParam)
    if coverAttackType < 0 || coverAttackType > int(CoverAttackType.COUNT)
      return EBehResult.ER_FAILED

    if coverAttack == 1
      let maxStance = cover_hide_max_stances[coverAttackType]
      let minStance = cover_hide_min_stances[coverAttackType]
      owner.blackBoard |> set(maxStanceParam, maxStance)
      owner.blackBoard |> set(minStanceParam, minStance)
      return EBehResult.ER_SUCCESS

    if coverAttack == 2
      let maxStance = cover_attk_max_stances[coverAttackType]
      let minStance = cover_attk_min_stances[coverAttackType]
      owner.blackBoard |> set(maxStanceParam, maxStance)
      owner.blackBoard |> set(minStanceParam, minStance)
      return EBehResult.ER_SUCCESS

    return EBehResult.ER_FAILED

[beh_node(name="changeStanceForCoverAttack")]
class ChangeStanceForCoverAttack : BehNodeAdapter
  coverAttackTypeParam : int = -1
  hide : bool = false

  needStance : int = -1
  needHeight : float = 0.0
  timeout : float = 0.0
  timeoutTime : float = 2.0

  def override loadFromBlk(data : DataBlock) : void
    coverAttackTypeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverAttackTypeParam", "coverAttackType"), 0)
    hide = datablock_getBool(data, "hide", hide)
    timeoutTime = datablock_getReal(data, "timeout", timeoutTime)

  def override init() : void
    needStance = -1
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return
    let coverAttackType = owner.blackBoard |> datablock_getInt(coverAttackTypeParam)
    if coverAttackType < 0 || coverAttackType > int(CoverAttackType.COUNT)
      return

    if hide
      needStance = rnd_int(cover_hide_min_stances[coverAttackType], cover_hide_max_stances[coverAttackType])
    else
      needStance = rnd_int(cover_attk_min_stances[coverAttackType], cover_attk_max_stances[coverAttackType])

    needHeight = float(needStance) - 1.0
    timeout = timeoutTime

  def override update(dt : float) : EBehResult
    if needStance < 0
      return EBehResult.ER_FAILED
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    var atStance = false
    query(agent.eid) <| $ [es] (var human_net_phys : HumanActor&)
      assume phys = human_net_phys.phys
      assume producedCT = phys.producedCT
      assume currHeight = phys.currentState.height
      producedCT |> human_control_state_set_lean_position(0.0)
      producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, needStance == 1)
      producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, needStance == 0)
      let reachEpsilon = 0.01
      if abs(currHeight - needHeight) < reachEpsilon
        atStance = true

    if !atStance
      timeout -= dt
      if timeout < 0.0
        return EBehResult.ER_FAILED
      return EBehResult.ER_RUNNING

    return EBehResult.ER_SUCCESS

[beh_node(name="findCoverForCoverAttack")]
class FindCoverForCoverAttack : BehNodeAdapter
  targetParam : int = -1

  searchRadius : float = 8.0
  minDistToTarget : float = 4.5
  attackAngle : float = 35.0

  searchRadiusSq : float
  minDistToTargetSq : float
  attackCosAngle : float

  maxBehindTarget : float = 2.0

  checkFindPath : bool = true
  checkFindPathDoneLen : int = 10
  avoidRunAlongCos : float = 0.95
  maxAroundLenCoef : float = 1.5
  checkedFindDone : bool = false

  approachPosParam : int = -1
  maxMoveAwayFromApproachPos : float = 5.0

  outCoverAttackTypeParam : int = -1
  outCoverAttackCoverParam : int = -1
  outCoverAttackCoverSlotParam : int = -1

  coverIter : int = 0
  coverIterSlot : int = 0
  approach : bool = false
  approachPos : float3
  hasTargetPos : bool = false
  targetPos : float3
  bbox : bbox3f
  prevCoverId : int2
  agentPos : float3
  distApproachSq : float
  dirToTargetXZ : float3
  bestDistSq : float
  bestCoverId : int2
  bestScore : int
  bestAttack : CoverAttackType
  bestFound : bool = false

  atTime : float

  IGNORE_COVER_TIME = 10.0
  MAX_SLOW_PER_UPDATE = 1

  avoidLeaderActing : LeaderActingInfo

  def override loadFromBlk(data : DataBlock) : void
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

    searchRadius = datablock_getReal(data, "searchRadius", searchRadius)
    minDistToTarget = datablock_getReal(data, "minDistToTarget", minDistToTarget)
    attackAngle = datablock_getReal(data, "attackAngle", attackAngle)

    maxBehindTarget = datablock_getReal(data, "maxBehindTarget", maxBehindTarget)

    searchRadiusSq = square(searchRadius)
    minDistToTargetSq = square(minDistToTarget)
    attackCosAngle = cos(deg_to_rad(attackAngle))

    if datablock_find_param(data, "approachPosParam") >= 0
      approachPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "approachPosParam", ""), float3())
    maxMoveAwayFromApproachPos = datablock_getReal(data, "maxMoveAwayFromApproachPos", maxMoveAwayFromApproachPos)

    outCoverAttackTypeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outCoverAttackTypeParam", "coverAttackType"), 0)
    outCoverAttackCoverParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outCoverAttackCoverParam", "coverAttackCover"), -1)
    outCoverAttackCoverSlotParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outCoverAttackTypeParam", "coverAttackCoverSlot"), 0)

  def override exit() : void
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (var agent__checkCoversList : IntList&)
      agent__checkCoversList |> clear()

  def override init() : void
    coverIter = -1
    coverIterSlot = 0

    hasTargetPos = false
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    query(targetEid) <| $ [es] (ai_target : Target)
      targetPos = ai_target.targetPos
      hasTargetPos = true
    if !hasTargetPos
      return

    approach = false
    approachPos = float3()
    if approachPosParam >= 0
      approach = true
      approachPos = owner.blackBoard |> datablock_getPoint3(approachPosParam)

    var hasAgent = false
    let agentEid = beh_tree_eid(owner)
    prevCoverId = int2(-1, 0)
    query(agentEid) <| $ [es] (var agent__checkCoversList : IntList&;
                               var cover_updater__heldCovers : IPoint2List&;
                               walker_agent : EntityAgent)
      hasAgent = true
      agentPos = walker_agent.pos
      agent__checkCoversList |> clear()

      if length(cover_updater__heldCovers) > 0
        prevCoverId = cover_updater__heldCovers[0]

      query() <| $ [es] (var covers : CoversComponent&)
        reset_covers(covers, cover_updater__heldCovers)

        bbox.bmax.xyz = agentPos + float3(searchRadius, 3.5f, searchRadius)
        bbox.bmin.xyz = agentPos - float3(searchRadius, 1.5f, searchRadius)

        covers_box_cull(covers, bbox) <| $ [unused_argument(tm)] (id : int; tm : mat44f#)
          if tm.col3.xyz == float3() 
            return
          agent__checkCoversList |> push(id)
    if !hasAgent
      return

    distApproachSq = square(distance(agentPos, approachPos) + maxMoveAwayFromApproachPos)
    dirToTargetXZ = normalize(float3(targetPos.x - agentPos.x, 0.0, targetPos.z - agentPos.z))

    bestDistSq = FLT_MAX
    bestCoverId = int2(-1, 0)
    bestScore = 0
    bestAttack = CoverAttackType.NONE
    bestFound = false

    atTime = get_sync_time()

    coverIter = 0
    coverIterSlot = 0

    checkedFindDone = false

    avoidLeaderActing = get_squad_leader_acting_for_agent(agentEid)

  def override update(dt : float) : EBehResult
    if coverIter < 0
      return EBehResult.ER_FAILED

    var res = EBehResult.ER_FAILED
    var slowLeft = MAX_SLOW_PER_UPDATE

    let visibleMap = get_global_visible_covers_map()

    let agentEid = beh_tree_eid(owner)
    query() <| $ [es] (var covers : CoversComponent&)
      query(agentEid) <| $ [es] (walker_agent : EntityAgent;
                                 team : int = TEAM_UNASSIGNED;
                                 agent__checkCoversList : IntList;
                                 agent__ignoredCoversSlots : IntList const?;
                                 agent__ignoredCoversTimes : FloatList const?;
                                 var cover_updater__heldCovers : IPoint2List&)
        let filterInfo = get_filter_covers_info()
        let numCoversToCheck = length(agent__checkCoversList)
        while coverIter < numCoversToCheck
          if bestFound
            break

          let id = agent__checkCoversList[coverIter]

          assume cover     = covers.list[id]
          assume coverDesc = covers.coverDescs[id]
          if filter_cover(cover, coverDesc, bbox, -1, filterInfo)
            coverIter += 1
            coverIterSlot = 0
            continue

          if team != TEAM_UNASSIGNED && glob_vis_covers_map_has_other_teams(visibleMap, id, team)
            coverIter += 1
            coverIterSlot = 0
            continue

          let numSlots = length(coverDesc.slots)
          let isPrevCover = prevCoverId.x == id

          var slotBestCoverId = int2(id, -1)
          var slotBestDistSq = bestDistSq
          var slotBestScore = bestScore
          var slotBestAttack = CoverAttackType.NONE

          while coverIterSlot < numSlots
            let i = coverIterSlot
            coverIterSlot += 1

            let isPrevCoverSlot = isPrevCover && i == prevCoverId.y
            var attackType = CoverAttackType.NONE
            var score = eval_cover_attack_type_and_score(cover, coverDesc, i, attackType)

            var ignoreSlot = false
            if agent__ignoredCoversSlots != null && agent__ignoredCoversTimes != null
              for ignored, ignoreTime in *agent__ignoredCoversSlots, *agent__ignoredCoversTimes
                if ignored < 0 || atTime > ignoreTime + IGNORE_COVER_TIME
                  continue
                let ignoredIndex = ignored & ((1 << 24) - 1)
                let ignoredSlot = ignored >> 24
                if ignoredIndex == id && abs(ignoredSlot - i) <= 1
                  ignoreSlot = true
                  break
              if ignoreSlot
                continue

            if score < slotBestScore && !(score > 2 && isPrevCoverSlot)
              continue

            let coverSlotPos = get_cover_slot_pos(cover, coverDesc, i)
            if is_conflict_with_squad_leader_acting(avoidLeaderActing, coverSlotPos, agentEid)
              continue
            let coverSlotOfs = targetPos - coverSlotPos
            let cosAngle = dot(cover.dir, normalize(float3(coverSlotOfs.x, 0.0, coverSlotOfs.z)))
            if cosAngle < attackCosAngle
              if cosAngle < 0.0
                continue
              score = 1
              attackType = CoverAttackType.PRONE_DOWN
              if score < slotBestScore
                continue

            let distFromAgentSq = distance_sq(agentPos, coverSlotPos)
            if distFromAgentSq > searchRadiusSq
              score = 1
              if score < slotBestScore
                continue

            let distToTargetSq = length_sq(coverSlotOfs)
            if distToTargetSq < minDistToTargetSq
              continue

            let distBehindTarget = (coverSlotPos.x - targetPos.x) * dirToTargetXZ.x + (coverSlotPos.z - targetPos.z) * dirToTargetXZ.z
            if distBehindTarget >= maxBehindTarget
              score = 1
              if score < slotBestScore
                continue

            if approach && distance_sq(approachPos, coverSlotPos) > distApproachSq
              score -= 1
              if score < slotBestScore
                continue

            if distFromAgentSq > slotBestDistSq && score <= slotBestScore && !isPrevCoverSlot
              continue

            if check_move_to_cover_along_fire_line(agentPos, coverSlotPos, targetPos)
              continue

            if slowLeft == 0
              coverIterSlot -= 1
              slowLeft = -1
              break
            slowLeft -= 1

            if !is_point_safe(coverSlotPos, team)
              continue
            if !check_cover_pos_valid(coverSlotPos)
              continue

            if check_cover_near_enemies((coverSlotPos + agentPos) * 0.5, minDistToTarget, agentEid)
              continue

            if !check_cover_safe(coverSlotPos, targetPos)
              score = 1
              attackType = CoverAttackType.PRONE_DOWN
              if score < slotBestScore
                continue

            if checkFindPath && !checkedFindDone
              var checked = false
              let extents = float3(0.35, FLT_MAX, 0.35)
              let distTreshold = 1.0
              let dist0 = distance(agentPos, coverSlotPos)
              find_path(agentPos, coverSlotPos, extents, 1.0, 0.25) <| $(path)
                let numPoints = length(path)
                if numPoints <= 1
                  return
                if numPoints >= checkFindPathDoneLen
                  checkedFindDone = true
                if distance_sq(path[numPoints - 1], coverSlotPos) > distTreshold
                  return
                checked = true
                var totalDist = 0.0
                for j in range(numPoints - 1)
                  let pt1 = path[j]
                  let pt2 = path[j + 1]
                  let dist = length(pt2 - pt1)
                  totalDist += dist
                if checked && totalDist > dist0 * maxAroundLenCoef
                  checked = false
              if !checked
                continue
              checkedFindDone = true

            if score > 1 && !check_cover_attack(attackType, cover, coverSlotPos, walker_agent, targetPos)
              if attackType == CoverAttackType.CRAWL_TO_CROUCH
                attackType = CoverAttackType.CRAWL_TO_STAND
                if !check_cover_attack(attackType, cover, coverSlotPos, walker_agent, targetPos)
                  score = 1
                  attackType = CoverAttackType.PRONE_DOWN
                  if score < slotBestScore
                    continue
              elif attackType == CoverAttackType.PRONE_DOWN && rnd_int(0, 100) < 50
                attackType = CoverAttackType.STAND_STRAFES
                if !check_cover_attack(attackType, cover, coverSlotPos, walker_agent, targetPos)
                  score = 1
                  attackType = CoverAttackType.PRONE_DOWN
                  if score < slotBestScore
                    continue
              else
                score = 1
                attackType = CoverAttackType.PRONE_DOWN
                if score < slotBestScore
                  continue

            slotBestDistSq = distFromAgentSq
            slotBestCoverId = int2(id, i)
            slotBestAttack = attackType
            slotBestScore = score

            if isPrevCoverSlot
              bestFound = true
              break

          if slotBestCoverId.y != -1
            bestDistSq = slotBestDistSq
            bestCoverId = slotBestCoverId
            bestScore = slotBestScore
            bestAttack = slotBestAttack

          if slowLeft < 0
            break
          coverIter += 1
          coverIterSlot = 0

        if slowLeft < 0
          res = EBehResult.ER_RUNNING
        elif bestCoverId.x != -1
          push(cover_updater__heldCovers, bestCoverId)
          assume coverDesc = covers.coverDescs[bestCoverId.x]
          coverDesc.slots[bestCoverId.y].numUsed += 1
          if coverDesc.slots[bestCoverId.y].numUsed == 1
            coverDesc.numUsedSlots += 1

          owner.blackBoard |> set(outCoverAttackTypeParam, int(bestAttack))
          owner.blackBoard |> set(outCoverAttackCoverParam, bestCoverId.x)
          owner.blackBoard |> set(outCoverAttackCoverSlotParam, bestCoverId.y)
          res = EBehResult.ER_SUCCESS
    return res

[beh_node(name="checkCoverForCoverAttack")]
class CheckCoverForCoverAttack : BehNodeAdapter
  coverIndexParam : int = -1
  coverSlotParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    coverIndexParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverIndexParam", "coverAttackCover"), -1)
    coverSlotParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverSlotParam", "coverAttackCoverSlot"), 0)

  def override update(dt : float) : EBehResult
    var agentTeam = TEAM_UNASSIGNED
    query(beh_tree_eid(owner)) <| $ [es] (team : int)
      agentTeam = team

    var res = EBehResult.ER_FAILED
    query() <| $ [es] (covers : CoversComponent)
      let coverIndex = owner.blackBoard |> datablock_getInt(coverIndexParam)
      if coverIndex < 0 || coverIndex >= length(covers.list)
        return
      assume coverDesc = covers.coverDescs[coverIndex]
      let coverSlot = owner.blackBoard |> datablock_getInt(coverSlotParam)
      if coverSlot < 0 || coverSlot >= length(coverDesc.slots)
        return

      assume cover = covers.list[coverIndex]
      if !isCoverAllowable(covers, uint(coverIndex)) 
        return

      if agentTeam != TEAM_UNASSIGNED
        let visibleMap = get_global_visible_covers_map()
        if glob_vis_covers_map_has_other_teams(visibleMap, coverIndex, agentTeam)
          return

      res = EBehResult.ER_SUCCESS
    return res

[beh_node(name="checkTooManyEnemiesWatching")]
class CheckTooManyEnemiesWatching : BehNodeAdapter
  maxSumCosCoef : float = 1.0

  def override loadFromBlk(data : DataBlock) : void
    maxSumCosCoef = datablock_getReal(data, "maxSumCosCoef", maxSumCosCoef)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    var agentTeam = TEAM_UNASSIGNED
    query(beh_tree_eid(owner)) <| $ [es] (team : int)
      agentTeam = team

    var sumCosCoef = 0.0
    query(agent.eid) <| $ [es] (agent_dangers : AgentDangers)
      for i in iter_range(agent_dangers.dangers)
        let dangerEid = agent_dangers.dangers[i].eid
        query(dangerEid) <| $ [es] (ai_target : Target;
                                    team : int = TEAM_UNASSIGNED;
                                    human_parachute__isDeployed : bool const?;
                                    human_net_phys : HumanActor)
          if !ai_target.isAlive || ai_target.isHidden
            return
          if team == agentTeam
            return

          var factor = 1.0
          factor *= ai_target.useVehicle != uint(INVALID_ENTITY_ID) ? 0.5 : 1.0
          factor *= ai_target.isDowned ? 0.1 : 1.0
          let isTargetOnParachute = human_parachute__isDeployed != null ? *human_parachute__isDeployed : false
          if isTargetOnParachute
            factor *= 0.25

          let toTarget = ai_target.targetPos - agent.pos

          assume currentState = human_net_phys.phys.currentState
          let gunDir = currentState.gunDir
          let cosCoef = dot(normalize(toTarget), normalize(gunDir))
          if cosCoef < 0.0
            factor *= square(cosCoef)
          else
            factor *= 0.0

          sumCosCoef += factor

    
    

    return sumCosCoef > maxSumCosCoef ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="checkTargetTraceable")]
class CheckTargetTraceable : BehNodeAdapter
  targetParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    var isTargetTraceable = false
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    if targetEid != INVALID_ENTITY_ID
      query(agent.eid) <| $ [es] (agent_dangers : AgentDangers)
        for danger in agent_dangers.dangers
          if danger.traceable && danger.eid == targetEid
            isTargetTraceable = true
            return

    return isTargetTraceable ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="ignoreCover")]
class IgnoreCover : BehNodeAdapter
  coverIndexParam : int = -1
  coverSlotParam : int = -1

  MAX_IGNORED_COVERS = 5

  def override loadFromBlk(data : DataBlock) : void
    coverIndexParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverIndexParam", ""), -1)
    coverSlotParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverSlotParam", ""), -1)

  def override update(dt : float) : EBehResult
    query() <| $ [es] (covers : CoversComponent)
      let coverIndex = owner.blackBoard |> datablock_getInt(coverIndexParam)
      if coverIndex < 0 || coverIndex >= length(covers.list)
        return
      assume coverDesc = covers.coverDescs[coverIndex]
      let coverSlot = owner.blackBoard |> datablock_getInt(coverSlotParam)
      let numSlots = length(coverDesc.slots)
      if coverSlot < 0 || coverSlot >= numSlots
        return

      query(beh_tree_eid(owner)) <| $ [es] (var agent__ignoredCoversSlots : IntList&;
                                            var agent__ignoredCoversTimes : FloatList&;
                                            var agent__ignoredCoversLast : int&)
        let ignored = coverIndex + (coverSlot << 24)

        if length(agent__ignoredCoversSlots) < MAX_IGNORED_COVERS
          agent__ignoredCoversSlots |> push(ignored)
          agent__ignoredCoversTimes |> push(get_sync_time())
          agent__ignoredCoversLast = 0
        else
          let next = (agent__ignoredCoversLast + 1) % MAX_IGNORED_COVERS
          agent__ignoredCoversSlots[next] = ignored
          agent__ignoredCoversTimes[next] = get_sync_time()
          agent__ignoredCoversLast = next

    return EBehResult.ER_SUCCESS


[beh_node(name="makeSideStepPos")]
class MakeSideStepPos : BehNodeAdapter
  outPosParam : int = -1
  targetParam : int = -1

  sideStepDist : float = 0.5

  def override loadFromBlk(data : DataBlock) : void
    outPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3())
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    var hasTargetPos = false
    var targetPos = float3()
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    query(targetEid) <| $ [es] (ai_target : Target)
      targetPos = ai_target.targetPos
      hasTargetPos = true
    if !hasTargetPos
      return EBehResult.ER_FAILED

    var pos = agent.pos
    var dir = targetPos - agent.pos
    dir.y = 0.0
    dir = normalize(dir)

    let coef = rnd_int(0, 100) < 50 ? 1.0 : -1.0
    let dist = sideStepDist * coef
    pos.x += dir.z * dist
    pos.z -= dir.x * dist

    owner.blackBoard |> set(outPosParam, pos)
    return EBehResult.ER_SUCCESS

[beh_node(name="checkAllowedPosition")]
class CheckAllowedPosition : BehNodeAdapter
  posParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    let avoidLeaderActing = get_squad_leader_acting_for_agent(agent.eid)
    if avoidLeaderActing.actingFlags != 0
      let pos = owner.blackBoard |> datablock_getPoint3(posParam)
      if is_conflict_with_squad_leader_acting(avoidLeaderActing, pos, agent.eid)
        return EBehResult.ER_FAILED

    return EBehResult.ER_SUCCESS

