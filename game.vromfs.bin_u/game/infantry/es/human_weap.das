require ecs
require ecs.safe
require ecs.common
require app
require %game.events
require %game.unit.unit_events
require %appGame.infantry.es.human_weap_common
require inventory
require math.base
require DagorSystem
require DaWeapons
require DngWeapon
require DngHuman
require HumanPhys
require AnimV20
require GamePhys
require PropsManager

require %appGame.wt_events
require %appGame.infantry.es.human_reload_common
require MPlayer
require DagorDataBlock
require Unit


[es(tag=server, on_appear, after=gun_init_shell_prop_ids_es)]
def gun_mod_custom_props_init_es(evt : Event;
                                 eid : EntityId;
                                 gunAttachable__slotName : string;
                                 var slot_attach__slotId : int&;
                                 var custom_props : Object?)
  let animcharSlotId = animchar_getSlotId(gunAttachable__slotName)
  slot_attach__slotId = animcharSlotId
  if custom_props != null
    human_gun_mod_from_custom_props(*custom_props, eid)
  server_init_gun_ammo(eid)


[es(tag=server, on_appear, after=gun_init_shell_prop_ids_es)]
def server_init_gun_es(evt : Event;
                       eid : EntityId;
                       gun__owner : EntityId;
                       gun__initialSlotId : int;
                       gun__initialFlags : int)
  if gun__initialSlotId != -1
    let gunEid = eid
    var gunEids = getRW_ecs_EidList(gun__owner, "human_weap__gunEids")
    if gunEids == null 
      if !doesEntityExist(gun__owner)
        logwarn("Ignore gun[{gun__initialSlotId}] init since parent {gun__owner} doesn't exist anymore")
      else
        logerr("Gun's [{gun__initialSlotId}] parent {gun__owner}<{getEntityTemplateName(gun__owner)}> exist but doesn't have 'human_weap.gunEids' component?!")
      return
    server_init_gun(gun__owner, gunEid, gun__initialSlotId, *gunEids)
    if (gun__initialFlags & int(RecreateGunsFlags.Attach)) != 0
      let attach = (gun__initialSlotId == get_int(gun__owner, "human_weap__currentGunSlot") ?? 0)
      sendEventImmediate(gunEid, CmdWeapAttach(toEid = gun__owner, isAttached = attach, slotId = gun__initialSlotId))

    if (gun__initialFlags & int(RecreateGunsFlags.ParentLoaded)) != 0
      sendEvent(gunEid, EventOnParentLoaded(eid = gun__owner, slotId = gun__initialSlotId))
    
    


def server_recreate_guns(eid : EntityId;
                         human_weap__weapTemplates : Object;
                         flags : int;
                         var human_weap__gunEids : EidList;
                         var human_weap__gunMods : Array;
                         var human_weap__weapInitialComponents : Array)
  human_weap__gunEids |> resize(int(HUWeaponSlots.EWS_NUM))
  var currentGunSlot = -1
  for slotId in range(int(HUWeaponSlots.EWS_NUM))
    destroyEntity(human_weap__gunEids[slotId])
    var gunMods = human_weap__gunMods[slotId] |> getRW_ecs_EidList()
    if gunMods != null
      for gunModEid in *gunMods
        destroyEntity(gunModEid)
      *gunMods |> clear()
    if currentGunSlot < 0
      currentGunSlot = slotId
    let weaponSlotName = get_human_weapon_slot_name(slotId)
    let weapTempl = human_weap__weapTemplates |> get_ecs_string(weaponSlotName)
    let weapTemplStr = weapTempl != null ? *weapTempl |> string() : ""
    
    
    var gunInitComps : Object? = null
    if slotId < length(human_weap__weapInitialComponents)
      gunInitComps = human_weap__weapInitialComponents[slotId] |> getRW_ecs_object()

    human_weap__gunEids[slotId] = create_gun_for_entity_impl(eid, weapTemplStr, gunInitComps) <| $(n : string;
                                                                                                   var ci : ComponentsInitializer)
      set(ci, "gun__initialSlotId", slotId)
      set(ci, "gun__initialFlags", flags)
      if is_dedicated()
        
        let newEid = createEntitySync(n, ci)
        
        
        
        
        return newEid
      else
        return createEntity(n, ci)

    if !human_weap__gunEids[slotId] && slotId == currentGunSlot
      currentGunSlot = -1
  return currentGunSlot


def setup_human_actor_weapon_slot(human_weap__gunEids : EidList;
                                  human_weap__currentGunSlot : int;
                                  var human_net_phys : HumanActor)
  if !human_weap__gunEids[int(human_net_phys.phys.producedCT.chosenWeapon)]
    if human_weap__currentGunSlot >= 0
      human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(human_weap__currentGunSlot))
      human_net_phys.phys.currentState.weapEquipState.curSlot = HUWeaponSlots(human_weap__currentGunSlot)


