require ecs
require app
require Unit
require WTDamageModel
require IGroundModel
require DagorMath
require DagorDataBlock
require DagorRandom
require WarShipModel
require %game.unit.repair_system_common
require %game.unit.extinguish_system_common
require %game.unit.unit_events
require %game.unit.repair_system_events
require %game.unit.extinguish_system_events
require %game.unit.ship_events


let PROCESS_REPAIR = 0u
let PROCESS_EXTINGUISH = 1u
let PROCESS_UNWATERING = 2u
let PROCESS_MASK = 3u
let MAX_PROCESSES = 3u


def get_priorities_dbg(priorities : uint)
  var s : array<string>
  for i in 0u..MAX_PROCESSES
    let cur_process = (priorities >> i * 2u) & PROCESS_MASK
    if cur_process == PROCESS_REPAIR
      s |> push("repair")
    elif cur_process == PROCESS_EXTINGUISH
      s |> push("extinguish")
    elif cur_process == PROCESS_UNWATERING
      s |> push("unwatering")
  return <- s


def get_process_priority_idx(priorities : uint; running_processes : uint; process : uint) : int
  var running_count = 0
  for i in 0u..MAX_PROCESSES
    let cur_process = (priorities >> i * 2u) & PROCESS_MASK
    if cur_process == process
      return running_count
    if (running_processes & (1u << cur_process)) != 0u
      running_count++
  return 0


[es]
def ship_start_damage_control_es(evt : EventShipStartDamageControl;
                                 eid : EntityId;
                                 ship__modernDamageControl : bool;
                                 ship_damage_control__cooldownTime : float;
                                 var ship_damage_control__cooldownEndTime : float&;
                                 var ship_damage_control__priorities : uint&)
  if !ship__modernDamageControl
    return

  let start = evt.priorities != 0u
  if start
    if ship_damage_control__priorities != evt.priorities
      if ship_damage_control__cooldownEndTime > float(get_app().usefulTotalTime)
        return
      ship_damage_control__cooldownEndTime = ship_damage_control__cooldownTime + float(get_app().usefulTotalTime)
      ship_damage_control__priorities = evt.priorities
    
  else
    sendEvent(eid, EventShipRequestRepairBreaches(repair = false))
    sendEvent(eid, EventRepairSystemRequestRepair(repair = false))
    sendEvent(eid, EventExtinguishSystemTurnOffExtinguisher())


[es(before=ship_damage_control_load_priorities_es)]
def ship_damage_control_init_es(evt : CmdInitComponent;
                                var ship__modernDamageControl : bool&;
                                var ship_damage_control__cooldownTime : float&;
                                var ship_damage_control__priorities : uint&;
                                var ship_damage_control__timePenalty : float3&)
  ship__modernDamageControl = false
  *evt.modelBlk |> datablock_get_block("shipDamageControl") <| $(blk)
    ship__modernDamageControl = blk |> datablock_getBool("shipDamageControlEnabled", false)
    ship_damage_control__cooldownTime = blk |> datablock_getReal("switchPresetCooldown", 10.0f)
    ship_damage_control__timePenalty = blk |> datablock_getPoint3("shipboardDamageControlWeight", float3(1.0f, 1.2f, 1.4f))
  ship_damage_control__priorities = 0u


[es(no_order)]
def ship_update_damage_control_es(act : UpdateStageInfoAct;
                                  eid : EntityId;
                                  unit__ref : UnitRef;
                                  ship__modernDamageControl : bool;
                                  var repair_system_auto_check_delay : float&;
                                  repair_system_remaining_repair_time : float;
                                  fire_damage__isBurn : bool;

                                  extinguish_system_extinguish_time_end : float;
                                  extinguish_system_is_assisting : bool;
                                  repair_system_state : uint;
                                  repair_system_speed_multiplier : float;
                                  repair_system_repair_hp_multiplier : float;
                                  repair_system_parts_id : PartIdList;
                                  repair_system_parts_hp : Point4List;
                                  repair_system_parts_state : UInt32List)
  if !ship__modernDamageControl
    return

  if fire_damage__isBurn && !is_extinguisher_active(fire_damage__isBurn, extinguish_system_is_assisting, extinguish_system_extinguish_time_end)
    sendEvent(eid, EventExtinguishSystemActivateExtinguisher(assisteeId = INVALID_ENTITY_ID))

  repair_system_auto_check_delay -= act.dt
  if repair_system_auto_check_delay < 0.0f
    let unit = unit__ref.unit
    let ship = as_ship(unit)
    if (ship != null && !unit.isDelayed && repair_system_remaining_repair_time <= 0.0f &&
        !ship.isVeryFewCrew && !ship.isCoverDestroyed && is_repair_needed(unit,
          repair_system_state, repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
          repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp, true, true, false))
      sendEvent(eid, EventRepairSystemRequestRepair(repair = true))
      repair_system_auto_check_delay = 5.0f
    else
      repair_system_auto_check_delay = rnd_float(0.2f, 0.3f)

  


