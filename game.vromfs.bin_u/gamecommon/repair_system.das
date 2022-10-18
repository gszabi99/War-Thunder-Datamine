require ecs
require dm
require app
require DagorMath
require DagorRandom
require DagorDataBlock
require Unit
require IGroundModel
require WTDamageModel
require %game.unit_events
require %game.dm_events
require %game.repair_system_events


def get_flag(repair_state : uint; flag) : bool
  return (repair_state & uint(flag)) != 0u;

def set_flag(var repair_state : uint&; flag; set : bool)
  if set
    repair_state |= uint(flag)
  else
    repair_state &= ~uint(flag)


def load_repair_parts(blk : DataBlock;
                      override_by_part_id : bool;
                      var repair_system_parts_id : IntList&;
                      var repair_system_parts_state : UInt32List&;
                      var repair_system_parts_hp : Point4List&;
                      var repair_system_parts_speed_mult : FloatList&)

  let part_repair_hp_val = blk |> datablock_getReal("partRepairHp", 0.7f)
  let part_hp_for_repair_val = blk |> datablock_getReal("hpForRepair", 0.0f)
  blk |> datablock_for_each_block() <| $(part_blk)
    let part_id = get_dm_part_id_by_dm_name(part_blk.getBlockName, true)
    if part_id < 0
      return

    let repair_speed = part_blk |> datablock_getReal("speed", 1.0f)
    let repair_hp_val = part_blk |> datablock_getReal("partRepairHp", part_repair_hp_val)
    let hp_for_repair = part_blk |> datablock_getReal("hpForRepair", part_hp_for_repair_val)
    let serially_repaired = part_blk |> datablock_getBool("serially", false)
    let completely_repair = part_blk |> datablock_getBool("completely", false)
    let mod_required = part_blk |> datablock_getBool("modRequired", true)
    assert(repair_speed > 0.0f)

    var part_state = 0u
    set_flag(part_state, DmPartRepairState SERIALLY_REPAIR, serially_repaired)
    set_flag(part_state, DmPartRepairState COMPLETELY_REPAIR, completely_repair)
    set_flag(part_state, DmPartRepairState MOD_REQUIRED, mod_required)
    set_flag(part_state, DmPartRepairState ALLOW_REPAIR, true)

    var overriden = false
    if override_by_part_id
      for i in 0..length(repair_system_parts_id)
        if repair_system_parts_id[i] == part_id
          repair_system_parts_state[i] = part_state
          repair_system_parts_hp[i] = float4(0.0f, 0.0f, repair_hp_val, hp_for_repair)
          repair_system_parts_speed_mult[i] = repair_speed
          overriden = true

    if !overriden
      repair_system_parts_id |> push(part_id)
      repair_system_parts_state |> push(part_state)
      repair_system_parts_hp |> push(float4(0.0f, 0.0f, repair_hp_val, hp_for_repair))
      repair_system_parts_speed_mult |> push(repair_speed)


[es]
def repair_system_init_handle_es(evt : CmdInitComponent;
                                 uid : int;
                                 var repair_system_state : uint&;
                                 var repair_system_parts_id : IntList&;
                                 var repair_system_parts_state : UInt32List&;
                                 var repair_system_parts_hp : Point4List&;
                                 var repair_system_parts_speed_mult : FloatList&)
  let unit = get_unit(uid);
  assert(unit != null)

  set_flag(repair_system_state, RepairState INITIALIZED, true)
  set_flag(repair_system_state, RepairState SUITABLE_FOR_REPAIR, false)
  set_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY, false)
  set_flag(repair_system_state, RepairState WAS_REPAIRING_WITHOUT_MODS, false)
  set_flag(repair_system_state, RepairState REPAIR_DELAY_FOR_START, true)

  load_repair_parts(
    unit.isTank || unit.isWalker ? get_dm_params().tankRepairParts : get_dm_params().shipRepairParts, false,
    repair_system_parts_id,
    repair_system_parts_state,
    repair_system_parts_hp,
    repair_system_parts_speed_mult
  )

  *evt.modelBlk |> datablock_get_block("repairParts") <| $(repar_parts_blk)
    load_repair_parts(
      repar_parts_blk, true,
      repair_system_parts_id,
      repair_system_parts_state,
      repair_system_parts_hp,
      repair_system_parts_speed_mult
    )


