require ecs
require net
require app
require dm
require math
require DagorRandom
require DagorMath
require Unit
require UnitFx
require AmmoStowage
require Weapon
require WTDamageModel
require IGroundModel
require WTHangar
require %dasGameLibs.math.base
require %game.utils.utils_common
require %game.utils.component_bundle_macro
require %game.dm.fire_system_events
require %game.unit.unit_events
require %game.unit.ammo_stowage_common
require %game.unit.ammo_stowage_events
require %game.events







[with_bundle(v)]
def ammo_stowage_restore_slots(var v : tuple<
                                 ammo_slots__state : UInt32List
                                 >) : void
  
  for state in v.ammo_slots__state
    set_flag(state, AmmoSlotState.ENABLED, true)
    set_flag(state, AmmoSlotState.FLOODED, false)


[es, with_bundle(v)]
def ammo_stowage_respawn_handle(evt : EventUnitRespawn; eid : EntityId;
                                var v : tuple<
                                  ammo_slots__state : UInt32List
                                  >) : void
  ammo_stowage_restore_slots() <| v
  sendEvent(eid, EventBulletsAmountChanged(isRefill = true))


[es, with_bundle(v)]
def ammo_stowage_repair_handle(evt : EventUnitRepair; eid : EntityId;
                               var v : tuple<
                                 ammo_slots__state : UInt32List
                                 >) : void
  ammo_stowage_restore_slots() <| v
  sendEvent(eid, EventBulletsAmountChanged(isRefill = false))







