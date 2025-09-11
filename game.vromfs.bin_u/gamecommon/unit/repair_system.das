require ecs
require dm
require app
require net
require DagorMath
require DagorRandom
require DagorDataBlock
require Unit
require IGroundModel
require WTDamageModel
require %game.utils.utils_common
require %game.dm.dm_events
require %game.unit.unit_events
require %game.unit.repair_system_events
require %game.unit.repair_system_common
require %game.events


def load_repair_parts(unit : Unit?; blk : DataBlock;
                      override_by_part_id : bool;
                      var repair_system_parts_id : PartIdList&;
                      var repair_system_parts_state : UInt32List&;
                      var repair_system_parts_hp : Point4List&;
                      var repair_system_parts_speed_mult : FloatList&)

  let part_repair_hp_val = blk |> datablock_getReal("partRepairHp", 0.7f)
  let part_hp_for_repair_val = blk |> datablock_getReal("hpForRepair", 0.0f)
  blk |> datablock_for_each_block() <| $(part_blk)
    let part_id = find_part_id(unit.dmData, part_blk.getBlockName)
    if !part_id.valid
      return

    let repair_speed = part_blk |> datablock_getReal("speed", 1.0f)
    let repair_hp_val = part_blk |> datablock_getReal("partRepairHp", part_repair_hp_val)
    let hp_for_repair = part_blk |> datablock_getReal("hpForRepair", part_hp_for_repair_val)
    let serially_repaired = part_blk |> datablock_getBool("serially", false)
    let completely_repair = part_blk |> datablock_getBool("completely", false)
    let mod_required = part_blk |> datablock_getBool("modRequired", true)
    let only_surface_repair = part_blk |> datablock_getBool("onlySurfaceRepair", false)
    assert(repair_speed > 0.0f)

    var part_state = 0u
    set_flag(part_state, DmPartRepairState.SERIALLY_REPAIR, serially_repaired)
    set_flag(part_state, DmPartRepairState.COMPLETELY_REPAIR, completely_repair)
    set_flag(part_state, DmPartRepairState.MOD_REQUIRED, mod_required)
    set_flag(part_state, DmPartRepairState.ALLOW_REPAIR, true)
    set_flag(part_state, DmPartRepairState.ONLY_SURFACE, only_surface_repair)

    var overriden = false
    if override_by_part_id
      for i in 0..length(repair_system_parts_id)
        if repair_system_parts_id[i].id == part_id.id
          repair_system_parts_state[i] = part_state
          repair_system_parts_hp[i] = float4(0.0f, 0.0f, repair_hp_val, hp_for_repair)
          repair_system_parts_speed_mult[i] = repair_speed
          overriden = true

    if !overriden
      repair_system_parts_id |> push(part_id)
      repair_system_parts_state |> push(part_state)
      repair_system_parts_hp |> push(float4(0.0f, 0.0f, repair_hp_val, hp_for_repair))
      repair_system_parts_speed_mult |> push(repair_speed)


