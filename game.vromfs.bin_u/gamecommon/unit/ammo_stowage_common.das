module ammo_stowage_common shared

require ecs
require dm
require app
require net
require BitStream
require BallisticsProps
require Unit
require UnitFx
require Weapon
require WTDamageModel
require DagorMath
require DagorDataBlock
require GeomNodeTree
require AmmoStowage
require DagorSystem
require %game.utils.component_bundle_macro
require %game.utils.utils_common
require %game.unit.ammo_stowage_events







struct public PartRemap
  partId : PartId = PartId()
  stowageId : int
  clusterId : int
  slotId : int

def public get_remap(remap : IPoint4List&; partId : PartId) : PartRemap
  let idx = int(partId.id)
  if idx < length(remap) && idx >= 0
    let r = remap[idx]
    if r.x >= 0
      return PartRemap(partId = partId, stowageId = r.y, clusterId = r.z, slotId = r.w)
  return PartRemap(partId = PartId(), stowageId = -1, clusterId = -1, slotId = -1)

def public add_remap(var remap : IPoint4List&; part : PartRemap) : bool
  assert(part.partId.valid)
  let idx = int(part.partId.id)
  if length(remap) <= idx
    let old_size = length(remap)
    remap |> resize(idx + 16)
    for i in range(old_size, length(remap))
      remap[i] = int4(-1)
  elif remap[idx].x != -1
    return false
  remap[idx] = int4(int(part.partId.id), part.stowageId, part.clusterId, part.slotId)
  return true







[with_bundle(v)]
def public get_ammo_cluster_type(cluster_id : int; v : tuple<ammo_clusters__typeAndStage : UInt16List>) : int
  return int(v.ammo_clusters__typeAndStage[cluster_id]) & 255

[with_bundle(v)]
def public get_ammo_cluster_stage(cluster_id : int; v : tuple<ammo_clusters__typeAndStage : UInt16List>) : int
  return int(v.ammo_clusters__typeAndStage[cluster_id]) >> 8

[with_bundle(v)]
def get_ammo_slot_type(slot_id : int;  v : tuple<ammo_slots__ammoMaskAndType : UInt32List>) : int
  return int(v.ammo_slots__ammoMaskAndType[slot_id] & 0xffu)

[with_bundle(v)]
def get_ammo_slot_class_mask(slot_id : int;  v : tuple<ammo_slots__ammoMaskAndType : UInt32List>) : uint
  return uint(v.ammo_slots__ammoMaskAndType[slot_id] >> 8u)







[with_bundle(v)]
def public ammo_slot_set_dm_enabled(var unit : Unit?; slot_id : int; is_enabled : bool; v : tuple<ammo_slots__partId : PartIdList>) : bool
  let slot_part_id = v.ammo_slots__partId[slot_id]
  assume dvm = *unit.visual
  if dvm |> dm_is_part_enabled(slot_part_id) != is_enabled
    dvm |> dm_set_part_enabled(slot_part_id, is_enabled)
    dvm |> dm_set_decor_by_part_id(int(slot_part_id.globalId), is_enabled)
    if is_enabled
      dvm |> dm_set_rel_hp(int(slot_part_id.globalId), 1.0f, false)
    return true
  return false

[with_bundle(v)]
def public ammo_slot_update_dm(var unit : Unit?; slot_id : int; v : tuple<ammo_slots__partId : PartIdList; ammo_slots__numAmmo : IPoint2List>) : bool
  return ammo_slot_set_dm_enabled(unit, slot_id, v.ammo_slots__numAmmo[slot_id].x > 0, v)