[with_bundle(v)]
def ammo_stowage_gather_and_update_ammo(unit : Unit?;
                                        stowage_id : int;
                                        v : tuple<
                                          ammo_stowage__ammoState : uint;
                                          ammo_stowage__ammoTypeRemap : IPoint4List;
                                          ammo_stowage__weaponsIds : IntList;
                                          ammo_stowage__relatedPartsIds : PartIdList;
                                          ammo_stowages__clustersRange : IPoint2List;
                                          ammo_clusters__state : UInt32List;
                                          ammo_clusters__typeAndStage : UInt16List;
                                          ammo_clusters__slotsRange : IPoint2List;
                                          ammo_clusters__relatedPartsRange : IPoint2List;
                                          ammo_slots__numAmmo : IPoint2List -const;
                                          ammo_slots__ammoMaskAndType : UInt32List;
                                          ammo_per_type_data__state : UInt32List -const;
                                          ammo_per_type_data__numAmmoFs : IntList -const
                                          >) : tuple<hash : uint; data_range : int2>
  let clusters_range = v.ammo_stowages__clustersRange[stowage_id]
  let enable_per_ammo_types = get_flag(v.ammo_stowage__ammoState, AmmoState.ENABLE_PER_AMMO_TYPES)

  var stowage_any_parts_broken = false
  var stowage_all_parts_broken = clusters_range.x != clusters_range.y
  var stowage_has_autoloader_parts = false
  var stowage_has_elevator_parts = false
  assert(int(AmmoClusterStage.NUM_STAGES) == 4)
  var stage_present : bool[4]
  for p in stage_present
    p = false
  var auto_load_present = false
  for cluster_id in clusters_range.x..clusters_range.y
    let cluster_state = v.ammo_clusters__state[cluster_id]
    let cluster_stage = get_ammo_cluster_stage(cluster_id, v)
    let parts_range = v.ammo_clusters__relatedPartsRange[cluster_id]
    if get_flag(cluster_state, AmmoClusterState.EXCLUDED)
      continue
    stage_present[cluster_stage] = true
    if get_flag(cluster_state, AmmoClusterState.AUTO_LOAD)
      auto_load_present = true

    stowage_has_autoloader_parts = get_flag(cluster_state, AmmoClusterState.HAS_AUTOLOADER_PARTS) || stowage_has_autoloader_parts
    stowage_has_elevator_parts = get_flag(cluster_state, AmmoClusterState.HAS_ELEVATOR_PARTS) || stowage_has_elevator_parts
    if !get_flag(cluster_state, AmmoClusterState.DESTROYED_DM_BLOCKS_SHOOT) || parts_range.x == parts_range.y
      stowage_all_parts_broken = false
      continue
    for i in parts_range.x..parts_range.y
      if get_part_hp(unit.dmData, v.ammo_stowage__relatedPartsIds[i]) > 0.f
        stowage_all_parts_broken = false
      else
        stowage_any_parts_broken = true

  let ammo_type_count = length(v.ammo_stowage__ammoTypeRemap)
  let per_ammo_offset = stowage_id * ammo_type_count
  for ammo_type in 0..ammo_type_count
    let glob_ammo_idx = per_ammo_offset + ammo_type
    let ammo_type_remap = v.ammo_stowage__ammoTypeRemap[ammo_type]

    v.ammo_per_type_data__state[glob_ammo_idx] = 0u
    if stage_present[int(AmmoClusterStage.FIRST_STAGE)] || stage_present[int(AmmoClusterStage.SECOND_STAGE)]
      v.ammo_per_type_data__state[glob_ammo_idx] |= (
          uint(AmmoStowagePerAmmoState.EMPTY) |
          uint(AmmoStowagePerAmmoState.EMPTY_FIRST_STAGE) |
          uint(AmmoStowagePerAmmoState.EMPTY_SECOND_STAGE)
        )
    set_flag(v.ammo_per_type_data__state[glob_ammo_idx], AmmoStowagePerAmmoState.EMPTY_AUTO_LOAD, auto_load_present)

    if ammo_type_remap.x != stowage_id
      
      continue

    var loaded_ammo_cnt = 0
    var is_ready_to_shoot = false
    for weapon_i in ammo_type_remap.y..ammo_type_remap.z
      let weapon = unit.weap.Weapons |> get_weapon(v.ammo_stowage__weaponsIds[weapon_i])
      if weapon == null
        continue
      let gun = weapon |> as_gun()
      if gun != null
        loaded_ammo_cnt += int(gun.chosenBulletType) == ammo_type_remap.w || !enable_per_ammo_types ? gun.currentLoadedAmmoCount : 0
        is_ready_to_shoot = gun.isReadyToShoot || is_ready_to_shoot
      else
        loaded_ammo_cnt += 1 
        is_ready_to_shoot = true
    set_flag(v.ammo_per_type_data__state[glob_ammo_idx], AmmoStowagePerAmmoState.EMPTY_LOADED_AMMO, loaded_ammo_cnt == 0)
    v.ammo_per_type_data__numAmmoFs[glob_ammo_idx] = stage_present[int(AmmoClusterStage.FIRST_STAGE)] || stage_present[int(AmmoClusterStage.LOADED_IN_GUN)] ? 0 : -1
    
    var weapon_blocked_by_broken_parts = false
    if stowage_has_elevator_parts && stowage_all_parts_broken
      weapon_blocked_by_broken_parts = true
    if stowage_has_autoloader_parts && stowage_any_parts_broken && !is_ready_to_shoot
      weapon_blocked_by_broken_parts = true
    set_flag(v.ammo_per_type_data__state[glob_ammo_idx], AmmoStowagePerAmmoState.BLOCKED_BY_BROKEN_PARTS, weapon_blocked_by_broken_parts)

  
  
  let fs_cluster_stage = stage_present[int(AmmoClusterStage.LOADED_IN_GUN)] ? int(AmmoClusterStage.LOADED_IN_GUN) : int(AmmoClusterStage.FIRST_STAGE)

  var ammo_hash = 1u
  for cluster_id in clusters_range.x..clusters_range.y
    let cluster_stage = get_ammo_cluster_stage(cluster_id, v)
    let cluster_type = get_ammo_cluster_type(cluster_id, v)
    let slots_range = v.ammo_clusters__slotsRange[cluster_id]
    var cluster_ammo = int2(0, 0)
    for slot_id in slots_range.x..slots_range.y
      
      let slot_ammo = v.ammo_slots__numAmmo[slot_id]
      let slot_ammo_type = get_ammo_slot_type(slot_id, v)
      ammo_hash = (ammo_hash * 16777619u) ^ uint(slot_ammo.x * 17 + slot_ammo_type)
      cluster_ammo += slot_ammo
      
      let glob_ammo_idx = per_ammo_offset + slot_ammo_type
      if slot_ammo.x == 0
        continue
      if cluster_stage == fs_cluster_stage && cluster_type == int(AmmoClusterType.SHELLS)
        v.ammo_per_type_data__numAmmoFs[glob_ammo_idx] += slot_ammo.x
      set_flag(v.ammo_per_type_data__state[glob_ammo_idx], AmmoStowagePerAmmoState.EMPTY, false)
      if cluster_stage == int(AmmoClusterStage.FIRST_STAGE)
        set_flag(v.ammo_per_type_data__state[glob_ammo_idx], AmmoStowagePerAmmoState.EMPTY_FIRST_STAGE, false)
      if cluster_stage == int(AmmoClusterStage.SECOND_STAGE)
        set_flag(v.ammo_per_type_data__state[glob_ammo_idx], AmmoStowagePerAmmoState.EMPTY_SECOND_STAGE, false)
      if get_flag(v.ammo_clusters__state[cluster_id], AmmoClusterState.AUTO_LOAD)
        set_flag(v.ammo_per_type_data__state[glob_ammo_idx], AmmoStowagePerAmmoState.EMPTY_AUTO_LOAD, false)

  
  
  
  
  
  
  
  
  if fs_cluster_stage == int(AmmoClusterStage.LOADED_IN_GUN)
    var need_redistribute_loaded_in_gun_ammo = false
    for ammo_type in 0..ammo_type_count
      let glob_ammo_idx = per_ammo_offset + ammo_type
      let ammo_type_remap = v.ammo_stowage__ammoTypeRemap[ammo_type]
      if ammo_type_remap.x != stowage_id
        
        continue
      
      
      if (v.ammo_per_type_data__numAmmoFs[glob_ammo_idx] == 0) != get_flag(v.ammo_per_type_data__state[glob_ammo_idx], AmmoStowagePerAmmoState.EMPTY_LOADED_AMMO)
        need_redistribute_loaded_in_gun_ammo = true
    if need_redistribute_loaded_in_gun_ammo
      
      sendEvent(unit.eid, EventAmmoStowageSetup(
        netSyncIfRequired = true,
        initNum = false,
        isRefill = false))

  return (ammo_hash, int2(per_ammo_offset, per_ammo_offset + ammo_type_count))