def load_toolkit_mod_blk(blk : DataBlock&;
                         var unit : Unit?;
                         var repair_system_state : uint&;
                         var repair_system_toolkit_count : int&;
                         var repair_system_toolkit_count_max : int&;
                         var repair_system_speed_multiplier_base : float&;
                         var repair_system_repair_hp_multiplier : float&;
                         is_default_toolkit : bool)
  repair_system_toolkit_count_max = blk |> datablock_getInt("toolkitActivationCount", repair_system_toolkit_count_max)
  let available_without_toolkit = blk |> datablock_getBool("repairAvailable", false) || is_default_toolkit

  var gm = unit |> as_gm()
  if gm != null && (repair_system_toolkit_count_max < 0 && !available_without_toolkit || repair_system_toolkit_count_max == 0)
    repair_system_toolkit_count_max = gm.toolkit.count

  set_flag(repair_system_state, RepairState.REPAIR_AVAILABLE_WITHOUT_TOOLKIT,
    blk |> datablock_getBool("repairAvailable",
    get_flag(repair_system_state, RepairState.REPAIR_AVAILABLE_WITHOUT_TOOLKIT)))

  let speed_mult_name_id = blk |> datablock_getNameId("speedMultiplier")
  let repair_hp_mult_name_id = blk |> datablock_getNameId("repairHpMultiplier")
  var speed_multiplier = 1.0f
  var repair_hp_multiplier = 1.0f
  for i in 0u..blk.paramCount
    if blk |> datablock_getParamType(i) == int(DataBlockParamType.TYPE_REAL)
      let param_name_id = blk |> datablock_getParamNameId(i)
      if param_name_id == speed_mult_name_id
        speed_multiplier *= blk |> datablock_getReal(int(i))
      if param_name_id == repair_hp_mult_name_id
        repair_hp_multiplier *= blk |> datablock_getReal(int(i))

  if gm != null
    repair_system_toolkit_count = min(gm.toolkit.count, repair_system_toolkit_count_max)
  if repair_system_toolkit_count_max < 0
    repair_system_toolkit_count = 0

  if gm != null
    gm.haveRepair = repair_system_toolkit_count_max < 0 && (
      get_flag(repair_system_state, RepairState.REPAIR_AVAILABLE_WITHOUT_TOOLKIT) ||
      get_flag(repair_system_state, RepairState.REPAIR_PENALTY_WITHOUT_TOOLKIT)
    )

  let has_toolkit = ((repair_system_toolkit_count_max < 0 && available_without_toolkit) ||
                     (repair_system_toolkit_count_max >= 0 && gm != null && gm.toolkit.isAvailable))
  if has_toolkit
    repair_system_speed_multiplier_base = speed_multiplier
    repair_system_repair_hp_multiplier = repair_hp_multiplier

  return has_toolkit



[es]
def repair_system_init_handle_es(evt : CmdInitComponent;
                                 var unit__ref : UnitRef;
                                 var repair_system_state : uint&;
                                 var repair_system_toolkit_count : int&;
                                 var repair_system_toolkit_count_max : int&;
                                 var repair_system_speed_multiplier_base : float&;
                                 var repair_system_repair_hp_multiplier : float&;
                                 var repair_system_parts_id : PartIdList&;
                                 var repair_system_parts_state : UInt32List&;
                                 var repair_system_parts_hp : Point4List&;
                                 var repair_system_parts_speed_mult : FloatList&)
  var unit = unit__ref.unit
  var gm = unit |> as_gm()
  assert(unit != null)
  if unit == null
    return

  
  set_flag(repair_system_state, RepairState.INITIALIZED, true)
  set_flag(repair_system_state, RepairState.SUITABLE_FOR_REPAIR, false)
  set_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY, false)
  set_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS, false)
  set_flag(repair_system_state, RepairState.REPAIR_DELAY_FOR_START, true)
  set_flag(repair_system_state, RepairState.REPAIR_AVAILABLE_WITHOUT_TOOLKIT, false)
  repair_system_toolkit_count_max = -1
  repair_system_speed_multiplier_base = 1.0f
  repair_system_repair_hp_multiplier = 1.0f
  if gm != null
    gm.haveRepair = false

  
  load_repair_parts(
    unit,
    unit.isTank || unit.isWalker || unit.isHuman ? get_wt_dm_params().tankRepairParts : get_wt_dm_params().shipRepairParts, false,
    repair_system_parts_id,
    repair_system_parts_state,
    repair_system_parts_hp,
    repair_system_parts_speed_mult
  )

  *evt.modelBlk |> datablock_get_block("repairParts") <| $(repar_parts_blk)
    load_repair_parts(
      unit,
      repar_parts_blk, true,
      repair_system_parts_id,
      repair_system_parts_state,
      repair_system_parts_hp,
      repair_system_parts_speed_mult
    )

  
  set_flag(repair_system_state, RepairState.CAN_AUTO_REPAIR, true)
  set_flag(repair_system_state, RepairState.REPAIR_PENALTY_WITHOUT_TOOLKIT, false)

  if unit.isShip
    
    *evt.modelBlk |> datablock_get_block("shipDamageControl") <| $(ship_dc_blk)
      let new_dmg_control_system = ship_dc_blk |> datablock_getBool("shipDamageControlEnabled", false)
      if new_dmg_control_system
        set_flag(repair_system_state, RepairState.CAN_AUTO_REPAIR, false)
        set_flag(repair_system_state, RepairState.REPAIR_PENALTY_WITHOUT_TOOLKIT, true)

      
      ship_dc_blk |> datablock_get_block("defaultToolkit") <| $(blk)
        load_toolkit_mod_blk(blk,
          unit,
          repair_system_state,
          repair_system_toolkit_count,
          repair_system_toolkit_count_max,
          repair_system_speed_multiplier_base,
          repair_system_repair_hp_multiplier,
          true)