[with_bundle(v)]
def ammo_stowage_get_num_ammo_addable_to_slot(cluster_id : int; slot_id : int; num_ammo : int; ammo_type : int;
                                              v : tuple<
                                                ammo_clusters__state : UInt32List;
                                                ammo_slots__state : UInt32List;
                                                ammo_slots__ammoMaskAndType : UInt32List;
                                                ammo_slots__numAmmo : IPoint2List;
                                                ammo_stowage__ammoTypeToMask : UInt32List
                                                >) : int
  if !get_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ENABLED) && !get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.RESTORE_AFTER_DEAD)
    return 0
  let slot_ammo = v.ammo_slots__numAmmo[slot_id]
  if num_ammo == 0 || slot_ammo.x == slot_ammo.y
    return 0
  if get_ammo_slot_type(slot_id, v) != ammo_type
    if slot_ammo.x > 0
      return 0
    if (v.ammo_stowage__ammoTypeToMask[ammo_type] & get_ammo_slot_class_mask(slot_id, v)) == 0u
      return 0
  return min(slot_ammo.y - slot_ammo.x, num_ammo)

[with_bundle(v)]
def ammo_stowage_can_add_ammo_to_slot(cluster_id : int; slot_id : int; num_ammo : int; ammo_type : int;
                                      v : tuple<
                                        ammo_clusters__state : UInt32List;
                                        ammo_slots__state : UInt32List;
                                        ammo_slots__ammoMaskAndType : UInt32List;
                                        ammo_slots__numAmmo : IPoint2List;
                                        ammo_stowage__ammoTypeToMask : UInt32List
                                        >) : bool
  return ammo_stowage_get_num_ammo_addable_to_slot(cluster_id, slot_id, num_ammo, ammo_type, v) == num_ammo

[with_bundle(v)]
def ammo_stowage_add_ammo_to_slot_no_check(slot_id : int; num_ammo : int; ammo_type : int;
                                           var v : tuple<
                                             ammo_slots__state : UInt32List;
                                             ammo_slots__ammoMaskAndType : UInt32List;
                                             ammo_slots__numAmmo : IPoint2List
                                             >) : void
  if num_ammo == 0
    return
  var slot_ammo = v.ammo_slots__numAmmo[slot_id]
  v.ammo_slots__ammoMaskAndType[slot_id] = (v.ammo_slots__ammoMaskAndType[slot_id] & 0xffffff00u) | uint(ammo_type)
  slot_ammo.x = min(slot_ammo.x + num_ammo, slot_ammo.y)
  v.ammo_slots__numAmmo[slot_id] = slot_ammo
  if slot_ammo.x > 0
    set_flag(v.ammo_slots__state[slot_id], AmmoSlotState.ENABLED, true)

[with_bundle(v)]
def ammo_stowage_add_ammo_to_slot_partial(cluster_id : int; slot_id : int; var num_ammo : int&; ammo_type : int;
                                          var v : tuple<
                                            ammo_clusters__state : UInt32List const;
                                            ammo_slots__state : UInt32List;
                                            ammo_slots__ammoMaskAndType : UInt32List;
                                            ammo_slots__numAmmo : IPoint2List;
                                            ammo_stowage__ammoTypeToMask : UInt32List const
                                            >) : void
  let added_ammo = ammo_stowage_get_num_ammo_addable_to_slot(cluster_id, slot_id, num_ammo, ammo_type, v)
  if added_ammo > 0
    num_ammo -= added_ammo
    ammo_stowage_add_ammo_to_slot_no_check(slot_id, added_ammo, ammo_type, v)

[with_bundle(v)]
def ammo_stowage_extract_ammo_from_slot(slot_id : int; num_ammo : int;
                                        var v : tuple<
                                          ammo_slots__numAmmo : IPoint2List
                                          >) : bool
  var slot_ammo = v.ammo_slots__numAmmo[slot_id]
  if slot_ammo.x < num_ammo
    return false
  slot_ammo.x -= num_ammo
  v.ammo_slots__numAmmo[slot_id] = slot_ammo
  return true

