require ecs
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.es.human_weap_client_common
require %appGame.infantry.es.camera_common
require %game.events
require math.base
require HumanPhys
require DngHuman
require DaWeapons
require DngWeapon
require DagorMath
require DagorMathUtils
require GridCollision
require CollisionTraces
require Dacoll
require AnimV20
require GeomNodeTree
require Unit


struct AimInertiaStepCfg
  dt : float          
  timeStretch : float 
  pMax : float2       
  vMax : float        
  yMin : float        
  yMax : float        
  vScaleFrac : float  
  tqScale : float     
  p0 : float2         


def do_gun_traceray(from : float3; dir : float3; var t : float&; ray_mat_id : int; ignore_human_eid : EntityId)
  var retEid = INVALID_ENTITY_ID
  var pmid : int
  var norm : float3
  using() <| $(var desc : RendInstDesc#)
    traceray_normalized(from, dir, t, pmid, norm, 127, desc, ray_mat_id)
  using() <| $(var intersections : IntersectedEntities)
    trace_entities_in_grid(ecs_hash("humans"), from, dir, t, ignore_human_eid, intersections, SortIntersections.NO)
    trace_entities_in_grid(ecs_hash("vehicles"), from, dir, t, ignore_human_eid, intersections, SortIntersections.YES)
    for isect in intersections
      if get_bool(isect.eid, "animchar__visible") ?? true
        retEid = isect.eid
        break
  return retEid

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

[es(tag=server, before=net_phys_update_es)]
def human_weap_mod_active_update_es(info : ParallelUpdateFrameDelayed;
                                    human_weap__gunMods : Array;
                                    human_weap__currentGunSlot : int;
                                    var human_weap__weapModActivateStartTime : float&;
                                    var human_weap__weapModActivateFinishTime : float&)
  if (human_weap__weapModActivateStartTime < 0.0) || (human_weap__currentGunSlot < 0)
    return

  let inProgress = info.curTime <= human_weap__weapModActivateFinishTime
  if inProgress
    return

  let gunModEids = get_ecs_EidList(human_weap__gunMods[human_weap__currentGunSlot])
  for gunMod in *gunModEids
    query(gunMod) <| $ [es] (var weapon_mod__active : bool&; weapon_mod__wantActiveState : bool)
      weapon_mod__active = weapon_mod__wantActiveState
      human_weap__weapModActivateStartTime = -1.0
      human_weap__weapModActivateFinishTime = -1.0

[es(after=(human_weap_client_es, human_weap_reload_es, human_weap_mod_active_update_es), before=(hero_medic_select_damaged_human_es, human_vehicle_seats_non_shooter_pre_animchar_es, after_guns_update_sync, human_attached_gun_rotate_body), REQUIRE=(controlledHero, human_weap))]
def human_weap_update_es(info : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         isInVehicle : bool = false;
                         human_vehicle__isHoldingGunPassenger : bool = false;
                         human_weap__currentGunEid : EntityId;
                         human_weap__grenadeThrower : EntityId = INVALID_ENTITY_ID;
                         human_weap__lockedGrenadeThrowingCounter : int = 0;
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
                         human_weap__maxGunVisualAngleDeviation : float = 10.;
                         human_unarmed__active : bool = false;
                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                         human_weap__tracerayLen : float&;
                         isReplayObserved : Tag const?;
                         var human_net_phys : HumanActor;
                         var transform : float3x4&;
                         human_weap__weapModActivateStartTime : float;
                         human_weap__weapModActivateFinishTime : float;
                         var human_weap__gunEids : EidList;
                         var human_weap__throwMode : bool&;
                         unit__ref : UnitRef)
  if !isAlive || isDowned || unit__ref.unit.isDelayed || human_net_phys.phys.currentState |> human_phys_state_attachedToLadder
    return

  let dt = info.dt
  var atTime = info.curTime

  
  
  assume ct = (isReplayObserved == null && human_net_phys.isLocalControl) ? human_net_phys.phys.producedCT : human_net_phys.phys.appliedCT
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT) && !ct.haveUnenqueuedHctShoot
    atTime = floor(atTime / human_net_phys.phys.timeStep) * human_net_phys.phys.timeStep

  let isForReal = true
  let wishGunDir = ct.wishShootDir
  let gunDir = wishGunDir
  let up = transform[1]
  var horzDir = normalize(gunDir - dot(gunDir, up) * up)

  assume phys = human_net_phys.phys
  assume prevState = phys.previousState
  assume curState  = phys.currentState
  if prevState.moveState == HUMoveState.EMS_SPRINT || curState.moveState == HUMoveState.EMS_SPRINT
    let from = prevState.moveState == HUMoveState.EMS_SPRINT ? 1.0 : 0.0
    let to = curState.moveState == HUMoveState.EMS_SPRINT ? 1.0 : 0.0
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

  let updCtx = GunUpdateCtx(
    dt = dt,
    atTime = atTime,
    isForReal = isForReal,
    eid = eid,
    isDowned = isDowned,
    isThrowingAllowed = human_weap__lockedGrenadeThrowingCounter == 0 && (human_vehicle__isHoldingGunPassenger || !isInVehicle),
    shotDeviationMult = entity_mods__shotDeviationMult,
    rotationShotSpreadDecrMult = entity_mods__rotationShotSpreadDecrMult,
    aimingAfterFireMult = entity_mods__aimingAfterFireMult,
    boltActionMult = entity_mods__boltActionMult,
    shotDeviationAdd = entity_mods__shotDeviationAdd,
    fastThrowExclusive = human_weap__fastThrowExclusive,
    deviationBufferSizeMult = entity_mods__deviationBufferSizeMult)

  let physTransform = human_net_phys.phys.currentState.location |> location_makeTM()
  human_weap_gun_update(human_net_phys, human_weap__gunEids, human_weap__throwMode,
                        updCtx, transform, gunDir, gunShootDir, physTransform,
                        ct, grenade_rethrow__grenadeEid,
                        human_unarmed__active, human_attached_gun__attachedGunEid, human_weap__currentGunEid,
                        human_weap__jumpDeviation, human_weap__changePosDeviationCanAim, human_weap__changePosDeviationCanNotAim,
                        human_weap__grenadeThrower, human_phys__jumpEndTime, human_phys__afterJumpDelay, human_phys__isInAirLong, bipod__enabled,
                        human_weap__weapModActivateStartTime, human_weap__weapModActivateFinishTime)

