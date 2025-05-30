module fire_system_common shared public
require ecs
require dm
require WTDamageModel
require DmFire
require DagorMath
require GeomNodeTree
require AmmoStowage
require %game.utils.utils_common
require %game.utils.component_bundle_macro
require %game.dm.dm_events
require %game.dm.fire_system_events
require %game.events
require %game.unit.ammo_stowage_common



let INVALID_GEOM_NODE_ID = -1


struct StartSingleBurnDesc
  partId : PartId = PartId()
  nodeId : int
  fireParamsId : int
  fireFxId : int
  offset : float3
  centerDmgPart : float3
  radius : float
  finalRadius : float
  atTime : float
  initiatorId : uint


[with_bundle(v)]
def check_is_burning(v : tuple<fire_data__startTime : FloatList>) : bool
  for start_time in v.fire_data__startTime
    if start_time > 0.0f
      return true
  return false

[with_bundle(v)]
def can_be_extinguished_with_extinguisher(v : tuple<
                                            fire_data__startTime : FloatList;
                                            fire_data__fireParamsId : IntList
                                            >) : bool
  for start_time, fire_params_id in v.fire_data__startTime, v.fire_data__fireParamsId
    if start_time > 0.0f
      let fire_params = get_fire_params(fire_params_id)
      if fire_params != null && fire_params.extinguisherEffective
        return true
  return false


[with_bundle(v)]
def fire_system_start_single_burn(eid : EntityId; desc : StartSingleBurnDesc;
                                  var v : tuple<
                                    fire_data__packedPartId : UInt32List;
                                    fire_data__nodeId : IntList;
                                    fire_data__fireParamsId : IntList;
                                    fire_data__offset : Point3List;
                                    fire_data__radius : Point2List;
                                    fire_data__initiatorId : UInt32List;
                                    fire_data__startTime : FloatList;
                                    fire_data__extinguishProgress : FloatList;
                                    fire_data__underwaterTimer : FloatList
                                    >) : int
  if length(v.fire_data__packedPartId) > 255
    return -1

  let fireParams = get_fire_params(desc.fireParamsId)
  if fireParams == null
    return -1

  var idx = -1
  if !fireParams.allowMultipleFires
    for i, nodeId in iter_range(v.fire_data__packedPartId), v.fire_data__nodeId
      if desc.nodeId != INVALID_GEOM_NODE_ID && nodeId == desc.nodeId
        idx = i
        break

  if idx == -1
    idx = length(v.fire_data__packedPartId)
    v.fire_data__packedPartId |> push(desc.partId.packed)
    v.fire_data__nodeId |> push(desc.nodeId)
    v.fire_data__fireParamsId |> push(desc.fireParamsId)
    v.fire_data__offset |> push(desc.offset)
    v.fire_data__radius |> push(float2(desc.radius, desc.finalRadius))
    v.fire_data__initiatorId |> push(-1u)
    v.fire_data__startTime |> push(-1.0f)
    v.fire_data__extinguishProgress |> push(0.0f)
    v.fire_data__underwaterTimer |> push(-1.0f)

  if v.fire_data__startTime[idx] > 0.0f
    return -1

  v.fire_data__startTime[idx] = float(desc.atTime)
  v.fire_data__initiatorId[idx] = desc.initiatorId
  v.fire_data__extinguishProgress[idx] = 0.0f

  sendEvent(eid, EventOnStartSingleBurn(
    fireId = idx,
    fireParamsId = v.fire_data__fireParamsId[idx],
    fireFxId = desc.fireFxId,
    nodeId = v.fire_data__nodeId[idx],
    offset = v.fire_data__offset[idx],
    dmgPos = desc.centerDmgPart
  ))
  return idx

[with_bundle(v)]
def fire_system_stop_single_burn(eid : EntityId; fire_id : int;
                                 var v : tuple<
                                   fire_data__initiatorId : UInt32List;
                                   fire_data__startTime : FloatList
                                   >)
  if fire_id >= 0 && fire_id < length(v.fire_data__initiatorId)
    sendEvent(eid, EventOnStopSingleBurn(fireId = fire_id, initiatorId = v.fire_data__initiatorId[fire_id]))
    v.fire_data__startTime[fire_id] = -1.0f
    v.fire_data__initiatorId[fire_id] = -1u


def fire_system_calc_burn_radius(fire_params : FireParams; coll_node_sph : BSphere3; bounding_radius : float)
  let radius = coll_node_sph.r * fire_params.radiusScales.x
  let final_radius = fire_params.radiusScales.y > 0.0f ? coll_node_sph.r * fire_params.radiusScales.y : bounding_radius * 2.0f
  return (radius, final_radius)


def fire_system_calc_burn_offset(fire_params : FireParams; coll_node_sph : BSphere3; tree : GeomNodeTree; node_id : int; pos : float3)
  if fire_params.allowMultipleFx && node_id != INVALID_GEOM_NODE_ID
    var tm : float3x4
    geomtree_getNodeWtmScalar(tree, node_id, tm)
    return inverse(tm) * pos
  else
    return coll_node_sph.c

[with_bundle(v)]
def fire_system_get_fire_sphere(fire_id : int; at_time : float;
                                v : tuple<
                                  fire_data__fireParamsId : IntList;
                                  fire_data__offset : Point3List;
                                  fire_data__radius : Point2List;
                                  fire_data__startTime : FloatList
                                  >)
  let fire_params = get_fire_params(v.fire_data__fireParamsId[fire_id])
  let radius = v.fire_data__radius[fire_id]
  return BSphere3(v.fire_data__offset[fire_id], cvt(at_time - v.fire_data__startTime[fire_id],
      fire_params.maxFireTime.x, fire_params.maxFireTime.y, radius.x, radius.y))




[with_bundle(v)]
def fire_system_can_part_burn(part_id : PartId;
                              v : tuple<
                                ammo_slots__state : UInt32List;
                                ammo_stowage__partIdRemap : IPoint4List
                                >) : bool
  let remap = get_remap(v.ammo_stowage__partIdRemap, part_id)
  if remap.partId.valid
    return !get_flag(v.ammo_slots__state[remap.slotId], AmmoSlotState.FLOODED)
  return true

