options no_global_variables = false
require ecs
require app
require math.base
require math.random
require walkerai
require DngWalkerai
require BehNodes
require Dacoll
require DagorDataBlock
require DagorRandom
require DagorMath
require math.linear
require Grid
require WTDamageModel
require %appGame.wt_events
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.team_common
require Weapon


var 
  REGULAR_CHECK_REACTION_ID : int
  ON_HIT_REACTION_ID : int
  ON_BULLET_NEARBY_REACTION_ID : int
  TRACEABLE_DANGER_REACTION_ID : int
  ENEMY_PLAYER_NEAR_REACTION_ID : int
  TEAM_MATE_IN_TROUBLE_REACTION_ID : int
  SQUAD_LEADER_CHANGED_VEHICLE_REACTION_ID : int
  SQUAD_LEADER_CHANGED_REACTION_ID : int
  SQUAD_LEADER_REDIRECT_REACTION_ID : int
  SQUAD_LEADER_FOLLOW_REACTION_ID : int

[register_beh_nodes]
def register_nodes()
  REGULAR_CHECK_REACTION_ID = register_reaction("regularCheck")
  ON_HIT_REACTION_ID = register_reaction("onHit")
  ON_BULLET_NEARBY_REACTION_ID = register_reaction("onBulletNearby")
  TRACEABLE_DANGER_REACTION_ID = walkerai::register_reaction("onTraceableDanger")
  ENEMY_PLAYER_NEAR_REACTION_ID = walkerai::register_reaction("onEnemyPlayerNear")
  TEAM_MATE_IN_TROUBLE_REACTION_ID = walkerai::register_reaction("onTeamMateTrouble")
  SQUAD_LEADER_CHANGED_VEHICLE_REACTION_ID = walkerai::register_reaction("onSquadLeaderChangedVehicle")
  SQUAD_LEADER_CHANGED_REACTION_ID = walkerai::register_reaction("onSquadLeaderChanged")
  SQUAD_LEADER_REDIRECT_REACTION_ID = walkerai::register_reaction("leaderRedirect")
  SQUAD_LEADER_FOLLOW_REACTION_ID = walkerai::register_reaction("followLeader")


[es(on_appear)]
def beh_tree_regular_check_reaction_init(evt : Event; beh_tree__regularCheckRange : float2; var beh_tree__regularCheckAt : float&)
  beh_tree__regularCheckAt = get_sync_time() + rnd_float(beh_tree__regularCheckRange)

[es(REQUIRE_NOT=deadEntity, before=beh_tree_update_es, after=walker_agent_es)]
def beh_tree_regular_check_reaction(info : UpdateStageInfoAct;
                                    beh_tree__enabled : bool;
                                    beh_tree__regularCheckRange : float2;
                                    var beh_tree__regularCheckAt : float&;
                                    var beh_tree : BehaviourTree)
  if !beh_tree__enabled || beh_tree__regularCheckAt >= info.curTime
    return
  beh_tree |> beh_tree_react(REGULAR_CHECK_REACTION_ID, info.dt)
  beh_tree__regularCheckAt = info.curTime + rnd_float(beh_tree__regularCheckRange)


[es(tag=server, no_order)]
def beh_tree_clear_agent_dangers_on_died(evt : EventEntityDied; var agent_dangers : AgentDangers)
  agent_dangers.dangers |> clear()

[es(tag=server, no_order)]
def beh_tree_on_hit_reaction(evt : EventOnEntityHit; eid : EntityId; isAlive : bool; team : int;
                             var beh_tree : BehaviourTree; beh_tree__enabled : bool = true;
                             var agent_dangers__lastHitReactionDir : float3?;
                             var agent_dangers__lastHitReactionOffenderEid : EntityId?;
                             var agent_dangers__lastHitReactionTime : float?)
  if !beh_tree__enabled || !isAlive || evt.damageType == int(DamageType.DM_BLEEDING)
    return
  let offenderEid = evt.offender
  let offenderTeam = get_int(offenderEid, "team") ?? TEAM_UNASSIGNED
  if eid != evt.victim || is_teams_friendly(offenderTeam, team) || has(offenderEid, "dmgzone__damage")
    return
  if agent_dangers__lastHitReactionTime != null
    *agent_dangers__lastHitReactionTime = get_sync_time()
  if agent_dangers__lastHitReactionOffenderEid != null
    *agent_dangers__lastHitReactionOffenderEid = offenderEid
  if agent_dangers__lastHitReactionDir != null
    *agent_dangers__lastHitReactionDir = evt.hitDir
  beh_tree |> beh_tree_react(ON_HIT_REACTION_ID, 0f)


