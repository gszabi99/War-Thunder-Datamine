require ecs
require AnimV20
require GeomNodeTree

[es(tag=server, on_appear)]
def human_breath_node_init(evt : Event;
                           animchar : AnimcharBaseComponent;
                           breath_node__node : string;
                           var breath_node__nodeId : int&)
  breath_node__nodeId = geomtree_findNodeIndex(*animchar.nodeTree, breath_node__node)
