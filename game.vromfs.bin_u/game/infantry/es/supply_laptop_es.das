require ecs
require Mission


def private zone_team(active : bool; owning_team : int) : int
  return active ? owning_team : -1

[es(tag=server, on_appear, REQUIRE=supplyLaptop)]
def supply_laptop_link_es(evt : Event;
                          eid aka laptop_eid : EntityId;
                          transform : float3x4;
                          var supply_laptop__nodeEid : EntityId&;
                          var supply_laptop__team : int&)
  let pos = transform[3].xz
  find_query() <| $ [es] (eid aka node_eid : EntityId;
                          supply_graph__name : string;
                          var supply_graph__laptopEids : EidList&;
                          team : int const?;
                          active : bool = false;
                          capzone__owningTeam : int = -1)
    let areaId = get_area_id(supply_graph__name)
    if areaId < 0 || !is_in_area(areaId, pos)
      return false
    supply_laptop__nodeEid = node_eid
    supply_laptop__team = team ?? zone_team(active, capzone__owningTeam)
    push(supply_graph__laptopEids, laptop_eid)
    return true

[es(tag=server, on_appear)]
def supply_graph_node_link_laptops_es(evt : Event;
                                      eid aka node_eid : EntityId;
                                      supply_graph__name : string;
                                      var supply_graph__laptopEids : EidList&;
                                      team : int const?;
                                      active : bool = false;
                                      capzone__owningTeam : int = -1)
  let areaId = get_area_id(supply_graph__name)
  if areaId < 0
    return
  let nodeTeam = team ?? zone_team(active, capzone__owningTeam)
  query() <| $ [es(REQUIRE=supplyLaptop)] (eid aka laptop_eid : EntityId;
                                           transform : float3x4;
                                           var supply_laptop__nodeEid : EntityId&;
                                           var supply_laptop__team : int&)
    let pos = transform[3].xz
    if supply_laptop__nodeEid != INVALID_ENTITY_ID || !is_in_area(areaId, pos)
      return
    supply_laptop__nodeEid = node_eid
    supply_laptop__team = nodeTeam
    push(supply_graph__laptopEids, laptop_eid)

[es(tag=server, track=(active, capzone__owningTeam))]
def supply_node_laptops_team_es(evt : Event;
                                active : bool;
                                capzone__owningTeam : int;
                                supply_graph__laptopEids : EidList)
  let nodeTeam = zone_team(active, capzone__owningTeam)
  for laptopEid in supply_graph__laptopEids
    query(laptopEid) <| $ [es] (var supply_laptop__team : int&)
      supply_laptop__team = nodeTeam