[es]
def repair_system_init_mod_handle_es(evt : EventUnitInitModification;
                                     var unit__ref : UnitRef;
                                     var repair_system_state : uint&;
                                     var repair_system_toolkit_count : int&;
                                     var repair_system_toolkit_count_max : int&;
                                     var repair_system_speed_multiplier_base : float&;
                                     var repair_system_repair_hp_multiplier : float&)
  if evt.modType != "toolkit"
    return
  
  load_toolkit_mod_blk(*evt.blk,
    unit__ref.unit,
    repair_system_state,
    repair_system_toolkit_count,
    repair_system_toolkit_count_max,
    repair_system_speed_multiplier_base,
    repair_system_repair_hp_multiplier,
    false)



[es(no_order)]
def repair_system_update_es(act : UpdateStageInfoAct;
                            eid : EntityId;
                            var unit__ref : UnitRef;
                            var repair_system_state : uint&;
                            var repair_system_remaining_repair_time : float&;
                            var repair_system_delay_time_to_repair : float&;
                            var repair_system_auto_check_delay : float&;
                            repair_system_toolkit_count : int;
                            repair_system_toolkit_count_max : int;
                            repair_system_speed_multiplier_base : float;
                            var repair_system_speed_multiplier : float&;
                            var repair_system_trailer_repair_progress : float&;
                            repair_system_trailer_repair_time : float;
                            repair_system_repair_hp_multiplier : float;
                            var repair_system_scheduled_bot_repair_time : float&;
                            repair_system_parts_id : PartIdList;
                            repair_system_parts_speed_mult : FloatList;
                            var repair_system_parts_hp : Point4List&;        
                            var repair_system_parts_state : UInt32List&)
  var unit = unit__ref.unit
  if unit.isDelayed
    return
  let gm = unit |> as_gm()

  
  set_flag(repair_system_state, RepairState.HAS_REPAIR_TOOLKIT,
    (repair_system_toolkit_count_max < 0 && get_flag(repair_system_state, RepairState.REPAIR_AVAILABLE_WITHOUT_TOOLKIT)) ||
    (repair_system_toolkit_count_max >= 0 && (
      (repair_system_toolkit_count > 0 && gm != null && gm.toolkit.isAvailable) ||
      get_flag(repair_system_state, RepairState.IS_BOT)
    ))
  )
  set_flag(repair_system_state, RepairState.REPAIR_AVAILABLE,
    get_flag(repair_system_state, RepairState.HAS_REPAIR_TOOLKIT) ||
    get_flag(repair_system_state, RepairState.REPAIR_PENALTY_WITHOUT_TOOLKIT) ||
    get_flag(repair_system_state, RepairState.IS_BOT) ||
    get_flag(repair_system_state, RepairState.REPAIR_ON_BASE)
  )
  let repair_with_mods_available = is_repair_with_mods_availabile(repair_system_state)

  
  if unit.isImmortal
    return

  
  if !get_flag(repair_system_state, RepairState.SUITABLE_FOR_REPAIR)
    return

  
  repair_system_speed_multiplier = repair_system_speed_multiplier_base * get_difficulty_config().tankRepairSpeedK
  if gm != null
    repair_system_speed_multiplier *= gm.crewRepairSpeedMultiplier
  if get_flag(repair_system_state, RepairState.REPAIR_ON_BASE)
    repair_system_speed_multiplier *= get_wt_dm_params().repairOnBaseMul
  if !get_flag(repair_system_state, RepairState.HAS_REPAIR_TOOLKIT) && get_flag(repair_system_state, RepairState.REPAIR_PENALTY_WITHOUT_TOOLKIT)
    repair_system_speed_multiplier *= repair_system_repair_hp_multiplier

  
  assume dmData = unit.dmData
  let was_repairing = repair_system_remaining_repair_time > 0.0f
  var not_finished = false
  var has_changed = false

  
  if get_flag(repair_system_state, RepairState.IS_BOT) && unit.isGroundModel && unit.isAuthority
    if repair_system_scheduled_bot_repair_time >= 0.0f
      repair_system_scheduled_bot_repair_time += act.dt
      
      if repair_system_scheduled_bot_repair_time > get_game_params().timeAfterHitForRepairTankBots
        if is_repair_needed(unit, repair_system_state, repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
            repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
            false, true, false)
          set_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY, true)
          set_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS, true)
          repair_system_remaining_repair_time = calc_time_to_repair(unit,
            repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
            repair_system_parts_id, repair_system_parts_state,
            repair_system_parts_hp, repair_system_parts_speed_mult,
            repair_with_mods_available, repair_system_trailer_repair_time, repair_system_trailer_repair_progress)
          has_changed = true

        
        repair_system_scheduled_bot_repair_time = -1.0f

  if unit.isAuthority
    if get_flag(repair_system_state, RepairState.IS_MOVING) && !get_flag(repair_system_state, RepairState.IS_BOT)
      
      if repair_system_remaining_repair_time > 0.0f && get_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY)
        for part_state in repair_system_parts_state
          set_flag(part_state, DmPartRepairState.IN_PROGRESS, false)
        repair_system_remaining_repair_time = 0.0f
        not_finished = true
        has_changed = true

    
    elif repair_system_delay_time_to_repair <= 0.0f && repair_system_remaining_repair_time <= 0.0f && !unit.isBurn && get_flag(repair_system_state, RepairState.CAN_AUTO_REPAIR)
      repair_system_auto_check_delay -= act.dt
      if repair_system_auto_check_delay < 0.0f
        if is_repair_needed(unit, repair_system_state, repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
            repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
            false, true, false)
          set_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY, true)
          set_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS, true)
          repair_system_delay_time_to_repair = 0.001f
          has_changed = true
        repair_system_auto_check_delay = rnd_float(0.2f, 0.3f)

    
    if repair_system_remaining_repair_time > 0.0f || repair_system_delay_time_to_repair > 0.0f
      
      if is_repair_needed(unit, repair_system_state, repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
          repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
          !get_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY), 
          true, 
          get_flag(repair_system_state, RepairState.NEED_REPAIR_HELP) && get_flag(repair_system_state, RepairState.HAS_REPAIR_ASSISTANT) )

        
        if unit.isBurn && (unit.isTank || unit.isWalker)
          repair_system_remaining_repair_time = 0.0f
          repair_system_delay_time_to_repair = 0.0f
          sendEvent(eid, EventRepairSystemStopRepair())
          not_finished = true
          has_changed = true

        
        if repair_system_delay_time_to_repair > 0.0f
          repair_system_delay_time_to_repair -= act.dt

          
          if repair_system_delay_time_to_repair <= 0.0f
            
            if ((repair_system_remaining_repair_time <= 0.0f || get_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS) ||
                get_game_params().canAssistRepairWithoutRequest) &&
                is_repair_needed(unit, repair_system_state, repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
                  repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
                  true, true, get_flag(repair_system_state, RepairState.NEED_REPAIR_HELP)))

              
              repair_system_remaining_repair_time = calc_time_to_repair(unit,
                repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
                repair_system_parts_id, repair_system_parts_state,
                repair_system_parts_hp, repair_system_parts_speed_mult,
                repair_with_mods_available, repair_system_trailer_repair_time, repair_system_trailer_repair_progress)
              set_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS, get_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY))

            
            else
              repair_system_remaining_repair_time = 0.0f
              sendEvent(eid, EventRepairSystemStopRepair())
              sendEvent(eid, EventRepairSystemSpendToolkit())
              not_finished = true

            has_changed = true

        
        if repair_system_remaining_repair_time > 0.0f
          if repair_system_speed_multiplier <= 0.0f
            return

          var serially_repaired = false
          var any_parts_repairing = false

          
          for part_state, part_id, part_hp, part_mult in repair_system_parts_state, repair_system_parts_id, repair_system_parts_hp, repair_system_parts_speed_mult
            let part_hp_for_repair = part_hp.w
            
            if (get_flag(part_state, DmPartRepairState.ALLOW_REPAIR) && (!get_flag(part_state, DmPartRepairState.MOD_REQUIRED) || repair_with_mods_available) &&
               (part_id.valid && dmData |> get_part_hp_rel(part_id) <= part_hp_for_repair) && (!get_flag(part_state, DmPartRepairState.ONLY_SURFACE) || !unit.isFullyUnderWater))
              
              if get_flag(part_state, DmPartRepairState.SERIALLY_REPAIR)
                if serially_repaired
                  continue
                serially_repaired = true

              
              let needed_hp = get_part_needed_hp(dmData, part_id, part_hp, repair_system_repair_hp_multiplier)
              part_hp.x = get_part_current_hp(dmData, part_id, part_state, part_hp) + part_mult * repair_system_speed_multiplier * act.dt
              set_flag(part_state, DmPartRepairState.IN_PROGRESS, part_hp.x < needed_hp)

              
              if (part_hp.x >= needed_hp)
                sendEventImmediate(eid, EventDamagePartRestored(
                  packedPartId = part_id.packed,
                  hp = part_hp.z * repair_system_repair_hp_multiplier
                ))
                part_hp.x = get_part_hp(dmData, part_id)

              any_parts_repairing = true
            else
              set_flag(part_state, DmPartRepairState.IN_PROGRESS, false)

          if repair_system_trailer_repair_progress >= 0.0
            repair_system_trailer_repair_progress += repair_system_speed_multiplier / get_difficulty_config().tankRepairSpeedK * act.dt / repair_system_trailer_repair_time
            if repair_system_trailer_repair_progress >= 1.0
              var trailer = get_unit_by_eid(unit.trailerEid)
              if trailer != null
                *trailer |> sendRepair()
              repair_system_trailer_repair_progress = -1.0
              any_parts_repairing = true

          let prev_remaining_repair_time = repair_system_remaining_repair_time
          repair_system_remaining_repair_time = calc_time_to_repair(unit,
            repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
            repair_system_parts_id, repair_system_parts_state,
            repair_system_parts_hp, repair_system_parts_speed_mult,
            repair_with_mods_available, repair_system_trailer_repair_time,
            repair_system_trailer_repair_progress)

          
          if repair_system_remaining_repair_time <= 0.0
            if !get_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS)
              sendEvent(eid, EventRepairSystemSpendToolkit())
              if unit.moduleEffectBuffer != null
                *unit.moduleEffectBuffer |> onRepair()
            has_changed = true
          
          elif floor(prev_remaining_repair_time * 2.0f) != floor(repair_system_remaining_repair_time * 2.0f)
            has_changed = true

          
          if any_parts_repairing && !is_repair_needed(unit, repair_system_state, repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
                  repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
                  false, true, false)
            set_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS, false)

      
      else
        print("[REPAIR] uid:{unit.id} EventRepairSystemStopRepair");
        sendEvent(eid, EventRepairSystemStopRepair())
        repair_system_remaining_repair_time = 0.0f
        repair_system_delay_time_to_repair = 0.0f
        has_changed = true

  
  if !was_repairing && repair_system_remaining_repair_time > 0.0f
    print("[REPAIR] uid:{unit.id} EventRepairSystemOnStartRepair: repair_system_remaining_repair_time:{repair_system_remaining_repair_time}");
    sendEvent(eid, EventRepairSystemOnStartRepair())

  
  if was_repairing && repair_system_remaining_repair_time <= 0.0f
    print("[REPAIR] uid:{unit.id} EventRepairSystemOnStopRepair: not_finished:{not_finished}");
    sendEvent(eid, EventRepairSystemOnStopRepair(notFinished = not_finished))

  if has_changed && is_server()
    sendEvent(eid, EventRepairSystemNetSync(
                      toolkitCount = repair_system_toolkit_count,
                      delayToRepair = repair_system_delay_time_to_repair,
                      remainingRepiarTime = repair_system_remaining_repair_time,
                      repairWithoutModsOnly = get_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY)
                    ))


