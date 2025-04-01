require ecs
require ecs.common
require app
require net
require math
require math.base


require %appGame.es.human_gun_common



require DagorSystem
require %game.events
require DagorMath
require DagorDataBlock



require DaWeapons
require DngWeapon
require AnimV20
require HumanPhys
require PhysDecl
require PhysVars
require AnimatedPhys
require DaWeapons
require DngHuman
require DagorMath
require math.base
require ecs.safe
require strings
require PhysMat
require PropsManager

[es(on_appear)]
def gun_attach__mainSlotId_init(evt : Event;
                                gun_attach__slot : string;
                                var gun_attach__mainSlotId : int&)
  gun_attach__mainSlotId = animchar_getSlotId(gun_attach__slot)


[es(on_appear)]
def gun_attach__altSlotId_init(evt : Event;
                               gun_attach__alternativeSlot : string;
                               var gun_attach__altSlotId : int&)
  gun_attach__altSlotId = animchar_getSlotId(gun_attach__alternativeSlot)


[es(on_appear, before=server_init_gun_es)]
def gun_attach__holsterSlotsIds_init(evt : Event;
                                     gun_attach__holsterSlots : Array const?;
                                     var gun_attach__holsterSlotsIds : IntList)
  gun_attach__holsterSlotsIds |> resize(int(HUWeaponSlots EWS_NUM))
  var i = 0

  if gun_attach__holsterSlots != null
    let holsterSlotsCount = length(*gun_attach__holsterSlots)
    verify(holsterSlotsCount <= int(HUWeaponSlots EWS_NUM))

    while i < holsterSlotsCount
      let slotName = get_ecs_string((*gun_attach__holsterSlots)[i])
      gun_attach__holsterSlotsIds[i] = (slotName != null
                                          ? animchar_getSlotId(*slotName |> string())
                                          : -1)
      ++i

  while i < int(HUWeaponSlots EWS_NUM)
    gun_attach__holsterSlotsIds[i] = -1
    ++i


[es(REQUIRE=(animchar_render__enabled, gun__propsId),
    REQUIRE_NOT=skip_common_weap_phys_update)]
