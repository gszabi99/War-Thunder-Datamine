options always_export_initializer = true

require app
require ecs
require ecs.common
require BehNodes
require DagorDataBlock
require DagorSystem

require math
require math.ang
require math.base
require math.random
require DagorMath
require DagorMathUtils
require DagorRandom

require DagorDebug3D

require Grid
require GridCollision
require CollisionTraces
require Dacoll
require RendInst
require SmokeOccluder

require HumanPhys
require DngHuman
require DngWalkerai
require walkerai
require %appGame.infantry.es.walker_common
require %appGame.infantry.es.team_common
require %appGame.infantry.es.offender_cache_common

require inventory
require DngWeapon
require DaWeapons
require DaWeaponProps
require Weapon
require PropsManager
require GuidanceLock

require dm
require Unit
require BallisticsProps

require AnimV20
require CollRes

require %appGame.infantry.ai.walker_nodes_common
require %appGame.infantry.ai.ai_weapons_common
require %appGame.infantry.es.ai_dangers_attack_debug_common
require %appGame.infantry.es.human_attached_gun_common
require %appGame.infantry.es.interactable_common

require %game.events

require %appGame.wt_events

require %appGame.squad_order_enums
require %appGame.infantry.es.squad_order_common
require %appGame.infantry.es.inventory_common
require %appGame.infantry.es.loc_squad_common

require %appGame.infantry.ai.ai_combat_common
require %appGame.infantry.es.dm_ai_common

require Mission
require pathfinder
require net


[beh_node(name="startAim")]
class StartAim : BehNodeAdapter

  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor&)
      assume ct = human_net_phys.phys.producedCT
      ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, true)
    return EBehResult.ER_SUCCESS

[beh_node(name="stopAim")]
class StopAim : BehNodeAdapter

  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor&)
      assume ct = human_net_phys.phys.producedCT
      ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, false)
    return EBehResult.ER_SUCCESS

[beh_node(name="canHoldWeaponInVehicle")]
class CanHoldWeaponInVehicle : BehNodeAdapter

  def override update(dt : float) : EBehResult
    return (get_bool(beh_tree_eid(owner), "human_vehicle__canHoldWeapon") ?? false) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="assignStationaryGun")]
class AssignStationaryGun : BehNodeAdapter
  gunEidParam : int = -1
  assignForTime : float = 5.0

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    assignForTime = datablock_getReal(data, "assignForTime", assignForTime)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    var res = EBehResult.ER_FAILED
    query(gunEid) <| $ [es] (var stationary_gun__botAssignedEid : EntityId&;
                             var stationary_gun__botAssignedTimeout : float&)
      var alreadyAssigned = false
      let curTime = get_sync_time()
      query(stationary_gun__botAssignedEid) <| $ [es] (isAlive : bool; beh_tree__enabled : bool; possessedByPlr : EntityId)
        if isAlive && beh_tree__enabled && possessedByPlr == INVALID_ENTITY_ID && curTime < stationary_gun__botAssignedTimeout
          if stationary_gun__botAssignedEid != agentEid
            alreadyAssigned = true
      if !alreadyAssigned
        stationary_gun__botAssignedEid = agentEid
        stationary_gun__botAssignedTimeout = curTime + assignForTime
        res = EBehResult.ER_SUCCESS
    return res

[beh_node(name="hasStationaryGunAssigned")]
class HasStationaryGunAssigned : BehNodeAdapter
  gunEidParam : int = -1
  allowAliveGuns : bool = true
  allowDeadGuns : bool = false

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    allowAliveGuns = datablock_getBool(data, "allowAliveGuns", allowAliveGuns)
    allowDeadGuns = datablock_getBool(data, "allowDeadGuns", allowDeadGuns)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    var res = EBehResult.ER_FAILED
    query(gunEid) <| $ [es] (stationary_gun__botAssignedEid : EntityId;
                             stationary_gun__botAssignedTimeout : float;
                             isAlive : bool)
      if stationary_gun__botAssignedEid == agentEid && get_sync_time() < stationary_gun__botAssignedTimeout
        if (isAlive && allowAliveGuns) || (!isAlive && allowDeadGuns)
          res =  EBehResult.ER_SUCCESS
    return res

[beh_node(name="blacklistStationaryGun")]
class BlacklistStationaryGun : BehNodeAdapter
  gunEidParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)

  def override update(dt : float) : EBehResult
    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    query(gunEid) <| $ [es] (var stationary_gun__botsBlacklisted : int&)
      stationary_gun__botsBlacklisted += 1

    return EBehResult.ER_SUCCESS


[beh_node(name="attachToStationaryGun")]
class AttachToStationaryGun : BehNodeAdapter
  radius : float = 2.0
  gunEidParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "gunEidParam") >= 0
      gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    radius = datablock_getReal(data, "radius", radius)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let gunEid = gunEidParam >= 0 ? EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam))) : find_gun_to_attach(agentEid, radius, true)
    if gunEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED
    sendEvent(gunEid, CmdUse(requesterEid = agentEid))
    return EBehResult.ER_SUCCESS

[beh_node(name="isAttachedToStationaryGun")]
class IsAttachedToStationaryGun : BehNodeAdapter
  gunEidParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "gunEidParam") >= 0
      gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    query(agentEid) <| $ [es] (human_attached_gun__attachedGunEid : EntityId)
      if gunEidParam >= 0
        let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
        if !!human_attached_gun__attachedGunEid && gunEid == human_attached_gun__attachedGunEid
          res = EBehResult.ER_SUCCESS
      else
        if !!human_attached_gun__attachedGunEid
          res = EBehResult.ER_SUCCESS
    return res

[beh_node(name="detachFromStationaryGun")]
class DetachFromStationaryGun : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var attachedGunEid = INVALID_ENTITY_ID
    query(agentEid) <| $ [es] (human_attached_gun__attachedGunEid : EntityId)
      attachedGunEid = human_attached_gun__attachedGunEid
    if attachedGunEid == INVALID_ENTITY_ID
      return EBehResult.ER_SUCCESS 
    sendEvent(attachedGunEid, CmdUse(requesterEid = agentEid))
    return EBehResult.ER_SUCCESS


[beh_node(name="findStationaryGun")]
class FindStationaryGun : BehNodeAdapter
  radius : float = 10.0
  posOffset : float3 = float3(0.0, 0.0, 0.0)
  posParam : int = -1

  gunEidOutParam : int = -1
  gunAITypeOutParam : int = -1

  extraChecks : bool = false
  rangeAITypes : int2 = int2(0, -1)
  skipAssignedToSelf : bool = false
  skipAssignedToOthers : bool = true
  skipDeadGuns : bool = true
  skipAliveGuns : bool = false
  maxBlacklisted : int = 2
  targetEidParam : int = -1
  traceTargets : bool = true
  maxTraces : int = 3
  requireEnemySide : bool = false
  requireTargets : int = 0
  hiddenTargets : bool = false
  rangeLimits : float2 =  float2(0, -1)

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "posParam") >= 0
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    radius = datablock_getReal(data, "radius", radius)
    posOffset = datablock_getPoint3(data, "posOffset", posOffset)

    if datablock_find_param(data, "gunEidOutParam") >= 0
      gunEidOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidOutParam", ""), 0)
    if datablock_find_param(data, "gunAITypeOutParam") >= 0
      gunAITypeOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunAITypeOutParam", ""), 0)

    extraChecks = datablock_getBool(data, "extraChecks", extraChecks)
    rangeAITypes = datablock_getIPoint2(data, "rangeAITypes", rangeAITypes)
    skipAssignedToSelf = datablock_getBool(data, "skipAssignedToSelf", skipAssignedToSelf)
    skipAssignedToOthers = datablock_getBool(data, "skipAssignedToOthers", skipAssignedToOthers)
    skipDeadGuns = datablock_getBool(data, "skipDeadGuns", skipDeadGuns)
    skipAliveGuns = datablock_getBool(data, "skipAliveGuns", skipAliveGuns)
    maxBlacklisted = datablock_getInt(data, "maxBlacklisted", maxBlacklisted)
    if datablock_find_param(data, "targetEidParam") >= 0
      targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", ""), 0)
    traceTargets = datablock_getBool(data, "traceTargets", traceTargets)
    maxTraces = datablock_getInt(data, "maxTraces", maxTraces)
    requireEnemySide = datablock_getBool(data, "requireEnemySide", requireEnemySide)
    requireTargets = datablock_getInt(data, "requireTargets", requireTargets)
    hiddenTargets = datablock_getBool(data, "hiddenTargets", hiddenTargets)
    rangeLimits = datablock_getPoint2(data, "rangeLimits", rangeLimits)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    var playerTeam = -1
    var agentPos = float3()
    if requireEnemySide
      query(agentEid) <| $ [es] (squad_member__playerEid : EntityId; transform : float3x4)
        agentPos = transform[3]
        query(squad_member__playerEid) <| $ [es] (team : int)
          playerTeam = team

    var targetEid = INVALID_ENTITY_ID
    if targetEidParam >= 0
      targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
      if targetEid == INVALID_ENTITY_ID
        return EBehResult.ER_FAILED

    let curTime = get_sync_time()

    var gunAIType = 0
    let gunEid = find_interactable(ecs_hash("interactable"), beh_tree_eid(owner), radius, true) <| $(gun_eid : EntityId)
      if !can_shoot_from_attached_gun(gun_eid)
        return false
      if !extraChecks
        return true

      var filtered = false
      query(gun_eid) <| $ [es] (isAlive : bool = false;
                                specialAIStGunType : int = 0;
                                stationary_gun__botAssignedEid : EntityId = INVALID_ENTITY_ID;
                                stationary_gun__botAssignedTimeout : float = 0.0;
                                stationary_gun__botsBlacklisted : int = 0)
        if (!isAlive && skipDeadGuns) || (isAlive && skipAliveGuns)
          filtered = true
          return
        if stationary_gun__botsBlacklisted >= maxBlacklisted
          filtered = true
          return
        gunAIType = specialAIStGunType
        if gunAIType < rangeAITypes.x || (rangeAITypes.y >= 0 && gunAIType > rangeAITypes.y)
          filtered = true
          return
        let assignedEid = stationary_gun__botAssignedEid
        if !!assignedEid && curTime < stationary_gun__botAssignedTimeout
          if (assignedEid == agentEid && skipAssignedToSelf) || (assignedEid != agentEid && skipAssignedToOthers)
            filtered = true
      if filtered
        return false

      var traced = false
      if !!targetEid && !check_attached_gun_target(gun_eid, targetEid, traceTargets, traced)
        return false

      if requireEnemySide && playerTeam >= 1
        var numPos = 0
        let gunDir = get_attached_gun_ai_aim_to_dir(gun_eid)
        get_respawn_points() <| $(active, respType, team, respPos)
          if !active || respType != "human" || is_teams_friendly(team, playerTeam)
            return
          if dot(gunDir, normalize(respPos - agentPos)) > 0.5
            ++numPos
        if numPos <= 0
          return false

      if requireTargets > 0 && !(requireTargets == 1 && !!targetEid)
        var fireRange = MOUNTED_GUN_DEFAULT_FIRE_RANGE
        query(gun_eid) <| $ [es] (mounted_gun__aiFireRange : float2)
          fireRange = mounted_gun__aiFireRange
        let needTargets = requireTargets - (!!targetEid ? 1 : 0)
        var gotTargets = 0
        var leftTraces = maxTraces
        query(agentEid) <| $ [es] (agent_dangers : AgentDangers)
          for danger in agent_dangers.dangers
            if danger.distance < fireRange.x || danger.distance > fireRange.y
              continue
            if !danger.traceable && !(hiddenTargets && is_attached_gun_hidden_target_incoming(gun_eid, danger.eid))
              continue

            let targetOK = check_attached_gun_target(gun_eid, danger.eid, leftTraces > 0, traced)
            if traced
              leftTraces -= 1
            if !targetOK
              continue
            gotTargets += 1
            if gotTargets >= needTargets
              break
        if gotTargets < needTargets
          return false
      return true

    var res = EBehResult.ER_FAILED
    query(gunEid) <| $ [es] (transform : float3x4)
      if posParam >= 0
        owner.blackBoard |> set(posParam, transform * posOffset)
      if gunEidOutParam >= 0
        owner.blackBoard |> set(gunEidOutParam, int(uint(gunEid)))
      if gunAITypeOutParam >= 0
        owner.blackBoard |> set(gunAITypeOutParam, gunAIType)
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="findNextTargetForStationaryGun")]
class FindNextTargetForStationaryGun : BehNodeAdapter
  gunEidParam : int = -1
  targetEidOutParam : int = -1
  minTimeInFrustum : float = 2.0
  iterParam : int = -1
  maxTraces : int = 3

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    targetEidOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidOutParam", ""), 0)
    minTimeInFrustum = datablock_getReal(data, "minTimeInFrustum", minTimeInFrustum)
    iterParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunIter", "stGunTgtIter"), 0)
    maxTraces = datablock_getInt(data, "maxTraces", maxTraces)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED
    if !can_shoot_from_attached_gun(gunEid)
      return EBehResult.ER_FAILED

    var iterValue = owner.blackBoard |> datablock_getInt(iterParam)
    var targetEid = INVALID_ENTITY_ID

    let curTime = get_sync_time()

    query(agentEid) <| $ [es] (agent_dangers : AgentDangers)
      let numDangers = length(agent_dangers.dangers)
      if iterValue < 0 || iterValue >= numDangers
        iterValue = 0
      if numDangers <= 0
        return
      let startIterValue = iterValue
      var leftTraces = maxTraces
      var leftDangers = numDangers
      while leftDangers > 0 && leftTraces > 0
        leftDangers -= 1
        let dangerIdx = iterValue
        iterValue = (iterValue + 1) % numDangers
        assume danger = agent_dangers.dangers[dangerIdx]
        if danger.traceable && curTime - danger.inFrustumTime >= minTimeInFrustum
          var traced = false
          let targetOK = check_attached_gun_target(gunEid, danger.eid, true, traced)
          if traced
            leftTraces -= 1
          if targetOK
            targetEid = danger.eid
            break
        if iterValue == startIterValue
          break

    owner.blackBoard |> set(iterParam, iterValue)
    owner.blackBoard |> set(targetEidOutParam, int(uint(targetEid)))

    return !!targetEid ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="checkStationaryGunTarget")]
class CheckStationaryGunTarget : BehNodeAdapter
  gunEidParam : int = -1
  targetEidParam : int = -1
  traceHit : bool = false

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", ""), 0)
    traceHit = datablock_getBool(data, "traceHit", traceHit)

  def override update(dt : float) : EBehResult
    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED
    if !can_shoot_from_attached_gun(gunEid)
      return EBehResult.ER_FAILED

    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    if targetEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    var traced = false
    if !check_attached_gun_target(gunEid, targetEid, traceHit, traced)
      return EBehResult.ER_FAILED
    return EBehResult.ER_SUCCESS

[beh_node(name="getStationaryGunInfo")]
class GetStationaryGunInfo : BehNodeAdapter
  gunEidParam : int = -1
  posOffset : float3  = float3(0.0, 0.0, 0.0)
  posOutParam : int = -1
  gunAITypeOutParam : int = -1
  lookPosOutParam : int = -1
  lookRandYawRange : float2 = float2(-1.0, 1.0)
  lookRandPitchRange : float2 = float2(-1.0, 1.0)
  lookRandDistRange : float2 = float2(0.0, 1.0)

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    posOffset = datablock_getPoint3(data, "posOffset", posOffset)
    if datablock_find_param(data, "posOutParam") >= 0
      posOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posOutParam", ""), float3())
    if datablock_find_param(data, "gunAITypeOutParam") >= 0
      gunAITypeOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunAITypeOutParam", ""), 0)
    if datablock_find_param(data, "lookPosOutParam") >= 0
      lookPosOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lookPosOutParam", ""), float3())
    lookRandYawRange = datablock_getPoint2(data, "lookRandYawRange", lookRandYawRange)
    lookRandPitchRange = datablock_getPoint2(data, "lookRandPitchRange", lookRandPitchRange)
    lookRandDistRange = datablock_getPoint2(data, "lookRandDistRange", lookRandDistRange)

  def override update(dt : float) : EBehResult
    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    var hasData = false
    var gunTransform = IDENT_TM
    var gunAIType = 0
    query(gunEid) <| $ [es] (transform : float3x4; specialAIStGunType : int = 0)
      hasData = true
      gunTransform = transform
      gunAIType = specialAIStGunType
    if !hasData
      return EBehResult.ER_FAILED

    if posOutParam >= 0
      owner.blackBoard |> set(posOutParam, gunTransform * posOffset)

    if gunAITypeOutParam >= 0
      owner.blackBoard |> set(gunAITypeOutParam, gunAIType)

    if lookPosOutParam >= 0
      let kYaw = rnd_float(lookRandYawRange.x, lookRandYawRange.y)
      let kPitch = rnd_float(lookRandPitchRange.x, lookRandPitchRange.y)
      let kDist = rnd_float(lookRandDistRange.x, lookRandDistRange.y)
      var lookPos = float3()
      if !get_attached_gun_ai_aim_point(lookPos, gunEid, kYaw, kPitch, kDist)
        return EBehResult.ER_FAILED
      owner.blackBoard |> set(lookPosOutParam, lookPos)

    return EBehResult.ER_SUCCESS


[beh_node(name="isAllyPlayerNear")]
class IsAllyPlayerNear : BehNodeAdapter
  radius : float = 1.0

  def override loadFromBlk(data : DataBlock) : void
    radius = datablock_getReal(data, "radius", radius)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var isAllyNear = false
    query(agentEid) <| $ [es] (transform aka agent_transform : float3x4; squad_member__playerEid : EntityId)
      var playerTeam = -1
      query(squad_member__playerEid) <| $ [es] (team : int)
        playerTeam = team
      if playerTeam > 0
        let radiusSq = square(radius)
        for_each_entity_in_grid(ecs_hash("humans"), BSphere3(agent_transform[3], radius), GridEntCheck.BOUNDING) <| $(that_eid : EntityId)
          if agentEid == that_eid
            return
          query(that_eid) <| $ [es] (transform aka that_transform : float3x4; possessedByPlr : EntityId; beh_tree__enabled : bool)
            if !beh_tree__enabled && distance_sq(agent_transform[3], that_transform[3]) < radiusSq
              query(possessedByPlr) <| $ [es(REQUIRE_NOT=playerIsBot)] (team aka that_team : int)
                if is_teams_friendly(playerTeam, that_team)
                  isAllyNear = true
    return isAllyNear ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="passedTimeSinceControlledByPlayer")]
class PassedTimeSinceControlledByPlayer : BehNodeAdapter
  time : float = 5.0

  def override loadFromBlk(var data : DataBlock) : void
    time = data |> datablock_getReal("time", time)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var timePassed = true
    query(agentEid) <| $ [es] (human_weap__lastTimeInfiniteAmmoEnabled : float = 0.0)
      if human_weap__lastTimeInfiniteAmmoEnabled > 0.0
        timePassed = get_sync_time() > human_weap__lastTimeInfiniteAmmoEnabled + time
    return timePassed ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="checkReloadWeapon")]