[es]
def repair_system_init_mod_handle_es(evt : EventUnitInitModification;
                                     uid : int;
                                     var repair_system_state : uint&;
                                     var repair_system_toolkit_count : int&;
                                     var repair_system_toolkit_count_max : int&;
                                     var repair_system_speed_multiplier_base : float&)
  if evt.modType != "toolkit"
    return

  var gm = get_unit(uid) |> as_gm()
  let toolkit = gm != null ? gm.toolkit : null

  repair_system_toolkit_count_max = evt.blk |> datablock_getInt("toolkitActivationCount", -1)
  if toolkit != null
    repair_system_toolkit_count = min(toolkit.count, repair_system_toolkit_count_max)
  if repair_system_toolkit_count_max < 0
    repair_system_toolkit_count = 0

  let repair_available_without_toolkit = evt.blk |> datablock_getBool("repairAvailable", false)
  set_flag(repair_system_state, RepairState REPAIR_AVAILABLE_WITHOUT_TOOLKIT, repair_available_without_toolkit)

  repair_system_speed_multiplier_base = 1.0f
  let speed_mult_name_id = evt.blk |> datablock_getNameId("speedMultiplier")
  for i in 0u..evt.blk.paramCount
    if evt.blk |> datablock_getParamType(i) == int(DataBlockParamType TYPE_REAL) && evt.blk |> datablock_getParamNameId(i) == speed_mult_name_id
      repair_system_speed_multiplier_base *= evt.blk |> datablock_getReal(int(i))

  if gm != null
    gm.haveRepair = repair_system_toolkit_count_max < 0 && repair_available_without_toolkit

def is_repair_with_mods_availabile(repair_state : uint) : bool
  return ((
    get_flag(repair_state, RepairState REPAIR_AVAILABLE) ||
    get_flag(repair_state, RepairState NEED_REPAIR_HELP) ||
    get_flag(repair_state, RepairState REPAIR_ON_BASE)
  ) && !get_flag(repair_state, RepairState REPAIR_WITHOUT_MODS_ONLY))


def can_repair_part(dm : DamageableVisualModel; part_id : int; part_state : uint; part_hp : float4; repair_with_mods_available : bool)
  return (
    get_flag(part_state, DmPartRepairState ALLOW_REPAIR) &&
    (!get_flag(part_state, DmPartRepairState MOD_REQUIRED) || repair_with_mods_available) &&
    dm |> dm_is_dmg_part_active(part_id) && dm |> dm_get_rel_hp(part_id) <= part_hp.w
  )


def is_repair_needed(unit : Unit?; repair_state : uint; speed_multiplier : float;
                     parts_id : IntList; parts_state : UInt32List; parts_hp : Point4List;
                     with_mods : bool; without_mods : bool; with_help : bool) : bool
  if unit.isGroundModel && speed_multiplier > 0.0f
    assume dm = *unit.visual
    for part_id, part_state, part_hp in parts_id, parts_state, parts_hp
      if can_repair_part(dm, part_id, part_state, part_hp, true)
        if !get_flag(part_state, DmPartRepairState MOD_REQUIRED)
          if without_mods
            return true
        elif with_mods
          if with_help || get_flag(repair_state, RepairState REPAIR_AVAILABLE) || get_flag(repair_state, RepairState REPAIR_ON_BASE)
            return true
  return false