def human_gun_es(evt : CmdWeapPhysUpdate;
                 eid : EntityId;
                 gun__ammo : int;
                 gun__autoReload : bool;
                 gun__manuallyUnloaded : bool;
                 human_gun_attached : bool;
                 gun__isOverheat : bool = false;
                 gun__isReady : bool = true;
                 gun : Gun)
  if !human_gun_attached
    return

  let ownerEid = evt.owner
  let atTime = evt.atTime
  let dt = evt.dt
  let isForReal = evt.isForReal
  let gctrl = evt.gctrl
  let gloc = evt.gloc
  let shoot = gctrl.shoot && !gun__isOverheat && gun__isReady

  
  try_reload_empty_gun(gun, eid, gun__autoReload, gun__manuallyUnloaded, gctrl.shoot, isForReal, gun__ammo, ownerEid, (atTime - dt))

  let rndSeed = 0 
  using() <| $(var gctr : GunControls#)
    gctr.shoot = shoot
    gctr.timeStep = evt.gctrl.timeStep
    sendEventImmediate(eid, [[CmdGunUpdate atTime=atTime, isForReal=isForReal, seed=rndSeed, gctrl := gctr, gloc=gloc]])

[es(on_appear, REQUIRE=specialItem__attachToHolster, track=gun__owner)]
def special_item_attach_to_holster(evt : Event; eid : EntityId; gun__owner : EntityId)
  query(gun__owner) <| $ [es] (human_weap__currentGunEid : EntityId)
    sendEvent(eid, [[CmdWeapAttach slotId = int(HUWeaponSlots EWS_SPECIAL), toEid=gun__owner, isAttached=(human_weap__currentGunEid == eid)]])

[es(tag=render, REQUIRE=human, on_appear, track=(human_weap__gunEids, isInVehicle, itemContainer), after=human_gun_attach_es)]
def hide_guns_in_vehicle_es(evt : Event; isInVehicle : bool; human_weap__gunEids : EidList; itemContainer : EidList)
  for gunEid in human_weap__gunEids
    query(gunEid) <| $ [es(REQUIRE=gun__hideInVehcile)] (var gun__visible : bool&)
      gun__visible = !isInVehicle

  for itemEid in itemContainer 
    query(itemEid) <| $ [es(REQUIRE=gun__hideInVehcile)] (var gun__visible : bool&)
      gun__visible = !isInVehicle

[es(no_order, REQUIRE=animchar_render__enabled)]
def human_gun_attach_es(evt : CmdWeapAttach;
                        gun_attach__mainSlotId : int;
                        gun_attach__holsterSlotsIds : IntList const?;
                        var slot_attach__rotOffset : float3?;
                        var human_gun_attached : bool&;
                        var slot_attach__slotId : int&;
                        var slot_attach__attachedTo : EntityId&;
                        var gun__visible : bool&;
                        gun__hideInVehcile : Tag const?;
                        gun_attach__holsterRotOffset : float3 = float3())
  let ownerEid = evt.toEid
  if !ownerEid || !doesEntityExist(ownerEid)
    return
  let attachFlag = evt.isAttached
  let slotId = evt.slotId
  let weaponHolster = (gun_attach__holsterSlotsIds != null
                      ? ((*gun_attach__holsterSlotsIds)[slotId] >= 0)
                      : false)
  var holsetOffset = float3()

  gun__visible = (attachFlag || weaponHolster)
  if gun__hideInVehcile != null
    query(ownerEid) <| $ [es] (isInVehicle : bool)
      gun__visible &&= !isInVehicle

  if attachFlag
    slot_attach__attachedTo = ownerEid
    slot_attach__slotId = gun_attach__mainSlotId
  elif weaponHolster
    slot_attach__attachedTo = ownerEid
    slot_attach__slotId = (*gun_attach__holsterSlotsIds)[slotId]
    holsetOffset = gun_attach__holsterRotOffset
  else
    slot_attach__attachedTo = INVALID_ENTITY_ID
    slot_attach__slotId = -1

  human_gun_attached = attachFlag
  if slot_attach__rotOffset != null
    *slot_attach__rotOffset = holsetOffset
















[es(tag=server, track=(human_weap__currentGunSlot, human_weap__gunEids))]
def human_gun_deflect_es(evt : Event;
                         human_weap__currentGunSlot : int;
                         human_weap__gunEids : EidList;
                         var human_weap__bulletDeflectionAngle : float&;
                         var human_weap__bulletDeflectionArmor : float&)
  let gun = human_weap__currentGunSlot >= 0 ? human_weap__gunEids[human_weap__currentGunSlot] : INVALID_ENTITY_ID
  query(gun) <| $ [es] (bulletDeflectAngle : float = 0.0;
                        bulletDeflectArmor : float = 0.0)
    human_weap__bulletDeflectionAngle = bulletDeflectAngle
    human_weap__bulletDeflectionArmor = bulletDeflectArmor


def reset_reload_anim(gun_anim__reloadVarId : int;
                      gun_anim__singleReloadVarId : int;
                      var physVars : PhysVars;
                      var animchar : AnimcharBaseComponent;
                      var animPhys : AnimatedPhys)
  physVars |> setVar(gun_anim__reloadVarId, -1.0)
  physVars |> setVar(gun_anim__singleReloadVarId, -1.0)
  animPhys |> anim_phys_update(animchar, physVars)
  animchar |> animchar_act(0.01, true)


[es(tag=gameClient, track=human_gun_attached)]
def human_gun_reset_reload_anim_client_es(evt : Event;
                                          gun_anim__reloadVarId : int;
                                          gun_anim__singleReloadVarId : int;
                                          human_gun_attached : bool;
                                          var phys_vars : PhysVars;
                                          var animchar : AnimcharBaseComponent;
                                          var anim_phys : AnimatedPhys)
  if !human_gun_attached
    reset_reload_anim(gun_anim__reloadVarId, gun_anim__singleReloadVarId, phys_vars, animchar, anim_phys)












def approach_var(var phys_vars : PhysVars&;
                 var_id : int;
                 target_value : float;
                 dt : float;
                 viscosity : float)
  let new_value = approach(getVar(phys_vars, var_id), target_value, dt, viscosity)
  phys_vars |> setVar(var_id, new_value)

[es(tag=gameClient, before=before_animchar_update_sync)]
def human_grenade_thrower_phys_vars_es(info : ParallelUpdateFrameDelayed;
                                       human_weap__gunEids : EidList;
                                       human_weap__currentGunSlot : int;
                                       gun_offset__acrossId : int;
                                       gun_offset__alongId : int;
                                       gun_offset__upId : int;
                                       gun_offset__tau : float = 0.1f;
                                       human_net_phys : HumanActor;
                                       var phys_vars : PhysVars&)
  let gun = human_weap__currentGunSlot >= 0 ? human_weap__gunEids[human_weap__currentGunSlot] : INVALID_ENTITY_ID
  query(gun) <| $ [es(REQUIRE=grenade_thrower)] (grenade_thrower_tilt__leanMult : float;
                                                 grenade_thrower_tilt__offsetMult : float;
                                                 var gun_tilt__fpsAngle : float&)
    let lean = human_net_phys.phys.appliedCT.leanPosition
    gun_tilt__fpsAngle = lean * grenade_thrower_tilt__leanMult
    phys_vars |> approach_var(gun_offset__acrossId, lean * grenade_thrower_tilt__offsetMult, info.dt, gun_offset__tau)
    phys_vars |> approach_var(gun_offset__alongId, 0.0, info.dt, gun_offset__tau)
    phys_vars |> approach_var(gun_offset__upId, 0.0, info.dt, gun_offset__tau)

[es(tag=gameClient, before=before_animchar_update_sync)]
def human_gun_phys_vars_es(info : ParallelUpdateFrameDelayed;
                           reye_offset__fwd0Id : int;
                           gun_offset__acrossId : int;
                           gun_offset__upId : int;
                           gun_offset__alongId : int;
                           gun_offset__tau : float = 0.3f;
                           human_weap__currentGunSlot : int;
                           human_weap__gunEids : EidList;
                           animchar__visible : bool;
                           human_net_phys : HumanActor;
                           human_net_phys__isCrouch : bool;
                           human_net_phys__isCrawl : bool;
                           human_net_phys__curMoveState : int;
                           bipod__enabled : bool = false;
                           isTpsView : bool = false;
                           human_anim__isFpv : bool = false;
                           var phys_vars : PhysVars&)
  if !animchar__visible
    return

  let gun = human_weap__currentGunSlot >= 0 ? human_weap__gunEids[human_weap__currentGunSlot] : INVALID_ENTITY_ID
  query(gun) <| $ [es(REQUIRE_NOT=grenade_thrower)] (gun_anim_var__defReyeOffsetFwd0 : float;
                                                     gun_anim_var__defGunOffsetAlong : float;
                                                     gun_anim_var__defGunOffsetAcross : float;
                                                     gun_anim_var__defGunOffsetUp : float;
                                                     gun_anim_var__tpsReyeOffsetFwd0 : float = 0.;
                                                     gun_anim_var__tpsGunOffsetAlong : float = 0.0;
                                                     gun_anim_var__tpsGunOffsetAcross : float = 0.0;
                                                     gun_anim_var__tpsGunOffsetUp : float = 0.0;
                                                     gun_anim_var__fpsReyeOffsetFwd0 : float const?;
                                                     gun_anim_var__fpsGunOffsetAlong : float const?;
                                                     gun_anim_var__fpsGunOffsetAcross : float const?;
                                                     gun_anim_var__fpsGunOffsetOptionalAcross : float const?;
                                                     gun_anim_var__fpsGunOffsetUp : float const?;
                                                     gun_anim_var__fpsGunOffsetOptionalUp : float const?;
                                                     gunAnimOffsetAlwaysInAim : Tag const?;
                                                     gun_dynamic_position__offset : float3 = float3();
                                                     subsidiaryGunEid : EntityId const?;
                                                     gun_anim__reloadProgress : float;
                                                     gun_tilt__reloadProgressLimit : float = 1.0f)
    assume isAim = is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType HCT_AIM)
    assume isCrouch = human_net_phys__isCrouch
    assume isCrawl = human_net_phys__isCrawl
    assume isInSprint = human_net_phys__curMoveState == int(HUMoveState EMS_SPRINT)
    let isTpsViewOnSoldier = !human_anim__isFpv || isTpsView
    if !isAim && !(isCrouch || isCrawl) && isTpsViewOnSoldier && !bipod__enabled && gunAnimOffsetAlwaysInAim == null
      phys_vars |> approach_var(reye_offset__fwd0Id, gun_anim_var__tpsReyeOffsetFwd0, info.dt, gun_offset__tau)
      phys_vars |> approach_var(gun_offset__alongId, gun_anim_var__tpsGunOffsetAlong, info.dt, gun_offset__tau)
      phys_vars |> approach_var(gun_offset__acrossId, gun_anim_var__tpsGunOffsetAcross, info.dt, gun_offset__tau)
      phys_vars |> approach_var(gun_offset__upId, gun_anim_var__tpsGunOffsetUp, info.dt, gun_offset__tau)
      return

    if !isTpsViewOnSoldier
      var offsetUp = gun_anim_var__fpsGunOffsetUp ?? gun_anim_var__defGunOffsetUp
      var offsetAcross = gun_anim_var__fpsGunOffsetAcross ?? gun_anim_var__defGunOffsetAcross
      let useNeoclassicalTilt = find_query() <| $ [es] (neoclassical_tilt__enable : bool)
        return neoclassical_tilt__enable
      let isReloading = gun_anim__reloadProgress > 0.
      let isEndOfReloading = gun_anim__reloadProgress > gun_tilt__reloadProgressLimit
      let isWearingWeaponMod = subsidiaryGunEid != null
      let isWearingOffWeaponMod = isWearingWeaponMod && isReloading

      let applyNeoClassicTilt = ((!isReloading || isEndOfReloading) && !isAim && !isCrawl && !bipod__enabled && !isWearingWeaponMod && !isInSprint) || isWearingOffWeaponMod
      if applyNeoClassicTilt && useNeoclassicalTilt
        if gun_anim_var__fpsGunOffsetOptionalAcross != null
          offsetAcross += *gun_anim_var__fpsGunOffsetOptionalAcross
        if gun_anim_var__fpsGunOffsetOptionalUp != null
          offsetUp += *gun_anim_var__fpsGunOffsetOptionalUp

      let offset = float3(gun_anim_var__fpsGunOffsetAlong ?? gun_anim_var__defGunOffsetAlong, offsetUp, offsetAcross) + gun_dynamic_position__offset
      phys_vars |> approach_var(reye_offset__fwd0Id, gun_anim_var__fpsReyeOffsetFwd0 ?? gun_anim_var__defReyeOffsetFwd0, info.dt, gun_offset__tau)
      phys_vars |> approach_var(gun_offset__alongId, offset.x, info.dt, gun_offset__tau)
      phys_vars |> approach_var(gun_offset__acrossId, offset.z, info.dt, gun_offset__tau)
      phys_vars |> approach_var(gun_offset__upId, offset.y, info.dt, gun_offset__tau)
      return

    phys_vars |> approach_var(reye_offset__fwd0Id, gun_anim_var__defReyeOffsetFwd0, info.dt, gun_offset__tau)
    phys_vars |> approach_var(gun_offset__acrossId, gun_anim_var__defGunOffsetAcross, info.dt, gun_offset__tau)
    phys_vars |> approach_var(gun_offset__alongId, gun_anim_var__defGunOffsetAlong, info.dt, gun_offset__tau)
    phys_vars |> approach_var(gun_offset__upId, gun_anim_var__defGunOffsetUp, info.dt, gun_offset__tau)