class CheckReloadWeapon : BehNodeAdapter
  checkOnly : bool = false
  enoughAmmoRatio : float = 0.0

  skipEnemyNearRadius : float = -1.0
  skipEnemyDeltaHeights : float2 = float2(-2.0, 3.0)
  waitReloadFinish : bool = true

  def override loadFromBlk(var data : DataBlock) : void
    checkOnly = data |> datablock_getBool("checkOnly", checkOnly)
    enoughAmmoRatio = data |> datablock_getReal("enoughAmmoRatio", enoughAmmoRatio)

    skipEnemyNearRadius = data |> datablock_getReal("skipEnemyNearRadius", skipEnemyNearRadius)
    skipEnemyDeltaHeights = data |> datablock_getPoint2("skipEnemyDeltaHeights", skipEnemyDeltaHeights)
    waitReloadFinish = data |> datablock_getBool("waitReloadFinish", waitReloadFinish)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let reload = check_human_reload(ownerEid, enoughAmmoRatio)
    if checkOnly
      return reload != 0 ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    if reload > 0
      return waitReloadFinish ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS
    if reload < 0
      if skipEnemyNearRadius > 1.0 && check_hostile_humans_nearby(ownerEid, skipEnemyNearRadius, skipEnemyDeltaHeights)
        return EBehResult.ER_SUCCESS
      query(ownerEid) <| $ [es] (human_weap__currentGunEid : EntityId)
        let atTime = get_sync_time()
        sendEventImmediate(ownerEid, CmdRequestReload(atTime = atTime, gunEid = human_weap__currentGunEid, isQuick = false))
      return waitReloadFinish ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS
    return EBehResult.ER_SUCCESS

[beh_node(name="blockReload")]
class BlockReload : BehNodeAdapter
  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (var human_weap__reloadBlockedForAI : bool&)
      human_weap__reloadBlockedForAI = true
    return EBehResult.ER_SUCCESS

[beh_node(name="unblockReload")]
class UnblockReload : BehNodeAdapter
  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (var human_weap__reloadBlockedForAI : bool&)
      human_weap__reloadBlockedForAI = false
    return EBehResult.ER_SUCCESS


[beh_node(name="decideOnAttackTarget")]
class DecideOnAttackTarget : BehNodeAdapter
  checkOnly : bool = false

  forceAlwaysInstant : bool = false
  instantSpotChances : float4 = float4(1.0, 1.0, 1.0, 0.5)
  instantSpotNearDist : float = 8.5
  instantSpotLowerPerMeter : float = 0.001

  targetEidParam : int = -1
  targetSeeTimeParam : int = -1
  targetAcceptTime : float = 0.3

  lastTargetEidParam : int = -1
  lastTargetSeenParam : int = -1
  lastTargetTimeParam : int = -1
  forgetTargetTime : float = 7.5

  hunchLevelParam : int = -1
  prevHunchTimeParam : int = -1
  hunchTimeForDist1 = float3(0.5, 1.0, 60.)
  hunchTimeForDist2 = float3(0.4, 0.7, 25.)
  hunchTimeForDist3 = float3(0.2, 0.5, 5.)
  hunchDistDiv12 : float = 0.0
  hunchDistDiv23 : float = 0.0

  stillBackTimeRange = float2(0.2, 0.3)
  stillSideTimeRange = float2(0.1, 0.2)
  turnExactBackChance = 0.9
  turnExactSideChance = 0.9

  followTurnAngleRange : float2 = float2(50.0, 70.0)
  sideTurnAngleRange : float2 = float2(70.0, 110.0)
  backTurnAngleRange : float2 = float2(110.0, 150.0)
  deviateExactAngle : float = 10.0
  backAngle : float = 135.0
  sideAngle : float = 60.0

  focusBackTimeRange = float2(0.2, 0.3)
  focusSideTimeRange = float2(0.1, 0.2)
  focusAheadTimeRange = float2(0.0, 0.1)
  focusProneAddTimeRange = float2(0.1, 0.2)
  refocusTimeRange = float2(0.0, 0.1)

  stillTimeOutParam : int = -1
  turnAngleOutParam : int = -1
  focusTimeOutParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    checkOnly = datablock_getBool(data, "checkOnly", checkOnly)
    forceAlwaysInstant = datablock_getBool(data, "forceAlwaysInstant", forceAlwaysInstant)
    instantSpotChances = datablock_getPoint4(data, "instantSpotChances", instantSpotChances)
    instantSpotNearDist = datablock_getReal(data, "instantSpotNearDist", instantSpotNearDist)
    instantSpotLowerPerMeter = datablock_getReal(data, "instantSpotLowerPerMeter", instantSpotLowerPerMeter)

    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)
    targetSeeTimeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetSeeTimeParam", ""), -1.0)

    lastTargetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lastTargetEidParam", "lastTargetEid"), 0)
    lastTargetSeenParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lastTargetSeenParam", "lastTargetSeen"), false)
    lastTargetTimeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lastTargetTimeParam", "lastTargetTime"), 0.0)

    hunchLevelParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "hunchLevelParam", "hunchLevel"), 0.0)
    prevHunchTimeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "prevHunchTimeParam", "prevHunchTime"), -1.0)
    hunchDistDiv12 = safeinv(hunchTimeForDist1.z - hunchTimeForDist2.z)
    hunchDistDiv23 = safeinv(hunchTimeForDist2.z - hunchTimeForDist3.z)

    followTurnAngleRange *= DEG_TO_RAD
    sideTurnAngleRange *= DEG_TO_RAD
    backTurnAngleRange *= DEG_TO_RAD
    deviateExactAngle *= DEG_TO_RAD
    backAngle *= DEG_TO_RAD
    sideAngle *= DEG_TO_RAD

    stillTimeOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "stillTimeOutParam", ""), 0.0)
    turnAngleOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "turnAngleOutParam", ""), 0.0)
    focusTimeOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "focusTimeOutParam", ""), 0.0)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)

    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    if targetEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    let curTime = get_sync_time()

    if forceAlwaysInstant
      let lastTargetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(lastTargetEidParam)))
      let lastTargetTime = owner.blackBoard |> datablock_getReal(lastTargetTimeParam)
      if lastTargetEid != targetEid || curTime - lastTargetTime >= forgetTargetTime
        var spotChance = 1.0
        query(targetEid) <| $ [es] (human_net_phys : HumanActor; transform : float3x4)
          let targetPos = transform[3]
          let delta = targetPos - agent.pos
          let angleTo = atan2(delta.z, delta.x)
          let angleDir = atan2(agent.shootDir.z, agent.shootDir.x)
          let absAngleDiff = abs(angle_diff(angleDir, angleTo))
          if absAngleDiff > backAngle
            spotChance *= instantSpotChances.z
          elif absAngleDiff > sideAngle
            spotChance *= instantSpotChances.y
          else
            spotChance *= instantSpotChances.x
          if human_net_phys.phys.currentState.isCrawl
            spotChance *= instantSpotChances.w
          let dist = length(delta)
          spotChance -= instantSpotLowerPerMeter * dist
          if dist < instantSpotNearDist
            spotChance = 1.0
        if spotChance < 1.0 && rnd_float(0.0, 1.0) > spotChance
          
          return EBehResult.ER_FAILED
        
        
      
      

      if !checkOnly
        owner.blackBoard |> set(lastTargetEidParam, int(uint(targetEid)))
        owner.blackBoard |> set(lastTargetTimeParam, curTime)

        owner.blackBoard |> set(lastTargetSeenParam, true)
        owner.blackBoard |> set(lastTargetEidParam, int(uint(targetEid)))
        owner.blackBoard |> set(lastTargetTimeParam, curTime)

        owner.blackBoard |> set(prevHunchTimeParam, -1.0)
        owner.blackBoard |> set(hunchLevelParam, 0.0)

        owner.blackBoard |> set(stillTimeOutParam, 0.0)
        owner.blackBoard |> set(turnAngleOutParam, 0.0)
        owner.blackBoard |> set(focusTimeOutParam, 0.0)
      return EBehResult.ER_SUCCESS

    var lastTargetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(lastTargetEidParam)))
    var lastTargetSeen = owner.blackBoard |> datablock_getBool(lastTargetSeenParam)
    let lastTargetTime = owner.blackBoard |> datablock_getReal(lastTargetTimeParam)

    if lastTargetEid != INVALID_ENTITY_ID && curTime - lastTargetTime > forgetTargetTime
      lastTargetEid = INVALID_ENTITY_ID
      lastTargetSeen = false
      if !checkOnly
        owner.blackBoard |> set(targetSeeTimeParam, curTime)

    let targetSeeTime = owner.blackBoard |> datablock_getReal(targetSeeTimeParam)
    if targetSeeTime >= 0.0 && curTime - targetSeeTime >= targetAcceptTime
      var focusTime = 0.0
      if targetEid != lastTargetEid
        owner.blackBoard |> set(lastTargetEidParam, int(uint(targetEid)))
        focusTime = rnd_float(focusAheadTimeRange.x, focusAheadTimeRange.y)
      elif !lastTargetSeen
        focusTime = rnd_float(refocusTimeRange.x, refocusTimeRange.y)

      query(targetEid) <| $ [es] (human_net_phys : HumanActor)
        if human_net_phys.phys.currentState.isCrawl
          focusTime += rnd_float(focusProneAddTimeRange.x, focusProneAddTimeRange.y)

      if !checkOnly
        owner.blackBoard |> set(lastTargetSeenParam, true)
        owner.blackBoard |> set(lastTargetTimeParam, curTime)

        owner.blackBoard |> set(prevHunchTimeParam, -1.0)
        owner.blackBoard |> set(hunchLevelParam, 0.0)

        owner.blackBoard |> set(stillTimeOutParam, 0.0)
        owner.blackBoard |> set(turnAngleOutParam, 0.0)
        owner.blackBoard |> set(focusTimeOutParam, focusTime)
      return EBehResult.ER_SUCCESS

    if !checkOnly
      owner.blackBoard |> set(lastTargetSeenParam, false)

    var hasTargetPos = false
    var targetPos = float3()
    query(targetEid) <| $ [es] (transform : float3x4)
      hasTargetPos = true
      targetPos = transform[3]

    var targetCrawl = false
    query(targetEid) <| $ [es] (human_net_phys : HumanActor)
      targetCrawl = human_net_phys.phys.currentState.isCrawl

    if targetEid == lastTargetEid
      var turnAngle = 0.0
      if hasTargetPos && lastTargetSeen
        let delta = targetPos - agent.pos
        let angleTo = atan2(delta.z, delta.x)
        let angleDir = atan2(agent.shootDir.z, agent.shootDir.x)
        turnAngle = rnd_float(followTurnAngleRange.x, followTurnAngleRange.y)
        if angle_diff(angleDir, angleTo) < 0.0
          turnAngle = -turnAngle
      else
        turnAngle = rnd_float(-PI, PI)

      var focusTime = rnd_float(refocusTimeRange.x, refocusTimeRange.y)
      if targetCrawl
        focusTime += rnd_float(focusProneAddTimeRange.x, focusProneAddTimeRange.y)

      if !checkOnly
        owner.blackBoard |> set(lastTargetSeenParam, true)
        owner.blackBoard |> set(lastTargetTimeParam, curTime)

        owner.blackBoard |> set(stillTimeOutParam, 0.0)
        owner.blackBoard |> set(turnAngleOutParam, turnAngle)
        owner.blackBoard |> set(focusTimeOutParam, focusTime)
      return EBehResult.ER_SUCCESS

    let dist = hasTargetPos ? distance(targetPos, agent.pos) : 0.0
    var time = 0.0
    if dist > hunchTimeForDist1.z
      time = rnd_float(hunchTimeForDist1.x, hunchTimeForDist1.y)
    elif dist > hunchTimeForDist2.z
      let ratio = (dist - hunchTimeForDist2.z) * hunchDistDiv12
      let time1 = rnd_float(hunchTimeForDist1.x, hunchTimeForDist1.y)
      let time2 = rnd_float(hunchTimeForDist2.x, hunchTimeForDist2.y)
      time = lerp(time2, time1, ratio)
    elif dist > hunchTimeForDist3.z
      let ratio = (dist - hunchTimeForDist3.z) * hunchDistDiv23
      let time2 = rnd_float(hunchTimeForDist2.x, hunchTimeForDist2.y)
      let time3 = rnd_float(hunchTimeForDist3.x, hunchTimeForDist3.y)
      time = lerp(time3, time2, ratio)
    else
      time = rnd_float(hunchTimeForDist3.x, hunchTimeForDist3.y)

    var hunchCoef = 1.0
    if hasTargetPos
      hunchCoef = 1.5 + 0.5 * dot(agent.shootDir, normalize(targetPos - agent.pos))

    let prevHunchTime = owner.blackBoard |> datablock_getReal(prevHunchTimeParam)
    let deltaTime = (prevHunchTime >= 0.0) ? (curTime - prevHunchTime) : 0.0
    let hunchAdd = (time > 0.0 ? (deltaTime / time) : 1.0) * hunchCoef
    let wasHunchLevel = owner.blackBoard |> datablock_getReal(hunchLevelParam)
    var newHunchLevel = min(1.0, wasHunchLevel + hunchAdd)
    if newHunchLevel != wasHunchLevel && !checkOnly
      owner.blackBoard |> set(hunchLevelParam, newHunchLevel)
    if prevHunchTime != curTime && !checkOnly
      owner.blackBoard |> set(prevHunchTimeParam, curTime)

    if newHunchLevel < 1.0
      return EBehResult.ER_FAILED 

    var stillTime = 0.0
    var turnAngle = 0.0
    var focusTime = 0.0

    if hasTargetPos
      let delta = targetPos - agent.pos
      let angleTo = atan2(delta.z, delta.x)
      let angleDir = atan2(agent.shootDir.z, agent.shootDir.x)

      let angleDiff = angle_diff(angleDir, angleTo)
      if abs(angleDiff) > backAngle
        stillTime = rnd_float(stillBackTimeRange.x, stillBackTimeRange.y)
        focusTime = rnd_float(focusBackTimeRange.x, focusBackTimeRange.y)
        if rnd_float(0.0, 1.0) < turnExactBackChance
          turnAngle = angleDiff + rnd_float(-deviateExactAngle, deviateExactAngle)
        else
          turnAngle = rnd_float(backTurnAngleRange.x, backTurnAngleRange.y)
          if angleDiff < 0.0
            turnAngle = -turnAngle
          if rnd_float(0.0, 1.0) < 0.5
            turnAngle = -turnAngle
      else
        stillTime = rnd_float(stillSideTimeRange.x, stillSideTimeRange.y)
        focusTime = rnd_float(focusSideTimeRange.x, focusSideTimeRange.y)
        if rnd_float(0.0, 1.0) < turnExactSideChance
          turnAngle = angleDiff + rnd_float(-deviateExactAngle, deviateExactAngle)
        else
          turnAngle = rnd_float(sideTurnAngleRange.x, sideTurnAngleRange.y)
          if angleDiff < 0.0
            turnAngle = -turnAngle
          if rnd_float(0.0, 1.0) < 0.5
            turnAngle = -turnAngle
    else
      
      stillTime = 0.0
      turnAngle = rnd_float(-PI, PI)
      focusTime = rnd_float(focusBackTimeRange.x, focusBackTimeRange.y)

    if focusTime > 0.0 && targetCrawl
      focusTime += rnd_float(focusProneAddTimeRange.x, focusProneAddTimeRange.y)

    if lastTargetEid != INVALID_ENTITY_ID && !checkOnly
      owner.blackBoard |> set(lastTargetEidParam, int(uint(INVALID_ENTITY_ID))) 

    if !checkOnly
      newHunchLevel = 0.5
      owner.blackBoard |> set(hunchLevelParam, newHunchLevel)

      owner.blackBoard |> set(lastTargetSeenParam, false)
      owner.blackBoard |> set(lastTargetTimeParam, curTime)

      owner.blackBoard |> set(stillTimeOutParam, stillTime)
      owner.blackBoard |> set(turnAngleOutParam, turnAngle)
      owner.blackBoard |> set(focusTimeOutParam, focusTime)
    return EBehResult.ER_SUCCESS


