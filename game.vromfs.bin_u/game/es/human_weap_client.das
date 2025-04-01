require ecs
require %appGame.es.human_weap_common
require %game.events
require math.base
require math.ang
require HumanPhys
require DngHuman
require DaWeapons
require DngWeapon

require DagorMath
require DagorMathUtils
require DagorSystem

require Grid
require GridCollision
require CollisionTraces
require Dacoll
require CollRes
require AnimV20
require GeomNodeTree


def do_gun_traceray(from : float3; dir : float3; var t : float&; ray_mat_id : int; ignore_human_eid : EntityId)
  var retEid = INVALID_ENTITY_ID
  var pmid : int
  var norm : float3
  using() <| $(var desc : RendInstDesc#)
    traceray_normalized(from, dir, t, pmid, norm, 127, desc, ray_mat_id)
  using() <| $(var intersections : IntersectedEntities)
    trace_entities_in_grid(ecs_hash("humans"), from, dir, t, ignore_human_eid, intersections, SortIntersections NO)
    trace_entities_in_grid(ecs_hash("vehicles"), from, dir, t, ignore_human_eid, intersections, SortIntersections YES)
    for isect in intersections
      if get_bool(isect.eid, "animchar__visible") ?? true
        retEid = isect.eid
        break
  return retEid

def get_active_camera_tm()
  var tm = IDENT_TM
  query() <| $ [es] (camera__active : bool;
                     transform : float3x4)
    if camera__active
      tm = transform
  return tm

[es(REQUIRE=(human_input, human_weap))]
def human_weap_trace_es(info : ParallelUpdateFrameDelayed;
                        eid : EntityId;
                        human_net_phys : HumanActor;
                        human_weap__prevGunAngles : float2&;
                        var human_weap__traceIntersectedEid : EntityId&;
                        var human_weap__tracerayLen : float&;
                        isDowned : bool = false;
                        isAlive : bool = true)
  if !isAlive || isDowned || human_net_phys.phys.currentState |> human_phys_state_attachedToLadder
    return
  let gunDir = angles_to_dir(human_weap__prevGunAngles)
  let gunEid = get_human_gun_eid(eid)
  if gunEid != INVALID_ENTITY_ID
    query(gunEid) <| $ [es] (gun__aimRayMatId : int = -1)
      
      let cameraTm = get_active_camera_tm()
      let camPos = cameraTm[3]
      human_weap__tracerayLen = 100.0
      human_weap__traceIntersectedEid = do_gun_traceray(camPos, gunDir, human_weap__tracerayLen, gun__aimRayMatId, eid)

[es(after=(human_weap_client_es, human_phys_es, human_weap_reload_es, human_weap_mod_active_update_es), before=(hero_medic_select_damaged_human_es, human_vehicle_seats_non_shooter_pre_animchar_es, after_guns_update_sync, human_attached_gun_rotate_body), REQUIRE=(controlledHero, human_weap))]
def human_weap_update_es(info : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         human_weap__gunAngleTau : float;
                         isInVehicle : bool = false;
                         human_vehicle__isHoldingGunPassenger : bool = false;
                         human_weap__crawlClampVertAngleRad : float2;
                         human_weap__clampVertAngleRad : float2;
                         human_weap__aimInertia : float2;
                         human_weap__currentGunEid : EntityId;
                         human_weap__grenadeThrower : EntityId = INVALID_ENTITY_ID;
                         human_weap__lockedGrenadeThrowingCounter : int = 0;
                         human_weap__mortarMode : bool = false;
                         human_weap__jumpDeviation : float = 0.;
                         human_weap__changePosDeviationCanAim : float = 0.;
                         human_weap__changePosDeviationCanNotAim : float = 0.;
                         human_phys__afterJumpDelay : float = 0.;
                         human_phys__jumpEndTime : float;
                         human_phys__isInAirLong : bool;
                         isDowned : bool = false;
                         isAlive : bool = true;
                         bipod__enabled : bool = false;
                         entity_mods__shotDeviationMult : float = 1.0;
                         entity_mods__rotationShotSpreadDecrMult : float = 1.0;
                         entity_mods__aimingAfterFireMult : float = 1.0;
                         entity_mods__boltActionMult : float = 1.0;
                         entity_mods__deviationBufferSizeMult : float = 1.0;
                         grenade_rethrow__grenadeEid : EntityId const? = null;
                         entity_mods__shotDeviationAdd : float = 0.0;
                         human_weap__fastThrowExclusive : bool = true;
                         human_weap__maxParallaxDeviation : float = 10.0;
                         human_weap__extraGunSpeedOnJump : float = 0.0;
                         human_weap__maxGunVisualAngleDeviation : float = 10.;
                         human_unarmed__active : bool = false;
                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                         human_weap__tracerayLen : float&;
                         isReplayObserved : Tag const?;
                         var human_net_phys : HumanActor;
                         var transform : float3x4;
                         var human_weap__gunEids : EidList;
                         var human_weap__throwMode : bool&;
                         var human_weap__prevGunAngles : float2&;
                         var human_weap__gunAngleSpeed : float2&)
  if !isAlive || isDowned || human_net_phys.phys.currentState |> human_phys_state_attachedToLadder
    return

  let dt = info.dt
  var atTime = info.curTime

  
  
  assume ct = (isReplayObserved == null && human_net_phys.isLocalControl) ? human_net_phys.phys.producedCT : human_net_phys.phys.appliedCT
  if ct |> is_control_bit_set(HumanPhysControlType HCT_SHOOT) && !ct.haveUnenqueuedHctShoot
    atTime = floor(atTime / human_net_phys.phys.timeStep) * human_net_phys.phys.timeStep

  let isForReal = true
  let wishGunDir = ct.wishShootDir
  var gunDir = wishGunDir
  let gunAnglesOffset = human_weap__aimInertia
  var gunAngles = dir_to_angles(gunDir) + gunAnglesOffset
  gunAngles.y = clamp(gunAngles.y, -SAFE_HALF_PI, SAFE_HALF_PI)
  var gunSpeedAng = gunAngles - human_weap__prevGunAngles
  gunSpeedAng.x = norm_s_ang(gunSpeedAng.x)
  let isInAir = (int(human_net_phys.phys.currentState.isInAirHistory) & 1) != 0
  if human_weap__extraGunSpeedOnJump > 0.0 && isInAir
    let humanVel = human_net_phys.phys.currentState.velocity
    let dir = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType HCT_AIM) ? 1.0 : -1.0
    let extraGunSpeedOnJump = human_weap__extraGunSpeedOnJump
    gunSpeedAng.y += dir * cvt(humanVel.y, -1.0, 1.0, -extraGunSpeedOnJump, extraGunSpeedOnJump)
  let gunSpeed = gunSpeedAng * safeinv(dt)
  human_weap__gunAngleSpeed = approach(human_weap__gunAngleSpeed, gunSpeed, dt, human_weap__gunAngleTau)
  human_weap__prevGunAngles = gunAngles

  assume phys = human_net_phys.phys
  if !human_weap__mortarMode && !bipod__enabled
    let vertLimits = phys.currentState.isCrawl ? human_weap__crawlClampVertAngleRad : human_weap__clampVertAngleRad
    apply_gun_angle_offsets(phys, atTime, vertLimits, gunAngles)
  gunDir = angles_to_dir(gunAngles)

  let up = transform[1]
  var horzDir = normalize(gunDir - dot(gunDir, up) * up)

  assume prevState = phys.previousState
  assume curState  = phys.currentState
  if prevState.moveState == HUMoveState EMS_SPRINT || curState.moveState == HUMoveState EMS_SPRINT
    let from = prevState.moveState == HUMoveState EMS_SPRINT ? 1.0 : 0.0
    let to = curState.moveState == HUMoveState EMS_SPRINT ? 1.0 : 0.0
    let interpK = get_phys_interpk_clamped(phys, atTime)
    horzDir = slerp(dir_to_quat(horzDir), dir_to_quat(transform[0]), lerp(from, to, interpK)) |> quat_get_forward()
  transform[0] = horzDir
  transform |> orthonormalize()

  var gunShootDir = gunDir
  let gunEid = get_human_gun_eid(eid)
  if gunEid != INVALID_ENTITY_ID  && human_weap__tracerayLen != 0.
    query(gunEid) <| $ [es(REQUIRE_NOT=mortar)] (gun : Gun; animchar : AnimcharBaseComponent)
      
      let cameraTm = get_active_camera_tm()
      let camPos = cameraTm[3]
      let shootTm = gun.shootNodeData |> gun_shoot_node_data_calcShootTm(gunDir, transform, transform)
      let shootPos = shootTm[3]
      gunShootDir = normalize(camPos + gunDir * human_weap__tracerayLen - shootPos)
      let initialGunAngles = dir_to_angles(gunDir)
      var wishGunAngles = dir_to_angles(gunShootDir)
      let angDevRad = deg_to_rad(human_weap__maxParallaxDeviation)
      wishGunAngles.x = clamp(renorm_ang(wishGunAngles.x, initialGunAngles.x), initialGunAngles.x - angDevRad,
                                                                               initialGunAngles.x + angDevRad)
      wishGunAngles.y = clamp(wishGunAngles.y, initialGunAngles.y - angDevRad, initialGunAngles.y + angDevRad)
      gunShootDir = angles_to_dir(wishGunAngles)

      var visualTm : float3x4
      geomtree_getNodeWtmScalar(*animchar.nodeTree, 0, visualTm)
      let visualGunDir = normalize(-visualTm[2])
      if !human_weap__throwMode && dot(visualGunDir, gunShootDir) < cos(deg_to_rad(human_weap__maxGunVisualAngleDeviation))
        gunShootDir = visualGunDir

  let updCtx = [[GunUpdateCtx
    dt=dt,
    atTime=atTime,
    isForReal=isForReal,
    eid=eid,
    isDowned=isDowned,
    isThrowingAllowed=human_weap__lockedGrenadeThrowingCounter == 0 && (human_vehicle__isHoldingGunPassenger || !isInVehicle),
    shotDeviationMult=entity_mods__shotDeviationMult,
    rotationShotSpreadDecrMult=entity_mods__rotationShotSpreadDecrMult,
    aimingAfterFireMult=entity_mods__aimingAfterFireMult,
    boltActionMult=entity_mods__boltActionMult,
    shotDeviationAdd=entity_mods__shotDeviationAdd,
    fastThrowExclusive=human_weap__fastThrowExclusive,
    deviationBufferSizeMult=entity_mods__deviationBufferSizeMult]]

  let physTransform = human_net_phys.phys.currentState.location |> location_makeTM()
  human_weap_gun_update(human_net_phys, human_weap__gunEids, human_weap__throwMode,
                        updCtx, transform, gunDir, gunShootDir, physTransform,
                        ct, grenade_rethrow__grenadeEid,
                        human_unarmed__active, human_attached_gun__attachedGunEid, human_weap__currentGunEid,
                        human_weap__jumpDeviation, human_weap__changePosDeviationCanAim, human_weap__changePosDeviationCanNotAim,
                        human_weap__grenadeThrower, human_phys__jumpEndTime, human_phys__afterJumpDelay, human_phys__isInAirLong, bipod__enabled)

