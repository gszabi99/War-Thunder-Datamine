require ecs
require app
require Unit
require WTDamageModel
require IGroundModel
require DagorMath
require DagorDataBlock
require DagorRandom
require %game.repair_system_common
require %game.extinguish_system_common
require %game.unit_events
require %game.ship_events
require %game.repair_system_events
require %game.extinguish_system_events


let PROCESS_REPAIR = 0u
let PROCESS_EXTINGUISH = 1u
let PROCESS_UNWATERING = 2u
let PROCESS_MASK = 3u
let MAX_PROCESSES = 3u


def is_process_present(processes : uint; process : uint) : bool
  for i in 0u..MAX_PROCESSES
    if ((processes >> i * 2u) & PROCESS_MASK) == process
      return true
  return false


def get_process_penalty(processes : uint; process : uint; penatlies : float3) : float
  for i in 0u..MAX_PROCESSES
    if ((processes >> i * 2u) & PROCESS_MASK) == process
      return penatlies[i]
  return 1.0f


[es]
def ship_start_damage_control_es(evt : EventShipStartDamageControl;
                                 eid : EntityId;
                                 ship_modern_damage_control : bool;
                                 var ship_damage_control_cooldown_end_time : float&;
                                 var ship_damage_control_priorities : uint&)
  if !ship_modern_damage_control
    return

  let start = evt.priorities != 0u
  if start
    if ship_damage_control_priorities != evt.priorities
      if ship_damage_control_cooldown_end_time > float(get_app().usefulTotalTime)
        return
      ship_damage_control_cooldown_end_time = get_app().gameParams.shipDamageControlSwitchCooldownTime + float(get_app().usefulTotalTime)
      ship_damage_control_priorities = evt.priorities

    sendEvent(eid, [[EventShipRequestRepairBreaches repair=true]])
    sendEvent(eid, [[EventRepairSystemRequestRepair repair=true]])
    sendEvent(eid, [[EventExtinguishSystemActivateExtinguisher assisteeId=INVALID_ENTITY_ID]])
  else
    sendEvent(eid, [[EventShipRequestRepairBreaches repair=false]])
    sendEvent(eid, [[EventRepairSystemRequestRepair repair=false]])
    sendEvent(eid, [[EventExtinguishSystemTurnOffExtinguisher]])


[es]
def ship_damage_control_init_es(evt : CmdInitComponent;
                                var ship_modern_damage_control : bool&;
                                var ship_damage_control_priorities : uint&)
  ship_modern_damage_control = false
  *evt.modelBlk |> datablock_get_block("shipDamageControl") <| $(blk)
    ship_modern_damage_control = blk |> datablock_getBool("shipDamageControlEnabled", false)
  ship_damage_control_priorities = 0u


[es(no_order)]
def ship_update_damage_control_es(act : UpdateStageInfoAct;
                                  eid : EntityId;
                                  uid : int;
                                  var repair_system_auto_check_delay : float&;
                                  ship_damage_control_running : bool;
                                  fire_damage__isBurn : bool;

                                  repair_system_state : uint;
                                  repair_system_speed_multiplier : float;
                                  repair_system_repair_hp_multiplier : float;
                                  repair_system_parts_id : PartIdList;
                                  repair_system_parts_hp : Point4List;
                                  repair_system_parts_state : UInt32List)

  if ship_damage_control_running
    if fire_damage__isBurn
      sendEvent(eid, [[EventExtinguishSystemActivateExtinguisher assisteeId=INVALID_ENTITY_ID]])

    repair_system_auto_check_delay -= act.dt
    if repair_system_auto_check_delay < 0.0f
      let unit = get_unit(uid)
      if unit != null && !unit.isDelayed && is_repair_needed(unit,
                                              repair_system_state, repair_system_speed_multiplier, repair_system_repair_hp_multiplier,
                                              repair_system_parts_id, repair_system_parts_state, repair_system_parts_hp, true, true, false)
        sendEvent(eid, [[EventRepairSystemRequestRepair repair=true]])
      repair_system_auto_check_delay = rnd_float(0.2f, 0.3f)

    // breach repair is requested automatically, if breaches are added


