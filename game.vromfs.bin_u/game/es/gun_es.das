require ecs

require DaWeapons
require DngWeapon
require DagorSystem
require DagorRandom
require DaWeapons
require DagorMath
require DaWeaponProps
require BallisticsProps
require PropsManager
require %game.events


struct GunUpdateInput
  atTime : float
  isForReal : bool
  gunEid : EntityId
  offenderEid : EntityId
  pointVel : float3
  @safe_when_uninitialized curGunPropsId : PropsId
  shellIndexInSet : int
  extraDeviation : float
  zeroingAngle : float
  projectileVelocityMult : float

def private init_ammo_set(ammo_set__shellIds : IntList; gun__shell_prop_ids : PropsIdList; var ammo_set_indices : array<int>&)
  let shellPropsSize = length(gun__shell_prop_ids)
  for shellInd in ammo_set__shellIds
    if shellInd < shellPropsSize
      ammo_set_indices |> push(shellInd)

def private gun_launch(ld : LaunchDesc; gun_eid : EntityId;  offender_eid : EntityId)
  sendEventImmediate(gun_eid, [[CmdGuidanceLockSwitch on = false]])
  var ok = false
  shell_entity_get_props(ld.shellId) <| $(entProps : ShellEntityTypeProps)
    let physTemplName = entProps.physTemplName
    if !empty(physTemplName)
      ok = true
      sendEventImmediate(offender_eid, [[CmdLaunchShell launchDesc=ld, gunEid=gun_eid]])
  if !ok
    get_props_ProjBallisticsProperties(ld.shellId) <| $ [unused_argument(_)] (_ : ProjBallisticsProperties)
      ok = true
      sendEventImmediate(offender_eid, [[CmdLaunchProjectile launchDesc=ld, gunEid=gun_eid]])
  return ok