[es(tag=server, REQUIRE=(unit__ref, human))]
def human_weap_modifications_init_es(evt : CmdInitComponent;
                                     ownedByPlr : EntityId;
                                     unit__ref : UnitRef;
                                     var human_weap__weapInfo : Array&;
                                     var inventory__itemCreateTemplates : Object)
  let player = player_get_by_eid(ownedByPlr)
  if player == null
    return

  let weaponMods = "weapon"
  let equipmentMods = "equipment_common"

  let mods : DataBlock& = get_modifications_blk()
  let allMods = datablock_get_block_by_name(mods, "modifications")
  let modsNum = getModCount(*unit__ref.unit.unitMod)
  for i in range(0, modsNum)
    let modName = getModName(*unit__ref.unit.unitMod, i)
    let modBlock = datablock_get_block_by_name(*allMods, modName)
    if modBlock != null
      let modClassName = datablock_getStr(*modBlock, "modClass", "")
      if modClassName != weaponMods && modClassName != equipmentMods
        continue
      let effectsBlock = datablock_get_block_by_name(*modBlock, "effects")
      if effectsBlock != null
        let weapInfoIndex = datablock_getInt(*effectsBlock, "weapInfoIndex", 0)
        let ecsTemplateName = datablock_getStr(*effectsBlock, "ecsGunModTemplate", "")
        let ecsTemplate = getTemplateByName(ecsTemplateName)
        if ecsTemplateName != "" && ecsTemplate != null
          let attachableSlotName = getTemplateComponent(*ecsTemplate, "gunAttachable__gunSlotName") ?? ""
          if attachableSlotName != ""
            var weapInfoInSlot = getRW_ecs_object(human_weap__weapInfo[weapInfoIndex])
            var gunMods = weapInfoInSlot |> getRW_ecs_object("gunMods")
            if gunMods == null
              using() <| $(var emptyGunMods : Object)
                *weapInfoInSlot |> set("gunMods", emptyGunMods)
              gunMods = weapInfoInSlot |> getRW_ecs_object("gunMods")
            *gunMods |> set(attachableSlotName, ecsTemplateName)

        let inventoryItemNum = datablock_getInt(*effectsBlock, "ecsItemTemplateNum", 0)
        let itemTemplateName = datablock_getStr(*effectsBlock, "ecsItemTemplate", "")
        if inventoryItemNum > 0 && itemTemplateName != "" && getTemplateByName(itemTemplateName) != null
          let count = get_int(inventory__itemCreateTemplates, itemTemplateName) ?? 0
          set(inventory__itemCreateTemplates, itemTemplateName, count + inventoryItemNum)

        let inventoryItemToRemove = datablock_getStr(*effectsBlock, "ecsItemTemplateRemove", "")
        erase(inventory__itemCreateTemplates, inventoryItemToRemove)


[es(tag=server, REQUIRE=(unit__ref, human))]
def human_init_weapon_from_modification_es(evt : CmdInitComponent;
                                           ownedByPlr : EntityId;
                                           unit__ref : UnitRef;
                                           unit_crew__customizableSlots : IntList;
                                           var human_weap__weapTemplates : Object;
                                           var inventory__itemCreateTemplates : Object)
  let player = player_get_by_eid(ownedByPlr)
  if player == null
    return

  let checkingModClass = "equipment_common"
  let mods : DataBlock& = get_modifications_blk()
  let allMods = datablock_get_block_by_name(mods, "modifications")
  let modsNum = getModCount(*unit__ref.unit.unitMod)
  for i in range(0, modsNum)
    let modName = getModName(*unit__ref.unit.unitMod, i)
    let modBlock = datablock_get_block_by_name(*allMods, modName)
    if modBlock != null
      let modClassName = datablock_getStr(*modBlock, "modClass", "")
      if modClassName != checkingModClass
        continue
      let effectsBlock = datablock_get_block_by_name(*modBlock, "effects")
      if effectsBlock == null
        continue
      let ecsTemplateName = datablock_getStr(*effectsBlock, "ecsEquipTemplate", "")
      let ecsEquipTemplateSlot = datablock_getInt(*effectsBlock, "ecsEquipTemplateSlot", -1)
      if ecsTemplateName == "" || find_index(unit_crew__customizableSlots, ecsEquipTemplateSlot) < 0
        continue

      let itemTemplateName = datablock_getStr(*effectsBlock, "ecsItemTemplate", "")
      let inventoryItemNum = datablock_getInt(*effectsBlock, "ecsItemTemplateNum", 0)

      if inventoryItemNum > 0 && itemTemplateName != ""
        set(human_weap__weapTemplates, get_human_weapon_slot_name(ecsEquipTemplateSlot), ecsTemplateName)
        set(inventory__itemCreateTemplates, itemTemplateName, inventoryItemNum)