[beh_node(name="checkBlockLeader")]
class CheckBlockLeader : BehNodeAdapter
  outPosParam : int = -1
  outTypeParam : int = -1
  minDistToMove : float = 0.15
  minDistToLeaderPos : float = 1.1
  reachDistToLeaderPos : float = 1.2
  minLeaderSpeed : float = 0.1
  minDistToLeaderSight : float = 0.5
  moveDistOffLeaderSight : float = 0.8
  maxDistByLeaderSight : float = 10.0
  rewriteOrderPos : bool = true

  AGENT_FORWARD_DISPLACEMENT : float = 0.15

  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "outPosParam") >= 0
      outPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3())
    if datablock_find_param(data, "outTypeParam") >= 0
      outTypeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outTypeParam", ""), -1)
    minDistToMove = data |> datablock_getReal("minDistToMove", minDistToMove)
    minDistToLeaderPos = data |> datablock_getReal("minDistToLeaderPos", minDistToLeaderPos)
    reachDistToLeaderPos = data |> datablock_getReal("reachDistToLeaderPos", reachDistToLeaderPos)
    minLeaderSpeed = data |> datablock_getReal("minLeaderSpeed", minLeaderSpeed)
    minDistToLeaderSight = data |> datablock_getReal("minDistToLeaderSight", minDistToLeaderSight)
    moveDistOffLeaderSight = data |> datablock_getReal("moveDistOffLeaderSight", moveDistOffLeaderSight)
    maxDistByLeaderSight = data |> datablock_getReal("maxDistByLeaderSight", maxDistByLeaderSight)

  def override update(dt : float) : EBehResult
    var result = false
    var resultPos = float3()
    var resultType = -1
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (transform aka agent_transform : float3x4;
                               squad_member__isPersonalOrder : bool;
                               squad_member__playerEid : EntityId;
                               squad_member__squad : EntityId)
      var isBot = false
      query(squad_member__playerEid) <| $ [es(REQUIRE=playerIsBot)] ()
        isBot = true
      if isBot
        return
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
        if squad__leader == agentEid
          return
        query(squad__leader) <| $ [es] (transform aka leader_transform : float3x4;
                                        human_net_phys : HumanActor&)
          let agentPos = agent_transform[3] + agent_transform[0] * AGENT_FORWARD_DISPLACEMENT
          let leaderPos = leader_transform[3] + leader_transform[0] * AGENT_FORWARD_DISPLACEMENT
          let deltaToLeader = x0z(leaderPos - agentPos)

          let extents = float3(0.8, FLT_MAX, 0.8)
          let projExtents = float3(0.8, 2.5, 0.8)

          resultPos = agentPos
          if length_sq(deltaToLeader) < square(minDistToLeaderPos)
            let dirToLeader = normalize(x0z(deltaToLeader))
            resultPos = leaderPos - dirToLeader * reachDistToLeaderPos
            traceray_navmesh(agentPos, resultPos, extents, resultPos)
            var posOK = project_to_nearest_navmesh_point_avoid_obstacles(resultPos, projExtents)
            if dot(-dirToLeader, leader_transform[0]) > 0.707
              posOK = false
            elif dot(normalize(resultPos - agentPos), leader_transform[0]) > 0.707
              posOK = false
            let MIN_DIST_MOVE_AWAY_FROM_LEADER_SQ = square(reachDistToLeaderPos - minDistToLeaderPos)
            if posOK && distance_sq(agentPos, resultPos) >= MIN_DIST_MOVE_AWAY_FROM_LEADER_SQ
              result = true
              resultType = 1
            else
              let dirToSide = float3(dirToLeader.z, 0.0, -dirToLeader.x)
              let sideDist1 = dot(leader_transform[2], agentPos - leaderPos)
              let sideDist2 = dot(leader_transform[2], agentPos + dirToSide * minDistToLeaderPos - leaderPos)
              let sideCoef = (sideDist1 < 0.0) == (sideDist2 < 0.0) ? 1.0 : -1.0
              resultPos = agentPos + sideCoef * dirToSide * minDistToLeaderPos + dirToLeader * 0.1
              traceray_navmesh(agentPos, resultPos, extents, resultPos)
              posOK = project_to_nearest_navmesh_point_avoid_obstacles(resultPos, projExtents)
              if posOK && distance_sq(agentPos, resultPos) >= MIN_DIST_MOVE_AWAY_FROM_LEADER_SQ
                result = true
                resultType = 1
              else
                resultPos = agentPos - sideCoef * dirToSide * minDistToLeaderPos + dirToLeader * 0.1
                traceray_navmesh(agentPos, resultPos, extents, resultPos)
                posOK = project_to_nearest_navmesh_point_avoid_obstacles(resultPos, projExtents)
                if posOK && distance_sq(agentPos, resultPos) >= MIN_DIST_MOVE_AWAY_FROM_LEADER_SQ
                  result = true
                  resultType = 1
          if result
            return

          if squad_member__isPersonalOrder
            return

          assume phys = human_net_phys.phys
          assume currentState = phys.currentState
          let isMoving = length_sq(currentState.velocity) > square(minLeaderSpeed)
          if !isMoving
            return

          let COS_20_DEG = 0.93969262078
          if dot(normalize(x0z(currentState.velocity)), -normalize(deltaToLeader)) < COS_20_DEG
            return

          let sightDist = dot(leader_transform[0], resultPos) - dot(leader_transform[0], leaderPos)
          if sightDist > 0.0 && sightDist < maxDistByLeaderSight
            let leaderLeft = leader_transform[2]
            let distToSight = dot(leaderLeft, resultPos) - dot(leaderLeft, leaderPos)
            if abs(distToSight) < minDistToLeaderSight
              let midPos = resultPos - leaderLeft  * distToSight
              var resultPos1 = midPos + leaderLeft * moveDistOffLeaderSight
              var resultPos2 = midPos - leaderLeft * moveDistOffLeaderSight
              traceray_navmesh(agentPos, resultPos1, extents, resultPos1)
              traceray_navmesh(agentPos, resultPos2, extents, resultPos2)
              let MIN_DIST_MOVE_SQ = square(minDistToMove)
              if project_to_nearest_navmesh_point_avoid_obstacles(resultPos1, projExtents)
                if project_to_nearest_navmesh_point_avoid_obstacles(resultPos2, projExtents)
                  result = true
                  let distSq1 = distance_sq(agentPos, resultPos1)
                  let distSq2 = distance_sq(agentPos, resultPos2)
                  if distSq1 >= MIN_DIST_MOVE_SQ && distSq2 >= MIN_DIST_MOVE_SQ
                    resultPos = distance_sq(midPos, resultPos1) > distance_sq(midPos, resultPos2) ? resultPos1 : resultPos2
                  elif distSq1 >= MIN_DIST_MOVE_SQ
                    resultPos = resultPos1
                  elif distSq2 >= MIN_DIST_MOVE_SQ
                    resultPos = resultPos2
                  resultType = 0
                elif distance_sq(agentPos, resultPos1) >= MIN_DIST_MOVE_SQ
                  result = true
                  resultPos = resultPos1
                  resultType = 0
              elif project_to_nearest_navmesh_point_avoid_obstacles(resultPos2, projExtents)
                if distance_sq(agentPos, resultPos2) >= MIN_DIST_MOVE_SQ
                  result = true
                  resultPos = resultPos2
                  resultType = 0
      if result
        resultPos -= agent_transform[0] * AGENT_FORWARD_DISPLACEMENT
      
      
    if result
      if outPosParam >= 0
        owner.blackBoard |> set(outPosParam, resultPos)
      if outTypeParam >= 0
        owner.blackBoard |> set(outTypeParam, resultType)
      if rewriteOrderPos
        query(agentEid) <| $ [es] (var squad_member__followLeaderPos : float3&)
          squad_member__followLeaderPos = resultPos
        query(agentEid) <| $ [es] (transform : float3x4;
                                   squad_member__orderType : int;
                                   squad_member__isPersonalOrder : bool;
                                   var squad_member__orderPosition : float3&)
          if squad_member__isPersonalOrder && is_squad_mate_order_overwatch_by_direction(squad_member__orderType)
            let MIN_DIST_POSITIONAL = 1.0
            if distance_sq(squad_member__orderPosition, transform[3]) < square(MIN_DIST_POSITIONAL)
              squad_member__orderPosition = resultPos
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isLastFollowerInSquad")]
class IsLastFollowerInSquad : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var isLast = false
    query(agentEid) <| $ [es] (squad_member__followLeader : bool; squad_member__followLeaderLast : bool)
      isLast = squad_member__followLeader && squad_member__followLeaderLast
    return isLast ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="fixMoveWishPos")]
class FixMoveWishPos : BehNodeAdapter
  posParam : int = -1
  minDistToLeader : float = 1.0

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    minDistToLeader = data |> datablock_getReal("minDistToLeader", minDistToLeader)

  def override update(dt : float) : EBehResult
    if posParam < 0
      return EBehResult.ER_SUCCESS
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__playerEid : EntityId;
                               squad_member__squad : EntityId)
      var isBot = false
      query(squad_member__playerEid) <| $ [es(REQUIRE=playerIsBot)] ()
        isBot = true
      if !isBot
        query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
          if squad__leader != agentEid
            query(squad__leader) <| $ [es] (transform aka leader_transform : float3x4)
              let pos = owner.blackBoard |> datablock_getPoint3(posParam)
              let distSq = length_sq(x0z(leader_transform[3] - pos))
              if distSq < square(minDistToLeader)
                let dir = normalize(x0z(pos - leader_transform[3]))
                let newPos = pos + dir * (minDistToLeader - sqrt(distSq))
                owner.blackBoard |> set(posParam, newPos)
    return EBehResult.ER_SUCCESS

[beh_node(name="fixLookDirPos")]
class FixLookDirPos : BehNodeAdapter
  posParam : int = -1
  goodLookDist : float = 5.0
  fromPosParam : int = -1
  fromPosOffsetDirPosParam : int = -1
  fromPosOffsetDist : float = 0.0
  failOnFix : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    goodLookDist = data |> datablock_getReal("goodLookDist", goodLookDist)
    if datablock_find_param(data, "fromPosParam") >= 0
      fromPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "fromPosParam", ""), float3())
    if datablock_find_param(data, "fromPosOffsetDirPosParam") >= 0
      fromPosOffsetDirPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "fromPosOffsetDirPosParam", ""), float3())
    fromPosOffsetDist = data |> datablock_getReal("fromPosOffsetDist", fromPosOffsetDist)
    failOnFix = data |> datablock_getBool("failOnFix", failOnFix)

  def trace_for_obstruction(pos : float3; dir : float3; var dist : float&; our_team : int; self_eid : EntityId)
    
    if rayhit_normalized(pos, dir, dist, ETF_ALL, -1)
      return true
    var result = false
    trace_entities_in_grid(ecs_hash("humans"), pos, dir, dist, INVALID_ENTITY_ID, SortIntersections.NO) <| $(intersections : array<IntersectedEntity>#)
      for intersection in intersections
        if intersection.eid != self_eid
          
          
          if dot(normalize(intersection.pos - pos), dir) > 0.9
            if (get_int(intersection.eid, "team") ?? TEAM_UNASSIGNED) == our_team
              dist = min(dist, intersection.t)
              result = true
    return result

  def override update(dt : float) : EBehResult
    if posParam < 0
      return EBehResult.ER_SUCCESS

    let agentEid = beh_tree_eid(owner)
    var agentTeam = TEAM_UNASSIGNED
    var hasFromPos = false
    var fromPos = float3()
    query(agentEid) <| $ [es] (transform : float3x4; walker_agent : EntityAgent; team : int = TEAM_UNASSIGNED;
                               squad_member__isPersonalOrder : bool; squad_member__orderType : int;
                               squad_member__followLeaderStance : int)
      agentTeam = team
      fromPos = transform[3]
      fromPos.y = walker_agent.shootFrom[STANCE_STAND].y
      if squad_member__isPersonalOrder
        if squad_member__orderType == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_CROUCHED)
          fromPos.y = walker_agent.shootFrom[STANCE_CROUCH].y
        elif squad_member__orderType == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_PRONE)
          fromPos.y = walker_agent.shootFrom[STANCE_CRAWL].y
      else
        if squad_member__followLeaderStance == STANCE_CROUCH
          fromPos.y = walker_agent.shootFrom[STANCE_CROUCH].y
        elif squad_member__followLeaderStance == STANCE_CRAWL
          fromPos.y = walker_agent.shootFrom[STANCE_CRAWL].y
      hasFromPos = true
    if fromPosParam >= 0
      fromPos = owner.blackBoard |> datablock_getPoint3(fromPosParam)
      hasFromPos = true
    if !hasFromPos
      return EBehResult.ER_SUCCESS
    if fromPosOffsetDirPosParam >= 0
      let fromPosOffsetDirPos = owner.blackBoard |> datablock_getPoint3(fromPosOffsetDirPosParam)
      fromPos += normalize(fromPosOffsetDirPos - fromPos) * fromPosOffsetDist

    let toPos = owner.blackBoard |> datablock_getPoint3(posParam)

    var dir = toPos - fromPos
    dir.y = 0.0
    if length_sq(dir) < 0.00001
      return EBehResult.ER_SUCCESS
    dir = normalize(dir)

    var dist = goodLookDist
    if !trace_for_obstruction(fromPos, dir, dist, agentTeam, agentEid)
      return EBehResult.ER_SUCCESS

    if failOnFix
      return EBehResult.ER_FAILED

    let dir2 = float3(dir.z, 0.0, -dir.x)
    let dir2a = normalize(dir + dir2)
    var dist2a = goodLookDist
    if !trace_for_obstruction(fromPos, dir2a, dist2a, agentTeam, agentEid)
      owner.blackBoard |> set(posParam, fromPos + dir2a * goodLookDist)
      return EBehResult.ER_SUCCESS

    let dir3 = float3(-dir.z, 0.0, dir.x)
    let dir3a = normalize(dir + dir3)
    var dist3a = goodLookDist
    if !trace_for_obstruction(fromPos, dir3a, dist3a, agentTeam, agentEid)
      owner.blackBoard |> set(posParam, fromPos + dir3a * goodLookDist)
      return EBehResult.ER_SUCCESS

    var dist4 = goodLookDist
    if !trace_for_obstruction(fromPos, -dir, dist4, agentTeam, agentEid)
      owner.blackBoard |> set(posParam, fromPos - dir * goodLookDist)
      return EBehResult.ER_SUCCESS

    var dist2 = goodLookDist
    if !trace_for_obstruction(fromPos, dir2, dist2, agentTeam, agentEid)
      owner.blackBoard |> set(posParam, fromPos + dir2 * goodLookDist)
      return EBehResult.ER_SUCCESS

    var dist3 = goodLookDist
    if !trace_for_obstruction(fromPos, dir3, dist3, agentTeam, agentEid)
      owner.blackBoard |> set(posParam, fromPos + dir3 * goodLookDist)
      return EBehResult.ER_SUCCESS

    if dist < dist2a
      dist = dist2a
      dir = dir2a
    if dist < dist3a
      dist = dist3a
      dir = dir3a
    if dist < dist3
      dist = dist3
      dir = dir3
    if dist < dist2
      dist = dist2
      dir = dir2

    owner.blackBoard |> set(posParam, fromPos + dir * goodLookDist)
    return EBehResult.ER_SUCCESS


[beh_node(name="isPointAhead")]
class IsPointAhead : BehNodeAdapter
  posParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())

  def override update(dt : float) : EBehResult
    if posParam < 0
      return EBehResult.ER_FAILED

    let pt = owner.blackBoard |> datablock_getPoint3(posParam)

    var result = false
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (transform : float3x4)
      let dirToPt = normalize(pt - transform[0])
      result = dot(transform[0], dirToPt) > 0.0

    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="isCurrentWeaponRequiresLongAiming")]
class IsCurrentWeaponRequiresLongAiming : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var result = false
    query(agentEid) <| $ [es] (human_weap__currentGunEid : EntityId)
      query(human_weap__currentGunEid) <| $ [es] (specialAIWeaponType : int)
        if specialAIWeaponType == int(SpecialAIWeaponType.ROCKET_LAUNCHERS)
          result = true
        elif specialAIWeaponType == int(SpecialAIWeaponType.ANTI_TANK_RIFLES)
          result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="isDownSlope")]
class IsDownSlopeNode : BehNodeAdapter
  toPosParam : int = -1

  minDist = 1.0
  distCheck = 1.0
  distToHeighthCoef = 0.1

  def override loadFromBlk(var data : DataBlock) : void
    toPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toPosParam", ""), float3())

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var agentPos = float3()
    query(agentEid) <| $ [es] (transform : float3x4)
      agentPos = transform[3]
    if agentPos == float3()
      return EBehResult.ER_FAILED

    let toPos = owner.blackBoard |> datablock_getPoint3(toPosParam)
    let delta = toPos - agentPos
    if length_sq(delta) < square(minDist)
      return EBehResult.ER_FAILED

    let fromPos = agentPos + float3(0.0, 0.25, 0.0)
    let dirDelta = normalize(delta)
    let dirDown = float3(0, -1, 0)
    var norm : float3

    var dist1 = 2.0
    if !traceray_normalized(fromPos, dirDown, dist1, norm, ETF_DEFAULT)
      return EBehResult.ER_FAILED
    var dist2 = 2.0
    if !traceray_normalized(fromPos + dirDelta * distCheck, dirDown, dist2, norm, ETF_DEFAULT)
      return EBehResult.ER_FAILED
    if dist2 < dist1 + distCheck * distToHeighthCoef
      return EBehResult.ER_FAILED
    return EBehResult.ER_SUCCESS


[beh_node(name="findWeaponSlotWithSpecAIType")]
class FindWeaponSlotWithSpecAIType : BehNodeAdapter
  outParam : int = -1
  specWeapAIType : int = 0
  minAmmo : int = 0
  targetEidParam : int = -1
  maxLowAircraftHeight : float = 15.0
  maxLowAircraftSpeed : float = 30.0

  def override loadFromBlk(var data : DataBlock) : void
    outParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toParam", ""), -1)
    minAmmo = datablock_getInt(data, "minAmmo", minAmmo)
    if datablock_find_param(data, "targetEidParam") >= 0
      targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", ""), 0)

    let KM_H_IN_M_S = 1000.0 / 3600.0
    maxLowAircraftSpeed = datablock_getReal(data, "maxLowAircraftSpeed", maxLowAircraftSpeed)
    maxLowAircraftSpeed *= KM_H_IN_M_S
    maxLowAircraftHeight = datablock_getReal(data, "maxLowAircraftHeight", maxLowAircraftHeight)

    let weapTypeName = datablock_getStr(data, "specAIWeapTypeName", "")
    for i in range(length(SPECIAL_AI_WEAPON_TYPE_NAMES))
      if weapTypeName == SPECIAL_AI_WEAPON_TYPE_NAMES[i]
        specWeapAIType = i

  def override update(dt : float) : EBehResult
    var found = false
    query(beh_tree_eid(owner)) <| $ [es] (transform aka agent_transform : float3x4; human_weap__gunEids : EidList)
      for slot_index, gunEid in iter_range(human_weap__gunEids), human_weap__gunEids
        if minAmmo > 0 && !check_ai_gun_has_min_ammo(gunEid, minAmmo)
          continue
        if !check_ai_gun_has_spec_ai_type(gunEid, specWeapAIType)
          continue
        if targetEidParam >= 0
          let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
          var canShootTarget = true
          var isAntiAircraftGun = false
          var isLowAircraftGun = false
          var isGuidedGun = false
          query(gunEid) <| $ [es] (specialAIWeaponType : int = 0; combatFiringAntiAircraft : bool = false; combatFiringLowAircrafts : bool = false)
            isAntiAircraftGun = combatFiringAntiAircraft
            isLowAircraftGun = combatFiringLowAircrafts
            isGuidedGun = specialAIWeaponType == int(SpecialAIWeaponType.ATGM_MPADS_LAUNCHERS)
          query(targetEid) <| $ [es] (transform aka vehicle_transform : float3x4;
                                      ai_target : Target;
                                      unit_tag__tank : Tag const?;
                                      unit_tag__aircraft : Tag const?)
            if unit_tag__tank != null && (isAntiAircraftGun && !isLowAircraftGun)
              canShootTarget = false
            elif unit_tag__aircraft != null
              if !isAntiAircraftGun && !isLowAircraftGun
                canShootTarget = false
              if isLowAircraftGun && (length_sq(ai_target.velocity) > maxLowAircraftSpeed || vehicle_transform[3].y > agent_transform[3].y + maxLowAircraftHeight)
                canShootTarget = false
            elif isGuidedGun && unit_tag__tank == null && unit_tag__aircraft == null
              canShootTarget = false
          if !canShootTarget
            continue
        owner.blackBoard |> set(outParam, slot_index)
        found = true
        break
    return found ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="findWeaponSlotWithTag")]
class FindWeaponSlotWithTag : BehNodeAdapter
  outParam : int = -1
  tag : string = ""
  tagHash : uint
  minAmmo : int = 0

  def override loadFromBlk(var data : DataBlock) : void
    outParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toParam", "preferedWeapon"), -1)
    tag = datablock_getStr(data, "tag", "")
    tagHash = ecs_hash(tag)
    minAmmo = datablock_getInt(data, "minAmmo", minAmmo)

  def override update(dt : float) : EBehResult
    if tag == ""
      return EBehResult.ER_FAILED
    var found = false
    query(beh_tree_eid(owner)) <| $ [es] (human_weap__gunEids : EidList)
      for slot_index, gunEid in iter_range(human_weap__gunEids), human_weap__gunEids
        if !has(gunEid, tag, tagHash)
          continue
        if minAmmo > 0 && !check_ai_gun_has_min_ammo(gunEid, minAmmo)
          continue
        owner.blackBoard |> set(outParam, slot_index)
        found = true
        break
    return found ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


def is_vehicle_with_alive_crew(vehicle_eid : EntityId)
  var hasCrew = false
  query(vehicle_eid) <| $ [es] (unit__ref : UnitRef)
    let vehicleUnit = unit__ref.unit
    if vehicleUnit != null && get_crewman_alive_count(vehicleUnit) > 0
      hasCrew = true
  return hasCrew