[es]
def repair_system_stop_repair_handle_es(evt : EventRepairSystemStopRepair;
                                        eid : EntityId;
                                        unit__ref : UnitRef;
                                        repair_system_state : uint;
                                        var repair_system_parts_state : UInt32List&;
                                        repair_system_parts_id : PartIdList&;
                                        var repair_system_parts_hp : Point4List&)
  let unit = unit__ref.unit
  if unit.isDelayed
    return
  assume dmData = unit.dmData

  for part_state, part_id, part_hp in repair_system_parts_state, repair_system_parts_id, repair_system_parts_hp
    set_flag(part_state, DmPartRepairState.IN_PROGRESS, false)
    if part_id.valid && is_part_dead(dmData, part_id)
      if !get_flag(part_state, DmPartRepairState.COMPLETELY_REPAIR) && (
          get_flag(repair_system_state, RepairState.REPAIR_AVAILABLE) || !get_flag(part_state, DmPartRepairState.MOD_REQUIRED))
        let hp = safediv(get_part_current_hp(dmData, part_id, part_state, part_hp), dm_get_part_hp_prop(dmData, part_id))
        sendEvent(eid, EventDamagePartRestored(packedPartId = part_id.packed, hp = hp))


[es]
def repair_system_spend_toolkit_handle_es(evt : EventRepairSystemSpendToolkit;
                                          unit__ref : UnitRef;
                                          var repair_system_toolkit_count : int&)
  if repair_system_toolkit_count > 0
    repair_system_toolkit_count--

  let unit = unit__ref.unit
  if unit.isDelayed
    return
  let gm = unit |> as_gm()
  if gm != null
    gm.toolkit |> spend_expendable_modification()