[es(tag=server, REQUIRE=(unit__ref, human))]
def human_init_weapon_preset_es(evt : CmdInitComponent;
                                eid : EntityId;
                                ownedByPlr : EntityId;
                                unit_crew__customizableSlots : IntList;
                                unit_crew__canBeLeader : bool = false;
                                var unit__ref : UnitRef;
                                var human_weap__weapTemplates : Object;
                                var inventory__itemCreateTemplates : Object)
  let player = player_get_by_eid(ownedByPlr)
  if player == null
    return

  var isBotPlayer = false
  query(ownedByPlr) <| $ [es(REQUIRE=playerIsBot)] ()
    isBotPlayer = true

  var crewMemberIdx = player_find_crew_member_idx(*player, eid)
  if crewMemberIdx < 0
    crewMemberIdx = unit_crew__canBeLeader ? 0 : -1

  var slotsWeapons : table<uint; string>

  let presetNameFromUi = string(evt.data.weaponPresetName)
  if presetNameFromUi == ""
    return

  let weaponPresetsBlk = datablock_get_block_by_name(evt.data.modelBlk, "weapon_presets")
  let weaponSlotsBlk = datablock_get_block_by_name(evt.data.modelBlk, "WeaponSlots")
  if weaponPresetsBlk == null || weaponSlotsBlk == null
    logerr("no weapon_presets or WeaponSlots for soldier {eid} ({getEntityTemplateName(eid)}) of a player {ownedByPlr}")
    return

  var chosenPresetBlk = ""
  for preset_i in 0u..weaponPresetsBlk.blockCount
    let preset = datablock_get_block(*weaponPresetsBlk, preset_i)
    let presetName = datablock_getStr(*preset, "name", "")
    if presetName == presetNameFromUi
      chosenPresetBlk = datablock_getStr(*preset, "blk", "")
      break

  if chosenPresetBlk == ""
    logerr("preset {presetNameFromUi} wasn't found in weaponPresets for soldier {eid} ({getEntityTemplateName(eid)}) of player {ownedByPlr}")
    return

  print("spawning soldier {eid} ({getEntityTemplateName(eid)}) with preset {chosenPresetBlk}")

  using() <| $(var chosenPreset : DataBlock)
    if !datablock_load(chosenPreset, chosenPresetBlk)
      return

    for soldier_i in 0u..chosenPreset.blockCount
      let soldierBlock = datablock_get_block(chosenPreset, soldier_i)
      let soldierInd = datablock_getInt(*soldierBlock, "index", -1)
      if soldierInd == crewMemberIdx
        for slot_i in 0u..soldierBlock.blockCount
          datablock_get_block(*soldierBlock, slot_i) <| $(slotBlk)
            let slot = datablock_getInt(slotBlk, "slot", -1)
            let preset = clone_string(datablock_getStr(slotBlk, "preset", ""))
            if slot >= 0 && preset != ""
              if find_index(unit_crew__customizableSlots, slot) >= 0
                slotsWeapons.insert(uint(slot), preset)
              else
                logerr("It is possible to customize weapons only in the following slots: {unit_crew__customizableSlots}, not in {slot} for soldier {eid} ({getEntityTemplateName(eid)})")

  for slotInd, weaponName in keys(slotsWeapons), values(slotsWeapons)
    for weaponSlot_i in 0u..weaponSlotsBlk.blockCount
      let weaponSlotBlock = datablock_get_block(*weaponSlotsBlk, weaponSlot_i)
      let weaponSlotIndex = datablock_getInt(*weaponSlotBlock, "index", -1)
      if weaponSlotIndex == int(slotInd)
        for weaponSlotWeapon_i in 0u..weaponSlotBlock.blockCount
          datablock_get_block(*weaponSlotBlock, weaponSlotWeapon_i) <| $(weaponBlk)
            let presetName = datablock_getStr(weaponBlk, "name", "")
            if presetName == weaponName
              let reqModification = datablock_getStr(weaponBlk, "reqModification", "")
              if !isBotPlayer && reqModification != "" && !hasMod(*unit__ref.unit.unitMod, reqModification)
                print("soldier {eid} ({getEntityTemplateName(eid)}) of a player {ownedByPlr} doesn't have {reqModification} modification")
                return

              let ecsWeaponTemplate = datablock_getStr(weaponBlk, "ecsTemplate", "")
              let inventoryItemTemplate = datablock_getStr(weaponBlk, "inventoryItemEcsTemplate", "")
              let inventoryItemNum = datablock_getInt(weaponBlk, "inventoryItemNum", 0)
              if ecsWeaponTemplate != "" && getTemplateByName(ecsWeaponTemplate) != null
                set(human_weap__weapTemplates, get_human_weapon_slot_name(int(slotInd)), ecsWeaponTemplate)

              if inventoryItemNum > 0 && inventoryItemTemplate != "" && getTemplateByName(inventoryItemTemplate) != null
                set(inventory__itemCreateTemplates, inventoryItemTemplate, inventoryItemNum)


