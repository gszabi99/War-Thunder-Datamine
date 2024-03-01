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
  // water is cleared upon repair/respawn, so it is safe to just set FLOODED to false for all slots
  for state in v.ammo_slots__state
    set_flag(state, AmmoSlotState ENABLED, true)
    set_flag(state, AmmoSlotState FLOODED, false)


[es, with_bundle(v)]
def ammo_stowage_respawn_handle(evt : EventUnitRespawn; eid : EntityId;
                                var v : tuple<
                                  ammo_slots__state : UInt32List
                                >) : void
  ammo_stowage_restore_slots() <| v
  sendEvent(eid, [[EventBulletsAmountChanged isRefill=true]])


[es, with_bundle(v)]
def ammo_stowage_repair_handle(evt : EventUnitRepair; eid : EntityId;
                               var v : tuple<
                                 ammo_slots__state : UInt32List
                               >) : void
  ammo_stowage_restore_slots() <| v
  sendEvent(eid, [[EventBulletsAmountChanged isRefill=false]])


[with_bundle(v)]
def can_replenish_to_cluster(cluster_id : int; bullets_cartridge : int; v : tuple<ammo_clusters__numAmmo : IPoint3List>) : bool
  return v.ammo_clusters__numAmmo[cluster_id].x + bullets_cartridge <= v.ammo_clusters__numAmmo[cluster_id].z

[with_bundle(v)]
def can_replenish_from_cluster(cluster_id : int; bullets_cartridge : int; v : tuple<ammo_clusters__numAmmo : IPoint3List>) : bool
  return v.ammo_clusters__numAmmo[cluster_id].x >= bullets_cartridge