[with_bundle(v)]
def find_next_slots_to_replenish(stowage_id : int; amount : int;
                                 v : tuple<
                                   ammo_stowage__ammoTypeToMask : UInt32List;
                                   ammo_stowages__state : UInt32List;
                                   ammo_stowages__replenishmentStartEnd : Point2List;
                                   ammo_stowages__clustersRange : IPoint2List;
                                   ammo_clusters__state : UInt32List;
                                   ammo_clusters__typeAndStage : UInt16List;
                                   ammo_clusters__ammoClassConstraints : UInt32List;
                                   ammo_clusters__slotsRange : IPoint2List;
                                   ammo_slots__state : UInt32List;
                                   ammo_slots__ammoMaskAndType : UInt32List;
                                   ammo_slots__numAmmo : IPoint2List
                                   >) : tuple<from_cluster_slot_id : int2[2]; to_cluster_slot_id : int2[2]; ammo_type : int>
  assert(int(AmmoClusterType.NUM_TYPES) == 2)
  var from_slot_ids : int2[2]
  var to_slot_ids : int2[2]
  for cluster_type in 0..int(int(AmmoClusterType.NUM_TYPES))
    from_slot_ids[cluster_type] = int2(-1, -1)
    to_slot_ids[cluster_type] = int2(-1, -1)
  var replenished_ammo_type = -1
  var replenished_stage = int(AmmoClusterStage.SECOND_STAGE)

  var ammo_count_by_type : array<int>
  ammo_count_by_type |> resize(length(v.ammo_stowage__ammoTypeToMask))

  let replenishment_in_progress = v.ammo_stowages__replenishmentStartEnd[stowage_id].y > 0.f
  let replenish_only_empty = get_flag(v.ammo_stowages__state[stowage_id], AmmoStowageState.REPLENISH_ONLY_EMPTY)
  let clusters_range = v.ammo_stowages__clustersRange[stowage_id]
  for to_cluster_id in clusters_range.x..clusters_range.y
    
    let to_cluster_stage = get_ammo_cluster_stage(to_cluster_id, v)
    let to_cluster_type = get_ammo_cluster_type(to_cluster_id, v)
    if to_cluster_stage > replenished_stage || to_cluster_stage < int(AmmoClusterStage.FIRST_STAGE)
      continue
    let to_slots_range = v.ammo_clusters__slotsRange[to_cluster_id]
    
    if to_slot_ids[to_cluster_type].x != -1
      continue
    
    for ammo_count in ammo_count_by_type
      ammo_count = 0
    for to_slot_id in to_slots_range.x..to_slots_range.y
      let slot_ammo = v.ammo_slots__numAmmo[to_slot_id].x
      if slot_ammo > 0
        ammo_count_by_type[get_ammo_slot_type(to_slot_id, v)] += slot_ammo
    
    for to_slot_id in to_slots_range.x..to_slots_range.y
      if v.ammo_slots__numAmmo[to_slot_id].x == v.ammo_slots__numAmmo[to_slot_id].y
        continue 
      let to_slot_constraint = get_ammo_slot_class_mask(to_slot_id, v)
      for from_cluster_id in (clusters_range.x + 1)..clusters_range.y
        let from_cluster_stage = get_ammo_cluster_stage(from_cluster_id, v)
        let from_cluster_type = get_ammo_cluster_type(from_cluster_id, v)
        
        if from_cluster_stage <= to_cluster_stage
          continue
        if from_cluster_type != to_cluster_type
          continue
        if (v.ammo_clusters__ammoClassConstraints[from_cluster_id] & to_slot_constraint) == 0u
          continue
        
        let from_slots_range = v.ammo_clusters__slotsRange[from_cluster_id]
        for from_slot_id in from_slots_range.x..from_slots_range.y
          if v.ammo_slots__numAmmo[from_slot_id].x < amount
            continue
          let slot_ammo_type = get_ammo_slot_type(from_slot_id, v)
          
          if !ammo_stowage_can_add_ammo_to_slot(to_cluster_id, to_slot_id, amount, slot_ammo_type, v)
            continue
          
          if !(replenished_ammo_type == -1 || ammo_count_by_type[replenished_ammo_type] >= ammo_count_by_type[slot_ammo_type])
            continue
          
          if replenish_only_empty && !replenishment_in_progress && ammo_count_by_type[slot_ammo_type] > 0
            continue
          
          if replenished_ammo_type != slot_ammo_type && replenished_ammo_type != -1
            for cluster_type in 0..int(int(AmmoClusterType.NUM_TYPES))
              from_slot_ids[cluster_type] = int2(-1, -1)
              to_slot_ids[cluster_type] = int2(-1, -1)
          
          from_slot_ids[from_cluster_type] = int2(from_cluster_id, from_slot_id)
          to_slot_ids[to_cluster_type] = int2(to_cluster_id, to_slot_id)
          replenished_ammo_type = slot_ammo_type
          replenished_stage = to_cluster_stage
  return (from_slot_ids, to_slot_ids, replenished_ammo_type)


