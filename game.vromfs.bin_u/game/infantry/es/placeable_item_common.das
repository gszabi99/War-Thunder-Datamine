module placeable_item_common shared

require ecs
require math.base
require AnimV20
require GeomNodeTree


def verify_place_restrictions(placer_pos : float3;
                              placeable_item_pos : float3;
                              placeable_item_eid : EntityId)
  var result = false
  query(placeable_item_eid) <| $ [es] (placeable_item__verifyDistance : float)
    let verifyDistSq = square(placeable_item__verifyDistance)
    if length_sq(placeable_item_pos.xz - placer_pos.xz) <= verifyDistSq
      result = true
  return result


def init_placeable_item_components(var init; tm; eid; team; player_eid; guid)
  set(init, "transform", tm)
  set(init, "gun__visible", true)
  set(init, "placeable_item__ownerEid", eid)
  set(init, "gun__owner", INVALID_ENTITY_ID)
  set(init, "item__lastOwner", eid)
  set(init, "item__ownerEid", INVALID_ENTITY_ID)
  set(init, "placeable_item__ownerTeam", team)
  set(init, "item__visible", true)
  set(init, "item__isOnGround", true)
  set(init, "builder_info__team", team)
  set(init, "builder_info__guid", guid)
  set(init, "buildByEngineerEid", eid)
  set(init, "buildByPlayer", player_eid)

def init_attached_to_vehicle_placeable_item_components(var init : ComponentsInitializer;
                                                       preview_tm : float3x4;
                                                       vehicle_eid : EntityId;
                                                       vehicle_node_id : int)
  query(vehicle_eid) <| $ [es] (animchar : AnimcharBaseComponent)
    set(init, "node_attached__entity", vehicle_eid)
    set(init, "node_attached__nodeId", vehicle_node_id)

    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, vehicle_node_id, tm)
    set(init, "node_attached__localTm", inverse(tm) * preview_tm)