[beh_node(name="findPiercableEnemyVehicle")]
class FindPiercableEnemyVehicle : BehNodeAdapter
  inTargetEidParam : int = -1

  outTargetEidParam : int = -1
  outLocalPosParam : int = -1
  outShootStanceParam : int = -1
  outShootLocalPosParam : int = -1

  weaponSlotParam : int = -1
  shootStances : int3 = int3(2, 2, 2)
  chanceTryNotPenetrate : float = 10.0
  chanceToTargetHumanPlayer : float = 0.2

  ignoreMoving : bool = true
  ignoreMovingSpeed : float = 20.0
  ignoreWithNoCrew : bool = false

  ignoreFlyingSpeed : float = 900.0
  shootAirPrepTime : float = 7.0
  shootAirCheckDist : float = 100.0
  maxLowAircraftHeight : float = 15.0
  maxLowAircraftSpeed : float = 30.0

  distanceErrorCoef : float = 1.1
  randOffset : float2 = float2(0.35, 0.15)
  withSecondaryChance : float = 0.25

  wideTraceRadius : float = 0.25
  wideTraceOffsetUp : float = 0.0
  wideTraceDistance : float = 5.0

  maxTargetsProcessed : int = 5
  maxPointsPerTarget : int = 5

  runTeam : int = 0
  runFarTracersEid : EntityId = INVALID_ENTITY_ID
  runAgentTransform : float3x4 = float3x4()
  runAgentShootUpPos : float3 = float3()
  runAgentShootForwPos : float3 = float3()
  runAgentShootDownPos : float3 = float3()
  runShootGuided : bool = false
  runShootAntiAircraft : bool = false
  runShootLowAircrafts : bool = false
  runShootVel : float = 0.0
  runShellId : PropsId = PropsId()
  runBallisticCoef : float = 1.0
  runShootRange : float2 = float2()
  runTicketIdx : int = -1

  runStep : int = 0
  runIndex1 : int = 0
  runIndex2 : int = 0
  runTargetNoPierceCheck : bool = false
  runTargetScore : float = 0.0
  runShootPos : float3 = float3()
  runShootStance : int = -1
  runBestEid : EntityId = INVALID_ENTITY_ID
  runBestScore : float = 0.0
  runBestLocalPos : float3 = float3()
  runBestShootPos : float3 = float3()
  runBestStance : int = -1

  SCAN_TICKET_TIMEOUT = 1.0
  BASE_SCORE_VALUE = 100000.0
  TANK_SCORE_MULTIPLIER = 5.0

  STEP_INIT_CHECK = 1
  STEP_TRACE_TARGETS = 2
  STEP_DONE = 3

  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "inTargetEidParam") >= 0
      inTargetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "inTargetEidParam", ""), 0)

    outTargetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outTargetEidParam", ""), 0)
    outLocalPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outLocalPosParam", ""), float3())
    if datablock_find_param(data, "outShootStanceParam") >= 0
      outShootStanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outShootStanceParam", ""), 1)
    if datablock_find_param(data, "outShootLocalPosParam") >= 0
      outShootLocalPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outShootLocalPosParam", ""), float3())

    weaponSlotParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "weaponSlotParam", ""), -1)
    shootStances = datablock_getIPoint3(data, "shootStances", shootStances)
    if datablock_find_param(data, "shootStance") >= 0
      let stance = datablock_getInt(data, "shootStance", 1)
      shootStances = int3(stance, stance, stance)

    chanceTryNotPenetrate = datablock_getReal(data, "chanceTryNotPenetrate", chanceTryNotPenetrate)

    let KM_H_IN_M_S = 1000.0 / 3600.0
    ignoreMoving = datablock_getBool(data, "ignoreMoving", ignoreMoving)
    ignoreMovingSpeed = datablock_getReal(data, "ignoreMovingSpeed", ignoreMovingSpeed)
    ignoreMovingSpeed *= KM_H_IN_M_S

    ignoreWithNoCrew = datablock_getBool(data, "ignoreWithNoCrew", ignoreWithNoCrew)

    ignoreFlyingSpeed = datablock_getReal(data, "ignoreFlyingSpeed", ignoreFlyingSpeed)
    ignoreFlyingSpeed *= KM_H_IN_M_S

    maxLowAircraftSpeed = datablock_getReal(data, "maxLowAircraftSpeed", maxLowAircraftSpeed)
    maxLowAircraftSpeed *= KM_H_IN_M_S

    shootAirPrepTime = datablock_getReal(data, "shootAirPrepTime", shootAirPrepTime)
    shootAirCheckDist = datablock_getReal(data, "shootAirCheckDist", shootAirCheckDist)

    distanceErrorCoef = datablock_getReal(data, "distanceErrorCoef", distanceErrorCoef)

    wideTraceRadius = datablock_getReal(data, "wideTraceRadius", wideTraceRadius)
    wideTraceOffsetUp = datablock_getReal(data, "wideTraceOffsetUp", wideTraceOffsetUp)
    wideTraceDistance = datablock_getReal(data, "wideTraceDistance", wideTraceDistance)

    maxTargetsProcessed = datablock_getInt(data, "maxTargetsProcessed", maxTargetsProcessed)
    maxPointsPerTarget = datablock_getInt(data, "maxPointsPerTarget", maxPointsPerTarget)

  def override init() : void
    runStep = STEP_INIT_CHECK
    clear_targets()

  def override exit() : void
    runStep = STEP_INIT_CHECK
    clear_targets()

  def clear_targets()
    query(beh_tree_eid(owner)) <| $ [es] (var beh_tree__runEidList : EidList&; var beh_tree__runPosList : Point3List&)
      beh_tree__runEidList |> clear()
      beh_tree__runPosList |> clear()

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let curTime = get_sync_time()

    if runStep == STEP_INIT_CHECK
      var gunEid = INVALID_ENTITY_ID
      let gunSlot = owner.blackBoard |> datablock_getInt(weaponSlotParam)
      query(agentEid) <| $ [es] (transform : float3x4; human_weap__gunEids : EidList; team : int; walker_agent : EntityAgent)
        if gunSlot >= 0 && gunSlot < length(human_weap__gunEids)
          let checkGunEid = human_weap__gunEids[gunSlot]
          query(checkGunEid) <| $ [es] (combatFiringRange : float2;
                                        gun__curShellId : PropsId;
                                        combatFiringAntiAircraft : bool = false;
                                        combatFiringLowAircrafts : bool = false;
                                        combatBallisticCoef : float = 0.0;
                                        specialAIWeaponType : int = 0)
            gunEid = checkGunEid
            runShootGuided = specialAIWeaponType == int(SpecialAIWeaponType.ATGM_MPADS_LAUNCHERS)
            runShootAntiAircraft = combatFiringAntiAircraft
            runShootLowAircrafts = combatFiringLowAircrafts
            runShootVel = 50.0
            if !runShootGuided
              shell_start_get_props(gun__curShellId) <| $(shellStartProps : ShellStartProps)
                if shellStartProps.speed > 0.0
                  runShootVel = shellStartProps.speed
              get_props_RocketProperties(gun__curShellId) <| $(rocketMotorProps : RocketProperties)
                let speed = rocketMotorProps.rocketMotor.endSpeed
                if speed > 0.0
                  runShootVel = speed
            runShellId = gun__curShellId
            runBallisticCoef = combatBallisticCoef
            runShootRange = combatFiringRange
            runAgentTransform = transform
            let invTr = inverse(transform)
            runAgentShootUpPos = invTr * walker_agent.shootFrom[shootStances.x]
            runAgentShootForwPos = invTr * walker_agent.shootFrom[shootStances.y]
            runAgentShootDownPos = invTr * walker_agent.shootFrom[shootStances.z]
            runTeam = team
      if gunEid == INVALID_ENTITY_ID
        return EBehResult.ER_FAILED

      runFarTracersEid = INVALID_ENTITY_ID
      find_query() <| $ [es] (eid : EntityId; team__id : int)
        if team__id == runTeam
          runFarTracersEid = eid
          return true
        return false
      if runFarTracersEid == INVALID_ENTITY_ID
        return EBehResult.ER_FAILED

      runTicketIdx = -1
      query(runFarTracersEid) <| $ [es] (team_bots__maxFarTracesAtOnce : int;
                                         var team_bots__farTracersEids : EidList&;
                                         var team_bots__farTracersTimeouts : FloatList&)
        for i in iter_range(team_bots__farTracersEids)
          if team_bots__farTracersEids[i] == agentEid || team_bots__farTracersTimeouts[i] < curTime
            team_bots__farTracersEids[i] = agentEid
            team_bots__farTracersTimeouts[i] = curTime + SCAN_TICKET_TIMEOUT
            runTicketIdx = i
            break
        let numAllocated = length(team_bots__farTracersEids)
        if runTicketIdx < 0 && numAllocated < team_bots__maxFarTracesAtOnce
          runTicketIdx = numAllocated
          team_bots__farTracersEids |> push(agentEid)
          team_bots__farTracersTimeouts |> push(curTime + SCAN_TICKET_TIMEOUT)
      if runTicketIdx < 0
        return EBehResult.ER_FAILED

      var numTargets = 0
      query(agentEid) <| $ [es] (var beh_tree__runEidList : EidList&)
        beh_tree__runEidList |> clear()

        let findRadius = runShootRange.y * distanceErrorCoef

        var givenTargetOnly = false
        if inTargetEidParam >= 0
          let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(inTargetEidParam)))
          if targetEid != INVALID_ENTITY_ID
            givenTargetOnly = true
            beh_tree__runEidList |> push(targetEid)
            ++numTargets

        if !runShootAntiAircraft && !givenTargetOnly
          let minDistSq = square(safediv(runShootRange.x, distanceErrorCoef))
          let maxDistSq = square(findRadius)
          let maxVelSq = square(ignoreMovingSpeed)
          for_each_entity_in_grid(ecs_hash("vehicles"), BSphere3(runAgentTransform[3], findRadius), GridEntCheck.BOUNDING) <| $(that_eid : EntityId)
            query(that_eid) <| $ [es(REQUIRE_NOT=unit_tag__aircraft)] (transform : float3x4; team : int; ai_target : Target)
              if that_eid == agentEid
                return
              if !ai_target.isAlive || team <= 0 || is_teams_friendly(team, runTeam)
                return
              if ignoreMoving && length_sq(ai_target.velocity) > maxVelSq
                return
              let distSq = distance_sq(transform[3], runAgentTransform[3])
              if distSq < minDistSq || distSq > maxDistSq
                return
              if ignoreWithNoCrew && !is_vehicle_with_alive_crew(that_eid)
                return
              beh_tree__runEidList |> push(that_eid)
              ++numTargets

          if rnd_float(0.0, 1.0) < chanceToTargetHumanPlayer
            query(agentEid) <| $ [es] (agent_dangers : AgentDangers)
              for danger in agent_dangers.dangers
                if !danger.traceable || danger.distance < runShootRange.x || danger.distance > runShootRange.y
                  continue
                var dangerOK = false
                query(danger.eid) <| $ [es] (transform : float3x4; isAlive : bool = true; isDowned : bool = false; isInVehicleHidden : bool = false; beh_tree__enabled : bool)
                  let LOOKING_TO_AGENT_COS = 0.8
                  if !beh_tree__enabled && isAlive && !isDowned && !isInVehicleHidden && dot(transform[0], normalize(runAgentTransform[3] - transform[3])) > LOOKING_TO_AGENT_COS
                    dangerOK = true
                if dangerOK
                  beh_tree__runEidList |> push(danger.eid)
                  ++numTargets

        if (runShootAntiAircraft || runShootLowAircrafts) && !givenTargetOnly
          let minDistSq = square(safediv(runShootRange.x, distanceErrorCoef))
          let maxDistSq = square(findRadius)
          let maxVelSq = runShootAntiAircraft ? square(ignoreFlyingSpeed) : square(maxLowAircraftSpeed)
          query() <| $ [es(REQUIRE=unit_tag__aircraft)] (eid aka that_eid : EntityId; transform : float3x4; team : int; ai_target : Target; aircraft__troubleScore : float = 1.0)
            if !ai_target.isAlive || team <= 0 || is_teams_friendly(team, runTeam) || aircraft__troubleScore <= 0.5
              return
            if length_sq(ai_target.velocity) > maxVelSq
              return
            if !runShootAntiAircraft && runShootLowAircrafts && transform[3].y > runAgentTransform[3].y + maxLowAircraftHeight
              return
            let predictedTargetPos = transform[3] + ai_target.velocity * shootAirPrepTime
            let distSq = distance_sq(predictedTargetPos, runAgentTransform[3])
            if distSq < minDistSq || distSq > maxDistSq
              return
            if ignoreWithNoCrew && !is_vehicle_with_alive_crew(that_eid)
              return
            beh_tree__runEidList |> push(that_eid)
            ++numTargets

        if length(beh_tree__runEidList) > 1
          shuffle(beh_tree__runEidList)
        if length(beh_tree__runEidList) > maxTargetsProcessed
          beh_tree__runEidList |> resize(maxTargetsProcessed)

      if numTargets <= 0
        return EBehResult.ER_FAILED
      runStep = STEP_TRACE_TARGETS
      runIndex1 = 0
      runIndex2 = 0
      runBestEid = INVALID_ENTITY_ID
      runBestScore = 0.0
      runBestLocalPos = float3()
      runBestShootPos = float3()
      runBestStance = shootStances.y
      return EBehResult.ER_RUNNING

    if runStep == STEP_TRACE_TARGETS
      query(runFarTracersEid) <| $ [es] (var team_bots__farTracersEids : EidList&;
                                         var team_bots__farTracersTimeouts : FloatList&)
        if runTicketIdx >= 0 && runTicketIdx < length(team_bots__farTracersEids)
          team_bots__farTracersEids[runTicketIdx] = agentEid
          team_bots__farTracersTimeouts |> push(curTime + SCAN_TICKET_TIMEOUT)

      var done = false
      query(agentEid) <| $ [es] (beh_tree__runEidList : EidList; var beh_tree__runPosList : Point3List&)
        let numTargets = length(beh_tree__runEidList)
        while runIndex1 < numTargets
          let targetEid = beh_tree__runEidList[runIndex1]

          if runIndex2 == 0
            query(targetEid) <| $ [es] (transform : float3x4; unit_tag__tank : Tag const?; dm_ai__pointsYRange : float2 = float2(0.0, 2.0))
              beh_tree__runPosList |> clear()

              let midPoint = transform * float3(0.0, (dm_ai__pointsYRange.x + dm_ai__pointsYRange.y) * 0.5, 0.0)

              let agentDir = normalize(midPoint.xz - runAgentTransform[3].xz)
              runAgentTransform[0] = float3(agentDir.x, 0.0, agentDir.y)
              runAgentTransform[1] = float3(0.0, 1.0, 0.0)
              runAgentTransform[2] = cross(runAgentTransform[0], runAgentTransform[1])

              let midCheckAgentShootPos = runAgentTransform * runAgentShootDownPos
              let midDelta = midPoint - midCheckAgentShootPos
              let midDir = normalize(midDelta)

              let SHOOT_CLING_SIN = 0.05
              if midDir.y > SHOOT_CLING_SIN
                runShootPos = runAgentTransform * runAgentShootUpPos
                runShootStance = shootStances.x
              elif midDir.y < -SHOOT_CLING_SIN
                runShootPos = runAgentTransform * runAgentShootDownPos
                runShootStance = shootStances.z
              else
                runShootPos = runAgentTransform * runAgentShootForwPos
                runShootStance = shootStances.y

              let isTargetAircraft = has(targetEid, "unit_tag__aircraft")

              let targetPoint = transform * float3(0.0, dm_ai__pointsYRange.y, 0.0)
              let targetDelta = targetPoint - runShootPos
              let targetDir = normalize(targetDelta)
              let targetDist = !isTargetAircraft ? length(targetDelta) : shootAirCheckDist

              runTargetScore = safediv(BASE_SCORE_VALUE, targetDist)
              if unit_tag__tank != null
                runTargetScore *= TANK_SCORE_MULTIPLIER

              if runBestEid != INVALID_ENTITY_ID && runBestScore >= runTargetScore
                return

              let noCrew = ignoreWithNoCrew || !is_vehicle_with_alive_crew(targetEid)
              var targetDMAIPoints : array<TargetDMAIPoint>
              pick_target_dm_ai_points(targetDMAIPoints, maxPointsPerTarget, runShootPos, targetEid, noCrew, randOffset,  false, withSecondaryChance)
              for point in targetDMAIPoints
                push(beh_tree__runPosList, point.worldPos)

              runTargetNoPierceCheck = false
              if empty(beh_tree__runPosList)
                runTargetNoPierceCheck = isTargetAircraft || has(targetEid, "human")
                if !runTargetNoPierceCheck
                  return
                beh_tree__runPosList |> push(midPoint)

              let dist = targetDist
              if (rayhit_normalized(runShootPos, targetDir, dist, ETF_DEFAULT, -1) ||
                  traceTransparencyRayRIGenNormalized(runShootPos, targetDir, dist, 0.01) ||
                  rayhit_smoke_occluders(runShootPos, targetPoint))
                beh_tree__runPosList |> clear()
                return

              let pt1 = runShootPos + float3(0.0, wideTraceOffsetUp, 0.0) - targetDir * wideTraceRadius
              let pt2 = pt1 + targetDir * (wideTraceDistance + wideTraceRadius)
              var queryOut = ShapeQueryOutput()
              if sphere_cast(pt1, pt2, wideTraceRadius, queryOut)
                beh_tree__runPosList |> clear()
                return

          let numPoints = length(beh_tree__runPosList)
          if runIndex2 >= numPoints
            runIndex2 = 0
            ++runIndex1
            break

          let targetHitPos = beh_tree__runPosList[runIndex2]
          ++runIndex2

          query(targetEid) <| $ [es] (transform : float3x4)
            var aimShootHitPos = targetHitPos
            if runTargetNoPierceCheck || trace_pierce_shot(aimShootHitPos, runShootPos, targetHitPos, runShootVel, runShellId, runBallisticCoef, targetEid, chanceTryNotPenetrate)
              runIndex2 = numPoints
              if runBestEid == INVALID_ENTITY_ID || runBestScore < runTargetScore
                runBestEid = targetEid
                runBestScore = runTargetScore
                runBestLocalPos = inverse(transform) * aimShootHitPos
                runBestShootPos = inverse(runAgentTransform) * runShootPos
                runBestStance = runShootStance

          if runIndex2 >= numPoints
            runIndex2 = 0
            ++runIndex1
        done = runIndex1 >= numTargets
      if !done
        return EBehResult.ER_RUNNING
      runStep = STEP_DONE

    clear_targets()

    if outTargetEidParam >= 0
      owner.blackBoard |> set(outTargetEidParam, int(uint(runBestEid)))
    if outLocalPosParam >= 0
      owner.blackBoard |> set(outLocalPosParam, runBestLocalPos)
    if outShootStanceParam >= 0
      owner.blackBoard |> set(outShootStanceParam, runBestStance)
    if outShootLocalPosParam >= 0
      owner.blackBoard |> set(outShootLocalPosParam, runBestShootPos)

    return runBestEid != INVALID_ENTITY_ID ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="shootGuidedMissle")]
