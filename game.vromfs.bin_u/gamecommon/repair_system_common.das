module repair_system_common shared
require ecs
require DagorMath
require Unit
require WTDamageModel
require app


let REPAIR_PENALTY_REL_HP = 0.5f
let REPAIR_PENALTY_SLOW = 1.5f


def get_flag(repair_state : uint; flag) : bool
  return (repair_state & uint(flag)) != 0u;


def set_flag(var repair_state : uint&; flag; set : bool)
  if set
    repair_state |= uint(flag)
  else
    repair_state &= ~uint(flag)


def is_repair_with_mods_availabile(repair_state : uint) : bool
  return ((
    get_flag(repair_state, RepairState REPAIR_AVAILABLE) ||
    get_flag(repair_state, RepairState NEED_REPAIR_HELP) ||
    get_flag(repair_state, RepairState REPAIR_ON_BASE)
  ) && !get_flag(repair_state, RepairState REPAIR_WITHOUT_MODS_ONLY))


def can_repair_part(dm : DamageableVisualModel; part_id : int; part_state : uint; part_hp : float4; repair_system_repair_hp_multiplier : float; repair_with_mods_available : bool)
  return (
    get_flag(part_state, DmPartRepairState ALLOW_REPAIR) &&
    (!get_flag(part_state, DmPartRepairState MOD_REQUIRED) || repair_with_mods_available) &&
    dm |> dm_is_dmg_part_active(part_id) && dm |> dm_get_rel_hp(part_id) <= part_hp.w * repair_system_repair_hp_multiplier
  )


def is_repair_needed(unit : Unit?; repair_state : uint; speed_multiplier : float; repair_system_repair_hp_multiplier : float;
                     parts_id : IntList; parts_state : UInt32List; parts_hp : Point4List;
                     with_mods : bool; without_mods : bool; with_help : bool) : bool
  if unit.isGroundModel && speed_multiplier > 0.0f
    assume dm = *unit.visual
    for part_id, part_state, part_hp in parts_id, parts_state, parts_hp
      if can_repair_part(dm, part_id, part_state, part_hp, repair_system_repair_hp_multiplier, true)
        if !get_flag(part_state, DmPartRepairState MOD_REQUIRED)
          if without_mods
            return true
        elif with_mods
          if with_help || get_flag(repair_state, RepairState REPAIR_AVAILABLE) || get_flag(repair_state, RepairState REPAIR_ON_BASE)
            return true
    if with_mods && (with_help || get_flag(repair_state, RepairState REPAIR_AVAILABLE) || get_flag(repair_state, RepairState REPAIR_ON_BASE))
      var trailer = get_unit(unit.getTrailerId);
      if trailer != null && !trailer.isAlive
        return true
  return false


def can_start_repair(unit : Unit?; repair_state : uint; speed_multiplier : float; repair_system_repair_hp_multiplier : float;
                     parts_id : IntList; parts_state : UInt32List; parts_hp : Point4List;
                     remaining_repair_time : float; delay_time_to_repair : float; repair_by_ally : bool) : bool
  return (
    delay_time_to_repair <= 0.0f &&
    is_repair_needed(unit, repair_state, speed_multiplier, repair_system_repair_hp_multiplier, parts_id, parts_state, parts_hp, true, true, repair_by_ally) &&
    (
      remaining_repair_time <= 0.0f ||
      (is_repair_needed(unit, repair_state, speed_multiplier, repair_system_repair_hp_multiplier, parts_id, parts_state, parts_hp, true, true, false) &&
       get_flag(repair_state, RepairState REPAIR_WITHOUT_MODS_ONLY))
    )
  )


def can_stop_repair(repair_state : uint; remaining_repair_time : float) : bool
  return !get_flag(repair_state, RepairState REPAIR_WITHOUT_MODS_ONLY) && remaining_repair_time > 0.0f


def get_part_repair_hp(unit : Unit?; part_id : int) : float
  return *unit.visual |> dm_get_dmg_part_hp(part_id)


def get_part_needed_hp(dm; part_id : int; var part_hp : float4&; repair_system_repair_hp_multiplier : float)
  if part_hp.y <= 0.0f
    part_hp.y = dm |> dm_get_part_hp_prop(part_id)
  return part_hp.y * repair_system_repair_hp_multiplier * part_hp.z


def get_part_current_hp(dm; part_id : int; part_state : uint; var part_hp : float4&)
  if !get_flag(part_state, DmPartRepairState IN_PROGRESS)
    return dm |> dm_get_dmg_part_hp(part_id)
  return part_hp.x


def calc_time_to_repair(unit : Unit?; speed_multiplier : float; repair_system_repair_hp_multiplier : float;
                        repair_system_parts_id : IntList; repair_system_parts_state : UInt32List;
                        var repair_system_parts_hp : Point4List&; repair_system_parts_speed_mult : FloatList;
                        repair_with_mods_available : bool; repair_trailer_time : float; repair_trailer_progress : float)
  var total_normal_time_to_repair = 0.0f
  var total_serial_time_to_repair = 0.0f
  assume dm = *unit.visual
  for part_id, part_state, part_hp, part_mult in repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp, repair_system_parts_speed_mult
    if can_repair_part(dm, part_id, part_state, part_hp, repair_system_repair_hp_multiplier, repair_with_mods_available)
      let current_hp = dm |> get_part_current_hp(part_id, part_state, part_hp)
      let needed_hp = dm |> get_part_needed_hp(part_id, part_hp, repair_system_repair_hp_multiplier)
      let time = safediv(needed_hp - current_hp, part_mult * speed_multiplier)
      if get_flag(part_state, DmPartRepairState SERIALLY_REPAIR)
        total_serial_time_to_repair += time
      else
        total_normal_time_to_repair = max(total_normal_time_to_repair, time);
  var trailer = get_unit(unit.getTrailerId);
  if trailer != null && !trailer.isAlive
    total_normal_time_to_repair = max(total_normal_time_to_repair, (1.0 - repair_trailer_progress) * repair_trailer_time * get_difficulty_config().tankRepairSpeedK / speed_multiplier)
  return max(total_normal_time_to_repair, total_serial_time_to_repair);
