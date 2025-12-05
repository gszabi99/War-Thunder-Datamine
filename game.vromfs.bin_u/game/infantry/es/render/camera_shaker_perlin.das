require ecs
require DagorMath
require DagorRandom
require math
require math.base
require math.easing
require HumanPhys
require DngHuman
require DaWeapons
require %appGame.infantry.es.render.camera_shaker_common
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.hitpoints_common


def calc_trauma(trauma, addTrauma, maxTrauma)
  return trauma >= maxTrauma ? trauma : clamp(min(trauma + addTrauma, maxTrauma), 0.f, 1.f)

[es(tag=gameClient)]
def camera_shaker_perlin_add_trauma(evt : CmdAddCameraTrauma;
                                    camera__active : bool;
                                    var camera_shaker__trauma : float&)
  if camera__active
    camera_shaker__trauma = calc_trauma(camera_shaker__trauma, evt.addTrauma, evt.maxTrauma)

[es(tag=gameClient)]
def camera_shaker_perlin_add_trauma_by_distance(evt : CmdAddCameraTraumaByDistance;
                                                transform : float3x4;
                                                camera__active : bool;
                                                var camera_shaker__trauma : float&)
  if camera__active
    let distanceSq = length_sq(evt.position - transform[3])
    let maxDistSq = square(evt.maxDistance)
    let maxTrauma = cvt(maxDistSq - distanceSq, 0.f, maxDistSq, 0.f, evt.maxTrauma)
    camera_shaker__trauma = calc_trauma(camera_shaker__trauma, evt.addTrauma, maxTrauma)

[es(tag=gameClient)]
def camera_shaker_perlin_punch(evt : CmdCameraPunch;
                               camera__active : bool;
                               var camera_shaker__punch : float&;
                               var camera_shaker__punchAngles : float3&)
  if camera__active && camera_shaker__punch <= 0.05f
    camera_shaker__punch = 1.f
    camera_shaker__punchAngles = evt.angles * DEG_TO_RAD

[es(tag=gameClient)]
def camera_shaker_perlin_punch_by_dir(evt : CmdCameraPunchByDir;
                                      camera__active : bool;
                                      camera_shaker__punchByDirMaxAngles : float3;
                                      camera_shaker__punchMaxPower : float;
                                      camera_shaker__punchDirLength : float;
                                      var camera_shaker__punch : float&;
                                      var camera_shaker__punchAngles : float3&)
  if !camera__active || camera_shaker__punch > 0.05f
    return

  let dir = evt.localDir
  let power = cvt(length(evt.localDir), 0.f, camera_shaker__punchDirLength, 0.f, camera_shaker__punchMaxPower)

  let maxPitch = camera_shaker__punchByDirMaxAngles.x * power
  let maxYaw = camera_shaker__punchByDirMaxAngles.y * power
  let maxRoll = camera_shaker__punchByDirMaxAngles.z * power

  let roll = cvt(dir.y, -1.f, 1.f, -maxRoll, maxRoll)
  if abs(dir.x) >= abs(dir.z)
    camera_shaker__punchAngles = float3(-sign(dir.x) * maxPitch, 0.f, -sign(dir.z) * roll)
  else
    camera_shaker__punchAngles = float3(0.f, sign(dir.z) * maxYaw, sign(dir.z) * roll)

  camera_shaker__punch = 1.f
  camera_shaker__punchAngles *= DEG_TO_RAD

