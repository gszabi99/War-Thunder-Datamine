require ecs
require app
require Unit
require DagorMath
require DagorDataBlock
require DagorRandom
require IGroundModel
require dm
require DmFire
require WTDamageModel
require WarShipModel
require %game.events
require %game.unit_events
require %game.extinguish_system_events


def is_extinguisher_available(gm : IGroundModel?; count : int; count_max : int)
  return (gm != null && gm.extinguisher.isAvailable && count > 0) || count_max < 0


def is_extinguisher_active(is_burning : bool; is_assisting : bool; extinguish_end_time : float) : bool
  return (is_burning || is_assisting) && extinguish_end_time > 0.0


def is_crew_busy(is_burning : bool; is_assisting : bool; crew_busy_time_end : float) : bool
  return (is_burning || is_assisting) && crew_busy_time_end > 0.0


def can_be_extinguished_with_extinguisher(fire_damage : FireDamageComponent&)
  for fire_data in fire_damage.data
    if fire_data.startTime > 0.0lf
      let fire_params = get_fire_params(fire_data.fireParamsId)
      if fire_params.extinguisherEffective
        return true
  return false


// ---------------------------- extinguish system update -------------------------------

[es(no_order)]
def extinguish_system_update_es(act : UpdateStageInfoAct;
                                eid : EntityId;
                                uid : int;
                                fire_damage__isBurn : bool;
                                extinguish_system_is_assisting : bool;
                                var extinguish_system_extinguish_time_start : float&;
                                var extinguish_system_extinguish_time_end : float&;
                                extinguish_system_extinguisher_time_min : float;
                                var extinguish_system_crew_busy_time_end : float&;
                                var extinguish_system_next_extinguisher_time : float&;
                                var fire_system_require_net_sync : bool&;
                                var fire_damage : FireDamageComponent&)
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed || !unit.isAuthority
    return

  let gm = unit |> as_gm()
  let total_time = float(get_app().usefulTotalTime)

  if fire_damage__isBurn || extinguish_system_is_assisting
    if extinguish_system_crew_busy_time_end > 0.0 && extinguish_system_crew_busy_time_end < total_time
      extinguish_system_crew_busy_time_end = -1.0f
      sendEvent(eid, [[EventExtinguishSystemNotifyCrewBusy busy=false]])
      fire_system_require_net_sync = true

    // handle warships (TODO: move it to other system)
    if unit.isShip
      if extinguish_system_extinguish_time_end > extinguish_system_extinguish_time_start
        let time_to_extinguish = safediv(extinguish_system_extinguisher_time_min, gm.crewExtinguishSpeedMultiplier);
        var current_time_to_extinguish = 0.0;
        if (is_extinguisher_active(fire_damage__isBurn, extinguish_system_is_assisting, extinguish_system_extinguish_time_end) &&
            extinguish_system_extinguish_time_end > extinguish_system_extinguish_time_start)
          current_time_to_extinguish = extinguish_system_extinguish_time_end - extinguish_system_extinguish_time_start

        if time_to_extinguish + 1.0 < current_time_to_extinguish
          extinguish_system_extinguish_time_start = total_time - time_to_extinguish * (
            (total_time - extinguish_system_extinguish_time_start) / current_time_to_extinguish)
          extinguish_system_extinguish_time_end = extinguish_system_extinguish_time_start + time_to_extinguish
        else
          extinguish_system_extinguish_time_end += time_to_extinguish - current_time_to_extinguish

        if abs(time_to_extinguish - current_time_to_extinguish) > .5f
          fire_system_require_net_sync = true

    if 0.0 < extinguish_system_extinguish_time_end && extinguish_system_extinguish_time_end < total_time
      sendEvent(eid, [[EventExtinguishSystemStopBurnWithExtinguisher]])
      sendEvent(eid, [[EventExtinguishSystemTurnOffExtinguisher]])

    // update underwater
    if !is_extinguisher_active(fire_damage__isBurn, extinguish_system_is_assisting, extinguish_system_extinguish_time_end)
      for fire_data in fire_damage.data
        if fire_data.startTime < 0.0lf
          continue

        let is_underwater = is_fire_emitter_underwater(eid, fire_data)
        if is_underwater
          if fire_data.underwaterTimer < 0.0f
            fire_data.underwaterTimer = get_fire_params(fire_data.fireParamsId).underwaterExtinguishTime
        else
          fire_data.underwaterTimer = -1.0f

        if fire_data.underwaterTimer > 0.0f
          fire_data.underwaterTimer -= act.dt
          if fire_data.underwaterTimer <= 0.0f
            sendEvent(eid, [[EventFireSystemStopSingleBurn fireId=fire_data.id]])

  if extinguish_system_next_extinguisher_time < total_time && extinguish_system_next_extinguisher_time > 0.0f
    extinguish_system_next_extinguisher_time = -1.0f
    fire_system_require_net_sync = true