[es(on_event=EventUnitRespawn, on_event=EventUnitRepair)]
def repair_system_handle_restore_es(evt : Event;
                                    eid : EntityId;
                                    unit__ref : UnitRef;
                                    var repair_system_remaining_repair_time : float&;
                                    var repair_system_delay_time_to_repair : float&;
                                    var repair_system_scheduled_bot_repair_time : float&;
                                    var repair_system_toolkit_count : int&;
                                    repair_system_toolkit_count_max : int;
                                    var repair_system_parts_state : UInt32List&)
  let unit = unit__ref.unit
  let gm = unit |> as_gm()

  var toolkit_count = 0
  if gm != null && !unit.isDelayed
    gm.toolkit |> reinit_expendable_modification()
    toolkit_count = gm.toolkit.count

  repair_system_remaining_repair_time = -1.0f
  for part_state in repair_system_parts_state
    set_flag(part_state, DmPartRepairState.IN_PROGRESS, false)
    set_flag(part_state, DmPartRepairState.ALLOW_REPAIR, true)
  repair_system_delay_time_to_repair = -1.0f
  if toolkit_count > 0
    repair_system_toolkit_count = max(toolkit_count, repair_system_toolkit_count_max)
  if repair_system_toolkit_count_max < 0
    repair_system_toolkit_count = 0
  repair_system_scheduled_bot_repair_time = -1.0f

  if is_server()
    sendEvent(eid, EventRepairSystemNetSync(
                      toolkitCount = repair_system_toolkit_count,
                      delayToRepair = -1.0f,
                      remainingRepiarTime = -1.0f,
                      repairWithoutModsOnly = false
                    ))


