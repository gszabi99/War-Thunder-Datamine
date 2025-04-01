require ecs
require GamePhys
require HumanPhys
require DngHuman

require %game.events
require DagorMath
require math.base
require %appGame.es.human_weap_common

[es(on_appear)]
def init_default_holster_equip_times_es(evt : Event;
                                        var human_weap__defHolsterTime : FloatList&;
                                        var human_weap__defEquipTime : FloatList&;
                                        human_net_phys : HumanActor&)
  assume weaponParams = human_net_phys.phys.weaponParams
  for wp in weaponParams
    push(human_weap__defHolsterTime, wp.holsterTime)
    push(human_weap__defEquipTime, wp.equipTime)

def private update_holster_equip_times_impl(human_weap__gunEids : EidList&;
                                            human_weap__defHolsterTime : FloatList&;
                                            human_weap__defEquipTime : FloatList&;
                                            var human_net_phys : HumanActor&)
  assume weaponParams = human_net_phys.phys.weaponParams
  for gunEid, i in human_weap__gunEids, range(0, length(human_weap__gunEids))
    var weaponHolsterTime = -1.0
    var weaponEquipTime = -1.0
    query(gunEid) <| $ [es] (weapon__holsterTime : float = -1.f;
                             weapon__equipTime : float = -1.f)
      weaponHolsterTime = weapon__holsterTime
      weaponEquipTime = weapon__equipTime
    weaponParams[i].holsterTime = weaponHolsterTime > 0.0 ? weaponHolsterTime : human_weap__defHolsterTime[i]
    weaponParams[i].equipTime = weaponEquipTime > 0.0 ? weaponEquipTime : human_weap__defEquipTime[i]

[es(track=human_weap__gunEids, before=update_weapon_equip_state)]
def update_holster_equip_time_on_gun_eids_change_es(evt : Event;
                                                    human_weap__defHolsterTime : FloatList&;
                                                    human_weap__defEquipTime : FloatList&;
                                                    human_weap__gunEids : EidList;
                                                    var human_net_phys : HumanActor&)
  update_holster_equip_times_impl(human_weap__gunEids, human_weap__defHolsterTime, human_weap__defEquipTime, human_net_phys)

[es(on_appear, track=slot_attach__weaponSlotIdx)]
def update_holster_equip_time_on_weapon_slot_change_es(evt : Event;
                                                       slot_attach__weaponSlotIdx : int;
                                                       gun__owner : EntityId)
  if slot_attach__weaponSlotIdx < 0
    return
  query(gun__owner) <| $ [es] (var human_net_phys : HumanActor&;
                               human_weap__gunEids : EidList;
                               human_weap__defHolsterTime : FloatList&;
                               human_weap__defEquipTime : FloatList&)
    update_holster_equip_times_impl(human_weap__gunEids, human_weap__defHolsterTime, human_weap__defEquipTime, human_net_phys)