[es(tag=gameClient, after=shooter_cam_update_tm_es, before=after_camera_sync)]
def camera_shaker_perlin_update_es(info : UpdateStageInfoAct;
                                   camera_shaker__maxShake : float3;
                                   camera_shaker__traumaFadeoutSpeed : float;
                                   camera_shaker__shakePower : float;
                                   camera_shaker__punchSpeed : float;
                                   camera_shaker__punchAngles : float3;
                                   camera_shaker__extraShakeAngles : float3;
                                   var camera_shaker__punch : float&;
                                   var camera_shaker__shake : float&;
                                   var camera_shaker__trauma : float&;
                                   var camera_shaker__totalTime : float&;
                                   var transform : float3x4)
  camera_shaker__shake = square(camera_shaker__trauma)

  let shake = camera_shaker__shake
  let maxShake = camera_shaker__maxShake * DEG_TO_RAD
  var shakerAngles = float3(maxShake.x * shake * perlin_noise1(camera_shaker__totalTime),
                            maxShake.y * shake * perlin_noise1(camera_shaker__totalTime + 1000.f),
                            maxShake.z * shake * perlin_noise1(camera_shaker__totalTime + 2000.f))

  camera_shaker__trauma = clamp(camera_shaker__trauma - camera_shaker__traumaFadeoutSpeed * info.dt, 0.f, 1.f)
  camera_shaker__totalTime += camera_shaker__shakePower * info.dt
  if camera_shaker__totalTime > 1e5
    camera_shaker__totalTime = 0.f

  shakerAngles += smoothStopArch3(1.f - camera_shaker__punch) * camera_shaker__punchAngles
  camera_shaker__punch = clamp(camera_shaker__punch - camera_shaker__punchSpeed * info.dt, 0.f, 1.f)

  shakerAngles += camera_shaker__extraShakeAngles

  var shakerTm : float3x4

  rotxTM(shakerAngles.x, shakerTm)
  transform = transform * shakerTm

  rotyTM(shakerAngles.y, shakerTm)
  transform = transform * shakerTm

  rotzTM(shakerAngles.z, shakerTm)
  transform = transform * shakerTm


[es(tag=gameClient, on_disappear, REQUIRE=hero)]
def camera_shaker_perlin_reset_extra_shake_on_disappear(evt : Event; bindedCamera : EntityId)
  query(bindedCamera) <| $ [es] (var camera_shaker__extraShakeAngles : float3&)
    camera_shaker__extraShakeAngles = float3(0.0f)


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity, before=camera_shaker_perlin_update_es)]
def camera_shaker_perlin_swing_on_sprint(info : UpdateStageInfoAct;
                                         bindedCamera : EntityId;
                                         human_net_phys : HumanActor;
                                         human_net_phys__curMoveState : int;
                                         double_sprint__isActive : bool;
                                         camera_shake__sprintSwingMaxRotations : float3;
                                         camera_shake__sprintSwingOmega : float3;
                                         camera_shake__doubleSprintSwingMaxRotations : float3;
                                         camera_shake__doubleSprintSwingOmega : float3;
                                         camera_shake__sprintSwingMinVelocity : float;
                                         camera_shake__sprintSwingMaxVelocity : float;
                                         camera_shake__sprintSwingTau : float;
                                         var camera_shake__sprintSwingTime : float&;
                                         var camera_shake__sprintSwingAmplitude : float&;
                                         var camera_shake__sprintCurrentMaxSwingRotations : float3&)
  query(bindedCamera) <| $ [es] (camera__active : bool;
                                 camera_settings__shakePowerMult : float;
                                 var camera_shaker__extraShakeAngles : float3&)
    if !camera__active
      camera_shake__sprintSwingTime = 0.f
      camera_shaker__extraShakeAngles = float3(0.0f)
      return

    let velocity = human_net_phys.phys.currentState.velocity
    let isInSprint = human_net_phys__curMoveState == int(HUMoveState.EMS_SPRINT)

    var wishAmplitude = isInSprint ? cvt(length_sq(velocity), square(camera_shake__sprintSwingMinVelocity), square(camera_shake__sprintSwingMaxVelocity), 0.f, 1.f) : 0.f
    wishAmplitude *= camera_settings__shakePowerMult

    camera_shake__sprintSwingAmplitude = approach(camera_shake__sprintSwingAmplitude, wishAmplitude, info.dt, camera_shake__sprintSwingTau)

    if camera_shake__sprintSwingAmplitude <= 1.e-2f
      camera_shake__sprintSwingTime = 0.f
      camera_shaker__extraShakeAngles = float3(0.f, 0.f, 0.f)
      return

    let wishMaxSwingRotations = (double_sprint__isActive ? camera_shake__doubleSprintSwingMaxRotations : camera_shake__sprintSwingMaxRotations) * DEG_TO_RAD
    camera_shake__sprintCurrentMaxSwingRotations = approach(camera_shake__sprintCurrentMaxSwingRotations, wishMaxSwingRotations, info.dt, camera_shake__sprintSwingTau)

    let wishSwingOmega = double_sprint__isActive ? camera_shake__doubleSprintSwingOmega : camera_shake__sprintSwingOmega
    var swingOmegaTime = wishSwingOmega * camera_shake__sprintSwingTime
    if double_sprint__isActive
      let swingOmegaTimeOffset = (camera_shake__doubleSprintSwingOmega - camera_shake__sprintSwingOmega) * camera_shake__sprintSwingTime
      swingOmegaTime -= swingOmegaTimeOffset

    camera_shaker__extraShakeAngles.x = camera_shake__sprintSwingAmplitude * camera_shake__sprintCurrentMaxSwingRotations.x * sin(swingOmegaTime.x)
    camera_shaker__extraShakeAngles.y = camera_shake__sprintSwingAmplitude * camera_shake__sprintCurrentMaxSwingRotations.y * sin(swingOmegaTime.y)
    camera_shaker__extraShakeAngles.z = camera_shake__sprintSwingAmplitude * camera_shake__sprintCurrentMaxSwingRotations.z * sin(swingOmegaTime.z)

    camera_shake__sprintSwingTime += info.dt

