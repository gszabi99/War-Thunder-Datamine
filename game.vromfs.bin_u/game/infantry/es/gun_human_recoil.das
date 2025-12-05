require ecs
require ecs.safe
require app
require math
require math.base
require DaWeapons
require HumanPhys
require DagorRandom
require DagorMath
require DngHuman
require %game.events
require DaWeaponProps

def process_aim_offs(var aim_offs : float2&; var aim_angles : float2&; tau, dt : float)
  let delta = approach(aim_offs, float2(0.f), dt, tau) - aim_offs
  aim_offs += delta
  aim_angles -= delta

def private get_compensation_amount(recoil_delta : float; compensate_delta : float)
  if sign(recoil_delta) != sign(recoil_delta + compensate_delta)
    return -recoil_delta

  if abs(recoil_delta) > abs(recoil_delta + compensate_delta)
    return compensate_delta

  return 0.0

[es(tag=input, after=after_guns_update_sync, before=clear_gun_launch_events_es, REQUIRE=watchedByPlr)]
def gun_human_recoil_es(info : ParallelUpdateFrameDelayed;
                        var human_net_phys : HumanActor;
                        var human_input__aimOffset : float2&;
                        var human_input__uncompensatedAimOffset : float2&;
                        var human_input__lastShotAt : float&;
                        human_input__decayUncompensatedAimOffsetAfter : float;
                        human_input__decayAimOffsetVisc : float;
                        var human_weap__recoil : float&;
                        var human_weap__curRecoilMult : float&;
                        human_input__oldAimAngle : float2 const?;
                        var human_input__aimAngle : float2?;
                        human_weap__currentGunEid : EntityId;
                        entity_mods__recoilMult = 1.f;
                        human_net_phys__crawlRecoilMult = 0.3f;
                        human_net_phys__crouchRecoilMult = 0.7f;
                        human_net_phys__aimRecoilMult = 0.7f;
                        human_net_phys__recoilOffsMult = 1.f;
                        human_net_phys__recoilControlMult = 0.f;
                        human_input__aimOffsetVisc = 0.1f;
                        entity_mods__verticalRecoilOffsMult = 1.f;
                        entity_mods__horizontalRecoilOffsMult = 1.f;
                        platformRecoilControlMult = 1.f;
                        platformDecayUncompensatedRecoil = false;
                        human_weap__recoilMult = 1.f;
                        bipod__enabled = false;
                        bipod__recoilMult = 1.f;
                        human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  let currentGunEid  = human_weap__currentGunEid

  if !currentGunEid && !human_attached_gun__attachedGunEid
    return

  let isAttachedGun = !!human_attached_gun__attachedGunEid
  let gunEid = isAttachedGun ? human_attached_gun__attachedGunEid : (get_Eid(currentGunEid, "subsidiaryGunEid") ?? currentGunEid)

  var aimOffsetDelta = float2(0.0, 0.0)

  query(gunEid) <| $ [es] (gun_launch_events : GunLaunchEvents;
                           gun__recoilAmount : float;
                           gun__crawlRecoilMult : float const?;
                           gun__crouchRecoilMult : float const?;
                           gun__aimRecoilMult : float const?;
                           gun__recoilOffsMult : float const?;
                           gun__recoilControlMult : float const?;
                           gun__salt = 0;
                           gun__recoilDirAmount = 0.f;
                           gun__recoilDir = 0.f;
                           gun__visualRecoilMult = 1.f;
                           gun_dynamic_recoil__recoilMultForCurrentShot : float = 1.0)

    human_weap__curRecoilMult = 1.f

    if bipod__enabled
      human_weap__curRecoilMult = bipod__recoilMult <= 0. ? (gun__crawlRecoilMult ?? human_net_phys__crawlRecoilMult) : bipod__recoilMult
    elif human_net_phys.phys.currentState.isCrawl
      human_weap__curRecoilMult = gun__crawlRecoilMult ?? human_net_phys__crawlRecoilMult
    elif human_net_phys.phys.currentState.isCrouch
      human_weap__curRecoilMult = gun__crouchRecoilMult ?? human_net_phys__crouchRecoilMult

    if human_net_phys.phys.currentState.isAiming
      human_weap__curRecoilMult *= gun__aimRecoilMult ?? human_net_phys__aimRecoilMult

    if bipod__enabled
      human_weap__curRecoilMult *= bipod__recoilMult

    human_weap__curRecoilMult *= entity_mods__recoilMult * human_weap__recoilMult

    if length(gun_launch_events.launchEvents) == 0
      return

    let baseRecoilAmountForCurrentShot = gun__recoilAmount * gun_dynamic_recoil__recoilMultForCurrentShot * human_weap__curRecoilMult
    for event in gun_launch_events.launchEvents
      var seed = phys_time_to_seed(event.atTime) ^ gun__salt
      let ang = _frnd(seed) * TWOPI
      let omniOffs = float2(sin(ang), cos(ang))
      let dirOffs = float2(sin(gun__recoilDir), cos(gun__recoilDir))
      shell_start_get_props(event.shellId) <| $(shellStartProps : ShellStartProps)
        let recoilAmountForCurrentShot = shellStartProps.recoilMultiplier * baseRecoilAmountForCurrentShot
        var offs = lerp(omniOffs, dirOffs, float2(gun__recoilDirAmount)) * recoilAmountForCurrentShot
        offs.x *= entity_mods__horizontalRecoilOffsMult
        offs.y *= entity_mods__verticalRecoilOffsMult
        human_net_phys.phys.currentState.gunAimOffset += offs * (gun__recoilOffsMult ?? human_net_phys__recoilOffsMult)
        aimOffsetDelta += offs * (gun__recoilControlMult ?? human_net_phys__recoilControlMult) * platformRecoilControlMult
        human_weap__recoil += recoilAmountForCurrentShot * gun__visualRecoilMult

    human_input__aimOffset += aimOffsetDelta

    human_input__uncompensatedAimOffset -= aimOffsetDelta
    human_input__lastShotAt = info.curTime

  if human_input__aimAngle != null && human_input__oldAimAngle != null
    
    
    
    let aimAngleDelta = *human_input__oldAimAngle - *human_input__aimAngle
    let aimAngleDeltaNorm = float2(norm_s_ang(aimAngleDelta.x), norm_s_ang(aimAngleDelta.y))

    let compensationAmount = float2(get_compensation_amount(human_input__uncompensatedAimOffset.x, aimAngleDeltaNorm.x),
                                    get_compensation_amount(human_input__uncompensatedAimOffset.y, aimAngleDeltaNorm.y))

    human_input__uncompensatedAimOffset += compensationAmount


    if !platformDecayUncompensatedRecoil || info.curTime < human_input__lastShotAt + human_input__decayUncompensatedAimOffsetAfter
      process_aim_offs(human_input__aimOffset, *human_input__aimAngle, human_input__aimOffsetVisc, info.dt)
    else
      process_aim_offs(human_input__uncompensatedAimOffset, *human_input__aimAngle, human_input__decayAimOffsetVisc, info.dt)
  else
    human_input__aimOffset = float2(0.f)


[es(tag=gameClient, after=gun_update_time_between_shots)]
def gun_update_recoil_for_current_shot(evt : EventShot;
                                       gun : Gun;
                                       gun__originalTimeBetweenShots : float;
                                       gun__firingParamsRecoilMults : FloatList;
                                       gun_dynamic_recoil__timeMultToResetRecoilMult : float;
                                       var gun_dynamic_recoil__burstIndex : int&;
                                       var gun_dynamic_recoil__lastShotTime : float&;
                                       var gun_dynamic_recoil__recoilMultForCurrentShot : float&)
  
  
  
  let maxTime = gun__originalTimeBetweenShots * 2.0 * gun_dynamic_recoil__timeMultToResetRecoilMult
  let lastShotTime = gun_dynamic_recoil__lastShotTime
  let curShotTime = gun.curState.atTime

  if curShotTime - lastShotTime >= maxTime
    gun_dynamic_recoil__burstIndex = 0

  gun_dynamic_recoil__recoilMultForCurrentShot = gun__firingParamsRecoilMults?[gun_dynamic_recoil__burstIndex] ?? 1.0

  gun_dynamic_recoil__burstIndex++
  gun_dynamic_recoil__lastShotTime = curShotTime