class ShootGuidedMissle : BehNodeAdapter
  targetUnitParam : int = -1
  targetLocalPosParam : int = -1
  warmupTimeout : float = 7.0
  targetTimeout : float = 10.0

  predictPosTime : float = 0.5

  aimingYawFreqCoef : float = 2.0
  aimingPitchFreqCoef : float = 0.2
  aimingYawAngleDeg : float = 1.0
  aimingPitchAngleDeg : float2 = float2(0.0, 30.0)

  DEFAULT_AIMING_PITCH_ANGLE_DEG : float2 = float2(0.0, 30.0)

  prevGuidanceState : int = -1
  timeoutTimer : float = 0.0
  aimingTimer : float = 0.0
  aimingTimeMax : float = 0.0
  makeShot : bool = false
  done : bool = false
  doneTimer : float = 0.0
  doneTimeWait : float = 3.0

  def override loadFromBlk(var data : DataBlock) : void
    targetUnitParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0)
    targetLocalPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetLocalPosParam", ""), float3())
    warmupTimeout = datablock_getReal(data, "warmupTimeout", warmupTimeout)
    targetTimeout = datablock_getReal(data, "targetTimeout", targetTimeout)
    predictPosTime = datablock_getReal(data, "predictPosTime", predictPosTime)
    doneTimeWait = datablock_getReal(data, "doneTimeWait", doneTimeWait)

  def apply_controls(var agent : EntityAgent?&; aim : bool; shoot : bool) : void
    if agent.phys != null
      assume ct = agent.phys.producedCT
      ct |> human_control_state_set_neutral_ctrl()
      ct |> human_control_state_set_walk_speed(0.f)
      ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, aim)
      ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, shoot)
      ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, false)
      ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, false)

  def override init() : void
    var agent = beh_tree_entity_agent(*owner)
    apply_controls(agent, true, false)
    prevGuidanceState = -1
    timeoutTimer = warmupTimeout
    aimingTimer = 0.0
    aimingTimeMax = 0.0
    makeShot = false
    done = false

  def override exit() : void
    var agent = beh_tree_entity_agent(*owner)
    apply_controls(agent, false, false)

  def override update(dt : float) : EBehResult
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetUnitParam)))
    if targetEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    let targetLocalPos = owner.blackBoard |> datablock_getPoint3(targetLocalPosParam)

    var hasTarget = false
    var targetPos = float3()
    query(targetEid) <| $ [es] (transform : float3x4; ai_target : Target const?)
      hasTarget = true
      targetPos = transform * targetLocalPos
      if ai_target != null
        if !ai_target.isAlive
          hasTarget = false
        targetPos += ai_target.velocity * predictPosTime
    if !hasTarget && !done
      return EBehResult.ER_FAILED

    var agent = beh_tree_entity_agent(*owner)
    var agentPos = agent.pos + float3(0.0, 1.0, 0.0)
    query(agent.eid) <| $ [es] (human_weap__currentGunEid : EntityId; walker_agent : EntityAgent)
      agentPos = walker_agent.shootFrom[STANCE_STAND]
      query(human_weap__currentGunEid) <| $ [es] (gun__guidanceState : int; combatAimingPitchDegRange : float2 const?)
        aimingPitchAngleDeg = combatAimingPitchDegRange != null ? *combatAimingPitchDegRange : DEFAULT_AIMING_PITCH_ANGLE_DEG
        if gun__guidanceState != prevGuidanceState
          prevGuidanceState = gun__guidanceState
          if makeShot
            if !done && gun__guidanceState != int(GuidanceLockState.RESULT_TRACKING)
              done = true
              doneTimer = doneTimeWait
          elif gun__guidanceState <= int(GuidanceLockState.RESULT_STANDBY)
            apply_controls(agent, true, true)
            timeoutTimer = warmupTimeout
          elif gun__guidanceState <= int(GuidanceLockState.RESULT_LOCKING)
            apply_controls(agent, true, false)
            timeoutTimer = targetTimeout
          elif gun__guidanceState <= int(GuidanceLockState.RESULT_TRACKING)
            aimingTimeMax = aimingTimer
            makeShot = true

    if !done
      if makeShot
        aimingTimer -= dt
        if aimingTimer <= aimingTimeMax * 0.5
          apply_controls(agent, true, true)
      else
        aimingTimer += dt

      if agent.phys != null
        assume ct = agent.phys.producedCT
        let delta = targetPos - agentPos
        var angles = dir_to_angles(normalize(delta))
        angles.x += cos(aimingTimer * aimingYawFreqCoef) * deg_to_rad(aimingYawAngleDeg)
        angles.y += deg_to_rad(aimingPitchAngleDeg.x) + abs(sin(aimingTimer * aimingPitchFreqCoef) * deg_to_rad(aimingPitchAngleDeg.y - aimingPitchAngleDeg.x))
        angles.y = clamp(angles.y, -PI, PI)
        let dir = angles_to_dir(angles)
        ct |> human_control_state_set_wish_shoot_dir(dir)
        ct |> human_control_state_set_wish_look_dir(dir)
        ct |> human_control_state_set_lean_position(0.f)

      timeoutTimer -= dt
      if timeoutTimer < 0.0
        return EBehResult.ER_FAILED
      return EBehResult.ER_RUNNING

    doneTimer -= dt
    if doneTimer > 0.0
      apply_controls(agent, true, true)
      return EBehResult.ER_RUNNING
    return EBehResult.ER_SUCCESS


[beh_node(name="checkFriendlyFire")]
class CheckFriendlyFire : BehNodeAdapter
  targetUnitParam : int = -1

  midHeight : float = 1.0
  safeRadius : float = 0.8

  def override loadFromBlk(var data : DataBlock) : void
    targetUnitParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0)

  def override update(dt : float) : EBehResult
    var isFriendlyFireEnabled = false
    query() <| $ [es(REQUIRE=gamemodeFriendlyFire)] ()
      isFriendlyFireEnabled = true
    if !isFriendlyFireEnabled
      return EBehResult.ER_SUCCESS

    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_SUCCESS

    let fromPos = agent.pos + float3(0.0, midHeight, 0.0)
    var toPos = float3()

    var hasTarget = false
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetUnitParam)))
    query(targetEid) <| $ [es] (transform : float3x4)
      toPos = transform[3] + float3(0.0, midHeight, 0.0)
      hasTarget = true

    let delta = toPos - fromPos
    let dir = normalize(delta)
    var dist = length(delta)
    if dist > 0.0
      var allyAtLineOfFire = false
      using() <| $(var intersections : IntersectedEntities)
        trace_entities_in_grid_by_capsule(ecs_hash("humans"), fromPos, dir, dist, safeRadius, agent.eid, intersections, SortIntersections.NO)
        for intersection in intersections
          let eid = intersection.eid
          if eid == targetEid || eid == agent.eid
            continue
          query(eid) <| $ [es] (team : int)
            if is_teams_friendly(agent.teamId, team)
              allyAtLineOfFire = true
          if allyAtLineOfFire
            break
      if allyAtLineOfFire
        return EBehResult.ER_FAILED

    return EBehResult.ER_SUCCESS

[beh_node(name="traceLineOfSight")]
class TraceLineOfSight : BehNodeAdapter
  fromLocalPosParam : int = -1
  fromPosOffset : float3 = float3(0.0, 0.0, 0.0)

  toEidParam : int = -1
  toLocalPosParam : int = -1
  toPosParam : int = -1

  traceDistance : float = 5.0
  traceRadius : float = 1.0
  traceWorld : bool = false
  traceHumans : bool = false
  traceVehicles : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "fromLocalPosParam") >= 0
      fromLocalPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "fromLocalPosParam", ""), float3())
    fromPosOffset = datablock_getPoint3(data, "fromPosOffset", fromPosOffset)

    if datablock_find_param(data, "toEidParam") >= 0
      toEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toEidParam", ""), 0)
    if datablock_find_param(data, "toLocalPosParam") >= 0
      toLocalPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toLocalPosParam", ""), float3())

    if datablock_find_param(data, "toPosParam") >= 0
      toPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toPosParam", ""), float3())

    traceDistance = datablock_getReal(data, "traceDistance", traceDistance)
    traceRadius = datablock_getReal(data, "traceRadius", traceRadius)
    traceWorld = datablock_getBool(data, "traceWorld", traceWorld)
    traceHumans = datablock_getBool(data, "traceHumans", traceHumans)
    traceVehicles = datablock_getBool(data, "traceVehicles", traceVehicles)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var fromPos = float3()
    var hasPos = false
    query(agentEid) <| $ [es] (transform : float3x4)
      hasPos = true
      var fromLocalPos = float3()
      if fromLocalPosParam >= 0
        fromLocalPos = owner.blackBoard |> datablock_getPoint3(fromLocalPosParam)
      fromPos = transform * fromLocalPos + fromPosOffset
    if !hasPos
      return EBehResult.ER_FAILED

    var toPos = float3()
    var excludeEid = INVALID_ENTITY_ID
    if toEidParam >= 0
      hasPos = false
      let toEid = EntityId(uint(owner.blackBoard |> datablock_getInt(toEidParam)))
      query(toEid) <| $ [es] (transform : float3x4)
        hasPos = true
        excludeEid = toEid
        var toLocalPos = float3()
        if toLocalPosParam >= 0
          toLocalPos = owner.blackBoard |> datablock_getPoint3(toLocalPosParam)
        toPos = transform * toLocalPos
      if !hasPos
        return EBehResult.ER_FAILED
    elif toPosParam >= 0
      toPos = owner.blackBoard |> datablock_getPoint3(toPosParam)
    else
      return EBehResult.ER_FAILED

    let toDir = normalize(toPos - fromPos)

    if traceWorld
      var queryOut = ShapeQueryOutput()
      let endPos = fromPos + toDir * traceDistance
      if sphere_cast(fromPos, endPos, traceRadius, queryOut)
        return EBehResult.ER_FAILED

    if traceHumans
      var dist = traceDistance
      if trace_entities_in_grid_by_capsule(ecs_hash("humans"), fromPos, toDir, dist, traceRadius, agentEid)
        return EBehResult.ER_FAILED

    if traceVehicles
      var dist = traceDistance
      if trace_entities_in_grid_by_capsule(ecs_hash("vehicles"), fromPos, toDir, dist, traceRadius, excludeEid)
        return EBehResult.ER_FAILED

    return EBehResult.ER_SUCCESS

[beh_node(name="traceSeePoint")]
class TraceSeePoint : BehNodeAdapter
  posParam : int = -1
  addHeight : float = 1.0
  maxTraceDist : float = -1.0

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    addHeight = data |> datablock_getReal("addHeight", addHeight)
    maxTraceDist = data |> datablock_getReal("maxTraceDist", addHeight)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var hasFromPos = false
    var fromPos = float3()
    query(agentEid) <| $ [es] (transform : float3x4; walker_agent : EntityAgent)
      fromPos = transform[3]
      fromPos.y = walker_agent.shootFrom[STANCE_STAND].y
      hasFromPos = true
    if !hasFromPos
      return EBehResult.ER_FAILED

    var toPos = owner.blackBoard |> datablock_getPoint3(posParam)
    toPos.y += addHeight

    let delta = toPos - fromPos
    var dist = length(delta)
    let dir = delta * safeinv(dist)
    if maxTraceDist > 0.0 && dist > maxTraceDist
      dist = maxTraceDist
    if rayhit_normalized(fromPos, dir, dist, ETF_ALL, -1)
      return EBehResult.ER_FAILED

    return EBehResult.ER_SUCCESS


[beh_node(name="getRegroupPos")]
class GetRegroupPos : BehNodeAdapter
  posParam : int = -1
  dirPosParam : int = -1
  stanceParam : int = -1
  toPosParam : int = -1
  toDirPosParam : int = -1
  leanParam : int = -1
  runParam : int = -1
  useEntityParam : int = -1

  DIR_POS_DIST = 25.0
  MAX_DISTANCE_NO_RUN = 5.0

  def override loadFromBlk(var data : DataBlock) : void
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (transform : float3x4)
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), transform[3])
    if datablock_find_param(data, "dirPosParam") >= 0
      dirPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "dirPosParam", ""), float3())
    if datablock_find_param(data, "stanceParam") >= 0
      stanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "stanceParam", ""), 1)
    if datablock_find_param(data, "toPosParam") >= 0
      toPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toPosParam", ""), float3())
    if datablock_find_param(data, "toDirPosParam") >= 0
      toDirPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toDirPosParam", ""), float3())
    if datablock_find_param(data, "leanParam") >= 0
      leanParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "leanParam", ""), 0.0)
    if datablock_find_param(data, "runParam") >= 0
      runParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "runParam", ""), -1)
    if datablock_find_param(data, "useEntityParam") >= 0
      useEntityParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "useEntityParam", ""), -1)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    owner.blackBoard |> set(posParam, agent.pos)
    if dirPosParam >= 0
      owner.blackBoard |> set(dirPosParam, float3()) 
    if stanceParam >= 0
      owner.blackBoard |> set(stanceParam, -1) 
    if toPosParam >= 0
      owner.blackBoard |> set(toPosParam, float3()) 
    if toDirPosParam >= 0
      owner.blackBoard |> set(toDirPosParam, float3()) 
    if leanParam >= 0
      owner.blackBoard |> set(leanParam, 0.0) 
    if runParam >= 0
      owner.blackBoard |> set(runParam, -1) 
    if useEntityParam >= 0
      owner.blackBoard |> set(useEntityParam, int(uint(INVALID_ENTITY_ID))) 

    query(agent.eid) <| $ [es] (squad_member__squad : EntityId;
                                squad_member__followLeader : bool;
                                squad_member__followLeaderPos : float3;
                                squad_member__followLeaderDir : float3;
                                squad_member__followLeaderStance : int;
                                squad_member__followLeaderRun : bool;
                                squad_member__isPersonalOrder : bool;
                                squad_member__orderType : int;
                                squad_member__orderPosition : float3;
                                squad_member__orderByDirection : float3;
                                squad_member__orderToPosition : float3 = float3();
                                squad_member__orderToDirection : float3 = float3();
                                squad_member__orderUseEntity : EntityId = INVALID_ENTITY_ID;
                                squad_member__playerEid : EntityId = INVALID_ENTITY_ID;
                                beh_tree__latencyLoadRequire : bool = false)
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId; squadAI_tactical__actionType : int = -1)
        if squad__leader == agent.eid
          return
        if squad_member__isPersonalOrder
          owner.blackBoard |> set(posParam, squad_member__orderPosition)
          var byDir = false
          var byStance = -1
          var byLean = false
          if squad_member__orderType == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_STANDING)
            byDir = true
            byStance = STANCE_STAND
          elif squad_member__orderType == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_CROUCHED)
            byDir = true
            byStance = STANCE_CROUCH
          elif squad_member__orderType == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_PRONE)
            byDir = true
            byStance = STANCE_CRAWL
          elif squad_member__orderType == int(SquadMateOrder.ESMO_PEEKOUT_STANDING)
            byDir = true
            byLean = true
            byStance = STANCE_STAND
          elif squad_member__orderType == int(SquadMateOrder.ESMO_PEEKOUT_CROUCHED)
            byDir = true
            byLean = true
            byStance = STANCE_CROUCH
          elif squad_member__orderType == int(SquadMateOrder.ESMO_PEEKOUT_STAND_UP)
            byDir = true
            byLean = false
            byStance = STANCE_CROUCH
          if dirPosParam >= 0 && byDir
            owner.blackBoard |> set(dirPosParam, squad_member__orderPosition + squad_member__orderByDirection * DIR_POS_DIST)
          if stanceParam >= 0 && byStance >= 0 && !beh_tree__latencyLoadRequire
            owner.blackBoard |> set(stanceParam, byStance)
          if toPosParam >= 0
            owner.blackBoard |> set(toPosParam, squad_member__orderToPosition)
          if toDirPosParam >= 0
            owner.blackBoard |> set(toDirPosParam, squad_member__orderToPosition + squad_member__orderToDirection * DIR_POS_DIST)
          if leanParam >= 0 && byLean
            let toDirLeft = float3(-squad_member__orderToDirection.z, 0.0, squad_member__orderToDirection.x)
            let lean = dot(toDirLeft, squad_member__orderByDirection) > 0.0 ? -1.0 : 1.0
            owner.blackBoard |> set(leanParam, lean)
          if useEntityParam >= 0
            owner.blackBoard |> set(useEntityParam, int(uint(squad_member__orderUseEntity)))
        else
          var isBot = false
          query(squad_member__playerEid) <| $ [es(REQUIRE=playerIsBot)] ()
            isBot = true
          if isBot
            var pos = float3()
            query(squad__leader) <| $ [es] (beh_tree : BehaviourTree)
              let paramId = datablock_find_param(beh_tree.blackBoard, "regroupPosition")
              if paramId >= 0
                pos = datablock_getPoint3(beh_tree.blackBoard, paramId)
                if pos != float3()
                  let isCornerAction = squadAI_tactical__actionType != 2 
                  let radius = !isCornerAction ? rnd_float(5.0, 15.0) : rnd_float(3.0, 5.0)
                  let angle = deg_to_rad(rnd_float(0.0, 360.0))
                  for i in range(5)
                    var newPos = pos
                    let tryRadius = radius / float(i + 1)
                    newPos.x = pos.x + tryRadius * sin(angle)
                    newPos.z = pos.z + tryRadius * cos(angle)
                    let projExtents = float3(2.5, 1.5, 2.5)
                    var projectedPos = newPos + float3(0.0, -0.5, 0.0)
                    if project_to_nearest_navmesh_point_avoid_obstacles(projectedPos, projExtents)
                      if abs(projectedPos.y - newPos.y) < 2.5
                        pos = projectedPos
                        break
            if pos != float3()
              owner.blackBoard |> set(posParam, pos)
              if !squad_member__followLeader
                if dirPosParam >= 0
                  query(agent.eid) <| $ [es] (transform : float3x4)
                    owner.blackBoard |> set(dirPosParam, transform[3] + transform[0] * 10.0)
                if stanceParam >= 0 && !beh_tree__latencyLoadRequire
                  owner.blackBoard |> set(stanceParam, STANCE_CROUCH)
              else
                if dirPosParam >= 0
                  owner.blackBoard |> set(dirPosParam, squad_member__followLeaderPos + squad_member__followLeaderDir * DIR_POS_DIST)
                if stanceParam >= 0 && !beh_tree__latencyLoadRequire
                  owner.blackBoard |> set(stanceParam, squad_member__followLeaderStance)
                if runParam >= 0
                  if distance_sq(squad_member__followLeaderPos, agent.pos) > square(MAX_DISTANCE_NO_RUN)
                    owner.blackBoard |> set(runParam, 1)
                  else
                    owner.blackBoard |> set(runParam, squad_member__followLeaderRun ? 1 : 0)
              return

          if !squad_member__followLeader
            
            owner.blackBoard |> set(posParam, float3())
          else
            owner.blackBoard |> set(posParam, squad_member__followLeaderPos)
            if dirPosParam >= 0
              owner.blackBoard |> set(dirPosParam, squad_member__followLeaderPos + squad_member__followLeaderDir * DIR_POS_DIST)
            if stanceParam >= 0 && !beh_tree__latencyLoadRequire
              owner.blackBoard |> set(stanceParam, squad_member__followLeaderStance)
            if runParam >= 0
              if distance_sq(squad_member__followLeaderPos, agent.pos) > square(MAX_DISTANCE_NO_RUN)
                owner.blackBoard |> set(runParam, 1)
              else
                owner.blackBoard |> set(runParam, squad_member__followLeaderRun ? 1 : 0)

    return EBehResult.ER_SUCCESS

[beh_node(name="makeSquadReaction")]
class MakeSquadReaction : BehNodeAdapter
  makeReaction : string = ""
  def override loadFromBlk(var data : DataBlock) : void
    makeReaction = datablock_getStr(data, "makeReaction", "")
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (var squad_member__makeReaction : das_string&)
      squad_member__makeReaction := makeReaction
    return EBehResult.ER_SUCCESS

[beh_node(name="isFollowingLeader")]
class IsFollowingLeader : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED
    var follow = false
    query(agent.eid) <| $ [es] (squad_member__isPersonalOrder : bool;
                                squad_member__orderType : int;
                                squad_member__followLeader : bool)
      if !squad_member__isPersonalOrder || squad_member__orderType == int(SquadMateOrder.ESMO_NO_ORDER)
        follow = squad_member__followLeader
    return follow ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="checkAndResetForceReposition")]
class CheckAndResetForceReposition : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (var squad_member__forceReposition : bool&)
      if squad_member__forceReposition
        squad_member__forceReposition = false
        res = EBehResult.ER_SUCCESS
    return res

[beh_node(name="hasWatchDirection")]
class HasWatchDirection : BehNodeAdapter
  noFollowLeader : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    noFollowLeader = datablock_getBool(data, "noFollowLeader", noFollowLeader)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED
    var result = false
    query(agent.eid) <| $ [es] (squad_member__isPersonalOrder : bool;
                                squad_member__orderType : int;
                                squad_member__followLeader : bool;
                                squad_member__followLeaderDir : float3)
      if squad_member__isPersonalOrder && squad_member__orderType != int(SquadMateOrder.ESMO_NO_ORDER)
        if is_squad_mate_order_overwatch_by_direction(squad_member__orderType)
          result = true
      elif !noFollowLeader
        if squad_member__followLeader && squad_member__followLeaderDir != float3()
          result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="hasOrder")]