[es(no_order)]
def ship_update_time_penalty_es(info : UpdateStageInfoAct;
                                uid : int;
                                ship_modern_damage_control : bool;
                                ship_damage_control_priorities : uint;
                                ship_damage_control_time_penalty : float3;
                                var ship_damage_control_running : bool&;
                                var ship_damage_control_repair_speed_mult : float&;
                                var ship_damage_control_extinguish_speed_mult : float&;
                                var ship_damage_control_unwatering_speed_mult : float&;

                                repair_system_remaining_repair_time : float;
                                fire_damage__isBurn : bool;
                                extinguish_system_is_assisting : bool;
                                extinguish_system_extinguish_time_end : float;
                                ship_repair_breaches_remaining_time : float;
                                ship_unwatering_remaining_time : float)
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return

  // in old system we count repair breaches as unwatering process, in new system - as repair process
  let repair_in_progress = repair_system_remaining_repair_time > 0.0f || ship_modern_damage_control && ship_repair_breaches_remaining_time > 0.0f;
  let extinguish_in_progress = is_extinguisher_active(fire_damage__isBurn, extinguish_system_is_assisting, extinguish_system_extinguish_time_end)
  let unwatering_in_progress = ship_unwatering_remaining_time > 0.0f || !ship_modern_damage_control && ship_repair_breaches_remaining_time > 0.0f

  let crew = unit.crew
  var repair_mult = crew != null ? safeinv(crew.repairTimeMult) : 1.0f
  var extinguish_mult = crew != null ? safeinv(crew.extinguishTimeMult) : 1.0f
  var unwatering_mult = crew != null ? safeinv(crew.unwateringTimeMult) : 1.0f

  if ship_modern_damage_control
    ship_damage_control_running = repair_in_progress || extinguish_in_progress || unwatering_in_progress

    let repair_inv_penalty = safeinv(get_process_penalty(ship_damage_control_priorities, PROCESS_REPAIR, ship_damage_control_time_penalty))
    let extinguish_inv_penalty = safeinv(get_process_penalty(ship_damage_control_priorities, PROCESS_EXTINGUISH, ship_damage_control_time_penalty))
    let unwatering_inv_penalty = safeinv(get_process_penalty(ship_damage_control_priorities, PROCESS_UNWATERING, ship_damage_control_time_penalty))

    ship_damage_control_repair_speed_mult = repair_mult * repair_inv_penalty
    ship_damage_control_extinguish_speed_mult = extinguish_mult * extinguish_inv_penalty
    ship_damage_control_unwatering_speed_mult = unwatering_mult * unwatering_inv_penalty

  else
    ship_damage_control_running = false

    repair_mult = repair_in_progress ? repair_mult : 0.0f
    extinguish_mult = extinguish_in_progress ? extinguish_mult : 0.0f
    unwatering_mult = unwatering_in_progress ? unwatering_mult : 0.0f

    let penalties = get_dm_params().shipboardDamageControlWeight
    let repair_inv_penalty = safeinv(penalties.x)
    let extinguish_inv_penalty = safeinv(penalties.y)
    let unwatering_inv_penalty = safeinv(penalties.z)

    let total_weight = repair_mult + extinguish_mult + unwatering_mult
    if total_weight == 0.0f
      ship_damage_control_repair_speed_mult = 1.0f
      ship_damage_control_extinguish_speed_mult = 1.0f
      ship_damage_control_unwatering_speed_mult = 1.0f
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

    ship_damage_control_repair_speed_mult = repair_mult > 0.0f ? repair_mult : 1.0f
    ship_damage_control_extinguish_speed_mult = extinguish_mult > 0.0f ? extinguish_mult : 1.0f
    ship_damage_control_unwatering_speed_mult = unwatering_mult > 0.0f ? unwatering_mult : 1.0f

  // print("{repair_in_progress} {extinguish_in_progress} {unwatering_in_progress}")
  // print("{ship_damage_control_repair_speed_mult} {ship_damage_control_extinguish_speed_mult} {ship_damage_control_unwatering_speed_mult}")