[es(tag=server, no_order)]
def beh_tree_on_bullet_nearby_reaction(info : UpdateStageInfoAct; isAlive : bool; team : int;
                                       var agent_dangers : AgentDangers;
                                       agent_dangers__standShootPos : float3;
                                       var beh_tree : BehaviourTree; beh_tree__enabled : bool = true;
                                       var agent_dangers__lastBulletReactionTime : float&;
                                       var agent_dangers__nextBulletReactionTime : float&;
                                       var agent_dangers__lastBulletReactionOffenderEid : EntityId?;
                                       var agent_dangers__lastBulletReactionDir : float3?;
                                       agent_dangers__projectileDist : float = 4.0;
                                       agent_dangers__silencedProjectileDist : float = 1.0;
                                       agent_dangers__bulletReactionTime : float = 0.4)


  if !beh_tree__enabled || !isAlive || info.curTime < agent_dangers__nextBulletReactionTime
    return
  let projectileDistSq = square(agent_dangers__projectileDist)
  let silencedProjectileDistSq = square(agent_dangers__silencedProjectileDist)
  var projectileVel = float3()
  var offenderEid = INVALID_ENTITY_ID

  find_query() <| $ [es] (bullet_component : Bullet; isSilencedProjectile : Tag const?)
    let ownerEid = bullet_component.damageOwnerEid
    let startPos = bullet_component.pos
    let endPos = bullet_component.pos + bullet_component.vel * info.dt
    let distSq = distance_sq_to_seg(agent_dangers__standShootPos, startPos, endPos);
    if distSq > (isSilencedProjectile != null ? silencedProjectileDistSq : projectileDistSq)
      return false

    let projectileOwnerTeam = get_int(ownerEid, "team") ?? TEAM_UNASSIGNED
    if is_teams_friendly(team, projectileOwnerTeam)
      return false

    for danger in agent_dangers.dangers
      if danger.eid == ownerEid
        danger.lastBulletNearbyTime = info.curTime
        break

    offenderEid = ownerEid
    projectileVel = bullet_component.vel
    agent_dangers__nextBulletReactionTime = info.curTime + agent_dangers__bulletReactionTime
    return true

  if offenderEid != INVALID_ENTITY_ID
    if agent_dangers__lastBulletReactionOffenderEid != null
      *agent_dangers__lastBulletReactionOffenderEid = offenderEid
    if agent_dangers__lastBulletReactionDir != null
      *agent_dangers__lastBulletReactionDir = -normalize(projectileVel) 

  if agent_dangers__lastBulletReactionTime != agent_dangers__nextBulletReactionTime && agent_dangers__nextBulletReactionTime < info.curTime
    agent_dangers__lastBulletReactionTime = agent_dangers__nextBulletReactionTime
    beh_tree |> beh_tree_react(ON_BULLET_NEARBY_REACTION_ID, 0f)


def has_traceable_danger(dangers; threshold : float)
  for danger in dangers
    if danger.traceable && danger.dangerMeter >= threshold
      return true
  return false

[es(tag=server, no_order)]
def beh_tree_traceable_danger_reaction(act : UpdateStageInfoAct; agent_dangers : AgentDangers;
                                       var beh_tree : BehaviourTree; beh_tree__enabled : bool = true;
                                       var agent_dangers__hasTraceableDangers : bool&;
                                       agent_dangers__hasTraceableDangerThreshold = 1.0)
  if !beh_tree__enabled || length(agent_dangers.dangers) == 0
    agent_dangers__hasTraceableDangers = false
    return
  let hasTraceableDangers = has_traceable_danger(agent_dangers.dangers, agent_dangers__hasTraceableDangerThreshold)
  if hasTraceableDangers && hasTraceableDangers != agent_dangers__hasTraceableDangers && TRACEABLE_DANGER_REACTION_ID > -1
    beh_tree |> beh_tree_react(TRACEABLE_DANGER_REACTION_ID, 0f)
  agent_dangers__hasTraceableDangers = hasTraceableDangers


