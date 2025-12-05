require ecs
require math.base
require math.easing
require DagorMath
require HumanPhys
require DngWeapon
require DaWeapons
require DngHuman

def camera_walk_bhv(info : UpdateStageInfoAct&;
                    eid : EntityId;
                    human_net_phys : HumanActor&;
                    human_weap__currentGunEid : EntityId;
                    human_weap__currentGunModEids : EidList&;
                    human_cam_walk_bhv__moveMagnitude : float;
                    human_cam_walk_bhv__runMagnitude : float;
                    human_cam_walk_bhv__sprintMagnitude : float;
                    human_cam_walk_bhv__movePeriod : float;
                    human_cam_walk_bhv__runPeriod : float;
                    human_cam_walk_bhv__sprintPeriod : float;
                    human_cam_walk_bhv__offsetXMult : float;
                    human_cam_walk_bhv__offsetYPeriodMult : float;
                    human_cam_walk_bhv__spreadMult : float;
                    human_cam_walk_bhv__spreadTimePeriod : float;
                    human_cam_walk_bhv__spreadHorzMult : float;
                    human_cam_walk_bhv__aimMagnitudeMult : float;
                    human_cam_walk_bhv__maxOpticsMult : float;
                    var human_weap__gunOffsAngles : float3&)
  var moveState  = uint(human_net_phys.phys.currentState.moveState)

  if (uint(human_net_phys.phys.currentState.states) & uint(StateFlag.ST_ON_GROUND)) == 0u
    moveState = uint(HUMoveState.EMS_STAND)

  if human_net_phys.phys.currentState.isCrouch
    moveState = min(moveState, uint(HUMoveState.EMS_WALK))

  var moveMagnitude = 0.f
  var movePeriod    = 0.f

  if moveState == uint(HUMoveState.EMS_WALK)
    moveMagnitude = human_cam_walk_bhv__moveMagnitude
    movePeriod    = human_cam_walk_bhv__movePeriod
  elif moveState == uint(HUMoveState.EMS_RUN)
    moveMagnitude = human_cam_walk_bhv__runMagnitude
    movePeriod    = human_cam_walk_bhv__runPeriod
  elif moveState == uint(HUMoveState.EMS_SPRINT)
    moveMagnitude = human_cam_walk_bhv__sprintMagnitude
    movePeriod    = human_cam_walk_bhv__sprintPeriod

  var gunEid = INVALID_ENTITY_ID

  query(eid) <| $ [es] (human_attached_gun__attachedGunEid : EntityId const?;
                        human_weap__currentGunEid : EntityId const?)
    if human_weap__currentGunEid != null
      gunEid = *human_weap__currentGunEid

    if human_attached_gun__attachedGunEid != null
      gunEid = *human_attached_gun__attachedGunEid

  var additionalOffset = float3(0.f)

  query(gunEid) <| $ [es] (gun : Gun&;
                           gun_deviation : GunDeviation const?;
                           gun_spread__maxDeltaAngle : float;
                           gun__sightsDistance : float)
    let sightsMult = cvt(gun__sightsDistance, 0.05f, 0.3f, 0.5f, 5.f)

    var projectileSpread = gun_calcSpread(gun)

    if gun_deviation != null
      let angleDev = deg_to_rad(gun_spread__maxDeltaAngle + (*gun_deviation).minExtraDev)

      projectileSpread.x = max(projectileSpread.x - angleDev, 0.f)
      projectileSpread.y = max(projectileSpread.y - angleDev, 0.f)

    additionalOffset += float3(0.f,
                               perlin_noise1(human_cam_walk_bhv__spreadTimePeriod * info.curTime + 17.21f) * projectileSpread.x * human_cam_walk_bhv__spreadHorzMult,
                              (perlin_noise1(human_cam_walk_bhv__spreadTimePeriod * info.curTime + 13.19f) + 1.f) * projectileSpread.y) * human_cam_walk_bhv__spreadMult * sightsMult


  var isIntegratedScope = false

  query(human_weap__currentGunEid) <| $ [es] (gun__spreadOffsetMult : float = 1.f;
                                              gun__moveOffsetMult : float = 1.f;
                                              gun__integratedScope : bool = false)

    additionalOffset *= gun__spreadOffsetMult
    moveMagnitude    *= gun__moveOffsetMult
    isIntegratedScope = gun__integratedScope

  if human_net_phys.phys.currentState.isAiming
    moveMagnitude  *= human_cam_walk_bhv__aimMagnitudeMult

  let sineMoves   = float2(sin(info.curTime * TWOPI * movePeriod),
                           sin(info.curTime * TWOPI * movePeriod * human_cam_walk_bhv__offsetYPeriodMult))

  var wishOffset  = float3(0.f,
                          (linear(0.5f * (sineMoves.x + 1.f)) * 2.f - 1.f) * human_cam_walk_bhv__offsetXMult,
                           inQuad(0.5f * (sineMoves.y + 1.f)) * 2.f) * moveMagnitude + additionalOffset

  var gunScopeEid = INVALID_ENTITY_ID

  for currentGunModEid in human_weap__currentGunModEids
    if has(currentGunModEid, "gunScope")
      gunScopeEid = currentGunModEid
      break

  if isIntegratedScope && (gunScopeEid == INVALID_ENTITY_ID)
    gunScopeEid = human_weap__currentGunEid

  let tau = 0.05f

  if gunScopeEid != INVALID_ENTITY_ID
    let interpK      = get_phys_interpk_clamped(human_net_phys.phys, info.curTime)
    let zoomPos      = lerp(human_net_phys.phys.previousState.zoomPosition, human_net_phys.phys.currentState.zoomPosition, interpK)
    additionalOffset = lerp(additionalOffset, float3(0.f), float3(zoomPos))
    wishOffset       = lerp(wishOffset, float3(0.f), float3(min(zoomPos, human_cam_walk_bhv__maxOpticsMult)))

  human_weap__gunOffsAngles = approach(human_weap__gunOffsAngles, wishOffset, info.dt, tau)

