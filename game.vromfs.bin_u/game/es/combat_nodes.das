options always_export_initializer = true

require app
require ecs
require BehNodes
require DagorDataBlock
require DagorSystem

[cpp_event(unicast)]
struct CmdUse
  requesterEid : EntityId
















require DngWalkerai
require walkerai



















require %appGame.es.human_attached_gun_common
require %appGame.es.interactable_common







def is_teams_friendly(team1 : int; team2 : int) 
  return team1 == team2
























































































































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
      return EBehResult ER_FAILED
    sendEvent(gunEid, [[CmdUse requesterEid=agentEid]])
    return EBehResult ER_SUCCESS

[beh_node(name="isAttachedToStationaryGun")]
class IsAttachedToStationaryGun : BehNodeAdapter
  gunEidParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "gunEidParam") >= 0
      gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var res = EBehResult ER_FAILED
    query(agentEid) <| $ [es] (human_attached_gun__attachedGunEid : EntityId)
      if gunEidParam >= 0
        let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
        if !!human_attached_gun__attachedGunEid && gunEid == human_attached_gun__attachedGunEid
          res = EBehResult ER_SUCCESS
      else
        if !!human_attached_gun__attachedGunEid
          res = EBehResult ER_SUCCESS
    return res

[beh_node(name="detachFromStationaryGun")]
class DetachFromStationaryGun : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var attachedGunEid = INVALID_ENTITY_ID
    query(agentEid) <| $ [es] (human_attached_gun__attachedGunEid : EntityId)
      attachedGunEid = human_attached_gun__attachedGunEid
    if attachedGunEid == INVALID_ENTITY_ID
      return EBehResult ER_SUCCESS 
    sendEvent(attachedGunEid, [[CmdUse requesterEid=agentEid]]) 
    return EBehResult ER_SUCCESS


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
      return EBehResult ER_FAILED

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
        return EBehResult ER_FAILED

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
        query() <| $ [es(REQUIRE=respbase, REQUIRE_NOT=customRespawnBase)] (active : bool; team : int; transform aka spawn_transform : float3x4; respawnbaseType : string)
          if !active || respawnbaseType != "human" || is_teams_friendly(team, playerTeam)
            return
          let respPos = spawn_transform[3]
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

    var res = EBehResult ER_FAILED
    query(gunEid) <| $ [es] (transform : float3x4)
      if posParam >= 0
        owner.blackBoard |> set(posParam, transform * posOffset)
      if gunEidOutParam >= 0
        owner.blackBoard |> set(gunEidOutParam, int(uint(gunEid)))
      if gunAITypeOutParam >= 0
        owner.blackBoard |> set(gunAITypeOutParam, gunAIType)
      res = EBehResult ER_SUCCESS
    return res



































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































