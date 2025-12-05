require ecs
require app
require %appGame.infantry.es.ai_dangers_attack_debug_common
require DagorMath
require DagorMathUtils
require strings


def private debug_ai_dangers_analyze(agent_idx : int; danger_idx : int)
  query() <| $ [es] (dangers_attack_debug__agentEid : EidList;
                     dangers_attack_debug__dangerEid : EidList;
                     var dangers_attack_debug__dangerData : IPoint4List&;
                     dangers_attack_debug__eventData : IPoint4List;
                     dangers_attack_debug__eventVec1 : Point4List;
                     dangers_attack_debug__eventVec2 : Point4List;
                     dangers_attack_debug__eventDSym : IPoint4List)
    let agentEid = dangers_attack_debug__agentEid[agent_idx]
    let dangerEid = dangers_attack_debug__dangerEid[danger_idx]
    let dngEvLast = dangers_attack_debug__dangerData[danger_idx].z
    let dngType = dangers_attack_debug__dangerData[danger_idx].w

    dangers_attack_debug__dangerData[danger_idx].y |= int(AIDangerFlags.DONE_ANALYZE)

    var evIdx = dngEvLast
    var numEvents = 0
    while evIdx >= 0
      ++numEvents
      evIdx = dangers_attack_debug__eventData[evIdx].x

    var evts : array<int>
    evts |> resize(numEvents)

    evIdx = dngEvLast
    var evAt = numEvents - 1
    while evIdx >= 0
      evts[evAt--] = evIdx
      evIdx = dangers_attack_debug__eventData[evIdx].x

    var addedIdx = -1
    var tracedIdx = -1
    var lastNonTracedTime = -1.0
    var lastTracedTime = -1.0
    var lastTraceable = false
    var lastInFrustum = false
    var lastTr = 0
    var lastInF = 0

    var gotIdx = -1
    var begIdx = -1
    var begAdd = 0.0
    var atkIdx = -1
    var sucIdx = -1

    var printDanger = false
    var printDSyms = float2(-1.0, -1.0)
    var printStack = false
    var stackAt = -1

    for idx in evts
      let evType = dangers_attack_debug__eventData[idx].y
      let evN1 = dangers_attack_debug__eventData[idx].z
      
      
      let evTime = dangers_attack_debug__eventVec1[idx].w
      
      
      
      
      
      

      

      if evType == int(AIDangerEvent.ADDED)
        lastInFrustum = (evN1 & int(AIDangerFlags.INFRUSTUM)) != 0
        lastTraceable = (evN1 & int(AIDangerFlags.TRACEABLE)) != 0
        lastNonTracedTime = !lastTraceable ? evTime : -1.0
        lastTracedTime = lastTraceable ? evTime : -1.0
        lastTr = lastTraceable ? 1 : 0
        lastInF = lastInFrustum ? 1 : 0
        if addedIdx < 0
          addedIdx = idx
      elif evType == int(AIDangerEvent.TRACEABLE)
        lastTraceable = evN1 > 0
        lastTr = lastTraceable ? 1 : 0
        if lastTraceable
          lastTracedTime = evTime
        else
          lastNonTracedTime = evTime
        if tracedIdx < 0 && lastTraceable
          tracedIdx = idx
          
          
          
          
          
          
          
      elif evType == int(AIDangerEvent.INFRUSTUM)
        lastInFrustum = evN1 > 0
        lastInF = lastInFrustum ? 1 : 0
      elif evType == int(AIDangerEvent.GOT_DANGER)
        let MAX_DIST_NEAR = 10.0
        let MIN_DIST_TOOFAR = 100.0
        let MAX_TIME_FIND_NEAR = 2.0
        let MAX_TIME_FIND_FAR = 3.5
        let MAX_TIME_FIND_TOOFAR = 10.0

        let agentPos = dangers_attack_debug__eventVec2[idx].xyz
        let dangerPos = dangers_attack_debug__eventVec1[idx].xyz
        let dist = distance(agentPos, dangerPos)
        let maxTimeFind = dist < MAX_DIST_NEAR ? MAX_TIME_FIND_NEAR : dist < MIN_DIST_TOOFAR ? cvt(dist, MAX_DIST_NEAR, MIN_DIST_TOOFAR, MAX_TIME_FIND_FAR, MAX_TIME_FIND_TOOFAR) : MAX_TIME_FIND_TOOFAR

        if lastTracedTime >= 0.0
          let timeFind = evTime - lastTracedTime
          if timeFind > maxTimeFind
            error("!!! DANGER FOUND+ T={timeFind} evTime={evTime} kindCode={evN1} T{lastTr} F{lastInF} dist={dist}")
            if !printDanger
              printDanger = true; printDSyms = float2(lastTracedTime, evTime)
        elif lastNonTracedTime >= 0.0
          let timeFind = evTime - lastNonTracedTime
          if timeFind > maxTimeFind
            error("!!! DANGER FOUND- T={timeFind} evTime={evTime} kindCode={evN1} T{lastTr} F{lastInF} dist={dist}")
            if !printDanger
              printDanger = true; printDSyms = float2(lastNonTracedTime, evTime)
        else
          error("!!! DANGER FOUND??? [non_traceable] evTime={evTime} kindCode={evN1} T{lastTr} F{lastInF} dist={dist}")
          printDanger = true
          if !printStack
            printStack = true; stackAt = idx
        gotIdx = idx
        begIdx = -1; begAdd = 0.0; atkIdx = -1; sucIdx = -1
      elif evType == int(AIDangerEvent.A_BEGIN)
        if gotIdx < 0
          error("???????? A_BEGIN without GOT_DANGER evTime={evTime} kindCode={dangers_attack_debug__eventData[idx].z}")
          if !printStack
            printStack = true; stackAt = idx
          gotIdx = -1; begIdx = -1; begAdd = 0.0; atkIdx = -1; sucIdx = -1
        else
          begIdx = idx
          begAdd = 0.0
          atkIdx = -1; sucIdx = -1
          let gotTime = dangers_attack_debug__eventVec1[gotIdx].w
          let begTime = dangers_attack_debug__eventVec1[begIdx].w
          let timeBeg = begTime - gotTime
          if timeBeg > 1.0
            error("!!! DANGER ->BEGIN T={timeBeg} evTime={evTime} kindCode={dangers_attack_debug__eventData[idx].z} T{lastTr} F{lastInF}")
            if !printDanger
              printDanger = true; printDSyms = float2(gotTime, begTime)
      elif evType == int(AIDangerEvent.A_SHOOT) || evType == int(AIDangerEvent.A_MELEE)
        if gotIdx < 0
          error("???????? A_SHOOT/A_MELEE without GOT_DANGER evTime={evTime} kindCode={dangers_attack_debug__eventData[idx].z}")
          if !printStack
            printStack = true; stackAt = idx
          gotIdx = -1; begIdx = -1; begAdd = 0.0; atkIdx = -1; sucIdx = -1
        else
          atkIdx = idx
          sucIdx = -1
          let begTime = dangers_attack_debug__eventVec1[begIdx].w + begAdd
          let atkTime = dangers_attack_debug__eventVec1[atkIdx].w
          begIdx = idx 
          begAdd = evType == int(AIDangerEvent.A_SHOOT) ? 3.0 : 1.0 
          let timeRdy = atkTime - begTime
          if timeRdy > 2.5
            error("!!! DANGER ->SHOOT T={timeRdy} evTime={evTime} kindCode={dangers_attack_debug__eventData[idx].z} T{lastTr} F{lastInF}")
            if !printDanger
              printDanger = true; printDSyms = float2(begTime, atkTime)
      elif evType == int(AIDangerEvent.A_SUCCESS)
        if atkIdx < 0
          error("???????? A_SUCCESS without A_SHOOT/A_MELEE evTime={evTime} kindCode={dangers_attack_debug__eventData[idx].z}")
          if !printStack
            printStack = true; stackAt = idx
          atkIdx = -1; sucIdx = -1
        else
          sucIdx = idx
          let atkTime = dangers_attack_debug__eventVec1[atkIdx].w
          let sucTime = dangers_attack_debug__eventVec1[sucIdx].w
          let timeAtk = sucTime - atkTime
          if timeAtk > 4.0
            error("!!! DANGER +ATTACK T={timeAtk} evTime={evTime} kindCode={dangers_attack_debug__eventData[idx].z} T{lastTr} F{lastInF}")
            if !printDanger
              printDanger = true
              printDSyms = float2(atkTime, sucTime)
          atkIdx = -1
          sucIdx = -1

    if printDanger || printStack
      error("!!! DANGER >>> agent_idx={agent_idx} danger_idx={danger_idx} agentEid={agentEid} dangerEid={dangerEid} dngEvLast={dngEvLast} numEvents={numEvents} dngType={dngType}")
      if printDSyms.x >= 0.0
        var numDangersT = 0
        var numDangersTF = 0
        query() <| $ [es] (dangers_attack_debug__agentToDangers : IntList)
          var dIdx = dangers_attack_debug__agentToDangers[agent_idx]
          while dIdx >= 0
            let dngFlags = dangers_attack_debug__dangerData[dIdx].y
            if (dngFlags & int(AIDangerFlags.TRACEABLE)) != 0
              ++numDangersT
              if (dngFlags & int(AIDangerFlags.INFRUSTUM)) != 0
                ++numDangersTF
            dIdx = dangers_attack_debug__dangerData[dIdx].x

        error("!DSYMS BEGIN! timeFrom={printDSyms.x} timeTo={printDSyms.y} numDangersT={numDangersT} numDangersTF={numDangersTF}")
        var isTr = 0
        var inFr = 0
        for idx in evts
          let evType = dangers_attack_debug__eventData[idx].y
          let evTime = dangers_attack_debug__eventVec1[idx].w
          let evN1 = dangers_attack_debug__eventData[idx].z
          let evN2 = dangers_attack_debug__eventData[idx].w
          if evType == int(AIDangerEvent.ADDED)
            isTr = (evN1 & int(AIDangerFlags.TRACEABLE)) != 0 ? 1 : 0
            inFr = (evN1 & int(AIDangerFlags.INFRUSTUM)) != 0 ? 1 : 0
          elif evType == int(AIDangerEvent.TRACEABLE)
            isTr = evN1 > 0 ? 1 : 0
          elif evType == int(AIDangerEvent.INFRUSTUM)
            inFr = evN1 > 0 ? 1 : 0
          let timeAround = 3.5
          if evTime >= printDSyms.x - timeAround && evTime <= printDSyms.y + timeAround
            let agentAct = dangers_attack_debug__eventDSym[idx].y
            let agentActID = dangers_attack_debug__eventDSym[idx].z
            let agentPos = dangers_attack_debug__eventVec2[idx].xyz
            let dangerPos = dangers_attack_debug__eventVec1[idx].xyz
            let dist = distance(agentPos, dangerPos)
            if evType == int(AIDangerEvent.ACTION_DSYM)
              if evN1 > 0
                error("!DSYM! idx={idx} evTime={evTime} ACTION={to_char(evN1)}{evN2} wasAct={to_char(agentAct)}{agentActID} T{isTr} F{inFr} dist={dist}")
              else
                error("!DSYM! idx={idx} evTime={evTime} REACTION={evN2} wasAct={to_char(agentAct)}{agentActID} T{isTr} F{inFr} dist={dist}")
            else
              error("!DSYM! idx={idx} evType={evType} evTime={evTime} evN1={evN1} evN2={evN2} act={to_char(agentAct)}{agentActID} T{isTr} F{inFr} dist={dist}")
        error("!DSYMS END!")

    if printStack
      let agentAct = dangers_attack_debug__eventDSym[stackAt].y
      let agentActID = dangers_attack_debug__eventDSym[stackAt].z
      error("!STACK BEGIN! stackAt={stackAt} act={to_char(agentAct)}{agentActID}")
      for idx in evts
        let evType = dangers_attack_debug__eventData[idx].y
        let evTime = dangers_attack_debug__eventVec1[idx].w
        error("!STACK! idx={idx} evType={evType} evTime={evTime}") 
      error("!STACK END!")

      error("!ALIKES! agentEid={agentEid} dangerEid={dangerEid}")
      query() <| $ [es] (dangers_attack_debug__agentToDangers : IntList;
                         dangers_attack_debug__doneDangers : IPoint2List;
                         dangers_attack_debug__analyzeAgents : IntList;
                         dangers_attack_debug__analyzeDangers : IntList)
        var alikes : array<int>
        for agentDanger in dangers_attack_debug__doneDangers
          if agentDanger.x == agent_idx 
            error("!ALIKE DONE! dangerIdx={agentDanger.y} dangerEid={dangers_attack_debug__dangerEid[agentDanger.y]}")
            alikes |> push(agentDanger.y)
        for analyzeIdx in iter_range(dangers_attack_debug__analyzeAgents)
          let analyzeDangerIdx = dangers_attack_debug__analyzeDangers[analyzeIdx]
          if dangers_attack_debug__analyzeAgents[analyzeIdx] == agent_idx 
            error("!ALIKE ANLZ! dangerIdx={analyzeDangerIdx} dangerEid={dangers_attack_debug__dangerEid[analyzeDangerIdx]}")
            alikes |> push(analyzeDangerIdx)
        var thatDangerIdx = dangers_attack_debug__agentToDangers[agent_idx]
        while thatDangerIdx >= 0
          if dangerEid == dangers_attack_debug__dangerEid[thatDangerIdx]
            error("!ALIKE CURR! dangerIdx={thatDangerIdx} dangerEid={dangerEid}")
            alikes |> push(thatDangerIdx)
          thatDangerIdx = dangers_attack_debug__dangerData[thatDangerIdx].x
        for alike in alikes
          var alikeEvIdx = dangers_attack_debug__dangerData[alike].z
          var evStr = ""
          while alikeEvIdx >= 0
            let alikeEvType = dangers_attack_debug__eventData[alikeEvIdx].y
            let alikeEvN1 = dangers_attack_debug__eventData[alikeEvIdx].z
            let alikeEvTime = dangers_attack_debug__eventVec1[alikeEvIdx].w
            if alikeEvType == int(AIDangerEvent.TRACEABLE) || alikeEvType == int(AIDangerEvent.INFRUSTUM)
              if alikeEvN1 > 0
                evStr = "[{alikeEvTime}]{alikeEvType}+ {evStr}"
              else
                evStr = "[{alikeEvTime}]{alikeEvType}- {evStr}"
            else
              evStr = "[{alikeEvTime}]{alikeEvType}:{alikeEvN1} {evStr}"
            alikeEvIdx = dangers_attack_debug__eventData[alikeEvIdx].x
          error("!!! ALIKE {alike} EVENTS: {evStr}")
        error("!ALIKES END! num={length(alikes)}")


