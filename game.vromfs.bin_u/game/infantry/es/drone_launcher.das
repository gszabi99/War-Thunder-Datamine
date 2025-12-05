require ecs
require app

require %appGame.wt_events
require %appGame.infantry.es.drone_launcher_common
require %appGame.infantry.es.loc_squad_common
require DagorMath
require DngHuman
require Plane
require FlightModelWrap
require Dacoll
require net


def is_there_space_for_drone(soldier_transform : float3x4; offset : float3) : bool
  let beltHeightPosition = soldier_transform * float3(0., 1., 0.)
  let wishDronePosition  = soldier_transform * offset

  var castRes = ShapeQueryOutput()
  return !sphere_cast(beltHeightPosition, wishDronePosition, 0.2, castRes, -1)


def drone_launcher_server_report_fail_launch(drone_launcher__eid : EntityId)
  send_net_event(drone_launcher__eid, ResponseDroneLauncherFailLaunch())


def check_space_for_launching_drone(human_eid : EntityId;
                                    position_offset : float3)
  if human_eid == INVALID_ENTITY_ID
    return false

  var ccdTm : float3x4
  var truePositionOffset = position_offset
  query(human_eid) <| $ [es] (human_net_phys : HumanActor)
    human_net_phys.phys.currentState.location |> location_toTM(ccdTm)
    let dirQuat = dir_to_quat(human_net_phys.phys.appliedCT.wishLookDir)
    truePositionOffset = dirQuat * position_offset
  return is_there_space_for_drone(ccdTm, truePositionOffset)


def create_drone_entity(transform : float3x4; droneTemplate : string; ownerEid : EntityId; playerEid : EntityId; team : int; launcherEid : EntityId; enableSound : bool)
  return createEntity(droneTemplate) <| $(var init)
    set(init, "drone__owner", ownerEid)
    set(init, "ownedByPlr", playerEid)
    set(init, "unit_params__supportUnitIdx", 0) 
    set(init, "drone__launcherEid", launcherEid)
    set(init, "transform", transform)
    set(init, "team", team)
    set(init, "drone__soundEnabled", enableSound)
    set(init, "sound_control__allowSound", enableSound)


[es(tag=server, REQUIRE=isDrone, on_event=(CmdDestroyDrone, EventPlayerUnitControlLost), on_disappear)]
def reset_drone_launcher_on_drone_destroy_server(evt : Event;
                                                 eid aka drone_eid : EntityId;
                                                 drone__launcherEid : EntityId)
  query(drone__launcherEid) <| $ [es] (drone_launcher__cooldown : float;
                                       var drone_launcher__drone : EntityId&;
                                       var drone_launcher__state : int&;
                                       var drone_launcher__nextUseAtTime : float&)
    if drone_launcher__drone != drone_eid
      return
    drone_launcher__drone = INVALID_ENTITY_ID
    drone_launcher__state = int(DroneLauncherState.DLS_OFFLINE)
    drone_launcher__nextUseAtTime = get_sync_time() + drone_launcher__cooldown


[es(tag=server, track=gun__owner, on_appear)]
def drone_launcher_on_owner_changed(evt : Event;
                                    eid aka drone_launcher__eid : EntityId;
                                    gun__owner aka drone_launcher_gun__owner : EntityId;
                                    var drone_launcher__tacticalPhone : EntityId&)
  query(drone_launcher__tacticalPhone) <| $ [es] (var tactical_phone__droneLauncher : EntityId&)
    tactical_phone__droneLauncher = INVALID_ENTITY_ID
  find_query() <| $ [es] (eid aka tactical_phone__eid : EntityId;
                          gun__owner aka tactical_phone_gun__owner : EntityId;
                          var tactical_phone__droneLauncher : EntityId&)
    if drone_launcher_gun__owner != tactical_phone_gun__owner
      return false
    drone_launcher__tacticalPhone = tactical_phone__eid
    tactical_phone__droneLauncher = drone_launcher__eid
    return true


[es(on_appear)]
def drone_launcher_appear(evt : Event;
                          drone_launcher__firstLaunchTimeout : float;
                          var drone_launcher__state : int&;
                          var drone_launcher__nextUseAtTime : float&)
  drone_launcher__state = drone_launcher__firstLaunchTimeout > 0.0 ? int(DroneLauncherState.DLS_OFFLINE) : int(DroneLauncherState.DLS_READY)
  drone_launcher__nextUseAtTime = get_sync_time() + drone_launcher__firstLaunchTimeout