[with_bundle(v)]
def ammo_stowage_try_swap_slots(slot_1_id : int; slot_2_id : int;
                                v : tuple<
                                  ammo_slots__state : UInt32List -const;
                                  ammo_slots__numAmmo : IPoint2List -const;
                                  ammo_slots__ammoMaskAndType : UInt32List -const;
                                  ammo_stowage__ammoTypeToMask : UInt32List
                                  >) : bool
  let ammo_count_1 = v.ammo_slots__numAmmo[slot_1_id]
  let ammo_count_2 = v.ammo_slots__numAmmo[slot_2_id]
  let ammo_type_1 = get_ammo_slot_type(slot_1_id, v)
  let ammo_type_2 = get_ammo_slot_type(slot_2_id, v)
  let ammo_mask_1 = get_ammo_slot_class_mask(slot_1_id, v)
  let ammo_mask_2 = get_ammo_slot_class_mask(slot_2_id, v)
  if ammo_count_1.x > ammo_count_2.y || ammo_count_2.x > ammo_count_1.y
    return false
  if ammo_count_1.x > 0 && (v.ammo_stowage__ammoTypeToMask[ammo_type_1] & ammo_mask_2) == 0u
    return false
  if ammo_count_2.x > 0 && (v.ammo_stowage__ammoTypeToMask[ammo_type_2] & ammo_mask_1) == 0u
    return false
  v.ammo_slots__ammoMaskAndType[slot_1_id] = uint(ammo_type_2) | (ammo_mask_1 << 8u)
  v.ammo_slots__ammoMaskAndType[slot_2_id] = uint(ammo_type_1) | (ammo_mask_2 << 8u)
  v.ammo_slots__numAmmo[slot_1_id].x = ammo_count_2.x
  v.ammo_slots__numAmmo[slot_2_id].x = ammo_count_1.x
  if ammo_count_1.x > 0
    set_flag(v.ammo_slots__state[slot_2_id], AmmoSlotState.ENABLED, true)
  if ammo_count_2.x > 0
    set_flag(v.ammo_slots__state[slot_1_id], AmmoSlotState.ENABLED, true)
  return true







[with_bundle(v)]
def ammo_cluster_balance_slots(var unit : Unit?; cluster_id : int; update_dm : bool;
                               v : tuple<
                                 ammo_stowage__ammoTypeToMask : UInt32List;
                                 ammo_clusters__slotsRange : IPoint2List;
                                 ammo_clusters__state : UInt32List;
                                 ammo_slots__state : UInt32List -const;
                                 ammo_slots__numAmmo : IPoint2List -const;
                                 ammo_slots__ammoMaskAndType : UInt32List -const;
                                 ammo_slots__partId : PartIdList
                                 >) : bool
  var dm_changed = false
  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  var to_slot_id = slots_range.x
  var from_slot_id = slots_range.y - 1
  while to_slot_id < from_slot_id
    if v.ammo_slots__numAmmo[to_slot_id].x != 0
      to_slot_id++
      continue
    let ammo_count = v.ammo_slots__numAmmo[from_slot_id].x
    if ammo_count == 0
      from_slot_id--
      continue
    let ammo_type = get_ammo_slot_type(from_slot_id, v)

    var search_slot_id = to_slot_id
    while search_slot_id < from_slot_id && !ammo_stowage_can_add_ammo_to_slot(cluster_id, search_slot_id, ammo_count, ammo_type, v)
      search_slot_id++
    if search_slot_id < from_slot_id
      ammo_stowage_extract_ammo_from_slot(from_slot_id, ammo_count, v)
      ammo_stowage_add_ammo_to_slot_no_check(search_slot_id, ammo_count, ammo_type, v)
      set_flag(v.ammo_slots__state[search_slot_id], AmmoSlotState.ENABLED, true)
      if update_dm
        ammo_slot_set_dm_enabled(unit, search_slot_id, true, v)
        ammo_slot_set_dm_enabled(unit, from_slot_id, false, v)
      dm_changed = true
    from_slot_id--
  return dm_changed







struct WeaponAndAmmoInfo
  stowage_id : int
  bullet_set_id : int
  ammo_type : int
  count : int
  max_count : int
  loaded_count : int
  max_loaded_count : int
  first_weapon_idx : int

