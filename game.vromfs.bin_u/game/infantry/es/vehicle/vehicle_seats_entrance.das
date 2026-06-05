require ecs
require ecs.common
require GeomNodeTree
require Unit

[es(tag=server, on_appear)]
def init_entracne_node(evt : Event;
                       seat__id : int;
                       seat__vehicleEid : EntityId;
                       var seat__entranceNodeId : int&)
  query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array;
                                     unit__ref : UnitRef)
    let seat = get_ecs_object(vehicle_seats__seats, seat__id)
    if seat == null
      return

    let entranceNode = get_string(*seat, "entranceNode", "")
    if entranceNode == ""
      return

    let tree = get_entity_geom_node_tree(unit__ref, null)
    if tree == null
      return

    seat__entranceNodeId = geomtree_findNodeIndex(*tree, entranceNode)