// ---------------------------- extinguish init & reset --------------------------------

[es]
def extinguish_system_init_mod_handle_es(evt : EventUnitInitModification;
                                         uid : int;
                                         var extinguish_system_auto_extinguisher : bool&;
                                         var extinguish_system_extinguisher_count : int&;
                                         var extinguish_system_extinguisher_count_max : int&;
                                         var extinguish_system_cooldown : float&;
                                         var extinguish_system_crew_busy_time : float&;
                                         var extinguish_system_extinguisher_time_min : float&;
                                         var extinguish_system_extinguisher_time_max : float&)
  if evt.modType != "extinguisher"
    return

  let unit = get_unit(uid)
  var gm = unit |> as_gm()
  assert(unit != null)

  let default_count = unit.isShip ? -1 : 0
  extinguish_system_auto_extinguisher = evt.blk |> datablock_getBool("automaticExtinguisher", false);
  extinguish_system_extinguisher_count_max = evt.blk |> datablock_getInt(
    "extinguisherActivationCount", gm != null && gm.extinguisher.isAvailable ? default_count : 0);

  var extinguisher_reduction_time = 0.0f;
  var extinguisher_activation_additional_count = 0;
  extinguish_system_cooldown = 0.f;

  let additional_count_name_id = evt.blk |> datablock_getNameId("extinguisherActivationAdditionalCount");
  let extinguisher_reduction_time_name_id = evt.blk |> datablock_getNameId("extinguisherReductionTime");
  let cooldown_name_id = evt.blk |> datablock_getNameId("extinguisherCooldown");

  if (additional_count_name_id >= 0 || extinguisher_reduction_time_name_id >= 0 || cooldown_name_id >= 0)
    for i in 0u..evt.blk.paramCount
      let param_name_id = evt.blk |> datablock_getParamNameId(i)
      let param_type = evt.blk |> datablock_getParamType(i)

      if param_name_id == additional_count_name_id && param_type == int(DataBlockParamType TYPE_INT)
        extinguisher_activation_additional_count += evt.blk |> datablock_getInt(int(i))
      elif param_name_id == extinguisher_reduction_time_name_id && param_type == int(DataBlockParamType TYPE_REAL)
        extinguisher_reduction_time += evt.blk |> datablock_getReal(int(i));
      elif param_name_id == cooldown_name_id
        extinguish_system_cooldown = evt.blk |> datablock_getReal(int(i));

  if (extinguish_system_extinguisher_count_max > 0)
    extinguish_system_extinguisher_count_max += extinguisher_activation_additional_count;

  if gm != null
    extinguish_system_extinguisher_count = min(gm.extinguisher.count, extinguish_system_extinguisher_count_max);
  if (extinguish_system_extinguisher_count_max < 0)
    extinguish_system_extinguisher_count = 0;
  extinguish_system_extinguisher_time_min = evt.blk |> datablock_getReal("extinguisherMinTime", 0.f) - extinguisher_reduction_time;
  extinguish_system_extinguisher_time_max = evt.blk |> datablock_getReal("extinguisherMaxTime", 0.f) - extinguisher_reduction_time;
  extinguish_system_extinguisher_time_min = max(extinguish_system_extinguisher_time_min, 0.0f);
  extinguish_system_extinguisher_time_max = max(extinguish_system_extinguisher_time_max, 0.0f);
  if (extinguish_system_extinguisher_time_max >= extinguish_system_extinguisher_time_min)
    extinguish_system_extinguisher_time_max = extinguish_system_extinguisher_time_min
  extinguish_system_crew_busy_time = evt.blk |> datablock_getReal("extinguisherCrewBusyTime", 5.f);

  if (gm != null)
    gm.haveExtinguish = (gm != null && gm.extinguisher.isAvailable &&
      extinguish_system_extinguisher_count > 0) || extinguish_system_extinguisher_count_max < 0


