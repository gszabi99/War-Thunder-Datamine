module human_weap_common shared
require app
require ecs
require net
require ecs.common
require ecs.safe
require %game.events







require inventory
require HumanPhys
require DaWeaponProps
require DaWeapons
require DngWeapon
require DagorSystem

require DngHuman

require %game.events

require AnimV20
require DagorMath
require DagorMathUtils
require WeapHelpers
require PropsManager

require %appGame.es.human_gun_common
require %appGame.es.human_reload_common
require %appGame.es.human_weapon_utils_common

require Dacoll
require daslib.strings_boost

require AnimatedPhys
require math.base
require %appGame.es.multiple_guns_slot_common






require ecs.common
require ecs.safe











require DagorSystem





require DagorMath
require DagorMathUtils














def anim_attach(var slot_attach__slotId : int&;
                eid : EntityId;
                slot_id : int;
                attach_eid : EntityId)
  query(attach_eid) <| $ [es] (var slot_attach__attachedTo : EntityId&)
    slot_attach__attachedTo = eid
  slot_attach__slotId = slot_id


def anim_detach(var slot_attach__slotId : int&;
                attach_eid : EntityId)
  query(attach_eid) <| $ [es] (var slot_attach__attachedTo : EntityId&)
    slot_attach__attachedTo = INVALID_ENTITY_ID
  slot_attach__slotId = -1;

let PHYS_MAX_CONTROLS_TICKS_DELTA_SEC = (0.375f)
def find_rethrowable_grenade(to_whom : EntityId)
  var res = INVALID_ENTITY_ID
  query(to_whom) <| $ [es] (transform aka human_transform : float3x4; human_use_object__rethrowDist : float = 2.5f)
    let humanPos = human_transform[3]
    let humanDir = human_transform[0].xz
    query() <| $ [es(REQUIRE_NOT=shell__blockRethrow)] (eid : EntityId;
                                                        active : bool;
                                                        transform : float3x4;
                                                        slot_attach__attachedTo : EntityId;
                                                        shell__explTime : float;
                                                        
                                                        shell__rethrowTime : float = 4.0f)
      if slot_attach__attachedTo != INVALID_ENTITY_ID || !active
        return

      var adjustedRethrowTime = shell__rethrowTime
      
      
      
      if is_dedicated()
        adjustedRethrowTime += PHYS_MAX_CONTROLS_TICKS_DELTA_SEC

      let timer = 0.0f
      
      
      

      let restTime = timer - min(adjustedRethrowTime, timer)
      if get_sync_time() > shell__explTime - restTime
        return

      let shellPos = transform[3]
      if length_sq(humanPos - shellPos) > square(human_use_object__rethrowDist)
        return

      if dot(humanDir, shellPos.xz - humanPos.xz) > 0.0
        res = eid
  return res



def get_weapon_slot_from_name(name : string) : tuple<slot : HUWeaponSlots; found : bool>
  let slotIdx = get_weapon_slot_index_from_name(name)
  for slot in each_enum(HUWeaponSlots EWS_PRIMARY)
    if int(slot) == slotIdx
      return [[auto slot, true]]

  return [[auto HUWeaponSlots EWS_PRIMARY, false]]


def unload_gun_ammo(gun_eid, owner : EntityId) : void
  if !is_server()
    return

  query(gun_eid) <| $ [es(REQUIRE=gun, REQUIRE_NOT=gun__disableAmmoUnload)] (gun__ammoHolderEid : EntityId;
                                                                             gun__ammo : int)
    if gun__ammoHolderEid != INVALID_ENTITY_ID
      put_ammo_to_container(gun__ammo, gun__ammoHolderEid, owner)
      set_ammo_holder(gun_eid, ecs::INVALID_ENTITY_ID)
      destroyEntity(gun__ammoHolderEid)
      sendEventImmediate(gun_eid, [[CmdUnloadAmmo unloadManually=true]])


def unload_ammo_impl(eid : EntityId; slot_id : int)
  query(eid) <| $ [es] (human_weap__gunEids : EidList)
    if slot_id >= length(human_weap__gunEids)
      return
    
    var gunEid = human_weap__gunEids[slot_id]
    query(human_weap__gunEids[slot_id]) <| $ [es] (subsidiaryGunEid : EntityId)
      gunEid = subsidiaryGunEid
    unload_gun_ammo(gunEid, eid)


def request_unload_ammo(eid : EntityId; slot_name : string)
  if eid == INVALID_ENTITY_ID
    return
  let slotId = get_weapon_slot_index_from_name(slot_name)
  if slotId < 0
    return
  request_unload_ammo(eid, int(slotId))


def request_unload_ammo(eid : EntityId;
                        slot_id : int)
  if is_server()
    unload_ammo_impl(eid, slot_id)
  else
    send_net_event(eid, [[HumanRequestUnloadAmmo slotId=slot_id]])


def get_weapon_slot_index_from_name(name : string) : int
  let slotName = HUWeaponSlots(name)
  if slotName == HUWeaponSlots EWS_NUM
    return -1
  return int(slotName)









def choose_weapon(human_eid : EntityId; slot : HUWeaponSlots; gun_eid : EntityId = INVALID_ENTITY_ID)
  query(human_eid) <| $ [es] (human_weap__gunEids : EidList;
                              multiple_guns_slots__active : BoolList;
                              var human_net_phys : HumanActor&)
    let slotInt = int(slot)
    if gun_eid != INVALID_ENTITY_ID && multiple_guns_slots__active?[slotInt] ?? false
      try_multiple_guns_slot_equip_gun_server(human_eid, gun_eid, slotInt);
      return

    if human_weap__gunEids[slotInt] == INVALID_ENTITY_ID
      return
    human_net_phys.phys.producedCT |> set_chosen_weapon(slot)

def choose_weapon(human_eid : EntityId; slot_name : string; gun_eid : EntityId = INVALID_ENTITY_ID)
  let slot = get_weapon_slot_from_name(slot_name)
  if !slot.found
    return false
  choose_weapon(human_eid, slot.slot, gun_eid)
  return true


def reset_weapon_state(var phys : HumanPhys&)
  assume weapEquipState = phys.currentState.weapEquipState
  weapEquipState.progress = 0.
  weapEquipState.curState = HUWeaponEquipState EES_HOLSTERING
  weapEquipState.nextSlot = phys.appliedCT.chosenWeapon