[es(tag=server, REQUIRE_NOT=deadEntity, no_order)]
def beh_tree_enemy_player_near_reaction(act : UpdateStageInfoAct; agent_dangers : AgentDangers; var beh_tree : BehaviourTree;
                                        beh_tree__enemyPlayerInRadiusDist : float;
                                        var beh_tree__enemyPlayerInRadiusAt : float&;
                                        beh_tree__enemyPlayerInRadiusPeriod : float;
                                        beh_tree__enabled : bool = true)
  if !beh_tree__enabled || length(agent_dangers.dangers) == 0 || act.curTime < beh_tree__enemyPlayerInRadiusAt
    return

  beh_tree__enemyPlayerInRadiusAt = act.curTime + beh_tree__enemyPlayerInRadiusPeriod

  for danger in agent_dangers.dangers
    if danger.traceable && danger.distance < beh_tree__enemyPlayerInRadiusDist
      beh_tree |> beh_tree_react(ENEMY_PLAYER_NEAR_REACTION_ID, 0f)
      return


[es(tag=server, REQUIRE=human, track=(isAlive, isDowned))]
def beh_tree_team_mate_in_trouble_reaction(evt : Event;
                                           eid aka victim_eid : EntityId;
                                           beh_tree__enabled : bool;
                                           isAlive : bool;
                                           isDowned : bool;
                                           isInVehicle : bool;
                                           team aka victim_team : int;
                                           transform aka victim_transform : float3x4;
                                           beh_tree__mateTroubleCallMaxDistance : float = 25.0)
  if isAlive && !isDowned
    return
  if !beh_tree__enabled || isInVehicle
    return

  if rnd_float(0.0, 1.0) < 0.1
    return

  var callEid = INVALID_ENTITY_ID
  var callDistSq = square(beh_tree__mateTroubleCallMaxDistance)

  let humanMidOfs = float3(0.0, 1.0, 0.0)
  let seePos = victim_transform[3] + humanMidOfs

  let callSphere = BSphere3(victim_transform[3], beh_tree__mateTroubleCallMaxDistance)
  for_each_entity_in_grid(ecs_hash("humans"), callSphere, GridEntCheck.BOUNDING) <| $(human_eid : EntityId)
    if human_eid == victim_eid
      return
    query(human_eid) <| $ [es(REQUIRE_NOT=(deadEntity))] (beh_tree__enabled : bool;
                                                          isAlive : bool;
                                                          isDowned : bool;
                                                          isInVehicle : bool;
                                                          team aka human_team : int;
                                                          walker_agent__serverAiAction : int;
                                                          walker_agent__serverAiActionTime : float;
                                                          beh_tree__mateTroubleCloseRadius : float = 7.0;
                                                          beh_tree__mateTroubleStandReactTime : float = 0.5;
                                                          beh_tree__mateTroubleMoveReactTime : float = 2.0;
                                                          beh_tree__mateTroubleCoverReactTime : float = 3.0;
                                                          transform aka human_transform : float3x4)
      if human_team != victim_team
        return
      if !beh_tree__enabled || !isAlive || isDowned || isInVehicle
        return
      let aiAction = walker_agent__serverAiAction
      let passedTime = get_sync_time() - walker_agent__serverAiActionTime
      if (!(aiAction == int(AiAction.AI_ACTION_STAND) && passedTime > beh_tree__mateTroubleStandReactTime) &&
          !(aiAction == int(AiAction.AI_ACTION_MOVE) && passedTime > beh_tree__mateTroubleMoveReactTime) &&
          !(aiAction == int(AiAction.AI_ACTION_IN_COVER) && passedTime > beh_tree__mateTroubleCoverReactTime))
        return
      let fromPos = human_transform[3] + humanMidOfs
      let distSq = distance_sq(human_transform[3], victim_transform[3])
      if distSq < callDistSq
        let lookVec = seePos - fromPos
        let isClose = distSq < square(beh_tree__mateTroubleCloseRadius)
        if isClose || dot(human_transform[0], lookVec) > 0.0
          let lookDir = normalize(lookVec)
          let dist = length(lookVec)
          let vecRight = float3(lookDir.z, 0.0, -lookDir.x)
          let lookDir2 = normalize(seePos + vecRight - fromPos)
          let lookDir3 = normalize(seePos - vecRight - fromPos)
          if isClose || (!rayhit_normalized(fromPos, lookDir, dist, ETF_DEFAULT, -1) ||
                         !rayhit_normalized(fromPos, lookDir2, dist, ETF_DEFAULT, -1) ||
                         !rayhit_normalized(fromPos, lookDir3, dist, ETF_DEFAULT, -1))
            callDistSq = distSq
            callEid = human_eid

  if callEid == INVALID_ENTITY_ID
    return

  let reactPos = victim_transform[3]
  var enemyEid = INVALID_ENTITY_ID
  var enemyPos = float3()

  query(victim_eid) <| $ [es] (hitpoints__lastOffender : OffenderData)
    query(hitpoints__lastOffender.eid) <| $ [es] (transform aka enemy_transform : float3x4)
      enemyEid = hitpoints__lastOffender.eid
      enemyPos = enemy_transform[3]

  if enemyEid == INVALID_ENTITY_ID
    return

  query(callEid) <| $ [es] (var beh_tree : BehaviourTree)
    beh_tree.blackBoard |> set("reactionPos", reactPos)
    beh_tree.blackBoard |> set("reactionEnemyEid", int(uint(enemyEid)))
    beh_tree.blackBoard |> set("reactionEnemyPos", enemyPos)

    beh_tree |> beh_tree_react(TEAM_MATE_IN_TROUBLE_REACTION_ID, 0f)