def can_start_repair(unit : Unit?; repair_state : uint; speed_multiplier : float;
                     parts_id : IntList; parts_state : UInt32List; parts_hp : Point4List;
                     remaining_repair_time : float; delay_time_to_repair : float; repair_by_ally : bool) : bool
  return (
    delay_time_to_repair <= 0.0f &&
    is_repair_needed(unit, repair_state, speed_multiplier, parts_id, parts_state, parts_hp, true, true, repair_by_ally) &&
    (
      remaining_repair_time <= 0.0f ||
      (is_repair_needed(unit, repair_state, speed_multiplier, parts_id, parts_state, parts_hp, true, true, false) &&
       get_flag(repair_state, RepairState REPAIR_WITHOUT_MODS_ONLY))
    )
  )


def can_stop_repair(repair_state : uint; remaining_repair_time : float) : bool
  return !get_flag(repair_state, RepairState REPAIR_WITHOUT_MODS_ONLY) && remaining_repair_time > 0.0f


def get_part_repair_hp(unit : Unit?; part_id : int) : float
  return *unit.visual |> dm_get_dmg_part_hp(part_id)


def get_part_needed_hp(dm; part_id : int; var part_hp : float4&)
  if part_hp.y <= 0.0f
    let part_repair_hp_val = part_hp.z
    return dm |> dm_get_part_hp_prop(part_id) * part_repair_hp_val
  return part_hp.y


def get_part_current_hp(dm; part_id : int; part_state : uint; var part_hp : float4&)
  if !get_flag(part_state, DmPartRepairState IN_PROGRESS)
    return dm |> dm_get_dmg_part_hp(part_id)
  return part_hp.x


def calc_time_to_repair(unit : Unit?; speed_multiplier : float;
                        repair_system_parts_id : IntList; repair_system_parts_state : UInt32List;
                        var repair_system_parts_hp : Point4List&; repair_system_parts_speed_mult : FloatList;
                        repair_with_mods_available : bool)
  var total_normal_time_to_repair = 0.0f
  var total_serial_time_to_repair = 0.0f
  assume dm = *unit.visual
  for part_id, part_state, part_hp, part_mult in repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp, repair_system_parts_speed_mult
    if can_repair_part(dm, part_id, part_state, part_hp, repair_with_mods_available)
      let part_repair_hp_val = part_hp.z
      let current_hp = dm |> get_part_current_hp(part_id, part_state, part_hp)
      let needed_hp = dm |> get_part_needed_hp(part_id, part_hp)
      let time = safediv(needed_hp - current_hp, part_mult * speed_multiplier)
      if get_flag(part_state, DmPartRepairState SERIALLY_REPAIR)
        total_serial_time_to_repair += time
      else
        total_normal_time_to_repair = max(total_normal_time_to_repair, time);
  return max(total_normal_time_to_repair, total_serial_time_to_repair);


