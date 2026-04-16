require ecs
require app
require math.base
require DagorRandom
require %game.events
require Grid
require walkerai
require %appGame.infantry.ai.ai_squad_tactical_common

[es(tag=server, no_order)]
def ai_squad_tactical_update_targets(info : ParallelUpdateFrameDelayed;
                                     eid aka squad_eid : EntityId;
                                     squad__ownerPlayer : EntityId;
                                     squad__numAliveMembers : int;
                                     squadAI_tactical__updateTargetsTime : float2;
                                     var squadAI_tactical__updateTargetsTimer : float&;
                                     squadAI_tactical__informTeamMatesRadius : float = 25.0)
  var isBot = false
  query(squad__ownerPlayer) <| $ [es(REQUIRE=playerIsBot)] ()
    isBot = true
  if !isBot
    return

  squadAI_tactical__updateTargetsTimer -= info.dt
  if squadAI_tactical__updateTargetsTimer > 0.0
    return
  squadAI_tactical__updateTargetsTimer = rnd_float(squadAI_tactical__updateTargetsTime.x, squadAI_tactical__updateTargetsTime.y)

  query(squad_eid) <| $ [es] (squad__allMembers : EidList;
                              var squadAI_tactical__updateTargetsIndex : int&)
    let numMembers = length(squad__allMembers)
    if numMembers <= 0
      return

    if squadAI_tactical__updateTargetsIndex < 0 || squadAI_tactical__updateTargetsIndex >= numMembers
      squadAI_tactical__updateTargetsIndex = 0

    let memberEid = squad__allMembers[squadAI_tactical__updateTargetsIndex]
    squadAI_tactical__updateTargetsIndex++

    if squad__numAliveMembers == 1
      query(memberEid) <| $ [es] (transform : float3x4; agent_dangers : AgentDangers; team aka member_team : int)
        let memberPos = transform[3]
        let informRadius = squadAI_tactical__informTeamMatesRadius
        var informsLeft = 2
        for_each_entity_in_grid(ecs_hash("humans"), BSphere3(memberPos, informRadius), GridEntCheck.BOUNDING) <| $(that_eid : EntityId; that_pos : float3)
          if informsLeft > 0 && that_eid != memberEid && distance_sq(that_pos, memberPos) < square(informRadius)
            query(that_eid) <| $ [es] (isAlive : bool; squad_member__squad : EntityId; team aka that_team : int)
              if isAlive && member_team == that_team && squad_eid != squad_member__squad
                --informsLeft
                for danger in agent_dangers.dangers
                  if danger.traceable
                    ai_squad_tactical_add_update_target(squad_member__squad, danger.eid, false)
    else
      query(memberEid) <| $ [es] (agent_dangers : AgentDangers)
        for danger in agent_dangers.dangers
          if danger.traceable
            ai_squad_tactical_add_update_target(squad_eid, danger.eid, false)




