[es(tag=server, on_appear)]
def drone_launcher_appear_server(evt : Event;
                                 var drone_launcher_launch__velocityDir : float3&)
  drone_launcher_launch__velocityDir = normalize(drone_launcher_launch__velocityDir)


[es(tag=server)]
def drone_launcher_on_instant_launch_request(evt : RequestDroneLauncherInstantLaunch;
                                             eid aka human_eid : EntityId;
                                             possessedByPlr : EntityId;
                                             human_weap__currentGunEid : EntityId;
                                             team : int;
                                             var beh_tree__wantRoleDroner : bool&)
  query(evt.droneLauncherEid) <| $ [es] (gun__owner : EntityId;
                                         drone_launcher__tacticalPhone : EntityId;
                                         drone_launcher__droneTemplate : string;
                                         drone_launcher__cooldown : float;
                                         drone_launcher__instantLaunchFromPhone : bool;
                                         var drone_launcher__drone : EntityId&;
                                         var drone_launcher__state : int&;
                                         var drone_launcher__nextUseAtTime : float&)
    if human_eid != gun__owner || human_weap__currentGunEid != drone_launcher__tacticalPhone
      return

    let time = get_sync_time()
    let droneAlreadyExists = drone_launcher__drone != INVALID_ENTITY_ID
    let isCooldown = time < drone_launcher__nextUseAtTime
    let respawn = get_respawn_base_for_drone(team)
    if droneAlreadyExists || isCooldown || (respawn is nothing) || !drone_launcher__instantLaunchFromPhone
      drone_launcher_server_report_fail_launch(evt.droneLauncherEid)
      return

    beh_tree__wantRoleDroner = true

    drone_launcher__drone = create_drone_entity(respawn as transform, drone_launcher__droneTemplate, human_eid, possessedByPlr, team, evt.droneLauncherEid, true)
    drone_launcher__nextUseAtTime = time + drone_launcher__cooldown
    drone_launcher__state = int(DroneLauncherState.DLS_LAUNCHED)


[es(tag=server)]
def drone_launcher_on_start_launch_request(evt : RequestDroneLauncherStartLaunch;
                                           eid aka human_eid : EntityId;
                                           human_weap__currentGunEid : EntityId;
                                           var beh_tree__wantRoleDroner : bool&)
  if human_weap__currentGunEid != evt.droneLauncherEid
    return

  query(evt.droneLauncherEid) <| $ [es] (gun__owner : EntityId;
                                         drone_launcher__nextUseAtTime : float;
                                         drone_launcher_anim__launchTime : float;
                                         drone_launcher__instantLaunchFromPhone : bool;
                                         drone_launcher__drone : EntityId&;
                                         var drone_launcher__state : int&;
                                         var drone_launcher_launch__start : float&;
                                         var drone_launcher_launch__applyTransformAndVelocityStatus : bool&;
                                         var drone_launcher_launch__enableSoundStatus : bool&;
                                         var drone_launcher_launch__replaceStatus : bool&;
                                         var drone_launcher_launch__controlStatus : bool&;
                                         var drone_launcher_anim__launchStart : float&;
                                         var drone_launcher_anim__launchEnd : float&;
                                         var drone_launcher_anim__replaceAnimationWithEntity : bool&)
    if human_eid != gun__owner
      return

    let droneAlreadyExists = drone_launcher__drone != INVALID_ENTITY_ID
    let isCooldown = evt.atTime < drone_launcher__nextUseAtTime
    let requestTimeIsTooOld = (get_sync_time() - evt.atTime) > 0.4 
    let requestTimeIsFuture = get_sync_time() < evt.atTime 

    if droneAlreadyExists || requestTimeIsTooOld || requestTimeIsFuture || isCooldown || drone_launcher__instantLaunchFromPhone
      drone_launcher_server_report_fail_launch(evt.droneLauncherEid)
      return

    beh_tree__wantRoleDroner = true

    drone_launcher__state = int(DroneLauncherState.DLS_LAUNCH)
    drone_launcher_launch__start = evt.atTime
    drone_launcher_launch__applyTransformAndVelocityStatus = false
    drone_launcher_launch__enableSoundStatus = false
    drone_launcher_launch__replaceStatus = false
    drone_launcher_launch__controlStatus = false

    drone_launcher_anim__launchStart = evt.atTime
    drone_launcher_anim__launchEnd = evt.atTime + drone_launcher_anim__launchTime
    drone_launcher_anim__replaceAnimationWithEntity = false


