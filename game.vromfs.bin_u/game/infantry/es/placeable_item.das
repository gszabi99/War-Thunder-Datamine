require ecs
require ecs.common
require net
require app
require GridCollision
require CollisionTraces
require CollRes
require AnimV20
require Dacoll
require math.base
require DagorMath
require %appGame.infantry.es.placeable_item_common
require strings
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.inventory_common
require GeomNodeTree
require DagorSystem


[es(tag=gameClient, before=placeable_item_place_request)]
def placeable_item_detach_reset_es(evt : CmdWeapAttach; var placeable_item__placeRequestReady : bool&)
  if !evt.isAttached
    placeable_item__placeRequestReady = false


[es(tag=gameClient, on_appear)]
def placeable_item_init_root_node_id(evt : Event;
                                     eid : EntityId;
                                     animchar : AnimcharBaseComponent;
                                     placeable_item__rootNodeName : string;
                                     var placeable_item__rootNodeId : int&)
  placeable_item__rootNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(placeable_item__rootNodeName)
  if placeable_item__rootNodeId == -1
    logerr("<{getEntityTemplateName(eid)}> does not have '{placeable_item__rootNodeName}' animchar node")


[es(tag=gameClient, REQUIRE_NOT=itemInWorld)]
def placeable_item_place_request(evt : CmdWeapPhysUpdate;
                                 eid : EntityId;
                                 animchar : AnimcharBaseComponent;
                                 animchar_attach__attachedTo : EntityId;
                                 animchar_render__root_pos : vec4f;
                                 placeable_item__rootNodeId : int const?;
                                 var placeable_item__placeTm : float3x4&;
                                 var placeable_item__inProgress : bool&;
                                 var placeable_item__placeRequestSend : bool&;
                                 var placeable_item__placeRequestReady : bool&;
                                 var placeable_item__lastPosition : float3&;
                                 var placeable_item__startPlacingPos : float3&;
                                 placeable_item__minDistanceToWall : float;
                                 placeable_item__additionalHeight : float;
                                 placeable_item__additionalRotation : float3;
                                 placeable_item__maxAnimLenSq = 0.04;
                                 placeable_item__allowablePlaceHeight = 0.15f)
  if !evt.isForReal
    return
  let isShootPressed = evt.gctrl.shoot
  placeable_item__placeRequestReady ||= !isShootPressed

  var placePos = animchar_render__root_pos.xyz
  if placeable_item__rootNodeId != null && *placeable_item__rootNodeId != -1
    placePos = *animchar.nodeTree |> geomtree_getNodeWpos(*placeable_item__rootNodeId)

  if placeable_item__placeRequestReady && isShootPressed
    placeable_item__inProgress = true
    placeable_item__placeRequestSend = false
    placeable_item__startPlacingPos = placePos

  if !placeable_item__inProgress
    return

  let curPlacingAnimLenSq = distance_sq(placeable_item__startPlacingPos, placePos)

  var humanTm : float3x4
  var humanAnimcharRenderRootPos : float3
  query(animchar_attach__attachedTo) <| $ [es] (transform : float3x4; animchar_render__root_pos : vec4f)
    humanTm = transform
    humanAnimcharRenderRootPos = animchar_render__root_pos.xyz

  let initialHeight = 100.
  var height = initialHeight
  var norm : float3
  var vehicleEid = INVALID_ENTITY_ID
  var vehicleNodeId = 0
  var startPlace = false

  if has(eid, "attachableToVehicle")
    let traceDir = float3(0., -1., 0.)

    trace_entities_in_grid(ecs_hash("vehicles"), placePos, traceDir, height, INVALID_ENTITY_ID, SortIntersections.YES) <| $(intersections : array<IntersectedEntity>#)
      for it in intersections
        if has(it.eid, "vehicle")
          norm = it.norm
          vehicleEid = it.eid
          query(vehicleEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                       collres : CollisionResource)
            let node = collres_get_node(collres, it.collNodeId)
            
            vehicleNodeId = uint(node.geomNodeId) < uint(animchar.nodeTree.nodeCount) ? int(node.geomNodeId) : 0
          break

    if !!vehicleEid
      startPlace = height < placeable_item__allowablePlaceHeight || curPlacingAnimLenSq >= placeable_item__maxAnimLenSq

  if !startPlace
    var wallNorm : float3
    var distance = placeable_item__minDistanceToWall
    let traceDir = placePos - placeable_item__lastPosition
    let humanDirXZ = float3(humanTm[0].x, 0.0, humanTm[0].z)
    let traceDirXZ = normalize_default(float3(traceDir.x, 0.0, traceDir.z), normalize(humanDirXZ))
    let isNearbyWall = traceray_normalized(placePos, traceDirXZ, distance, wallNorm, ETF_DEFAULT)
    if isNearbyWall
      placePos += normalize(float3(wallNorm.x, 0.0, wallNorm.z)) * (placeable_item__minDistanceToWall - distance)

    height = initialHeight
    let traceResult = tracedown_normalized(placePos, height, norm, ETF_DEFAULT)

    startPlace = traceResult && (height < placeable_item__allowablePlaceHeight || isNearbyWall)

    if !startPlace && traceResult && curPlacingAnimLenSq >= placeable_item__maxAnimLenSq
      height = initialHeight
      if tracedown_normalized(placePos, height, norm, ETF_DEFAULT)
        startPlace = true

    if !startPlace && !traceResult
      let placePosXZ = placePos.xz
      height = placePos.y - traceht_lmesh(placePosXZ)
      startPlace = true

  placeable_item__lastPosition = placePos

  if placeable_item__placeRequestSend || !placeable_item__placeRequestReady || !startPlace
    return

  placeable_item__placeTm = humanTm
  placeable_item__placeTm[1] = normalize_default(norm, float3(0., 1., 0.)) 
  placeable_item__placeTm[2] = cross(placeable_item__placeTm[0], placeable_item__placeTm[1]) 
  placeable_item__placeTm[0] = cross(placeable_item__placeTm[1], placeable_item__placeTm[2]) 

  let anglesRad = deg_to_rad(placeable_item__additionalRotation)
  var q : quat
  euler_to_quat(anglesRad.y, anglesRad.z, anglesRad.x, q) 
  var rotTm : float3x4
  make_tm(q, float3(0.0f, 0.0f, 0.0f), rotTm)
  placeable_item__placeTm = placeable_item__placeTm * rotTm
  placeable_item__placeTm[3] = placePos
  placeable_item__placeTm[3].y += placeable_item__additionalHeight - height

  orthonormalize(placeable_item__placeTm) 

  placeable_item__inProgress = false
  placeable_item__placeRequestSend = true
  placeable_item__placeRequestReady = false

  send_net_event(animchar_attach__attachedTo, CmdStartPlacePlaceableItem(
                                            itemEid = eid,
                                            tm = placeable_item__placeTm,
                                            vehicleEid = vehicleEid,
                                            vehicleNodeId = vehicleNodeId))


[es(REQUIRE=transform,  on_appear)]
def remove_from_attachments_on_create_es(evt : Event;
                                         eid : EntityId;
                                         placeable_item__ownerEid : EntityId)
  query(placeable_item__ownerEid) <| $ [es] (var attaches_list : EidList&)
    let idxInAttaches = find_index(attaches_list, eid)
    if idxInAttaches != -1
      erase(attaches_list, idxInAttaches)


[es]
def placeable_item_start_place_es(evt : CmdStartPlacePlaceableItem;
                                  eid : EntityId;
                                  transform : float3x4;
                                  team : int;
                                  guid : string;
                                  squad_member__playerEid : EntityId;
                                  var itemContainer : EidList&;
                                  var human_weap__gunEids : EidList&;
                                  var human_weap__currentGunEid : EntityId&)
  if human_weap__currentGunEid != evt.itemEid
    return

  let previewTm = evt.tm
  if !verify_place_restrictions(transform[3], previewTm[3], human_weap__currentGunEid)
    return
  let idxInContainer = find_index(itemContainer, human_weap__currentGunEid)
  if idxInContainer != -1
    erase(itemContainer, idxInContainer)
  let idxInGuns = find_index(human_weap__gunEids, human_weap__currentGunEid)
  if idxInGuns != -1
    human_weap__gunEids[idxInGuns] = INVALID_ENTITY_ID
  sendEventImmediate(human_weap__currentGunEid, CmdWeapAttach(toEid = eid, isAttached = false, slotId = idxInGuns))
  var placeTemplate = ""
  var keepOldTemplate = true
  query(evt.itemEid) <| $ [es] (placeable_item__removedTemplate : string = "";
                                placeable_item__template : string;
                                placeable_item__keepOldTemplate : bool;
                                attachable_to_vehicle__template = "")
    keepOldTemplate = placeable_item__keepOldTemplate
    if evt.vehicleEid != INVALID_ENTITY_ID && !empty(attachable_to_vehicle__template)
      placeTemplate = attachable_to_vehicle__template
    else
      placeTemplate = placeable_item__template
    if placeable_item__removedTemplate != ""
      removeSubTemplate(human_weap__currentGunEid, placeable_item__removedTemplate)
  addSubTemplate(human_weap__currentGunEid, placeTemplate) <| $(var init : ComponentsInitializer)
    init_placeable_item_components(init, previewTm, eid, team, squad_member__playerEid, guid)
    init_attached_to_vehicle_placeable_item_components(init, previewTm, evt.vehicleEid, evt.vehicleNodeId)

  if !keepOldTemplate
    reCreateEntityFrom(human_weap__currentGunEid, placeTemplate)

  sendEvent(eid, CmdFinishPlacePlaceableItem(
                   tm = previewTm,
                   newTemplate = keepOldTemplate ? add_sub_template_name(evt.itemEid, placeTemplate) : placeTemplate,
                   itemEid = human_weap__currentGunEid,
                   vehicleEid = evt.vehicleEid,
                   vehicleNodeId = evt.vehicleNodeId))
  human_weap__currentGunEid = INVALID_ENTITY_ID


[es(tag=server)]
def placeable_item_finish_place_es(evt : CmdFinishPlacePlaceableItem;
                                   eid : EntityId;
                                   team : int;
                                   guid : string;
                                   squad_member__playerEid : EntityId)
  if !empty(evt.newTemplate) && !!evt.itemEid
    remote_recreate_entity_from(evt.itemEid, "{evt.newTemplate}") <| $(var init : ComponentsInitializer)
      init_placeable_item_components(init, evt.tm, eid, team, squad_member__playerEid, guid)
      init_attached_to_vehicle_placeable_item_components(init, evt.tm, evt.vehicleEid, evt.vehicleNodeId)


[es(tag=server)]
def placeable_item_on_loot(evt : EventOnLootPickup; eid : EntityId; var itemContainer : EidList&)
  query(evt.itemEid) <| $ [es(REQUIRE=placeable_item)] (item__template : string)
    let oldItemEidIdx = find_index(itemContainer, evt.itemEid)
    if oldItemEidIdx > -1
      erase(itemContainer, oldItemEidIdx)
    destroyEntity(evt.itemEid)
    push_item_in_cont(eid, item__template)
