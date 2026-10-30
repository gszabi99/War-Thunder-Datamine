require ecs
require app
require strings
require AnimV20
require DagorSystem
require GeomNodeTree


[es(tag=sound, on_appear)]
def human_sound_geomtree_nodes_init(evt : Event;
                                    eid : EntityId;
                                    animchar : AnimcharBaseComponent;
                                    human_sound_geomtree_nodes__headNodeName : string;
                                    var human_sound_geomtree_nodes__headNodeId : int&;
                                    human_sound_geomtree_nodes__pelvisNodeName : string;
                                    var human_sound_geomtree_nodes__pelvisNodeId : int&;
                                    human_sound_geomtree_nodes__meleeNodeName : string;
                                    var human_sound_geomtree_nodes__meleeNodeId : int&)
  if !empty(human_sound_geomtree_nodes__headNodeName)
    human_sound_geomtree_nodes__headNodeId = geomtree_findNodeIndex(*animchar.nodeTree, human_sound_geomtree_nodes__headNodeName)
    if human_sound_geomtree_nodes__headNodeId == -1
      logerr("Geomtree node '{human_sound_geomtree_nodes__headNodeName}' for entity '{getEntityTemplateName(eid)}' not found (human sound related)")
  if !empty(human_sound_geomtree_nodes__pelvisNodeName)
    human_sound_geomtree_nodes__pelvisNodeId = geomtree_findNodeIndex(*animchar.nodeTree, human_sound_geomtree_nodes__pelvisNodeName)
    if human_sound_geomtree_nodes__pelvisNodeId == -1
      logerr("Geomtree node '{human_sound_geomtree_nodes__pelvisNodeName}' for entity '{getEntityTemplateName(eid)}' not found (human sound related)")
  if !empty(human_sound_geomtree_nodes__meleeNodeName)
    human_sound_geomtree_nodes__meleeNodeId = geomtree_findNodeIndex(*animchar.nodeTree, human_sound_geomtree_nodes__meleeNodeName)
    if human_sound_geomtree_nodes__meleeNodeId == -1
      logerr("Geomtree node '{human_sound_geomtree_nodes__meleeNodeName}' for entity '{getEntityTemplateName(eid)}' not found (human sound related)")