[es(tag=server, on_appear, after=unit_init_completed_es, REQUIRE=inventory_created)]
def human_weap_created_server_es(evt : Event;
                                 eid : EntityId;
                                 human_weap__weapTemplates : Object;
                                 var human_weap__gunEids : EidList;
                                 var human_weap__gunMods : Array;
                                 var human_weap__weapInitialComponents : Array;
                                 var human_weap__currentGunSlot : int&;
                                 var human_net_phys : HumanActor?)
  human_weap__currentGunSlot = server_recreate_guns(eid, human_weap__weapTemplates,
                                                    int(RecreateGunsFlags.Attach) | int(RecreateGunsFlags.ParentLoaded),
                                                    human_weap__gunEids, human_weap__gunMods, human_weap__weapInitialComponents)

  if human_net_phys != null
    setup_human_actor_weapon_slot(human_weap__gunEids, human_weap__currentGunSlot, *human_net_phys)


[es(tag=server, on_appear, before=gun_init_es)]
def gun_init_ammo_prop_ids(evt : Event;
                           eid : EntityId;
                           gun__ammoHolders : Array;
                           var gun__ammoHolderIds : IntList)
  for ammoHolder in gun__ammoHolders
    let ammoHolderName = ammoHolder ?? ""
    if ammoHolderName == ""
      logerr("Unacceptable to have empty \"ammoHolder\" in template <{getEntityTemplateName(eid)}>")
    gun__ammoHolderIds |> push(int(ecs_hash(ammoHolderName)))


[es(on_appear, track=(gun__ammoHolderEid, gun__ammoHolderIds))]
def gun_track_cur_ammo_type(evt : Event;
                            gun__ammoHolderIds : IntList;
                            gun__ammoHolderEid : EntityId;
                            var gun__curAmmoHolderIndex : int&;
                            var gun__maxAmmo : int&)
  gun__curAmmoHolderIndex = -1
  query(gun__ammoHolderEid) <| $ [es] (ammo_holder__id : int;
                                       ammo_holder__ammoCount : int)
    gun__curAmmoHolderIndex = find_index(gun__ammoHolderIds, ammo_holder__id)
    gun__maxAmmo = ammo_holder__ammoCount


[es(tag=server, on_appear, REQUIRE=gun__createLoaded)]
def load_gun_on_create(evt : Event;
                       gun__ammoHolders : Array;
                       var customProps : Object&)
  for ammoHolder in gun__ammoHolders
    let ammoHolderName = ammoHolder ?? ""
    if ammoHolderName != ""
      let templ = getTemplateByName(ammoHolderName)
      if templ != null
        customProps |> set("ammoCount", getTemplateComponent(*templ, "ammo_holder__ammoCount") ?? 0)
        return


[es(tag=netClient, on_appear)]
def human_weap_created_client_es(evt : Event;
                                 eid : EntityId;
                                 human_weap__gunEids : EidList;
                                 human_weap__currentGunSlot : int;
                                 var human_net_phys : HumanActor?)
  if human_net_phys != null
    setup_human_actor_weapon_slot(human_weap__gunEids, human_weap__currentGunSlot, *human_net_phys)
  for i in range(int(HUWeaponSlots EWS_NUM))
    if human_weap__gunEids[i] != INVALID_ENTITY_ID
      let attach = (human_weap__currentGunSlot == i)
      add_delayed_action_client_wait_for_gun_creation(eid, human_weap__gunEids[i], attach, i)


[es(tag=netClient)]
def clear_client_pending_gun_creation_waits_es(evt : EventEntityManagerBeforeClear)
  remove_delayed_actions_client_wait_for_gun_creation()



[es(tag=netClient, REQUIRE_NOT=phys_obj_net_phys, on_appear)]
def replace_local_projectile_es(evt : Event;
                                eid : EntityId;
                                shell__owner : EntityId;
                                var animchar_attach__attachedTo aka server_animchar_attach__attachedTo : EntityId&;
                                var slot_attach__slotId aka server_slot_attach__slotId : int&;
                                var gun__visible aka server_gun__visible : bool&)
  
  

  
  query(shell__owner) <| $ [es] (var human_weap__localProjectileEid : EntityId&)
    let serverProjectileEid = eid

    
    
    if human_weap__localProjectileEid == INVALID_ENTITY_ID || serverProjectileEid == human_weap__localProjectileEid
      return
    

    
    
    query(human_weap__localProjectileEid) <| $ [es] (animchar_attach__attachedTo aka local_animchar_attach__attachedTo : EntityId)
      server_animchar_attach__attachedTo = local_animchar_attach__attachedTo

    query(human_weap__localProjectileEid) <| $ [es] (slot_attach__slotId aka local_slot_attach__slotId : int)
      server_slot_attach__slotId = local_slot_attach__slotId

    query(human_weap__localProjectileEid) <| $ [es] (gun__visible aka local_gun__visible : bool)
      server_gun__visible = local_gun__visible

    
    destroyEntity(human_weap__localProjectileEid)
    human_weap__localProjectileEid = INVALID_ENTITY_ID