def deadzone(v : float2; thres : float) : float2
  return float2(
    abs(v.x) < thres ? 0.0 : sign(v.x) * (abs(v.x) - thres),
    abs(v.y) < thres ? 0.0 : sign(v.y) * (abs(v.y) - thres))

def deadzone(v : float; thres : float) : float
  return abs(v) < thres ? 0.0 : sign(v) * (abs(v) - thres)

def aim_inertia_step(var p : float2&; var v : float2&; cfg : AimInertiaStepCfg;
                     tqLut : FloatList; tqN : int; tqSharp : float;
                     zetaLut : FloatList; zetaN : int; zetaSharp : float)
  
  let pN     = float2(abs(p.x) / cfg.pMax.x, abs(p.y) / cfg.pMax.y)     
  let vRet   = float2(-sign(p.x) * v.x, -sign(p.y) * v.y)
  let vScale = cfg.vScaleFrac * cfg.vMax / cfg.timeStretch
  let vN     = float2(vRet.x / vScale, vRet.y / vScale)                 

  
  
  let tqEff = float2(lookup_lut_2d(tqLut, tqN, pN.x, vN.x, tqSharp) * cfg.tqScale * cfg.timeStretch,
                     lookup_lut_2d(tqLut, tqN, pN.y, vN.y, tqSharp) * cfg.tqScale * cfg.timeStretch)
  let zEff  = float2(lookup_lut_2d(zetaLut, zetaN, pN.x, vN.x, zetaSharp),
                     lookup_lut_2d(zetaLut, zetaN, pN.y, vN.y, zetaSharp))
  let wEff  = 0.5 * PI * float2(safeinv(tqEff.x), safeinv(tqEff.y))
  let k     = wEff * wEff
  let c     = 2. * zEff * wEff

  
  
  let rawP = p + v * cfg.dt
  if rawP.x > cfg.pMax.x
    p.x = cfg.pMax.x
    if v.x > 0.
      v.x = 0.
  elif rawP.x < -cfg.pMax.x
    p.x = -cfg.pMax.x
    if v.x < 0.
      v.x = 0.
  else
    p.x = rawP.x
  if rawP.y > cfg.yMax
    p.y = cfg.yMax
    if v.y > 0.
      v.y = 0.
  elif rawP.y < cfg.yMin
    p.y = cfg.yMin
    if v.y < 0.
      v.y = 0.
  else
    p.y = rawP.y

  let accel = (cfg.p0 - p) * k - v * c
  v += accel * cfg.dt
  v.x = clamp(v.x, -cfg.vMax, cfg.vMax)
  v.y = clamp(v.y, -cfg.vMax, cfg.vMax)