def check_gun_trace(var phys : HumanPhys;
                    gun_tm : float3x4;
                    len_override : float;
                    gun_mat_id : int;
                    max_backoff : float;
                    var backoff : float&;
                    min_backup_dist : float = 0.2;
                    backup_dist_factor : float = 0.5;
                    fast_check_idx : int = -1)
  assume currentState = phys.currentState
  assume weaponParams = phys.weaponParams[int(currentState.weapEquipState.curSlot)]

  let traceHandle = phys |> human_phys_getTraceHandle()
  let gunDir = currentState.gunDir

  backoff = 0.

  if (phys.precompWeaponPos == null ||
      !phys.precompWeaponPos.isLoaded ||
      !weaponParams.exists ||
      currentState.isCrawl ||
      weaponParams.gunLen < 0.05)
    return false

  let gunLen = len_override >= 0. ? len_override : weaponParams.gunLen
  let backupDist = min(min_backup_dist, gunLen * backup_dist_factor)
  let gunStartPos = gun_tm[3] - gunDir * backupDist

  let gunAimPos = gun_tm * weaponParams.offsAimNode - gunDir * backupDist
  let leftPos = gun_tm * weaponParams.offsCheckLeftNode - gunDir * backupDist
  let rightPos = gun_tm * weaponParams.offsCheckRightNode - gunDir * backupDist
  var t = gunLen + backupDist
  var pmid = -1
  var norm : float3
  var riDesc = RendInstDesc()
  var res = false
  if fast_check_idx <= 0
    res = traceray_normalized(gunStartPos, gunDir, t, pmid, norm, ETF_DEFAULT, riDesc, gun_mat_id, traceHandle)
  if !res && (fast_check_idx < 0 || fast_check_idx == 1)
    res = traceray_normalized(gunAimPos, gunDir, t, pmid, norm, ETF_DEFAULT, riDesc, gun_mat_id, traceHandle)
  if !res && (fast_check_idx < 0 || fast_check_idx == 2)
    res = traceray_normalized(leftPos, gunDir, t, pmid, norm, ETF_DEFAULT, riDesc, gun_mat_id, traceHandle)
  if !res && (fast_check_idx < 0 || fast_check_idx == 3)
    res = traceray_normalized(rightPos, gunDir, t, pmid, norm, ETF_DEFAULT, riDesc, gun_mat_id, traceHandle)

  if !res
    return false
  let backoffAmount = gunLen + backupDist - t
  if backoffAmount <= max_backoff
    backoff = backoffAmount
    return false
  return true

def is_human_allowed_shooting(eid : EntityId; attached_gun_eid : EntityId; human_net_phys : HumanActor) : bool
  assume currentState = human_net_phys.phys.currentState
  let isSprinting = currentState.moveState == HUMoveState EMS_SPRINT
  let isMelee = currentState.weapEquipState.curSlot == HUWeaponSlots EWS_MELEE
  let isGunEquiped = currentState.weapEquipState.curState == HUWeaponEquipState EES_EQUIPED || attached_gun_eid != INVALID_ENTITY_ID
  let isMoving = currentState.moveState != HUMoveState EMS_STAND
  var res = (!(isSprinting && !isMelee) &&
            !currentState |> human_phys_state_get_is_swimming() && isGunEquiped &&
            currentState |> human_phys_state_get_canShoot() &&
            !(currentState |> human_phys_state_get_forceWeaponDown()) &&
            !(currentState.isCrawl && isMoving))
  if !res
    return false
  query(eid) <| $ [es] (isInVehicle : bool = false; isShootingAllowed : bool = true;
                        human_weap__blockAiming : bool = false; human_vehicle__isHoldingGunPassenger : bool = false;
                        human_weap__inspectEndTime : float = -1.0)
    res = (isShootingAllowed && !human_weap__blockAiming &&
          (!isInVehicle || human_vehicle__isHoldingGunPassenger) &&
          (get_sync_time() > human_weap__inspectEndTime))
  return res


def is_human_allowed_shooting(eid : EntityId)
  var res = false
  query(eid) <| $ [es] (human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                        human_net_phys : HumanActor)
    res = is_human_allowed_shooting(eid, human_attached_gun__attachedGunEid, human_net_phys)
  return res

def human_weap_clamp_vert_aim_angle(angle : float; interp_quat : quat; limits : float2)
  var pitchBasis : float
  var heading : float
  var bank : float
  quat_to_euler(interp_quat, heading, pitchBasis, bank)
  return clamp(angle, pitchBasis + limits.x, pitchBasis + limits.y)

def apply_gun_angle_offsets(phys : HumanPhys; at_time : float; limits : float2; var angles : float2&)
  assume prevState = phys.previousState
  assume curState  = phys.currentState
  let prevOffset = prevState.breathOffset + prevState.handsShakeOffset + prevState.gunAimOffset
  let curOffset = curState.breathOffset + curState.handsShakeOffset + curState.gunAimOffset
  let interpK = get_phys_interpk_clamped(phys, at_time)

  angles += lerp(prevOffset, curOffset, float2(interpK))
  let interpQuat = slerp(prevState.location.O.quat, curState.location.O.quat, interpK)
  angles.y = human_weap_clamp_vert_aim_angle(angles.y, interpQuat, limits)






















































def human_weap_switch_to_slot(eid : EntityId;
                              gun_eid : EntityId;
                              alternative : bool)
  query(gun_eid) <| $ [es] (gun_attach__mainSlotId : int;
                            gun_attach__altSlotId : int = -1;
                            var slot_attach__slotId : int&)
    let slot = alternative ? gun_attach__altSlotId : gun_attach__mainSlotId
    anim_attach(slot_attach__slotId, eid, slot, gun_eid)
    sendEvent(eid, [[EventOnSelectWeap curr_gun_slot_id=slot]])


def clear_throw_mode(human_eid : EntityId;
                     grenade_thrower_eid : EntityId;
                     human_weap__gunEids : EidList;
                     var human_weap__throwMode : bool&;
                     var phys : HumanPhys)
  human_weap__throwMode = false
  if phys.appliedCT.chosenWeapon == HUWeaponSlots EWS_GRENADE && !take_grenade_in_hand(human_eid, grenade_thrower_eid)
    switch_to_first_weap_with_ammo(human_weap__gunEids, phys)


def reload_projectile(eid, gun_eid : EntityId) : EntityId
  var shellEid = INVALID_ENTITY_ID
  query(gun_eid) <| $ [es] (gun__shell_prop_ids : PropsIdList;
                            var human_gun_attached : bool&;
                            var grenade_thrower__projectileEntity : EntityId&;
                            gun__curShellId : PropsId const?;
                            gun__propsId : PropsId)
    if !gun__propsId.valid || length(gun__shell_prop_ids) == 0
      return
    
      
        
    if gun__curShellId != null
      shell_entity_get_props(*gun__curShellId) <| $(entProps : ShellEntityTypeProps)
        let entPropsTemplName = entProps.templName
        if !empty(entPropsTemplName) && grenade_thrower__projectileEntity == INVALID_ENTITY_ID
          shellEid = create_shell_entity(entPropsTemplName,
                                          IDENT_TM,
                                          float3(0.f),
                                          eid,
                                          *gun__curShellId,
                                          gun__propsId,
                                           get_sync_time(),
                                           0.f,
                                           false,
                                           !is_server(),
                                          INVALID_ENTITY_ID)
          human_gun_attached = false
          grenade_thrower__projectileEntity = shellEid

  return shellEid