[es(tag=(gameClient, net), track=gun__firingModeIndex)]
def human_gun_update_firing_mode_client_es(evt : Event;
                                           var gun : Gun;
                                           gun__firingModeIndex : int)
  gun |> gun_setFiringModeIndex(uint8(gun__firingModeIndex))


[es(tag=gameClient, on_appear, track=(gun__firingModeNames, gun__firingModeIndex))]
def human_gun_update_firing_mode_name_es(evt : Event;
                                         gun__firingModeNames : Array;
                                         gun__firingModeIndex : int;
                                         var gun__firingModeName : das_string)
  if gun__firingModeIndex >= 0
    gun__firingModeName := get_string(gun__firingModeNames[gun__firingModeIndex], "")
  else
    gun__firingModeName := ""


[es(tag=server, on_appear)]
def human_gun_init_offsets_es(evt : Event;
                              gun__propsId : PropsId;
                              var gun_anim_var__defReyeOffsetFwd0 : float&;
                              var gun_anim_var__defGunOffsetAlong : float&;
                              var gun_anim_var__defGunOffsetAcross : float&;
                              var gun_anim_var__defGunOffsetUp : float&;
                              var gun__animOffset : float3&)
  get_props_GunToAnimProps(gun__propsId) <| $(p : GunToAnimProps)
    assume ownerAnimVars = p.ownerAnimVars

    gun__animOffset.x =  ownerAnimVars |> datablock_getReal("gun_offset_along", 0.0)
    gun__animOffset.y =  ownerAnimVars |> datablock_getReal("gun_offset_up", 0.0)
    gun__animOffset.z = -ownerAnimVars |> datablock_getReal("gun_offset_across", 0.0)

    gun_anim_var__defReyeOffsetFwd0 = datablock_getReal(p.ownerAnimVars, "reye_offset_fwd0", 0f)
    gun_anim_var__defGunOffsetAcross = datablock_getReal(p.ownerAnimVars, "gun_offset_across", 0f)
    gun_anim_var__defGunOffsetUp = datablock_getReal(p.ownerAnimVars, "gun_offset_up", 0f)
    gun_anim_var__defGunOffsetAlong = datablock_getReal(p.ownerAnimVars, "gun_offset_along", 0f)