class HasOrder : BehNodeAdapter
  outsideOfCurrentVehicle : bool = false
  positionalOrder : bool = false
  actionOrder : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    outsideOfCurrentVehicle = datablock_getBool(data, "outsideOfCurrentVehicle", outsideOfCurrentVehicle)
    positionalOrder = datablock_getBool(data, "positionalOrder", positionalOrder)
    actionOrder = datablock_getBool(data, "actionOrder", actionOrder)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)

    var result = false
    query(agent.eid) <| $ [es] (squad_member__isPersonalOrder : bool;
                                squad_member__orderType : int;
                                squad_member__orderUseEntity : EntityId = INVALID_ENTITY_ID;
                                human_anim__vehicleSelected : EntityId = INVALID_ENTITY_ID)
      if squad_member__isPersonalOrder
        if !positionalOrder && !actionOrder
          result = squad_member__orderType != int(SquadMateOrder.ESMO_NO_ORDER)
        else
          if positionalOrder && is_squad_mate_order_positional(squad_member__orderType)
            result = true
          if actionOrder && is_squad_mate_order_action(squad_member__orderType)
            result = true
        if outsideOfCurrentVehicle
          if human_anim__vehicleSelected != INVALID_ENTITY_ID && squad_member__orderType == int(SquadMateOrder.ESMO_USE_VEHICLE) && squad_member__orderUseEntity == human_anim__vehicleSelected
            result = false

    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isOrderOverwatch")]
class IsOrderOverwatch : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var result = false
    query(beh_tree_eid(owner)) <| $ [es] (squad_member__isPersonalOrder : bool;
                                          squad_member__orderType : int)
      if squad_member__isPersonalOrder
        if is_squad_mate_order_overwatch_by_direction(squad_member__orderType)
          result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isOrderPeekout")]
class IsOrderPeekout : BehNodeAdapter
  peekoutTypeStr : string = ""
  peekoutType : int = -1
  def override loadFromBlk(var data : DataBlock) : void
    peekoutTypeStr = datablock_getStr(data, "peekoutType", "")
    if peekoutTypeStr == "STANDING"
      peekoutType = int(SquadMateOrder.ESMO_PEEKOUT_STANDING)
    elif peekoutTypeStr == "CROUCHED"
      peekoutType = int(SquadMateOrder.ESMO_PEEKOUT_CROUCHED)
    elif peekoutTypeStr == "STAND_UP"
      peekoutType = int(SquadMateOrder.ESMO_PEEKOUT_STAND_UP)
  def override update(dt : float) : EBehResult
    var result = false
    query(beh_tree_eid(owner)) <| $ [es] (squad_member__isPersonalOrder : bool;
                                          squad_member__orderType : int)
      if squad_member__isPersonalOrder
        if is_squad_mate_order_peekout(squad_member__orderType)
          if peekoutType < 0 || squad_member__orderType == peekoutType
            result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isOrderThrowGrenade")]
class IsOrderThrowGrenade : BehNodeAdapter
  grenadeKind : string = ""
  def override loadFromBlk(var data : DataBlock) : void
    grenadeKind = datablock_getStr(data, "grenadeKind", "")
  def override update(dt : float) : EBehResult
    var result = false
    query(beh_tree_eid(owner)) <| $ [es] (squad_member__isPersonalOrder : bool;
                                          squad_member__orderType : int)
      if squad_member__isPersonalOrder
        if is_squad_mate_order_throw_grenade(squad_member__orderType)
          if grenadeKind == ""
            result = true
          elif grenadeKind == "FRAG"
            result = squad_member__orderType == int(SquadMateOrder.ESMO_THROW_FRAG_GRENADE)
          elif grenadeKind == "SMOKE"
            result = squad_member__orderType == int(SquadMateOrder.ESMO_THROW_SMOKE_GRENADE)
          elif grenadeKind == "FLASH"
            result = squad_member__orderType == int(SquadMateOrder.ESMO_THROW_FLASH_GRENADE)
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isOrderAttackVehicle")]
class IsOrderAttackVehicle : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var result = false
    query(beh_tree_eid(owner)) <| $ [es] (squad_member__isPersonalOrder : bool;
                                          squad_member__orderType : int)
      if squad_member__isPersonalOrder
        if is_squad_mate_order_attack_vehicle(squad_member__orderType)
          result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="chooseGrenadeOfType")]
class ChooseGrenadeOfType : BehNodeAdapter
  grenadeType : string = ""
  def override loadFromBlk(var data : DataBlock) : void
    grenadeType = datablock_getStr(data, "grenadeType", "")
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var result = false
    query(agentEid) <| $ [es] (itemContainer : EidList; var human_net_phys : HumanActor&)
      for itemEid in itemContainer
        query(itemEid) <| $ [es] (item__grenadeType : string; item__id : int)
          if grenadeType == "" || item__grenadeType == grenadeType
            set_chosen_weapon(human_net_phys.phys.producedCT, HUWeaponSlots.EWS_GRENADE)
            sendEvent(agentEid, CmdSetWishAmmoItemType(slot_id = int(HUWeaponSlots.EWS_GRENADE), item_id = item__id))
            result = true
            return
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="switchToNextOrder")]
class SwitchToNextOrder : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    switch_to_next_squad_mate_order(agentEid)
    return EBehResult.ER_SUCCESS

[beh_node(name="reportToPlayer")]
class ReportToPlayer : BehNodeAdapter
  heroLogEvent : string = ""
  heroLogText : string = ""
  def override loadFromBlk(var data : DataBlock) : void
    heroLogEvent = datablock_getStr(data, "heroLogEvent", "")
    heroLogText = datablock_getStr(data, "heroLogText", "")
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if heroLogEvent != "" && heroLogText != ""
      query(agentEid) <| $ [es] (squad_member__squad : EntityId)
        query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
          send_net_event(squad__leader, CmdHeroLogEvent(event = heroLogEvent, text = heroLogText))
    return EBehResult.ER_SUCCESS


[beh_node(name="isTargetLookingAtAgent")]
class IsTargetLookingAtAgent : BehNodeAdapter
  targetParam : int = -1
  clipAngleCos : float = 0.0
  def override loadFromBlk(var data : DataBlock) : void
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)
    let clipAngleDeg = datablock_getReal(data, "clipAngleDeg", 90.0)
    clipAngleCos = cos(deg_to_rad(clipAngleDeg))
  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    var result = false
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    query(targetEid) <| $ [es] (human_net_phys : HumanActor; transform : float3x4)
      let gunPos = transform[3]
      let gunDir = human_net_phys.phys.currentState.gunDir
      if dot(normalize(agent.pos - gunPos), gunDir) > clipAngleCos
        result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isAtStance")]
class IsAtStance : BehNodeAdapter
  stanceParam : int = -1
  def override loadFromBlk(var data : DataBlock) : void
    stanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "stanceParam", ""), -1)
  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED
    let stance1 = owner.blackBoard |> datablock_getInt(stanceParam)
    if stance1 < 0 
      return EBehResult.ER_SUCCESS
    var stance2 = -1
    query(agent.eid) <| $ [es] (human_net_phys : HumanActor;
                                beh_tree__latencyLoadRequire : bool = false)
      assume ct = human_net_phys.phys.producedCT
      let isCrouch = ct |> is_control_bit_set(HumanPhysControlType.HCT_CROUCH)
      let isCrawl = ct |> is_control_bit_set(HumanPhysControlType.HCT_CRAWL)
      let standState = human_net_phys.phys.currentState.standState
      if isCrawl || standState == HUStandState.ESS_CRAWL
        stance2 = 0
      elif (standState == HUStandState.ESS_CROUCH || isCrouch) && !isCrawl
        stance2 = 1
      elif standState == HUStandState.ESS_STAND && !isCrouch && !isCrawl
        stance2 = 2
      if beh_tree__latencyLoadRequire
        stance2 = stance1
    return (stance1 == stance2) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="fixAiming")]
class FixAiming : BehNodeAdapter
  velCoef : float = 0.0
  def override loadFromBlk(var data : DataBlock) : void
    velCoef = datablock_getReal(data, "velCoef", velCoef)
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (var walker_agent : EntityAgent&)
      walker_agent.aiming.aimVelocity *= velCoef
    return EBehResult.ER_SUCCESS

[beh_node(name="acceptActiveDanger")]
class AcceptActiveDanger : BehNodeAdapter
  fromType : int = 0
  eidParam : int = -1
  time : float = 5.0

  chanceMakeTraceable : float = 0.0
  makeTraceableDanger : float = 0.5

  FROM_EID_PARAM = 0
  FROM_REACTION_ON_HIT = 1
  FROM_REACTION_ON_BULLET_NEARBY = 2

  def override loadFromBlk(var data : DataBlock) : void
    fromType = FROM_EID_PARAM
    let fromReaction = datablock_getStr(data, "fromReaction", "")
    if fromReaction == "onHit"
      fromType = FROM_REACTION_ON_HIT
    elif fromReaction == "onBulletNearby"
      fromType = FROM_REACTION_ON_BULLET_NEARBY

    if datablock_find_param(data, "eidParam") >= 0
      eidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "eidParam", ""), 0)
    time = datablock_getReal(data, "time", time)

    chanceMakeTraceable = datablock_getReal(data, "chanceMakeTraceable", chanceMakeTraceable)
    makeTraceableDanger = datablock_getReal(data, "makeTraceableDanger", makeTraceableDanger)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let curTime = get_sync_time()
    let DISTANCE_EPSILON = 5.0
    query(agentEid) <| $ [es] (var agent_dangers__keepDangerEid : EntityId&;
                               var agent_dangers__keepDangerToTime : float&;
                               var agent_dangers : AgentDangers;
                               transform aka agent_transform : float3x4;
                               agent_dangers__lastHitReactionOffenderEid : EntityId = INVALID_ENTITY_ID;
                               agent_dangers__lastBulletReactionOffenderEid : EntityId = INVALID_ENTITY_ID;
                               agent_dangers__maxDangerDist : float)
      var targetEid = INVALID_ENTITY_ID
      if fromType == FROM_EID_PARAM
        targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(eidParam)))
      elif fromType == FROM_REACTION_ON_HIT
        targetEid = agent_dangers__lastHitReactionOffenderEid
      elif fromType == FROM_REACTION_ON_BULLET_NEARBY
        targetEid = agent_dangers__lastBulletReactionOffenderEid

      query(targetEid) <| $ [es] (transform aka target_transform : float3x4)
        let distSq = distance_sq(agent_transform[3], target_transform[3])

        if fromType != FROM_EID_PARAM
          if chanceMakeTraceable > 0.0 && rnd_float(0.0, 1.0) < chanceMakeTraceable
            var found = false
            for danger in agent_dangers.dangers
              if danger.eid == targetEid
                found = true
                if !danger.traceable
                  danger.traceable = true
                  if danger.dangerMeter < makeTraceableDanger
                    danger.dangerMeter = makeTraceableDanger
                  break
            if !found
              using() <| $(var newDanger : Danger#)
                newDanger.eid = targetEid
                newDanger.inFrustumTime = -1.0
                newDanger.distance = sqrt(distSq)
                newDanger.alertness = 0.1
                newDanger.traceable = true
                newDanger.dangerMeter = makeTraceableDanger
                push_clone(agent_dangers.dangers, newDanger)

        if distSq > square(max(0.0, agent_dangers__maxDangerDist - DISTANCE_EPSILON))
          agent_dangers__keepDangerEid = targetEid
          agent_dangers__keepDangerToTime = curTime + time

    return EBehResult.ER_SUCCESS


def find_best_grenade_ammo_item_id(item_container : EidList; grenade_types_list : StringList;
                                   use_exclude_list : bool; exclude_grenade_types_list : StringList) : int
  var bestItemId = INVALID_ITEM_ID
  var bestItemIdPriority = -1
  if empty(grenade_types_list)
    return bestItemId
  var found = false
  for itemEid in item_container
    query(itemEid) <| $ [es] (item__grenadeType : string; item__id : int)
      let idx = find_index(grenade_types_list, item__grenadeType)
      if idx != -1 && (!use_exclude_list || find_index(exclude_grenade_types_list, item__grenadeType) < 0)
        let foundItemIdPriority = idx
        if bestItemIdPriority == -1 || foundItemIdPriority < bestItemIdPriority
          bestItemIdPriority = foundItemIdPriority
          bestItemId = item__id
          if foundItemIdPriority == 0
            found = true
            return
    if found
      break
  return bestItemId

[beh_node(name="chooseBestWeapon")]
class ChooseBestWeapon : BehNodeAdapter
  targetParam : int = -1
  selectWeapon : bool = true
  defaultCombatDist : float = 20.0

  changeWeaponTimeParam : int = -1
  changeWeaponDelay : float2 = float2(7.0, 15.0)
  switchRadiusCoef : float = 1.0

  allowGrenades : bool = false
  tryKeepSame : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    let targetParamName = data |> datablock_getStr("targetParam", "")
    if !empty(targetParamName)
      targetParam = owner.blackBoard |> get_or_create(targetParamName, 0)
    selectWeapon = data |> datablock_getBool("selectWeapon", selectWeapon)
    defaultCombatDist = data |> datablock_getReal("defaultCombatDist", defaultCombatDist)

    let changeWeaponTimeParamName = data |> datablock_getStr("changeWeaponTimeParam", "nextChangeWeaponTime")
    if !empty(changeWeaponTimeParamName)
      changeWeaponTimeParam = owner.blackBoard |> get_or_create(changeWeaponTimeParamName, 0.0)
    changeWeaponDelay = data |> datablock_getPoint2("changeWeaponDelay", changeWeaponDelay)
    switchRadiusCoef = data |> datablock_getReal("switchRadiusCoef", switchRadiusCoef)

    allowGrenades = data |> datablock_getBool("allowGrenades", allowGrenades)
    tryKeepSame = data |> datablock_getBool("tryKeepSame", tryKeepSame)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED
    if agent.phys == null
      return EBehResult.ER_FAILED

    var unarmed = false
    query(agent.eid) <| $ [es] (human_unarmed__active : bool)
      unarmed = human_unarmed__active
    if unarmed
      return EBehResult.ER_FAILED

    var agentPlayerIsBot = false
    var agentSquadEid = INVALID_ENTITY_ID
    query(agent.eid) <| $ [es] (squad_member__playerEid : EntityId; squad_member__squad : EntityId)
      query(squad_member__playerEid) <| $ [es(REQUIRE=playerIsBot)] ()
        agentPlayerIsBot = true
      agentSquadEid = squad_member__squad

    var vehicleTarget = false
    var distToTargetSq = square(defaultCombatDist)
    var targetInVehicle = false
    let targetUnitId = targetParam >= 0 ? owner.blackBoard |> datablock_getInt(targetParam) : 0
    query(EntityId(uint(targetUnitId))) <| $ [es] (ai_target : Target;
                                                   agent_dangers__tag : string = "";
                                                   isInVehicle : bool = false)
      vehicleTarget = agent_dangers__tag == "vehicle"
      distToTargetSq = length_sq(ai_target.targetPos - agent.pos)
      targetInVehicle = isInVehicle

    if vehicleTarget
      let curTime = get_sync_time()
      var allowedToThrowGrenade = true
      query(agentSquadEid) <| $ [es(REQUIRE=playerIsBot)] (squadAI__nextAllowedThrowAntiTankGrenadeTime : float;
                                                           squadAI__throwAntiTankGrenadeCounter : int;
                                                           squadAI__throwAntiTankGrenadeDist : float2)
        allowedToThrowGrenade = false
        if squadAI__throwAntiTankGrenadeCounter > 0 || curTime >= squadAI__nextAllowedThrowAntiTankGrenadeTime
          if distToTargetSq >= square(squadAI__throwAntiTankGrenadeDist.x) && distToTargetSq <= square(squadAI__throwAntiTankGrenadeDist.y)
            allowedToThrowGrenade = true
      if !allowedToThrowGrenade
        return EBehResult.ER_FAILED
      var foundGrenade = false
      query(agent.eid) <| $ [es] (itemContainer : EidList; @shared_comp beh_tree__antitankGrenades : StringList)
        let grenadeItemId = find_best_grenade_ammo_item_id(itemContainer, beh_tree__antitankGrenades, false, beh_tree__antitankGrenades)
        if grenadeItemId != INVALID_ITEM_ID
          foundGrenade = true
          if selectWeapon
            set_chosen_weapon(agent.phys.producedCT, HUWeaponSlots.EWS_GRENADE)
            sendEvent(agent.eid, CmdSetWishAmmoItemType(slot_id = int(HUWeaponSlots.EWS_GRENADE), item_id = grenadeItemId))
            query(agentSquadEid) <| $ [es(REQUIRE=playerIsBot)] (var squadAI__nextAllowedThrowAntiTankGrenadeTime : float&;
                                                                 var squadAI__throwAntiTankGrenadeCounter : int&;
                                                                 squadAI__throwAntiTankGrenadeCounterReset : int2;
                                                                 squadAI__throwAntiTankGrenadeDelay : float2)
              if squadAI__throwAntiTankGrenadeCounter > 0
                --squadAI__throwAntiTankGrenadeCounter
              else
                squadAI__nextAllowedThrowAntiTankGrenadeTime = curTime + rnd_float(squadAI__throwAntiTankGrenadeDelay.x, squadAI__throwAntiTankGrenadeDelay.y)
                squadAI__throwAntiTankGrenadeCounter = rnd_int(squadAI__throwAntiTankGrenadeCounterReset.x, squadAI__throwAntiTankGrenadeCounterReset.y)
      return foundGrenade ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

    if allowGrenades && !targetInVehicle && agentPlayerIsBot
      let curTime = get_sync_time()
      var allowedToThrowGrenade = false
      var agentTeam = -1
      var tanksNearDistanceSq = 0.0
      var tanksNearChance = 1.0
      query(agentSquadEid) <| $ [es] (team aka player_team : int;
                                      squadAI__saveGrenadesForEnemyTanksDistance : float;
                                      squadAI__saveGrenadesForEnemyTanksChance : float;
                                      var squadAI__nextAllowedThrowGrenadeTime : float&;
                                      squadAI__throwGrenadeDelay : float2;
                                      squadAI__throwGrenadeDist : float2)
        if squadAI__nextAllowedThrowGrenadeTime < 0.0
          squadAI__nextAllowedThrowGrenadeTime = curTime + rnd_float(squadAI__throwGrenadeDelay.x, squadAI__throwGrenadeDelay.y)
        if curTime >= squadAI__nextAllowedThrowGrenadeTime
          if distToTargetSq >= square(squadAI__throwGrenadeDist.x) && distToTargetSq <= square(squadAI__throwGrenadeDist.y)
            allowedToThrowGrenade = true
            agentTeam = player_team
            tanksNearDistanceSq = square(squadAI__saveGrenadesForEnemyTanksDistance)
            tanksNearChance = squadAI__saveGrenadesForEnemyTanksChance
      if allowedToThrowGrenade
        var foundGrenade = false
        query(agent.eid) <| $ [es] (itemContainer : EidList; @shared_comp beh_tree__antibotGrenades : StringList; @shared_comp beh_tree__antitankGrenades : StringList)
          var grenadeItemId = find_best_grenade_ammo_item_id(itemContainer, beh_tree__antibotGrenades, true, beh_tree__antitankGrenades)
          if grenadeItemId == INVALID_ITEM_ID
            grenadeItemId = find_best_grenade_ammo_item_id(itemContainer, beh_tree__antibotGrenades, false, beh_tree__antitankGrenades)
            if grenadeItemId != INVALID_ITEM_ID && agentTeam >= 1
              let enemyTanksAround = find_query() <| $ [es(REQUIRE=unit_tag__tank, REQUIRE_NOT=deadEntity)] (team aka tank_team : int; transform aka tank_transform : float3x4)
                return tank_team >= 1 && tank_team != agentTeam && distance_sq(tank_transform[3], agent.pos) < tanksNearDistanceSq
              if enemyTanksAround && (tanksNearChance >= 1.0 || rnd_float(0.0, 1.0) < tanksNearChance)
                grenadeItemId = INVALID_ITEM_ID
          if grenadeItemId != INVALID_ITEM_ID
            foundGrenade = true
            if selectWeapon
              set_chosen_weapon(agent.phys.producedCT, HUWeaponSlots.EWS_GRENADE)
              sendEvent(agent.eid, CmdSetWishAmmoItemType(slot_id = int(HUWeaponSlots.EWS_GRENADE), item_id = grenadeItemId))
              query(agentSquadEid) <| $ [es] (var squadAI__nextAllowedThrowGrenadeTime : float&; squadAI__throwGrenadeDelay : float2)
                squadAI__nextAllowedThrowGrenadeTime = curTime + rnd_float(squadAI__throwGrenadeDelay.x, squadAI__throwGrenadeDelay.y)
        if foundGrenade
          return EBehResult.ER_SUCCESS

    let currWeapon = int(agent.phys.producedCT.chosenWeapon)
    var currAllowed = false
    var bestWeapons : array<int>
    var goodWeapon = -1
    var otherWeapon = -1
    var otherWeaponPriority = 0
    query(agent.eid) <| $ [es] (human_weap__gunEids : EidList)
      var closestStartFireRange = 0.0
      for i, gunEid in range(int(HUWeaponSlots.EWS_NUM)), human_weap__gunEids
        if gunEid == INVALID_ENTITY_ID || i == int(HUWeaponSlots.EWS_GRENADE)
          continue
        if i == int(HUWeaponSlots.EWS_MELEE)
          if otherWeaponPriority == 0 && otherWeapon == -1
            otherWeapon = i
          continue

        var allowedGun = false
        var firingRange = float2()
        var targetInFarRange = false
        var specialAIWeapType = 0
        query(gunEid) <| $ [es] (specialAIWeaponType : int const?; combatFiringRange : float2;
                                 gun__totalAmmo : int = 0; gun__ammo : int = 0; gun__isOverheat : bool = false)
          let isCurrent = i == currWeapon
          let rangeCoef = isCurrent ? 1.0 : switchRadiusCoef
          firingRange = float2(combatFiringRange.x, combatFiringRange.y * rangeCoef)
          targetInFarRange = distToTargetSq < square(firingRange.y)
          allowedGun = (gun__totalAmmo + gun__ammo) > 0 && !gun__isOverheat
          if allowedGun && specialAIWeaponType != null
            specialAIWeapType = *specialAIWeaponType
            if specialAIWeapType == int(SpecialAIWeaponType.ROCKET_LAUNCHERS)
              allowedGun = false
            elif specialAIWeapType == int(SpecialAIWeaponType.PISTOLS)
              allowedGun = false
              if otherWeaponPriority < 10
                otherWeapon = i
                otherWeaponPriority = 10
            elif specialAIWeapType == int(SpecialAIWeaponType.ANTI_TANK_RIFLES)
              allowedGun = false
              if otherWeaponPriority < 5
                otherWeapon = i
                otherWeaponPriority = 5
            elif specialAIWeapType == int(SpecialAIWeaponType.FLAME_THROWERS)
              if !targetInFarRange
                allowedGun = false
            elif specialAIWeapType != 0
              allowedGun = false
        if !allowedGun
          continue

        if currWeapon == i
          currAllowed = true
        if !targetInFarRange
          
          if otherWeaponPriority < 15 && specialAIWeapType == 0
            otherWeapon = i
            otherWeaponPriority = 15
          continue
        if distToTargetSq > square(firingRange.x)
          bestWeapons |> push(i)
        elif goodWeapon == -1 || firingRange.x < closestStartFireRange
          closestStartFireRange = firingRange.x
          goodWeapon = i

    var bestWeapon = -1
    let nextChangeWeaponTime = changeWeaponTimeParam >= 0 ? owner.blackBoard |> datablock_getReal(changeWeaponTimeParam) : 0.0
    if !currAllowed || (get_sync_time() >= nextChangeWeaponTime && !tryKeepSame)
      if !empty(bestWeapons)
        bestWeapon = bestWeapons[rnd_int(0, length(bestWeapons) - 1)]
      else
        bestWeapon = goodWeapon >= 0 ? goodWeapon : otherWeapon
    else
      bestWeapon = currWeapon

    if bestWeapon >= 0
      if selectWeapon && bestWeapon != currWeapon
        set_chosen_weapon(agent.phys.producedCT, HUWeaponSlots(bestWeapon))
        if changeWeaponTimeParam >= 0
          owner.blackBoard |> set(changeWeaponTimeParam, get_sync_time() + rnd_float(changeWeaponDelay.x, changeWeaponDelay.y))
      return EBehResult.ER_SUCCESS
    return EBehResult.ER_FAILED

[beh_node(name="resetGrenadeThrowTime")]
class ResetGrenadeThrowTime : BehNodeAdapter
  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (squad_member__playerEid : EntityId; squad_member__squad : EntityId)
      query(squad_member__playerEid) <| $ [es(REQUIRE=playerIsBot)] ()
        query(squad_member__squad) <| $ [es] (var squadAI__nextAllowedThrowGrenadeTime : float&)
          squadAI__nextAllowedThrowGrenadeTime = get_sync_time()
    return EBehResult.ER_SUCCESS

[beh_node(name="resetAntiTankGrenadeThrowLimiter")]
class ResetAntiTankGrenadeThrowLimiter : BehNodeAdapter
  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (squad_member__playerEid : EntityId; squad_member__squad : EntityId)
      query(squad_member__playerEid) <| $ [es(REQUIRE=playerIsBot)] ()
        query(squad_member__squad) <| $ [es] (var squadAI__throwAntiTankGrenadeCounter : int&)
          ++squadAI__throwAntiTankGrenadeCounter
    return EBehResult.ER_SUCCESS

[beh_node(name="hasGrenade")]
class HasGrenade : BehNodeAdapter
  enemyType : int = 0

  GRENADE_TYPE_ANTITANK = 0
  GRENADE_TYPE_ANTIHUMAN = 1

  def override loadFromBlk(var data : DataBlock) : void
    enemyType = datablock_getInt(data, "enemyType", enemyType)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (itemContainer : EidList; @shared_comp beh_tree__antitankGrenades : StringList;
                                          @shared_comp beh_tree__antibotGrenades : StringList)
      if enemyType == GRENADE_TYPE_ANTITANK
        for grenadeType in beh_tree__antitankGrenades
          if find_grenade_of_type(itemContainer, grenadeType) != INVALID_ENTITY_ID
            res = EBehResult.ER_SUCCESS
            break
      elif enemyType == GRENADE_TYPE_ANTIHUMAN
        for grenadeType in beh_tree__antibotGrenades
          if find_grenade_of_type(itemContainer, grenadeType) != INVALID_ENTITY_ID
            res = EBehResult.ER_SUCCESS
            break
    return res

[beh_node(name="hasCloseRangeWeapon")]
class HasCloseRangeWeapon : BehNodeAdapter
  checkOnlyCurrent : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    checkOnlyCurrent = datablock_getBool(data, "checkOnlyCurrent", checkOnlyCurrent)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    var hasWeapon = false
    query(agent.eid) <| $ [es] (human_weap__gunEids : EidList; human_weap__currentGunEid : EntityId)
      for i, gunEid in range(int(HUWeaponSlots.EWS_NUM)), human_weap__gunEids
        if checkOnlyCurrent && gunEid != human_weap__currentGunEid
          continue
        if gunEid == INVALID_ENTITY_ID || i == int(HUWeaponSlots.EWS_GRENADE) || i == int(HUWeaponSlots.EWS_MELEE)
          continue
        if check_human_reload(gunEid, 0.001) != 0
          continue
        query(gunEid) <| $ [es] (gun__statName : string; gun__totalAmmo : int = 0; gun__ammo : int = 0;
                                 specialAIWeaponType : int const?; gun__isOverheat : bool = false)
          if gun__totalAmmo + gun__ammo <= 0 || gun__isOverheat
            return
          if specialAIWeaponType != null && *specialAIWeaponType != int(SpecialAIWeaponType.PISTOLS)
            return
          if (gun__statName == "flamethrower" ||
              gun__statName == "launcher" ||
              gun__statName == "mine" ||
              gun__statName == "tnt_block")
            return
          hasWeapon = true
        if hasWeapon
          break
    return hasWeapon ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isMeleeWeaponSelected")]
class IsMeleeWeaponSelected : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    return agent.phys.producedCT.chosenWeapon == HUWeaponSlots.EWS_MELEE ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isWeaponSlotSelected")]
class IsWeaponSlotSelected : BehNodeAdapter
  slotParam : int = -1
  def override loadFromBlk(var data : DataBlock) : void
    slotParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "slotParam", ""), -1)
  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    let slot = datablock_getInt(owner.blackBoard, slotParam)
    return int(agent.phys.producedCT.chosenWeapon) == slot ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="isGrenadeSelected")]