def get_drone_transform_relative_to_human(human_net_phys : HumanActor;
                                          position_offset : float3 = float3(0.0, 0.0, 0.0))
  var droneTm : float3x4
  human_net_phys.phys.currentState.location |> location_toTM(droneTm)
  if length_sq(position_offset) > 0.0
    let dirQuat = dir_to_quat(human_net_phys.phys.appliedCT.wishLookDir)
    let truePositionOffset = dirQuat * position_offset
    make_tm(dirQuat, droneTm[3] + truePositionOffset, droneTm)
  return droneTm


[es(tag=server, on_appear)]
def init_drone_speed_es(evt : Event;
                        transform : float3x4;
                        drone__start_velocity_dir : float3;
                        drone__start_velocity_speed : float;
                        var plane_net_phys : PlaneActor)
  if drone__start_velocity_speed > 0.0
    let startDir = normalize(transform[0] * drone__start_velocity_dir.x + transform[1] * drone__start_velocity_dir.y + transform[2] * drone__start_velocity_dir.z)
    plane_net_phys.phys |> flight_model_setVelocityRough(startDir * drone__start_velocity_speed)


[es(tag=server, after=drone_launcher_on_start_launch_request)]
def drone_launcher_launching_server(info : UpdateStageInfoAct;
                                    eid : EntityId;
                                    gun__owner : EntityId;
                                    var drone_launcher__drone : EntityId&;
                                    drone_launcher__nextUseAtTime : float;
                                    drone_launcher__droneTemplate : string;
                                    drone_launcher_launch__positionOffset : float3;
                                    drone_launcher_launch__start : float;
                                    drone_launcher_launch__enableSoundTime : float;
                                    drone_launcher_launch__replaceTime : float;
                                    drone_launcher_launch__controlTime : float;
                                    var drone_launcher_launch__enableSoundStatus : bool&;
                                    var drone_launcher_launch__replaceStatus : bool&;
                                    var drone_launcher_launch__controlStatus : bool&;
                                    var drone_launcher__state : int&;
                                    var drone_launcher_anim__replaceAnimationWithEntity : bool&)
  if drone_launcher__state == int(DroneLauncherState.DLS_OFFLINE)
    if info.curTime >= drone_launcher__nextUseAtTime
      drone_launcher__state = int(DroneLauncherState.DLS_READY)

  if drone_launcher__state != int(DroneLauncherState.DLS_LAUNCH)
    return

  let delta = info.curTime - drone_launcher_launch__start

  if !drone_launcher_launch__enableSoundStatus && delta >= drone_launcher_launch__enableSoundTime
    query(drone_launcher__drone) <| $ [es] (var drone__soundEnabled : bool&)
      drone__soundEnabled = true
    drone_launcher_launch__enableSoundStatus = true

  if !drone_launcher_launch__replaceStatus && delta >= drone_launcher_launch__replaceTime
    drone_launcher_anim__replaceAnimationWithEntity = true
    drone_launcher_launch__replaceStatus = true

  if !drone_launcher_launch__controlStatus && delta >= drone_launcher_launch__controlTime
    query(gun__owner) <| $ [es] (human_net_phys : HumanActor;
                                 possessedByPlr : EntityId;
                                 team : int)
      let droneTm = get_drone_transform_relative_to_human(human_net_phys, drone_launcher_launch__positionOffset)
      drone_launcher__drone = create_drone_entity(droneTm, drone_launcher__droneTemplate, gun__owner, possessedByPlr, team, eid, true)
      drone_launcher_launch__controlStatus = true

  if drone_launcher_launch__enableSoundStatus && drone_launcher_launch__replaceStatus && drone_launcher_launch__controlStatus
    drone_launcher__state = int(DroneLauncherState.DLS_LAUNCHED)


[es(tag=server, REQUIRE=drone_launcher, on_disappear)]
def on_drone_launcher_disappear(evt : Event;
                                gun__owner : EntityId;
                                drone_launcher__drone : EntityId)
  send_net_event(gun__owner, CmdRequestDestroyDrone(droneEid = drone_launcher__drone))