[es(REQUIRE=human, on_appear, before=human_gun_phys_vars_es)]
def human_gun_offset_var_init(evt : Event;
                              var phys_vars : PhysVars&;
                              var reye_offset__fwd0Id : int&;
                              var gun_offset__acrossId : int&;
                              var gun_offset__upId : int&;
                              var gun_offset__alongId : int&)
  reye_offset__fwd0Id   = phys_vars |> registerVar("reye_offset_fwd0", 0.)
  gun_offset__acrossId  = phys_vars |> registerVar("gun_offset_across", 0.)
  gun_offset__upId      = phys_vars |> registerVar("gun_offset_up", 0.)
  gun_offset__alongId   = phys_vars |> registerVar("gun_offset_along", 0.)


[es(tag=gameClient, on_appear)]
def human_gun_offset_global_var_init(evt : Event;
                                     var phys_vars : PhysVars&;
                                     var gun_offset_global__awayId : int&;
                                     var gun_offset_global__upId : int&;
                                     var gun_offset_global__acrossId : int&)
  gun_offset_global__awayId = phys_vars |> registerVar("gun_offset_global_along", 0.)
  gun_offset_global__upId = phys_vars |> registerVar("gun_offset_global_up", 0.)
  gun_offset_global__acrossId = phys_vars |> registerVar("gun_offset_global_across", 0.)