[es]
def extinguish_system_repair_handle_es(evt : EventUnitRepair;
                                       eid : EntityId;
                                       var extinguish_system_extinguish_time_start : float&;
                                       var extinguish_system_extinguish_time_end : float&;
                                       var extinguish_system_crew_busy_time_end : float&;
                                       var extinguish_system_is_assisting : bool&;
                                       var fire_system_require_net_sync : bool&)
  extinguish_system_extinguish_time_start = -1.0f
  extinguish_system_extinguish_time_end = -1.0f
  extinguish_system_crew_busy_time_end = -1.0f
  extinguish_system_is_assisting = false
  fire_system_require_net_sync = true
  sendEvent(eid, [[EventExtinguishSystemNotifyCrewBusy busy=false]])
  sendEvent(eid, [[EventFireSystemStopBurn]])


[es]
def extinguish_system_respawn_handle_es(evt : EventUnitRespawn;
                                        eid : EntityId;
                                        uid : int;
                                        var extinguish_system_extinguisher_count : int&;
                                        extinguish_system_extinguisher_count_max : int;
                                        var extinguish_system_extinguish_time_start : float&;
                                        var extinguish_system_extinguish_time_end : float&;
                                        var extinguish_system_crew_busy_time_end : float&;
                                        var extinguish_system_is_assisting : bool&;
                                        var fire_system_require_net_sync : bool&;
                                        var fire_damage : FireDamageComponent&)
  fire_damage.data |> clear()
  fire_damage.nextUpdateTime = -1.0lf

  let unit = get_unit(uid)
  let gm = unit |> as_gm()
  let extinguisher_count = gm != null && !unit.isDelayed ? gm.extinguisher.count : -1

  if extinguisher_count >= 0
    extinguish_system_extinguisher_count = min(extinguish_system_extinguisher_count_max, extinguisher_count)
  if extinguish_system_extinguisher_count_max < 0
    extinguish_system_extinguisher_count = 0

  extinguish_system_extinguish_time_start = -1.0f
  extinguish_system_extinguish_time_end = -1.0f
  extinguish_system_crew_busy_time_end = -1.0f
  extinguish_system_is_assisting = false
  fire_system_require_net_sync = true
  sendEvent(eid, [[EventExtinguishSystemNotifyCrewBusy busy=false]])
  sendEvent(eid, [[EventFireSystemStopBurn]])


// ---------------------------- extinguish other events --------------------------------

[es]
def extinguish_system_activate_handle_es(evt : EventExtinguishSystemSetActive;
                                         eid : EntityId;
                                         uid : int;
                                         var extinguish_system_extinguish_time_start : float&;
                                         var extinguish_system_extinguish_time_end : float&;
                                         var extinguish_system_crew_busy_time_end : float&;
                                         var extinguish_system_is_assisting : bool&;
                                         var fire_system_require_net_sync : bool&)
  let ship = get_unit(uid) |> as_ship()
  if ship == null || !ship.isVeryFewCrew
    if evt.active
      sendEvent(eid, [[EventExtinguishSystemActivateExtinguisher assisteeId=INVALID_ENTITY_ID]])
    else
      extinguish_system_extinguish_time_start = -1.0f
      extinguish_system_extinguish_time_end = -1.0f
      extinguish_system_crew_busy_time_end = -1.0f
      extinguish_system_is_assisting = false
      fire_system_require_net_sync = true
      sendEvent(eid, [[EventExtinguishSystemNotifyCrewBusy busy=false]])