[es(tag=gameClient, after=human_weap_update_es, REQUIRE=(hero, human_weap), REQUIRE_NOT=deadEntity)]
def human_weapon_inertia(info : ParallelUpdateFrameDelayed;
                         isAlive : bool;
                         isDowned : bool;
                         isInVehicle : bool;
                         bipod__enabled : bool = false;
                         human_net_phys : HumanActor;
                         human_input__gunToAimAngleLimit : float2;
                         human_input__aimAngle : float2;
                         human_input__oldAimAngle : float2;
                         human_weap__aimOmegaViscosity : float;
                         human_weap__currentGunEid : EntityId;
                         human_weap__crawlClampVertAngleRad : float2;
                         human_weap__clampVertAngleRad : float2;
                         human_weap__aimInertiaDeltaTime : float;
                         human_weap__aimInertiaCrouchMult : float;
                         human_weap__aimInertiaCrawlMult : float;
                         human_weap__aimInertiaAimingMult : float;
                         human_weap__aimInertiaVScaleFrac : float;
                         human_weap__aimInertia_TqScale : float;
                         human_weap__aimInertia_TqLut : FloatList;
                         human_weap__aimInertia_TqLutColumnCount : int;
                         human_weap__aimInertia_TqLutSharpness : float;
                         human_weap__aimInertia_ZetaLut : FloatList;
                         human_weap__aimInertia_ZetaLutColumnCount : int;
                         human_weap__aimInertia_ZetaLutSharpness : float;
                         human_weap__aimInertiaTimeStretchMin : float;
                         human_weap__aimInertiaTimeStretchMax : float;
                         human_weap__aimInertiaTimeStretchBias : float;
                         human_weap__aimInertiaWeightMin : float;
                         human_weap__aimInertiaWeightMax : float;
                         human_weap__aimInertiaRestPointGainMin : float;
                         human_weap__aimInertiaRestPointGainMax : float;
                         human_weap__aimInertiaRestPointGainBias : float;
                         human_weap__aimInertiaOmegaDrainMin : float;
                         human_weap__aimInertiaOmegaDrainMax : float;
                         human_weap__aimInertiaOmegaDrainBias : float;
                         human_weap__aimInertiaAccumAngleMin : float;
                         human_weap__aimInertiaAccumAngleMax : float;
                         human_weap__aimInertiaMaxMult : float;
                         human_weap__aimInertiaVelocityMax : float;
                         human_weap__aimInertiaViscosity : float;
                         var human_weap__aimOmega : float2&;
                         var human_weap__aimInertiaRestPoint : float2&;
                         var human_weap__aimInertia : float2&;
                         var human_weap__aimInertiaVelocity : float2&;
                         var human_weap__aimInertiaLastTick : int&;
                         var human_weap__aimInertiaWish : float2&;
                         var human_weap__aimInertiaAccumAngle : float2&)
  if human_weap__aimInertiaLastTick < 0
    human_weap__aimInertiaLastTick = int(safediv(info.curTime, human_weap__aimInertiaDeltaTime))
    return

  assume inertia = human_weap__aimInertia
  assume wishInertia = human_weap__aimInertiaWish
  assume inertiaVel = human_weap__aimInertiaVelocity

  let curTick = int(safediv(info.curTime, human_weap__aimInertiaDeltaTime))
  var weight = get_float(human_weap__currentGunEid, "gun__inertialMass") ?? 0.0
  if weight == 0.0
    weight = get_float(human_weap__currentGunEid, "item__weight") ?? 0.0
  weight = clamp(weight, 0.0, human_weap__aimInertiaWeightMax)

  if (!isAlive || isDowned || isInVehicle
      || has(human_weap__currentGunEid, "disableAimInertia")
      || weight < human_weap__aimInertiaWeightMin
      || bipod__enabled)
    inertia = float2()
    wishInertia = float2()
    inertiaVel = float2()
    human_weap__aimInertiaRestPoint = float2()
    human_weap__aimOmega = float2()
    human_weap__aimInertiaAccumAngle = float2()
    human_weap__aimInertiaLastTick = curTick
    return

  var timeStretch = param_curve(weight, human_weap__aimInertiaWeightMin, human_weap__aimInertiaWeightMax,
    human_weap__aimInertiaTimeStretchMin, human_weap__aimInertiaTimeStretchMax, human_weap__aimInertiaTimeStretchBias)
  let aimInertiaOmegaDrain = param_curve(weight, human_weap__aimInertiaWeightMin, human_weap__aimInertiaWeightMax,
    human_weap__aimInertiaOmegaDrainMin, human_weap__aimInertiaOmegaDrainMax, human_weap__aimInertiaOmegaDrainBias)
  let restPointGain = param_curve(weight, human_weap__aimInertiaWeightMin, human_weap__aimInertiaWeightMax,
    human_weap__aimInertiaRestPointGainMin, human_weap__aimInertiaRestPointGainMax, human_weap__aimInertiaRestPointGainBias)

  
  if human_net_phys.phys.currentState.isCrouch
    timeStretch *= human_weap__aimInertiaCrouchMult
  elif human_net_phys.phys.currentState.isCrawl
    timeStretch *= human_weap__aimInertiaCrawlMult
  if human_phys_isAiming(human_net_phys.phys)
    timeStretch *= human_weap__aimInertiaAimingMult

  let deltaAimAngleRaw = human_input__aimAngle - human_input__oldAimAngle
  let deltaAimAngle = float2(norm_s_ang(deltaAimAngleRaw.x), norm_s_ang(deltaAimAngleRaw.y))

  human_weap__aimOmega = approach(human_weap__aimOmega, deltaAimAngle / max(info.dt, 1e-4), info.dt, human_weap__aimOmegaViscosity)
  let aimAccumInertiaAngleMax = float2(human_weap__aimInertiaAccumAngleMax)
  human_weap__aimInertiaAccumAngle += abs(human_weap__aimOmega) * info.dt
  let aimInertiaOmegaDrainDt = float2(aimInertiaOmegaDrain * info.dt)
  human_weap__aimInertiaAccumAngle = clamp(human_weap__aimInertiaAccumAngle - aimInertiaOmegaDrainDt, float2(), aimAccumInertiaAngleMax)

  human_weap__aimInertiaRestPoint = restPointGain * deadzone(human_weap__aimOmega, aimInertiaOmegaDrain)
  if abs(human_weap__aimInertiaAccumAngle.x) < human_weap__aimInertiaAccumAngleMin
    human_weap__aimInertiaRestPoint.x = 0.0
  if abs(human_weap__aimInertiaAccumAngle.y) < human_weap__aimInertiaAccumAngleMin
    human_weap__aimInertiaRestPoint.y = 0.0

  let inertiaMax = human_weap__aimInertiaMaxMult * deg_to_rad(human_input__gunToAimAngleLimit)

  let vertLimits = human_net_phys.phys.currentState.isCrawl ? human_weap__crawlClampVertAngleRad : human_weap__clampVertAngleRad
  let aimY = human_input__aimAngle.y
  let wishYMin = max(-inertiaMax.y, vertLimits.x - aimY)
  let wishYMax = min(inertiaMax.y, vertLimits.y - aimY)

  let cfg = AimInertiaStepCfg(
    dt = human_weap__aimInertiaDeltaTime,
    timeStretch = timeStretch,
    pMax = inertiaMax,
    vMax = human_weap__aimInertiaVelocityMax,
    yMin = wishYMin,
    yMax = wishYMax,
    vScaleFrac = human_weap__aimInertiaVScaleFrac,
    tqScale = human_weap__aimInertia_TqScale,
    p0 = human_weap__aimInertiaRestPoint)

  for _ in range(human_weap__aimInertiaLastTick, curTick)
    aim_inertia_step(wishInertia, inertiaVel, cfg,
                     human_weap__aimInertia_TqLut,   human_weap__aimInertia_TqLutColumnCount,   human_weap__aimInertia_TqLutSharpness,
                     human_weap__aimInertia_ZetaLut, human_weap__aimInertia_ZetaLutColumnCount, human_weap__aimInertia_ZetaLutSharpness)

  inertia = approach(inertia, wishInertia, info.dt, human_weap__aimInertiaViscosity)

  human_weap__aimInertiaLastTick = curTick
