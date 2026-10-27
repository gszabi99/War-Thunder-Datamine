require ecs
require WTPhysActor
require DngHuman
require HumanPhys
require math
require math.base
require math.ang
require DagorMath
require DagorMathUtils
require AnimV20
require WTInput
require %game.events
require %appGame.infantry.es.human_weap_common

def private is_aiming_through_subsidiary_sight(gun_eid : EntityId) : bool
  var res = false
  query(gun_eid) <| $ [es] (gun_anim__weapModEid : EntityId; weap__sightEid : EntityId)
    if !gun_anim__weapModEid || weap__sightEid != gun_anim__weapModEid
      return
    query(gun_anim__weapModEid) <| $ [es(REQUIRE=sightPresets)] (weapon_mod__active : bool)
      res = weapon_mod__active
  return res

[es(on_event=(EventUnitRespawn, EventUnitSpawned))]
def human_look_dir_camera_reset_sight_turn_es(evt : Event;
                                              camera__gunAimOffset : float2;
                                              var camera__prevGunAimOffset : float2&;
                                              var camera__appliedSightTurn : float2&)
  camera__prevGunAimOffset = camera__gunAimOffset
  camera__appliedSightTurn = float2(0.0, 0.0)

[es(after=after_net_phys_sync)]
def human_look_dir_camera_es(info : ParallelUpdateFrameDelayed;
                             camera__active : bool;
                             camera__target : EntityId)
  if !camera__active
    return
  query(camera__target) <| $ [es(REQUIRE_NOT=deadEntity)] (var human_net_phys : HumanActor;
                                                           var camera__prevGunAimOffset : float2&;
                                                           var camera__appliedSightTurn : float2&;
                                                           var camera__shootOffset : float2&;
                                                           var camera__prevLookDir : float3&;
                                                           var camera__lookDir : float3&;
                                                           var human_input__aimAngle : float2?;
                                                           var human_input__oldAimAngle : float2?;
                                                           human_input__currentVertLookAngleLimit : float2 const?;
                                                           camera__gunAimOffset : float2;
                                                           human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                                                           camera__shootOffsetTau : float = 0.05f;
                                                           camera__breathOffsetAimMult : float = 0.7;
                                                           isInVehicle : bool = false;
                                                           bipod__enabled : bool = false)
    let sightTurn = camera__gunAimOffset - camera__prevGunAimOffset
    camera__prevGunAimOffset = camera__gunAimOffset

    assume ct = human_net_phys.phys.producedCT
    let interpK = get_phys_interpk_clamped(human_net_phys.phys, info.curTime)
    let aimPosition = lerp(human_net_phys.phys.previousState.aimPosition, human_net_phys.phys.currentState.aimPosition, interpK)

    
    if (human_net_phys.isLocalControl && human_input__aimAngle != null && human_input__oldAimAngle != null
        && human_input__currentVertLookAngleLimit != null)
      let isCompensating = !isInVehicle && aimPosition >= 1.0 && is_aiming_through_subsidiary_sight(human_weap__currentGunEid)
      var turn = isCompensating ? sightTurn : -camera__appliedSightTurn
      if turn.x != 0.0 || turn.y != 0.0
        let aim = *human_input__aimAngle
        let limit = deg_to_rad(*human_input__currentVertLookAngleLimit)
        let lo = min(max(limit.x, -SAFE_HALF_PI), aim.y)
        let hi = max(min(limit.y, SAFE_HALF_PI), aim.y)
        turn.y = aim.y - clamp(aim.y - turn.y, lo, hi)
        *human_input__aimAngle -= turn
        *human_input__oldAimAngle -= turn
        let lookDir = angles_to_dir(dir_to_angles(ct.wishLookDir) - turn)
        human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(lookDir)
        camera__shootOffset += turn
        camera__appliedSightTurn += turn

    if isInVehicle
      return
    camera__prevLookDir = camera__lookDir

    var ang : float2
    if (int(human_net_phys.role) & int(NetRole.URF_LOCAL_CONTROL)) != 0
      ang = dir_to_angles(ct.wishLookDir)
    else
      
      
      ang = dir_to_angles(human_net_phys.phys.currentState.gunDir)

    var aimOffs = lerp(human_net_phys.phys.previousState.gunAimOffset, human_net_phys.phys.currentState.gunAimOffset, float2(interpK))
    aimOffs += camera__gunAimOffset

    camera__shootOffset = approach(camera__shootOffset, aimOffs, info.dt, camera__shootOffsetTau)
    ang += camera__shootOffset

    
    
    if aimPosition > 0.0 && camera__breathOffsetAimMult > 0.0 && !bipod__enabled
      let breathOffset = lerp(human_net_phys.phys.previousState.breathOffset, human_net_phys.phys.currentState.breathOffset, float2(interpK))
      ang += breathOffset * aimPosition * camera__breathOffsetAimMult

    ang.y = clamp(ang.y, -SAFE_HALF_PI, SAFE_HALF_PI)
    camera__lookDir = angles_to_dir(ang)