def private ammo_stowage_iter_weapons_arr_impl(weap : WeaponController const?;
                                               weapons_arr : array<int>;
                                               separate_weapons : bool;
                                               separate_bullet_sets : bool;
                                               per_ammo_types_enabled : bool;
                                               stowage_id : int;
                                               var next_ammo_type : int&;
                                               fn : block<(info : WeaponAndAmmoInfo) : void>) : void
  if length(weapons_arr) == 0
    return
  var bullet_set_cnt = 1
  for weapon_i in weapons_arr
    var gun = get_weapon(weap.Weapons, weapon_i) |> as_gun()
    if gun != null
      bullet_set_cnt = max(length(gun.properties.bulletSets), bullet_set_cnt)

  var base_ammo_info = WeaponAndAmmoInfo(
    stowage_id = stowage_id,
    bullet_set_id = 0,
    first_weapon_idx = weapons_arr[0],
    ammo_type = 0,
    count = 0,
    max_count = 0,
    loaded_count = 0,
    max_loaded_count = 0
  )
  for bullet_set_id in 0..bullet_set_cnt
    
    var ammo_info := base_ammo_info
    ammo_info.count = 0
    ammo_info.max_count = 0
    ammo_info.loaded_count = 0
    ammo_info.max_loaded_count = 0
    for weapon_idx in weapons_arr
      if separate_weapons
        ammo_info.count = 0
        ammo_info.max_count = 0
        ammo_info.loaded_count = 0
        ammo_info.max_loaded_count = 0

      let weapon = get_weapon(weap.Weapons, weapon_idx)
      let gun = weapon |> as_gun()
      if gun != null
        let gun_props = gun.properties
        if length(gun_props.bulletSets) <= bullet_set_id
          continue
        assume bullet_set = gun_props.bulletSets[bullet_set_id]
        ammo_info.count += max(0, bullet_set.bulletsCount)
        ammo_info.max_count += max(0, bullet_set.initialBulletsCount)
        ammo_info.loaded_count += int(gun.chosenBulletType) == bullet_set_id ? int(gun.currentLoadedAmmoCount) : 0
        ammo_info.max_loaded_count += int(bullet_set.bulletsCartridge)
      else
        ammo_info.count += max(0, weapon.countBullets)
        ammo_info.max_count += max(0, weapon.fullBullets)
        ammo_info.loaded_count += weapon.countBullets > 0 ? 1 : 0
        ammo_info.max_loaded_count += 1

      if separate_weapons
        ammo_info.first_weapon_idx = weapon_idx
        ammo_info.bullet_set_id = bullet_set_id
        ammo_info.ammo_type = next_ammo_type
        fn |> invoke(ammo_info)

    if separate_bullet_sets && !separate_weapons
      ammo_info.bullet_set_id = bullet_set_id
      ammo_info.ammo_type = next_ammo_type
      fn |> invoke(ammo_info)
    if !separate_bullet_sets
      base_ammo_info.count += ammo_info.count
      base_ammo_info.max_count += ammo_info.max_count
      base_ammo_info.loaded_count += ammo_info.loaded_count
      base_ammo_info.max_loaded_count = max(ammo_info.max_loaded_count, base_ammo_info.max_loaded_count)

    if per_ammo_types_enabled
      next_ammo_type++

  if !separate_bullet_sets
    base_ammo_info.ammo_type = next_ammo_type
    fn |> invoke(base_ammo_info)
  if !per_ammo_types_enabled
    next_ammo_type++

