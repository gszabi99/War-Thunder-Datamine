module ai_dangers_attack_debug_common shared

require ecs
require app
require DagorMathUtils


enum AIDangerEvent
  ADDED       
  TRACEABLE   
  INFRUSTUM   
  LOST        
  GOT_DANGER  
  REJECTED    
  R_APPEAR    
  R_NEARBY    
  A_BEGIN     
  A_OTHER     
  A_SHOOT     
  A_MELEE     
  A_SUCCESS   
  ACTION_DSYM 

enum private AIDangerFlags
  TRACEABLE = 1
  INFRUSTUM = 2
  IN_ANALYSIS = 4
  DONE_ANALYZE = 8

def private debug_ai_attack_add_event(ev_type : AIDangerEvent; ev_n1 : int; ev_n2 : int;
                                      agent_eid : EntityId; danger_eid : EntityId;
                                      var danger_data : int4&; danger_idx : int)
  if (danger_data.y & int(AIDangerFlags.DONE_ANALYZE)) != 0
    error("debugDanger: SHOULD NOT ADD EVENTS TO ANALYZED! agent_eid={agent_eid} danger_eid={danger_eid} danger_idx={danger_idx}")
    return

  query() <| $ [es] (var dangers_attack_debug__eventData : IPoint4List&;
                     var dangers_attack_debug__eventVec1 : Point4List&;
                     var dangers_attack_debug__eventVec2 : Point4List&;
                     var dangers_attack_debug__eventDSym : IPoint4List&)
    let atTime = get_sync_time()

    var agentPos = float3()
    var agentYaw = -1.f
    query(agent_eid) <| $ [es] (transform : float3x4)
      agentPos = transform[3]
      agentYaw = dir_to_angles(transform[0]).x

    var agentBeh = -1
    var agentAct = -1
    var agentActID = -1
    query(agent_eid) <| $ [es] (beh_tree__debugSym1 : int3; beh_tree__debugSym2 : int3)
      agentBeh = beh_tree__debugSym1.x
      agentAct = beh_tree__debugSym1.z
      agentActID = beh_tree__debugSym2.x

    var dangerPos = float3()
    query(danger_eid) <| $ [es] (transform : float3x4)
      dangerPos = transform[3]

    let evPrev = danger_data.z
    danger_data.z = length(dangers_attack_debug__eventData)

    let ctxFlags = danger_data.y

    dangers_attack_debug__eventData |> push(int4(evPrev, ev_type, ev_n1, ev_n2))
    dangers_attack_debug__eventVec1 |> push(float4(dangerPos, atTime))
    dangers_attack_debug__eventVec2 |> push(float4(agentPos, agentYaw))
    dangers_attack_debug__eventDSym |> push(int4(agentBeh, agentAct, agentActID, ctxFlags))

def private debug_ai_attack_add_event(ev_type : AIDangerEvent; ev_n1 : int; ev_n2 : int;
                                      agent_eid : EntityId; danger_eid : EntityId;
                                      danger_idx : int)
  query() <| $ [es] (var dangers_attack_debug__dangerData : IPoint4List&)
    assume dangersData = dangers_attack_debug__dangerData
    debug_ai_attack_add_event(ev_type, ev_n1, ev_n2, agent_eid, danger_eid, dangersData[danger_idx], danger_idx)


def debug_ai_attack_find_agent(agent_eid : EntityId)
  var agentIdx = -1
  query() <| $ [es] (dangers_attack_debug__agentEid : EidList)
    for i in iter_range(dangers_attack_debug__agentEid)
      if dangers_attack_debug__agentEid[i] == agent_eid
        agentIdx = i
        break
  return agentIdx

