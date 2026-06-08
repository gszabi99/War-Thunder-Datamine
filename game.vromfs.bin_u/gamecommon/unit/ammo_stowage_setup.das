require ecs
require dm
require app
require net
require BitStream
require Unit
require Weapon
require AmmoStowage
require DagorSystem
require WTDamageModel
require WTHangar
require %game.utils.component_bundle_macro
require %game.utils.utils_common
require %game.unit.ammo_stowage_events
require %game.unit.ammo_stowage_common







[with_bundle(v)]
def setup_ammo_cluster_subtract(cluster_id : int; var num_ammo : int&; ammo_type : int;
                                v : tuple<
                                  ammo_clusters__slotsRange : IPoint2List;
                                  ammo_slots__numAmmo : IPoint2List -const;
                                  ammo_slots__ammoMaskAndType : UInt32List -const
                                  >) : int
  
  var subtracted_ammo = 0
  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  for slot_id in slots_range.x..slots_range.y
    if get_ammo_slot_type(slot_id, v) == ammo_type
      var slot_ammo = v.ammo_slots__numAmmo[slot_id]
      let prev_ammo = slot_ammo.x
      slot_ammo.x = min(slot_ammo.x, num_ammo)
      subtracted_ammo += prev_ammo - slot_ammo.x
      num_ammo -= slot_ammo.x
      v.ammo_slots__numAmmo[slot_id] = slot_ammo
  return subtracted_ammo

[with_bundle(v)]
def setup_ammo_cluster_add(cluster_id : int; var num_ammo : int&; ammo_type : int;
                           v : tuple<
                             ammo_clusters__state : UInt32List;
                             ammo_clusters__slotsRange : IPoint2List;
                             ammo_slots__state : UInt32List -const;
                             ammo_slots__numAmmo : IPoint2List -const;
                             ammo_slots__ammoMaskAndType : UInt32List -const;
                             ammo_stowage__ammoTypeToMask : UInt32List
                             >) : int
  if num_ammo == 0
    return 0
  
  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  let num_ammo_before = num_ammo
  for slot_id in slots_range.x..slots_range.y
    ammo_stowage_add_ammo_to_slot_partial(cluster_id, slot_id, num_ammo, ammo_type, v)
  return num_ammo_before - num_ammo

[with_bundle(v)]
def setup_ammo_cluster_subtract_amount(cluster_id : int; var num_ammo : int&;
                                       v : tuple<
                                         ammo_clusters__slotsRange : IPoint2List;
                                         ammo_slots__numAmmo : IPoint2List -const
                                         >) : int
  let num_ammo_before = num_ammo
  let slots_range = v.ammo_clusters__slotsRange[cluster_id]
  for slot_id in slots_range.x..slots_range.y
    if num_ammo == 0
      break
    var slot_ammo = v.ammo_slots__numAmmo[slot_id]
    let removed = min(slot_ammo.x, num_ammo)
    slot_ammo.x -= removed
    num_ammo -= removed
    v.ammo_slots__numAmmo[slot_id] = slot_ammo
  return num_ammo_before - num_ammo

def setup_ammo_get_weapon_stored_count(weapon : Weapon?; remove_loaded_ammo : bool; can_load_to_breech : bool) : int
  if weapon == null
    return 0
  let gun = weapon |> as_gun()
  if gun != null
    var count = 0
    for bullet_set in gun.properties.bulletSets
      count += max(0, bullet_set.bulletsCount)
    if remove_loaded_ammo && can_load_to_breech
      count -= int(gun.currentLoadedAmmoCount)
    return max(0, count)
  var count = max(0, int(weapon.countBullets))
  if remove_loaded_ammo && can_load_to_breech && count > 0
    count--
  return count

[with_bundle(v)]
def setup_ammo_get_weapon_ammo_type(unit : Unit?; stowage_id : int; weapon_idx : int;
                                    v : tuple<
                                      ammo_stowage__ammoTypeRemap : IPoint4List;
                                      ammo_stowage__weaponsIds : IntList
                                      >) : int
  var result = -1
  let weapon = unit.weap.Weapons |> get_weapon(weapon_idx)
  let gun = weapon |> as_gun()
  for ammo_type in 0..length(v.ammo_stowage__ammoTypeRemap)
    let ammo_type_remap = v.ammo_stowage__ammoTypeRemap[ammo_type]
    if ammo_type_remap.x != stowage_id
      continue
    for weapon_i in ammo_type_remap.y..ammo_type_remap.z
      if v.ammo_stowage__weaponsIds[weapon_i] != weapon_idx
        continue
      if result < 0
        result = ammo_type
      if gun != null && ammo_type_remap.w == int(gun.chosenBulletType)
        return ammo_type
  return max(0, result)