[es]
def repair_system_repair_request_handle_es(evt : EventRepairSystemRequestRepair;
                                           var repair_system_state : uint&;
                                           var repair_system_remaining_repair_time : float&;
                                           var repair_system_delay_time_to_repair : float&)
  if evt.repair
    if repair_system_remaining_repair_time <= 0.0f
      set_flag(repair_system_state, RepairState.REPAIR_DELAY_FOR_START, true)
      set_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY, false)
      set_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS, false)
      repair_system_delay_time_to_repair = 0.001f
  else
    repair_system_remaining_repair_time = -1.0f
    repair_system_delay_time_to_repair = -1.0f


[es]
def repair_system_repair_button_handle_es(evt : EventRepairSystemSendRequestingRepair;
                                          unit__ref : UnitRef;
                                          eid : EntityId;
                                          var repair_system_state : uint&;
                                          repair_system_remaining_repair_time : float;
                                          var repair_system_delay_time_to_repair : float&;
                                          repair_system_repair_hp_multiplier : float;
                                          repair_system_toolkit_count : int;
                                          repair_system_toolkit_count_max : int;
                                          repair_system_speed_multiplier : float;
                                          repair_system_parts_id : PartIdList;
                                          repair_system_parts_state : UInt32List;
                                          repair_system_parts_hp : Point4List)
  let unit = unit__ref.unit
  if unit.isDelayed
    return
  let fRepairAvailable = get_flag(repair_system_state, RepairState.REPAIR_AVAILABLE)
  let fNeedRepairHelp = get_flag(repair_system_state, RepairState.NEED_REPAIR_HELP)
  print("[REPAIR] uid:{unit.id} button_handle_es: isBurn:{unit.isBurn} toolkit_count:{repair_system_toolkit_count} fRepairAvailable:{fRepairAvailable} fNeedRepairHelp:{fNeedRepairHelp} btnDown:{evt.isButtonDown}")
  if (!unit.isShip && unit.isBurn) || (repair_system_toolkit_count_max >= 0 && !fRepairAvailable && !fNeedRepairHelp)
    return

  sendEvent(eid, EventRepairSystemOnRequestedRepair())

  var has_changed = false
  if evt.isButtonDown
    var delay = -1.0f
    if unit.isShip
      if can_stop_repair(repair_system_state, repair_system_remaining_repair_time)
        delay = get_game_params().shipCancelActionDelay
      else
        delay = 0.001f
    else
      delay = get_wt_dm_params().repairDelayTimerForTanks

    let can_start = can_start_repair(
      unit, repair_system_state, repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
      repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp,
      repair_system_remaining_repair_time, repair_system_delay_time_to_repair,
      get_flag(repair_system_state, RepairState.NEED_REPAIR_HELP)
    )

    print("[REPAIR] uid:{unit.id} button_handle_es: can_start:{can_start} delay:{delay}")
    if can_start || (repair_system_remaining_repair_time > delay && !get_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS))
      set_flag(repair_system_state, RepairState.REPAIR_DELAY_FOR_START, can_start)
      set_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY, false)
      repair_system_delay_time_to_repair = delay
      has_changed = true
  elif repair_system_delay_time_to_repair > 0.0f
    let delay_for_start = get_flag(repair_system_state, RepairState.REPAIR_DELAY_FOR_START)
    if delay_for_start && (repair_system_remaining_repair_time <= 0.0f || get_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS))
      repair_system_delay_time_to_repair = 0.0f
      set_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY, get_flag(repair_system_state, RepairState.WAS_REPAIRING_WITHOUT_MODS))
      has_changed = true
    elif !delay_for_start && (repair_system_remaining_repair_time > 0.0f && repair_system_delay_time_to_repair > 0.0f)
      repair_system_delay_time_to_repair = 0.0f
      has_changed = true

  if has_changed
    if is_server()
      sendEvent(eid, EventRepairSystemNetSync(
                        toolkitCount = repair_system_toolkit_count,
                        delayToRepair = repair_system_delay_time_to_repair,
                        remainingRepiarTime = repair_system_remaining_repair_time,
                        repairWithoutModsOnly = get_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY)
                      ))
  elif evt.isButtonDown && evt.forceSpendToolkit
    sendEvent(eid, EventRepairSystemSpendToolkit())