def private debug_ai_attack_find_agent_and_danger(agent_eid : EntityId; danger_eid : EntityId;
                                                  var out_danger_idx : int&; var out_prev_danger_idx : int&;
                                                  var over_danger_idx : int&)
  var agentIdx = -1
  out_danger_idx = -1
  out_prev_danger_idx = -1
  query() <| $ [es] (dangers_attack_debug__agentEid : EidList;
                     dangers_attack_debug__agentToDangers : IntList;
                     dangers_attack_debug__dangerEid : EidList;
                     dangers_attack_debug__dangerData : IPoint4List)
    for i in iter_range(dangers_attack_debug__agentEid)
      if dangers_attack_debug__agentEid[i] == agent_eid
        agentIdx = i
        break
    if agentIdx >= 0
      var tryDangerIdx = dangers_attack_debug__agentToDangers[agentIdx]
      while tryDangerIdx >= 0
        if dangers_attack_debug__dangerEid[tryDangerIdx] == danger_eid
          if over_danger_idx < 0 || over_danger_idx == tryDangerIdx
            out_danger_idx = tryDangerIdx
            over_danger_idx = tryDangerIdx
            return
        out_prev_danger_idx = tryDangerIdx
        tryDangerIdx = dangers_attack_debug__dangerData[tryDangerIdx].x
      if out_danger_idx < 0 && over_danger_idx >= 0
        out_danger_idx = debug_ai_attack_find_danger_in_analysis(agent_eid, danger_eid, over_danger_idx)
        out_prev_danger_idx = out_danger_idx
  if agentIdx < 0
    over_danger_idx = -1
  return agentIdx


def private debug_ai_attack_find_danger_in_analysis(agent_eid : EntityId; danger_eid : EntityId; var over_danger_idx : int&)
  var foundDangerIdx = -1
  query() <| $ [es] (dangers_attack_debug__analyzeAgents : IntList;
                     dangers_attack_debug__analyzeDangers : IntList;
                     dangers_attack_debug__agentEid : EidList;
                     dangers_attack_debug__dangerEid : EidList)
    for i in iter_range(dangers_attack_debug__analyzeAgents)
      let agentIdx = dangers_attack_debug__analyzeAgents[i]
      if dangers_attack_debug__agentEid[agentIdx] == agent_eid
        let dangerIdx = dangers_attack_debug__analyzeDangers[i]
        if dangers_attack_debug__dangerEid[dangerIdx] == danger_eid
          if over_danger_idx < 0 || over_danger_idx == dangerIdx
            foundDangerIdx = dangerIdx
            over_danger_idx = dangerIdx
            return
  return foundDangerIdx

def debug_ai_attack_move_danger_to_analyze(agent_idx : int; danger_idx : int; prev_danger_idx : int)
  var needMove = true
  query() <| $ [es] (dangers_attack_debug__dangerData : IPoint4List)
    let dngFlags = dangers_attack_debug__dangerData[danger_idx].y
    if (dngFlags & int(AIDangerFlags.IN_ANALYSIS)) != 0 || (dngFlags & int(AIDangerFlags.DONE_ANALYZE)) != 0
      needMove = false
  if !needMove
    return

  query() <| $ [es] (var dangers_attack_debug__analyzeTimes : FloatList&;
                     var dangers_attack_debug__analyzeAgents : IntList&;
                     var dangers_attack_debug__analyzeDangers : IntList&)
    let DELAY_BEFORE_ANALYZE = 30.0
    dangers_attack_debug__analyzeTimes |> push(get_sync_time() + DELAY_BEFORE_ANALYZE)
    dangers_attack_debug__analyzeAgents |> push(agent_idx)
    dangers_attack_debug__analyzeDangers |> push(danger_idx)

  query() <| $ [es] (var dangers_attack_debug__agentToDangers : IntList&;
                     var dangers_attack_debug__dangerData : IPoint4List&)
    let dngNext = dangers_attack_debug__dangerData[danger_idx].x
    dangers_attack_debug__dangerData[danger_idx].x = -1
    dangers_attack_debug__dangerData[danger_idx].y |= int(AIDangerFlags.IN_ANALYSIS)
    if prev_danger_idx >= 0
      dangers_attack_debug__dangerData[prev_danger_idx].x = dngNext
    else
      dangers_attack_debug__agentToDangers[agent_idx] = dngNext