[es(tag=gameClient, after=human_weap_update_es, REQUIRE=(hero, human_weap), REQUIRE_NOT=deadEntity)]
def human_weapon_inertia(info : ParallelUpdateFrameDelayed;
                         isAlive : bool;
                         isDowned : bool;
                         isInVehicle : bool;
                         human_net_phys : HumanActor;
                         human_input__gunToAimAngleLimit : float2;
                         human_input__aimAngle : float2;
                         human_input__oldAimAngle : float2;
                         human_weap__currentGunEid : EntityId;
                         human_weap__aimInertiaCrouchMult : float;
                         human_weap__aimInertiaCrawlMult : float;
                         human_weap__aimInertiaAimingMult : float;
                         human_weap__aimInertiaStrengthMult : float;
                         human_weap__aimInertiaDampingMult : float;
                         human_weap__aimInertiaStiffnessMultStart : float;
                         human_weap__aimInertiaStiffnessMultEnd : float;
                         human_weap__aimInertiaDampingMultStart : float;
                         human_weap__aimInertiaDampingMultEnd : float;
                         human_weap__aimInertiaBoostInterval : float2;
                         human_weap__aimInertiaDeltaTime : float;
                         human_weap__aimInertiaMaxMult : float;
                         human_weap__aimInertiaVelocityMax : float;
                         human_weap__aimInertiaMinWeight : float;
                         human_weap__aimInertiaViscosity : float;
                         human_weap__crawlClampVertAngleRad : float2;
                         human_weap__clampVertAngleRad : float2;
                         var human_weap__aimInertia : float2&;
                         var human_weap__aimInertiaVelocity : float2&;
                         var human_weap__aimInertiaLastTick : int&;
                         var human_weap__aimInertiaLocal : float2&)
  if human_weap__aimInertiaLastTick < 0
    human_weap__aimInertiaLastTick = int(safediv(info.curTime, human_weap__aimInertiaDeltaTime))
    return

  assume inertia = human_weap__aimInertia
  assume localInertia = human_weap__aimInertiaLocal
  assume inertiaVel = human_weap__aimInertiaVelocity

  let curTick = int(safediv(info.curTime, human_weap__aimInertiaDeltaTime))
  let weight = get_float(human_weap__currentGunEid, "item__weight") ?? 0.0

  if (!isAlive || isDowned || isInVehicle
      || has(human_weap__currentGunEid, "disableAimInertia")
      || weight < human_weap__aimInertiaMinWeight)
    inertia = float2()
    localInertia = float2()
    inertiaVel = float2()
    human_weap__aimInertiaLastTick = curTick
    return

  var strength = weight * human_weap__aimInertiaStrengthMult
  if human_net_phys.phys.currentState.isCrouch
    strength *= human_weap__aimInertiaCrouchMult
  elif human_net_phys.phys.currentState.isCrawl
    strength *= human_weap__aimInertiaCrawlMult
  if human_phys_isAiming(human_net_phys.phys)
    strength *= human_weap__aimInertiaAimingMult
  strength = safeinv(strength)

  var k = square(strength)
  var c = 2.0 * human_weap__aimInertiaDampingMult * strength

  let deltaAimAngleRaw = human_input__aimAngle - human_input__oldAimAngle
  let deltaAimAngle = float2(norm_s_ang(deltaAimAngleRaw.x), norm_s_ang(deltaAimAngleRaw.y))
  localInertia -= deltaAimAngle

  let inertiaLenSq = length_sq(inertia)
  if inertiaLenSq < square(human_weap__aimInertiaBoostInterval.x)
    k *= human_weap__aimInertiaStiffnessMultEnd
    c *= human_weap__aimInertiaDampingMultEnd
  elif inertiaLenSq > square(human_weap__aimInertiaBoostInterval.y)
    k *= human_weap__aimInertiaStiffnessMultStart
    c *= human_weap__aimInertiaDampingMultStart

  let inertiaMax = human_weap__aimInertiaMaxMult * deg_to_rad(human_input__gunToAimAngleLimit)
  for _ in range(human_weap__aimInertiaLastTick, curTick)
    let inertiaAccel = -localInertia * k - inertiaVel * c
    localInertia += inertiaVel * human_weap__aimInertiaDeltaTime
    localInertia.x = clamp(localInertia.x, -inertiaMax.x, inertiaMax.x)
    localInertia.y = clamp(localInertia.y, -inertiaMax.y, inertiaMax.y)
    inertiaVel += inertiaAccel * human_weap__aimInertiaDeltaTime
    inertiaVel.x = clamp(inertiaVel.x, -human_weap__aimInertiaVelocityMax, human_weap__aimInertiaVelocityMax)
    inertiaVel.y = clamp(inertiaVel.y, -human_weap__aimInertiaVelocityMax, human_weap__aimInertiaVelocityMax)

  human_weap__aimInertiaLastTick = curTick

  let vertDir = human_net_phys.phys.currentState.vertDirection
  let rootDir = get_some_normal(vertDir)
  let aimDir = basis_aware_angles_to_dir(human_input__aimAngle, vertDir, rootDir)
  let vertLimits = human_net_phys.phys.currentState.isCrawl ? human_weap__crawlClampVertAngleRad : human_weap__clampVertAngleRad
  var localInertiaInLocAngles = human_input__aimAngle + localInertia
  localInertiaInLocAngles.y = clamp(localInertiaInLocAngles.y, vertLimits.x, vertLimits.y)
  let localInertiaInGlobDir = basis_aware_angles_to_dir(localInertiaInLocAngles, vertDir, rootDir)
  var wishInertia = dir_to_angles(localInertiaInGlobDir) - dir_to_angles(aimDir)
  wishInertia = float2(norm_s_ang(wishInertia.x), norm_s_ang(wishInertia.y))
  inertia = approach(inertia, wishInertia, info.dt, human_weap__aimInertiaViscosity)
