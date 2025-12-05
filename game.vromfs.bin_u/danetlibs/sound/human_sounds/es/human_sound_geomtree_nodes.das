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
                                    var human_sound_geomtree_nodes__headNodeId : int&)
  if !empty(human_sound_geomtree_nodes__headNodeName)
    human_sound_geomtree_nodes__headNodeId = geomtree_findNodeIndex(*animchar.nodeTree, human_sound_geomtree_nodes__headNodeName)
    if human_sound_geomtree_nodes__headNodeId == -1
      logerr("Geomtree node '{human_sound_geomtree_nodes__headNodeName}' for entity '{getEntityTemplateName(eid)}' not found (human sound related)")