[with_bundle(v)]
def private ammo_stowage_iter_weapons_and_bullet_sets_impl(weap : WeaponController const?;
                                                           separate_weapons : bool;
                                                           separate_bullet_sets : bool;
                                                           per_ammo_types_enabled : bool;
                                                           stowage_id : int;
                                                           var next_ammo_type : int&;
                                                           v : tuple<
                                                             ammo_stowages__weaponTriggersRange : IPoint2List;
                                                             ammo_stowage__weaponTriggers : IntList
                                                             >;
                                                           fn : block<(info : WeaponAndAmmoInfo) : void>) : void
  var weapons_arr : array<int>
  let triggers_range = v.ammo_stowages__weaponTriggersRange[stowage_id]
  for trigger_no_idx in triggers_range.x..triggers_range.y
    let trigger_no = v.ammo_stowage__weaponTriggers[trigger_no_idx]
    for weapon in weap.Weapons |> get_weapons_by_trigger(trigger_no)
      if weapon == null
        continue
      if length(weapons_arr) > 0 && per_ammo_types_enabled && !check_weapons_have_same_bullets(get_weapon(weap.Weapons, weapons_arr[0]), weapon)
        ammo_stowage_iter_weapons_arr_impl(
          weap,
          weapons_arr,
          separate_weapons,
          separate_bullet_sets,
          per_ammo_types_enabled,
          stowage_id,
          next_ammo_type,
          fn)
        weapons_arr |> clear()
      weapons_arr |> push(weapon.weaponIdx)
  if length(weapons_arr) > 0
    ammo_stowage_iter_weapons_arr_impl(
      weap,
      weapons_arr,
      separate_weapons,
      separate_bullet_sets,
      per_ammo_types_enabled,
      stowage_id,
      next_ammo_type,
      fn
    )

[with_bundle(v)]
def ammo_stowage_iter_all_ammo_types(weap : WeaponController const?;
                                     v : tuple<
                                       ammo_stowage__ammoState : uint;
                                       ammo_stowages__weaponTriggersRange : IPoint2List;
                                       ammo_stowage__weaponTriggers : IntList
                                       >;
                                     fn : block<(info : WeaponAndAmmoInfo) : void>) : void
  let per_ammo_types_enabled = get_flag(v.ammo_stowage__ammoState, AmmoState.ENABLE_PER_AMMO_TYPES)
  var next_ammo_type = 0
  for stowage_id in iter_range(v.ammo_stowages__weaponTriggersRange)
    ammo_stowage_iter_weapons_and_bullet_sets_impl(
      weap,
      false,                   
      per_ammo_types_enabled,  
      per_ammo_types_enabled,
      stowage_id,
      next_ammo_type,
      v,
      fn
    )

[with_bundle(v)]
def ammo_stowage_iter_all_weapons_and_bullet_sets(weap : WeaponController const?;
                                                  v : tuple<
                                                    ammo_stowage__ammoState : uint;
                                                    ammo_stowages__weaponTriggersRange : IPoint2List;
                                                    ammo_stowage__weaponTriggers : IntList
                                                    >;
                                                  fn : block<(info : WeaponAndAmmoInfo) : void>) : void
  let per_ammo_types_enabled = get_flag(v.ammo_stowage__ammoState, AmmoState.ENABLE_PER_AMMO_TYPES)
  var next_ammo_type = 0
  for stowage_id in iter_range(v.ammo_stowages__weaponTriggersRange)
    ammo_stowage_iter_weapons_and_bullet_sets_impl(
      weap,
      true, 
      true, 
      per_ammo_types_enabled,
      stowage_id,
      next_ammo_type,
      v,
      fn
    )

[with_bundle(v)]
def ammo_stowage_iter_all_stowages_and_bullets(weap : WeaponController const?;
                                               v : tuple<
                                                 ammo_stowage__ammoState : uint;
                                                 ammo_stowages__weaponTriggersRange : IPoint2List;
                                                 ammo_stowage__weaponTriggers : IntList
                                                 >;
                                               fn : block<(stowage_id : int; info_arr : array<WeaponAndAmmoInfo>) : void>) : void
  let per_ammo_types_enabled = get_flag(v.ammo_stowage__ammoState, AmmoState.ENABLE_PER_AMMO_TYPES)
  var next_ammo_type = 0
  var info_arr : array<WeaponAndAmmoInfo>
  info_arr |> reserve(8)
  for stowage_id in iter_range(v.ammo_stowages__weaponTriggersRange)
    info_arr |> clear()
    ammo_stowage_iter_weapons_and_bullet_sets_impl(
      weap,
      false,                  
      per_ammo_types_enabled, 
      per_ammo_types_enabled,
      stowage_id,
      next_ammo_type,
      v
    ) <| $(info)
      info_arr |> push(info)
    fn |> invoke(stowage_id, info_arr)