[es]
def extinguish_system_activate_extinguisher_handle_es(evt : EventExtinguishSystemActivateExtinguisher;
                                                      eid : EntityId;
                                                      uid : int;
                                                      fire_damage__isBurn : bool;
                                                      var extinguish_system_is_assisting : bool&;
                                                      extinguish_system_extinguisher_count : int;
                                                      extinguish_system_extinguisher_count_max : int;
                                                      extinguish_system_extinguisher_time_min : float;
                                                      extinguish_system_extinguisher_time_max : float;
                                                      var extinguish_system_extinguish_time_start : float&;
                                                      var extinguish_system_extinguish_time_end : float&;
                                                      extinguish_system_next_extinguisher_time : float;
                                                      var extinguish_system_crew_busy_time_end : float&;
                                                      extinguish_system_crew_busy_time : float;
                                                      var fire_system_require_net_sync : bool&;
                                                      fire_damage : FireDamageComponent&)
  let is_assisting = evt.assisteeId != INVALID_ENTITY_ID
  let is_burning = fire_damage__isBurn
  if (is_burning && is_assisting) || (!is_burning && !is_assisting)
    return

  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  let gm = unit |> as_gm()

  if (is_extinguisher_available(gm, extinguish_system_extinguisher_count, extinguish_system_extinguisher_count_max) &&
      !is_extinguisher_active(is_burning, is_assisting, extinguish_system_extinguish_time_end) && extinguish_system_next_extinguisher_time < 0.0)
    if is_assisting
      query(evt.assisteeId) <| $ [es] (fire_damage : FireDamageComponent&)
        if !can_be_extinguished_with_extinguisher(fire_damage)
          sendEvent(eid, [[EventExtinguishSystemNotifyCantExtinguish]])
    elif !can_be_extinguished_with_extinguisher(fire_damage)
      sendEvent(eid, [[EventExtinguishSystemNotifyCantExtinguish]])
      return

    let total_time = float(get_app().usefulTotalTime)

    if unit.isTank && !is_assisting
      extinguish_system_crew_busy_time_end = max(total_time + extinguish_system_crew_busy_time, extinguish_system_crew_busy_time_end)

    if unit.isAuthority
      if extinguish_system_extinguisher_count_max > 0
        sendEvent(eid, [[EventExtinguishSystemSpendExtinghuisher]])

      var time_to_extinguish = rnd_float(extinguish_system_extinguisher_time_min, extinguish_system_extinguisher_time_max)
      if unit.isShip
        extinguish_system_extinguish_time_end = 1.0f
        time_to_extinguish = safediv(extinguish_system_extinguisher_time_min, gm.crewExtinguishSpeedMultiplier)

      extinguish_system_extinguish_time_start = total_time
      extinguish_system_extinguish_time_end = extinguish_system_extinguish_time_start + time_to_extinguish
      extinguish_system_is_assisting = is_assisting
      sendEvent(eid, [[EventExtinguishSystemNotifyCrewBusy busy=true]])
      fire_system_require_net_sync = true
    sendEvent(eid, [[EventExtinguishSystemOnExtinguisherActivate active=true]])


[es]
def extinguish_system_stop_burn_with_extinguisher_handle_es(evt : EventExtinguishSystemStopBurnWithExtinguisher;
                                                            eid : EntityId;
                                                            uid : int;
                                                            var extinguish_system_is_assisting : bool&;
                                                            var extinguish_system_next_extinguisher_time : float&;
                                                            var extinguish_system_last_extinguish_time : float&;
                                                            extinguish_system_cooldown : float;
                                                            var fire_system_require_net_sync : bool&;
                                                            fire_damage : FireDamageComponent&)
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return

  var all_extinguished = false
  if !extinguish_system_is_assisting
    for fire_data in fire_damage.data
      let fire_params = get_fire_params(fire_data.fireParamsId)
      if fire_params == null || fire_params.extinguisherEffective
        sendEvent(eid, [[EventFireSystemStopSingleBurn fireId=fire_data.id]])
      else
        all_extinguished = false

  let total_time = float(get_app().usefulTotalTime)
  extinguish_system_next_extinguisher_time = total_time + extinguish_system_cooldown
  extinguish_system_last_extinguish_time = total_time + extinguish_system_cooldown
  extinguish_system_is_assisting = false

  sendEvent(eid, [[EventExtinguishSystemNotifyCrewBusy busy=false]])
  sendEvent(eid, [[EventExtinguishSystemNotifyExtinghuished]])
  if all_extinguished
    sendEvent(eid, [[EventFireSystemStopBurn]])
  fire_system_require_net_sync = true