[es(no_order)]
def ship_update_time_penalty_es(info : UpdateStageInfoAct;
                                unit__ref : UnitRef;
                                ship__modernDamageControl : bool;
                                ship_damage_control__priorities : uint;
                                ship_damage_control__timePenalty : float3;
                                var ship_damage_control__repairSpeedMult : float&;
                                var ship_damage_control__extinguishSpeedMult : float&;
                                var ship_damage_control__unwateringSpeedMult : float&;

                                repair_system_remaining_repair_time : float;
                                fire_damage__isBurn : bool;
                                extinguish_system_is_assisting : bool;
                                extinguish_system_extinguish_time_end : float;
                                ship__repairBreachesRemainingTime : float;
                                ship__unwateringRemainingTime : float)
  let unit = unit__ref.unit
  if unit.isDelayed
    return

  
  let repair_in_progress = repair_system_remaining_repair_time > 0.0f || ship__modernDamageControl && ship__repairBreachesRemainingTime > 0.0f
  let extinguish_in_progress = is_extinguisher_active(fire_damage__isBurn, extinguish_system_is_assisting, extinguish_system_extinguish_time_end)
  let unwatering_in_progress = ship__unwateringRemainingTime > 0.0f || !ship__modernDamageControl && ship__repairBreachesRemainingTime > 0.0f

  let crew = unit.crew
  var repair_mult = crew != null ? safeinv(crew.repairTimeMult) : 1.0f
  var extinguish_mult = crew != null ? safeinv(crew.extinguishTimeMult) : 1.0f
  var unwatering_mult = crew != null ? safeinv(crew.unwateringTimeMult) : 1.0f

  if ship__modernDamageControl
    let running_processes = (
      (repair_in_progress ? (1u << PROCESS_REPAIR) : 0u) |
      (extinguish_in_progress ? (1u << PROCESS_EXTINGUISH) : 0u) |
      (unwatering_in_progress ? (1u << PROCESS_UNWATERING) : 0u)
    )
    let penalties = ship_damage_control__timePenalty
    let repair_inv_penalty = safeinv(penalties[get_process_priority_idx(ship_damage_control__priorities, running_processes, PROCESS_REPAIR)])
    let extinguish_inv_penalty = safeinv(penalties[get_process_priority_idx(ship_damage_control__priorities, running_processes, PROCESS_EXTINGUISH)])
    let unwatering_inv_penalty = safeinv(penalties[get_process_priority_idx(ship_damage_control__priorities, running_processes, PROCESS_UNWATERING)])

    ship_damage_control__repairSpeedMult = repair_mult * repair_inv_penalty
    ship_damage_control__extinguishSpeedMult = extinguish_mult * extinguish_inv_penalty
    ship_damage_control__unwateringSpeedMult = unwatering_mult * unwatering_inv_penalty

  else
    repair_mult = repair_in_progress ? repair_mult : 0.0f
    extinguish_mult = extinguish_in_progress ? extinguish_mult : 0.0f
    unwatering_mult = unwatering_in_progress ? unwatering_mult : 0.0f

    let penalties = get_wt_dm_params().shipboardDamageControlWeight
    let repair_inv_penalty = safeinv(penalties.x)
    let extinguish_inv_penalty = safeinv(penalties.y)
    let unwatering_inv_penalty = safeinv(penalties.z)

    let total_weight = repair_mult + extinguish_mult + unwatering_mult
    if total_weight == 0.0f
      ship_damage_control__repairSpeedMult = 1.0f
      ship_damage_control__extinguishSpeedMult = 1.0f
      ship_damage_control__unwateringSpeedMult = 1.0f
      return

    let total_inv_weight = safeinv(repair_inv_penalty * repair_mult +
                                  extinguish_inv_penalty * extinguish_mult +
                                  unwatering_inv_penalty * unwatering_mult)
    repair_mult *= total_inv_weight * repair_inv_penalty * repair_mult
    extinguish_mult *= total_inv_weight * extinguish_inv_penalty * extinguish_mult
    unwatering_mult *= total_inv_weight * unwatering_inv_penalty * unwatering_mult

    let crew_survive_effort = crew != null ? crew.surviveEffortMult : 1.0f
    if (repair_mult > 0.0f ? 1 : 0) + (extinguish_mult > 0.0f ? 1 : 0) + (unwatering_mult > 0.0f ? 1 : 0) >= 2
      repair_mult *= crew_survive_effort
      extinguish_mult *= crew_survive_effort
      unwatering_mult *= crew_survive_effort

    ship_damage_control__repairSpeedMult = repair_mult > 0.0f ? repair_mult : 1.0f
    ship_damage_control__extinguishSpeedMult = extinguish_mult > 0.0f ? extinguish_mult : 1.0f
    ship_damage_control__unwateringSpeedMult = unwatering_mult > 0.0f ? unwatering_mult : 1.0f

  
  