[es(tag=gameClient, before=before_animchar_update_sync)]
def human_gun_offset_global_set_es(info : ParallelUpdateFrameDelayed;
                                   gun_offset_global__awayId : int;
                                   gun_offset_global__upId : int;
                                   gun_offset_global__acrossId : int;
                                   gun_offset__fromSoldier : float3;
                                   var phys_vars : PhysVars&)
  phys_vars |> setVar(gun_offset_global__awayId, gun_offset__fromSoldier.x)
  phys_vars |> setVar(gun_offset_global__upId, gun_offset__fromSoldier.y)
  phys_vars |> setVar(gun_offset_global__acrossId, gun_offset__fromSoldier.z)


[es(tag=gameClient, track=slot_attach__rotOffset, on_appear)]
def set_slot_attach__rotation_tm(evt : Event; slot_attach__rotOffset : float3; var slot_attach__rotTm : float3x4&)
  var q : quat
  let offset = deg_to_rad(slot_attach__rotOffset)
  euler_to_quat(offset.x, offset.y, offset.z, q)
  make_tm(q, float3(), slot_attach__rotTm)

[es(tag=gameClient, track=slot_attach__posOffset, on_appear, after=set_slot_attach__rotation_tm)]
def set_slot_attach__position_tm(evt : Event; slot_attach__posOffset : float3; var slot_attach__rotTm : float3x4&)
  slot_attach__rotTm[3] = slot_attach__posOffset

