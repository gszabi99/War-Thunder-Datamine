require ecs
require app
require %game.events
require math
require math.base
require DagorMath
require DagorSystem
require AnimV20
require GeomNodeTree

def find_camera_node_idx(eid : EntityId;
                         animchar : AnimcharBaseComponent;
                         nodeName : string) : int
  let nodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex(nodeName)
  if (nodeIdx < 0)
    let templateName = getEntityTemplateName(eid)
    logerr("Can't find camera node {nodeName} in {templateName}")
  return nodeIdx

[es(on_appear)]
def camera_aim_node_init(evt : Event;
                         eid : EntityId;
                         animchar : AnimcharBaseComponent;
                         entity_cam_nodes__aimNode : das_string const?;
                         var entity_cam_nodes__aimNodeIdx : int&)
  let nodeName = entity_cam_nodes__aimNode != null ? string(*entity_cam_nodes__aimNode) : "aim"
  let nodeIdx = find_camera_node_idx(eid, animchar, nodeName)
  entity_cam_nodes__aimNodeIdx = nodeIdx