[es(no_order)]
def repair_system_update_es(act : UpdateStageInfoAct;
                            active : bool;
                            eid : EntityId;
                            uid : int;
                            var repair_system_state : uint&;
                            var repair_system_remaining_repair_time : float&;
                            var repair_system_delay_time_to_repair : float&;
                            var repair_system_auto_check_delay : float&;
                            repair_system_toolkit_count : int;
                            repair_system_toolkit_count_max : int;
                            repair_system_speed_multiplier_base : float;
                            repair_system_speed_multiplier_koef : float;
                            var repair_system_scheduled_bot_repair_time : float&;
                            repair_system_parts_id : IntList;
                            repair_system_parts_speed_mult : FloatList;
                            var repair_system_parts_hp : Point4List&;        // x - hp, y - ph needed, z - repairHpVal, w - hpForRepair
                            var repair_system_parts_state : UInt32List&)
  if !active
    return

  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  let gm = unit |> as_gm()
  assume toolkit = gm.toolkit;

  // update repair available state
  set_flag(repair_system_state, RepairState REPAIR_AVAILABLE,
    (repair_system_toolkit_count_max < 0 && get_flag(repair_system_state, RepairState REPAIR_AVAILABLE_WITHOUT_TOOLKIT)) ||
    (repair_system_toolkit_count_max >= 0 && (
      (repair_system_toolkit_count > 0 && toolkit != null && toolkit.isAvailable) ||
      get_flag(repair_system_state, RepairState IS_BOT)
    ))
  )

  let repair_with_mods_available = is_repair_with_mods_availabile(repair_system_state)
  let repair_speed_multiplier = repair_system_speed_multiplier_base * repair_system_speed_multiplier_koef

  // if not suitable for repair return
  if unit == null || !get_flag(repair_system_state, RepairState SUITABLE_FOR_REPAIR)
    return

  assume dm = *unit.visual
  let was_repairing = repair_system_remaining_repair_time > 0.0f
  var not_finished = false
  var has_changed = false

  // handle bots
  if get_flag(repair_system_state, RepairState IS_BOT) && unit.isGroundModel && unit.isAuthority
    if repair_system_scheduled_bot_repair_time >= 0.0f
      repair_system_scheduled_bot_repair_time += act.dt
      // if bot ready to start repair, start it
      if repair_system_scheduled_bot_repair_time > get_app().gameParams.timeAfterHitForRepairTankBots
        if is_repair_needed(unit, repair_system_state, repair_speed_multiplier,
            repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
            false, true, false)
          set_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY, true)
          set_flag(repair_system_state, RepairState WAS_REPAIRING_WITHOUT_MODS, true)
          repair_system_remaining_repair_time = calc_time_to_repair(unit, repair_speed_multiplier,
            repair_system_parts_id, repair_system_parts_state,
            repair_system_parts_hp, repair_system_parts_speed_mult,
            repair_with_mods_available)
          has_changed = true

        // reset bot repair timer
        repair_system_scheduled_bot_repair_time = -1.0f

  if unit.isAuthority
    if get_flag(repair_system_state, RepairState IS_MOVING) && !get_flag(repair_system_state, RepairState IS_BOT)
      // if player is moving, stop repair
      if repair_system_remaining_repair_time > 0.0f && get_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY)
        for part_state in repair_system_parts_state
          set_flag(part_state, DmPartRepairState IN_PROGRESS, false)
        repair_system_remaining_repair_time = 0.0f
        not_finished = true
        has_changed = true

    // auto start repair without mods
    elif repair_system_delay_time_to_repair <= 0.0f && repair_system_remaining_repair_time <= 0.0f && !unit.isBurn
      repair_system_auto_check_delay -= act.dt
      if repair_system_auto_check_delay < 0.0f && is_repair_needed(unit, repair_system_state, repair_speed_multiplier,
            repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
            false, true, false)
        set_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY, true)
        set_flag(repair_system_state, RepairState WAS_REPAIRING_WITHOUT_MODS, true)
        repair_system_delay_time_to_repair = 0.001f
        has_changed = true
        repair_system_auto_check_delay = rnd_float(0.2f, 0.3f)

    // if repair is delayed or in progress
    if repair_system_remaining_repair_time > 0.0f || repair_system_delay_time_to_repair > 0.0f
      // if repair is needed
      if is_repair_needed(unit, repair_system_state, repair_speed_multiplier,
          repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
          !get_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY), /* with mods */
          true, /* without mods */
          get_flag(repair_system_state, RepairState NEED_REPAIR_HELP) && get_flag(repair_system_state, RepairState HAS_REPAIR_ASSISTANT) /* with help */)

        // if tank is burning - stop repair
        if unit.isBurn && (unit.isTank || unit.isWalker)
          repair_system_remaining_repair_time = 0.0f
          repair_system_delay_time_to_repair = 0.0f
          sendEvent(eid, [[EventRepairSystemStopRepair]])
          not_finished = true
          has_changed = true

        // if repair is delayed
        if repair_system_delay_time_to_repair > 0.0f
          repair_system_delay_time_to_repair -= act.dt;

          // if ready start repair
          if repair_system_delay_time_to_repair <= 0.0f
            // if no repair in progress and any repair is needed
            if ((repair_system_remaining_repair_time <= 0.0f || get_flag(repair_system_state, RepairState WAS_REPAIRING_WITHOUT_MODS)) &&
                is_repair_needed(unit, repair_system_state, repair_speed_multiplier,
                  repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
                  true, true, get_flag(repair_system_state, RepairState NEED_REPAIR_HELP)))

              // start repair
              repair_system_remaining_repair_time = calc_time_to_repair(unit, repair_speed_multiplier,
                repair_system_parts_id, repair_system_parts_state,
                repair_system_parts_hp, repair_system_parts_speed_mult,
                repair_with_mods_available)
              set_flag(repair_system_state, RepairState WAS_REPAIRING_WITHOUT_MODS, get_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY))

            // if no repair is needed, stop any in-progress repair and consume toolkit (not sure why this is here)
            else
              repair_system_remaining_repair_time = 0.0f
              sendEvent(eid, [[EventRepairSystemStopRepair]])
              sendEvent(eid, [[EventRepairSystemSpendToolkit]])
              not_finished = true

            has_changed = true

        // if repair in progress
        if repair_system_remaining_repair_time > 0.0f
          if repair_speed_multiplier <= 0.0f
            return

          var serially_repaired = false
          var any_parts_repairing = false

          // for each part
          for part_state, part_id, part_hp, part_mult in repair_system_parts_state, repair_system_parts_id, repair_system_parts_hp, repair_system_parts_speed_mult
            let part_hp_for_repair = part_hp.w
            // if part can be repaired
            if (get_flag(part_state, DmPartRepairState ALLOW_REPAIR) && (!get_flag(part_state, DmPartRepairState MOD_REQUIRED) || repair_with_mods_available) &&
               (dm |> dm_is_dmg_part_active(part_id) && dm |> dm_get_rel_hp(part_id) <= part_hp_for_repair))
              // serially repair only one part
              if get_flag(part_state, DmPartRepairState SERIALLY_REPAIR)
                if serially_repaired
                  continue;
                serially_repaired = true

              // update repair progress
              let needed_hp = get_part_needed_hp(dm, part_id, part_hp)
              part_hp.x = get_part_current_hp(dm, part_id, part_state, part_hp) + part_mult * repair_speed_multiplier * act.dt;
              set_flag(part_state, DmPartRepairState IN_PROGRESS, part_hp.x < needed_hp)

              // part is repaired
              if (part_hp.x >= needed_hp)
                sendEventImmediate(eid, [[EventDamagePartRestored partId=part_id, hp=part_hp.z]])
                part_hp.x = get_part_repair_hp(unit, part_id)

              any_parts_repairing = true

          // if some parts are repairing and repair without mods is not needed
          if any_parts_repairing && !is_repair_needed(unit, repair_system_state, repair_speed_multiplier,
                  repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
                  false, true, false)
            set_flag(repair_system_state, RepairState WAS_REPAIRING_WITHOUT_MODS, false)

          let prev_remaining_repair_time = repair_system_remaining_repair_time
          repair_system_remaining_repair_time = calc_time_to_repair(unit, repair_speed_multiplier,
            repair_system_parts_id, repair_system_parts_state,
            repair_system_parts_hp, repair_system_parts_speed_mult,
            repair_with_mods_available)

          // if repair has ended - spend toolkit
          if repair_system_remaining_repair_time <= 0.0
            sendEvent(eid, [[EventRepairSystemSpendToolkit]])
            has_changed = true

          // if repair time has changed - send updates to client
          elif floor(prev_remaining_repair_time * 2.0f) != floor(repair_system_remaining_repair_time * 2.0f)
            has_changed = true

      // if repair is not needed, reset timers
      else
        repair_system_remaining_repair_time = 0.0f
        repair_system_delay_time_to_repair = 0.0f
        has_changed = true

  // if started repair
  if !was_repairing && repair_system_remaining_repair_time > 0.0f
    sendEvent(eid, [[EventRepairSystemOnStartRepair]])

  // if ended repair
  if was_repairing && repair_system_remaining_repair_time <= 0.0f
    sendEvent(eid, [[EventRepairSystemOnStopRepair notFinished=not_finished]])

  if has_changed
    sendEvent(eid, [[EventRepairSystemNetSync
                      toolkitCount=repair_system_toolkit_count,
                      delayToRepair=repair_system_delay_time_to_repair,
                      remainingRepiarTime=repair_system_remaining_repair_time,
                      repairWithoutModsOnly=get_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY)
                    ]])


