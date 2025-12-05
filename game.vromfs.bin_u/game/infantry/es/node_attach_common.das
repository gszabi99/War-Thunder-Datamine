module node_attach_common shared
require ecs
require AnimV20
require GeomNodeTree
require math.base


def attach_to_node(eid : EntityId; bind_to_eid : EntityId; node_id : int; local_tm : float3x4)
  addSubTemplate(eid, "node_attached_itm") <| $(var init)
    set(init, "node_attached__entity", bind_to_eid)
    set(init, "node_attached__nodeId", node_id)
    set(init, "node_attached__localTm", local_tm)

def attach_to_node(eid : EntityId; bind_to_eid : EntityId; node_id : int; local_offset : float3)
  var tm = IDENT_TM
  tm[3] = local_offset
  attach_to_node(eid, bind_to_eid, node_id, tm)

def attach_to_node(eid : EntityId; bind_to_eid : EntityId; node_id : int)
  attach_to_node(eid, bind_to_eid, node_id, IDENT_TM)

def attach_to_node_pos(eid : EntityId; bind_to_eid : EntityId; node_id : int; local_pos : float3)
  addSubTemplate(eid, "node_attached_pos") <| $(var init)
    set(init, "node_attached__entity", bind_to_eid)
    set(init, "node_attached__nodeId", node_id)
    set(init, "node_attached__localPos", local_pos)

def get_node_local_pos(eid : EntityId; node_id : int; var pos : float3&) : bool
  var queryStatus = false
  query(eid) <| $ [es] (animchar : AnimcharBaseComponent)
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, node_id, tm)
    pos = inverse(tm) * pos
    queryStatus = true
  return queryStatus

def get_node_wpos(eid : EntityId; node_id : int; var tm : float3x4&) : bool
  var queryStatus = false
  query(eid) <| $ [es] (animchar : AnimcharBaseComponent)
    geomtree_getNodeWtmScalar(*animchar.nodeTree, node_id, tm)
    queryStatus = true
  return queryStatus
