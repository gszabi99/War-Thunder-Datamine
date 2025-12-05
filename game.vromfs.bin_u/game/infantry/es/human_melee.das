require ecs
require app
require net
require math.base
require %game.events
require %appGame.infantry.es.human_weap_common
require PhysVars
require HumanPhys
require DngHuman
require DngWeapon
require DaWeapons
require %appGame.infantry.es.action_common
require AnimV20
require PropsManager























def run_human_melee_action(eid : EntityId;
                           human_net_phys : HumanActor;
                           override_time : float;
                           override_props_id : PropsId;
                           override_at : float;
                           attack_period : float;
                           progress : float = 0.0;
                           time_mult : float = 1.0)
  let meleeName = human_net_phys.phys.currentState.isCrawl ? "crawl_melee" : "stand_melee"

  if is_server()
    sendEvent(eid, CmdInterruptReloadImmediately())

  
  
  let curInterpDelayTicksPacked = 1
  run_action(eid, meleeName, override_props_id, curInterpDelayTicksPacked,
             override_time, override_at, attack_period, progress, time_mult)


def is_melee_input_triggered(gun__melee : bool;
                             is_melee_disabled : bool;
                             gctrl : GunControls&;
                             phys : HumanPhys&)
  let isMainMeleeAttackActive = gun__melee && gctrl.shoot
  let isSecondaryMeleeAttackActive = !is_melee_disabled && phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_MELEE)
  return isMainMeleeAttackActive || isSecondaryMeleeAttackActive


def can_run_melee_action(eid : EntityId;
                         gun__melee : bool;
                         is_melee_disabled : bool;
                         phys : HumanPhys&;
                         gctrl : GunControls&;
                         human_net_phys : HumanActor&;
                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  if is_melee_input_triggered(gun__melee, is_melee_disabled, gctrl, phys)
    return true

  let isHumanAllowedShooting = is_human_allowed_shooting(eid, human_attached_gun__attachedGunEid, human_net_phys)
  let isShootControlBit = phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT)
  let isSwimming = phys.currentState |> human_phys_state_get_is_swimming()

  return !isHumanAllowedShooting && isShootControlBit && isSwimming


[es(REQUIRE_NOT=meleeChargeWeapon)]
def melee_weapon_phys_es(evt : CmdWeapPhysUpdate;
                         melee_weapon__propsId : PropsId;
                         gun__melee : bool;
                         melee_weapon__attackTime : float = -1.0;
                         melee_weapon__attackAt : float = -1.0;
                         melee_weapon__attackPeriod : float = -1.0;
                         disableMelee : Tag const?)
  if !evt.isForReal
    return

  let ownerEid = evt.owner

  query(ownerEid) <| $ [es] (human_unarmed__active : bool = false;
                             human_net_phys : HumanActor&;
                             isInVehicle : bool = false;
                             entity_mods__meleeSpeedMult : float)
    if (isInVehicle || human_unarmed__active)
      return

    let isCanRunMeleeAction = can_run_melee_action(ownerEid, gun__melee, disableMelee != null,
                                                   human_net_phys.phys,
                                                   evt.gctrl, human_net_phys)
    if isCanRunMeleeAction
      run_human_melee_action(ownerEid, human_net_phys, melee_weapon__attackTime,
                             melee_weapon__propsId, melee_weapon__attackAt,
                             melee_weapon__attackPeriod, 0.0, entity_mods__meleeSpeedMult)