[es(tag=netClient, on_disappear)]
def destroy_local_projectile_es(evt : Event;
                                var human_weap__localProjectileEid : EntityId&)
  
  destroyEntity(human_weap__localProjectileEid)
  human_weap__localProjectileEid = INVALID_ENTITY_ID















[es(REQUIRE=human_weap, REQUIRE_NOT=controlledHero)]
def human_weap_post_phys_es(evt : CmdPostPhysUpdate;
                            eid : EntityId;
                            transform : float3x4;
                            isInVehicle : bool = false;
                            human_vehicle__isHoldingGunPassenger : bool = false;
                            human_weap__currentGunEid : EntityId;
                            human_weap__grenadeThrower : EntityId = INVALID_ENTITY_ID;
                            human_weap__lockedGrenadeThrowingCounter : int = 0;
                            human_weap__jumpDeviation : float = 0.;
                            human_weap__changePosDeviationCanAim : float = 0.;
                            human_weap__changePosDeviationCanNotAim : float = 0.;
                            human_phys__afterJumpDelay : float = 0.;
                            human_phys__jumpEndTime : float;
                            human_phys__isInAirLong : bool;
                            entity_mods__shotDeviationMult : float = 1.0;
                            entity_mods__rotationShotSpreadDecrMult : float = 1.0;
                            entity_mods__aimingAfterFireMult : float = 1.0;
                            entity_mods__boltActionMult : float = 1.0;
                            entity_mods__deviationBufferSizeMult : float = 1.0;
                            grenade_rethrow__grenadeEid : EntityId const? = null;
                            entity_mods__shotDeviationAdd : float = 0.0;
                            human_weap__fastThrowExclusive : bool = true;
                            human_unarmed__active : bool = false;
                            isAlive : bool = true;
                            isDowned : bool = false;
                            bipod__enabled : bool = false;
                            human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                            var human_net_phys : HumanActor;
                            var human_weap__gunEids : EidList;
                            var human_weap__throwMode : bool&)
  if isAlive && !isDowned
    let tick = evt.tick
    let dt = evt.dt
    let isForReal = evt.isForReal
    let atTime = float(tick) * dt
    let gunDir = human_net_phys.phys.currentState.gunDir
    let physTransform = human_net_phys.phys.currentState.location |> location_makeTM()

    let updCtx = GunUpdateCtx(
      dt = dt,
      atTime = atTime,
      isForReal = isForReal,
      eid = eid,
      isDowned = isDowned,
      isThrowingAllowed = human_weap__lockedGrenadeThrowingCounter == 0 && (human_vehicle__isHoldingGunPassenger || !isInVehicle),
      shotDeviationMult = entity_mods__shotDeviationMult,
      rotationShotSpreadDecrMult = entity_mods__rotationShotSpreadDecrMult,
      aimingAfterFireMult = entity_mods__aimingAfterFireMult,
      boltActionMult = entity_mods__boltActionMult,
      shotDeviationAdd = entity_mods__shotDeviationAdd,
      fastThrowExclusive = human_weap__fastThrowExclusive,
      deviationBufferSizeMult = entity_mods__deviationBufferSizeMult)

    human_weap_gun_update(human_net_phys, human_weap__gunEids, human_weap__throwMode,
                          updCtx,  transform, gunDir, gunDir, physTransform,
                          human_net_phys.phys.appliedCT, grenade_rethrow__grenadeEid,
                          human_unarmed__active, human_attached_gun__attachedGunEid, human_weap__currentGunEid,
                          human_weap__jumpDeviation, human_weap__changePosDeviationCanAim, human_weap__changePosDeviationCanNotAim,
                          human_weap__grenadeThrower, human_phys__jumpEndTime, human_phys__afterJumpDelay, human_phys__isInAirLong, bipod__enabled)


