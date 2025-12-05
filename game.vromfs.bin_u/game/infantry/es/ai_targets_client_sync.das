require DagorSystem
require net
require %game.utils.net_utils
require walkerai
require ecs

require %appGame.wt_events
require ecs.common

[es(tag=server, after=ai_danger_trace_targets)]
def ai_danger_save_squad_targets(act : UpdateStageInfoAct;
                                 squad__allMembers : EidList;
                                 squad__ownerPlayer : EntityId;
                                 var squad__allMembersHumanTargets : EidList&)
  if has(squad__ownerPlayer, "playerIsBot")
    return
  squad__allMembersHumanTargets.clear()
  for memberEid in squad__allMembers
    query(memberEid) <| $ [es(REQUIRE_NOT=deadEntity)] (agent_dangers : AgentDangers)
      for danger in agent_dangers.dangers
        if danger.traceable && has(danger.eid, "human")
          if find_index(squad__allMembersHumanTargets, danger.eid) < 0
            push(squad__allMembersHumanTargets, danger.eid)

[es(tag=server, after=ai_danger_trace_targets)]
def ai_danger_send_squad_targets_changes(act : UpdateStageInfoAct;
                                         eid : EntityId;
                                         squad__ownerPlayer : EntityId;
                                         squad__allMembersHumanTargets : EidList;
                                         squad__humanTargetsSyncCooldown : float;
                                         var squad__humanTargetsNextSyncAtTime : float&;
                                         var squad__allMembersHumanTargetsSync : EidList&)
  if has(squad__ownerPlayer, "playerIsBot")
    return

  if squad__humanTargetsNextSyncAtTime > act.curTime
    return
  squad__humanTargetsNextSyncAtTime = act.curTime + squad__humanTargetsSyncCooldown

  for targetEid in squad__allMembersHumanTargets
    if find_index(squad__allMembersHumanTargetsSync, targetEid) < 0
      send_net_event(eid, EventSquadTargetsAddEid(targetEid = targetEid), target_entity_conn(squad__ownerPlayer))

  for targetEid in squad__allMembersHumanTargetsSync
    if find_index(squad__allMembersHumanTargets, targetEid) < 0
      send_net_event(eid, EventSquadTargetsRemoveEid(targetEid = targetEid), target_entity_conn(squad__ownerPlayer))
  squad__allMembersHumanTargetsSync := squad__allMembersHumanTargets

[es(tag=netClient)]
def ai_danger_add_squad_targets_changes(evt : EventSquadTargetsAddEid;
                                        eid : EntityId;
                                        var squad__allMembersHumanTargetsSync : EidList)
  if find_index(squad__allMembersHumanTargetsSync, evt.targetEid) < 0
    push(squad__allMembersHumanTargetsSync, evt.targetEid)
  else
    logerr("Target {evt.targetEid} is already in squad entity {eid} list")

[es(tag=netClient)]
def ai_danger_remove_squad_targets_changes(evt : EventSquadTargetsRemoveEid;
                                           eid : EntityId;
                                           var squad__allMembersHumanTargetsSync : EidList)
  let idx = find_index(squad__allMembersHumanTargetsSync, evt.targetEid)
  if idx >= 0
    squad__allMembersHumanTargetsSync |> erase(idx)
  else
    logerr("Target for remove {evt.targetEid} isn't in list of synced targets for squad {eid}")