[es]
def update_weapon_equip_state(evt : CmdPostPhysUpdate;
                              human_weap__gunMatId : int;
                              human_weap__gunBackoffVisc : float = 0.1;
                              human_weap__gunTraceTime : float = 0.2;
                              human_weap__gunMaxBackoff : float = 0.0;
                              human_weap__gunMinBackupDist : float = 0.2;
                              human_weap__gunBackupDistFactor : float = 0.5;
                              var human_weap__gunBackupLastTime : float&;
                              human_weap__gunBackupOptTime : float = 0.5;
                              human_net_phys__isSimplifiedPhys : bool = false;
                              var human_net_phys : HumanActor&)
  assume phys = human_net_phys.phys
  assume currentState = phys.currentState
  assume appliedCT = phys.appliedCT
  assume weapEquipState = currentState.weapEquipState
  assume weaponParams = phys.weaponParams

  if !phys.hasGuns
    return

  var humanTm : float3x4
  currentState.location |> location_toTM(humanTm)
  var gunTm : float3x4
  human_phys_calcGunTm(phys, PrecomputedPresetMode TPV, humanTm, currentState.gunAngles.y, currentState.leanPosition, currentState.height, gunTm)

  if weapEquipState.curState == HUWeaponEquipState EES_EQUIPED || weapEquipState.curState == HUWeaponEquipState EES_DOWN
    if appliedCT.chosenWeapon != weapEquipState.curSlot && weaponParams[int(appliedCT.chosenWeapon)].exists && phys.canSwitchWeapon
      phys |> reset_weapon_state()

  if weapEquipState.curState == HUWeaponEquipState EES_EQUIPED
    if human_phys_state_forceWeaponUp(currentState) || human_phys_state_attachedToExternalGun(currentState)
      return
    var backoff = 0.
    if !human_net_phys__isSimplifiedPhys
      let curTime = float(evt.tick) * evt.dt
      let doOpt = curTime - human_weap__gunBackupLastTime > human_weap__gunBackupOptTime
      let fastCheckIdx = doOpt ? evt.tick % 4 : -1
      let intersects = check_gun_trace(phys, gunTm, -1., human_weap__gunMatId, human_weap__gunMaxBackoff, backoff, human_weap__gunMinBackupDist, human_weap__gunBackupDistFactor, fastCheckIdx)
      if intersects || human_phys_state_get_forceWeaponDown(currentState) || human_phys_state_get_isClimbing(currentState)
        currentState.gunTraceTimer = 0.
        weapEquipState.curState = HUWeaponEquipState EES_DOWN
      if intersects || backoff > 0.f
        human_weap__gunBackupLastTime = curTime
    currentState.gunBackoffAmount = approach(currentState.gunBackoffAmount, backoff, evt.dt, human_weap__gunBackoffVisc)

  elif weapEquipState.curState == HUWeaponEquipState EES_HOLSTERING
    let holsterTime = weaponParams[int(weapEquipState.curSlot)].holsterTime
    let holsterMult = currentState.fasterChangeWeaponMult * weaponParams[int(weapEquipState.nextSlot)].holsterSwapSpeedMult
    weapEquipState.progress += safediv(evt.dt, holsterTime) * holsterMult
    if appliedCT.chosenWeapon != weapEquipState.nextSlot
      weapEquipState.nextSlot = appliedCT.chosenWeapon
    if weapEquipState.progress >= 1.
      weapEquipState.progress -= 1.
      weapEquipState.curState = HUWeaponEquipState EES_EQUIPING
    if currentState.moveState == HUMoveState EMS_SPRINT && !phys.allowWeaponSwitchOnSprint
      weapEquipState.progress = 0.
      weapEquipState.curState = HUWeaponEquipState EES_EQUIPED
  elif weapEquipState.curState == HUWeaponEquipState EES_EQUIPING
    let equipTime = weaponParams[int(weapEquipState.nextSlot)].equipTime
    let equipMult = currentState.fasterChangeWeaponMult * weaponParams[int(weapEquipState.nextSlot)].equipSpeedMult
    weapEquipState.progress += safediv(evt.dt, equipTime) * equipMult
    if weapEquipState.progress >= 1.
      weapEquipState.progress = 0.
      weapEquipState.curState = HUWeaponEquipState EES_EQUIPED
      if phys.canSwitchWeapon
        weapEquipState.curSlot = weapEquipState.nextSlot
  elif weapEquipState.curState == HUWeaponEquipState EES_DOWN
    var backoff = 0.
    let isGunDownByState = human_phys_state_get_forceWeaponDown(currentState) || human_phys_state_get_isClimbing(currentState)
    if (human_phys_state_forceWeaponUp(currentState)
        || human_phys_state_attachedToExternalGun(currentState)
        || (!isGunDownByState &&
           (human_net_phys__isSimplifiedPhys || !check_gun_trace(phys, gunTm, -1., human_weap__gunMatId, human_weap__gunMaxBackoff, backoff, human_weap__gunMinBackupDist, human_weap__gunBackupDistFactor))))
      currentState.gunTraceTimer += evt.dt
      if (currentState.gunTraceTimer > human_weap__gunTraceTime)
        weapEquipState.curState = HUWeaponEquipState EES_EQUIPED