class IsGrenadeSelected : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    return agent.phys.producedCT.chosenWeapon == HUWeaponSlots.EWS_GRENADE ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="checkSafeMove")]
class CheckSafeMove : BehNodeAdapter
  posParam : int = -1

  checkEnemyRadius : float = 15.0
  maxEnemyCount : int = 4

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "posParam") >= 0
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    checkEnemyRadius = datablock_getReal(data, "checkEnemyRadius", checkEnemyRadius)
    maxEnemyCount = datablock_getInt(data, "maxEnemyCount", maxEnemyCount)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if posParam < 0
      return EBehResult.ER_SUCCESS

    let targetPos = owner.blackBoard |> datablock_getPoint3(posParam)

    var agentPos = float3()
    var agentTeam = TEAM_UNASSIGNED
    var hasAgentPos = false
    query(agentEid) <| $ [es] (transform : float3x4; team : int)
      agentPos = transform[3]
      agentTeam = team
      hasAgentPos = true
    if !hasAgentPos
      return EBehResult.ER_SUCCESS

    let SUBSTEPS = 3
    let kdiv = 1.0 / float(SUBSTEPS - 1)
    let radiusSq = square(checkEnemyRadius)
    for i in range(SUBSTEPS)
      if i == 0
        continue
      let pos = lerp(agentPos, targetPos, float(i) * kdiv)

      var numEnemies = 0
      for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, checkEnemyRadius), GridEntCheck.BOUNDING) <| $(that_eid : EntityId)
        if agentEid == that_eid
          return
        query(that_eid) <| $ [es] (transform : float3x4; team : int)
          if distance_sq(transform[3], agentPos) < radiusSq && !is_teams_friendly(team, agentTeam)
            ++numEnemies
      if numEnemies >= maxEnemyCount
        return EBehResult.ER_FAILED

    return EBehResult.ER_SUCCESS

[beh_node(name="forceWeaponReady")]
class ForceWeaponReady : BehNodeAdapter
  forceReady : bool = true
  def override loadFromBlk(data : DataBlock) : void
    forceReady = datablock_getBool(data, "forceReady", forceReady)
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (var human_weap__gunEquipAIForce : bool&)
      human_weap__gunEquipAIForce = forceReady
    return EBehResult.ER_SUCCESS


def should_shell_damage(eid : EntityId, offender_eid : EntityId, def_offender_team : int = TEAM_UNASSIGNED) : bool
  if has(eid, "undestroyableRiExtra")
    return false
  if has(eid, "allow_friendly_damage")
    return true

  let offenderVehicle = get_Eid(offender_eid, "human_anim__vehicleSelected") ?? INVALID_ENTITY_ID
  var offenderTeam = get_int(offender_eid, "team") ?? def_offender_team

  if offenderTeam == def_offender_team && !doesEntityExist(offender_eid)
    let offender = get_offender_from_cache(offender_eid)
    if offender.player != INVALID_ENTITY_ID
      offenderTeam = get_int(offender.player, "team") ?? def_offender_team

  return !(is_teams_friendly(offenderTeam, get_int(eid, "team") ?? TEAM_UNASSIGNED) && eid != offender_eid && eid != offenderVehicle)

[beh_node(name="findDangerGrenade")]
class FindDangerGrenade : BehNodeAdapter
  grenTargetParam : int = -1
  grenadeExplTimeParam : int = -1
  radius : float = 0.0
  yRadius : float = 0.0
  allowUnderWater : bool = true
  maxWaterDepth : float = 0.0
  lethalOutParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    radius = datablock_getReal(data, "radius", radius)
    yRadius = datablock_getReal(data, "yRadius", 0.0)
    grenTargetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "grenTargetParam", ""), int(uint(INVALID_ENTITY_ID)))
    if datablock_find_param(data, "grenExplTime") >= 0
      grenadeExplTimeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "grenExplTime", ""), 0.0)
    allowUnderWater = datablock_getBool(data, "allowUnderWater", allowUnderWater)
    maxWaterDepth = datablock_getReal(data, "maxWaterDepth", maxWaterDepth)
    if datablock_find_param(data, "lethalOutParam") >= 0
      lethalOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lethalOutParam", ""), 1)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    let curTime = get_sync_time()
    let agentEid = agent.eid
    let requestSph = BSphere3(agent.pos, radius)
    var closestDistSq = FLT_MAX
    var closestGrenadeEid = INVALID_ENTITY_ID
    var closestExplTime = 0.0
    var closestLethal = false

    query() <| $ [es] (eid : EntityId;
                       active : bool;
                       transform : float3x4;
                       shell__shell_id__shell_id : PropsId;
                       shell__explTime : float;
                       shell__owner : EntityId;
                       shell__explosionTimer : float = 0.0;
                       shell__rethrower : EntityId = INVALID_ENTITY_ID;
                       beh_tree__ignoreSelfGrenadesTime : float = 1.5)
      if !active
        return
      let isThrowedByEnemy = should_shell_damage(agentEid, shell__owner)
      let isRethrowedByEnemy = shell__rethrower != INVALID_ENTITY_ID && should_shell_damage(agentEid, shell__rethrower)
      if !isThrowedByEnemy && !isRethrowedByEnemy
        return
      if agentEid == shell__owner
        if shell__explTime - shell__explosionTimer + beh_tree__ignoreSelfGrenadesTime < curTime
          return
      let shellPos = transform[3]
      if !(requestSph & shellPos)
        return
      if yRadius > 0.0 && abs(requestSph.c.y - shellPos.y) > yRadius
        return
      var waterHt = 0.0
      if !allowUnderWater && traceht_water(shellPos, waterHt) && waterHt - shellPos.y > maxWaterDepth
        return
      let shellRadius = get_shell_max_radius(shell__shell_id__shell_id)
      let isLethal = shellRadius > 0.0
      if lethalOutParam < 0 && !isLethal
        return
      if closestLethal && !isLethal
        return
      let distSq = length_sq(shellPos - requestSph.c)
      if distSq > closestDistSq && !(isLethal && !closestLethal)
        return
      closestDistSq = distSq
      closestExplTime = shell__explTime
      closestGrenadeEid = eid
      closestLethal = isLethal

    if closestDistSq >= square(radius)
      return EBehResult.ER_FAILED

    if grenadeExplTimeParam >= 0
      owner.blackBoard |> set(grenadeExplTimeParam, closestExplTime)
    owner.blackBoard |> set(grenTargetParam, int(uint(closestGrenadeEid)))
    if lethalOutParam >= 0
      owner.blackBoard |> set(lethalOutParam, closestLethal ? 1 : 0)

    return closestGrenadeEid != INVALID_ENTITY_ID ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="findSafeFromGrenadePos")]
class FindSafeFromGrenadePos : BehNodeAdapter
  posParam : int = -1
  grenTargetParam : int = -1
  radius : float = 0.0

  grenPosParam : int = -1
  grenRadius : float = -1.0
  grenRadiusParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    radius = datablock_getReal(data, "radius", radius)
    if datablock_find_param(data, "posParam") >= 0
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    if datablock_find_param(data, "grenTargetParam") >= 0
      grenTargetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "grenTargetParam", ""), int(uint(INVALID_ENTITY_ID)))
    if datablock_find_param(data, "grenPosParam") >= 0
      grenPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "grenPosParam", ""), float3())
    grenRadius = datablock_getReal(data, "grenRadius", grenRadius)
    if datablock_find_param(data, "grenRadiusParam") >= 0
      grenRadiusParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "grenRadiusParam", ""), 0.0)

  def trace_explosion_reach(pos1 : float3; pos2 : float3)
    let delta = pos2 - pos1
    let dist = length(delta)
    let dir = delta * safeinv(dist)
    if rayhit_normalized(pos1, dir, dist, ETF_ALL, -1)
      return false
    return true

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)

    var closestGrenadePos = float3()
    var closestGrenadeRad = 0.0

    if grenTargetParam >= 0
      let closestGrenadeEid = EntityId(uint(owner.blackBoard |> datablock_getInt(grenTargetParam)))
      if closestGrenadeEid == INVALID_ENTITY_ID
        return EBehResult.ER_FAILED
      var hasGrenadeInfo = false
      query(closestGrenadeEid) <| $ [es] (transform : float3x4; shell__shell_id__shell_id : PropsId)
        hasGrenadeInfo = true
        closestGrenadePos = transform[3]
        closestGrenadeRad = get_shell_max_radius(shell__shell_id__shell_id)
      if !hasGrenadeInfo
        return EBehResult.ER_FAILED
    elif grenPosParam >= 0
      closestGrenadePos = owner.blackBoard |> datablock_getPoint3(grenPosParam)
      closestGrenadeRad = grenRadius
      if grenRadiusParam >= 0
        closestGrenadeRad = owner.blackBoard |> datablock_getReal(grenRadiusParam)
    else
      return EBehResult.ER_FAILED

    if closestGrenadePos == float3()
      return EBehResult.ER_FAILED
    let curDistSq = length_sq(closestGrenadePos - agent.pos)
    if curDistSq > square(radius) || curDistSq > square(closestGrenadeRad)
      return EBehResult.ER_FAILED

    var dir = agent.pos - closestGrenadePos
    var dist = length(dir)
    dir *= safediv(closestGrenadeRad * 1.2, dist)
    var wishPos = closestGrenadePos + dir
    let NUM_ITERS = 5
    for i in range(NUM_ITERS)
      project_to_nearest_navmesh_point(wishPos, 0.5, agent.customNav)
      var path : array<float3>
      let extents = float3(0.5, FLT_MAX, 0.5)
      let result = find_path(agent.pos, wishPos, extents, 1.0, 0.25, agent.customNav) <| $(found_path)
        path := found_path
      if result == FindPathResult.FPR_FAILED
        if i == NUM_ITERS - 1
          return EBehResult.ER_FAILED
        let randAng = gfrnd() * TWOPI
        let randDist = gfrnd() * closestGrenadeRad
        wishPos = wishPos + float3(sin(randAng), 0.0, cos(randAng)) * randDist
        dir = wishPos - closestGrenadePos
        dist = length(dir)
        wishPos = closestGrenadePos + dir * safediv(dist, closestGrenadeRad * 1.2)
      else
        
        let minDistAwaySq = square(5.0)
        let closestGrenadeRadSq = square(closestGrenadeRad)
        var skip = 1
        var skips = 0
        for pathPos in path
          if skips > 0
            --skips
            
            continue
          let delta = pathPos - closestGrenadePos
          let lenSq = length_sq(delta)
          if lenSq < minDistAwaySq
            
            continue
          if lenSq < closestGrenadeRadSq
            if !trace_explosion_reach(closestGrenadePos, pathPos + float3(0.0, 0.4, 0.0))
              if !trace_explosion_reach(closestGrenadePos, pathPos + float3(0.0, 1.0, 0.0))
                if !trace_explosion_reach(closestGrenadePos, pathPos + float3(0.0, 1.6, 0.0))
                  wishPos = pathPos
                  
                  break
            skips = skip
            skip += 1
            
            continue
          wishPos = pathPos
          
          break
        break

    owner.blackBoard |> set(posParam, wishPos)
    return EBehResult.ER_SUCCESS