def determine_current_slot(cur_time : float;
                           human_net_phys : HumanActor;
                           human_inventory__entityToUse : EntityId;
                           isDowned : bool;
                           human_sec_anim__hideWeapon : bool;
                           human_sec_anim__hideMelee : bool;
                           human_sec_anim__play : bool;
                           human_unarmed__hiddenWeapon : bool;
                           action__running : bool;
                           burning__isPuttingOut : bool;
                           human_weap__radioMode : bool = false;
                           human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  var curSlot = int(determine_current_weapon_slot(cur_time, human_net_phys))
  let attachedToGun = (human_attached_gun__attachedGunEid != INVALID_ENTITY_ID)
  let isHealing = (human_inventory__entityToUse != INVALID_ENTITY_ID &&
                  has(human_inventory__entityToUse, "item__healAnimEnumValue"))
  if ((!action__running && (human_net_phys.phys.currentState |> human_phys_state_get_is_swimming))
      || attachedToGun || isHealing || burning__isPuttingOut || isDowned || human_unarmed__hiddenWeapon
      || human_net_phys.phys.currentState |> human_phys_state_attachedToLadder)
    curSlot = -1
  if human_sec_anim__play && (human_sec_anim__hideWeapon || (human_sec_anim__hideMelee && curSlot == int(HUWeaponSlots.EWS_MELEE)))
    curSlot = -1
  if human_weap__radioMode
    curSlot = -1
  return curSlot


def has_any_attached_gun(human_weap__gunEids : EidList)
  for gunEid in human_weap__gunEids
    if get_bool(gunEid, "human_gun_attached") ?? false
      return true
  return false


def set_current_gun(eid : EntityId;
                    human_weap__gunEids : EidList;
                    cur_gun : int;
                    var human_weap__currentGunSlot : int&;
                    var human_weap__previousGunSlot : int&)
  human_weap__previousGunSlot = human_weap__currentGunSlot
  if human_weap__currentGunSlot == cur_gun
    return

  human_weap__currentGunSlot = cur_gun
  for i in iter_range(human_weap__gunEids)
    let isAttached = (i == cur_gun)
    sendEvent(human_weap__gunEids[i], CmdWeapAttach(toEid = eid, isAttached = isAttached, slotId = i))

  sendEvent(eid, EventOnSelectWeap(curr_gun_slot_id = human_weap__currentGunSlot))


def send_attach_event_to_current_gun(eid : EntityId;
                                     human_weap__gunEids : EidList;
                                     human_weap__currentGunSlot : int)
  if human_weap__currentGunSlot < 0 || human_weap__currentGunSlot >= length(human_weap__gunEids)
    return
  let gunEid = human_weap__gunEids[human_weap__currentGunSlot]
  if !(get_bool(gunEid, "human_gun_attached") ?? true)
    sendEvent(gunEid, CmdWeapAttach(toEid = eid, isAttached = true, slotId = human_weap__currentGunSlot))


def human_weap_es_impl(var human_weap__currentGunSlot : int&;
                       var human_weap__previousGunSlot : int&;
                       cur_time : float;
                       eid : EntityId;
                       human_weap__gunEids : EidList;
                       human_net_phys : HumanActor;
                       human_inventory__entityToUse : EntityId;
                       action__running : bool;
                       isInVehicle : bool;
                       isInVehicleHidden : bool;
                       isDowned : bool;
                       human_vehicle__isHoldingGunPassenger : bool;
                       human_sec_anim__hideWeapon : bool;
                       human_sec_anim__hideMelee : bool;
                       human_sec_anim__play : bool;
                       human_unarmed__hiddenWeapon : bool;
                       burning__isPuttingOut : bool;
                       human_weap__radioMode : bool = false;
                       human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  let curSlot = determine_current_slot(cur_time, human_net_phys, human_inventory__entityToUse,
    isDowned, human_sec_anim__hideWeapon, human_sec_anim__hideMelee,
    human_sec_anim__play, human_unarmed__hiddenWeapon, action__running, burning__isPuttingOut,
    human_weap__radioMode, human_attached_gun__attachedGunEid)

  let animSlot = isInVehicle && !isInVehicleHidden && !human_vehicle__isHoldingGunPassenger && !action__running ? -1 : curSlot

  if human_weap__currentGunSlot != curSlot || (animSlot < 0 && has_any_attached_gun(human_weap__gunEids))
    set_current_gun(eid, human_weap__gunEids, animSlot, human_weap__currentGunSlot, human_weap__previousGunSlot)
  human_weap__currentGunSlot = curSlot

  if !isDowned
    send_attach_event_to_current_gun(eid, human_weap__gunEids, animSlot)


[es(tag=server, before=human_weap_post_phys_es)]
def human_weap_es(evt : CmdPostPhysUpdate;
                  eid : EntityId;
                  human_weap__gunEids : EidList;
                  human_net_phys : HumanActor;
                  human_inventory__entityToUse : EntityId;
                  action__running : bool = false;
                  isInVehicle : bool = false;
                  isInVehicleHidden : bool = false;
                  isDowned : bool = false;
                  human_vehicle__isHoldingGunPassenger : bool = false;
                  human_sec_anim__hideWeapon : bool = false;
                  human_sec_anim__hideMelee : bool = false;
                  human_sec_anim__play : bool = false;
                  human_unarmed__hiddenWeapon : bool = false;
                  burning__isPuttingOut : bool = false;
                  human_weap__radioMode : bool = false;
                  isAlive : bool;
                  human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                  var human_weap__currentGunSlot : int&;
                  var human_weap__previousGunSlot : int&)
  if isAlive
    human_weap_es_impl(
      human_weap__currentGunSlot, human_weap__previousGunSlot, get_sync_time(), eid, human_weap__gunEids,
      human_net_phys, human_inventory__entityToUse, action__running,
      isInVehicle, isInVehicleHidden, isDowned, human_vehicle__isHoldingGunPassenger,
      human_sec_anim__hideWeapon, human_sec_anim__hideMelee,
      human_sec_anim__play, human_unarmed__hiddenWeapon, burning__isPuttingOut,
      human_weap__radioMode, human_attached_gun__attachedGunEid)


[es(tag=netClient, after=(before_human_inventory_use_update))]
def human_weap_client_es(info : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         human_weap__gunEids : EidList;
                         human_net_phys : HumanActor;
                         human_inventory__entityToUse : EntityId;
                         action__running : bool = false;
                         isInVehicle : bool = false;
                         isInVehicleHidden : bool = false;
                         isDowned : bool = false;
                         human_vehicle__isHoldingGunPassenger : bool = false;
                         human_sec_anim__hideWeapon : bool = false;
                         human_sec_anim__hideMelee : bool = false;
                         human_sec_anim__play : bool = false;
                         human_unarmed__hiddenWeapon : bool = false;
                         burning__isPuttingOut : bool = false;
                         human_weap__radioMode : bool = false;
                         isAlive : bool;
                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                         var human_weap__currentGunSlot : int&;
                         var human_weap__previousGunSlot : int&)
  if isAlive
    human_weap_es_impl(
      human_weap__currentGunSlot, human_weap__previousGunSlot, info.curTime, eid, human_weap__gunEids,
      human_net_phys, human_inventory__entityToUse, action__running,
      isInVehicle, isInVehicleHidden, isDowned, human_vehicle__isHoldingGunPassenger,
      human_sec_anim__hideWeapon, human_sec_anim__hideMelee,
      human_sec_anim__play, human_unarmed__hiddenWeapon, burning__isPuttingOut,
      human_weap__radioMode, human_attached_gun__attachedGunEid)


































































































[es(tag=server)]
def human_weap_req_switch_firing_mode_es(evt : HumanWeapRequestSwitchFiringMode;
                                         human_weap__gunEids : EidList)
  let slotId = int(evt.slotId)
  let modeId = int(evt.modeId)
  if slotId >= length(human_weap__gunEids)
    return

  query(human_weap__gunEids[slotId]) <| $ [es] (var gun : Gun; var gun__firingModeIndex : int&)
    if gun |> gun_checkFiringModeIndex(modeId)
      gun |> gun_setFiringModeIndex(evt.modeId)
      gun__firingModeIndex = modeId











[es]
def human_weap_set_current_gun_es(evt : HumanWeapSetCurrentGun;
                                  var human_net_phys : HumanActor)
  human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(int(evt.slot)))
  human_net_phys.phys.currentState.weapEquipState.curSlot = HUWeaponSlots(int(evt.slot))











def update_total_ammo(gun_eid : EntityId;
                      itemContainer : EidList)
  query(gun_eid) <| $ [es(REQUIRE=gun)] (gun__wishAmmoItemType : int;
                                         var gun__totalAmmo : int&)
    gun__totalAmmo = get_total_ammo_count(itemContainer, gun__wishAmmoItemType, gun_eid)


[es(tag=server, track=(human_weap__gunEids, itemContainer))]
def human_weap_update_total_count_es(evt : Event;
                                     human_weap__gunEids : EidList;
                                     human_weap__gunMods : Array;
                                     itemContainer : EidList)
  for i in iter_range(human_weap__gunEids)
    update_total_ammo(human_weap__gunEids[i], itemContainer)
  for i in iter_range(human_weap__gunMods)
    let gunMods = get_ecs_EidList(human_weap__gunMods[i])
    if gunMods != null
      for gunModEid in *gunMods
        update_total_ammo(gunModEid, itemContainer)


[es(tag=server, track=(human_weap__gunEids, itemContainer))]
def human_weap_update_additional_ammo_count_es(evt : Event;
                                               human_weap__gunEids : EidList;
                                               itemContainer : EidList)
  for i in iter_range(human_weap__gunEids)
    let gunEid = human_weap__gunEids[i]
    query(gunEid) <| $ [es] (gun__isDualMagReady : bool;
                             var gun__additionalAmmo : int&)
      if gun__isDualMagReady
        find_ammo_for_gun(gunEid, itemContainer, INVALID_ITEM_ID, 0) <| $(ammoForGun : AmmoItemForGunResult)
          gun__additionalAmmo = ammoForGun.ammoCount


[es(tag=server, on_appear, track=(gun__isDualMagReady, gun__owner))]
def gun_update_additional_ammo_count_es(evt : Event;
                                        eid : EntityId;
                                        gun__owner : EntityId;
                                        gun__isDualMagReady : bool;
                                        var gun__additionalAmmo : int&)
  if !gun__isDualMagReady
    gun__additionalAmmo = 0
  else
    query(gun__owner) <| $ [es] (itemContainer : EidList)
      find_ammo_for_gun(eid, itemContainer, INVALID_ITEM_ID, 0) <| $(ammoForGun : AmmoItemForGunResult)
        gun__additionalAmmo = ammoForGun.ammoCount


[es(tag=server, track=gun__wishAmmoItemType)]
def human_weap_update_total_count_wish_ammo_item_type_es(evt : Event;
                                                         eid : EntityId;
                                                         gun__owner : EntityId;
                                                         gun__wishAmmoItemType : int;
                                                         var gun__totalAmmo : int&)
  query(gun__owner) <| $ [es] (itemContainer : EidList)
    gun__totalAmmo = get_total_ammo_count(itemContainer, gun__wishAmmoItemType, eid)


[es]
def human_weap_reinit_guns_es(evt : CmdReinitWeapons;
                              eid : EntityId;
                              human_weap__weapTemplates : Object;
                              var human_weap__currentGunSlot : int&;
                              var human_weap__gunEids : EidList;
                              var human_weap__gunMods : Array;
                              var human_weap__weapInitialComponents : Array)
  human_weap__currentGunSlot = server_recreate_guns(eid, human_weap__weapTemplates,
                                                    int(RecreateGunsFlags Attach),
                                                    human_weap__gunEids, human_weap__gunMods,
                                                    human_weap__weapInitialComponents)


[es(tag=server, on_appear)]
def reserve_ammo_props_init_es(evt : Event;
                               human_weap__weapInfo : Array;
                               var human_weap__reserveAmmoPropIds : IntList)
  let weapInfoSize = length(human_weap__weapInfo)
  human_weap__reserveAmmoPropIds |> resize(weapInfoSize)
  for i in range(weapInfoSize)
    let weapInfoSlot = get_ecs_object(human_weap__weapInfo[i])
    if weapInfoSlot != null
      let resvAmmoTypeName = weapInfoSlot |> get_string("reserveAmmoTemplate", "")
      human_weap__reserveAmmoPropIds[i] = resvAmmoTypeName != "" ? int(ecs_hash(resvAmmoTypeName)) : -1


[es(track=human_weap__mortarMode)]
def switch_to_mortar_mode_es(evt : Event;
                             human_weap__mortarMode : bool;
                             var human_weap__enableClampVertAimAngle : bool&)
  human_weap__enableClampVertAimAngle = !human_weap__mortarMode


[es(on_appear)]
def init_radio_slots_es(evt : Event;
                        radio__unequippedSlotName : string;
                        radio__equippedSlotName : string;
                        var radio__unequippedSlotId : int&;
                        var radio__equippedSlotId : int&)
  radio__unequippedSlotId = animchar_getSlotId(radio__unequippedSlotName)
  radio__equippedSlotId = animchar_getSlotId(radio__equippedSlotName)

[es(on_appear, track=human_weap__gunMods, REQUIRE=human_weap__gunMods)]
def calculate_weapon_params_with_attachable_mods_on_mods_change(evt : Event;
                                                                human_weap__gunEids : EidList)
  for gunEid in human_weap__gunEids
    calculate_weapon_params_with_attachable_mods(gunEid)

[es(on_appear, track=(slot_attach__weaponSlotIdx, animchar_attach__attachedTo), REQUIRE=(gun__modificatedParamNames, slot_attach__weaponSlotIdx, animchar_attach__attachedTo))]
def calculate_weapon_params_with_attachable_mods_on_weap_appear(evt : Event;
                                                                eid : EntityId)
  calculate_weapon_params_with_attachable_mods(eid)

[es(on_appear, track=animchar_attach__attachedTo, REQUIRE=animchar_attach__attachedTo)]
def calculate_weapon_params_with_attachable_mods_on_mods_appear(evt : Event;
                                                                animchar_attach__attachedTo : EntityId)
  calculate_weapon_params_with_attachable_mods(animchar_attach__attachedTo)


[es(tag=(server, net), REQUIRE=human_weap__gunEids)]
def human_weap_reload_net(evt : HumanRequestUnloadAmmo;
                          eid : EntityId)
  if evt.slotId >= 0
    unload_ammo_impl(eid, evt.slotId)

[es(tag=gameClient)]
def human_weap_on_net_shoot_es(evt : CmdNetUnitShot;
                               human_weap__gunEids : EidList)
  var gunFound = false
  for weapEid in human_weap__gunEids
    query(weapEid) <| $ [es] (gun__shell_prop_ids : PropsIdList)
      for curShellId in gun__shell_prop_ids
        if curShellId == evt.shellId
          gunFound = true
          var shootTm = IDENT_TM
          shootTm[3] = evt.pos
          sendEventImmediate(weapEid, CmdNetShot(shellId = int16(-1),
                                                 damageId = int16(-1),
                                                 ballisticsId = int16(-1),
                                                 gunPropsId = int16(-1),
                                                 atTime = get_sync_time(),
                                                 initialLifeTime = 0.,
                                                 tm = shootTm,
                                                 vel = evt.vel,
                                                 firingMode = uint(0),
                                                 bombBayHeight = 0.))
          break
    if gunFound
      return

[es(tag=server)]
def human_weap_set_last_shot_es(evt : CmdLaunchProjectile;
                                var human_weap__lastShotGunEid : EntityId&;
                                var human_weap__lastShotAtTime : float&)
  if (length_sq(evt.launchDesc.tm[3]) < 1e10)
    human_weap__lastShotAtTime = get_sync_time()
    human_weap__lastShotGunEid = evt.gunEid
