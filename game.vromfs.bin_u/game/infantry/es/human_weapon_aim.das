require ecs
require math.base
require HumanPhys
require DngHuman
require %game.events
require DagorMath
require DagorMathUtils
require %appGame.infantry.es.human_weap_common
require DagorSystem

[es(REQUIRE_NOT=(deadEntity, menuSoldier))]
def human_weapon_aim(evt : CmdPostPhysUpdate;
                     isDowned : bool;
                     human_net_phys__maxStamina : float;
                     human_weap__currentGunEid : EntityId;
                     human_weap__enableClampVertAimAngle : bool;
                     human_weap__crawlClampVertAngleRad : float2;
                     human_weap__clampVertAngleRad : float2;
                     human_weap__dyspneaTimeMultiplier : float = 0.5;
                     human_weap__dyspneaMaxMultiplier : float = 3.0;
                     human_weap__crawlClampAngleRad : float = HALF_PI;
                     human_weap__clampAngleRad : float = PI;
                     entity_mods__breathAimMult : float = 1.0;
                     var human_net_phys : HumanActor&;
                     var human_weap__holdBreathShakeMagnitudeMult : float&;
                     human_weap__holdBreathShakeMagnitudeMultViscosity : float = 1.0f;
                     human_weap__weaponShakeMagnitudeMult = 1.5f;
                     human_weap__weaponShakeMagnitudePow = 1.1f;
                     human_weap__weaponShakeSpeedMult = 0.15f;
                     human_weap__weaponShakeSpeedPow = 0.9f;
                     human_weap__weaponShakeDefaultWeight = 1.0f)
  assume currentState = human_net_phys.phys.currentState
  assume appliedCT = human_net_phys.phys.appliedCT
  assume holdBreathMagnitudeMult = human_weap__holdBreathShakeMagnitudeMult

  let rootDir = get_some_normal(currentState.vertDirection)
  assume weapParams = human_net_phys.phys.weaponParams[int(currentState.weapEquipState.curSlot)]

  let weight = get_float(human_weap__currentGunEid, "item__weight") ?? human_weap__weaponShakeDefaultWeight
  let weapShakeMagnitudeMult = weight == 0.0 ? 1.0 : pow(weight, human_weap__weaponShakeMagnitudePow) * human_weap__weaponShakeMagnitudeMult
  let weapShakeSpeedMult = weight == 0.0 ? 1.0 : pow(weight, human_weap__weaponShakeSpeedPow) * human_weap__weaponShakeSpeedMult

  let maxStamina = human_net_phys__maxStamina * currentState.maxStaminaMult * currentState.staminaBoostMult
  currentState.breathShakeMult = move_to(currentState.breathShakeMult,
                                         cvt(currentState.stamina, maxStamina,
                                         0., 1., 3.), evt.dt, 1.)

  if isDowned && !appliedCT.isMoving
    return

  let invDt = safeinv(evt.dt)
  let atTime = float(evt.tick) * evt.dt

  let nwsd = normalize(appliedCT.wishShootDir)
  var wishShootAngles = basis_aware_dir_to_angles(nwsd, currentState.vertDirection, rootDir)
  wishShootAngles.x = renorm_ang(wishShootAngles.x, currentState.gunAngles.x)

  let moveMagnitude = currentState.isControllable ? max(length(project_onto_plane(currentState.velocity, currentState.vertDirection)) - 1., 0.) : 0.0
  wishShootAngles.x += sin(atTime * TWOPI * 1.5) * weapParams.walkMoveMagnitude * 2. * moveMagnitude
  wishShootAngles.y += (sin(atTime * TWOPI * 3.) - 1.) * weapParams.walkMoveMagnitude * moveMagnitude

  let aimShakeMult = cvt(currentState.aimPosition, 0., 1., 1., 0.3)
  let breathMagnitude = (currentState.isCrawl ? weapParams.crawlBreathShakeMagnitude
                       : currentState.isCrouch ? weapParams.crouchBreathShakeMagnitude
                       : weapParams.breathShakeMagnitude)
  let isHoldBreath = is_hold_breath(currentState)
  holdBreathMagnitudeMult = approach(holdBreathMagnitudeMult, isHoldBreath ? 0. : 1., evt.dt, human_weap__holdBreathShakeMagnitudeMultViscosity)
  let shakeMagnitude = (breathMagnitude * currentState.breathShakeMult) * aimShakeMult * currentState.breathAmplitudeMult * entity_mods__breathAimMult * weapShakeMagnitudeMult * holdBreathMagnitudeMult

  let startHoldBreathTime = 1.
  if isHoldBreath
    currentState.breathTimer += evt.dt
  else
    currentState.breathTimer -= evt.dt * human_weap__dyspneaTimeMultiplier
  currentState.breathTimer = clamp(currentState.breathTimer, 0., startHoldBreathTime)

  let dyspneaMultiplier = isHoldBreath ? 0. : human_weap__dyspneaMaxMultiplier * currentState.breathShortness
  let holdBreathSpeedMult = cvt(currentState.breathTimer, 0., startHoldBreathTime, 1., dyspneaMultiplier)

  let breathSpeed = currentState.breathShakeMult * holdBreathSpeedMult * weapShakeSpeedMult
  currentState.breathTime += evt.dt * breathSpeed
  let timeMult = 0.15
  currentState.breathOffset.x = perlin_noise1(timeMult * currentState.breathTime + 17.21) * shakeMagnitude * holdBreathSpeedMult
  currentState.breathOffset.y = perlin_noise1(timeMult * currentState.breathTime + 13.19) * shakeMagnitude * holdBreathSpeedMult

  let handShakeMagnitude = currentState.handsShakeMagnitude
  currentState.handsShakeTime += evt.dt * currentState.handsShakeSpeedMult
  currentState.handsShakeOffset.x = perlin_noise1(timeMult * currentState.handsShakeTime + 17.21) * handShakeMagnitude
  currentState.handsShakeOffset.y = perlin_noise1(timeMult * currentState.handsShakeTime + 13.19) * handShakeMagnitude

  wishShootAngles += currentState.breathOffset + currentState.handsShakeOffset

  let walkYaw = renorm_ang(-atan2(currentState.bodyOrientDir.y, currentState.bodyOrientDir.x), wishShootAngles.x)
  let clampAngle = currentState.isCrawl ? human_weap__crawlClampAngleRad : human_weap__clampAngleRad
  wishShootAngles.x = clamp(wishShootAngles.x, walkYaw - clampAngle, walkYaw + clampAngle)
  if human_weap__enableClampVertAimAngle
    let vertLimits = currentState.isCrawl ? human_weap__crawlClampVertAngleRad : human_weap__clampVertAngleRad
    wishShootAngles.y = human_weap_clamp_vert_aim_angle(wishShootAngles.y, currentState.location.O.quat, vertLimits)

  currentState.prevAngles.x = renorm_ang(currentState.prevAngles.x, currentState.gunAngles.x)
  let anglesDif = wishShootAngles - currentState.prevAngles
  currentState.targetGunSpd.x = approach(currentState.targetGunSpd.x, anglesDif.x * invDt, evt.dt, weapParams.targetSpdVisc)
  currentState.targetGunSpd.y = approach(currentState.targetGunSpd.y, anglesDif.y * invDt, evt.dt, weapParams.targetSpdVisc)
  currentState.prevAngles = wishShootAngles

  let futureAngles = currentState.gunAngles + currentState.gunSpd * weapParams.predictTime
  let delta = wishShootAngles + currentState.targetGunSpd * weapParams.predictTime - futureAngles
  let maxSpeed = float2(weapParams.maxGunSpd, weapParams.maxGunSpd)
  let wishSpeed = clamp(weapParams.gunSpdDeltaMult * delta / weapParams.predictTime, -maxSpeed, maxSpeed)
  currentState.gunSpd.x = approach(currentState.gunSpd.x, wishSpeed.x, evt.dt, weapParams.gunSpdVisc)
  currentState.gunSpd.y = approach(currentState.gunSpd.y, wishSpeed.y, evt.dt, weapParams.gunSpdVisc)

  currentState.gunAngles += currentState.gunSpd * currentState.weaponTurningSpeedMult * evt.dt

  let turnSpeed = weapParams.moveToSpd * currentState.weaponTurningSpeedMult
  let wishYaw = renorm_ang(wishShootAngles.x, currentState.gunAngles.x)
  let wishPitch = renorm_ang(wishShootAngles.y, currentState.gunAngles.y)
  currentState.gunAngles.x = norm_s_ang(move_to(currentState.gunAngles.x, wishYaw, evt.dt, turnSpeed))
  currentState.gunAngles.y = norm_s_ang(move_to(currentState.gunAngles.y, wishPitch, evt.dt, turnSpeed))

  currentState.gunDir = basis_aware_angles_to_dir(currentState.gunAngles, currentState.vertDirection, rootDir)
  if !is_relative_equal_float(length_sq(currentState.gunDir), 1.0, 0.01)
    logerr("Not normalized currentState.gunDir set {currentState.gunDir} len={length(currentState.gunDir)}")
    currentState.gunDir = normalize(currentState.gunDir)
  let vertOffsetVisc = weapParams.vertOffsetRestoreVisc * currentState.aimingAfterFireMult
  currentState.gunAimOffset = approach(currentState.gunAimOffset, float2(), evt.dt, vertOffsetVisc)