[es, with_bundle(v)]
def ammo_stowage_update_replenishment_and_state_es(info : ParallelUpdateFrameDelayed;
                                                   eid : EntityId;
                                                   var unit__ref : UnitRef;
                                                   v : tuple<
                                                     ammo_stowage__ammoState : uint;
                                                     ammo_stowage__weaponTriggers : IntList;
                                                     ammo_stowage__relatedPartsIds : PartIdList;
                                                     ammo_stowage__ammoTypeToMask : UInt32List;
                                                     ammo_stowage__ammoTypeRemap : IPoint4List;
                                                     ammo_stowage__weaponsIds : IntList;
                                                     ammo_stowages__state : UInt32List;
                                                     ammo_stowages__replenishmentStartEnd : Point2List -const;
                                                     ammo_stowages__replenishmentTime : Point2List -const;
                                                     ammo_stowages__weaponTriggersRange : IPoint2List;
                                                     ammo_stowages__bulletsCartridge : IntList;
                                                     ammo_stowages__clustersRange : IPoint2List;
                                                     ammo_stowages__cachedAmmoHash : UInt32List -const;
                                                     ammo_clusters__state : UInt32List;
                                                     ammo_clusters__typeAndStage : UInt16List;
                                                     ammo_clusters__ammoClassConstraints : UInt32List;
                                                     ammo_clusters__relatedPartsRange : IPoint2List;

                                                     ammo_clusters__slotsRange : IPoint2List;
                                                     ammo_slots__state : UInt32List -const;
                                                     ammo_slots__numAmmo : IPoint2List -const;
                                                     ammo_slots__ammoMaskAndType : UInt32List -const;
                                                     ammo_slots__partId : PartIdList;

                                                     ammo_per_type_data__state : UInt32List -const;
                                                     ammo_per_type_data__numAmmoFs : IntList -const
                                                     >)
  var unit = unit__ref.unit
  if unit.isDelayed
    return
  let allow_replenishment = !is_in_hangar()

  v.ammo_stowages__cachedAmmoHash |> resize(length(v.ammo_stowages__state))

  let current_time = float(get_app().usefulTotalTime)
  let weapon_controller = unit.weap
  for stowage_id, replenishment_start_end, replenishment_time, bullets_cartridge, triggers_range in iter_range(v.ammo_stowages__state), v.ammo_stowages__replenishmentStartEnd, v.ammo_stowages__replenishmentTime, v.ammo_stowages__bulletsCartridge, v.ammo_stowages__weaponTriggersRange
    
    let gathered_stowage_data = ammo_stowage_gather_and_update_ammo(unit, stowage_id, v)

    
    if replenishment_time.x < VERY_SMALL_NUMBER || !allow_replenishment || unit.isBurn
      replenishment_start_end = float2(-1.0f)
      v.ammo_stowages__cachedAmmoHash[stowage_id] = 0u
      continue

    
    var any_weapon_reloading = false
    for i in triggers_range.x..triggers_range.y
      if weapon_controller.Weapons |> is_weapon_reloading(v.ammo_stowage__weaponTriggers[i], current_time)
        any_weapon_reloading = true
    if any_weapon_reloading
      replenishment_start_end = float2(-1.0f)
      v.ammo_stowages__cachedAmmoHash[stowage_id] = 0u
      continue

    
    var can_reload = false
    for i in triggers_range.x..triggers_range.y
      if unit |> is_loading_crewman_available(v.ammo_stowage__weaponTriggers[i])
        can_reload = true
        break
    if !can_reload
      replenishment_start_end = float2(-1.0f)
      v.ammo_stowages__cachedAmmoHash[stowage_id] = 0u
      continue

    if gathered_stowage_data.hash != v.ammo_stowages__cachedAmmoHash[stowage_id]
      
      
      v.ammo_stowages__cachedAmmoHash[stowage_id] = gathered_stowage_data.hash
      let replenish = find_next_slots_to_replenish(stowage_id, bullets_cartridge, v)
      
      if replenish.ammo_type == -1
        replenishment_start_end = float2(-1.0f)
        continue
    elif replenishment_start_end.x < 0.f && replenishment_start_end.y < 0.f
      
      continue

    
    if replenishment_start_end.x < 0.0f
      replenishment_start_end.x = current_time +  replenishment_time.y
      continue

    
    if replenishment_start_end.x >= current_time && replenishment_start_end.y < 0.0f 
      replenishment_start_end.y = replenishment_start_end.x +  replenishment_time.x * unit.loaderPenalty

    
    if current_time > replenishment_start_end.y
      let cur_replenish = find_next_slots_to_replenish(stowage_id, bullets_cartridge, v)
      
      if cur_replenish.ammo_type == -1
        replenishment_start_end = float2(-1.0f)
        continue

      
      var dm_changed = false
      for cluster_type in 0..int(AmmoClusterType.NUM_TYPES)
        let from_cluster_slot_id = cur_replenish.from_cluster_slot_id[cluster_type]
        let to_cluster_slot_id = cur_replenish.to_cluster_slot_id[cluster_type]
        if from_cluster_slot_id.x == -1 || to_cluster_slot_id.x == -1
          continue
        ammo_stowage_extract_ammo_from_slot(from_cluster_slot_id.y, bullets_cartridge, v)
        ammo_stowage_add_ammo_to_slot_no_check(to_cluster_slot_id.y, bullets_cartridge, cur_replenish.ammo_type, v)
        dm_changed = ammo_slot_update_dm(unit, from_cluster_slot_id.y, v) || dm_changed
        dm_changed = ammo_slot_update_dm(unit, to_cluster_slot_id.y, v) || dm_changed
        dm_changed = ammo_cluster_balance_slots(unit, from_cluster_slot_id.x, true, v) || dm_changed
        dm_changed = ammo_cluster_balance_slots(unit, to_cluster_slot_id.x, true, v) || dm_changed
      
      if dm_changed
        sendEvent(eid, EventAmmoStowageInvalidateRenderer())

      
      let next_replenish = find_next_slots_to_replenish(stowage_id, bullets_cartridge, v)
      if next_replenish.ammo_type != -1
        replenishment_start_end.x = replenishment_start_end.y
        replenishment_start_end.y += replenishment_time.x * unit.loaderPenalty

      
      ammo_stowage_gather_and_update_ammo(unit, stowage_id, v)
      ammo_stowage_send_net_sync(eid) <| v






