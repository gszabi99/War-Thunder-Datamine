require ecs
require math.base
require DngHuman
require PhysVars
require DagorRandom
require DagorMath
require %game.events

def random_p3(mu, sigma : float3) : float3
  return mu + sigma * float3(gauss_rnd(0), gauss_rnd(0), gauss_rnd(0))

def recoil_update(var pos : float3&; var vel : float3&; spring, damp, inertia : float3; dt : float)
  let invInertia = safeinv(inertia)
  
  let updateRate = 1.0 / 120.0
  var critDamping = 4.f * spring * inertia
  critDamping.x = sqrt(critDamping.x)
  critDamping.y = sqrt(critDamping.y)
  critDamping.z = sqrt(critDamping.z)
  let resDamping = damp * critDamping
  var remainingDt = dt
  while remainingDt > 0.f
    let curDt = min(remainingDt, updateRate)
    let acc = -(spring * pos + resDamping * vel) * invInertia
    pos += vel * curDt + acc * curDt * curDt * 0.5f
    vel += acc * curDt
    remainingDt -= updateRate

def constraint_movement(var pos : float3&; var vel : float3&; limit : float3)
  for i in range(0, 3)
    if pos[i] < -limit[i] || pos[i] > limit[i]
      vel[i] = 0.f
    pos[i] = clamp(pos[i], -limit[i], limit[i])

def constraint_movement(var pos : float3&; var vel : float3&; limit_min, limit_max : float3)
  for i in range(0, 3)
    if pos[i] < limit_min[i] || pos[i] > limit_max[i]
      vel[i] = 0.f
    pos[i] = clamp(pos[i], limit_min[i], limit_max[i])