[with_bundle(v)]
def setup_ammo_add_to_weapon_clusters(stowage_id : int; trigger_id : int; cluster_stage : int; cluster_type : int;
                                      var num_ammo : int&; ammo_type : int;
                                      v : tuple<
                                        ammo_stowage__ammoTypeToMask : UInt32List;
                                        ammo_stowages__weaponTriggersRange : IPoint2List;
                                        ammo_stowage__weaponTriggers : IntList;
                                        ammo_stowages__clustersRange : IPoint2List;
                                        ammo_clusters__typeAndStage : UInt16List;
                                        ammo_clusters__state : UInt32List;
                                        ammo_clusters__slotsRange : IPoint2List;
                                        ammo_clusters__weaponTriggersRange : IPoint2List;
                                        ammo_cluster__weaponTriggers : IntList;
                                        ammo_slots__state : UInt32List -const;
                                        ammo_slots__numAmmo : IPoint2List -const;
                                        ammo_slots__ammoMaskAndType : UInt32List -const
                                        >) : int
  let num_ammo_before = num_ammo
  if ammo_type < 0 || ammo_type >= length(v.ammo_stowage__ammoTypeToMask)
    return 0
  let clusters_range = v.ammo_stowages__clustersRange[stowage_id]
  for cluster_id in clusters_range.x..clusters_range.y
    if num_ammo == 0
      break
    if get_ammo_cluster_stage(cluster_id, v) != cluster_stage
      continue
    if get_ammo_cluster_type(cluster_id, v) != cluster_type
      continue
    if !ammo_cluster_has_weapon_trigger(stowage_id, cluster_id, trigger_id, v)
      continue
    setup_ammo_cluster_add(cluster_id, num_ammo, ammo_type, v)
  return num_ammo_before - num_ammo

[with_bundle(v)]
def setup_ammo_subtract_from_weapon_clusters(stowage_id : int; trigger_id : int; cluster_stage : int; cluster_type : int;
                                             var num_ammo : int&;
                                             v : tuple<
                                               ammo_stowages__weaponTriggersRange : IPoint2List;
                                               ammo_stowage__weaponTriggers : IntList;
                                               ammo_stowages__clustersRange : IPoint2List;
                                               ammo_clusters__typeAndStage : UInt16List;
                                               ammo_clusters__slotsRange : IPoint2List;
                                               ammo_clusters__weaponTriggersRange : IPoint2List;
                                               ammo_cluster__weaponTriggers : IntList;
                                               ammo_slots__numAmmo : IPoint2List -const
                                               >) : int
  let num_ammo_before = num_ammo
  let clusters_range = v.ammo_stowages__clustersRange[stowage_id]
  for cluster_id in clusters_range.x..clusters_range.y
    if num_ammo == 0
      break
    if get_ammo_cluster_stage(cluster_id, v) != cluster_stage
      continue
    if get_ammo_cluster_type(cluster_id, v) != cluster_type
      continue
    if !ammo_cluster_has_weapon_trigger(stowage_id, cluster_id, trigger_id, v)
      continue
    setup_ammo_cluster_subtract_amount(cluster_id, num_ammo, v)
  return num_ammo_before - num_ammo

[with_bundle(v)]
def setup_ammo_stowage_has_cluster_type(stowage_id : int; cluster_type : int;
                                        v : tuple<
                                          ammo_stowages__clustersRange : IPoint2List;
                                          ammo_clusters__typeAndStage : UInt16List
                                          >) : bool
  let clusters_range = v.ammo_stowages__clustersRange[stowage_id]
  for cluster_id in clusters_range.x..clusters_range.y
    if get_ammo_cluster_type(cluster_id, v) == cluster_type
      return true
  return false

[with_bundle(v)]
def setup_ammo_stowage_has_cluster_stage(stowage_id : int; cluster_stage : int;
                                         v : tuple<
                                           ammo_stowages__clustersRange : IPoint2List;
                                           ammo_clusters__typeAndStage : UInt16List
                                           >) : bool
  let clusters_range = v.ammo_stowages__clustersRange[stowage_id]
  for cluster_id in clusters_range.x..clusters_range.y
    if get_ammo_cluster_stage(cluster_id, v) == cluster_stage
      return true
  return false


