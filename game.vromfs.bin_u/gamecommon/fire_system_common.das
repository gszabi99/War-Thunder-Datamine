module fire_system_common shared public
require ecs
require dm
require WTDamageModel
require DmFire
require DagorMath
require GeomNodeTree
require %dasGameLibs.ecs.soa_template
require %game.component_bundle_macro
require %game.dm_events
require %game.fire_system_events
require %game.events


// TODO: dag::Index16 support
let INVALID_GEOM_NODE_ID = int(0xFFFF)


struct StartSingleBurnDesc
  partId : PartId
  nodeId : int
  fireParamsId : int
  fireFxId : int
  offset : float3
  centerDmgPart : float3
  radius : float
  finalRadius : float
  atTime : float
  initiatorId : uint


[soa_template]
struct FireData
  fire_data__packedPartId : uint // TODO: soa_template macro does not support custom types, so store packed part ids
  fire_data__nodeId : int
  fire_data__fireParamsId : int
  fire_data__offset : float3
  fire_data__radius : float2
  fire_data__initiatorId : uint
  fire_data__startTime : float
  fire_data__extinguishProgress : float
  fire_data__underwaterTimer : float


[soa_def]
def check_is_burning(fd : FireData_SOA)
  for data in fd
    if data.fire_data__startTime > 0.0f
      return true
  return false


[soa_def]
def can_be_extinguished_with_extinguisher(fd : FireData_SOA&)
  for fire_data in fd
    if fire_data.fire_data__startTime > 0.0f
      let fire_params = get_fire_params(fire_data.fire_data__fireParamsId)
      if fire_params.extinguisherEffective
        return true
  return false


[soa_def]
def fire_system_start_single_burn(eid : EntityId; desc : StartSingleBurnDesc; var fd : FireData_SOA&)
  if length(fd) > 255
    return -1

  let fire_params = get_fire_params(desc.fireParamsId)
  if fire_params == null
    return -1

  var idx = -1
  if !fire_params.allowMultipleFires
    for i, data in iter_range(fd), fd
      if desc.nodeId != INVALID_GEOM_NODE_ID && data.fire_data__nodeId == desc.nodeId
        idx = i
        break

  if idx == -1
    idx = length(fd)
    fd |> push() <| [[fire_system_common::FireData
      fire_data__packedPartId = desc.partId.packed,
      fire_data__nodeId = desc.nodeId,
      fire_data__fireParamsId = desc.fireParamsId,
      fire_data__offset = desc.offset,
      fire_data__radius = float2(desc.radius, desc.finalRadius),
      fire_data__initiatorId = -1u,
      fire_data__startTime = -1.0f,
      fire_data__extinguishProgress = 0.0f,
      fire_data__underwaterTimer = -1.0f
    ]]

  if fd[idx].fire_data__startTime > 0.0f
    return -1

  fd[idx].fire_data__startTime = float(desc.atTime)
  fd[idx].fire_data__initiatorId = desc.initiatorId
  fd[idx].fire_data__extinguishProgress = 0.0f

  sendEvent(eid, [[EventOnStartSingleBurn
    fireId = idx,
    fireParamsId = fd[idx].fire_data__fireParamsId,
    fireFxId = desc.fireFxId,
    nodeId = fd[idx].fire_data__nodeId,
    offset = fd[idx].fire_data__offset,
    dmgPos = desc.centerDmgPart
  ]])
  return idx


[soa_def]
def fire_system_stop_single_burn(eid : EntityId; var fd : FireData_SOA&; fire_id : int)
  if fire_id >= 0 && fire_id < length(fd)
    sendEvent(eid, [[EventOnStopSingleBurn fireId=fire_id, initiatorId=fd[fire_id].fire_data__initiatorId]])
    fd[fire_id].fire_data__startTime = -1.0f;
    fd[fire_id].fire_data__initiatorId = -1u;


def fire_system_calc_burn_radius(fire_params : FireParams; coll_node_sph : BSphere3; bounding_radius : float)
  let radius = coll_node_sph.r * fire_params.radiusScales.x
  let final_radius = fire_params.radiusScales.y > 0.0f ? coll_node_sph.r * fire_params.radiusScales.y : bounding_radius * 2.0f
  return [[tuple<float; float> radius, final_radius]]


def fire_system_calc_burn_offset(fire_params : FireParams; coll_node_sph : BSphere3; tree : GeomNodeTree; node_id : int; pos : float3)
  if fire_params.allowMultipleFx && node_id != int(0xFFFF)
    var tm : float3x4
    geomtree_getNodeWtmScalar(tree, node_id, tm)
    return inverse(tm) * pos
  else
    return coll_node_sph.c


[soa_def]
def fire_system_get_fire_sphere(fd : FireData_SOA; fire_id : int; at_time : float)
  let fire_params = get_fire_params(fd[fire_id].fire_data__fireParamsId)
  let radius = fd[fire_id].fire_data__radius
  return BSphere3(fd[fire_id].fire_data__offset, cvt(at_time - fd[fire_id].fire_data__startTime,
      fire_params.maxFireTime.x, fire_params.maxFireTime.y, radius.x, radius.y));