[es(after=update_phys_es, before=anim_phys_updater_es, before=animchar_es, REQUIRE_NOT=deadEntity)]
def human_anim_weap(info : ParallelUpdateFrameDelayed;
                    transform : float3x4;
                    human_net_phys : HumanActor;
                    human_anim__weaponRollVarId : int;
                    human_anim__weaponYawVarId : int;
                    human_anim__weaponPitchVarId : int;
                    human_anim__weaponOffsFwdVarId : int;
                    human_anim__weaponOffsUpVarId : int;
                    human_anim__weaponOffsLeftVarId : int;
                    human_net_phys__aimPosition : float;
                    bipod__enabled : bool = false;
                    bipod__crawlGunOffset : float3;
                    var bipod__crawlGunAnimOffset : float3&;
                    var phys_vars : PhysVars;
                    human_weap__gunEids : EidList;
                    human_weap__currentGunSlot : int;
                    human_weap__gunAngleSpeed : float2;
                    human_weap__gunAngleSpeedToVelocityMult : float3;
                    human_weap__gunAngleSpeedToOmegaMult : float3;
                    var human_weap__recoil : float&;
                    var human_weap__gunOffset : float3&;
                    var human_weap__gunVelocity : float3&;
                    human_weap__gunOffsetSpring : float3;
                    human_weap__gunOffsetDamping : float3;
                    var human_weap__gunRotation : float3&;
                    var human_weap__gunOmega : float3&;
                    human_weap__gunRotationSpring : float3;
                    human_weap__gunRotationDamping : float3;
                    human_weap__curRecoilMult : float;
                    human_weap__gunOffsAngles : float3;
                    var prevVisualBoltActionProgress : float&;
                    boltActionProgress : float;
                    human_weap__gunOffsetLimit : float3;
                    human_weap__gunRotationLimit : float3;
                    animchar__visible = true;
                    var human_weap__gunVelocityBasedOffsetCurrent : float3&;
                    human_weap__gunVelocityBasedOffsetViscosity : float;
                    human_weap__gunVelocityBasedOffsetLimitMin : float3;
                    human_weap__gunVelocityBasedOffsetLimitMax : float3;
                    human_weap__gunVelocityBasedMult : float3;
                    human_weap__jumpOffsetMinMaxGunWeight : float2;
                    human_weap__jumpOffsetAddVelocity : float3;
                    human_weap__jumpOffsetAddOmega : float3;
                    human_phys__jumpStartTime : float;
                    human_phys__jumpEndTime : float;
                    human_phys__afterJumpDelay : float;
                    human_weap__recoilToImpulseMult : float = 20.f;
                    human_anim__bipodCrawlGunOffsetViscosity : float = 0.05)
  if !animchar__visible
    return
  if human_weap__currentGunSlot < 0
    return
  let gunEid = human_weap__gunEids[human_weap__currentGunSlot]
  query(gunEid) <| $ [es] (gun__inertialMass : float;
                           gun__rotInertia, gun__recoilOffsetMean, gun__recoilOffsetDeviation,
                           gun__recoilRotationMean, gun__recoilRotationDeviation : float3;
                           gun__recoilAmount : float;
                           gun__recoilOriMultInAim : float3;
                           gun__rotationSpringMult : float3;
                           gun__visualRecoilMult : float = 1.0;
                           gun__visualBoltRecoilMult : float = 0.3)
    let massInertia = float3(gun__inertialMass, gun__inertialMass, gun__inertialMass)
    let rotInertia = gun__rotInertia * gun__inertialMass
    var invMoi = safeinv(rotInertia)
    let dtRate = 60. * info.dt 
    if boltActionProgress > 0.5 && prevVisualBoltActionProgress <= 0.5
      human_weap__recoil = gun__recoilAmount * gun__visualRecoilMult * human_weap__curRecoilMult * gun__visualBoltRecoilMult
    if human_weap__recoil > 0.f
      let invMass = safeinv(massInertia)
      let velRecoilMult = random_p3(gun__recoilOffsetMean, gun__recoilOffsetDeviation)
      let recoilOriMult = human_net_phys__aimPosition > 0.5 ? gun__recoilOriMultInAim : float3(1.0, 1.0, 1.0)
      human_weap__gunVelocity += human_weap__recoil * human_weap__recoilToImpulseMult * invMass * velRecoilMult

      let omegaRecoilMult = random_p3(gun__recoilRotationMean, gun__recoilRotationDeviation)
      human_weap__gunOmega += human_weap__recoil * human_weap__recoilToImpulseMult * invMoi * omegaRecoilMult * recoilOriMult

    human_weap__gunOmega += human_weap__gunOffsAngles * dtRate
    var invMass = safeinv(gun__inertialMass)
    if bipod__enabled
      invMoi *= 0.
      invMass *= 0.
    prevVisualBoltActionProgress = boltActionProgress
    human_weap__recoil = 0.f
    human_weap__gunVelocity.y += human_weap__gunAngleSpeed.y * human_weap__gunAngleSpeedToVelocityMult.y * invMass * dtRate
    human_weap__gunVelocity.z += human_weap__gunAngleSpeed.x * human_weap__gunAngleSpeedToVelocityMult.z * invMass * dtRate
    human_weap__gunOmega.x += human_weap__gunAngleSpeed.x * human_weap__gunAngleSpeedToOmegaMult.x * invMoi.x * dtRate
    human_weap__gunOmega.y += human_weap__gunAngleSpeed.x * human_weap__gunAngleSpeedToOmegaMult.y * invMoi.y * dtRate
    human_weap__gunOmega.z += human_weap__gunAngleSpeed.y * human_weap__gunAngleSpeedToOmegaMult.z * invMoi.z * dtRate

    
    let jumpOffsetApplyTime = max(human_phys__jumpEndTime, human_phys__jumpStartTime)
    let jumpOffsetWeight = 1.0 - abs(cvt(info.curTime, jumpOffsetApplyTime, jumpOffsetApplyTime + human_phys__afterJumpDelay, -1.0, 1.0)) 
    let jumpOffsetGunWeightMod = cvt(gun__inertialMass, human_weap__jumpOffsetMinMaxGunWeight.x, human_weap__jumpOffsetMinMaxGunWeight.y, 0.0, 1.0)
    human_weap__gunVelocity += human_weap__jumpOffsetAddVelocity * jumpOffsetWeight * jumpOffsetGunWeightMod
    human_weap__gunOmega += human_weap__jumpOffsetAddOmega * jumpOffsetWeight * jumpOffsetGunWeightMod

    recoil_update(human_weap__gunOffset, human_weap__gunVelocity,
                  human_weap__gunOffsetSpring, human_weap__gunOffsetDamping,
                  massInertia, info.dt)

    recoil_update(human_weap__gunRotation, human_weap__gunOmega,
                  human_weap__gunRotationSpring * gun__rotationSpringMult, human_weap__gunRotationDamping,
                  rotInertia, info.dt)

    setVar(phys_vars, human_anim__weaponRollVarId, human_weap__gunRotation.x)
    setVar(phys_vars, human_anim__weaponYawVarId, human_weap__gunRotation.y)
    setVar(phys_vars, human_anim__weaponPitchVarId, human_weap__gunRotation.z)

    constraint_movement(human_weap__gunOffset, human_weap__gunVelocity, human_weap__gunOffsetLimit)
    constraint_movement(human_weap__gunRotation, human_weap__gunOmega, human_weap__gunRotationLimit)

    
    assume phys = human_net_phys.phys
    let interpK = get_phys_interpk_clamped(phys, info.curTime)
    let velocity = lerp(phys.previousState.velocity, phys.currentState.velocity, float3(interpK))
    let upVelocity = dot(velocity, transform[1])
    var velocityBasedOffset = float3(0.0, upVelocity * human_weap__gunVelocityBasedMult.y, 0.0)
    var spd = float3(0.0)
    constraint_movement(velocityBasedOffset, spd, human_weap__gunVelocityBasedOffsetLimitMin, human_weap__gunVelocityBasedOffsetLimitMax)
    human_weap__gunVelocityBasedOffsetCurrent = approach(human_weap__gunVelocityBasedOffsetCurrent, velocityBasedOffset, info.dt, human_weap__gunVelocityBasedOffsetViscosity)
    let offset = human_weap__gunOffset + human_weap__gunVelocityBasedOffsetCurrent

    if bipod__enabled
      bipod__crawlGunAnimOffset = approach(bipod__crawlGunAnimOffset, bipod__crawlGunOffset, info.dt, human_anim__bipodCrawlGunOffsetViscosity)
      setVar(phys_vars, human_anim__weaponOffsFwdVarId, offset.x + bipod__crawlGunAnimOffset.x)
      setVar(phys_vars, human_anim__weaponOffsUpVarId, offset.y + bipod__crawlGunAnimOffset.y)
      setVar(phys_vars, human_anim__weaponOffsLeftVarId, offset.z + bipod__crawlGunAnimOffset.z)
    else
      setVar(phys_vars, human_anim__weaponOffsFwdVarId, offset.x)
      setVar(phys_vars, human_anim__weaponOffsUpVarId, offset.y)
      setVar(phys_vars, human_anim__weaponOffsLeftVarId, offset.z)