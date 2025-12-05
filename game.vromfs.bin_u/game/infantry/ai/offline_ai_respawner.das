require ecs
require app
require math.base

[es(tag=server, no_order)]
def offline_ai_respawner_es(act : UpdateStageInfoAct;
                            eid aka offline_ai_spawner_eid : EntityId;
                            var offline_ai_respawner__initTimer : float&;
                            offline_ai_respawner__respawnTime : float = 5.0)
  if offline_ai_respawner__initTimer > 0.0
    offline_ai_respawner__initTimer -= act.dt
    if offline_ai_respawner__initTimer > 0.0
      return
    
    query(offline_ai_spawner_eid) <| $ [es] (var offline_ai_respawner__unitTemplate : StringList&;
                                             var offline_ai_respawner__unitTeam : IntList&;
                                             var offline_ai_respawner__unitTransform : TMatrixList&;
                                             var offline_ai_respawner__unitSquad : EidList&;
                                             var offline_ai_respawner__unitPlayer : EidList&;
                                             var offline_ai_respawner__unitMemberIdx : IntList&;
                                             var offline_ai_respawner__unitBehNode : StringList&;
                                             var offline_ai_respawner__unitIsAI : BoolList&;
                                             var offline_ai_respawner__unitLastEid : EidList&;
                                             var offline_ai_respawner__unitRespawnTimer : FloatList&)
      query() <| $ [es] (eid aka squad_member_eid : EntityId;
                         squad_member__squad : EntityId;
                         squad_member__playerEid : EntityId;
                         squad_member__memberIdx : int;
                         beh_tree__node : string; beh_tree__enabled : bool;
                         transform : float3x4; team : int)
        if squad_member__squad == INVALID_ENTITY_ID || squad_member__playerEid == INVALID_ENTITY_ID || team <= 0
          return

        let tmpl = getEntityTemplateName(eid)
        

        offline_ai_respawner__unitTemplate |> push(tmpl)
        offline_ai_respawner__unitTeam |> push(team)
        offline_ai_respawner__unitTransform |> push(transform)
        offline_ai_respawner__unitSquad |> push(squad_member__squad)
        offline_ai_respawner__unitPlayer |> push(squad_member__playerEid)
        offline_ai_respawner__unitMemberIdx |> push(squad_member__memberIdx)
        offline_ai_respawner__unitBehNode |> push(beh_tree__node)
        offline_ai_respawner__unitIsAI |> push(beh_tree__enabled)

        offline_ai_respawner__unitLastEid |> push(squad_member_eid)
        offline_ai_respawner__unitRespawnTimer |> push(offline_ai_respawner__respawnTime)

        query(squad_member__squad) <| $ [es] (var squad__doNotCleanUp : bool&)
          squad__doNotCleanUp = true
    return

  
  let CHECK_TIME_PERIOD = 1.0
  offline_ai_respawner__initTimer -= act.dt
  if offline_ai_respawner__initTimer > -CHECK_TIME_PERIOD
    return
  offline_ai_respawner__initTimer = 0.0

  query() <| $ [es] (eid aka squad_eid : EntityId;
                     var squad__allMembers : EidList&;
                     var squad__leader : EntityId&)
    var numAlive = 0
    for memberEid in squad__allMembers
      query(memberEid) <| $ [es] (isAlive : bool)
        if isAlive
          ++numAlive
    if numAlive > 0
      return

    query(offline_ai_spawner_eid) <| $ [es] (offline_ai_respawner__unitTemplate : StringList;
                                             offline_ai_respawner__unitTeam : IntList;
                                             offline_ai_respawner__unitTransform : TMatrixList;
                                             offline_ai_respawner__unitSquad : EidList;
                                             offline_ai_respawner__unitPlayer : EidList;
                                             offline_ai_respawner__unitMemberIdx : IntList;
                                             offline_ai_respawner__unitBehNode : StringList;
                                             offline_ai_respawner__unitIsAI : BoolList;
                                             var offline_ai_respawner__unitLastEid : EidList&;
                                             var offline_ai_respawner__unitRespawnTimer : FloatList&)
      var waiting = false
      for memberEid in squad__allMembers
        for unitEid, unitRespawnTimer in offline_ai_respawner__unitLastEid, offline_ai_respawner__unitRespawnTimer
          if unitEid == memberEid
            if unitRespawnTimer > 0.0
              unitRespawnTimer -= CHECK_TIME_PERIOD
              waiting = true
      if waiting
        return

      for memberEidIdx in iter_range(squad__allMembers)
        for unitIdx in iter_range(offline_ai_respawner__unitLastEid)
          if offline_ai_respawner__unitLastEid[unitIdx] == squad__allMembers[memberEidIdx] && offline_ai_respawner__unitSquad[unitIdx] == squad_eid
            let tmpl = string(offline_ai_respawner__unitTemplate[unitIdx])
            let newUnitEid = createEntity(tmpl) <| $(var init : ComponentsInitializer)
              set(init, "transform", offline_ai_respawner__unitTransform[unitIdx])
              set(init, "team", offline_ai_respawner__unitTeam[unitIdx])
              set(init, "spawn_immunity__timer", 0.f)
              set(init, "squad_member__squad", offline_ai_respawner__unitSquad[unitIdx])
              set(init, "squad_member__playerEid", offline_ai_respawner__unitPlayer[unitIdx])
              set(init, "squad_member__memberIdx", offline_ai_respawner__unitMemberIdx[unitIdx])
              set(init, "beh_tree__node", offline_ai_respawner__unitBehNode[unitIdx])
              set(init, "beh_tree__enabled", offline_ai_respawner__unitIsAI[unitIdx])

            

            offline_ai_respawner__unitLastEid[unitIdx] = newUnitEid
            offline_ai_respawner__unitRespawnTimer[unitIdx] = offline_ai_respawner__respawnTime

            squad__allMembers[memberEidIdx] = INVALID_ENTITY_ID
            squad__leader = newUnitEid
      squad__allMembers |> clear() 