[with_bundle(v)]
def ammo_stowage_debug_print_all_clusters(v : tuple<
                                            ammo_stowage__ammoTypeToMask : UInt32List;
                                            ammo_clusters__state : UInt32List;
                                            ammo_clusters__slotsRange : IPoint2List;
                                            ammo_slots__numAmmo : IPoint2List;
                                            ammo_slots__ammoMaskAndType : UInt32List
                                            >) : void
  for cluster_id in iter_range(v.ammo_clusters__state)
    print("printing ammo in cluster {cluster_id}")
    var ammo_count : array<int>
    ammo_count |> resize(length(v.ammo_stowage__ammoTypeToMask))
    let slot_range = v.ammo_clusters__slotsRange[cluster_id]
    for slot_id in slot_range.x..slot_range.y
      let slot_ammo = v.ammo_slots__numAmmo[slot_id]
      if slot_ammo.x > 0
        ammo_count[get_ammo_slot_type(slot_id, v)] += slot_ammo.x
    for t, c in iter_range(ammo_count), ammo_count
      if c > 0
        print("  {c}:{t}")



[with_bundle(v)]
def public setup_ammo_stowage(var unit : Unit?; init_num : bool; is_refill : bool;
                              v : tuple<
                                ammo_stowage__ammoState : uint;
                                ammo_stowage__ammoLost : int -const;
                                ammo_stowage__ammoTypeToMask : UInt32List;
                                ammo_stowage__ammoTypeRemap : IPoint4List;
                                ammo_stowage__weaponsIds : IntList;

                                ammo_stowages__state : UInt32List -const;
                                ammo_stowages__clustersRange : IPoint2List;
                                ammo_stowages__weaponTriggersRange : IPoint2List;
                                ammo_stowage__weaponTriggers : IntList;
                                ammo_stowages__weaponAmmoRange : IPoint2List;
                                ammo_stowage__weaponAmmoIds : IntList;
                                ammo_stowage__weaponAmmoTriggers : IntList;
                                ammo_stowage__weaponAmmoCount : IntList -const;

                                ammo_clusters__typeAndStage : UInt16List;
                                ammo_clusters__state : UInt32List -const;
                                ammo_clusters__slotsRange : IPoint2List;
                                ammo_clusters__weaponTriggersRange : IPoint2List;
                                ammo_cluster__weaponTriggers : IntList;
                                ammo_slots__state : UInt32List -const;
                                ammo_slots__partId : PartIdList;
                                ammo_slots__numAmmo : IPoint2List -const;
                                ammo_slots__ammoMaskAndType : UInt32List -const
                                >) : bool
  
  let can_load_to_breech = !is_in_hangar()

  let eid = unit.eid
  let weapon_controller = unit.weap
  var is_sync_required = false
  let full_refill = init_num || is_refill

  
  for slot_state, slot_num_ammo in v.ammo_slots__state, v.ammo_slots__numAmmo
    if !get_flag(slot_state, AmmoSlotState.ENABLED)
      slot_num_ammo.x = 0

  if full_refill
    for slot_num_ammo in v.ammo_slots__numAmmo
      is_sync_required = is_sync_required || slot_num_ammo.x != 0
      slot_num_ammo.x = 0

  assert(int(AmmoClusterType.NUM_TYPES) == 2)

  for stowage_id in iter_range(v.ammo_stowages__state)
    let stowage_state = v.ammo_stowages__state[stowage_id]
    let remove_loaded_ammo = get_flag(stowage_state, AmmoStowageState.REMOVE_LOADED_AMMO)
    let has_charges = setup_ammo_stowage_has_cluster_type(stowage_id, int(AmmoClusterType.CHARGES), v)

    if full_refill
      var total_ammo_to_add = 0
      ammo_stowage_iter_all_weapons_and_bullet_sets(weapon_controller, v) <| $(ammo_info : WeaponAndAmmoInfo)
        if ammo_info.stowage_id != stowage_id || ammo_info.ammo_type >= length(v.ammo_stowage__ammoTypeToMask)
          return
        var ammo_to_add = ammo_info.count
        if remove_loaded_ammo && can_load_to_breech
          ammo_to_add -= ammo_info.loaded_count
        ammo_to_add = max(0, ammo_to_add)
        total_ammo_to_add += ammo_to_add

        let weapon_ammo_range = v.ammo_stowages__weaponAmmoRange[stowage_id]
        var trigger_id = -1
        for weapon_ammo_idx in weapon_ammo_range.x..weapon_ammo_range.y
          if v.ammo_stowage__weaponAmmoIds[weapon_ammo_idx] == ammo_info.first_weapon_idx
            trigger_id = v.ammo_stowage__weaponAmmoTriggers[weapon_ammo_idx]
            break
        if trigger_id < 0
          return

        for cluster_type in 0..int(AmmoClusterType.NUM_TYPES)
          if cluster_type == int(AmmoClusterType.CHARGES) && !has_charges
            continue
          var typed_ammo_to_add = ammo_to_add
          setup_ammo_add_to_weapon_clusters(stowage_id, trigger_id, int(AmmoClusterStage.FIRST_STAGE), cluster_type, typed_ammo_to_add, ammo_info.ammo_type, v)
          setup_ammo_add_to_weapon_clusters(stowage_id, trigger_id, int(AmmoClusterStage.SECOND_STAGE), cluster_type, typed_ammo_to_add, ammo_info.ammo_type, v)
          is_sync_required = is_sync_required || typed_ammo_to_add != ammo_to_add
          if init_num && typed_ammo_to_add > 0 && cluster_type == int(AmmoClusterType.SHELLS)
            logwarn("{unit.props.fileName}: failed to distribute ammo slots, excess={typed_ammo_to_add}, ammo_info={ammo_info}")

      if total_ammo_to_add > 0 || is_refill
        v.ammo_stowage__ammoLost = 0
    else
      let weapon_ammo_range = v.ammo_stowages__weaponAmmoRange[stowage_id]
      for weapon_ammo_idx in weapon_ammo_range.x..weapon_ammo_range.y
        let weapon_idx = v.ammo_stowage__weaponAmmoIds[weapon_ammo_idx]
        let trigger_id = v.ammo_stowage__weaponAmmoTriggers[weapon_ammo_idx]
        let weapon = weapon_controller.Weapons |> get_weapon(weapon_idx)
        let current_ammo = setup_ammo_get_weapon_stored_count(weapon, remove_loaded_ammo, can_load_to_breech)
        let prev_ammo = v.ammo_stowage__weaponAmmoCount[weapon_ammo_idx]
        let delta_ammo = current_ammo - prev_ammo
        var updated_ammo = current_ammo
        if delta_ammo < 0
          for cluster_type in 0..int(AmmoClusterType.NUM_TYPES)
            if cluster_type == int(AmmoClusterType.CHARGES) && !has_charges
              continue
            var ammo_to_subtract = -delta_ammo
            setup_ammo_subtract_from_weapon_clusters(stowage_id, trigger_id, int(AmmoClusterStage.FIRST_STAGE), cluster_type, ammo_to_subtract, v)
            setup_ammo_subtract_from_weapon_clusters(stowage_id, trigger_id, int(AmmoClusterStage.SECOND_STAGE), cluster_type, ammo_to_subtract, v)
            is_sync_required = is_sync_required || ammo_to_subtract != -delta_ammo
          set_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState.NEED_SYNC_BULLET_COUNT, true)
        elif delta_ammo > 0
          let ammo_type = setup_ammo_get_weapon_ammo_type(unit, stowage_id, weapon_idx, v)
          var added_ammo = 0
          for cluster_type in 0..int(AmmoClusterType.NUM_TYPES)
            if cluster_type == int(AmmoClusterType.CHARGES) && !has_charges
              continue
            var ammo_to_add = delta_ammo
            setup_ammo_add_to_weapon_clusters(stowage_id, trigger_id, int(AmmoClusterStage.SECOND_STAGE), cluster_type, ammo_to_add, ammo_type, v)
            setup_ammo_add_to_weapon_clusters(stowage_id, trigger_id, int(AmmoClusterStage.FIRST_STAGE), cluster_type, ammo_to_add, ammo_type, v)
            if cluster_type == int(AmmoClusterType.SHELLS)
              added_ammo = delta_ammo - ammo_to_add
            is_sync_required = is_sync_required || ammo_to_add != delta_ammo
          updated_ammo = prev_ammo + added_ammo
        v.ammo_stowage__weaponAmmoCount[weapon_ammo_idx] = updated_ammo

    if remove_loaded_ammo && can_load_to_breech && setup_ammo_stowage_has_cluster_stage(stowage_id, int(AmmoClusterStage.LOADED_IN_GUN), v)
      let clusters_range = v.ammo_stowages__clustersRange[stowage_id]
      for cluster_id in clusters_range.x..clusters_range.y
        if get_ammo_cluster_stage(cluster_id, v) != int(AmmoClusterStage.LOADED_IN_GUN)
          continue
        let slots_range = v.ammo_clusters__slotsRange[cluster_id]
        for slot_id in slots_range.x..slots_range.y
          is_sync_required = is_sync_required || v.ammo_slots__numAmmo[slot_id].x != 0
          v.ammo_slots__numAmmo[slot_id].x = 0

      ammo_stowage_iter_all_weapons_and_bullet_sets(weapon_controller, v) <| $(ammo_info : WeaponAndAmmoInfo)
        if ammo_info.stowage_id != stowage_id || ammo_info.loaded_count == 0 || ammo_info.ammo_type >= length(v.ammo_stowage__ammoTypeToMask)
          return
        let weapon_ammo_range = v.ammo_stowages__weaponAmmoRange[stowage_id]
        var trigger_id = -1
        for weapon_ammo_idx in weapon_ammo_range.x..weapon_ammo_range.y
          if v.ammo_stowage__weaponAmmoIds[weapon_ammo_idx] == ammo_info.first_weapon_idx
            trigger_id = v.ammo_stowage__weaponAmmoTriggers[weapon_ammo_idx]
            break
        if trigger_id < 0
          return
        for cluster_type in 0..int(AmmoClusterType.NUM_TYPES)
          if cluster_type == int(AmmoClusterType.CHARGES) && !has_charges
            continue
          var loaded_ammo_to_add = ammo_info.loaded_count
          setup_ammo_add_to_weapon_clusters(stowage_id, trigger_id, int(AmmoClusterStage.LOADED_IN_GUN), cluster_type, loaded_ammo_to_add, ammo_info.ammo_type, v)
          is_sync_required = is_sync_required || loaded_ammo_to_add != ammo_info.loaded_count

  if full_refill
    for stowage_id in iter_range(v.ammo_stowages__state)
      let stowage_state = v.ammo_stowages__state[stowage_id]
      let remove_loaded_ammo = get_flag(stowage_state, AmmoStowageState.REMOVE_LOADED_AMMO)
      let weapon_ammo_range = v.ammo_stowages__weaponAmmoRange[stowage_id]
      for weapon_ammo_idx in weapon_ammo_range.x..weapon_ammo_range.y
        let weapon_idx = v.ammo_stowage__weaponAmmoIds[weapon_ammo_idx]
        let weapon = weapon_controller.Weapons |> get_weapon(weapon_idx)
        v.ammo_stowage__weaponAmmoCount[weapon_ammo_idx] = setup_ammo_get_weapon_stored_count(weapon, remove_loaded_ammo, can_load_to_breech)

  
  for cluster_id in iter_range(v.ammo_clusters__state)
    ammo_cluster_balance_slots(unit, cluster_id, false, v)

  
  if init_num
    for cluster_id, slots_range in iter_range(v.ammo_clusters__slotsRange), v.ammo_clusters__slotsRange
      set_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.EXCLUDED, false)
      if get_ammo_cluster_stage(cluster_id, v) == int(AmmoClusterStage.LOADED_IN_GUN)
        continue
      var total_cluster_ammo = int2(0)
      for slot_id in slots_range.x..slots_range.y
        v.ammo_slots__numAmmo[slot_id].y = v.ammo_slots__numAmmo[slot_id].x
        total_cluster_ammo += v.ammo_slots__numAmmo[slot_id]
      set_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.EXCLUDED, total_cluster_ammo.y == 0)

  
  let enable_all_parts = is_in_hangar()
  var is_dm_changed = false
  for slot_id, slot_num_ammo in iter_range(v.ammo_slots__state), v.ammo_slots__numAmmo
    is_dm_changed = ammo_slot_set_dm_enabled(unit, slot_id, slot_num_ammo.x > 0 || enable_all_parts, v) || is_dm_changed
  if is_dm_changed
    sendEvent(eid, EventAmmoStowageInvalidateRenderer())

  return is_sync_required







