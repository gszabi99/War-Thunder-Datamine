options always_export_initializer = true

require app
require ecs
require ecs.common
require math
require math.base
require BehNodes
require DngWalkerai
require DagorDataBlock
require HumanPhys
require Dacoll
require pathfinder
require DagorRandom
require DagorMath
require Grid
require GridCollision
require %appGame.infantry.es.team_common
require DagorSystem


[beh_node(name="checkHealTeammatesAround")]
class CheckHealTeammatesAround : BehNodeAdapter
  healMateEidParam : int = -1
  nextHealWaitTime : float2 = float2(5.0, 10.0)
  checkAroundDistance : float = 7.0
  checkAroundHeights : float2 = float2(-1.5, 3.5)
  selfSquadOnly : bool = false

  hpHealThresholdCoef : float = 0.8
  minVelNotMovingSq : float = square(0.1)

  downedScoreMult : float = 0.5
  selfSquadPlayerScoreMult : float = 0.382
  selfSquadNonPlayerScoreMult : float = 0.618

  def override loadFromBlk(var data : DataBlock) : void
    healMateEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "healMateEidParam", ""), 0)
    nextHealWaitTime = datablock_getPoint2(data, "nextHealWaitTime", nextHealWaitTime)
    checkAroundDistance = datablock_getReal(data, "checkAroundDistance", checkAroundDistance)
    checkAroundHeights = datablock_getPoint2(data, "checkAroundHeights", checkAroundHeights)
    selfSquadOnly = datablock_getBool(data, "selfSquadOnly", selfSquadOnly)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED

    var result = false
    query(agent.eid) <| $ [es] (isAlive : bool;
                                isDowned : bool;
                                itemContainer : EidList;
                                transform aka bot_transform : float3x4;
                                human_net_phys__isSwimming : bool = false;
                                human_net_phys__isClimbing : bool = false;
                                squad_member__playerEid : EntityId)
      if !isAlive || isDowned || human_net_phys__isSwimming || human_net_phys__isClimbing
        return

      var botTeam = TEAM_UNASSIGNED
      var waitTime = 0.0
      query(squad_member__playerEid) <| $ [es] (team : int; player_bots__nextHealWaitTime : float)
        botTeam = team
        waitTime = player_bots__nextHealWaitTime
      if botTeam == TEAM_UNASSIGNED || get_sync_time() < waitTime
        return

      var canRevive = false
      var canHeal = false
      for itemEid in itemContainer
        query(itemEid) <| $ [es(REQUIRE=itemAIHeal)] (item__useTimeToTarget : float;
                                                      item__reviveAmount : float)
          if item__reviveAmount > 0.0 && item__useTimeToTarget > 0.0
            canRevive = true
        query(itemEid) <| $ [es(REQUIRE=itemAIHeal)] (item__useTimeToTarget : float;
                                                      item__healAmount : float = -1.0;
                                                      item__restoreHpAmount : float = -1.0)
          if item__useTimeToTarget > 0.0 && (item__healAmount > 0.0 || item__restoreHpAmount > 0.0)
            canHeal = true
      if !canRevive && !canHeal
        return

      var box = BBox3()
      let r = checkAroundDistance
      let h = checkAroundHeights
      box |> bbox3_add(bot_transform[3] + float3(-r, h.x, -r))
      box |> bbox3_add(bot_transform[3] + float3(r, h.y, r))

      let maxDistSq = square(checkAroundDistance)

      var bestEid = INVALID_ENTITY_ID
      var bestScore = FLT_MAX
      find_entity_in_grid(ecs_hash("humans"), box, GridEntCheck.BOUNDING) <| $(eid aka human_eid : EntityId)
        if human_eid == agent.eid
          return false
        query(human_eid) <| $ [es(REQUIRE=human, REQUIRE_NOT=deadEntity)] (isAlive : bool;
                                                                           isDowned aka human_isDowned : bool;
                                                                           transform aka human_transform : float3x4;
                                                                           hitpoints__hp : float = 1.0;
                                                                           hitpoints__maxHp : float = 1.0;
                                                                           beh_tree__enabled : bool = false;
                                                                           human_net_phys__velocity : float3 = float3();
                                                                           human_net_phys__isSwimming : bool = false;
                                                                           human_net_phys__isClimbing : bool = false;
                                                                           squad_member__playerEid aka human_squad_member__playerEid : EntityId)
          if !isAlive || human_net_phys__isSwimming || human_net_phys__isClimbing
            return

          let hpFull = hitpoints__hp >= hitpoints__maxHp * hpHealThresholdCoef
          if !human_isDowned && (!canHeal || hpFull)
            return
          if human_isDowned && !canRevive
            return

          let dirDelta = human_transform[3] - bot_transform[3]
          if !human_isDowned && length_sq(human_net_phys__velocity) > minVelNotMovingSq && dot(human_net_phys__velocity, dirDelta) > 0.0
            return
          let distSq = length_sq(dirDelta)
          if distSq > maxDistSq
            return

          var humanTeam = TEAM_UNASSIGNED
          query(human_squad_member__playerEid) <| $ [es] (team : int)
            humanTeam = team
          if humanTeam != botTeam
            return
          if selfSquadOnly && human_squad_member__playerEid != squad_member__playerEid
            return

          var humanScore = hitpoints__hp * min(1.0, distSq)
          if human_isDowned
            humanScore *= downedScoreMult
          if human_squad_member__playerEid == squad_member__playerEid
            humanScore *= beh_tree__enabled ? selfSquadNonPlayerScoreMult : selfSquadPlayerScoreMult

          if humanScore < bestScore
            bestEid = human_eid
            bestScore = humanScore
        return false
      if !bestEid
        return

      owner.blackBoard |> set(healMateEidParam, int(uint(bestEid)))

      query(squad_member__playerEid) <| $ [es] (var player_bots__nextHealWaitTime : float&)
        player_bots__nextHealWaitTime = get_sync_time() + rnd_float(nextHealWaitTime.x, nextHealWaitTime.y)

      result = true
    return result ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