struct AmmoPropsInfo
  ballisticsProps : ProjBallisticsProperties const?
  explosiveProps : ExplosiveProps const?
  kineticMass : float
  powderPortion : float
  splashDamageTypeId : int
  shatterDamageTypeId : int

def private fill_ammo_props_info(props) : AmmoPropsInfo
  return AmmoPropsInfo(
    ballisticsProps = get_proj_ballistics(props),
    explosiveProps = get_explosive_props(props),
    kineticMass = get_kinetic_mass(props),
    powderPortion = get_powder_portion(props),
    splashDamageTypeId = get_splash_damage_type(props),
    shatterDamageTypeId = get_shatter_damage_type(props)
  )

[with_bundle(v)]
def ammo_stowage_iter_all_ammo_props(weap : WeaponController const?; ammo_type : int;
                                     v : tuple<
                                       ammo_stowage__ammoState : uint;
                                       ammo_stowage__ammoTypeRemap : IPoint4List;
                                       ammo_stowage__weaponsIds : IntList
                                       >;
                                     fn : block<(props : AmmoPropsInfo; fraction : float) : void>) : void
  let iter_all_bullet_sets = !get_flag(v.ammo_stowage__ammoState, AmmoState.ENABLE_PER_AMMO_TYPES)
  let ammo_type_remap = v.ammo_stowage__ammoTypeRemap[ammo_type]

  
  var total_cnt = 0
  for weapon_i in ammo_type_remap.y..ammo_type_remap.z
    let weapon = weap.Weapons |> get_weapon(v.ammo_stowage__weaponsIds[weapon_i])
    let gun = as_gun(weapon)
    let base_gun = as_base_gun(weapon)
    if gun != null
      let bs_range = iter_all_bullet_sets ? int2(0, length(gun.properties.bulletSets)) : int2(ammo_type_remap.w, ammo_type_remap.w + 1)
      for bs_i in bs_range.x..bs_range.y
        total_cnt += gun.properties.bulletSets[bs_i].bulletsCount
    elif base_gun != null
      total_cnt += base_gun.countBullets

  
  for weapon_i in ammo_type_remap.y..ammo_type_remap.z
    let weapon = weap.Weapons |> get_weapon(v.ammo_stowage__weaponsIds[weapon_i])
    let gun = as_gun(weapon)
    let base_gun = as_base_gun(weapon)
    if gun != null
      let bs_range = iter_all_bullet_sets ? int2(0, length(gun.properties.bulletSets)) : int2(ammo_type_remap.w, ammo_type_remap.w + 1)
      for bs_i in bs_range.x..bs_range.y
        assume bullet_set = gun.properties.bulletSets[bs_i]
        let fraction = safediv(float(bullet_set.bulletsCount), float(total_cnt * length(bullet_set.bullet)))
        for props in bullet_set.bullet
          fn |> invoke(fill_ammo_props_info(*props), fraction)
    elif base_gun != null
      let fraction = safediv(float(base_gun.countBullets), float(total_cnt))
      fn |> invoke(fill_ammo_props_info(*base_gun.prop.shellProps), fraction)