[es(tag=gameClient, REQUIRE=hero)]
def camera_shaker_perlin_on_collision(evt : CmdCollisionDamage;
                                      hitpoints__maxHp : float;
                                      camera_shake__collisionDamageHpFactor : float;
                                      camera_shake__collisionDamageMaxTrauma : float)
  let trauma = cvt(evt.damage, 0.f, camera_shake__collisionDamageHpFactor * hitpoints__maxHp, 0.f, camera_shake__collisionDamageMaxTrauma)
  add_trauma(trauma, camera_shake__collisionDamageMaxTrauma)

[es(tag=gameClient, REQUIRE=hero)]
def camera_shaker_perlin_on_jump(evt : CmdPostPhysUpdate;
                                 human_net_phys : HumanActor;
                                 camera_shake__jumpMaxPunch : float;
                                 camera_shake__jumpMinSpeed : float;
                                 camera_shake__jumpMaxSpeed : float)
  let spdSummaryDiffY = human_net_phys.phys.currentState.spdSummaryDiff.y
  if spdSummaryDiffY >= camera_shake__jumpMinSpeed
    let pitchPunch = cvt(spdSummaryDiffY, camera_shake__jumpMinSpeed, camera_shake__jumpMaxSpeed, 0.f, -camera_shake__jumpMaxPunch)
    query() <| $ [es] (camera__active : bool;
                       camera_settings__shakePowerMult : float)
      if camera__active
        add_punch(float3(pitchPunch * camera_settings__shakePowerMult, 0.f, 0.f))















































































[es(tag=gameClient)]
def camera_shake_on_shot_receive_event(evt : CameraShakeOnShot;
                                       camera__active : bool;
                                       var camera_shaker__onShotExternalImpulse : float3&;
                                       var camera_shaker__onShotViscosity : float3&;
                                       var camera_shaker__onShotStiffness : float3&)
  if camera__active
    camera_shaker__onShotViscosity = evt.viscocity
    camera_shaker__onShotStiffness = evt.stiffness
    camera_shaker__onShotExternalImpulse = evt.impulse


def camera_shake_on_shot_iteration(var prevOffset : float3&; var offset : float3&; stiffness, viscosity, externalImpulse : float3; mass, dt : float)
  if mass > 0.
    let velocity = (offset - prevOffset) / dt
    let springForce = -stiffness * offset - viscosity * velocity
    let acceleration = springForce / mass
    let newOffset = 2.0f * offset - prevOffset + (acceleration * dt + externalImpulse / mass) * dt
    prevOffset = offset
    offset = newOffset
  offset = clamp(offset, float3(-15. * DEG_TO_RAD), float3(15. * DEG_TO_RAD))