[es(tag=server, on_disappear, REQUIRE=transform)]
def debug_ai_dangers_disappear_es(evt : Event; eid aka agent_eid : EntityId)
  let agentIdx = debug_ai_attack_find_agent(agent_eid)
  if agentIdx < 0
    return
  query() <| $ [es] (dangers_attack_debug__agentToDangers : IntList;
                     dangers_attack_debug__dangerData : IPoint4List)
    assume dangersData =  dangers_attack_debug__dangerData
    var dangerIdx = dangers_attack_debug__agentToDangers[agentIdx]
    let prevDangerIdx = -1 
    while dangerIdx >= 0
      let nextDangerIdx = dangersData[dangerIdx].x
      
      debug_ai_attack_move_danger_to_analyze(agentIdx, dangerIdx, prevDangerIdx)
      dangerIdx = nextDangerIdx


[es(tag=server, no_order)]
def debug_ai_dangers_update_es(act : UpdateStageInfoAct;
                               var dangers_attack_debug__analyzeTimes : FloatList&;
                               var dangers_attack_debug__analyzeAgents : IntList&;
                               var dangers_attack_debug__analyzeDangers : IntList&;
                               var dangers_attack_debug__doneDangers : IPoint2List&)
  var analyzeIdx = 0
  let curTime = get_sync_time()
  while analyzeIdx < length(dangers_attack_debug__analyzeTimes)
    if curTime < dangers_attack_debug__analyzeTimes[analyzeIdx]
      ++analyzeIdx
      continue
    let agentIdx = dangers_attack_debug__analyzeAgents[analyzeIdx]
    let dangerIdx = dangers_attack_debug__analyzeDangers[analyzeIdx]
    dangers_attack_debug__doneDangers |> push(int2(agentIdx, dangerIdx))
    dangers_attack_debug__analyzeTimes |> erase(analyzeIdx)
    dangers_attack_debug__analyzeAgents |> erase(analyzeIdx)
    dangers_attack_debug__analyzeDangers |> erase(analyzeIdx)
    
    if agentIdx >= 0 && dangerIdx >= 0
      debug_ai_dangers_analyze(agentIdx, dangerIdx)
