options always_export_initializer = true

require app
require ecs
require math.base
require BehNodes
require DagorDataBlock

[beh_node(name="isSquadFollowingAutoRoute")]
class IsSquadFollowingAutoRoute : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (squad__autoRouteIdx : int)
        if squad__autoRouteIdx >= 0
          res = EBehResult.ER_SUCCESS
    return res

[beh_node(name="isSquadLeaderFollowingAutoRoute")]
class IsSquadLeaderFollowingAutoRoute : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId; squad__autoRouteIdx : int)
        if agentEid == squad__leader && squad__autoRouteIdx >= 0
          res = EBehResult.ER_SUCCESS
    return res

[beh_node(name="tryFollowSquadAutoRoute")]
class TryFollowSquadAutoRoute : BehNodeAdapter
  outPosParam : int = -1
  reachDist : float = 10.0

  def override loadFromBlk(data : DataBlock) : void
    outPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3())
    reachDist = data |> datablock_getReal("reachDist", reachDist)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId; transform : float3x4)
      let ourPos = transform[3]
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId;
                                            var squad__autoRouteIdx : int&;
                                            var squad__autoRoutePos : int&;
                                            var squad__autoRouteEid : EntityId&;
                                            var squad__autoRouteTime : float&)
        if squad__autoRouteIdx < 0
          return
        query(squad__autoRouteEid) <| $ [es] (team__autoRouteBotSquads : Array)
          if squad__autoRouteIdx < 0 || squad__autoRouteIdx >= length(team__autoRouteBotSquads)
            return
          let routeObj = get_ecs_object(team__autoRouteBotSquads[squad__autoRouteIdx])
          if routeObj == null
            return
          let points = get_ecs_array(routeObj, "points")
          if points == null
            return
          let len = length(*points)
          if len <= 0 || squad__autoRoutePos < 0 || squad__autoRoutePos >= len
            return
          let pt = get_Point4((*points)[squad__autoRoutePos])
          if pt == null
            return

          let reachPos = (*pt).xyz
          let waitTime = (*pt).w

          if agentEid == squad__leader
            if squad__autoRouteTime < 0.0
              if distance_sq(ourPos, reachPos) < square(reachDist)
                squad__autoRouteTime = get_sync_time() + max(0.0, waitTime)
            elif get_sync_time() >= squad__autoRouteTime
              squad__autoRoutePos += 1
              squad__autoRouteTime = -1.0

          owner.blackBoard |> set(outPosParam, reachPos)
          res = EBehResult.ER_SUCCESS
        if res != EBehResult.ER_SUCCESS
          squad__autoRouteIdx = -1
          squad__autoRouteEid = INVALID_ENTITY_ID
    return res