[es]
def extinguish_system_extinguish_by_ally_handle_es(evt : EventExtinguishSystemExtinguishByAlly;
                                                   eid : EntityId;
                                                   uid : int;
                                                   fire_damage__isBurn : bool;
                                                   extinguish_system_is_assisting : bool;
                                                   extinguish_system_extinguisher_count : int;
                                                   extinguish_system_extinguisher_count_max : int;
                                                   var extinguish_system_extinguish_time_start : float&;
                                                   var extinguish_system_extinguish_time_end : float&;
                                                   extinguish_system_next_extinguisher_time : float;
                                                   var fire_system_require_net_sync : bool&;
                                                   fire_damage : FireDamageComponent&)
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  let gm = unit |> as_gm()
  let is_burning = fire_damage__isBurn

  if (is_burning &&
      !is_extinguisher_available(gm, extinguish_system_extinguisher_count, extinguish_system_extinguisher_count_max) &&
      !is_extinguisher_active(is_burning, extinguish_system_is_assisting, extinguish_system_extinguish_time_end) &&
      extinguish_system_next_extinguisher_time < 0.0)
    if !can_be_extinguished_with_extinguisher(fire_damage)
      return

    if unit == null
      return

    if unit.isAuthority
      unsafe
        var start_time : float& = extinguish_system_extinguish_time_start
        var end_time : float& = extinguish_system_extinguish_time_end
        query(evt.assistantId) <| $ [es] (extinguish_system_extinguish_time_start : float; extinguish_system_extinguish_time_end : float)
          start_time = extinguish_system_extinguish_time_start
          end_time = extinguish_system_extinguish_time_end
    sendEvent(eid, [[EventExtinguishSystemNotifyCrewBusy busy=true]])
    sendEvent(eid, [[EventExtinguishSystemOnExtinguisherActivate active=true]])
    fire_system_require_net_sync = true


[es]
def extinguish_system_spend_extinguisher_handle_es(evt : EventExtinguishSystemSpendExtinghuisher;
                                                   uid : int;
                                                   var extinguish_system_extinguisher_count : int&;
                                                   extinguish_system_extinguisher_count_max : int)
  if (extinguish_system_extinguisher_count > 0 && extinguish_system_extinguisher_count_max > 0)
    --extinguish_system_extinguisher_count;

  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  let gm = unit |> as_gm()
  if gm != null
    gm.extinguisher |> spend_expandable_modification()


[es]
def extinguish_system_turn_off_extinguisher_handle_es(evt : EventExtinguishSystemTurnOffExtinguisher;
                                                      eid : EntityId;
                                                      var extinguish_system_is_assisting : bool&;
                                                      var extinguish_system_extinguish_time_end : float&)
  if extinguish_system_extinguish_time_end > 0.0f
    extinguish_system_extinguish_time_end = -1.0f
    extinguish_system_is_assisting = false
    sendEvent(eid, [[EventExtinguishSystemOnExtinguisherActivate active=false]])


[es]
def extinguish_system_add_extinguisher_count_handle_es(evt : EventExtinguishSystemAddExtinguisherCount;
                                                       var extinguish_system_extinguisher_count : int&;
                                                       var extinguish_system_extinguisher_count_max : int&)
  extinguish_system_extinguisher_count = min(255, extinguish_system_extinguisher_count + evt.count)
  extinguish_system_extinguisher_count_max = extinguish_system_extinguisher_count // <--- ???


[es]
def fire_system_stop_single_burn_handle_es(evt : EventFireSystemStopSingleBurn;
                                           eid : EntityId;
                                           var fire_system_require_net_sync : bool&;
                                           var fire_damage : FireDamageComponent&)
  if evt.fireId >= 0 && evt.fireId < length(fire_damage.data)
    sendEvent(eid, [[EventOnStopSingleBurn fireId=evt.fireId, initiatorId=fire_damage.data[evt.fireId].initiatorId]])
    fire_damage.data[evt.fireId].startTime = -1.0lf;
    fire_damage.data[evt.fireId].initiatorId = -1u;
    fire_system_require_net_sync = true


// -------------------------------- fire net sync --------------------------------------