def debug_ai_danger_update(agent_eid : EntityId; danger_eid : EntityId; traceable : bool; in_frustum : bool)
  query() <| $ [es] (var dangers_attack_debug__agentEid : EidList&;
                     var dangers_attack_debug__agentToDangers : IntList&;
                     var dangers_attack_debug__dangerEid : EidList&;
                     var dangers_attack_debug__dangerData : IPoint4List&)
    var dangerIdx = -1
    var prevDangerIdx = -1
    var noOverDangerIdx = -1
    var agentIdx = debug_ai_attack_find_agent_and_danger(agent_eid, danger_eid, dangerIdx, prevDangerIdx, noOverDangerIdx)

    assume agentsEids = dangers_attack_debug__agentEid
    assume agentsToDangers = dangers_attack_debug__agentToDangers
    assume dangersEids = dangers_attack_debug__dangerEid
    assume dangersData = dangers_attack_debug__dangerData

    if agentIdx < 0
      agentIdx = length(agentsEids)
      agentsEids |> push(agent_eid)
      agentsToDangers |> push(-1)

    var newFlags = 0
    if traceable
      newFlags |= int(AIDangerFlags.TRACEABLE)
    if in_frustum
      newFlags |= int(AIDangerFlags.INFRUSTUM)

    if dangerIdx < 0
      var dngType = -1
      if has(danger_eid, "human")
        dngType = 1
      elif has(danger_eid, "unit_tag__tank")
        dngType = 2
      elif has(danger_eid, "unit_tag__aircraft")
        dngType = 3
      elif has(danger_eid, "unit_tag__ship")
        dngType = 4
      elif has(danger_eid, "unit_tag__light_vehicle")
        dngType = 5

      dangerIdx = length(dangersEids)
      let dngNext = agentsToDangers[agentIdx]
      agentsToDangers[agentIdx] = dangerIdx
      dangersEids |> push(danger_eid)
      dangersData |> push(int4(dngNext, newFlags, -1, dngType))
      debug_ai_attack_add_event(AIDangerEvent.ADDED, newFlags, 0, agent_eid, danger_eid, dangersData[dangerIdx], dangerIdx)

    let oldFlags = dangersData[dangerIdx].y
    dangersData[dangerIdx].y = newFlags
    if oldFlags != newFlags
      let wasTraceable = (oldFlags & int(AIDangerFlags.TRACEABLE)) != 0
      if wasTraceable != traceable
        debug_ai_attack_add_event(AIDangerEvent.TRACEABLE, traceable ? 1 : 0, 0, agent_eid, danger_eid, dangersData[dangerIdx], dangerIdx)
      let wasInFrustum = (oldFlags & int(AIDangerFlags.INFRUSTUM)) != 0
      if wasInFrustum != in_frustum
        debug_ai_attack_add_event(AIDangerEvent.INFRUSTUM, in_frustum ? 1 : 0, 0, agent_eid, danger_eid, dangersData[dangerIdx], dangerIdx)

def debug_ai_danger_lost(agent_eid : EntityId; danger_eid : EntityId; lost_code : int)
  var dangerIdx = -1
  var prevDangerIdx = -1
  var noOverDangerIdx = -1
  let agentIdx = debug_ai_attack_find_agent_and_danger(agent_eid, danger_eid, dangerIdx, prevDangerIdx, noOverDangerIdx)
  if agentIdx >= 0 && dangerIdx >= 0
    debug_ai_attack_add_event(AIDangerEvent.LOST, lost_code, 0, agent_eid, danger_eid, dangerIdx)
    debug_ai_attack_move_danger_to_analyze(agentIdx, dangerIdx, prevDangerIdx)


def debug_ai_danger_add_dsym(agent_eid : EntityId; sym1 : int; sym2 : int)
  let agentIdx = debug_ai_attack_find_agent(agent_eid)
  if agentIdx >= 0
    query() <| $ [es] (dangers_attack_debug__agentToDangers : IntList;
                       dangers_attack_debug__dangerEid : EidList;
                       dangers_attack_debug__dangerData : IPoint4List)
      var dangerIdx = dangers_attack_debug__agentToDangers[agentIdx]
      while dangerIdx >= 0
        let dangerEid = dangers_attack_debug__dangerEid[dangerIdx]
        debug_ai_attack_add_event(AIDangerEvent.ACTION_DSYM, sym1, sym2, agent_eid, dangerEid, dangerIdx)
        dangerIdx = dangers_attack_debug__dangerData[dangerIdx].x


