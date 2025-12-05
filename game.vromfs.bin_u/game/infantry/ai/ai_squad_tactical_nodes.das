options always_export_initializer = true

require app
require ecs
require math
require math.base
require math.random
require DagorMath
require BehNodes
require DagorDataBlock
require %appGame.infantry.ai.ai_squad_tactical_common

[beh_node(name="addUpdateTacticalTarget")]
class AddUpdateTacticalTarget : BehNodeAdapter
  targetEidParam : int = -1
  updateOnly : bool = false

  def override loadFromBlk(data : DataBlock) : void
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", ""), 0)
    updateOnly = datablock_getBool(data, "updateOnly", updateOnly)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId)
      let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
      query(targetEid) <| $ [es] (isAlive : bool = false)
        if isAlive
          ai_squad_tactical_add_update_target(squad_member__squad, targetEid, updateOnly)
    return EBehResult.ER_SUCCESS

[beh_node(name="checkActualTacticalTargets")]
class CheckActualTacticalTargets : BehNodeAdapter
  minTargets : int = 1
  maxTargets : int = 3
  chanceMinTargets : float = 0.95

  chanceMinDistance : float = 0.05
  rangeMinMaxDistances : float2 = float2(10.0, 100.0)
  maxTargetTimeByDist : float2 = float2(20.0, 5.0)

  def override loadFromBlk(data : DataBlock) : void
    minTargets = datablock_getInt(data, "minTargets", minTargets)
    maxTargets = datablock_getInt(data, "maxTargets", maxTargets)
    chanceMinTargets = datablock_getReal(data, "chanceMinTargets", chanceMinTargets)

    chanceMinDistance = datablock_getReal(data, "chanceMinDistance", chanceMinDistance)
    rangeMinMaxDistances = datablock_getPoint2(data, "rangeMinMaxDistances", rangeMinMaxDistances)
    maxTargetTimeByDist = datablock_getPoint2(data, "maxTargetTimeByDist", maxTargetTimeByDist)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var agentPos = float3()
    var hasAgentInfo = false
    query(agentEid) <| $ [es] (transform : float3x4)
      agentPos = transform[3]
      hasAgentInfo = true
    if !hasAgentInfo
      return EBehResult.ER_FAILED

    var numActualTargets = 0
    query(agentEid) <| $ [es] (squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (squadAI_tactical__targetsPosTime : Point4List; squadAI_tactical__targetsEids : EidList)
        let curTime = get_sync_time()
        for posTime, targetEid in squadAI_tactical__targetsPosTime, squadAI_tactical__targetsEids
          if curTime > posTime.w + maxTargetTimeByDist.x 
            continue
          var isValidTarget = false
          query(targetEid) <| $ [es] (isAlive : bool)
            isValidTarget = isAlive
          if !isValidTarget 
            continue
          let distToTarget = distance(posTime.xyz, agentPos)
          let timeoutByDist = cvt(distToTarget, rangeMinMaxDistances.x, rangeMinMaxDistances.y, maxTargetTimeByDist.x, maxTargetTimeByDist.y)
          if curTime > posTime.w + timeoutByDist 
            continue
          let chanceByDist = cvt(distToTarget, rangeMinMaxDistances.x, rangeMinMaxDistances.y, chanceMinDistance, 1.0)
          if rnd_float(0.0, 1.0) < chanceByDist 
            continue
          ++numActualTargets

    if numActualTargets < minTargets
      return EBehResult.ER_FAILED
    if numActualTargets >= maxTargets
      return EBehResult.ER_SUCCESS
    let chanceByNum = cvt(float(numActualTargets), float(minTargets), float(maxTargets), chanceMinTargets, 1.0)
    if chanceByNum < 1.0 && rnd_float(0.0, 1.0) > chanceByNum 
      return EBehResult.ER_FAILED

    return EBehResult.ER_SUCCESS
