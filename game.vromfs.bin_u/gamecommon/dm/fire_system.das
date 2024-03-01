require ecs
require app
require net
require dm
require DagorRandom
require DagorMath
require Unit
require WTDamageModel
require %dasGameLibs.ecs.soa_template
require %game.utils.component_bundle_macro
require %game.dm.fire_system_events
require %game.dm.fire_system_common
require %game.unit.unit_events
require %game.unit.extinguish_system_common
require %game.events


[es(no_order)]
def fire_damage_init_es(evt : CmdInitComponent; var fire_damage__updateBurnInterval : float&)
  fire_damage__updateBurnInterval = get_app().gameParams.updateBurnInterval


[soa_es, es(tag=server, no_order)]
def fire_damage_update_es(act : UpdateStageInfoAct;
                          eid : EntityId;
                          var fd : FireData_SOA&;
                          var fire_system_require_net_sync : bool&;
                          var fire_damage__nextUpdateTime : float&;
                          fire_damage__updateBurnInterval : float;
                          var fire_damage__isBurn : bool&)
  if !fire_damage__isBurn
    return

  let now_burning = check_is_burning(fd)
  if !now_burning
    sendEvent(eid, [[EventOnStopBurn wasBurning=true]])
    fd |> clear()
    fire_damage__isBurn = false
    fire_system_require_net_sync = true

  let at_time = float(get_app().usefulTotalTime)
  let seed = grnd()

  // update fire damage
  if fire_damage__nextUpdateTime < act.curTime
    fire_damage__nextUpdateTime = act.curTime + fire_damage__updateBurnInterval
    for id, data in iter_range(fd), fd
      if data.fire_data__startTime <= 0.0f
        continue

      let fire_params = get_fire_params(data.fire_data__fireParamsId)
      if fire_params != null && act.curTime > data.fire_data__startTime + fire_params.maxFireTime.y && gfrnd() < fire_params.extinguishChance
        fire_system_stop_single_burn(eid, fd, id)
        fire_system_require_net_sync = true
        continue

      let sph = fire_system_get_fire_sphere(fd, id, at_time)
      sendEvent(eid, [[EventOnBurnDamageToPart
        fireId=id,
        packedPartId=data.fire_data__packedPartId,
        fireParamsId=data.fire_data__fireParamsId,
        initiatorId=data.fire_data__initiatorId,
        seed=seed,
        sph = float4(sph.c.x, sph.c.y, sph.c.z, sph.r),
        atTime = act.curTime
      ]])

  // update underwater (this used to update only when extinguisher was not active, but it does not seem to be reasonable)
  for id, data in iter_range(fd), fd
    if data.fire_data__startTime < 0.0f
      continue
    let sph = fire_system_get_fire_sphere(fd, id, at_time)
    let is_underwater = is_fire_emitter_underwater(eid, data.fire_data__fireParamsId, data.fire_data__nodeId, sph)
    if is_underwater
      if data.fire_data__underwaterTimer <= 0.0f
        data.fire_data__underwaterTimer = get_fire_params(data.fire_data__fireParamsId).underwaterExtinguishTime
    else
      data.fire_data__underwaterTimer = -1.0f

    if data.fire_data__underwaterTimer > 0.0f
      data.fire_data__underwaterTimer -= act.dt
      if data.fire_data__underwaterTimer <= 0.0f
        fire_system_stop_single_burn(eid, fd, id)
        fire_system_require_net_sync = true


[soa_def]
def fire_damage_process_start_burn_event(eid : EntityId;
                                         unit : Unit?;
                                         part_id : PartId;
                                         fire_params_id : int;
                                         fire_fx_id : int;
                                         offender : OffenderData;
                                         pos : float4;
                                         var fd : FireData_SOA&;
                                         var fire_damage__isBurn : bool&)
  if unit.visual == null
    return
  assume dm = *unit.visual
  let geom_node_id = part_id.valid ? dm_get_geom_node_id_by_part_id(dm, int(part_id.globalId)) : INVALID_GEOM_NODE_ID
  let coll_node = dm_get_collision_node_by_part_id(dm, int(part_id.globalId))
  if coll_node == null
    return

  let fire_params = get_fire_params(fire_params_id)
  if fire_params == null || fire_params.damage <= 0.0f
    return

  let radius : tuple<radius : float; final_radius : float> = fire_system_calc_burn_radius(*fire_params, coll_node.boundingSphere, unit.collisionData.boundingSphere.r)
  var offset : float3
  if pos != float4(0.0f) && unit.collNodeTree != null && (fire_params.allowMultipleFires || fire_params.allowMultipleFx)
    offset = fire_system_calc_burn_offset(*fire_params, coll_node.boundingSphere, *unit.collNodeTree, geom_node_id, float3(pos.x, pos.y, pos.z))
  else
    offset = coll_node.boundingSphere.c

  let at_time = float(get_app().usefulTotalTime)
  let fire_id = fire_system_start_single_burn(eid, [[StartSingleBurnDesc
    partId=part_id,
    nodeId=geom_node_id,
    fireParamsId=fire_params_id,
    fireFxId=fire_fx_id,
    offset=offset,
    centerDmgPart=coll_node.tm * coll_node.modelBBox.center,
    radius=radius.radius,
    finalRadius=radius.final_radius,
    atTime=at_time,
    initiatorId=offender |> get_bullet_uid()
  ]], fd)

  if fire_id >= 0 && !fire_damage__isBurn
    fire_damage__isBurn = true
    let sph = fire_system_get_fire_sphere(fd, fire_id, at_time)
    sendEvent(eid, [[EventFireSystemStartBurning
      offender=offender,
      partId=part_id,
      sph = float4(sph.c.x, sph.c.y, sph.c.z, sph.r)
    ]])