def private gun_launch(var gun : Gun&;
                       input : GunUpdateInput;
                       var num_shells : int&;
                       shot_time : float;
                       correction_time : float;
                       curShellId : PropsId;
                       ammo_set_indices : array<int>;
                       
                       gun__shell_prop_ids : PropsIdList const ?)
  if !curShellId.valid
    return false

  if !input.isForReal 
    return true

  if num_shells == 0
    return false

  --num_shells

  assume state = gun.curState
  assume prevState = gun.prevState
  var spreadSettings = [[SpreadSettings]]
  gun_getSpreadSettings(gun, state, spreadSettings)

  var launchTm = state.shootTm
  if correction_time > 1e-6f 
    let prevQuat = DagorMath::quat(prevState.shootTm)
    let curQuat = DagorMath::quat(state.shootTm)
    assert(input.atTime > state.atTime);
    let alpha = correction_time / (input.atTime - state.atTime)
    make_tm(normalize(slerp(prevQuat, curQuat, alpha)), launchTm)
    launchTm[3] = lerp(prevState.shootTm.[3], state.shootTm[3], float3(alpha))

  let ammoSetSize = length(ammo_set_indices)
  let shellId = ammoSetSize > 0 ? (*gun__shell_prop_ids)[ammo_set_indices[input.shellIndexInSet % ammoSetSize]] : curShellId
  shell_start_get_props(shellId) <| $(shellStartProps : ShellStartProps)
    let dir = calc_projectile_dir(spreadSettings, gun.gunProps.spread, shellStartProps.spread, launchTm, state.randSeed,
      shellStartProps.pitch + input.zeroingAngle)
    let vel = dir * shellStartProps.speed * (1.f + _srnd(state.randSeed) * shellStartProps.speedDispersion) * input.projectileVelocityMult + input.pointVel
    var evt = [[EventShot]]
    if (length_sq(launchTm[3]) < 1e10 && length_sq(vel) < 1e10)
      evt.launchDesc.shellId = ammoSetSize > 0 ? (*gun__shell_prop_ids)[ammo_set_indices[input.shellIndexInSet % ammoSetSize]] : curShellId
      evt.launchDesc.gunPropsId = input.curGunPropsId
      evt.launchDesc.atTime = shot_time
      evt.launchDesc.initialLifeTime = correction_time
      evt.launchDesc.tm = launchTm
      evt.launchDesc.vel = vel
      evt.launchDesc.firingMode = uint(state.firingMode)
      evt.launchDesc.bombBayHeight = state.bombBayHeight
      if gun_launch(evt.launchDesc, input.gunEid, input.offenderEid)
        sendEventImmediate(input.gunEid, evt);
    else
      logerr("gun_launch try to start projectile with invalid data.
              {launchTm[3]} {vel} {dir} {shellStartProps.speed} {shellStartProps.speedDispersion}
              {input.projectileVelocityMult} {input.pointVel}")
  return true

def private gun_schedule_next_shot(var gun : Gun&; at_time : float; var rand_seed : int&)
  assume state = gun.curState
  assume firingMode = gun_getFiringMode(gun, int(state.firingMode))
  var timeBetweenShots = gun.gunProps.timeBetweenShots * firingMode.shotFreqMultiplier
  var boltActionTime = gun.gunProps.boltActionTime

  if firingMode.modeType == EFiringModeType EFM_MANUAL && !firingMode.autoScheduleShots
    timeBetweenShots *= gun.appliedControls.boltActionMult
    boltActionTime *= gun.appliedControls.boltActionMult

  let physStep = 1.f / 30.f;
  let dispK = 1.f + _srnd(rand_seed) * (physStep / 5.f);
  state.nextShotAtTime = at_time + timeBetweenShots * dispK;
  state.boltActionEndAtTime = at_time + boltActionTime * dispK;
  state.lastShotAtTime = at_time;
  state.timeBetweenShots = timeBetweenShots;

def private gun_update_shot_dry(var gun : Gun&; num_shells : int; gun_eid : EntityId)
  assume state = gun.curState
  if gun.appliedControls.shoot && num_shells == 0
    if state.atTime >= state.nextShotAtTime
      if state.atTime >= state.shotDryNextTime
        sendEventImmediate(gun_eid, [[EventShotDry]])
      state.shotDryNextTime = state.atTime + gun.appliedControls.timeStep * 2.
  else
    state.shotDryNextTime = 0.

def private gun_update(var gun : Gun&;
                       var input : GunUpdateInput&;
                       var num_shells : int&;
                       rnd_seed : int;
                       gun__curShellId : PropsId;
                       ammo_set_indices : array<int>;
                       gun__shell_prop_ids : PropsIdList const?)
  assume state = gun.curState
  if input.isForReal
    gun_update_shot_dry(gun, num_shells, input.gunEid)
  state.randSeed = rnd_seed

  assume firingMode = gun_getFiringMode(gun, int(state.firingMode))
  let shootOnRelease = firingMode.modeType == EFiringModeType EFM_ONRELEASE
  let shootNextBurst = (firingMode.modeType == EFiringModeType EFM_BURST &&
                        int(state.burstCounter) > 0 &&
                        int(state.burstCounter) < firingMode.burstSize &&
                        num_shells > 0)
  if shootNextBurst || (shootOnRelease ? state.isPrevAppliedControlShoot && !gun.appliedControls.shoot : gun.appliedControls.shoot)
    var fixedDt = gun.appliedControls.timeStep
    if fixedDt <= 0.f
      logerr("GunControls::syncTime <= 0 ({fixedDt}) in gun_update");
      fixedDt = 1.f / 30.f;

    
    
    state.atTime = max(state.atTime, input.atTime - fixedDt);
    
    while input.atTime >= state.nextShotAtTime && state.loaded
      var launchCorrectionTime = 0.f
      if state.atTime < state.nextShotAtTime
        launchCorrectionTime = state.nextShotAtTime - state.atTime
        if launchCorrectionTime > gun.gunProps.timeBetweenShots * firingMode.shotFreqMultiplier
          launchCorrectionTime = 0.f
        state.lastShotAtTime = state.nextShotAtTime
      else
        state.lastShotAtTime = input.atTime
      if !gun_launch(gun, input, num_shells, state.lastShotAtTime, launchCorrectionTime, gun__curShellId, ammo_set_indices, gun__shell_prop_ids)
        state.loaded = false
        break

      input.shellIndexInSet++
      state.burstCounter = uint16(int(state.burstCounter) + 1)
      if firingMode.autoScheduleShots
        var atTime = state.lastShotAtTime
        if firingMode.modeType == EFiringModeType EFM_AUTOMATIC && !state.isPrevAppliedControlShoot && gun.appliedControls.shoot 
                                                                                                                                
          
          
          
          atTime = ceil(atTime / fixedDt - 1e-3) * fixedDt 
        var seed = num_shells
        gun_schedule_next_shot(gun, atTime, seed)
      if !firingMode.autoScheduleShots || (firingMode.modeType == EFiringModeType EFM_BURST && int(state.burstCounter) >= firingMode.burstSize)
        state.loaded = false
        break
  elif !firingMode.autoScheduleShots
    if state.nextShotAtTime < input.atTime && !state.loaded && num_shells > 0
      var seed = num_shells
      gun_schedule_next_shot(gun, input.atTime, seed)
      state.loaded = true
  elif ((firingMode.modeType == EFiringModeType EFM_BURST &&
        (int(state.burstCounter) == 0 || int(state.burstCounter) >= firingMode.burstSize || num_shells == 0)) ||
        firingMode.modeType == EFiringModeType EFM_AUTOMATIC)
    state.burstCounter = uint16(0)
    state.loaded = true

  state.isPrevAppliedControlShoot = gun.appliedControls.shoot
  state.atTime = input.atTime

def private gun_update_tms(var gun : Gun&;
                           var gun_deviation : GunDeviation&;
                           gun__owner : EntityId;
                           gloc : GunLocation;
                           gctrl : GunControls;
                           at_time : float)
  var shootTm : float3x4
  var gunTm : float3x4
  let visTm : float3x4 const? = gloc.visTm
  let physTm : float3x4 const? = gloc.physTm
  if gloc.gunPos != null
    gun |> gun_calculate_shoot_tm(gloc.gunShootDir, gloc.gunPos, null, null, shootTm)
    gun |> gun_calculate_shoot_tm(gloc.gunDir, gloc.gunPos, null, null, gunTm)
  else
    gun |> gun_calculate_shoot_tm(gloc.gunShootDir, null, visTm, physTm, shootTm)
    gun |> gun_calculate_shoot_tm(gloc.gunDir, null, visTm, physTm, gunTm)

  var movementDeviationMult = 1.
  query(gun__owner) <| $ [es] (entity_mods__movementShotSpreadDecrMult : float)
    movementDeviationMult = entity_mods__movementShotSpreadDecrMult
  gun_deviation |> gun_deviationUpdate(at_time, gunTm[0], gctrl.shoot, movementDeviationMult)

  assume state = gun.curState
  if get_bool(gun__owner, "bipod__enabled") ?? false
    state.extraDeviation = float2(gun_deviation.minExtraDev, gun_deviation.minExtraDev)
  else
    state.extraDeviation = float2(gun_deviation.extraDev, gun_deviation.extraDev)
  state.gunTm = gunTm
  state.shootTm = shootTm


def private gun_update_shoot(var gun : Gun&; gctrl : GunControls)
  gun.appliedControls = gctrl

[es]
def gun_update_es(evt : CmdGunUpdate;
                  eid : EntityId;
                  gun__owner : EntityId;
                  gun__maxAmmo : int;
                  gun__salt : int;
                  gun__propsId : PropsId;
                  gun__curShellId : PropsId;
                  var gun__ammo : int&;
                  var gun : Gun&;
                  var gun_deviation : GunDeviation&;
                  gun__offender : EntityId const?;
                  gun__shell_prop_ids : PropsIdList const?;
                  ammo_set__shellIds : IntList const?;
                  gun__zeroingAngle : float = 0.;
                  gun__projectileVelocityMult : float = 1.;
                  gun__ignoreWeaponVelocity : bool = false;
                  mounted_gun : MountedGun const?)
  if evt.isForReal
    gun.prevState = gun.curState
    gun_update_tms(gun, gun_deviation, gun__owner, evt.gloc, evt.gctrl, evt.atTime)

  
  
  let isReplay = find_query() <| $ [es(REQUIRE=replayIsPlaying)] => true
  if isReplay && mounted_gun == null
    return

  let gloc = evt.gloc
  gun.appliedControls = evt.gctrl

  var gunIn = [[GunUpdateInput]]
  gunIn.atTime = evt.atTime
  gunIn.isForReal = evt.isForReal
  gunIn.gunEid = eid
  gunIn.offenderEid = !!gun__owner ? gun__owner : (gun__offender != null ? *gun__offender : eid)
  gunIn.pointVel = !gun__ignoreWeaponVelocity ? (gloc.gunVel ?? float3()) : float3()
  gunIn.curGunPropsId = gun__propsId
  gunIn.extraDeviation = gun_deviation.extraDev
  gunIn.zeroingAngle = gun__zeroingAngle
  gunIn.projectileVelocityMult = gun__projectileVelocityMult

  var curShellId = -1
  var ammo_set_indices : array<int>
  if ammo_set__shellIds != null && gun__shell_prop_ids != null
    if length(*ammo_set__shellIds) == 1
      let shellId = (*ammo_set__shellIds)[0]
      if shellId < length(*gun__shell_prop_ids)
        curShellId = shellId
    else
      init_ammo_set(*ammo_set__shellIds, *gun__shell_prop_ids, ammo_set_indices);
      let shellNumber = max(0, gun__maxAmmo - gun__ammo)
      gunIn.shellIndexInSet = shellNumber % max(1, length(ammo_set_indices))

  let rndSeed = evt.seed ^ gun__salt 
  gun_update(gun, gunIn, gun__ammo, rndSeed, curShellId < 0 ? gun__curShellId : (*gun__shell_prop_ids)[curShellId], ammo_set_indices, gun__shell_prop_ids)