def set_cur_ammo_num(gun_eid : EntityId; num : int)
  if num > 0
    query(gun_eid) <| $ [es] (gun__owner : EntityId;
                              gun__shell_prop_ids : PropsIdList;
                              var gun__curShellId : PropsId)
      if gun__curShellId.valid
        gun__curShellId = gun__shell_prop_ids[0]
      sendEventImmediate(gun_eid, [[CmdLoadAmmo ammoNum=num]])
      reload_projectile(gun__owner, gun_eid)
  else
    sendEventImmediate(gun_eid, [[CmdUnloadAmmo unloadManually=false]])


def human_gun_mod_reset_custom_props(var custom_props : Object)
  if custom_props |> has("itemEid")
    custom_props |> set("itemEid", INVALID_ENTITY_ID)


def human_gun_from_custom_props(var custom_props : Object;
                                gun_eid : EntityId)
  var ammoHolderEid = INVALID_ENTITY_ID
  if custom_props |> has("itemEid")
    ammoHolderEid = custom_props["itemEid"] |> get_Eid() ?? INVALID_ENTITY_ID
  if custom_props |> has("ammoCount")
    set_cur_ammo_num(gun_eid, custom_props["ammoCount"] |> get_int() ?? 0)
  var isGun = false
  query(gun_eid) <| $ [es(REQUIRE=gun)] (var gun__curShellId : PropsId;
                                         var gun__ammoHolderEid : EntityId&)
    isGun = true
    if custom_props |> has("shellPropsId")
      let shellPropsIdContainer = custom_props["shellPropsId"]
      if shellPropsIdContainer != null
        let shellPropsId = *shellPropsIdContainer |> get_shell_props_ids()
        if shellPropsId != null
          gun__curShellId = *shellPropsId
    gun__ammoHolderEid = ammoHolderEid
  if !isGun
    
    destroyEntity(ammoHolderEid)

  human_gun_mod_reset_custom_props(custom_props)


def human_gun_mod_from_custom_props(var custom_props : Object;
                                    mod_eid : EntityId)
  human_gun_from_custom_props(custom_props, mod_eid)


struct GunUpdateCtx
  dt : float
  atTime : float
  isForReal : bool
  eid : EntityId
  isDowned : bool
  isThrowingAllowed : bool
  shotDeviationMult : float
  rotationShotSpreadDecrMult : float
  aimingAfterFireMult : float
  boltActionMult : float
  shotDeviationAdd : float
  fastThrowExclusive : bool
  deviationBufferSizeMult : float


def search_grenade_for_fast_throw(var result_ammo_type : int&;
                                  eid : EntityId;
                                  grenade_gun_eid : EntityId;
                                  start_ammo_type : int;
                                  control_state : HumanControlState&)
  var foundGrenade = false
  query(eid) <| $ [es] (itemContainer : EidList)
    query(grenade_gun_eid) <| $ [es(REQUIRE=gun)] (gun__ammoHolderIds : IntList&;
                                                   gun__shell_prop_ids : PropsIdList&)
      gather_ammo_for_gun(gun__ammoHolderIds, gun__shell_prop_ids, itemContainer) <| $(ammoItems)
        let ammoItemsCount = length(ammoItems)
        let curSlot = ammoItems |> find_index(start_ammo_type)
        if !(control_state |> human_control_state_is_throw_state_set(HumanControlThrowSlot HCTS_ALL))
          return
        for i in range(ammoItemsCount)
          let ammoItemId = ammoItems[(i + curSlot) % ammoItemsCount]
          find_ammo_for_gun(grenade_gun_eid, itemContainer, ammoItemId, 0) <| $(ammoForGun : AmmoItemForGunResult)
            if ammoForGun.itemIndex < 0
              return
            let itemEid = itemContainer[ammoForGun.itemIndex]
            query(itemEid) <| $ [es] ([[shared_comp]] fastThrowSlots : Object;
                                      item__grenadeType : string)
              let slotConfig = *fastThrowSlots[item__grenadeType] as int
              if slotConfig != null
                for slot in each_enum(HumanControlThrowSlot HCTS_SLOT0)
                  if int(slot) == 1 << (*slotConfig - 1) && control_state |> human_control_state_is_throw_state_set(slot)
                    result_ammo_type = ammoItemId
                    foundGrenade = true
          if foundGrenade
            return
  return foundGrenade


def throw_grenade_away(eid : EntityId;
                       grenade_eid : EntityId;
                       grenade_thrower_eid : EntityId)
  var res = false
  query(grenade_eid) <| $ [es] (shell__hudMarkerTemplate : string = "";
                                shell__shell_id__shell_id : PropsId;
                                shell__gun_props_id : PropsId;
                                shell__explTime : float;
                                transform : float3x4;
                                shell__owner : EntityId = INVALID_ENTITY_ID;
                                shell__rethrower : EntityId = INVALID_ENTITY_ID;
                                grenade__rethrownTemplate : string = "";
                                var active : bool&;
                                var gun__visible : bool?)
    shell_entity_get_props(shell__shell_id__shell_id) <| $(entProps : ShellEntityTypeProps)
      let templName = grenade__rethrownTemplate == "" ? entProps.templName : grenade__rethrownTemplate
      if templName == ""
        return
      res = true
      
        
      query(grenade_thrower_eid) <| $ [es] (var shell_props : PropsId;
                                            var gun__ammo : int&;
                                            var gun__curShellId : PropsId;
                                            var gun : Gun;
                                            var human_gun_attached : bool&;
                                            var grenade_thrower__projectileEntity : EntityId&)
        
        

        var newShellOwner = shell__owner
        var newShellRethrower = shell__rethrower

        if shell__owner == INVALID_ENTITY_ID
          newShellOwner = eid
        else
          
          
          newShellRethrower = eid

        human_gun_attached = false
        shell_props := shell__shell_id__shell_id
        gun__ammo = gun__ammo + 1
        gun__curShellId := shell__shell_id__shell_id

        gun.curState.loaded = (gun__ammo != 0)

        if is_server()
          destroyEntity(grenade_eid)
          destroyEntity(grenade_thrower__projectileEntity)
          grenade_thrower__projectileEntity = INVALID_ENTITY_ID
        else
          if gun__visible != null
            *gun__visible = false
          active = false

        var templateName = ""
        if shell__hudMarkerTemplate != ""
          templateName = add_sub_template_name(templName, shell__hudMarkerTemplate)
        else
          templateName = templName

        let startVel = float3()
        
        
        grenade_thrower__projectileEntity = create_shell_entity(templateName, transform, startVel,
                                                                newShellOwner, shell__shell_id__shell_id,
                                                                shell__gun_props_id,  get_sync_time(),
                                                                shell__explTime,  true,  !is_server(),
                                                                newShellRethrower)

        if !is_server()
          query(eid) <| $ [es] (var human_weap__localProjectileEid : EntityId&)
            destroyEntity(human_weap__localProjectileEid)
            human_weap__localProjectileEid = grenade_thrower__projectileEntity
  return res