[es(no_order)]
def ammo_stowage_sync_num_ammo_fs_es(act : UpdateStageInfoAct;
                                     var ammo_per_type_data__numAmmoFsSync : IntList&;
                                     ammo_per_type_data__numAmmoFs : IntList)
  
  
  ammo_per_type_data__numAmmoFsSync := ammo_per_type_data__numAmmoFs


[es(on_event=EventOnStopBurn)]
def ammo_stowage_on_stop_burn_es(evt : Event;
                                 var unit__ref : UnitRef;
                                 var unit_fx : UnitFx;
                                 var ammo_clusters__state : UInt32List&;
                                 ammo_clusters__fireEvtId : IntList)

  let unit = unit__ref.unit
  if unit.isDelayed || !unit.isAuthority
    return
  for state, fire_event_id in ammo_clusters__state, ammo_clusters__fireEvtId
    if !get_flag(state, AmmoClusterState.FIRE_FATAL)
      unit_fx |> stopFxEvent(fire_event_id)


[es]
def ammo_stowage_reset_replenishment_es(evt : EventAmmoStowageResetReplenishment;
                                        eid : EntityId;
                                        unit__ref : UnitRef;
                                        ammo_stowages__state : UInt32List;
                                        var ammo_stowages__replenishmentStartEnd : Point2List&;
                                        ammo_stowages__replenishmentTime : Point2List)
  var unit = unit__ref.unit
  if unit.isDelayed
    return

  let current_time = float(get_app().usefulTotalTime)
  for stowage_id, replenishment_start_end, replanishment_time in iter_range(ammo_stowages__state), ammo_stowages__replenishmentStartEnd, ammo_stowages__replenishmentTime
    if replenishment_start_end.x <= 0.0 && replenishment_start_end.y <= 0.0
      continue

    if replenishment_start_end.x > current_time
      continue


    replenishment_start_end.x = current_time
    replenishment_start_end.y = current_time + replanishment_time.x * unit.loaderPenalty

    send_net_event(eid, EventAmmoStowageNetSyncReplanishmentReset(stowageId = stowage_id, endTime = replenishment_start_end.y))


[es(tag=netClient)]
def ammo_stowage_sync_reset_replenishment_es(evt : EventAmmoStowageNetSyncReplanishmentReset;
                                             var ammo_stowages__replenishmentStartEnd : Point2List&)
  if evt.stowageId < length(ammo_stowages__replenishmentStartEnd)
    let current_time = float(get_app().usefulTotalTime)
    ammo_stowages__replenishmentStartEnd[evt.stowageId] = float2(current_time, evt.endTime)
