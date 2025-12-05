require ecs
require app
require math.base
require DagorMath
require CollisionTraces
require GridCollision
require CollRes
require Dacoll
require AnimV20
require %game.events
require Weapon
require GeomNodeTree


def get_attachable_item_transform(previous_transform : float3x4;
                                  norm : float3;
                                  contact_pos : float3)
  var transform : float3x4
  transform[1] = normalize_default(norm, float3(0., 1., 0.)) 
  transform[2] = cross(previous_transform[0], transform[1]) 
  transform[0] = cross(transform[1], transform[2]) 
  transform[3] = contact_pos
  orthonormalize(transform) 
  return transform

def try_attach_to_vehicle(owner_eid : EntityId;
                          attachable_item_eid : EntityId;
                          attachable_item_transform : float3x4;
                          attachable_item__addTemplate : string;
                          attachable_item__removeTemplate : string;
                          contact_pos : float3;
                          prev_pos : float3;
                          dir : float3;
                          var distance : float)
  var norm : float3
  var vehicleEid = INVALID_ENTITY_ID
  var vehicleNodeId = 0
  var nodeTransform : float3x4
  using() <| $(var intersections : IntersectedEntities)
    let isCollidedWithVehicle = trace_entities_in_grid(ecs_hash("vehicles"), prev_pos, dir, distance, INVALID_ENTITY_ID, intersections, SortIntersections.YES)
    if isCollidedWithVehicle
      for it in intersections
        query(it.eid) <| $ [es(REQUIRE=vehicle)] (animchar : AnimcharBaseComponent;
                                                  collres : CollisionResource)
          norm = it.norm
          vehicleEid = it.eid
          let node = collres_get_node(collres, it.collNodeId)
          
          vehicleNodeId = uint(node.geomNodeId) < uint(animchar.nodeTree.nodeCount) ? int(node.geomNodeId) : 0
          geomtree_getNodeWtmScalar(*animchar.nodeTree, vehicleNodeId, nodeTransform)

        if !!vehicleEid
          break

  if vehicleEid == INVALID_ENTITY_ID
    return false

  let ownerExists = query(owner_eid) <| $ [es] (possessedByPlr : EntityId;
                                                team : int;
                                                guid : string)
    let transform = get_attachable_item_transform(attachable_item_transform, norm, contact_pos)
    let removeTemplate = attachable_item__removeTemplate
    let addTemplate = (empty(attachable_item__addTemplate) ? "" : "{attachable_item__addTemplate}+") + "attachable_item_on_vehicle"
    remote_remove_sub_template(attachable_item_eid, removeTemplate)
    remote_add_sub_template(attachable_item_eid, addTemplate) <| $(var init)
      set(init, "transform", transform)
      set(init, "item__lastOwner", owner_eid)
      set(init, "item__ownerEid", INVALID_ENTITY_ID)
      set(init, "item__visible", true)
      set(init, "item__isOnGround", true)
      set(init, "builder_info__team", team)
      set(init, "builder_info__guid", guid)
      set(init, "buildByEngineerEid", owner_eid)
      set(init, "buildByPlayer", possessedByPlr)
      set(init, "node_attached__entity", vehicleEid)
      set(init, "node_attached__nodeId", vehicleNodeId)
      set(init, "node_attached__localTm", inverse(nodeTransform) * transform)
  return ownerExists

def try_attach_to_environment(owner_eid : EntityId;
                              attachable_item_eid : EntityId;
                              attachable_item_transform : float3x4;
                              attachable_item__addTemplate : string;
                              attachable_item__removeTemplate : string;
                              contact_pos : float3;
                              prev_pos : float3;
                              dir : float3;
                              var distance : float)
  var norm : float3
  let isCollidedWithEnvironment = traceray_normalized(prev_pos, dir, distance, norm, ETF_DEFAULT)
  if !isCollidedWithEnvironment
    return false

  let ownerExists = query(owner_eid) <| $ [es] (possessedByPlr : EntityId;
                                                team : int;
                                                guid : string)
    let transform = get_attachable_item_transform(attachable_item_transform, norm, contact_pos)
    let removeTemplate = attachable_item__removeTemplate
    let addTemplate = (empty(attachable_item__addTemplate) ? "" : "{attachable_item__addTemplate}+") + "attachable_item_in_world"
    remote_remove_sub_template(attachable_item_eid, removeTemplate)
    remote_add_sub_template(attachable_item_eid, addTemplate) <| $(var init)
      set(init, "transform", transform)
      set(init, "item__lastOwner", owner_eid)
      set(init, "item__ownerEid", INVALID_ENTITY_ID)
      set(init, "item__visible", true)
      set(init, "item__isOnGround", true)
      set(init, "builder_info__team", team)
      set(init, "builder_info__guid", guid)
      set(init, "buildByEngineerEid", owner_eid)
      set(init, "buildByPlayer", possessedByPlr)
  return ownerExists

[es(tag=server, REQUIRE=(attachable_item, throwable_item))]
def attachable_item_attach_throwed_on_contact(evt : CmdPostPhysUpdate;
                                              eid : EntityId;
                                              throwable_item__owner : EntityId;
                                              var proj__physObj : ProjectilePhysObject&;
                                              transform : float3x4;
                                              throwable_item__throwed : bool;
                                              attachable_to_vehicle : Tag const?;
                                              attachable_to_environment : Tag const?;
                                              attachable_item__addTemplate : string = "";
                                              attachable_item__removeTemplate : string = "";
                                              attachable_item__minPrevPosToContactDistance : float = 0.1;
                                              attachable_item__minContactDirDeviationCos : float = 0.999)
  if !proj__physObj |> phys().currentState.hadContact || !throwable_item__throwed
    return

  let contact = proj__physObj |> phys().currentState.contactPoint
  var prevPos = float3(proj__physObj |> phys().previousState.location.P)
  let attachableDir = normalize(proj__physObj |> phys().previousState.velocity)
  if distance_sq(contact, prevPos) < square(attachable_item__minPrevPosToContactDistance)
    let contactDir = normalize(contact - prevPos)
    if dot(contactDir, attachableDir) < attachable_item__minContactDirDeviationCos
      prevPos = contact - attachableDir * attachable_item__minPrevPosToContactDistance

  if attachable_to_vehicle != null
    if try_attach_to_vehicle(throwable_item__owner, eid, transform, attachable_item__addTemplate, attachable_item__removeTemplate, contact, prevPos, attachableDir, 1.0f)
      return

  if attachable_to_environment != null
    if try_attach_to_environment(throwable_item__owner, eid, transform, attachable_item__addTemplate, attachable_item__removeTemplate, contact, prevPos, attachableDir, 1.0f)
      return
