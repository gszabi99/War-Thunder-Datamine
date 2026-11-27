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

def private update_supply_base_links(base_eid : EntityId; team : int)
  var linked : table<EntityId; bool>
  var stack : array<EntityId>
  linked[base_eid] = true
  query(base_eid) <| $ [es] (supply_graph__linkedEids : EidList)
    for linkedEid in supply_graph__linkedEids
      push(stack, linkedEid)
  while length(stack) > 0
    let nodeEid = back(stack)
    pop(stack)
    if key_exists(linked, nodeEid)
      continue
    linked[nodeEid] = false
    query(nodeEid) <| $ [es] (active : bool;
                              capzone__owningTeam : int;
                              supply_graph__linkedEids : EidList)
      if !active || capzone__owningTeam != team
        return
      linked[nodeEid] = true
      for linkedEid in supply_graph__linkedEids
        if !key_exists(linked, linkedEid)
          push(stack, linkedEid)
  query() <| $ [es] (eid : EntityId;
                     capzone__owningTeam : int;
                     var supply_node__hasBaseLink : bool&)
    if capzone__owningTeam == team
      supply_node__hasBaseLink = linked?[eid] ?? false

[es(tag=server, on_appear, REQUIRE=supplyBase, after=supply_graph_node_appear_es)]
def supply_base_link_es(evt : Event; eid : EntityId; team : int)
  update_supply_base_links(eid, team)

[es(tag=server, on_appear, track=(capzone__owningTeam, active), REQUIRE=(capzone__owningTeam, active), after=supply_graph_node_appear_es)]
def supply_node_base_link_es(evt : Event; var supply_node__hasBaseLink : bool&)
  supply_node__hasBaseLink = false
  query() <| $ [es(REQUIRE=supplyBase)] (eid : EntityId; team : int)
    update_supply_base_links(eid, team)

def private add_supplies(team : int; dt : float)
  query() <| $ [es] (capzone__owningTeam : int;
                     supply_node__hasBaseLink : bool;
                     supply_node__maxPoints : int;
                     supply_node__pointsPerMinute : int;
                     var supply_node__pointsCarry : float&;
                     var supply_node__points : int&)
    if !supply_node__hasBaseLink || capzone__owningTeam != team
      return
    supply_node__pointsCarry += float(supply_node__pointsPerMinute) * dt / 60.0
    let gain = int(supply_node__pointsCarry)
    supply_node__pointsCarry -= float(gain)
    supply_node__points = min(supply_node__points + gain, supply_node__maxPoints)

[es(tag=server, no_order, REQUIRE=supplyBase)]
def supply_base_update_es(info : UpdateStageInfoAct;
                          team : int;
                          supply_base__updatePeriod : float;
                          var supply_base__nextUpdateAt : float&)
  if supply_base__nextUpdateAt < 0.0
    supply_base__nextUpdateAt = info.curTime + supply_base__updatePeriod
    return
  if info.curTime < supply_base__nextUpdateAt
    return
  supply_base__nextUpdateAt += supply_base__updatePeriod
  add_supplies(team, supply_base__updatePeriod)

[es(tag=server, on_event=EventMissionUnload, REQUIRE=supplyBase)]
def supply_base_mission_unload(evt : Event; eid : EntityId)
  destroyEntity(eid)