[es(REQUIRE=meleeChargeWeapon)]
def charge_melee_weapon_phys_es(evt : CmdWeapPhysUpdate;
                                melee_weapon__propsId : PropsId;
                                melee_weapon__attackTime : float = -1.0;
                                melee_weapon__attackAt : float = -1.0;
                                melee_weapon__attackPeriod : float = -1.0)
  if !evt.isForReal
    return

  let ownerEid = evt.owner

  query(ownerEid) <| $ [es] (human_unarmed__active : bool = false;
                             human_net_phys : HumanActor&;
                             isInVehicle : bool;
                             action__running : bool;
                             human_melee_charge__animProgress : float;
                             entity_mods__meleeSpeedMult : float;
                             human_melee_charge__minStaminaLevelToStart : float;
                             human_melee_charge__isOnCooldown : bool;
                             var human_melee_charge__canStart : bool&;
                             var human_melee_charge__chargeEndTime : float&;
                             var human_melee_charge__isActive : bool&;
                             var human_melee_charge__isChargeOrAttack : bool&)
    human_melee_charge__isChargeOrAttack &&= action__running
    human_melee_charge__canStart = false
    if (isInVehicle || human_unarmed__active)
      return
    assume phys = human_net_phys.phys
    assume currentState = phys.currentState
    let isMeleeInputTriggered = phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_MELEE)
    let isChargeInputTriggered = isMeleeInputTriggered && phys.appliedCT.isAltAttackState

    let shouldPlayChargeAction = human_melee_charge__isActive && !isChargeInputTriggered
    let wasCharging = human_melee_charge__isActive
    let walkSpeed = phys |> human_phys_getWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_WALK) * currentState.moveSpeedMult
    let isSprintContol = phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_SPRINT)
    let isRunSpeed = length_sq(currentState.velocity) > square(walkSpeed)
    let forbiddenState = (int(StateFlag.ST_CROUCH) | int(StateFlag.ST_CRAWL) | int(StateFlag.ST_SWIM) | int(StateFlag.ST_DOWNED))
    let isValidState = (int(currentState.states) & forbiddenState) == 0
    let isSprintState = (int(currentState.states) & int(StateFlag.ST_SPRINT)) != 0
    let isSprinting = isSprintContol && (isSprintState || (wasCharging && isRunSpeed)) && isValidState
    let isStartBlocked = !isValidState || human_melee_charge__isOnCooldown || currentState.stamina < human_melee_charge__minStaminaLevelToStart
    let shouldStopCharge = !isSprinting || currentState.stamina <= 0.

    human_melee_charge__canStart = isSprinting && !isStartBlocked && !human_melee_charge__isActive
    human_melee_charge__isActive = isChargeInputTriggered && (wasCharging || !isStartBlocked)

    if shouldStopCharge
      human_melee_charge__isActive = false

    human_melee_charge__isChargeOrAttack ||= human_melee_charge__isActive
    let shouldPlayMeleeAction = !human_melee_charge__isActive && isMeleeInputTriggered && !isChargeInputTriggered
    if wasCharging && !human_melee_charge__isActive
      human_melee_charge__chargeEndTime = evt.atTime
    if shouldPlayChargeAction || shouldPlayMeleeAction
      run_human_melee_action(ownerEid, human_net_phys, melee_weapon__attackTime,
                             melee_weapon__propsId, melee_weapon__attackAt,
                             melee_weapon__attackPeriod, wasCharging ? human_melee_charge__animProgress : 0.0,
                             entity_mods__meleeSpeedMult)
      if shouldPlayChargeAction
        human_melee_charge__isChargeOrAttack = true
















































def melee_charge_speed(human_melee_charge__isActive : bool;
                       human_melee_charge__isChargeOrAttack : bool;
                       human_melee_charge__chargeSpeedMult : float;
                       human_melee_charge__chargeStrikeSpeedMult : float;
                       var human_net_phys : HumanActor&)
  if human_melee_charge__isChargeOrAttack
    human_net_phys.phys.currentState.moveSpeedMult *= human_melee_charge__isActive ? human_melee_charge__chargeSpeedMult : human_melee_charge__chargeStrikeSpeedMult


def melee_charge_stamina_drain(human_melee_charge__isActive : bool;
                               human_melee_charge__staminaDrainMult : float;
                               human_melee_charge__staminaRegenMult : float;
                               var human_stamina_regen_affect__mult : float&;
                               var human_net_phys : HumanActor&)
  if human_melee_charge__isActive
    human_stamina_regen_affect__mult *= human_melee_charge__staminaRegenMult
    human_net_phys.phys.currentState.staminaSprintDrainMult *= human_melee_charge__staminaDrainMult


[es(tag=netClient, REQUIRE=(meleeChargeWeapon, watchedPlayerItem), after=entity_mods_appliers_server_es )]
def melee_charge_human_phys_update_local(info : ParallelUpdateFrameDelayed; eid aka weapon_eid : EntityId; gun__owner : EntityId)
  query(gun__owner) <| $ [es] (human_weap__currentGunEid : EntityId;
                               human_melee_charge__isActive : bool;
                               human_melee_charge__isChargeOrAttack : bool;
                               human_melee_charge__chargeSpeedMult : float;
                               human_melee_charge__chargeStrikeSpeedMult : float;
                               human_melee_charge__staminaDrainMult : float;
                               human_melee_charge__staminaRegenMult : float;
                               var human_net_phys : HumanActor&;
                               var human_stamina_regen_affect__mult : float&)
    if human_weap__currentGunEid == weapon_eid
      melee_charge_stamina_drain(human_melee_charge__isActive, human_melee_charge__staminaDrainMult, human_melee_charge__staminaRegenMult, human_stamina_regen_affect__mult, human_net_phys)
      melee_charge_speed(human_melee_charge__isActive, human_melee_charge__isChargeOrAttack, human_melee_charge__chargeSpeedMult, human_melee_charge__chargeStrikeSpeedMult, human_net_phys)