[es, with_bundle(v)]
def ammo_stowage_setup_stowage_es(evt : EventAmmoStowageSetup; eid : EntityId; var unit__ref : UnitRef;
                                  v : tuple<
                                    ammo_stowage__ammoState : uint;
                                    ammo_stowage__ammoLost : int -const;
                                    ammo_stowage__ammoTypeToMask : UInt32List;
                                    ammo_stowage__ammoTypeRemap : IPoint4List;
                                    ammo_stowage__weaponsIds : IntList;
                                    ammo_stowages__state : UInt32List -const;
                                    ammo_stowages__replenishmentStartEnd : Point2List;
                                    ammo_stowages__clustersRange : IPoint2List;
                                    ammo_stowages__weaponTriggersRange : IPoint2List;
                                    ammo_stowage__weaponTriggers : IntList;
                                    ammo_stowages__weaponAmmoRange : IPoint2List;
                                    ammo_stowage__weaponAmmoIds : IntList;
                                    ammo_stowage__weaponAmmoTriggers : IntList;
                                    ammo_stowage__weaponAmmoCount : IntList -const;
                                    ammo_clusters__typeAndStage : UInt16List;
                                    ammo_clusters__state : UInt32List -const;
                                    ammo_clusters__slotsRange : IPoint2List;
                                    ammo_clusters__weaponTriggersRange : IPoint2List;
                                    ammo_cluster__weaponTriggers : IntList;
                                    ammo_slots__state : UInt32List -const;
                                    ammo_slots__partId : PartIdList;
                                    ammo_slots__numAmmo : IPoint2List -const;
                                    ammo_slots__ammoMaskAndType : UInt32List -const
                                    >)
  var unit = unit__ref.unit
  let sync_required = setup_ammo_stowage(unit,
    evt.initNum,
    evt.isRefill) <| v
  if evt.netSyncIfRequired && sync_required
    ammo_stowage_send_net_sync(eid) <| v