[es, with_bundle(v)]
def ammo_stowage_replenishment_updater_es(info : ParallelUpdateFrameDelayed;
                                          active : bool;
                                          eid : EntityId;
                                          uid : int;
                                          v : tuple<
                                            ammo_stowage__weaponTriggers : IntList;
                                            ammo_stowages__state : UInt32List;
                                            ammo_stowages__replenishmentStartEnd : Point2List- const;
                                            ammo_stowages__replenishmentTime : Point2List- const;
                                            ammo_stowages__weaponTriggersRange : IPoint2List;
                                            ammo_stowages__bulletsCartridge : IntList;
                                            ammo_stowages__clustersRange : IPoint2List;
                                            ammo_clusters__typeAndStage : UInt16List;
                                            ammo_clusters__numAmmo : IPoint3List- const
                                          >)
  if get_app().isInHangar
    return
  var unit = get_unit(uid)
  if unit == null || unit.isDelayed || !active
    return

  let current_time = float(get_app().usefulTotalTime)
  let weapon_controller = unit.weap
  for stowage_state, replenishment_start_end, replenishment_time, bullets_cartridge, triggers_range, clusters_range in v.ammo_stowages__state, v.ammo_stowages__replenishmentStartEnd, v.ammo_stowages__replenishmentTime, v.ammo_stowages__bulletsCartridge, v.ammo_stowages__weaponTriggersRange, v.ammo_stowages__clustersRange
    if replenishment_time.x < VERY_SMALL_NUMBER
      continue
    if unit.isBurn
      replenishment_start_end = float2(-1.0f)
      continue

    // gather total ammo count in each stage (for all types)
    assert(int(AmmoClusterStage NUM_STAGES) == 4)
    var num_ammo_in_stage : int3[4]
    for cluster_id in clusters_range.x..clusters_range.y
      var cluster_ammo = v.ammo_clusters__numAmmo[cluster_id];
      cluster_ammo.x = (cluster_ammo.x / bullets_cartridge) * bullets_cartridge; // round down just in case
      num_ammo_in_stage[get_ammo_cluster_stage(cluster_id, v)] += cluster_ammo

    // find pair of stages we can replenish to and from
    var stage_to_replenish_to = -1
    var stage_to_replenish_from = -1
    for to_stage in int(AmmoClusterStage FIRST_STAGE)..int(AmmoClusterStage NO_RELOAD)
      // for flag REPLENISH_ONLY_EMPTY: dont replenish non-empty stages, if replenishment havent started yet
      if get_flag(stowage_state, AmmoStowageState REPLENISH_ONLY_EMPTY) && replenishment_start_end.x < 0.0 && num_ammo_in_stage[to_stage].x > 0
        continue
      if num_ammo_in_stage[to_stage].x + bullets_cartridge <= num_ammo_in_stage[to_stage].z
        for from_stage in(to_stage + 1)..int(AmmoClusterStage NUM_STAGES)
          if num_ammo_in_stage[from_stage].x >= bullets_cartridge
            stage_to_replenish_from = from_stage // dont break here, we want the last available stage
        if stage_to_replenish_from != -1
          stage_to_replenish_to = to_stage
          break

    // if there is no stages to replenish - cancel replenishment
    if stage_to_replenish_to == -1
      replenishment_start_end = float2(-1.0f)
      continue

    // reset progress if weapon is reloading, however dont do this if weapon is blocked due to empty stage
    var check_weapon_reloading = false
    if get_flag(stowage_state, AmmoStowageState HAS_AUTO_LOAD)
      check_weapon_reloading = num_ammo_in_stage[int(AmmoClusterStage FIRST_STAGE)].x > 0
    else
      check_weapon_reloading = num_ammo_in_stage[int(AmmoClusterStage SECOND_STAGE)].x > 0 || num_ammo_in_stage[int(AmmoClusterStage FIRST_STAGE)].x > 0
    if check_weapon_reloading
      var end_stowage_update = false
      for i in triggers_range.x..triggers_range.y
        if weapon_controller.Weapons |> is_weapon_reloading(v.ammo_stowage__weaponTriggers[i], current_time)
          replenishment_start_end = float2(-1.0f)
          end_stowage_update = true
          break
      if end_stowage_update
        continue

    // cancel replenishment if there is no loader available
    var can_reload = false
    for i in triggers_range.x..triggers_range.y
      if unit |> is_loading_crewman_available(v.ammo_stowage__weaponTriggers[i])
        can_reload = true
        break
    if !can_reload
      replenishment_start_end = float2(-1.0f)
      continue

    // start replenishment delay if it havent started yet
    if replenishment_start_end.x < 0.0f
      replenishment_start_end.x = current_time + /* delay */ replenishment_time.y
      continue

    // start replenishment after a delay
    if replenishment_start_end.x >= current_time && replenishment_start_end.y < 0.0f // start after delay
      replenishment_start_end.y = replenishment_start_end.x + /* time */ replenishment_time.x * unit.loaderPenalty

    // do replenishment
    if current_time > replenishment_start_end.y
      // replenish all types of clusters
      var can_continue_replenishment = false
      assert(int(AmmoClusterType NUM_TYPES) == 2)
      var is_replenished_by_type : bool[2] = [[bool false; false]]
      for to_cluster_id in clusters_range.x..clusters_range.y
        let cluster_type = get_ammo_cluster_type(to_cluster_id, v)
        if is_replenished_by_type[cluster_type] || get_ammo_cluster_stage(to_cluster_id, v) != stage_to_replenish_to
          continue
        if !can_replenish_to_cluster(to_cluster_id, bullets_cartridge, v)
          continue
        for from_cluster_id in clusters_range.x..clusters_range.y
          if cluster_type != get_ammo_cluster_type(from_cluster_id, v) || get_ammo_cluster_stage(from_cluster_id, v) != stage_to_replenish_from
            continue
          if !can_replenish_from_cluster(from_cluster_id, bullets_cartridge, v)
            continue
          is_replenished_by_type[cluster_type] = true;
          v.ammo_clusters__numAmmo[to_cluster_id].x += bullets_cartridge
          v.ammo_clusters__numAmmo[from_cluster_id].x -= bullets_cartridge
          if can_replenish_to_cluster(to_cluster_id, bullets_cartridge, v) && can_replenish_from_cluster(from_cluster_id, bullets_cartridge, v)
            can_continue_replenishment = true
          break

      // continue replenishment, if it is available
      if can_continue_replenishment
        replenishment_start_end.x = replenishment_start_end.y
        replenishment_start_end.y += /* time */ replenishment_time.x * unit.loaderPenalty

      // sync
      sendEvent(eid, [[EventAmmoStowageSetup
        netSyncIfRequired=true,
        initNum=false,
        isRefill=false
      ]])


[es(on_event=EventOnStopBurn)]
def ammo_stowage_on_stop_burn_es(evt : Event;
                                 uid : int; active : bool;
                                 var unit_fx : UnitFx;
                                 var ammo_clusters__state : UInt32List&;
                                 ammo_clusters__fireEvtId : IntList)

  let unit = get_unit(uid)
  if !active || unit == null || unit.isDelayed || !unit.isAuthority
    return

  for state, fire_event_id in ammo_clusters__state, ammo_clusters__fireEvtId
    if !get_flag(state, AmmoClusterState FIRE_FATAL)
      unit_fx |> stopFxEvent(fire_event_id)


[es]
def ammo_stowage_cancel_replenishment_es(evt : EventAmmoStowageCancelReplenishment;
                                         var ammo_stowages__replenishmentStartEnd : Point2List&)
  for start_end in ammo_stowages__replenishmentStartEnd
    start_end.x = -1.0f
    start_end.y = -1.0f