[es]
def repair_system_stop_repair_handle_es(evt : EventRepairSystemStopRepair;
                                        eid : EntityId;
                                        uid : int;
                                        repair_system_state : uint;
                                        var repair_system_parts_state : UInt32List&;
                                        var repair_system_parts_id : IntList&;
                                        var repair_system_parts_hp : Point4List&)
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  assume dm = *unit.visual

  for part_state, part_id, part_hp in repair_system_parts_state, repair_system_parts_id, repair_system_parts_hp
    set_flag(part_state, DmPartRepairState IN_PROGRESS, false)
    if dm |> dm_is_dmg_part_active(part_id) && dm |> dm_is_dmg_part_dead(part_id)
      if !get_flag(part_state, DmPartRepairState COMPLETELY_REPAIR) && (
          get_flag(repair_system_state, RepairState REPAIR_AVAILABLE) || !get_flag(part_state, DmPartRepairState MOD_REQUIRED))
        let hp = safediv(dm |> get_part_current_hp(part_id, part_state, part_hp), dm |> dm_get_part_hp_prop(part_id))
        sendEvent(eid, [[EventDamagePartRestored partId=part_id, hp=hp]])


[es]
def repair_system_spend_toolkit_handle_es(evt : EventRepairSystemSpendToolkit;
                                          uid : int;
                                          var repair_system_toolkit_count : int&)
  if repair_system_toolkit_count > 0
    repair_system_toolkit_count--

  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  let gm = unit |> as_gm()
  if gm != null
    gm.toolkit |> spend_expandable_modification()