[with_bundle(v)]
def ammo_stowage_subtract_weapon_ammo(weap : WeaponController const?; ammo_type : int; initial_count : bool; subtract : int;
                                      v : tuple<
                                        ammo_stowage__ammoState : uint;
                                        ammo_stowage__ammoTypeRemap : IPoint4List;
                                        ammo_stowage__weaponsIds : IntList
                                        >) : void
  let iter_all_bullet_sets = !get_flag(v.ammo_stowage__ammoState, AmmoState.ENABLE_PER_AMMO_TYPES)

  let ammo_type_remap = v.ammo_stowage__ammoTypeRemap[ammo_type]
  let weapon_range = int2(ammo_type_remap.y, ammo_type_remap.z)
  var total_bs_count = weapon_range.y - weapon_range.x
  if iter_all_bullet_sets
    
    total_bs_count = 0
    for weapon_i in weapon_range.x..weapon_range.y
      let gun_i = as_gun(weap.Weapons |> get_weapon(v.ammo_stowage__weaponsIds[weapon_i]))
      if gun_i == null
        return
      total_bs_count += length(gun_i.properties.bulletSets)

  var remaining_subtract = subtract
  for subtract_per_bs in fixed_array<int>(subtract / total_bs_count, 1)
    for _ in 0..total_bs_count
      var subtract_from_this_bs = min(subtract_per_bs, remaining_subtract)
      if subtract_from_this_bs == 0
        break

      
      var gun : WTGun? = null
      var bullet_set_idx = 0
      for weapon_i in weapon_range.x..weapon_range.y
        var gun_i = as_gun(weap.Weapons |> get_weapon(v.ammo_stowage__weaponsIds[weapon_i]))
        if gun_i == null
          return
        let bullet_set_range = iter_all_bullet_sets ? int2(0, length(gun_i.properties.bulletSets)) : int2(ammo_type_remap.w, ammo_type_remap.w + 1)
        for bs_i in bullet_set_range.x..bullet_set_range.y
          let cnt = gun_i.properties.bulletSets[bs_i].bulletsCount
          if cnt == 0
            continue
          if gun == null || cnt > gun.properties.bulletSets[bullet_set_idx].bulletsCount
            bullet_set_idx = bs_i
            gun = gun_i
      if gun == null
        break 

      assume bullet_set = gun.properties.bulletSets[bullet_set_idx]
      var cnt = bullet_set.bulletsCount
      var max_cnt = bullet_set.initialBulletsCount
      if initial_count
        subtract_from_this_bs = min(subtract_from_this_bs, max_cnt)
        max_cnt -= subtract_from_this_bs
        bullet_set.initialBulletsCount = max_cnt
      else
        subtract_from_this_bs = min(subtract_from_this_bs, cnt)
        cnt -= subtract_from_this_bs
      remaining_subtract -= subtract_from_this_bs
      cnt = max(0, min(max_cnt, cnt))
      bullet_set.bulletsCount = cnt







[with_bundle(v)]
def public ammo_stowage_send_net_sync(eid : EntityId; v : tuple<
                                        ammo_stowages__replenishmentStartEnd : Point2List;
                                        ammo_slots__numAmmo : IPoint2List;
                                        ammo_slots__ammoMaskAndType : UInt32List
                                        >) : void
  if !is_server()
    return
  let current_time = float(get_app().usefulTotalTime)

  using() <| $(var bs : BitStream)
    bs |> WriteCompressed(length(v.ammo_stowages__replenishmentStartEnd))
    for replenishment in v.ammo_stowages__replenishmentStartEnd
      bs |> Write(replenishment.y > 0.f)
      if replenishment.y > 0.f
        bs |> Write(replenishment.y - current_time)
    bs |> WriteCompressed(length(v.ammo_slots__numAmmo))
    for slot_ammo, slot_mask_and_type in v.ammo_slots__numAmmo, v.ammo_slots__ammoMaskAndType
      bs |> Write(slot_ammo.x == 0)
      if slot_ammo.x == 0
        continue
      let slot_ammo_type_raw = uint8(slot_mask_and_type & 0xffu)
      bs |> Write(slot_ammo_type_raw)
      bs |> Write(slot_ammo.x == slot_ammo.y)
      if slot_ammo.x == slot_ammo.y
        continue
      bs |> WriteCompressed(slot_ammo.x)
    send_net_event(eid, EventAmmoStowageNetSync(bs = ecs_addr(bs)))