[es(tag=server, track=squad__leader)]
def beh_tree_squad_leader_changed_reaction(evt : Event;
                                           eid : EntityId;
                                           squad__leader : EntityId)
  query(eid) <| $ [es] (squad__allMembers : EidList)
    for memberEid in squad__allMembers
      if squad__leader == memberEid
        continue
      query(memberEid) <| $ [es(REQUIRE_NOT=deadEntity)] (beh_tree__enabled : bool; var beh_tree : BehaviourTree)
        if beh_tree__enabled
          beh_tree |> beh_tree_react(SQUAD_LEADER_CHANGED_REACTION_ID, 0f)


[es(tag=server, REQUIRE=isInVehicle, track=isInVehicle)]
def beh_tree_squad_leader_changed_vehicle_reaction(evt : Event;
                                                   eid : EntityId;
                                                   squad_member__squad : EntityId)
  query(squad_member__squad) <| $ [es] (squad__allMembers : EidList; squad__leader : EntityId)
    if squad__leader != eid
      return
    for memberEid in squad__allMembers
      if squad__leader == memberEid
        continue
      query(memberEid) <| $ [es(REQUIRE_NOT=deadEntity)] (beh_tree__enabled : bool; var beh_tree : BehaviourTree)
        if beh_tree__enabled
          beh_tree |> beh_tree_react(SQUAD_LEADER_CHANGED_VEHICLE_REACTION_ID, 0f)


[es(tag=server, track=squad_member__makeReaction)]
def beh_tree_squad_leader_make_reaction(evt : Event; eid : EntityId;
                                        squad_member__squad : EntityId;
                                        var squad_member__makeReaction : das_string&)
  if squad_member__makeReaction == ""
    return
  let makeReaction = string(squad_member__makeReaction)
  squad_member__makeReaction := ""

  if makeReaction == "leader_redirect"
    query(squad_member__squad) <| $ [es] (squad__allMembers : EidList; squad__leader : EntityId)
      if squad__leader != eid
        return
      for memberEid in squad__allMembers
        if squad__leader == memberEid
          continue
        query(memberEid) <| $ [es(REQUIRE_NOT=deadEntity)] (beh_tree__enabled : bool; var beh_tree : BehaviourTree)
          if beh_tree__enabled
            query(memberEid) <| $ [es] (var squad_member__forceReposition : bool&)
              squad_member__forceReposition = true
            beh_tree |> beh_tree_react(SQUAD_LEADER_REDIRECT_REACTION_ID, 0f)
  elif makeReaction == "follow_leader"
    query(eid) <| $ [es(REQUIRE_NOT=deadEntity)] (beh_tree__enabled : bool; var beh_tree : BehaviourTree)
      if beh_tree__enabled
        beh_tree |> beh_tree_react(SQUAD_LEADER_FOLLOW_REACTION_ID, 0f)
