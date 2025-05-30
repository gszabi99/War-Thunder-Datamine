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



[with_bundle(v), unused_argument(init_num)]
def public setup_ammo_stowage(var unit : Unit?; init_num : bool; is_refill : bool;
                              v : tuple<
                                ammo_stowage__ammoState : uint;
                                ammo_stowage__ammoLost : int -const;
                                ammo_stowage__ammoTypeToMask : UInt32List;

                                ammo_stowages__state : UInt32List -const;
                                ammo_stowages__clustersRange : IPoint2List;
                                ammo_stowages__weaponTriggersRange : IPoint2List;
                                ammo_stowage__weaponTriggers : IntList;

                                ammo_clusters__typeAndStage : UInt16List;
                                ammo_clusters__state : UInt32List -const;
                                ammo_clusters__slotsRange : IPoint2List;
                                ammo_slots__state : UInt32List -const;
                                ammo_slots__partId : PartIdList;
                                ammo_slots__numAmmo : IPoint2List -const;
                                ammo_slots__ammoMaskAndType : UInt32List -const
                                >) : bool
  
  let can_load_to_breech = !is_in_hangar()

  let eid = unit.eid
  let weapon_controller = unit.weap
  var is_sync_required = false

  
  for slot_state, slot_num_ammo in v.ammo_slots__state, v.ammo_slots__numAmmo
    if !get_flag(slot_state, AmmoSlotState.ENABLED)
      slot_num_ammo.x = 0

  assert(int(AmmoClusterType.NUM_TYPES) == 2)
  var stowage_ammo_arr : array<int2[2]> 
  stowage_ammo_arr |> reserve(8)

  ammo_stowage_iter_all_stowages_and_bullets(weapon_controller, v) <| $(stowage_id : int; ammo_info_arr : array<WeaponAndAmmoInfo>)
    let stowage_state = v.ammo_stowages__state[stowage_id]
    let clusters_range = v.ammo_stowages__clustersRange[stowage_id]

    
    stowage_ammo_arr |> resize(length(ammo_info_arr))
    for stowage_ammo in stowage_ammo_arr
      for cnt in stowage_ammo
        cnt = int2(0, 0)
    var total_ammo_to_add = 0

    for ammo_info, stowage_ammo in ammo_info_arr, stowage_ammo_arr
      
      if ammo_info.ammo_type >= length(v.ammo_stowage__ammoTypeToMask)
        continue
      var total_ammo_count = ammo_info.count
      if get_flag(stowage_state, AmmoStowageState.REMOVE_LOADED_AMMO) && can_load_to_breech
        total_ammo_count -= ammo_info.loaded_count

      assert(int(AmmoClusterType.NUM_TYPES) == 2)
      var num_ammo_in_stowage : int[2]
      var num_ammo_loaded : int[2]
      for cluster_type in 0..int(AmmoClusterType.NUM_TYPES)
        num_ammo_in_stowage[cluster_type] = total_ammo_count
        num_ammo_loaded[cluster_type] = ammo_info.loaded_count

      
      if true
        var cluster_id = clusters_range.y - 1
        for _ in clusters_range.x..clusters_range.y
          let cluster_type = get_ammo_cluster_type(cluster_id, v)
          var subtracted = 0
          if get_ammo_cluster_stage(cluster_id, v) == int(AmmoClusterStage.LOADED_IN_GUN)
            subtracted = setup_ammo_cluster_subtract(cluster_id, num_ammo_loaded[cluster_type], ammo_info.ammo_type, v)
          else
            subtracted = setup_ammo_cluster_subtract(cluster_id, num_ammo_in_stowage[cluster_type], ammo_info.ammo_type, v)
          is_sync_required = is_sync_required || subtracted != 0
          
          cluster_id--

      for cluster_type in 0..int(AmmoClusterType.NUM_TYPES)
        
        stowage_ammo[cluster_type].x = total_ammo_count - num_ammo_in_stowage[cluster_type]
        stowage_ammo[cluster_type].y = num_ammo_in_stowage[cluster_type]
        total_ammo_to_add += stowage_ammo[cluster_type].y

      
      for cluster_id in clusters_range.x..clusters_range.y
        let cluster_type = get_ammo_cluster_type(cluster_id, v)
        if get_ammo_cluster_stage(cluster_id, v) == int(AmmoClusterStage.LOADED_IN_GUN)
          let added = setup_ammo_cluster_add(cluster_id, num_ammo_loaded[cluster_type], ammo_info.ammo_type, v)
          is_sync_required = is_sync_required || added != 0

    
    if total_ammo_to_add > 0 || is_refill
      v.ammo_stowage__ammoLost = 0

    
    for cluster_id in clusters_range.x..clusters_range.y
      if total_ammo_to_add == 0
        break
      let cluster_type = get_ammo_cluster_type(cluster_id, v)
      if get_ammo_cluster_stage(cluster_id, v) == int(AmmoClusterStage.LOADED_IN_GUN)
        continue

      
      var free_slots_volume = 0
      let slots_range = v.ammo_clusters__slotsRange[cluster_id]
      for slot_id in slots_range.x..slots_range.y
        let slot_ammo = v.ammo_slots__numAmmo[slot_id]
        free_slots_volume += slot_ammo.y - slot_ammo.x

      var any_added = true
      while any_added
        any_added = false
        var remaining_ammo_type_count = 0
        for stowage_ammo in stowage_ammo_arr
          if stowage_ammo[cluster_type].y > 0
            remaining_ammo_type_count++
        if remaining_ammo_type_count == 0
          break
        let ammo_to_add_per_iter = max(1, free_slots_volume / remaining_ammo_type_count)
        
        for ammo_info, stowage_ammo in ammo_info_arr, stowage_ammo_arr
          if stowage_ammo[cluster_type].y == 0
            continue
          var ammo_to_add = min(ammo_to_add_per_iter, stowage_ammo[cluster_type].y)
          let added_ammo = setup_ammo_cluster_add(cluster_id, ammo_to_add, ammo_info.ammo_type, v)
          if added_ammo > 0
            stowage_ammo[cluster_type].y -= added_ammo
            total_ammo_to_add -= added_ammo
            free_slots_volume -= added_ammo
            any_added = true
            is_sync_required = true
            

    if init_num
      var any_excess = false
      for stowage_ammo in stowage_ammo_arr
        if stowage_ammo[int(AmmoClusterType.SHELLS)].y > 0 && stowage_ammo[int(AmmoClusterType.SHELLS)].x > 0
          any_excess = true
      if any_excess
        
        logwarn("{unit.props.fileName}: failed to distribute ammo slots, distributed/excess={stowage_ammo_arr}, ammo_info={ammo_info_arr}")

  
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
                                    ammo_stowages__state : UInt32List -const;
                                    ammo_stowages__replenishmentStartEnd : Point2List;
                                    ammo_stowages__clustersRange : IPoint2List;
                                    ammo_stowages__weaponTriggersRange : IPoint2List;
                                    ammo_stowage__weaponTriggers : IntList;
                                    ammo_clusters__typeAndStage : UInt16List;
                                    ammo_clusters__state : UInt32List -const;
                                    ammo_clusters__slotsRange : IPoint2List;
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
                                             ammo_stowages__state : UInt32List -const;
                                             ammo_stowages__replenishmentStartEnd : Point2List;
                                             ammo_stowages__clustersRange : IPoint2List;
                                             ammo_stowages__weaponTriggersRange : IPoint2List;
                                             ammo_stowage__weaponTriggers : IntList;
                                             ammo_clusters__typeAndStage : UInt16List;
                                             ammo_clusters__state : UInt32List -const;
                                             ammo_clusters__slotsRange : IPoint2List;
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
def ammo_stowage_force_reload_gun_es(evt : EventAmmoStowageForceReloadGun; var unit__ref : UnitRef;
                                     v : tuple<
                                       ammo_stowages__weaponTriggersRange : IPoint2List;
                                       ammo_stowage__weaponTriggers : IntList
                                       >)
  var unit = unit__ref.unit
  if unit.isDelayed
    return
  if evt.stowageId < 0 || evt.stowageId >= length(v.ammo_stowages__weaponTriggersRange)
    return
  let triggers_range = v.ammo_stowages__weaponTriggersRange[evt.stowageId]
  for trigger_no_idx in triggers_range.x..triggers_range.y
    for weapon in unit.weap.Weapons |> get_weapons_by_trigger(v.ammo_stowage__weaponTriggers[trigger_no_idx])
      var gun = weapon |> as_gun()
      if gun == null
        continue
      start_reloading_gun(*gun)







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