[es]
def repair_system_start_bot_repair_timer_es(evt : EventRepairSystemStartBotRepairTimer;
                                            var repair_system_scheduled_bot_repair_time : float&)
  repair_system_scheduled_bot_repair_time = 0.0f


[es]
def repair_system_handle_allow_part_repair_es(evt : EventRepairSystemAllowPartRepair;
                                              repair_system_parts_id : PartIdList;
                                              var repair_system_parts_state : UInt32List&)
  let evt_part_id = PartId(evt.packedPartId)
  for part_state, part_id in repair_system_parts_state, repair_system_parts_id
    if part_id.id == evt_part_id.id
      set_flag(part_state, DmPartRepairState.ALLOW_REPAIR, evt.allow)


[es(tag=netClient)]
def repair_system_net_sync_handle_es(evt : EventRepairSystemNetSync;
                                     var unit__ref : UnitRef;
                                     var repair_system_toolkit_count : int&;
                                     var repair_system_delay_time_to_repair : float&;
                                     var repair_system_remaining_repair_time : float&;
                                     var repair_system_state : uint&)
  print("[REPAIR] uid:{unit__ref.unit.id} repair_system_net_sync_handle_es: toolkit:{repair_system_toolkit_count}={evt.toolkitCount} delay:{evt.delayToRepair} remainingRepairTime:{evt.remainingRepiarTime}");
  set_flag(repair_system_state, RepairState.REPAIR_WITHOUT_MODS_ONLY, evt.repairWithoutModsOnly)
  repair_system_toolkit_count = evt.toolkitCount
  repair_system_delay_time_to_repair = evt.delayToRepair
  repair_system_remaining_repair_time = evt.remainingRepiarTime


[es]
def repair_system_trailer_dead_handle_es(evt : EventOnTrailerDead;
                                         var repair_system_trailer_repair_progress : float&)
  repair_system_trailer_repair_progress = 0.0


[es(tag=server)]
def repair_system_on_damage_es(evt : EventUnitDamage;
                               var unit__ref : UnitRef;
                               repair_system_state : uint&;
                               var repair_system_parts_hp : Point4List&;
                               repair_system_parts_state : UInt32List&;
                               repair_system_parts_id : PartIdList&)
  if !get_flag(repair_system_state, RepairState.SUITABLE_FOR_REPAIR)
    return
  var unit = unit__ref.unit
  if unit.isDelayed
    return

  let mult = get_game_params().minDamageFractionToResetRepair
  for part_id, part_state, part_hp in repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp
    if part_id.id == evt.partId.id && get_flag(part_state, DmPartRepairState.IN_PROGRESS)
      let current_hp = get_part_hp(unit.dmData, part_id)
      if part_hp.y * mult < evt.damage && current_hp > 0.0f
        part_hp.x = max(current_hp - evt.damage, 0.0f)
      break