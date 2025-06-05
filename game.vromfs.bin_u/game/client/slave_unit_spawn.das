require ecs
require app
require WTCamera
require Unit
require HeroManager
require Dacoll
require RendInst
require PhysMat
require %game.events
require %appGame.es.constructions_utils_common
require DagorMath
require DagorDataBlock
require hud
require vehicle
require HeavyVehicleModel

def is_unit_conflict_with_world(tm; collobj : CollisionObject const?; collobj_offset : float; rad : float)
  if collobj == null
    return false
  var tmCopy = tm
  tmCopy[3] = tmCopy[3] + normalize(tmCopy[1]) * collobj_offset
  if test_collision_world(*collobj, tmCopy, rad)
    return true
  return false

[es(tag=gameClient, no_order)]
def spawn_slave_ability_update_es(info : UpdateStageInfoAct;
                                  slave_unit_preview__radius : float;
                                  slave_unit_preview__availableAngles : float2;
                                  var unit__ref : UnitRef&;
                                  var slave_unit__transform : float3x4;
                                  var slave_unit_preview__canSpawn : bool&;
                                  checkGridObjectsTimeInterval : float;
                                  slave_unit_preview__collObjOffset : float;
                                  var nextCheckGridObjectsTime : float&;
                                  vehicle_net_phys : VehiclePhysActor)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed || !hero.isAlive
    return
  var riDesc = RendInstDesc()
  var len = slave_unit_preview__radius + 1.
  var riMatId = PHYSMAT_INVALID
  let rayMatId = PHYSMAT_INVALID
  var norm : float3
  let tracePos = get_camera_orig_pos()
  let traceDir = get_turret_aim_vector()
  var isBlocked = false
  traceray_normalized(tracePos, traceDir, len, riMatId, norm, ETF_ALL | ETF_RI_PHYS, riDesc, rayMatId)
  if riDesc.riExtraHandle != RIEX_HANDLE_NULL
    isBlocked = true
  let traceEnd = tracePos + traceDir * len
  if traceray_water_at_time(tracePos, traceEnd, float(get_app().usefulTotalTime), len)
    isBlocked = true
    norm = float3(0., 1., 0.)
  let inArea = length_sq(traceEnd - tracePos) < slave_unit_preview__radius * slave_unit_preview__radius
  let isAngleValid = check_inclination_angles(norm, slave_unit_preview__availableAngles)
  if isAngleValid
    slave_unit__transform[1] = norm
  slave_unit__transform[2] = normalize(cross(slave_unit__transform[1], -traceDir))
  slave_unit__transform[0] = normalize(cross(slave_unit__transform[1], slave_unit__transform[2]))
  slave_unit__transform[3] = traceEnd
  var unit = unit__ref.unit
  if unit == null
    return
  *unit |> teleportToPos(false, slave_unit__transform[3])
  unit.setOrientation(slave_unit__transform[0], slave_unit__transform[1]);
  if info.curTime > nextCheckGridObjectsTime
    var isValid = (inArea &&
                   isAngleValid &&
                   !isBlocked &&
                   !is_collide_with_unit(slave_unit__transform * unit.boundingBox, hero.eid, -1))
    if isValid
      if vehicle_phys_getCollisionObjectsCount(vehicle_net_phys.phys) > 0
        isValid = isValid && !is_unit_conflict_with_world(slave_unit__transform, vehicle_phys_getCollisionObject(vehicle_net_phys.phys, 0),
        slave_unit_preview__collObjOffset, unit.boundingSphereRad)
    nextCheckGridObjectsTime = info.curTime + checkGridObjectsTimeInterval
    slave_unit_preview__canSpawn = !isValid

[es(tag=gameClient, on_event=CmdTrySpawnSlave, after=spawn_slave_ability_update_es)]
def try_spawn_slave_object_es(evt : Event;
                              unit__ref : UnitRef;
                              slave_unit_preview__radius : float;
                              slave_unit_preview__availableAngles : float2;
                              slave_unit__transform : float3x4;
                              slave_unit_preview__collObjOffset : float;
                              vehicle_net_phys : VehiclePhysActor)
  var hero = get_controlled_hero()
  if hero == null || hero.isDelayed || !hero.isAlive
    return
  var slave = unit__ref.unit
  if slave == null
    return
  var riDesc = RendInstDesc()
  var len = slave_unit_preview__radius + 1.
  var riMatId = PHYSMAT_INVALID
  let rayMatId = PHYSMAT_INVALID
  var norm : float3
  let tracePos = get_camera_orig_pos()
  let traceDir = get_turret_aim_vector()
  var isBlocked = false
  traceray_normalized(tracePos, traceDir, len, riMatId, norm, ETF_ALL | ETF_RI_PHYS, riDesc, rayMatId)
  if riDesc.riExtraHandle != RIEX_HANDLE_NULL
    isBlocked = true
  let traceEnd = tracePos + traceDir * len
  let outOfRange = length_sq(traceEnd - tracePos) > slave_unit_preview__radius * slave_unit_preview__radius
  var hasObstacles = (outOfRange || isBlocked ||
                     traceray_water_at_time(tracePos, traceEnd, float(get_app().usefulTotalTime), len) ||
                     !check_inclination_angles(norm, slave_unit_preview__availableAngles) ||
                     is_collide_with_unit(slave_unit__transform * slave.boundingBox, hero.eid, -1))
  if !hasObstacles
    if vehicle_phys_getCollisionObjectsCount(vehicle_net_phys.phys) > 0
      hasObstacles = hasObstacles || is_unit_conflict_with_world(slave_unit__transform, vehicle_phys_getCollisionObject(vehicle_net_phys.phys, 0),
      slave_unit_preview__collObjOffset, slave.boundingSphereRad)
  if outOfRange
    using() <| $(var eventData : DataBlock)
      hud_notify_script("hint:slave_forbidden_range:show", eventData)
  elif hasObstacles
    using() <| $(var eventData : DataBlock)
      hud_notify_script("hint:slave_forbidden_obstacles:show", eventData)
  else
    let fcm = get_flight_control_mode()
    fcm.ctrlMap |> toggleSlaveUnitSpawn()
    let supportIdx = find_support_plane_index(hero, slave)
    *hero |> requestLaunchOrSwitchOnSupportPlane(true, false, supportIdx, slave_unit__transform)