def human_weap_gun_update(var human_net_phys : HumanActor;
                          var human_weap__gunEids : EidList;
                          var human_weap__throwMode : bool&;
                          ctx : GunUpdateCtx;
                          transform : float3x4;
                          gun_dir : float3;
                          gun_shoot_dir : float3;
                          phys_transform : float3x4;
                          ct : HumanControlState;
                          grenade_rethrow__grenadeEid : EntityId const?;
                          human_unarmed__active : bool;
                          human_attached_gun__attachedGunEid : EntityId;
                          human_weap__currentGunEid : EntityId;
                          human_weap__jumpDeviation : float;
                          human_weap__changePosDeviationCanAim : float;
                          human_weap__changePosDeviationCanNotAim : float;
                          human_weap__grenadeThrower : EntityId;
                          human_phys__jumpEndTime : float;
                          human_phys__afterJumpDelay : float;
                          human_phys__isInAirLong : bool;
                          bipod__enabled : bool)
  assume phys = human_net_phys.phys
  let selectedGun = determine_current_weapon_slot(ctx.atTime, human_net_phys)
  let curGun = selectedGun

  let allowShootingNoAttach = is_human_allowed_shooting(ctx.eid) && !human_attached_gun__attachedGunEid
  let isHctShootSet = ct |> is_control_bit_set(HumanPhysControlType HCT_SHOOT)
  var hasGrenade = false
  query(human_weap__grenadeThrower) <| $ [es(REQUIRE=grenade_thrower)] (gun__totalAmmo : int = 0;
                                                                        gun__ammo : int = 0)
    hasGrenade = gun__totalAmmo > 0 || gun__ammo > 0

  if (ct |> is_control_bit_set(HumanPhysControlType HCT_THROW_BACK) && ctx.isForReal &&
     !human_weap__throwMode && allowShootingNoAttach)
    var grenadeEid = INVALID_ENTITY_ID
    if is_server()
      grenadeEid = find_rethrowable_grenade(ctx.eid)
    elif grenade_rethrow__grenadeEid != null
      grenadeEid = *grenade_rethrow__grenadeEid
    if grenadeEid != INVALID_ENTITY_ID
      human_weap__throwMode = throw_grenade_away(ctx.eid, grenadeEid, human_weap__grenadeThrower)
    if is_server() && !human_weap__throwMode
      send_net_event(ctx.eid, [[HumanWeapThrowBackAbort]])

  var reloadGrenade = false
  var isFastThrow = false
  if ctx.isForReal && ctx.isThrowingAllowed && hasGrenade && allowShootingNoAttach
    let isFastThrowReq = ct |> human_control_state_is_throw_state_set(HumanControlThrowSlot HCTS_SLOT0)
    if isFastThrowReq && ctx.fastThrowExclusive && !human_weap__throwMode && human_weap__currentGunEid != human_weap__grenadeThrower
      human_weap__throwMode = true
      human_weap_switch_to_slot(ctx.eid, human_weap__grenadeThrower, true)
      reloadGrenade = true
    let isExtendedFastThrowReq = ct |> is_control_bit_set(HumanPhysControlType HCT_THROW)
    if isExtendedFastThrowReq && !ctx.fastThrowExclusive && !human_weap__throwMode
      let prevAmmoType = get_int(human_weap__grenadeThrower, "gun__wishAmmoItemType") ?? INVALID_ITEM_ID
      var newAmmoType = 0
      human_weap__throwMode = search_grenade_for_fast_throw(newAmmoType, ctx.eid, human_weap__grenadeThrower, prevAmmoType, ct)
      if human_weap__throwMode
        query(human_weap__grenadeThrower) <| $ [es(REQUIRE=gun)] (var gun__wishAmmoItemType : int&)
          gun__wishAmmoItemType = newAmmoType
        human_weap_switch_to_slot(ctx.eid, human_weap__grenadeThrower, true)

      reloadGrenade = human_weap__throwMode
      if is_server() && reloadGrenade && prevAmmoType != (get_int(human_weap__grenadeThrower, "gun__wishAmmoItemType") ?? INVALID_ITEM_ID)
        let obtainOwnedProjectileEntity = obtain_owned_projectile_entity(human_weap__grenadeThrower)
        destroyEntity(obtainOwnedProjectileEntity)
    isFastThrow = (isFastThrowReq || isExtendedFastThrowReq) && human_weap__throwMode
    if (!isFastThrow && human_weap__currentGunEid == human_weap__grenadeThrower
        && !human_weap__throwMode && isHctShootSet && !ctx.isDowned)
      human_weap__throwMode = true
      reloadGrenade = true

  if reloadGrenade
    if reload_impl(ctx.eid, human_weap__grenadeThrower, ReloadAmmoMode CONSUME)
      
      let projectileEid = reload_projectile(ctx.eid, human_weap__grenadeThrower)

      if !is_server()
        
        query(ctx.eid) <| $ [es] (var human_weap__localProjectileEid : EntityId&)
          destroyEntity(human_weap__localProjectileEid)
          human_weap__localProjectileEid = projectileEid

  let gunEid = human_weap__throwMode ? human_weap__grenadeThrower : human_weap__gunEids[int(curGun)]
  
  var overrideGunEid = gunEid
  var isLungeMine = false
  query(gunEid) <| $ [es] (subsidiaryGunEid : EntityId const?; lunge_mine : Tag const?)
    if subsidiaryGunEid != null
      overrideGunEid = *subsidiaryGunEid
    isLungeMine = lunge_mine != null

  var wgun : Gun const? = null
  var gunDev : GunDeviation? = null
  var gunAmmo = 0
  var jumpDeviation = human_weap__jumpDeviation
  var grenadeThrower : GrenadeThrower const? = null
  var defaultInit = false
  if curGun == HUWeaponSlots EWS_MELEE || isLungeMine
    if !has(gunEid, "melee_weapon__propsId")
      return
  elif gunEid == human_weap__grenadeThrower
    query(gunEid) <| $ [es] (grenade_thrower : GrenadeThrower const?)
      grenadeThrower = grenade_thrower
    if grenadeThrower == null
      return
    defaultInit = true
  else
    defaultInit = true

  if defaultInit
    query(overrideGunEid) <| $ [es(trust_access)] (gun : Gun const?;
                                                   var gun_deviation : GunDeviation?;
                                                   gun__jumpDeviation : float const?;
                                                   gun__ammo : int = 0)
      wgun = gun
      gunDev = gun_deviation
      gunAmmo = gun__ammo
      jumpDeviation = gun__jumpDeviation ?? jumpDeviation
    if wgun == null && !has(gunEid, "itemInWeaponSlot")
      return

  let isJumping = ((uint(phys.currentState.states) & uint(StateFlag ST_JUMP)) != 0u
    || phys.currentState.jumpStartTime > 0.
    || ctx.atTime - human_phys__jumpEndTime < human_phys__afterJumpDelay
    || human_phys__isInAirLong)

  if gunDev != null && ctx.isForReal
    *gunDev |> gun_deviation_getAppliedCT() <| $(var gunDevCT : GunDeviationInput#)
      gunDevCT.bufferSizeMult = ctx.deviationBufferSizeMult
      gunDevCT.tauMult = ctx.shotDeviationMult
      gunDevCT.rotationShotSpreadDecrMult = ctx.rotationShotSpreadDecrMult
      gunDevCT.aimingAfterFireMult = ctx.aimingAfterFireMult
      gunDevCT.movement = phys.currentState.velocity.xz
      let changePoseDeviation = human_phys_state_can_aim(phys.currentState) ? human_weap__changePosDeviationCanAim : human_weap__changePosDeviationCanNotAim
      var heightVel = abs(phys.currentState.heightCurVel)
      if bipod__enabled
        gunDevCT.movement *= 0.
        heightVel = 0.
      gunDevCT.minExtraDev = (lerp(get_float(overrideGunEid, "gun__deviationInFireReady") ?? 0.0, 0.0, phys.currentState.aimPosition)
                            + ctx.shotDeviationAdd
                            + max(cvt(heightVel, 0., 1., 0., changePoseDeviation),
                                 (isJumping ? jumpDeviation : 0.0)))

  
  var shoot = ((human_weap__throwMode
    ? isFastThrow || ct |> is_control_bit_set(HumanPhysControlType HCT_THROW_BACK) || isHctShootSet
    : (isHctShootSet && allowShootingNoAttach)) && !ctx.isDowned)

  if shoot
    query(ctx.eid) <| $ [es] (human_inventory__entityToUse : EntityId;
                              human_sec_anim__play : bool = false;
                              human_weap__reloadFinishTime : float = -1.0;
                              human_weap__isReloading : bool = false;
                              human_weap__weapModActivateStartTime : float = -1.0)
                              
      if human_sec_anim__play
        logerr("sec anim active in human_weap_gun_update with HCT_SHOOT set")
      if human_inventory__entityToUse != INVALID_ENTITY_ID
        if has(human_inventory__entityToUse, "item__ignoreLmbInterrupt")
          shoot = false
        else
          logerr("active human_inventory.entityToUse in human_weap_gun_update with HCT_SHOOT set")

      if !human_weap__throwMode
        shoot &&= ctx.atTime > human_weap__reloadFinishTime && !human_weap__isReloading
        shoot &&= human_weap__weapModActivateStartTime < 0.0
      elif ctx.isForReal
        query(gunEid) <| $ [es] (grenade_thrower__projectileEntity : EntityId;
                                 shell__autoThrowCountdown : float = 1.2)
          let explTime = get_float(grenade_thrower__projectileEntity, "shell__explTime") ?? 0.0
          if shell__autoThrowCountdown > 0.0 && explTime > 0.0 && ctx.atTime > explTime - shell__autoThrowCountdown
            shoot = false

      query(gunEid) <| $ [es] (blockShoot : bool;
                               blockShootReason : string = "")
        if blockShoot && wgun != null && !wgun.appliedControls.wishShoot
          broadcastEvent([[EventOnGunBlocksShoot reason=blockShootReason]])
        shoot = !blockShoot && shoot
      
      
      
      
      

  shoot = !human_unarmed__active && shoot

  if (wgun != null && gunAmmo == 0 && ctx.isForReal && !wgun.appliedControls.shoot && shoot &&
      phys.currentState.weapEquipState.curState == HUWeaponEquipState EES_EQUIPED && !isFastThrow)
    
    
    
    query(overrideGunEid) <| $ [es(REQUIRE_NOT=doNotHideWeapWithoutAmmo)] (gun__owner : EntityId;
                                                                           gun__totalAmmo : int = 0;
                                                                           subsidiaryGun : Tag const?;
                                                                           weapon_mod__active : bool = false)
      if gun__totalAmmo == 0
        if subsidiaryGun != null
          var parentGunHasAmmo = false
          query(gunEid) <| $ [es] (gun__totalAmmo aka parent_gun__totalAmmo : int = 0; gun__ammo : int = 0)
            parentGunHasAmmo = parent_gun__totalAmmo > 0 || gun__ammo > 0

          if parentGunHasAmmo
            
            
            if weapon_mod__active
              sendEvent(gun__owner, [[CmdWeapModToggle slotId=int(curGun)]])
            return

        var bestSlot = selectedGun
        var i = 0
        while i < int(HUWeaponSlots EWS_NUM) && bestSlot == selectedGun
          if i == int(HUWeaponSlots EWS_GRENADE) || i == int(selectedGun)
            ++i
            continue
          query(human_weap__gunEids[i]) <| $ [es] (gun__totalAmmo : int = 0; gun__ammo : int = 0)
            if gun__totalAmmo > 0 || gun__ammo > 0
              bestSlot = HUWeaponSlots(i)
          ++i
        phys.producedCT |> set_chosen_weapon(bestSlot)

  if ctx.isForReal && !isFastThrow
    let isRequestingReload = ct |> is_control_bit_set(HumanPhysControlType HCT_RELOAD)
    
    
    if isRequestingReload
      sendEvent(ctx.eid, [[CmdRequestReload atTime=ctx.atTime, gunEid=overrideGunEid, isQuick=ct.isQuickReloadStateSet]])
    elif ct.dodgeState != DodgeState No 
      sendEvent(ctx.eid, [[CmdGunRequestInspect atTime=ctx.atTime, gunEid=overrideGunEid]])
    query(overrideGunEid) <| $ [es] (var gun_reload__isRequesting : bool&)
      gun_reload__isRequesting = isRequestingReload

  using() <| $(var gctrl : GunControls#)
    gctrl.shoot = shoot
    gctrl.wishShoot = isHctShootSet
    gctrl.boltActionMult = ctx.boltActionMult
    gctrl.timeStep = human_net_phys.phys.timeStep

    if ct |> human_control_state_get_shootPos_packed() > 0u
      let worldShootPos = phys_transform * ct |> human_control_state_unpack_shootPos()
      using(gun_dir, gun_shoot_dir, human_net_phys.phys.currentState.velocity, worldShootPos) <| $(var gloc : GunLocation#)
        sendEventImmediate(gunEid, [[CmdWeapPhysUpdate
                                     owner=ctx.eid,
                                     atTime=ctx.atTime,
                                     dt=ctx.dt,
                                     isForReal=ctx.isForReal,
                                     slotId=int(curGun),
                                     gctrl := gctrl,
                                     gloc := gloc]])
    else
      using(gun_dir, gun_shoot_dir, human_net_phys.phys.currentState.velocity, transform, phys_transform) <| $(var gloc : GunLocation#)
        sendEventImmediate(gunEid, [[CmdWeapPhysUpdate
                                     owner=ctx.eid,
                                     atTime=ctx.atTime,
                                     dt=ctx.dt,
                                     isForReal=ctx.isForReal,
                                     slotId=int(curGun),
                                     gctrl := gctrl,
                                     gloc := gloc]])

  
    
    
    

  update_reload(ctx.eid, ctx.atTime, ctx.dt)

  if (human_weap__throwMode && ctx.isForReal && grenadeThrower != null &&
      grenadeThrower.state == GrenadeThrowState GTS_READY && !ctx.isDowned)
    clear_throw_mode(ctx.eid, gunEid, human_weap__gunEids, human_weap__throwMode, phys)

def obtain_grenade_thrower_projectile_entity(var grenade_thrower__projectileEntity : EntityId&)
  if !doesEntityExist(grenade_thrower__projectileEntity)
    return INVALID_ENTITY_ID
  setOptional(grenade_thrower__projectileEntity, "gun__visible", false)
  sendEvent(grenade_thrower__projectileEntity, [[CmdSlotDetach]])
  let ent = grenade_thrower__projectileEntity
  grenade_thrower__projectileEntity = INVALID_ENTITY_ID
  return ent


def obtain_owned_projectile_entity(gun_eid : EntityId)
  var projectileEid = INVALID_ENTITY_ID
  query(gun_eid) <| $ [es] (var grenade_thrower__projectileEntity : EntityId&)
    projectileEid = obtain_grenade_thrower_projectile_entity(grenade_thrower__projectileEntity)
  return projectileEid

def take_grenade_in_hand(human_eid : EntityId;
                         grenade_thrower_eid : EntityId)
  var hasGrenade = false
  query(grenade_thrower_eid) <| $ [es(REQUIRE=grenade_thrower)] (gun__totalAmmo : int;
                                                                 gun__ammo : int)
    hasGrenade = gun__totalAmmo > 0 || gun__ammo > 0

  if !hasGrenade
    return false
  if reload_impl(human_eid, grenade_thrower_eid, ReloadAmmoMode INFINITE) 
    let obtainOwnedProjectileEntity = obtain_owned_projectile_entity(grenade_thrower_eid)
    if is_server()
      destroyEntity(obtainOwnedProjectileEntity)

    
    let newProjectileEid = reload_projectile(human_eid, grenade_thrower_eid)

    if !is_server()
      
      query(human_eid) <| $ [es] (var human_weap__localProjectileEid : EntityId&)
        destroyEntity(human_weap__localProjectileEid)
        human_weap__localProjectileEid = newProjectileEid

    choose_weapon(human_eid, HUWeaponSlots EWS_GRENADE, grenade_thrower_eid)
    return true
  return false


def switch_to_first_weap_with_ammo(human_weap__gunEids : EidList;
                                   var phys : HumanPhys)
  var slots : array<tuple<slot : int; priority : int>>
  var choosenSlot = -1
  for i in range(int(HUWeaponSlots EWS_NUM))
    query(human_weap__gunEids[i]) <| $ [es] (gun__totalAmmo : int;
                                             gun__ammo : int;
                                             gun__switchToPriority : int = 0)
      if i != int(HUWeaponSlots EWS_GRENADE) && (gun__totalAmmo > 0 || gun__ammo > 0)
        slots |> push([[auto i, gun__switchToPriority]])
  if !empty(slots)
    sort(slots) <| $(a, b) { return a.priority == b.priority ? a.slot < b.slot : a.priority > b.priority; }
    choosenSlot = slots[0].slot
    phys.producedCT |> set_chosen_weapon(HUWeaponSlots(choosenSlot))

  return choosenSlot > -1

def human_weap_can_reload(human_eid : EntityId; gun_eid : EntityId) : bool
  var canReload = true
  query(human_eid) <| $ [es] (human_net_phys : HumanActor;
                              human_weap__throwMode : bool;
                              human_weap__weapModActivateStartTime : float;
                              boltActionProgress : float;
                              human_weap__isReloading : bool = false;
                              human_weap__canOperate : bool = true;
                              burning__isBurning : bool = false;
                              human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                              human_inventory__entityToUse : EntityId = INVALID_ENTITY_ID)
    assume currentState = human_net_phys.phys.currentState
    assume eqState = currentState.weapEquipState.curState
    assume mvState = currentState.moveState
    let isCrawlMoving = currentState.isCrawl && mvState != HUMoveState EMS_STAND
    let isAttachedToGun = !!human_attached_gun__attachedGunEid
    let isBlockedByBoltAction = ((get_bool(gun_eid, "reload__waitBoltActionFinished") ?? false) &&
                                  boltActionProgress > 0. && boltActionProgress < 1.)
    let usingItem = !!human_inventory__entityToUse && has(human_inventory__entityToUse, "item__interruptsReloading")

    canReload = (!human_weap__throwMode &&
                 !isCrawlMoving &&
                 !human_weap__isReloading &&
                 !burning__isBurning &&
                 (eqState == HUWeaponEquipState EES_EQUIPED || eqState == HUWeaponEquipState EES_DOWN || isAttachedToGun) &&
                 !isBlockedByBoltAction && (human_weap__weapModActivateStartTime < 0.) &&
                 !usingItem &&
                 human_weap__canOperate)
  return canReload
























def unload_gun_mod_ammo(human_eid : EntityId;
                        slot_id : int;
                        slot_name : string) : void
  query(human_eid) <| $ [es] (human_weap__gunMods, human_weap__gunModsBySlot : Array)
    if slot_id >= length(human_weap__gunMods)
      return

    var gunModsBySlot = human_weap__gunModsBySlot[slot_id] |> get_ecs_object()
    var gunMods = human_weap__gunMods[slot_id] |> get_ecs_EidList()
    if gunModsBySlot == null || gunMods == null
      return

    for gunModEid in *gunMods
      query(gunModEid) <| $ [es] (gunAttachable__gunSlotName : string)
        if !empty(slot_name) && (gunAttachable__gunSlotName != slot_name)
          return

        unload_gun_ammo(gunModEid, human_eid)

















































def attach_item_to_gun_impl(eid : EntityId;
                            human_weap__gunEids : EidList;
                            gun_slot_id : int;
                            slot_tag : string;
                            slot_name : string;
                            var human_weap__gunMods : Array;
                            var custom_props : Object? = null)
  if !human_weap__gunEids[gun_slot_id]
    return

  query(eid) <| $ [es] (var human_weap__gunModsBySlot : Array)
    var gunModSlots = human_weap__gunModsBySlot[gun_slot_id] |> getRW_ecs_object()
    if gunModSlots == null
      return

    if !*gunModSlots |> has(slot_name)
      return

    
    unload_gun_mod_ammo(eid, gun_slot_id, slot_name)

    *gunModSlots |> set(slot_name, slot_tag)

    var gunMods = getRW_ecs_EidList(human_weap__gunMods[gun_slot_id])
    for i in iter_range(*gunMods)
      let gunModEid = (*gunMods)[i]
      var erased = false
      query(gunModEid) <| $ [es] (gunAttachable__gunSlotName : string)
        if gunAttachable__gunSlotName == slot_name
          destroyEntity(gunModEid)
          *gunMods |> erase(i)
          erased = true
      if erased
        break

    if slot_tag == ""
      return

    let gunEid = human_weap__gunEids[gun_slot_id]
    query(gunEid) <| $ [es] (gun_mods__slots : Object)
      let slot = gun_mods__slots |> get_ecs_object(slot_name)
      if slot == null
        logerr("Gun '{getEntityTemplateName(gunEid)}' does not have slot '{slot_name}' in component 'gun_mods.slots'")
        return
      let slotName = *slot |> get_ecs_string(slot_tag)
      if slotName == null
        var avSlotTags = ""
        for kv in *slot
          avSlotTags += kv.key
          avSlotTags += ","
        if avSlotTags != ""
          avSlotTags = avSlotTags |> chop(0, length(avSlotTags) - 1)
        logerr("Unknown slot_tag '{slot_tag}' for slot '{slot_name}' while creating gunMods for {human_weap__gunEids[gun_slot_id]}<{getEntityTemplateName(human_weap__gunEids[gun_slot_id])}>,\navailable slot tags are {avSlotTags}")
        return

      using() <| $(var comps : ComponentsInitializer)
        set(comps, "slot_attach__attachedTo", gunEid)
        set(comps, "gun__owner", eid)

        using() <| $(var customPropsCopy : Object)
          if custom_props != null
            customPropsCopy := *custom_props
            set(comps, "custom_props", customPropsCopy)
            
            
            
            
            human_gun_mod_reset_custom_props(*custom_props)

          var modEid = INVALID_ENTITY_ID
          if is_dedicated()
            
            
            modEid = createEntitySync(*slotName |> string(), comps)
          else
            modEid = createEntity(*slotName |> string(), comps)

          *gunMods |> push(modEid)


def dead_or_downed(eid : EntityId) : bool
  var res = false
  query(eid) <| $ [es] (isAlive : bool = true;
                        isDowned : bool = false)
    res = !isAlive || isDowned
  return res






























































































































































enum RecreateGunsFlags
  None         = 0
  Attach       = 1 << 0
  ParentLoaded = 1 << 1


def init_gun_comps(var init : ComponentsInitializer;
                   eid : EntityId;
                   init_comps : Object const? = null)
  if init_comps != null
    set(init, "gun__initialComponents", *init_comps)
    for kv in *init_comps
      set(init, kv.key, kv.value)

  set(init, "gun__owner", eid)


def create_gun_for_entity_impl(eid : EntityId;
                               weap_templ_name : string;
                               init_comps : Object const?;
                               create : block<(n : string; var ci : ComponentsInitializer) : EntityId>)
  if weap_templ_name == ""
    return INVALID_ENTITY_ID

  var name = weap_templ_name
  query(eid) <| $ [es] (human_weap__itemRemap : Object)
    if human_weap__itemRemap |> has(weap_templ_name)
      let n = human_weap__itemRemap[weap_templ_name] |> get_ecs_string()
      if n != null
        name = *n |> string()

  var gunEid = INVALID_ENTITY_ID
  using() <| $(var init : ComponentsInitializer)
    init_gun_comps(init, eid, init_comps)
    gunEid = create |> invoke(name, init)
  return gunEid


def restore_ammo_type_impl(eid : EntityId;
                           var itemContainer : EidList;
                           ammo_template : string;
                           ammo_num : int;
                           calc_gun_ammo_cb : block<(ammo_item_id : int) : int>)
  if ammo_num <= 0
    return false

  let reserveAmmoItemId = ammo_template != "" ? int(ecs_hash(ammo_template)) : INVALID_ITEM_ID

  var initialNum = invoke(calc_gun_ammo_cb, reserveAmmoItemId) > 0 ? 1 : 0
  for itemEid in itemContainer
    var itemId = INVALID_ITEM_ID
    query(itemEid) <| $ [es] (item__id aka entity_item__id : int)
      itemId = entity_item__id
    initialNum += (itemId == reserveAmmoItemId) ? 1 : 0
  for _i in range(initialNum, ammo_num)
    var itemEid = INVALID_ENTITY_ID
    if ammo_template == ""
      logerr("Can't restore ammo with invalid ammo template ( isn't define in '{getEntityTemplateName(eid)} )")
      return false
    using() <| $(var init : ComponentsInitializer)
      set(init, "item__ownerEid", eid)
      set(init, "item__lastOwner", eid)
      itemEid = createInstantiatedEntitySync(ammo_template, init)
      if itemEid == INVALID_ENTITY_ID
        
        logerr("Template dependency '{ammo_template}' isn't instantiated in '{getEntityTemplateName(eid)}'")
        itemEid = createEntitySync(ammo_template, init)
    if find_index(itemContainer, itemEid) == -1
      itemContainer |> push(itemEid)

  return true


def restore_ammo_impl(eid : EntityId;
                      human_weap__gunEids : EidList;
                      gun_slot : int)
  var result = false
  query(eid) <| $ [es] (human_weap__weapInfo : Array;
                        var itemContainer : EidList)
    query(human_weap__gunEids[gun_slot]) <| $ [es(REQUIRE=gun)] (gun__ammo : int = 0; gun__ammoHolderEid : EntityId = INVALID_ENTITY_ID)
      if gun_slot > length(human_weap__weapInfo)
        return
      let weapInfoSlot = human_weap__weapInfo[gun_slot] |> get_ecs_object()
      let curAmmoHolderItemId = get_int(gun__ammoHolderEid, "item__id") ?? INVALID_ITEM_ID
      assume calcGunAmmoCb = ($(ammoItemId : int) : int { return ammoItemId == curAmmoHolderItemId ? gun__ammo : 0; })

      let numReserveAmmo = weapInfoSlot |> get_int("numReserveAmmo") ?? 0
      if numReserveAmmo > 0
        let reserveAmmoTemplate = weapInfoSlot |> get_ecs_string("reserveAmmoTemplate")
        if reserveAmmoTemplate == null
          logerr("'reserveAmmoTemplate' is missed in human_weap.weapInfo. See log for details.")
          print("eid: {eid} of template '{getEntityTemplateName(eid)}'")
          for item in human_weap__weapInfo
            let obj = item |> get_ecs_object()
            let objReserveAmmoTemplate = obj |> get_ecs_string("reserveAmmoTemplate")
            let objReserveAmmoTemplateStr = objReserveAmmoTemplate != null ? *objReserveAmmoTemplate |> string() : ""
            let objNumReserveAmmo = obj |> get_int("numReserveAmmo") ?? 0
            print("[reserveAmmoTemplate] = {objReserveAmmoTemplateStr}")
            print("[numReserveAmmo] = {objNumReserveAmmo}")
          return
        if !restore_ammo_type_impl(eid, itemContainer, string(*reserveAmmoTemplate), numReserveAmmo, calcGunAmmoCb)
          return

      let additionalAmmoTemplates = get_ecs_array(weapInfoSlot, "additionalReserveAmmoTemplates")
      let additionalAmmoNums = get_ecs_array(weapInfoSlot, "additionalNumReserveAmmos")
      if additionalAmmoTemplates != null && additionalAmmoNums != null
        for ammoTemplateItem, ammoNumItem in *additionalAmmoTemplates, *additionalAmmoNums
          let ammoTemplate = ammoTemplateItem ?? ""
          let ammoNum = ammoNumItem ?? 0
          if !restore_ammo_type_impl(eid, itemContainer, ammoTemplate, ammoNum, calcGunAmmoCb)
            return

      if (gun_slot != int(HUWeaponSlots EWS_GRENADE))
        reload_impl(eid, gun_slot, ReloadAmmoMode CONSUME)
      result = true
  return result

def restore_ammo_with_magazine_mod_impl(eid : EntityId;
                                        human_weap__gunEids : EidList;
                                        gun_slot : int;
                                        magazineMod : string)
  var result = false
  query(eid) <| $ [es] (human_weap__weapInfo : Array;
                        var itemContainer : EidList)
    query(human_weap__gunEids[gun_slot]) <| $ [es(REQUIRE=gun)] (gun__ammo : int = 0; gun__ammoHolderEid : EntityId = INVALID_ENTITY_ID)
      let curAmmoHolderItemId = get_int(gun__ammoHolderEid, "item__id") ?? INVALID_ITEM_ID
      assume calcGunAmmoCb = ($(ammoItemId : int) : int { return ammoItemId == curAmmoHolderItemId ? gun__ammo : 0; })
      let magazineTempl = getTemplateByName(magazineMod)
      if magazineTempl == null
        return

      let ammoHolderComponent = getTemplateComponent(*magazineTempl, "magazine_mod__ammoHolder")
      let ammoHolderTemplate = ammoHolderComponent |> get_ecs_string()
      if ammoHolderTemplate == null
        return

      let ammoHoldersCountComponent = getTemplateComponent(*magazineTempl, "magazine_mod__defaultAmmoHoldersCount")
      var ammoHoldersCount = ammoHoldersCountComponent |> get_int() ?? -1
      if ammoHoldersCount < 0
        let weapInfoSlot = human_weap__weapInfo[gun_slot] |> get_ecs_object()
        ammoHoldersCount = weapInfoSlot |> get_int("numReserveAmmo") ?? 0

      if !restore_ammo_type_impl(eid, itemContainer, string(*ammoHolderTemplate), ammoHoldersCount, calcGunAmmoCb)
        return

      if (gun_slot != int(HUWeaponSlots EWS_GRENADE))
        reload_impl(eid, gun_slot, ReloadAmmoMode CONSUME)
      result = true
  return result

def restore_ammo_impl(eid : EntityId;
                      human_weap__gunEids : EidList)
  for i in iter_range(human_weap__gunEids)
    if human_weap__gunEids[i] != INVALID_ENTITY_ID
      restore_ammo_impl(eid, human_weap__gunEids, i)


def get_total_ammo_count(item_container : EidList;
                         wish_ammo_item_type : int;
                         gun_eid : EntityId)
  var res = 0
  query(gun_eid) <| $ [es] (gun__ammoHolderIds : IntList;
                            gun__shell_prop_ids : PropsIdList)
    for itemEid in item_container
      query(itemEid) <| $ [es] (shell_props : PropsId const?;
                                item__id : int = INVALID_ITEM_ID;
                                ammo_holder__id : int const?;
                                ammo_holder__ammoCount : int const?)
        if wish_ammo_item_type != INVALID_ITEM_ID && item__id != wish_ammo_item_type
          return
        if ammo_holder__id != null && ammo_holder__ammoCount != null && is_ammo_for_gun(*ammo_holder__id, gun__ammoHolderIds)
          res += *ammo_holder__ammoCount
          return
        if shell_props != null && is_shell_for_gun(*shell_props, gun__shell_prop_ids)
          res++ 
          return
  return res


def server_init_gun_ammo(gun_eid : EntityId)
  query(gun_eid) <| $ [es(REQUIRE=gun)] (gun__owner : EntityId;
                                         gun__ammo : int;
                                         gun__wishAmmoItemType : int;
                                         var gun__serverAmmo : int&;
                                         var gun__totalAmmo : int&)
    gun__serverAmmo = gun__ammo
    let itemContainer = get_ecs_EidList(gun__owner, "itemContainer")
    if itemContainer != null
      gun__totalAmmo = get_total_ammo_count(*itemContainer, gun__wishAmmoItemType, gun_eid)


struct GunModInSlot
  key : string
  value : string


def server_init_gun(eid : EntityId;
                    gun_eid : EntityId;
                    slot_id : int;
                    var human_weap__gunEids : EidList)
  human_weap__gunEids[slot_id] = gun_eid
  query(eid) <| $ [es] (human_weap__currentGunSlot : int;
                        var human_weap__gunModsBySlot : Array;
                        var human_weap__gunMods : Array;
                        var human_weap__currentGunEid : EntityId&;
                        var human_weap__currentGunModEids : EidList&)
    let gunEidInSlot = human_weap__gunEids[slot_id]
    if gunEidInSlot != INVALID_ENTITY_ID
      var hasMagazineMod = false
      var gunModsInSlot = human_weap__gunModsBySlot[slot_id] |> getRW_ecs_object()
      if gunModsInSlot != null
        query(gunEidInSlot) <| $ [es] (var gun_mods__slots : Object)
          for slot in gun_mods__slots
            let slotName = slot.key
            if !*gunModsInSlot |> has(slotName)
              *gunModsInSlot |> set(slotName, "")
        if length(*gunModsInSlot) > 0
          
          var gunModsInSlotCopy : array<GunModInSlot>
          gunModsInSlotCopy |> reserve(length(*gunModsInSlot))
          for gunMod in *gunModsInSlot
            let gunModStr = gunMod.value |> get_ecs_string()
            let value = gunModStr != null ? *gunModStr |> string() : ""
            gunModsInSlotCopy |> push([[GunModInSlot key=gunMod.key, value=value]])
          for gunMod in gunModsInSlotCopy
            var nullCustomProps : Object? = null
            attach_item_to_gun_impl(eid, human_weap__gunEids, slot_id, gunMod.value,
                                    gunMod.key, human_weap__gunMods, nullCustomProps)
            if gunMod.key == "magazine" && hasMagazineMod != (gunMod.key == "magazine")
              hasMagazineMod = restore_ammo_with_magazine_mod_impl(eid, human_weap__gunEids, slot_id, gunMod.value)
      if !hasMagazineMod
        restore_ammo_impl(eid, human_weap__gunEids, slot_id)

      server_init_gun_ammo(gunEidInSlot)

    if human_weap__currentGunSlot == slot_id
      human_weap__currentGunEid = human_weap__gunEids[slot_id]
      human_weap__currentGunModEids := *(human_weap__gunMods[slot_id] |> get_ecs_EidList())





























































































































