[es, with_bundle(v)]
def ammo_stowage_bullets_amount_changed_es(evt : EventBulletsAmountChanged; eid : EntityId; var unit__ref : UnitRef;
                                           v : tuple<
                                             ammo_stowage__ammoState : uint;
                                             ammo_stowage__ammoLost : int -const;
                                             ammo_stowage__ammoTypeToMask : UInt32List;
                                             ammo_stowage__ammoTypeRemap : IPoint4List;
                                             ammo_stowage__weaponsIds : IntList;
                                             ammo_stowages__state : UInt32List -const;
                                             ammo_stowages__replenishmentStartEnd : Point2List;
                                             ammo_stowages__clustersRange : IPoint2List;
                                             ammo_stowages__weaponTriggersRange : IPoint2List;
                                             ammo_stowage__weaponTriggers : IntList;
                                             ammo_stowages__weaponAmmoRange : IPoint2List;
                                             ammo_stowage__weaponAmmoIds : IntList;
                                             ammo_stowage__weaponAmmoTriggers : IntList;
                                             ammo_stowage__weaponAmmoCount : IntList -const;
                                             ammo_clusters__typeAndStage : UInt16List;
                                             ammo_clusters__state : UInt32List -const;
                                             ammo_clusters__slotsRange : IPoint2List;
                                             ammo_clusters__weaponTriggersRange : IPoint2List;
                                             ammo_cluster__weaponTriggers : IntList;
                                             ammo_slots__state : UInt32List -const;
                                             ammo_slots__partId : PartIdList;
                                             ammo_slots__numAmmo : IPoint2List -const;
                                             ammo_slots__ammoMaskAndType : UInt32List -const
                                             >)
  var unit = unit__ref.unit
  if !unit.isDelayed
    let sync_required = setup_ammo_stowage(unit, false, evt.isRefill) <| v
    if sync_required
      ammo_stowage_send_net_sync(eid) <| v