[es(on_appear)]
def human_weap_init_gun_trace(evt : Event;
                              human_weap__gunMat : string = "gunRay";
                              var human_weap__gunMatId : int&)
  human_weap__gunMatId = get_material_id(human_weap__gunMat)


















[es(tag=gameClient)]
def gun_anim_holster_pos_offset_es(info : ParallelUpdateFrameDelayed;
                                   gun__owner : EntityId;
                                   gun_attach__holsterPosOffset : float3;
                                   slot_attach__posOffset : float3;
                                   slot_attach__weaponSlotIdx : int;
                                   gun_attach__holsterAnimLerpFactor : float;
                                   var slot_attach__rotTm : float3x4&)
  query(gun__owner) <| $ [es(REQUIRE=human_net_phys)] (human_net_phys : HumanActor)
    assume currentState = human_net_phys.phys.currentState
    if currentState.weapEquipState.curState == HUWeaponEquipState EES_EQUIPED
      return

    let isHolster = int(currentState.weapEquipState.nextSlot) != slot_attach__weaponSlotIdx
    if isHolster && currentState.weapEquipState.curState == HUWeaponEquipState EES_EQUIPING
      slot_attach__rotTm[3] = lerp(slot_attach__rotTm[3], gun_attach__holsterPosOffset, float3(info.dt * gun_attach__holsterAnimLerpFactor))
    elif !isHolster && currentState.weapEquipState.curState == HUWeaponEquipState EES_HOLSTERING
      slot_attach__rotTm[3] = lerp(slot_attach__rotTm[3], slot_attach__posOffset, float3(info.dt * gun_attach__holsterAnimLerpFactor))

[es(tag=gameClient, REQUIRE=menuChar)]
def gun_anim_holster_menu_pos_offset_es(info : ParallelUpdateFrameDelayed;
                                        human_weap__gunEids : EidList)
  for gunEid in human_weap__gunEids
    query(gunEid) <| $ [es] (human_gun_attached : bool;
                             gun_attach__holsterPosOffset : float3;
                             slot_attach__posOffset : float3;
                             gun_attach__holsterAnimLerpFactor : float;
                             var slot_attach__rotTm : float3x4&)
      if !human_gun_attached
        slot_attach__rotTm[3] = lerp(slot_attach__rotTm[3], gun_attach__holsterPosOffset, float3(info.dt * gun_attach__holsterAnimLerpFactor))
      else
        slot_attach__rotTm[3] = lerp(slot_attach__rotTm[3], slot_attach__posOffset, float3(info.dt * gun_attach__holsterAnimLerpFactor))

[es(tag=gameClient, on_appear, REQUIRE=menuChar)]
def gun_anim_holster_menu_pos_offset_init_on_soldier_creation_es(evt : Event; human_weap__gunEids : EidList)
  for gunEid in human_weap__gunEids
    query(gunEid) <| $ [es] (human_gun_attached : bool;
                             gun_attach__holsterPosOffset : float3;
                             slot_attach__posOffset : float3;
                             var slot_attach__rotTm : float3x4&)
      if !human_gun_attached
        slot_attach__rotTm[3] = gun_attach__holsterPosOffset
      else
        slot_attach__rotTm[3] = slot_attach__posOffset

[es(tag=gameClient, REQUIRE=menu_gun, after=human_gun_attach_es)]
def gun_anim_holster_menu_pos_offset_init_on_gun_attach_es(evt : CmdWeapAttach;
                                                           human_gun_attached : bool;
                                                           gun_attach__holsterPosOffset : float3;
                                                           slot_attach__posOffset : float3;
                                                           var slot_attach__rotTm : float3x4&)
  if !human_gun_attached
    slot_attach__rotTm[3] = gun_attach__holsterPosOffset
  else
    slot_attach__rotTm[3] = slot_attach__posOffset