[es]
def repair_system_handle_restore_es(evt : EventUnitRespawn;
                                    eid : EntityId;
                                    uid : int;
                                    var repair_system_remaining_repair_time : float&;
                                    var repair_system_delay_time_to_repair : float&;
                                    var repair_system_scheduled_bot_repair_time : float&;
                                    var repair_system_toolkit_count : int&;
                                    repair_system_toolkit_count_max : int)
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  let gm = unit |> as_gm()
  assume toolkit = gm.toolkit;
  let toolkit_count = toolkit != null ? (*toolkit).count : 0

  repair_system_remaining_repair_time = -1.0f
  repair_system_delay_time_to_repair = -1.0f
  if toolkit_count > 0
    repair_system_toolkit_count = max(toolkit_count, repair_system_toolkit_count_max)
  if repair_system_toolkit_count_max < 0
    repair_system_toolkit_count = 0
  repair_system_scheduled_bot_repair_time = -1.0f;

  sendEvent(eid, [[EventRepairSystemNetSync
                    toolkitCount=repair_system_toolkit_count,
                    delayToRepair=-1.0f,
                    remainingRepiarTime=-1.0f,
                    repairWithoutModsOnly=false
                  ]])


[es]
def repair_system_handle_request_repair_es(evt : EventRepairSystemSendRequestingRepair;
                                           uid : int;
                                           eid : EntityId;
                                           var repair_system_state : uint&;
                                           repair_system_remaining_repair_time : float;
                                           var repair_system_delay_time_to_repair : float&;
                                           repair_system_speed_multiplier_base : float;
                                           repair_system_speed_multiplier_koef : float;
                                           repair_system_toolkit_count : int;
                                           repair_system_toolkit_count_max : int;
                                           repair_system_parts_id : IntList;
                                           repair_system_parts_hp : Point4List;        // x - hp, y - ph needed, z - repairHpVal, w - hpForRepair
                                           repair_system_parts_state : UInt32List)
  let unit = get_unit(uid);
  if unit == null || unit.isDelayed
    return
  if (!unit.isShip && unit.isBurn) || (repair_system_toolkit_count_max >= 0 && !get_flag(repair_system_state, RepairState REPAIR_AVAILABLE) && !get_flag(repair_system_state, RepairState NEED_REPAIR_HELP))
    return

  sendEvent(eid, [[EventRepairSystemOnRequestedRepair]])

  var has_changed = false
  if evt.isButtonDown
    var delay = -1.0f
    if unit.isShip
      if can_stop_repair(repair_system_state, repair_system_remaining_repair_time)
        delay = get_app().gameParams.shipCancelActionDelay
      else
        delay = 0.001f
    else
      delay = get_dm_params().repairDelayTimerForTanks

    let can_start = can_start_repair(
      unit, repair_system_state, repair_system_speed_multiplier_base * repair_system_speed_multiplier_koef,
      repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
      repair_system_remaining_repair_time, repair_system_delay_time_to_repair,
      get_flag(repair_system_state, RepairState NEED_REPAIR_HELP)
    )
    if can_start || (repair_system_remaining_repair_time > delay && !get_flag(repair_system_state, RepairState WAS_REPAIRING_WITHOUT_MODS))
      set_flag(repair_system_state, RepairState REPAIR_DELAY_FOR_START, can_start)
      set_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY, false)
      repair_system_delay_time_to_repair = delay
      has_changed = true
  elif repair_system_delay_time_to_repair > 0.0f
    let delay_for_start = get_flag(repair_system_state, RepairState REPAIR_DELAY_FOR_START)
    if delay_for_start && (repair_system_remaining_repair_time <= 0.0f || get_flag(repair_system_state, RepairState WAS_REPAIRING_WITHOUT_MODS))
      repair_system_delay_time_to_repair = 0.0f
      set_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY, get_flag(repair_system_state, RepairState WAS_REPAIRING_WITHOUT_MODS))
      has_changed = true
    elif !delay_for_start && (repair_system_remaining_repair_time > 0.0f && repair_system_delay_time_to_repair > 0.0f)
      repair_system_delay_time_to_repair = 0.0f
      has_changed = true

  if has_changed
    sendEvent(eid, [[EventRepairSystemNetSync
                      toolkitCount=repair_system_toolkit_count,
                      delayToRepair=repair_system_delay_time_to_repair,
                      remainingRepiarTime=repair_system_remaining_repair_time,
                      repairWithoutModsOnly=get_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY)
                    ]])
  elif evt.isButtonDown && evt.forceSpendToolkit
    sendEvent(eid, [[EventRepairSystemSpendToolkit]])