[es(tag=render, REQUIRE=watchedHero)]
def human_camera_walk_bhv_es(info : UpdateStageInfoAct&;
                             eid : EntityId;
                             human_net_phys : HumanActor&;
                             human_weap__currentGunEid : EntityId;
                             human_weap__currentGunModEids : EidList&;
                             human_cam_walk_bhv__moveMagnitude : float = 0.0025f;
                             human_cam_walk_bhv__runMagnitude : float = 0.005f;
                             human_cam_walk_bhv__sprintMagnitude : float = 0.f;
                             human_cam_walk_bhv__movePeriod : float = 0.7f;
                             human_cam_walk_bhv__runPeriod : float = 0.7f;
                             human_cam_walk_bhv__sprintPeriod : float = 0.f;
                             human_cam_walk_bhv__offsetXMult : float = 1.f;
                             human_cam_walk_bhv__offsetYPeriodMult : float = 2.f;
                             human_cam_walk_bhv__spreadMult : float = 0.5f;
                             human_cam_walk_bhv__spreadTimePeriod : float = 0.5f;
                             human_cam_walk_bhv__spreadHorzMult : float = 2.f;
                             human_cam_walk_bhv__aimMagnitudeMult : float = 0.5f;
                             human_cam_walk_bhv__maxOpticsMult : float = 0.8f;
                             var human_weap__gunOffsAngles : float3&)
  if human_weap__currentGunEid == INVALID_ENTITY_ID
    return

  camera_walk_bhv(info, eid, human_net_phys, human_weap__currentGunEid, human_weap__currentGunModEids,
                  human_cam_walk_bhv__moveMagnitude,
                  human_cam_walk_bhv__runMagnitude, human_cam_walk_bhv__sprintMagnitude, human_cam_walk_bhv__movePeriod,
                  human_cam_walk_bhv__runPeriod, human_cam_walk_bhv__sprintPeriod, human_cam_walk_bhv__offsetXMult,
                  human_cam_walk_bhv__offsetYPeriodMult, human_cam_walk_bhv__spreadMult, human_cam_walk_bhv__spreadTimePeriod,
                  human_cam_walk_bhv__spreadHorzMult, human_cam_walk_bhv__aimMagnitudeMult, human_cam_walk_bhv__maxOpticsMult,
                  human_weap__gunOffsAngles)

[es(tag=render, REQUIRE=watchedHero, after=(human_camera_walk_bhv_es, human_attached_gun_controls_update_es))]
def human_camera_walk_bhv_attached_gun_es(info : UpdateStageInfoAct&;
                                          eid : EntityId;
                                          human_net_phys : HumanActor&;
                                          human_weap__currentGunEid : EntityId;
                                          human_weap__currentGunModEids : EidList&;
                                          human_attached_gun__attachedGunEid : EntityId;
                                          human_cam_walk_bhv__attachedGunSpreadMult : float = 0.5f;
                                          human_cam_walk_bhv__spreadTimePeriod : float = 0.5f;
                                          human_cam_walk_bhv__spreadHorzMult : float = 2.f)
  if human_attached_gun__attachedGunEid == INVALID_ENTITY_ID
    return

  var gunOffsAngles = float3(0.f)

  camera_walk_bhv(info, eid, human_net_phys, human_weap__currentGunEid, human_weap__currentGunModEids,
                  0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f,
                  human_cam_walk_bhv__attachedGunSpreadMult, human_cam_walk_bhv__spreadTimePeriod,
                  human_cam_walk_bhv__spreadHorzMult, 0.f, 1.f, gunOffsAngles)