[es, with_bundle(v)]
def ammo_stowage_force_reload_gun_es(evt : CmdAmmoStowageForceReloadGun; var unit__ref : UnitRef;
                                     v : tuple<
                                       ammo_stowages__weaponTriggersRange : IPoint2List;
                                       ammo_stowage__weaponTriggers : IntList
                                       >)
  var unit = unit__ref.unit
  if unit.isDelayed
    return
  ammo_stowage_iter_stowage_weapons(unit.weap, evt.stowageId, v) <| $(weapon : Weapon?)
    var gun = weapon |> as_gun()
    if gun != null
      start_reloading_gun(*gun)


[es, with_bundle(v)]
def ammo_stowage_recalc_gun_reloading_time_es(evt : CmdAmmoStowageRecalcReloadingTime; var unit__ref : UnitRef;
                                              v : tuple<
                                                ammo_stowages__weaponTriggersRange : IPoint2List;
                                                ammo_stowage__weaponTriggers : IntList
                                                >)
  var unit = unit__ref.unit
  if unit.isDelayed
    return
  ammo_stowage_iter_stowage_weapons(unit.weap, evt.stowageId, v) <| $(weapon : Weapon?)
    var gun = weapon |> as_gun()
    if gun != null
      *gun |> requestRecalcReloadTime()