[es(after=human_look_dir_camera_es, REQUIRE=watchedHero, REQUIRE_NOT=isReplayObserved)]
def human_look_dir_camera_in_vehicle_es(info : ParallelUpdateFrameDelayed;
                                        isInVehicle : bool;
                                        isAlive : bool;
                                        human_net_phys : HumanActor;
                                        human_vehicle__isHoldingGunPassenger : bool = false;
                                        var camera__lookDir : float3&)
  if !isInVehicle || !isAlive || !human_vehicle__isHoldingGunPassenger
    return
  assume ct = human_net_phys.phys.producedCT
  var ang = dir_to_angles(ct.wishLookDir)
  ang.y = clamp(ang.y, -SAFE_HALF_PI, SAFE_HALF_PI)
  camera__lookDir = angles_to_dir(ang)


[es(after=human_look_dir_camera_in_vehicle_es)]
def vehicle_passenger_freelook_camera_es(info : ParallelUpdateFrameDelayed;
                                         camera__active : bool;
                                         camera__target : EntityId;
                                         var vehicle_passenger_camera__relAngle : float2&)
  if !camera__active
    return
  var mouseAngles = get_mouse_axes_delta()
  mouseAngles.y *= 0.5
  query(camera__target) <| $ [es(REQUIRE_NOT=deadEntity)] (var camera__lookDir : float3&;
                                                           vehicle__globalSeatTm : float3x4;
                                                           isInVehicle : bool = false;
                                                           human_vehicle__isHoldingGunPassenger = false;
                                                           vehicle_passenger_camera__maxAngleDeg : float2 = float2(90.0, 60.0))
    if !isInVehicle || human_vehicle__isHoldingGunPassenger
      vehicle_passenger_camera__relAngle = float2(0., 0.)
      return
    let maxAngleRad = deg_to_rad(vehicle_passenger_camera__maxAngleDeg)
    vehicle_passenger_camera__relAngle.x = clamp(vehicle_passenger_camera__relAngle.x + mouseAngles.x, -maxAngleRad.x, maxAngleRad.x)
    vehicle_passenger_camera__relAngle.y = clamp(vehicle_passenger_camera__relAngle.y + mouseAngles.y, -maxAngleRad.y, maxAngleRad.y)
    let seatAngles = dir_to_angles(vehicle__globalSeatTm[0])
    var worldAng = seatAngles + vehicle_passenger_camera__relAngle
    worldAng.y = clamp(worldAng.y, -SAFE_HALF_PI, SAFE_HALF_PI)
    camera__lookDir = angles_to_dir(worldAng)


[es(after=vehicle_passenger_freelook_camera_es)]
def vehicle_passenger_freelook_sync_aim_es(info : ParallelUpdateFrameDelayed;
                                           camera__active : bool;
                                           camera__target : EntityId)
  if !camera__active
    return
  query(camera__target) <| $ [es(REQUIRE_NOT=deadEntity)] (camera__lookDir : float3;
                                                           human_net_phys__prevVertDir : float3;
                                                           var human_input__aimAngle : float2&;
                                                           var human_input__lookAngle : float2&;
                                                           var human_net_phys : HumanActor;
                                                           isInVehicle : bool = false;
                                                           human_vehicle__isHoldingGunPassenger = false)
    if !isInVehicle || human_vehicle__isHoldingGunPassenger
      return
    if (int(human_net_phys.role) & int(NetRole.URF_LOCAL_CONTROL)) == 0
      return
    let rootDir = get_some_normal(human_net_phys__prevVertDir)
    human_input__aimAngle = basis_aware_dir_to_angles(camera__lookDir, human_net_phys__prevVertDir, rootDir)
    human_input__lookAngle = float2(0., 0.)
    human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(camera__lookDir)
    human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(camera__lookDir)


[es(tag=gameClient, track=isInVehicle, on_appear)]
def vehicle_passenger_disable_camera_stabilization_es(evt : Event;
                                                      isInVehicle : bool;
                                                      var camera__isStabilized : bool&)
  camera__isStabilized = !isInVehicle


[es(after=human_look_dir_camera_es, REQUIRE=watchedHero, REQUIRE=deadEntity)]
def human_look_dir_dead_camera_es(info : ParallelUpdateFrameDelayed;
                                  eid : EntityId;
                                  transform : float3x4&;
                                  death_cam__killer : EntityId;
                                  death_cam__followTime : float;
                                  deatch_cam__viscosity : float2;
                                  var death_cam__startedAt : float&;
                                  var camera__lookDir : float3&)
  if death_cam__killer == eid
    return

  let killerTm = get_TMatrix(death_cam__killer, "transform")
  if killerTm != null
    if death_cam__startedAt < 0.0
      death_cam__startedAt = info.curTime
    if info.curTime > death_cam__startedAt + death_cam__followTime
      return

    let wishLookDir = normalize((*killerTm)[3] - transform[3])
    let viscosityPercent = cvt(info.curTime, death_cam__startedAt, death_cam__startedAt + death_cam__followTime, 0.0, 1.0)
    let viscosity = deatch_cam__viscosity[0] + deatch_cam__viscosity[1] * viscosityPercent * viscosityPercent
    camera__lookDir = approach(camera__lookDir, wishLookDir, info.dt, viscosity)


[es(after=human_look_dir_camera_es, REQUIRE=watchedHero, tag=ui)]
def look_hero_compass_angle_es(info : UpdateStageInfoAct;
                               var compass__forwardAngle : int&;
                               camera__lookDir : float3)
  let lookAngles = dir_to_angles(camera__lookDir)
  let angle = roundi(rad_to_deg(lookAngles.x)) + 90
  compass__forwardAngle = (angle + 360) % 360