[soa_es, es, with_bundle(v)]
def fire_damage_start_burn_with_offender(evt : EventFireSystemStartBurnWithOffender;
                                         eid : EntityId;
                                         uid : int;
                                         var fd : FireData_SOA&;
                                         v : tuple<
                                           fire_damage__isBurn : bool- const;
                                           extinguish_system_last_extinguish_time : float;
                                           fire_system_require_net_sync : bool- const;
                                           ammo_slots__state : UInt32List;
                                           ammo_stowage__partIdRemap : IPoint4List
                                         >)
  if !extinguish_system_can_reignite(v.extinguish_system_last_extinguish_time)
    return
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  if !fire_system_can_part_burn(evt.partId, v)
    return
  fire_damage_process_start_burn_event(eid, unit,
                                       evt.partId, evt.fireParamsId, evt.fireFxId, evt.offender, float4(0.0f),
                                       fd, v.fire_damage__isBurn)
  v.fire_system_require_net_sync = true


[soa_es, es(tag=server), with_bundle(v)]
def fire_damage_start_burn_with_offender_in_pos(evt : EventFireSystemStartBurnWithOffenderInPos;
                                                eid : EntityId;
                                                uid : int;
                                                var fd : FireData_SOA&;
                                                v : tuple<
                                                  fire_damage__isBurn : bool- const;
                                                  extinguish_system_last_extinguish_time : float;
                                                  fire_system_require_net_sync : bool- const;
                                                  ammo_slots__state : UInt32List;
                                                  ammo_stowage__partIdRemap : IPoint4List
                                                >)
  if !extinguish_system_can_reignite(v.extinguish_system_last_extinguish_time)
    return
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  if !fire_system_can_part_burn(evt.partId, v)
    return
  fire_damage_process_start_burn_event(eid, unit,
                                       evt.partId, evt.fireParamsId, evt.fireFxId, evt.offender, float4(evt.pos.x, evt.pos.y, evt.pos.z, 1.0f),
                                       fd, v.fire_damage__isBurn)
  v.fire_system_require_net_sync = true


[soa_es, es]
def fire_damage_stop_burn_es(evt : CmdStopBurn;
                             eid : EntityId;
                             var fd : FireData_SOA&;
                             var fire_system_require_net_sync : bool&;
                             var fire_damage__isBurn : bool&)
  sendEvent(eid, [[EventOnStopBurn wasBurning=fire_damage__isBurn]])
  fd |> clear()
  fire_damage__isBurn = false;
  fire_system_require_net_sync = true;


[es]
def fire_system_repair_es(evt : EventUnitRepair; eid : EntityId)
  sendEventImmediate(eid, [[CmdStopBurn]])


[es]
def fire_system_respawn_es(evt : EventUnitRespawn; eid : EntityId)
  sendEventImmediate(eid, [[CmdStopBurn]])


// -------------------------------- fire net sync --------------------------------------

[soa_es, es(after=fire_damage_update_es, tag=server)]
def fire_system_net_sync_update_es(act : UpdateStageInfoAct;
                                   eid : EntityId;
                                   var fire_system_require_net_sync : bool&;
                                   fire_damage__isBurn : bool;
                                   fd : FireData_SOA&)
  if !fire_system_require_net_sync
    return
  fire_system_require_net_sync = false

  using() <| $(var data : IntList)
    data |> reserve(length(fd) * 2)
    for fire_data in fd
      let is_burning = fire_data.fire_data__startTime >= 0.0f
      if is_burning
        data |> push(int(fire_data.fire_data__packedPartId))
        data |> push(fire_data.fire_data__fireParamsId)

    send_net_event(eid, [[EventFireSystemNetSync
      isBurning = fire_damage__isBurn,
      data=ecs_addr(data)
    ]])


[soa_es, es(tag=netClient)]
def fire_system_net_sync_handle_es(evt : EventFireSystemNetSync;
                                   eid : EntityId;
                                   var fire_damage__isBurn : bool&;
                                   var fd : FireData_SOA&)
  let total_time = float(get_app().usefulTotalTime)
  let was_burning = fire_damage__isBurn;
  fire_damage__isBurn = evt.isBurning;

  if !was_burning && evt.isBurning
    sendEvent(eid, [[EventFireSystemOnStartBurn offender=[[OffenderData]]]])
  elif was_burning && !evt.isBurning
    sendEvent(eid, [[CmdStopBurn]])

  var burning_parts : array<tuple<packed_part_id : uint; fire_params_id : int; already_burning : bool>>
  burning_parts |> reserve(length(*evt.data) / 2)
  for i in range(0, length(*evt.data) / 2)
    let packed_part_id = uint((*evt.data)[i * 2])
    let fire_params_id = (*evt.data)[i * 2 + 1]
    burning_parts |> push([[auto packed_part_id, fire_params_id, false]])

  for fire_id, data in iter_range(fd), fd
    var fire_found = false
    for part in burning_parts
      if data.fire_data__packedPartId == part.packed_part_id
        fire_found = true
        part.already_burning = true
        break
    if !fire_found
      fire_system_stop_single_burn(eid, fd, fire_id)

  for part in burning_parts
    if !part.already_burning
      fire_system_start_single_burn(eid, [[StartSingleBurnDesc
        partId = unpack_part_id(part.packed_part_id),
        nodeId = INVALID_GEOM_NODE_ID,
        fireParamsId = part.fire_params_id,
        fireFxId = -1,
        offset = float3(0.0f),
        centerDmgPart = float3(0.0f),
        radius = 0.0f,
        finalRadius = 0.0f,
        atTime = total_time,
        initiatorId = -1u
      ]], fd)