[es(tag=server, REQUIRE=meleeChargeWeapon, after=entity_mods_appliers_server_es )]
def melee_charge_human_phys_update_server(info : ParallelUpdateFrameDelayed; eid aka weapon_eid : EntityId; gun__owner : EntityId)
  query(gun__owner) <| $ [es] (human_weap__currentGunEid : EntityId;
                               human_melee_charge__isActive : bool;
                               human_melee_charge__isChargeOrAttack : bool;
                               human_melee_charge__chargeSpeedMult : float;
                               human_melee_charge__chargeStrikeSpeedMult : float;
                               human_melee_charge__staminaDrainMult : float;
                               human_melee_charge__staminaRegenMult : float;
                               var human_net_phys : HumanActor&;
                               var human_stamina_regen_affect__mult : float&)
    if human_weap__currentGunEid == weapon_eid
      melee_charge_stamina_drain(human_melee_charge__isActive, human_melee_charge__staminaDrainMult, human_melee_charge__staminaRegenMult, human_stamina_regen_affect__mult, human_net_phys)
      melee_charge_speed(human_melee_charge__isActive, human_melee_charge__isChargeOrAttack, human_melee_charge__chargeSpeedMult, human_melee_charge__chargeStrikeSpeedMult, human_net_phys)


def melee_charge_cooldown(time : float;
                          human_melee_charge__chargeEndTime : float;
                          human_melee_charge__cooldown : float;
                          var human_net_phys : HumanActor&;
                          var human_melee_charge__isOnCooldown : bool&)
  human_melee_charge__isOnCooldown = time < human_melee_charge__chargeEndTime + human_melee_charge__cooldown
  if human_melee_charge__isOnCooldown
    human_net_phys.phys.currentState.restoreStaminaMult = 0.0


[es(tag=netClient, REQUIRE=hero, after=entity_mods_appliers_server_es )]
def melee_charge_cooldown_local(info : ParallelUpdateFrameDelayed;
                                human_melee_charge__chargeEndTime : float;
                                human_melee_charge__cooldown : float;
                                var human_net_phys : HumanActor&;
                                var human_melee_charge__isOnCooldown : bool&)
  melee_charge_cooldown(info.curTime, human_melee_charge__chargeEndTime, human_melee_charge__cooldown, human_net_phys, human_melee_charge__isOnCooldown)


[es(tag=server, after=entity_mods_appliers_server_es )]
def melee_charge_cooldown_server(info : ParallelUpdateFrameDelayed;
                                 human_melee_charge__chargeEndTime : float;
                                 human_melee_charge__cooldown : float;
                                 var human_net_phys : HumanActor&;
                                 var human_melee_charge__isOnCooldown : bool&)
  melee_charge_cooldown(info.curTime, human_melee_charge__chargeEndTime, human_melee_charge__cooldown, human_net_phys, human_melee_charge__isOnCooldown)


def melee_charge_reset(var human_melee_charge__isActive : bool&;
                       var human_melee_charge__isChargeOrAttack : bool&;
                       var human_melee_charge__canStart : bool&;
                       var human_melee_charge__chargeEndTime : float&)
  if human_melee_charge__isActive
    human_melee_charge__chargeEndTime = get_sync_time()
  human_melee_charge__isActive = false
  human_melee_charge__isChargeOrAttack = false
  human_melee_charge__canStart = false


[es(tag=server, track=human_weap__currentGunEid, REQUIRE=human_weap__currentGunEid)]
def reset_melee_charge_server(evt : Event;
                              var human_melee_charge__isActive : bool&;
                              var human_melee_charge__isChargeOrAttack : bool&;
                              var human_melee_charge__canStart : bool&;
                              var human_melee_charge__chargeEndTime : float&)
  melee_charge_reset(human_melee_charge__isActive, human_melee_charge__isChargeOrAttack, human_melee_charge__canStart, human_melee_charge__chargeEndTime)


[es(tag=netClient, track=human_weap__currentGunEid, REQUIRE=(hero, human_weap__currentGunEid))]
def reset_melee_charge_client(evt : Event;
                              var human_melee_charge__isActive : bool&;
                              var human_melee_charge__isChargeOrAttack : bool&;
                              var human_melee_charge__canStart : bool&;
                              var human_melee_charge__chargeEndTime : float&)
  melee_charge_reset(human_melee_charge__isActive, human_melee_charge__isChargeOrAttack, human_melee_charge__canStart, human_melee_charge__chargeEndTime)


[es(REQUIRE_NOT=human_weap)]
def human_melee_post_phys_es(evt : CmdPostPhysUpdate;
                             eid : EntityId;
                             human_net_phys : HumanActor&)
  let isForReal = evt.isForReal
  let isMeleeControlBit = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_MELEE)

  if isForReal && isMeleeControlBit
    run_human_melee_action(eid, human_net_phys,
                            -1.0,  PropsId(),
                            -1.0,  -1.0)