[es(tag=gameClient, after=shooter_cam_update_tm_es, before=after_camera_sync)]
def camera_shake_on_shot_update(info : UpdateStageInfoAct;
                                camera_shaker__onShotViscosity : float3;
                                camera_shaker__onShotStiffness : float3;
                                camera_shaker__onShotMass : float;
                                var camera_shaker__onShotExternalImpulse : float3&;
                                var camera_shaker__onShotCameraOffset : float3&;
                                var camera_shaker__onShotCameraPrevOffset : float3&;
                                var transform : float3x4)
  assume stiffness = camera_shaker__onShotStiffness
  assume viscocity = camera_shaker__onShotViscosity
  assume mass = camera_shaker__onShotMass

  let FIXED_DT = 1.0 / 120.0
  let MAX_STEPS = 10
  let impulse = camera_shaker__onShotExternalImpulse
  let numSteps = min(floori(info.dt / FIXED_DT), MAX_STEPS)
  let residualTime = numSteps == MAX_STEPS ? 0.0 : info.dt - float(numSteps) * FIXED_DT

  var prevOffset = camera_shaker__onShotCameraPrevOffset
  var offset = camera_shaker__onShotCameraOffset

  
  if numSteps > 0
    camera_shake_on_shot_iteration(prevOffset, offset, stiffness, viscocity, impulse * FIXED_DT, mass, FIXED_DT)
    camera_shaker__onShotExternalImpulse = float3(0)
  for _ in range(numSteps - 1)
    camera_shake_on_shot_iteration(prevOffset, offset, stiffness, viscocity, float3(0), mass, FIXED_DT)
  if residualTime > 1e-5f
    camera_shake_on_shot_iteration(prevOffset, offset, stiffness, viscocity, impulse * residualTime, mass, residualTime)
    camera_shaker__onShotExternalImpulse = float3(0)

  camera_shaker__onShotCameraPrevOffset = prevOffset
  camera_shaker__onShotCameraOffset = offset

  var q : quat
  
  euler_to_quat(-offset.y, offset.z, -offset.x, q)
  var shakerTm : float3x4
  make_tm(q, float3(0.0f, 0.0f, 0.0f), shakerTm)
  transform = transform * shakerTm


[es(tag=gameClient, after=after_guns_update_sync, before=clear_gun_launch_events_es)]
def camera_shake_on_shot(info : ParallelUpdateFrameDelayed;
                         gun__owner : EntityId;
                         gun_launch_events : GunLaunchEvents;
                         gun__cameraShakeOnShotStrength : float3;
                         gun__cameraShakeOnShotViscocity : float3;
                         gun__cameraShakeOnShotStiffness : float3)
  if length(gun_launch_events.launchEvents) > 0
    query(gun__owner) <| $ [es(REQUIRE=hero)] (human_input__aimOffset : float2)
      assume recoilMultiplier = 100.0
      assume strength = gun__cameraShakeOnShotStrength
      assume aimOffset = human_input__aimOffset
      let impulse = float3(-aimOffset.y * strength.x * recoilMultiplier, -aimOffset.x * strength.y * recoilMultiplier, (1.0 + gauss_rnd(0)) * strength.z)

      broadcastEvent(CameraShakeOnShot(impulse = impulse,
                                         viscocity = gun__cameraShakeOnShotViscocity,
                                         stiffness = gun__cameraShakeOnShotStiffness,
                                         dt = info.dt))


[es(tag=gameClient, REQUIRE=hero)]
def camara_shake_perlin_punch_on_hit(evt : EventOnEntityHit; isAlive : bool; transform : float3x4)
  let acceptDamageType = (evt.damageType == int(DamageType.DM_MELEE) ||
                          evt.damageType == int(DamageType.DM_BACKSTAB) ||
                          evt.damageType == int(DamageType.DM_PROJECTILE) ||
                          evt.damageType == int(DamageType.DM_COLLISION))
  if has(evt.victim, "hero") && acceptDamageType && isAlive
    add_punch_by_dir(evt.deltaHp * rotate(inverse(transform), evt.hitDir))







