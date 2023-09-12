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


[es, with_bundle(v)]
def ammo_stowage_replenishment_updater_es(info : ParallelUpdateFrameDelayed;
                                          active : bool;
                                          eid : EntityId;
                                          uid : int;
                                          v : tuple<
                                            ammo_stowages__state : UInt32List;
                                            ammo_stowages__replenishmentStartEnd : Point2List- const;
                                            ammo_stowages__replenishmentTime : Point2List- const;
                                            ammo_stowages__weaponTriggersRange : IPoint2List;
                                            ammo_stowages__numAmmo : IPoint3List- const;
                                            ammo_stowages__numAmmoFirstStage : IPoint3List- const;
                                            ammo_stowage__weaponTriggers : IntList
                                          >)
  var unit = get_unit(uid)
  if unit == null || unit.isDelayed || !active
    return

  let current_time = float(get_app().usefulTotalTime)
  let weapon_controller = unit.weap
  for state, replenishment_start_end, replenishment_time, num_ammo, num_ammo_first_stage, triggers_range in v.ammo_stowages__state, v.ammo_stowages__replenishmentStartEnd, v.ammo_stowages__replenishmentTime, v.ammo_stowages__numAmmo, v.ammo_stowages__numAmmoFirstStage, v.ammo_stowages__weaponTriggersRange
    if replenishment_time.x < VERY_SMALL_NUMBER || num_ammo_first_stage.z <= 0
      continue

    if (num_ammo_first_stage.x >= num_ammo_first_stage.z ||
        num_ammo_first_stage.x >= num_ammo.x ||
        unit.isBurn)
      replenishment_start_end = float2(-1.0f)
      continue

    if (!get_flag(state, AmmoStowageState HAS_AUTO_LOAD) ||
        num_ammo_first_stage.x > (get_flag(state, AmmoStowageState REMOVE_LOADED_AMMO) ? -1 : 0))
      var end_stowage_update = false
      for i in triggers_range.x..triggers_range.y
        if weapon_controller.Weapons |> is_weapon_reloading(v.ammo_stowage__weaponTriggers[i], current_time)
          replenishment_start_end.x = -1.0f
          replenishment_start_end.y = -1.0f
          end_stowage_update = true
          break
      if end_stowage_update
        continue

    var can_reload = false
    for i in triggers_range.x..triggers_range.y
      if unit |> is_loading_crewman_available(v.ammo_stowage__weaponTriggers[i])
        can_reload = true
        break
    if !can_reload
      replenishment_start_end.x = -1.0f
      replenishment_start_end.y = -1.0f
      continue

    if replenishment_start_end.x < 0.0f
      replenishment_start_end.x = current_time + /* delay */ replenishment_time.y
      continue

    if replenishment_start_end.x >= current_time && replenishment_start_end.y < 0.0f
      replenishment_start_end.y = replenishment_start_end.x + /* time */ replenishment_time.x * unit.loaderPenalty

    if current_time > replenishment_start_end.y
      num_ammo_first_stage.x++
      if num_ammo_first_stage.x < num_ammo_first_stage.y && num_ammo_first_stage.x < num_ammo.x
        replenishment_start_end.x = replenishment_start_end.y
        replenishment_start_end.y += /* time */ replenishment_time.x * unit.loaderPenalty
      sendEvent(eid, [[EventAmmoStowageSetup
        netSyncIfRequired=true,
        canLoadToBreach=true,
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