[beh_node(name="isTargetStillTraceable")]
class IsTargetStillTraceable : BehNodeAdapter
  targetEidParam : int = -1
  def override loadFromBlk(data : DataBlock) : void
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", ""), 0)
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    if targetEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    var traceable = false
    query(agentEid) <| $ [es] (agent_dangers : AgentDangers)
      for danger in agent_dangers.dangers
        if danger.eid == targetEid
          traceable = danger.traceable
          return

    if traceable
      var shootPos = float3()
      var shootRayMat = -1
      var hmapTraceOffset = float3()
      var hasShootPos = false
      query(agentEid) <| $ [es] (agent_dangers__standShootPos : float3 const?; transform : float3x4;
                                 agent_dangers__hmapTraceOffset : float3 = float3();
                                 human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                 human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID)
        if agent_dangers__standShootPos != null
          shootPos = *agent_dangers__standShootPos
        else
          shootPos = transform[3]
        shootRayMat = get_shoot_ray_mat(human_attached_gun__attachedGunEid, human_weap__currentGunEid)
        hmapTraceOffset = agent_dangers__hmapTraceOffset
        hasShootPos = true

      var badTarget = true
      var targetPos = float3()
      let canBeInVehicle = true
      query(targetEid) <| $ [es] (ai_target : Target)
        badTarget = false
        targetPos = ai_target.targetPos
        if ai_target.isHidden || !ai_target.isAlive  || (!canBeInVehicle && ai_target.useVehicle > uint(0))
          badTarget = true
      if badTarget
        traceable = false

      if traceable && hasShootPos && !badTarget
        let fromPos = shootPos
        let dist = length(targetPos - fromPos)
        let dir = normalize(targetPos - fromPos)
        let lmeshTracePos = fromPos + hmapTraceOffset
        let t = dist
        let flags = (ETF_ALL) & ~(ETF_LMESH | ETF_HEIGHTMAP)
        var collides = (rayhit_normalized_lmesh(lmeshTracePos, dir, dist) ||
                        rayhit_normalized(fromPos, dir, dist, flags, shootRayMat) ||
                        traceTransparencyRayRIGenNormalized(fromPos, dir, dist, 0.01) ||
                        rayhit_smoke_occluders(fromPos, targetPos))
        collides ||= rayhit_entities_in_grid(ecs_hash("vehicles"), fromPos, dir, t, targetEid)
        if !collides
          find_entity_in_grid(ecs_hash("humans"), fromPos, dir, t, 0.0, GridEntCheck.BOUNDING) <| $(objEid : EntityId)
            if objEid != targetEid && objEid != agentEid
              query(objEid) <| $ [es] (transform aka obj_transform : float3x4; collres : CollisionResource; animchar : AnimcharBaseComponent)
                collides = collres_rayhit(collres, obj_transform, animchar.nodeTree, fromPos, dir, t)
            return collides
        if collides
          traceable = false
    return traceable ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="findTraceNearDanger")]
class FindTraceNearDanger : BehNodeAdapter
  dangerEidParam : int = -1
  distRange : float2 = float2(0.0, 100.0)
  maxDiffAngle : float = 60.0
  traceRayCheck : bool = true

  
  param_outEid : int = -1
  radiusParam : int = -1
  outDangerParam : int = -1
  outSeeTimeParam : int = -1
  minDanger : float = 0.0
  canBeInVehicle : bool = true
  tag : string = ""

  def override loadFromBlk(data : DataBlock) : void
    dangerEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "dangerEidParam", ""), 0)
    distRange = datablock_getPoint2(data, "distRange", distRange)
    maxDiffAngle = datablock_getReal(data, "maxDiffAngle", maxDiffAngle)
    traceRayCheck = datablock_getBool(data, "traceRayCheck", traceRayCheck)

    if datablock_find_param(data, "paramName") >= 0
      param_outEid = owner.blackBoard |> get_or_create(datablock_getStr(data, "paramName", ""), 0)
    if datablock_find_param(data, "radiusParamName") >= 0
      radiusParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "radiusParamName", ""), 0.0)
    if datablock_find_param(data, "outDangerParam") >= 0
      outDangerParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outDangerParam", ""), 0)
    if datablock_find_param(data, "outSeeTimeParam") >= 0
      radiusParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outSeeTimeParam", ""), 0.0)
    minDanger = datablock_getReal(data, "minDanger", minDanger)
    canBeInVehicle = datablock_getBool(data, "canBeInVehicle", canBeInVehicle)
    tag = datablock_getStr(data, "tag", "")

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED
    let dangerEid = EntityId(uint(owner.blackBoard |> datablock_getInt(dangerEidParam)))
    if dangerEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    var shootPos = float3()
    var hasShootPos = false
    query(agentEid) <| $ [es] (agent_dangers__standShootPos : float3 const?; transform : float3x4)
      if agent_dangers__standShootPos != null
        shootPos = *agent_dangers__standShootPos
      else
        shootPos = transform[3]
      hasShootPos = true
    if !hasShootPos
      return EBehResult.ER_FAILED

    var wasDangerPos = float3()
    var hasDangerPos = false
    query(dangerEid) <| $ [es] (ai_target : Target)
      wasDangerPos = ai_target.targetPos
      hasDangerPos = true
    if !hasDangerPos
      return EBehResult.ER_FAILED

    let dirToPrev = normalize(wasDangerPos - shootPos)
    let maxDiffAngleCos = cos(deg_to_rad(maxDiffAngle))

    let searchRadius = radiusParam >= 0 ? owner.blackBoard |> datablock_getReal(radiusParam) : -1.0

    var gotDangerEid = INVALID_ENTITY_ID
    var gotDangerScore = minDanger
    var gotDangerSeeTime = -1.0
    var gotDangerPos = float3()

    query(agentEid) <| $ [es] (agent_dangers : AgentDangers)
      for danger in agent_dangers.dangers
        if danger.eid == agentEid || danger.eid == dangerEid
          continue

        var skipTarget = true
        var targetPos = float3()
        query(danger.eid) <| $ [es] (ai_target : Target)
          skipTarget = false
          targetPos = ai_target.targetPos
          if ai_target.isHidden || !ai_target.isAlive  || (!canBeInVehicle && ai_target.useVehicle > uint(0))
            skipTarget = true
        if skipTarget
          continue

        if !tag.empty() && tag != get_string(danger.eid, "agent_dangers__tag", "")
          continue
        var dir = targetPos - shootPos
        let dist = length(dir)
        if searchRadius > 0.0 && dist > searchRadius
          continue
        let dangerScore = danger.dangerMeter
        if dangerScore < gotDangerScore
          continue

        let distToPrev = distance_sq(wasDangerPos, targetPos)
        if distToPrev < distRange.x || distToPrev > distRange.y
          continue
        dir = normalize(dir)
        if maxDiffAngle > 0.0 && dot(dir, dirToPrev) < maxDiffAngleCos
          continue
        if traceRayCheck && rayhit_normalized(shootPos, dir, dist, ETF_ALL, -1)
          continue

        gotDangerEid = danger.eid
        gotDangerScore = dangerScore
        gotDangerSeeTime = danger.inFrustumTime
        gotDangerPos = targetPos

    if gotDangerEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    

    if outSeeTimeParam >= 0
      let prevDanger = EntityId(uint(owner.blackBoard |> datablock_getInt(param_outEid)))
      if prevDanger != gotDangerEid
        owner.blackBoard |> set(outSeeTimeParam, gotDangerSeeTime)
    if param_outEid >= 0
      owner.blackBoard |> set(param_outEid, int(uint(gotDangerEid)))
    if outDangerParam >= 0
      owner.blackBoard |> set(outDangerParam, gotDangerScore)
    return EBehResult.ER_SUCCESS

def private get_shoot_ray_mat(human_attached_gun__attachedGunEid, human_weap__currentGunEid : EntityId)
  var res = -1
  let gunEid = human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid
  query(gunEid) <| $ [es] (gun__aimRayMatId : int)
    res = gun__aimRayMatId
  return res

[beh_node(name="traceMoveToSeeTarget")]
class TraceMoveToSeeTarget : BehNodeAdapter
  targetEidParam : int = -1
  traceSmoke : bool = true
  traceHumans : bool = true
  traceVehicles : bool = true

  stepLocalDir : float3 = float3(1, 0, 0)
  stepsRange : int2 = int2(2, 4)
  stepDist : float = 0.5
  stepByNavMesh : bool = true
  stepTryTwoDirs : bool = false

  outMoveToPosParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", ""), 0)
    traceSmoke = datablock_getBool(data, "traceSmoke", traceSmoke)
    traceHumans = datablock_getBool(data, "traceHumans", traceHumans)
    traceVehicles = datablock_getBool(data, "traceVehicles", traceVehicles)

    stepLocalDir = datablock_getPoint3(data, "stepLocalDir", stepLocalDir)
    stepsRange = datablock_getIPoint2(data, "stepsRange", stepsRange)
    stepDist = datablock_getReal(data, "stepDist", stepDist)
    stepByNavMesh = datablock_getBool(data, "stepByNavMesh", stepByNavMesh)
    stepTryTwoDirs = datablock_getBool(data, "stepTryTwoDirs", stepTryTwoDirs)

    if datablock_find_param(data, "outMoveToPosParam") >= 0
      outMoveToPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outMoveToPosParam", ""), float3())

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))

    var shootHt = 1.3
    var shootPos = float3()
    var stepDir = float3()
    var hmapTraceOffset = float3()
    var shootRayMat = -1
    var hasShootInfo = false
    query(agentEid) <| $ [es] (agent_dangers__standShootPos : float3 const?; transform : float3x4;
                               agent_dangers__hmapTraceOffset : float3 = float3();
                               human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                               human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID)
      stepDir = transform[0] * stepLocalDir.z
      stepDir += transform[1] * stepLocalDir.y
      stepDir += transform[2] * -stepLocalDir.x
      shootPos = transform[3]
      if agent_dangers__standShootPos != null
        shootHt = (*agent_dangers__standShootPos).y - shootPos.y
      hmapTraceOffset = agent_dangers__hmapTraceOffset
      shootRayMat = get_shoot_ray_mat(human_attached_gun__attachedGunEid, human_weap__currentGunEid)
      hasShootInfo = true
    if !hasShootInfo
      return EBehResult.ER_FAILED

    var targetPos = float3()
    var hasTargetPos = false
    query(targetEid) <| $ [es] (ai_target : Target)
      targetPos = ai_target.targetPos
      hasTargetPos = true
    if !hasTargetPos
      return EBehResult.ER_FAILED

    var checkOneDir = true
    var checkInvDir = stepTryTwoDirs
    var pos1 = shootPos
    var pos2 = shootPos

    var gotPos = false
    var resultPos = float3()

    let minStepDistSq = square(0.3)
    let extents = float3(0.8, FLT_MAX, 0.8)
    let projExtents = float3(0.8, 2.5, 0.8)
    let sphereRad = 0.4
    let sphereVec1 = float3(0.0, 0.5, 0.0)
    let sphereVec2 = float3(0.0, 1.3, 0.0)
    let shootHtVec = float3(0.0, shootHt, 0.0)

    var step = 0
    while (checkOneDir || checkInvDir) && step < stepsRange.y
      var stepLen = stepDist
      if step < stepsRange.x
        stepLen *= float(stepsRange.x)
        step = stepsRange.x - 1
      ++step

      for dirIdx in range(0, 2)
        assume checkDir = dirIdx == 0 ? checkOneDir : checkInvDir
        assume atPos = dirIdx == 0 ? pos1 : pos2
        let dirCoef = dirIdx == 0 ? 1.0 : -1.0

        if checkDir
          checkDir = false
          var testPos = atPos + stepDir * stepLen * dirCoef
          if stepByNavMesh
            if !traceray_navmesh(atPos, testPos, extents, testPos) || distance_sq(atPos, testPos) >= minStepDistSq
              if project_to_nearest_navmesh_point_avoid_obstacles(testPos, projExtents)
                atPos = testPos
                checkDir = true
          else
            var tmp = 0
            var queryOut = ShapeQueryOutput()
            let tracePos1 = testPos + sphereVec2
            let tracePos2 = testPos + sphereVec1
            sphere_query_ri(tracePos1, tracePos2, sphereRad, queryOut, -1, null) <| $(desc : RendInstDesc; t : float)
              if desc.cellIdx == 0 && t < 0.0
                tmp += 1
              return true
            if abs(queryOut.t - 1.0) > 0.001
              atPos = testPos
              checkDir = true
          if checkDir
            let fromPos = atPos + shootHtVec
            let dist = length(targetPos - fromPos)
            let dir = normalize(targetPos - fromPos)
            let lmeshTracePos = fromPos + hmapTraceOffset
            let t = dist
            let flags = (ETF_ALL) & ~(ETF_LMESH | ETF_HEIGHTMAP)
            var collides = (rayhit_normalized_lmesh(lmeshTracePos, dir, dist) ||
                            rayhit_normalized(fromPos, dir, dist, flags, shootRayMat) ||
                            traceTransparencyRayRIGenNormalized(fromPos, dir, dist, 0.01) ||
                            (traceSmoke && rayhit_smoke_occluders(fromPos, targetPos)))
            if traceVehicles
              collides ||= rayhit_entities_in_grid(ecs_hash("vehicles"), fromPos, dir, t, targetEid)
            if !collides && traceHumans
              find_entity_in_grid(ecs_hash("humans"), fromPos, dir, t, 0.0, GridEntCheck.BOUNDING) <| $(objEid : EntityId)
                if objEid != targetEid && objEid != agentEid
                  query(objEid) <| $ [es] (transform aka obj_transform : float3x4; collres : CollisionResource; animchar : AnimcharBaseComponent)
                    collides = collres_rayhit(collres, obj_transform, animchar.nodeTree, fromPos, dir, t)
                return collides
            if !collides
              gotPos = true
              resultPos = atPos
              
              
              break
            
            
          
          
      if gotPos
        break
    if !gotPos
      return EBehResult.ER_FAILED
    if outMoveToPosParam >= 0
      owner.blackBoard |> set(outMoveToPosParam, resultPos)
    return EBehResult.ER_SUCCESS


[beh_node(name="debugDanger")]
class DebugDangerNode : BehNodeAdapter
  typeDebug : int = -1
  kindCode : int = -1
  otherCode : int = -1
  dangerParam : int = -1
  newDanger : bool = false

  thruDangerEidParam : int = -1
  thruDangerIdxParam : int = -1

  
  DEBUG_GOT_DANGER = 1
  DEBUG_A_BEGIN = 3
  DEBUG_A_OTHER = 4
  DEBUG_A_SHOOT = 5
  DEBUG_A_MELEE = 6
  DEBUG_A_SUCCESS = 7
  DEBUG_REJECTED = 13

  
  
  
  

  DEBUG_DANGERS_ENABLED = 0

  def override loadFromBlk(var data : DataBlock) : void
    typeDebug = datablock_getInt(data, "type", typeDebug)
    kindCode = datablock_getInt(data, "kind", kindCode)
    otherCode = datablock_getInt(data, "other", otherCode)
    if datablock_find_param(data, "paramName") >= 0
      dangerParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "paramName", ""), 0)
    newDanger = datablock_getBool(data, "newDanger", newDanger)

    thruDangerEidParam = owner.blackBoard |> get_or_create("debugThruDangerEid", 0)
    thruDangerIdxParam = owner.blackBoard |> get_or_create("debugThruDangerIdx", -1)

  def override update(dt : float) : EBehResult
    if DEBUG_DANGERS_ENABLED != 1
      return EBehResult.ER_SUCCESS 

    let agentEid = beh_tree_eid(owner)
    let dangerEid = dangerParam >= 0 ? EntityId(uint(owner.blackBoard |> datablock_getInt(dangerParam))) : INVALID_ENTITY_ID

    let thruDangerEid = EntityId(uint(owner.blackBoard |> datablock_getInt(thruDangerEidParam)))
    var overDangerIdx = (newDanger || dangerEid != thruDangerEid) ? -1 : (owner.blackBoard |> datablock_getInt(thruDangerIdxParam))

    if overDangerIdx == -2
      return EBehResult.ER_SUCCESS 

    let wasODI = overDangerIdx

    if agentEid != INVALID_ENTITY_ID && dangerEid != INVALID_ENTITY_ID
      if typeDebug == DEBUG_GOT_DANGER
        debug_ai_danger_got_danger(agentEid, dangerEid, overDangerIdx, kindCode)
      elif typeDebug == DEBUG_A_BEGIN
        debug_ai_danger_attack_begin(agentEid, dangerEid, overDangerIdx, kindCode)
      elif typeDebug == DEBUG_A_OTHER
        debug_ai_danger_attack_other(agentEid, dangerEid, overDangerIdx, kindCode, otherCode)
      elif typeDebug == DEBUG_A_SHOOT
        debug_ai_danger_attack_attack(agentEid, dangerEid, overDangerIdx, false, kindCode)
      elif typeDebug == DEBUG_A_MELEE
        debug_ai_danger_attack_attack(agentEid, dangerEid, overDangerIdx, true, kindCode)
      elif typeDebug == DEBUG_A_SUCCESS
        debug_ai_danger_attack_success(agentEid, dangerEid, overDangerIdx, kindCode)
      elif typeDebug == DEBUG_REJECTED
        debug_ai_danger_rejected(agentEid, dangerEid, overDangerIdx, kindCode)
      else
        error("debugDanger: UNKNOWN typeDebug{typeDebug}")

      if newDanger
        if overDangerIdx < 0
          overDangerIdx = -2 
        owner.blackBoard |> set(thruDangerEidParam, int(uint(dangerEid)))
        owner.blackBoard |> set(thruDangerIdxParam, overDangerIdx)

      if newDanger || dangerEid != thruDangerEid
        if overDangerIdx == -1
          error("debugDanger: NO DANGER ALLOCATED wasODI={wasODI} overDangerIdx={overDangerIdx} typeDebug={typeDebug} kindCode={kindCode}")
      elif wasODI < 0 || overDangerIdx != wasODI
        error("debugDanger: ALLOCATED DANGER CHANGED wasODI={wasODI} overDangerIdx={overDangerIdx} typeDebug={typeDebug} kindCode={kindCode}")
    else
      error("debugDanger: INVALID EIDS typeDebug={typeDebug} kindCode={kindCode} otherCode={otherCode} agentEid={agentEid} dangerEid={dangerEid} overDangerIdx={overDangerIdx}")

    return EBehResult.ER_SUCCESS