[es]
def melee_unarmed_phys_es(evt : CmdPostPhysUpdate;
                          eid : EntityId;
                          human_net_phys : HumanActor&;
                          human_unarmed__attackTime : float;
                          human_unarmed__attackPeriod : float;
                          human_unarmed__propsId : PropsId;
                          human_unarmed__active : bool = false)
  if !human_unarmed__active
    return

  assume phys = human_net_phys.phys

  let isForReal = evt.isForReal
  let isMeleeControlBit = phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_MELEE)
  let isShootControlBit = phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT)

  if isForReal && (isMeleeControlBit || isShootControlBit)
    run_human_melee_action(eid, human_net_phys,
                           human_unarmed__attackTime, human_unarmed__propsId,
                            -1.0, human_unarmed__attackPeriod)


[es(on_appear)]
def human_unarmed_reg_es(evt : Event;
                         human_unarmed__selWeaponVar : string;
                         var human_unarmed__selWeaponVarId : int&)
  human_unarmed__selWeaponVarId = animV20_add_enum_value(human_unarmed__selWeaponVar)


[es(after=human_anim_weap_es)]
def human_unarmed_melee_anim_es(evt : ParallelUpdateFrameDelayed;
                                human_anim__changeWeaponVarId : int;
                                human_anim__selectedWeaponVarId : int;
                                human_unarmed__active : bool;
                                human_unarmed__selWeaponVarId : int = -1;
                                var phys_vars : PhysVars&)
  if human_unarmed__active && human_unarmed__selWeaponVarId >= 0 && human_anim__selectedWeaponVarId >= 0
    phys_vars |> setVar(human_anim__changeWeaponVarId, 1.0)
    let selWeaponVarId = float(human_unarmed__selWeaponVarId)
    phys_vars |> setVar(human_anim__selectedWeaponVarId, selWeaponVarId)


[es(after=human_anim_weap_es, track=human_unarmed__active)]
def human_unarmed_melee_lock_weapon(evt : Event;
                                    eid : EntityId;
                                    human_unarmed__active : bool;
                                    human_weap__gunEids : EidList&;
                                    var human_net_phys : HumanActor&)
  human_net_phys.phys.canSwitchWeapon = !human_unarmed__active

  if human_unarmed__active
    forcibly_lock_weap_slot(eid, -1, human_weap__gunEids, human_net_phys)


[es(REQUIRE=hero, after=human_optics_camera_es, before=before_camera_sync)]
def melee_charge_fov(info : ParallelUpdateFrameDelayed;
                     human_melee_charge__isActive : bool;
                     human_melee_charge__zoomMult : float;
                     human_melee_charge__zoomSpeed : float;
                     var human_melee_charge__zoom : float&;
                     var camera__magnification : float&)
  let targetZoom = human_melee_charge__isActive ? human_melee_charge__zoomMult : 1.
  human_melee_charge__zoom = move_to(human_melee_charge__zoom, targetZoom, info.dt, human_melee_charge__zoomSpeed)
  camera__magnification *= human_melee_charge__zoom


[es(tag=server, track=human_melee_charge__isActive)]
def melee_charge_stopping_power(evt : Event;
                                human_melee_charge__isActive : bool;
                                human_melee_charge__lessStoppingPower : float;
                                var human_melee_charge__currentLessStoppingPower : float&)
  human_melee_charge__currentLessStoppingPower = human_melee_charge__isActive ? human_melee_charge__lessStoppingPower : 0.


[es(tag=render, before=anim_phys_init_es, on_appear)]
def melee_charge_init_anim(evt : Event;
                           animchar : AnimcharBaseComponent;
                           human_melee_charge__animUpperState : string;
                           human_melee_charge__animProgressVar : string;
                           var phys_vars : PhysVars;
                           var human_melee_charge__animUpperStateId : int&;
                           var human_melee_charge__animProgressVarId : int&)
  if animchar.animGraph != null
    human_melee_charge__animUpperStateId = *animchar.animGraph |> anim_graph_getStateIdx(human_melee_charge__animUpperState)
    human_melee_charge__animProgressVarId = phys_vars |> registerVar(human_melee_charge__animProgressVar, 0.)


[es(tag=render, on_appear, track=human_weap__currentGunEid)]
def malee_charge_set_weap_anim_params(evt : Event;
                                      human_weap__currentGunEid : EntityId;
                                      human_melee_charge__animProgressBase : float;
                                      var human_melee_charge__animProgress : float&)
  human_melee_charge__animProgress = human_melee_charge__animProgressBase
  query(human_weap__currentGunEid) <| $ [es] (melee_charge_weapon__animProgress : float)
    human_melee_charge__animProgress = melee_charge_weapon__animProgress