[es]
def repair_system_start_bot_repair_timer_es(evt : EventRepairSystemStartBotRepairTimer;
                                            var repair_system_scheduled_bot_repair_time : float&)
  repair_system_scheduled_bot_repair_time = 0.0f

[es]
def repair_system_handle_allow_part_repair_es(evt : EventRepairSystemAllowPartRepair;
                                              repair_system_parts_id : IntList;
                                              var repair_system_parts_state : UInt32List&)
  for part_state, part_id in repair_system_parts_state, repair_system_parts_id
    if part_id == evt.partId
      set_flag(part_state, DmPartRepairState ALLOW_REPAIR, evt.allow)


[es]
def repair_system_handle_allow_all_parts_repair_es(evt : EventRepairSystemAllowAllPartsRepair;
                                                   var repair_system_parts_state : UInt32List&)
  for part_state in repair_system_parts_state
    set_flag(part_state, DmPartRepairState ALLOW_REPAIR, true)


[es]
def repair_system_net_sync_handle_es(evt : EventRepairSystemNetSync;
                                     var repair_system_toolkit_count : int&;
                                     var repair_system_delay_time_to_repair : float&;
                                     var repair_system_remaining_repair_time : float&;
                                     var repair_system_state : uint&)
  set_flag(repair_system_state, RepairState REPAIR_WITHOUT_MODS_ONLY, evt.repairWithoutModsOnly)
  repair_system_toolkit_count = evt.toolkitCount
  repair_system_delay_time_to_repair = evt.delayToRepair
  repair_system_remaining_repair_time = evt.remainingRepiarTime