def debug_ai_danger_got_danger(agent_eid : EntityId; danger_eid : EntityId; var over_danger_idx : int&; kind_code : int)
  var dangerIdx = -1
  var prevDangerIdx = -1
  let agentIdx = debug_ai_attack_find_agent_and_danger(agent_eid, danger_eid, dangerIdx, prevDangerIdx, over_danger_idx)
  if agentIdx >= 0 && dangerIdx >= 0
    debug_ai_attack_add_event(AIDangerEvent.GOT_DANGER, kind_code, 0, agent_eid, danger_eid, dangerIdx)

def debug_ai_danger_rejected(agent_eid : EntityId; danger_eid : EntityId; var over_danger_idx : int&; kind_code : int)
  var dangerIdx = -1
  var prevDangerIdx = -1
  let agentIdx = debug_ai_attack_find_agent_and_danger(agent_eid, danger_eid, dangerIdx, prevDangerIdx, over_danger_idx)
  if agentIdx >= 0 && dangerIdx >= 0
    debug_ai_attack_add_event(AIDangerEvent.REJECTED, kind_code, 0, agent_eid, danger_eid, dangerIdx)



  
  
  
  
    


  
  
  
  
    


def debug_ai_danger_attack_begin(agent_eid : EntityId; danger_eid : EntityId; var over_danger_idx : int&; kind_code : int)
  var dangerIdx = -1
  var prevDangerIdx = -1
  let agentIdx = debug_ai_attack_find_agent_and_danger(agent_eid, danger_eid, dangerIdx, prevDangerIdx, over_danger_idx)
  if agentIdx >= 0 && dangerIdx >= 0
    debug_ai_attack_add_event(AIDangerEvent.A_BEGIN, kind_code, 0, agent_eid, danger_eid, dangerIdx)

def debug_ai_danger_attack_other(agent_eid : EntityId; danger_eid : EntityId; var over_danger_idx : int&; kind_code : int; other_code : int)
  var dangerIdx = -1
  var prevDangerIdx = -1
  let agentIdx = debug_ai_attack_find_agent_and_danger(agent_eid, danger_eid, dangerIdx, prevDangerIdx, over_danger_idx)
  if agentIdx >= 0 && dangerIdx >= 0
    debug_ai_attack_add_event(AIDangerEvent.A_OTHER, kind_code, other_code, agent_eid, danger_eid, dangerIdx)

def debug_ai_danger_attack_attack(agent_eid : EntityId; danger_eid : EntityId; var over_danger_idx : int&; melee : bool; kind_code : int)
  var dangerIdx = -1
  var prevDangerIdx = -1
  let agentIdx = debug_ai_attack_find_agent_and_danger(agent_eid, danger_eid, dangerIdx, prevDangerIdx, over_danger_idx)
  if agentIdx >= 0 && dangerIdx >= 0
    let evType = melee ? AIDangerEvent.A_MELEE : AIDangerEvent.A_SHOOT
    debug_ai_attack_add_event(evType, kind_code, 0, agent_eid, danger_eid, dangerIdx)
    debug_ai_attack_move_danger_to_analyze(agentIdx, dangerIdx, prevDangerIdx)

def debug_ai_danger_attack_success(agent_eid : EntityId; danger_eid : EntityId; var over_danger_idx : int&; kind_code : int)
  let dangerIdx = debug_ai_attack_find_danger_in_analysis(agent_eid, danger_eid, over_danger_idx)
  if dangerIdx >= 0
    debug_ai_attack_add_event(AIDangerEvent.A_SUCCESS, kind_code, 0, agent_eid, danger_eid, dangerIdx)