[es(tag=netClient), with_bundle(v)]
def ammo_stowage_net_sync_es(evt : EventAmmoStowageNetSync;
                             eid : EntityId;
                             var v : tuple<
                               ammo_stowages__replenishmentStartEnd : Point2List;
                               ammo_slots__numAmmo : IPoint2List;
                               ammo_slots__ammoMaskAndType : UInt32List;
                               ammo_stowage__ammoTypeToMask : UInt32List const
                               >) : void
  assume bs = *evt.bs
  let current_time = float(get_app().usefulTotalTime)
  var stowage_cnt = 0
  bs |> ReadCompressed(stowage_cnt)
  if stowage_cnt != length(v.ammo_stowages__replenishmentStartEnd)
    return
  for replenishment in v.ammo_stowages__replenishmentStartEnd
    var is_replenishing = false
    bs |> Read(is_replenishing)
    if is_replenishing
      var remaining_time = 0.f
      bs |> Read(remaining_time)
      replenishment.y = current_time + remaining_time
      if replenishment.x < 0.0f
        replenishment.x = current_time
  var slot_cnt = 0
  bs |> ReadCompressed(slot_cnt)
  if slot_cnt != length(v.ammo_slots__numAmmo)
    return
  var changed = false
  for slot_ammo, slot_mask_and_type in v.ammo_slots__numAmmo, v.ammo_slots__ammoMaskAndType
    
    var is_empty_slot = false
    bs |> Read(is_empty_slot)
    if is_empty_slot
      changed = changed || slot_ammo.x != 0
      slot_ammo.x = 0
      continue
    
    var slot_ammo_type_raw = uint8(slot_mask_and_type & 0xffu)
    bs |> Read(slot_ammo_type_raw)
    let slot_ammo_type = min(int(slot_ammo_type_raw), length(v.ammo_stowage__ammoTypeToMask))
    changed = changed || slot_ammo_type != int(slot_mask_and_type & 0xffu)
    slot_mask_and_type = (slot_mask_and_type & 0xffffff00u) | uint(slot_ammo_type)
    
    var is_full_slot = false
    bs |> Read(is_full_slot)
    if is_full_slot
      changed = changed || slot_ammo.x != slot_ammo.y
      slot_ammo.x = slot_ammo.y
      continue
    
    let num_ammo_before = slot_ammo.x
    bs |> ReadCompressed(slot_ammo.x)
    slot_ammo.x = min(slot_ammo.x, slot_ammo.y)
    changed = changed || slot_ammo.x != num_ammo_before

  if changed
    sendEvent(eid, EventBulletsAmountChanged(isRefill = false))


[es(no_order)]
def ammo_stowage_gun_net_sync_es(act : UpdateStageInfoAct;
                                 var unit__ref : UnitRef;
                                 var ammo_stowages__state : UInt32List&;
                                 ammo_stowages__weaponTriggersRange : IPoint2List;
                                 ammo_stowage__weaponTriggers : IntList)
  for stowage_id, state in iter_range(ammo_stowages__state), ammo_stowages__state
    if get_flag(state, AmmoStowageState.NEED_SYNC_BULLET_COUNT)
      set_flag(state, AmmoStowageState.NEED_SYNC_BULLET_COUNT, false)

      let unit = unit__ref.unit
      if unit.isDelayed
        return
      let triggers_range = ammo_stowages__weaponTriggersRange[stowage_id]
      for trigger_id_idx in triggers_range.x..triggers_range.y
        let trigger_id = ammo_stowage__weaponTriggers[trigger_id_idx]
        for weapon in unit.weap.Weapons |> get_weapons_by_trigger(trigger_id)
          let gun = weapon |> as_gun()
          if gun == null
            continue
          send_bullet_rearm_event(*gun, false)

