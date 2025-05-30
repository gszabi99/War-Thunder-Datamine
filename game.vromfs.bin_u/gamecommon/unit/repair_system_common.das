module repair_system_common shared
require ecs
require DagorMath
require dm
require Unit
require WTDamageModel
require app
require %game.utils.utils_common


def is_repair_with_mods_availabile(repair_state : uint) : bool
  return ((
    get_flag(repair_state, RepairState.REPAIR_AVAILABLE) ||
    get_flag(repair_state, RepairState.NEED_REPAIR_HELP)
  ) && !get_flag(repair_state, RepairState.REPAIR_WITHOUT_MODS_ONLY))


def can_repair_part(dmData : DamageModelData; part_id : PartId; part_state : uint; part_hp : float4; repair_system_repair_hp_multiplier : float; repair_with_mods_available : bool;
                    under_water : bool)
  return (
    get_flag(part_state, DmPartRepairState.ALLOW_REPAIR) &&
    (!get_flag(part_state, DmPartRepairState.MOD_REQUIRED) || repair_with_mods_available) &&
    (!get_flag(part_state, DmPartRepairState.ONLY_SURFACE) || !under_water) &&
    is_valid_part_id(dmData, part_id) && get_part_hp_rel(dmData, part_id) <= part_hp.w * repair_system_repair_hp_multiplier
  )


def is_repair_needed(unit : Unit const?; repair_state : uint; speed_multiplier : float; repair_system_repair_hp_multiplier : float;
                     parts_id : PartIdList; parts_state : UInt32List; parts_hp : Point4List;
                     with_mods : bool; without_mods : bool; with_help : bool) : bool
  if unit.isGroundModel && speed_multiplier > 0.0f
    assume dmData = unit.dmData
    let repair_with_mods_available = with_help || get_flag(repair_state, RepairState.REPAIR_AVAILABLE)
    for part_id, part_state, part_hp in parts_id, parts_state, parts_hp
      if can_repair_part(dmData, part_id, part_state, part_hp, repair_system_repair_hp_multiplier, true, unit.isFullyUnderWater)
        if get_flag(part_state, DmPartRepairState.ONLY_SURFACE) && unit.isFullyUnderWater
          continue
        if !get_flag(part_state, DmPartRepairState.MOD_REQUIRED)
          if without_mods
            return true
        elif with_mods
          if repair_with_mods_available
            return true
    if with_mods && repair_with_mods_available
      var trailer = get_unit_by_eid(unit.trailerEid)
      if trailer != null && !trailer.isAlive
        return true
  return false


def can_start_repair(unit : Unit const?; repair_state : uint; speed_multiplier : float; repair_system_repair_hp_multiplier : float;
                     parts_id : PartIdList; parts_state : UInt32List; parts_hp : Point4List;
                     remaining_repair_time : float; delay_time_to_repair : float; repair_by_ally : bool) : bool
  return (
    delay_time_to_repair <= 0.0f &&
    is_repair_needed(unit, repair_state, speed_multiplier, repair_system_repair_hp_multiplier, parts_id, parts_state, parts_hp, true, true, repair_by_ally) &&
    (
      remaining_repair_time <= 0.0f ||
      (is_repair_needed(unit, repair_state, speed_multiplier, repair_system_repair_hp_multiplier, parts_id, parts_state, parts_hp, true, true, false) &&
       get_flag(repair_state, RepairState.REPAIR_WITHOUT_MODS_ONLY))
    )
  )


def can_stop_repair(repair_state : uint; remaining_repair_time : float) : bool
  return !get_flag(repair_state, RepairState.REPAIR_WITHOUT_MODS_ONLY) && remaining_repair_time > 0.0f


def get_part_repair_hp(dmData : DamageModelData; part_id : PartId) : float
  return get_part_hp(dmData, part_id)


def dm_get_part_hp_prop(dmData : DamageModelData; part_id : PartId) : float
  return get_part_hp_prop_value(dmData, part_id)


def get_part_needed_hp(dmData : DamageModelData; part_id : PartId; var part_hp : float4&; repair_system_repair_hp_multiplier : float)
  if part_hp.y <= 0.0f
    part_hp.y = dm_get_part_hp_prop(dmData, part_id)
  return part_hp.y * repair_system_repair_hp_multiplier * part_hp.z


def get_part_current_hp(dmData : DamageModelData; part_id : PartId; part_state : uint; part_hp : float4)
  if !get_flag(part_state, DmPartRepairState.IN_PROGRESS)
    return get_part_hp(dmData, part_id)
  return part_hp.x


def calc_time_to_repair(unit : Unit const?; speed_multiplier : float; repair_system_repair_hp_multiplier : float;
                        repair_system_parts_id : PartIdList; repair_system_parts_state : UInt32List;
                        var repair_system_parts_hp : Point4List&; repair_system_parts_speed_mult : FloatList;
                        repair_with_mods_available : bool; repair_trailer_time : float; repair_trailer_progress : float)
  var total_normal_time_to_repair = 0.0f
  var total_serial_time_to_repair = 0.0f
  assume dmData = unit.dmData
  for part_id, part_state, part_hp, part_mult in repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp, repair_system_parts_speed_mult
    if can_repair_part(dmData, part_id, part_state, part_hp, repair_system_repair_hp_multiplier, repair_with_mods_available, unit.isFullyUnderWater)
      let current_hp = dmData |> get_part_current_hp(part_id, part_state, part_hp)
      let needed_hp = dmData |> get_part_needed_hp(part_id, part_hp, repair_system_repair_hp_multiplier)
      let time = safediv(needed_hp - current_hp, part_mult * speed_multiplier)
      if get_flag(part_state, DmPartRepairState.SERIALLY_REPAIR)
        total_serial_time_to_repair += time
      else
        total_normal_time_to_repair = max(total_normal_time_to_repair, time)
  var trailer = get_unit_by_eid(unit.trailerEid)
  if trailer != null && !trailer.isAlive
    total_normal_time_to_repair = max(total_normal_time_to_repair, (1.0 - repair_trailer_progress) * repair_trailer_time * get_difficulty_config().tankRepairSpeedK / speed_multiplier)
  return max(total_normal_time_to_repair, total_serial_time_to_repair)
