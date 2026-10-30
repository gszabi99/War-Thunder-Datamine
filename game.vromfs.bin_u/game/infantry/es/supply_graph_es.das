require ecs
require math
require DagorSystem

def private find_supply_graph_node(name : string) : EntityId
  var found = INVALID_ENTITY_ID
  find_query() <| $ [es] (eid : EntityId; supply_graph__name : string)
    if supply_graph__name != name
      return false
    found = eid
    return true
  return found

def private add_supply_graph_link(from_eid : EntityId; to_eid : EntityId)
  query(from_eid) <| $ [es] (var supply_graph__linkedEids : EidList&)
    if !has_value(supply_graph__linkedEids, to_eid)
      push(supply_graph__linkedEids, to_eid)

def private link_supply_graph_nodes(a_eid : EntityId; b_eid : EntityId)
  if a_eid == b_eid || b_eid == INVALID_ENTITY_ID
    return
  add_supply_graph_link(a_eid, b_eid)
  add_supply_graph_link(b_eid, a_eid)

[es(tag=server, on_appear)]
def supply_graph_node_appear_es(evt : Event;
                                eid : EntityId;
                                supply_graph__name : string;
                                supply_graph__linkNames : StringList)
  let nodeEid = eid
  let nodeName = supply_graph__name
  for linkName in supply_graph__linkNames
    link_supply_graph_nodes(nodeEid, find_supply_graph_node(string(linkName)))
  var linkedBy : array<EntityId>
  query() <| $ [es] (eid aka other_eid : EntityId;
                     supply_graph__linkNames aka other_supply_graph__linkNames : StringList)
    if other_eid == nodeEid
      return
    for linkName in other_supply_graph__linkNames
      if string(linkName) == nodeName
        push(linkedBy, other_eid)
        return
  for otherEid in linkedBy
    link_supply_graph_nodes(nodeEid, otherEid)

[es(tag=server, on_appear, REQUIRE=supplyBase)]
def supply_base_appear_es(evt : Event;
                          eid : EntityId;
                          team : int;
                          supply_graph__name : string)
  let baseEid = eid
  let baseTeam = team
  let baseName = supply_graph__name
  find_query() <| $ [es(REQUIRE=supplyBase)] (eid aka other_eid : EntityId;
                                              team aka other_team : int;
                                              supply_graph__name aka other_supply_graph__name : string)
    if other_eid == baseEid || other_team != baseTeam
      return false
    logerr("supply base '{baseName}': team {baseTeam} already has supply base '{other_supply_graph__name}'")
    destroyEntity(baseEid)
    return true

def private add_supplies(base_eid : EntityId; team : int; dt : float)
  var visited : table<EntityId; bool>
  var stack : array<EntityId>
  visited[base_eid] = true
  query(base_eid) <| $ [es] (supply_graph__linkedEids : EidList)
    for linkedEid in supply_graph__linkedEids
      push(stack, linkedEid)
  while length(stack) > 0
    let nodeEid = back(stack)
    pop(stack)
    if visited?[nodeEid] ?? false
      continue
    visited[nodeEid] = true
    query(nodeEid) <| $ [es] (active : bool;
                              capzone__owningTeam : int;
                              supply_graph__linkedEids : EidList;
                              supply_node__maxPoints : float;
                              supply_node__pointsPerMinute : float;
                              var supply_node__points : float&)
      if !active || capzone__owningTeam != team
        return
      supply_node__points = min(supply_node__points + supply_node__pointsPerMinute * dt / 60.0, supply_node__maxPoints)
      for linkedEid in supply_graph__linkedEids
        if !(visited?[linkedEid] ?? false)
          push(stack, linkedEid)

[es(tag=server, no_order, REQUIRE=supplyBase)]
def supply_base_update_es(info : UpdateStageInfoAct;
                          eid : EntityId;
                          team : int;
                          supply_base__updatePeriod : float;
                          var supply_base__nextUpdateAt : float&)
  if supply_base__nextUpdateAt < 0.0
    supply_base__nextUpdateAt = info.curTime + supply_base__updatePeriod
    return
  if info.curTime < supply_base__nextUpdateAt
    return
  supply_base__nextUpdateAt += supply_base__updatePeriod
  add_supplies(eid, team, supply_base__updatePeriod)

[es(tag=server, on_event=EventMissionUnload, REQUIRE=supplyBase)]
def supply_base_mission_unload(evt : Event; eid : EntityId)
  destroyEntity(eid)
