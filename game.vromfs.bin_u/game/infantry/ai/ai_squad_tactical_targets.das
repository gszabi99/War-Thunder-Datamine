require ecs
require app
require DagorRandom
require %game.events
require walkerai
require %appGame.infantry.ai.ai_squad_tactical_common

[es(tag=server, no_order)]
def ai_squad_tactical_update_targets(info : ParallelUpdateFrameDelayed;
                                     eid aka squad_eid : EntityId;
                                     squad__ownerPlayer : EntityId;
                                     squadAI_tactical__updateTargetsTime : float2;
                                     var squadAI_tactical__updateTargetsTimer : float&)
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

    query(memberEid) <| $ [es] (var agent_dangers : AgentDangers)
      for danger in agent_dangers.dangers
        if danger.traceable
          ai_squad_tactical_add_update_target(squad_eid, danger.eid, false)




