[es(after=extinguish_system_update_es, tag=server)]
def fire_system_net_sync_update_es(act : UpdateStageInfoAct;
                                   eid : EntityId;
                                   extinguish_system_extinguisher_count : int;
                                   extinguish_system_is_assisting : bool;
                                   extinguish_system_crew_busy_time_end : float;
                                   extinguish_system_extinguish_time_end : float;
                                   extinguish_system_next_extinguisher_time : float;
                                   var fire_system_require_net_sync : bool&;
                                   fire_damage__isBurn : bool;
                                   fire_damage : FireDamageComponent&)
  if fire_system_require_net_sync
    let total_time = float(get_app().usefulTotalTime)

    var evt = new EventFireSystemNetSync
    evt.isBurning = fire_damage__isBurn
    evt.extinguisherCount = extinguish_system_extinguisher_count
    evt.crewBusyRemainingTime = is_crew_busy(fire_damage__isBurn, extinguish_system_is_assisting, extinguish_system_crew_busy_time_end) ? extinguish_system_crew_busy_time_end - total_time : -1.0f
    evt.extinguisherRemainingTime = is_extinguisher_active(fire_damage__isBurn, extinguish_system_is_assisting, extinguish_system_extinguish_time_end) ? extinguish_system_extinguish_time_end - total_time : -1.0f
    evt.timeToNextExtinguisher = extinguish_system_next_extinguisher_time

    for fire_data in fire_damage.data
      evt.partIds |> push(fire_data.partNo)
      evt.fireParamsIds |> push(fire_data.fireParamsId)
      evt.partsBurning |> push(fire_data.startTime >= 0.0lf);

    sendEvent(eid, *evt)
    unsafe
      delete(evt)
    fire_system_require_net_sync = false


[es(tag=netClient)]
def fire_system_net_sync_handle_es(evt : EventFireSystemNetSync;
                                   eid : EntityId;
                                   extinguish_system_is_assisting : bool;
                                   var extinguish_system_crew_busy_time_end : float&;
                                   var extinguish_system_extinguish_time_start : float&;
                                   var extinguish_system_extinguish_time_end : float&;
                                   var extinguish_system_next_extinguisher_time : float&;
                                   var extinguish_system_extinguisher_count : int&;
                                   var fire_damage__isBurn : bool&;
                                   var fire_damage : FireDamageComponent&)
  let total_time = float(get_app().usefulTotalTime)
  let was_burning = fire_damage__isBurn;
  let was_extinguisher_active = is_extinguisher_active(fire_damage__isBurn, extinguish_system_is_assisting, extinguish_system_extinguish_time_end)

  fire_damage__isBurn = evt.isBurning;
  extinguish_system_extinguisher_count = evt.extinguisherCount;
  extinguish_system_crew_busy_time_end = evt.crewBusyRemainingTime > 0.0 ? evt.crewBusyRemainingTime + total_time : -1.0f
  extinguish_system_extinguish_time_start = evt.extinguisherRemainingTime > 0.0f ? total_time : 0.0f
  extinguish_system_extinguish_time_end = evt.extinguisherRemainingTime > 0.0f ? evt.extinguisherRemainingTime + total_time : 0.0f
  extinguish_system_next_extinguisher_time = evt.timeToNextExtinguisher

  sendEventImmediate(eid, [[EventExtinguishSystemNotifyCrewBusy busy=is_crew_busy(fire_damage__isBurn, extinguish_system_is_assisting, extinguish_system_crew_busy_time_end)]])
  if !was_extinguisher_active && evt.extinguisherRemainingTime > 0.0f
    sendEvent(eid, [[EventExtinguishSystemOnExtinguisherActivate active=true]])
  if !was_burning && evt.isBurning
    sendEvent(eid, [[EventFireSystemOnStartBurnNoOffender]])
  elif was_burning && !evt.isBurning
    sendEvent(eid, [[EventFireSystemStopBurn]])

  for part_id, fire_params_id, is_part_burning in evt.partIds, evt.fireParamsIds, evt.partsBurning
    var fire_found = false
    for fire_data in fire_damage.data
      if fire_data.partNo == part_id
        fire_found = true
        if !is_part_burning
          sendEvent(eid, [[EventFireSystemStopSingleBurn fireId=fire_data.id]])
        break
    if !fire_found && is_part_burning
      sendEvent(eid, [[EventFireSystemStartSingleBurn partId=int(part_id), fireParamsId=fire_params_id]])

