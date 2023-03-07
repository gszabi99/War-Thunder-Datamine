require ecs
require net
require dm
require Unit
require app
require DagorSystem
require DagorRandom
require DagorMath
require DagorDataBlock
require WTDamageModel
require WarShipModel
require %game.unit_events
require %game.ship_events
require %game.repair_system_events


def load_cover_parts(blk : DataBlock&; add_compartment : bool;
                     unit : Unit?;
                     var ship_cover_parts_part_id : PartIdList&;
                     var ship_cover_parts_water : Point3List&;
                     var ship_cover_parts_pos : Point3List&;
                     var ship_cover_parts_weight : FloatList&;
                     var ship_cover_parts_compartment_id : IntList&;
                     var ship_cover_parts_inner_parts : IPoint2List&;
                     var ship_compartments_cover_parts : IPoint2List&;
                     var ship_inner_parts_ids : IntList&;
                     var ship_inner_parts_critical_water : FloatList&)
  assume unit_dm = *unit.visual
  let compartment_id = add_compartment ? length(ship_compartments_cover_parts) : -1
  let cover_parts_start = length(ship_cover_parts_part_id)
  var cover_parts_end = cover_parts_start
  var weights_sum = 0.0f
  blk |> datablock_for_each_block("cover") <| $(cover)
    let weight = cover |> datablock_getReal("weight", 1.0f)
    let max_water_alive = cover |> datablock_getReal("maxWaterAlive", 1.0f)
    assert(weight > 0.0)
    assert(max_water_alive >= 0.0f && max_water_alive <= 1.0f)
    let partNo = get_dm_part_id_by_dm_name(cover |> datablock_getStr("part", ""), true)
    let partId = unit_dm |> dm_get_remap(partNo)

    if partId |> dm_part_id_valid()
      ship_cover_parts_part_id |> push(partId)
      ship_cover_parts_water |> push(float3(0.0f, 0.0f, max_water_alive))
      ship_cover_parts_weight |> push(weight)
      ship_cover_parts_compartment_id |> push(compartment_id)

      if cover |> datablock_param_exists("pos", -1)
        ship_cover_parts_pos |> push(cover |> datablock_getPoint3("pos", float3(0, 0, 0)))
      else
        let node = unit_dm |> dm_get_collision_node_by_part_id(partNo)
        assert(node != null)
        ship_cover_parts_pos |> push(node.tm * node.modelBBox.center)

      let inner_parts_start = length(ship_inner_parts_ids)
      var inner_parts_end = inner_parts_start
      cover |> datablock_get_block("innerParts") <| $(inner_parts)
        inner_parts |> datablock_for_each_block() <| $(inner_part)
          let inner_part_id = get_dm_part_id_by_dm_name(inner_part |> datablock_getStr("partNo", ""), true)
          assert(inner_part_id != -1)
          let crit_water_level = inner_part |> datablock_getReal("critWaterLevel", 1.0f)
          assert(crit_water_level >= 0.0f && crit_water_level <= 1.0f)
          ship_inner_parts_ids |> push(inner_part_id)
          ship_inner_parts_critical_water |> push(crit_water_level)
          inner_parts_end++
      ship_cover_parts_inner_parts |> push(int2(inner_parts_start, inner_parts_end))

      weights_sum += weight
      cover_parts_end++

  if add_compartment
    ship_compartments_cover_parts |> push(int2(cover_parts_start, cover_parts_end))
  return weights_sum


[es]
def ship_repair_handler_es(evt : EventUnitRepair;
                           var ship_cover_parts_water : Point3List&;
                           var ship_breaches_id : IntList&;
                           var ship_breaches_pos : Point3List&;
                           var ship_breaches_normal : Point3List&;
                           var ship_breaches_size : FloatList&;
                           var ship_breaches_amount_to_repair : FloatList&;
                           var ship_breaches_depth_scale : FloatList&;
                           var ship_breaches_next_check : FloatList&;
                           var ship_breaches_part_id : PartIdList&;
                           var ship_breaches_cover_id : IntList&;
                           var ship_breaches_leaked_amount : FloatList&;
                           var ship_breaches_offender : BreachOffenderDataList&;
                           var ship_breaches_fatal_part_id : PartId&;
                           var ship_repair_breaches_remaining_time : float&;
                           var ship_unwatering_remaining_time : float&;
                           var ship_additional_water_left_side : float&;
                           var ship_additional_water_right_side : float&;
                           var ship_flood_step : int&)
  for water in ship_cover_parts_water
    water.x = 0.0f

  ship_breaches_id |> clear()
  ship_breaches_pos |> clear()
  ship_breaches_normal |> clear()
  ship_breaches_size |> clear()
  ship_breaches_amount_to_repair |> clear()
  ship_breaches_depth_scale |> clear()
  ship_breaches_next_check |> clear()
  ship_breaches_part_id |> clear()
  ship_breaches_cover_id |> clear()
  ship_breaches_leaked_amount |> clear()
  ship_breaches_offender |> clear()
  ship_breaches_fatal_part_id = PartId()

  ship_repair_breaches_remaining_time = -1.0f
  ship_unwatering_remaining_time = -1.0f
  ship_additional_water_left_side = 0.0f
  ship_additional_water_right_side = 0.0f
  ship_flood_step = 1


[es]
def ship_init_cover_parts_handle_es(evt : CmdInitComponent;
                                    uid : int;
                                    var ship_cover_parts_part_id : PartIdList&;
                                    var ship_cover_parts_water : Point3List&;
                                    var ship_cover_parts_pos : Point3List&;
                                    var ship_cover_parts_weight : FloatList&;
                                    var ship_cover_parts_compartment_id : IntList&;
                                    var ship_cover_parts_inner_parts : IPoint2List&;
                                    var ship_compartments_cover_parts : IPoint2List&;
                                    var ship_inner_parts_ids : IntList&;
                                    var ship_inner_parts_critical_water : FloatList&)
  let unit = get_unit(uid)
  assert(unit != null)
  if unit == null
    return

  ship_cover_parts_part_id |> clear()
  ship_cover_parts_water |> clear()
  ship_cover_parts_pos |> clear()
  ship_cover_parts_weight |> clear()
  ship_cover_parts_compartment_id |> clear()
  ship_cover_parts_inner_parts |> clear()
  ship_compartments_cover_parts |> clear()
  ship_inner_parts_ids |> clear()
  ship_inner_parts_critical_water |> clear()

  *evt.modelBlk |> datablock_get_block("shipCover") <| $(blk)
    var weights_sum = load_cover_parts(
      blk, false, unit,
      ship_cover_parts_part_id,
      ship_cover_parts_water,
      ship_cover_parts_pos,
      ship_cover_parts_weight,
      ship_cover_parts_compartment_id,
      ship_cover_parts_inner_parts,
      ship_compartments_cover_parts,
      ship_inner_parts_ids,
      ship_inner_parts_critical_water
    )

    blk |> datablock_for_each_block("compartment") <| $(compartment)
      weights_sum += load_cover_parts(
        compartment, true, unit,
        ship_cover_parts_part_id,
        ship_cover_parts_water,
        ship_cover_parts_pos,
        ship_cover_parts_weight,
        ship_cover_parts_compartment_id,
        ship_cover_parts_inner_parts,
        ship_compartments_cover_parts,
        ship_inner_parts_ids,
        ship_inner_parts_critical_water
      )

    let ship = unit |> as_ship()
    let ship_props = ship.shipProps
    for weight, water, inner_parts in ship_cover_parts_weight, ship_cover_parts_water, ship_cover_parts_inner_parts
      weight = safediv(weight, weights_sum)
      water.y = ship_props.additionalWaterCoverPartsThreshold * weight
      for i in range(inner_parts.x, inner_parts.y)
        ship_inner_parts_critical_water[i] *= water.y


[es(tag=netClient, after=ship_init_cover_parts_handle_es)]
def ship_request_net_sync_on_load_es(evt : CmdInitComponent; eid : EntityId)
  send_net_event(eid, [[EventShipRequestNetSync]])


[es]
def ship_init_mod_handle_es(evt : CmdInitComponent;
                            uid : int;
                            var ship_water_mass_vel_mut : float&)
  let unit = get_unit(uid)
  assert(unit != null)
  if unit != null && unit.modBlk != null
    let defaultVal = unit.isHumanPlayer ? 1.0f : 0.0f
    ship_water_mass_vel_mut = unit.modBlk |> datablock_getReal("waterMassVelMult", defaultVal)


[es]
def ship_init_damage_parts_handle_es(evt : EventShipInitDamageParts;
                                     var ship_pumps_part_id : IntList&)
  ship_pumps_part_id := evt.pumps


[es]
def ship_init_repair_parts_info_handle_es(evt : CmdInitComponent;
                                          uid : int;
                                          var ship_repair_parts_part_id : IntList&;
                                          var ship_repair_parts_time : FloatList&;
                                          var ship_repair_parts_hp : FloatList&)
  let unit = get_unit(uid)
  assert(unit != null)
  if unit == null
    return
  assume dm = *unit.visual

  *evt.modelBlk |> datablock_get_block("partsToRepair") <| $(blk)
    blk |> datablock_for_each_block() <| $(part_info)
      let partNo = get_dm_part_id_by_dm_name(part_info.getBlockName, true)
      let partId = dm |> dm_get_remap(partNo)
      if !partId |> dm_part_id_valid()
        return
      ship_repair_parts_part_id |> push(partNo)
      ship_repair_parts_time |> push(part_info |> datablock_getReal("time", 60.0f))
      ship_repair_parts_hp |> push(part_info |> datablock_getReal("hp", 0.5f))


// should be generalized in the future
[es]
def ship_copy_from_handle_es(evt : EventShipCopyFrom;
                             var ship_additional_water_left_side : float&;
                             var ship_additional_water_right_side : float&)
  var additional_water_left_side = ship_additional_water_left_side
  var additional_water_right_side = ship_additional_water_right_side

  query(evt.eid) <| $ [es] (
                            ship_additional_water_left_side : float;
                            ship_additional_water_right_side : float
                            )
    additional_water_left_side = ship_additional_water_left_side
    additional_water_right_side = ship_additional_water_right_side

  ship_additional_water_left_side = additional_water_left_side
  ship_additional_water_right_side = additional_water_right_side


def has_any_breaches(ship_breaches_amount_to_repair : FloatList&)
  for amount_to_repair in ship_breaches_amount_to_repair
    if amount_to_repair > 0.0f
      return true
  return false


def calc_time_to_repair_breaches(repair_speed_mult : float; ship_breaches_amount_to_repair : FloatList) : float
  var time = 0.0f
  for amount_to_repair in ship_breaches_amount_to_repair
    time = max(time, amount_to_repair / repair_speed_mult)
  return time


[es(no_order)]
def ship_repair_breaches_update_es(info : UpdateStageInfoAct;
                                   eid : EntityId;
                                   uid : int;
                                   ship_modern_damage_control : bool;
                                   var ship_repair_breaches_remaining_time : float&;
                                   repair_system_remaining_repair_time : float;
                                   ship_repair_crew_alive_mult : float;
                                   ship_damage_control_unwatering_speed_mult : float;
                                   ship_damage_control_repair_speed_mult : float;
                                   ship_breaches_id : IntList;
                                   var ship_breaches_amount_to_repair : FloatList&;
                                   ship_pumps_part_id : IntList;
                                   ship_cover_parts_water : Point3List;
                                   ship_water_mass_vel_mut : float;
                                   var ship_unwatering_remaining_time : float&)
  let unit = get_unit(uid)
  let ship = unit |> as_ship()
  if ship == null || unit.isDelayed
    return
  let ship_props = ship.shipProps

  let was_repairing_breaches = ship_repair_breaches_remaining_time > 0.0f
  if ship_repair_breaches_remaining_time > 0.0f || repair_system_remaining_repair_time > 0.0f && ship_modern_damage_control
    var repair_speed_mult = ship_repair_crew_alive_mult * ship_props.breachRepairSpeed
    if ship_modern_damage_control
      repair_speed_mult *= ship_damage_control_repair_speed_mult
    else
      repair_speed_mult *= ship_damage_control_unwatering_speed_mult
    ship_repair_breaches_remaining_time = calc_time_to_repair_breaches(repair_speed_mult, ship_breaches_amount_to_repair)

    for breach_id, amount_to_repair in ship_breaches_id, ship_breaches_amount_to_repair
      if amount_to_repair > 0.0f
        amount_to_repair -= repair_speed_mult * info.dt
      if amount_to_repair <= 0.0f
        amount_to_repair = 0.0f
        sendEvent(eid, [[EventShipRemoveBreach breachId=breach_id]])

  if was_repairing_breaches && ship_repair_breaches_remaining_time <= 0.0f
    ship_unwatering_remaining_time = calc_time_to_unwater(unit,
      ship_pumps_part_id,
      ship_cover_parts_water,
      ship_damage_control_unwatering_speed_mult,
      ship_water_mass_vel_mut
    )


def fixup_breaches_soa(var ship_breaches_id : IntList&; var ship_breaches_offender : BreachOffenderDataList&)
  if length(ship_breaches_id) != length(ship_breaches_offender)
    ship_breaches_offender |> resize(length(ship_breaches_id))


[es]
def ship_remove_breach_handle_es(evt : EventShipRemoveBreach;
                                 eid : EntityId;
                                 var ship_breaches_id : IntList&;
                                 var ship_breaches_pos : Point3List&;
                                 var ship_breaches_normal : Point3List&;
                                 var ship_breaches_size : FloatList&;
                                 var ship_breaches_amount_to_repair : FloatList&;
                                 var ship_breaches_depth_scale : FloatList&;
                                 var ship_breaches_next_check : FloatList&;
                                 var ship_breaches_part_id : PartIdList&;
                                 var ship_breaches_cover_id : IntList&;
                                 var ship_breaches_leaked_amount : FloatList&;
                                 var ship_breaches_offender : BreachOffenderDataList&)
  fixup_breaches_soa(ship_breaches_id, ship_breaches_offender)
  for i in iter_range(ship_breaches_id)
    if ship_breaches_id[i] == evt.breachId
      let local_pos = ship_breaches_pos[i]
      ship_breaches_id |> erase(i)
      ship_breaches_pos |> erase(i)
      ship_breaches_normal |> erase(i)
      ship_breaches_size |> erase(i)
      ship_breaches_amount_to_repair |> erase(i)
      ship_breaches_depth_scale |> erase(i)
      ship_breaches_next_check |> erase(i)
      ship_breaches_part_id |> erase(i)
      ship_breaches_cover_id |> erase(i)
      ship_breaches_leaked_amount |> erase(i)
      ship_breaches_offender |> erase(i)
      sendEvent(eid, [[EventShipOnRemoveBreach localPos=local_pos]])
      break


[es]
def add_breach_handle_es(evt : EventShipAddBreach;
                         eid : EntityId;
                         uid : int;
                         ship_damage_control_running : bool;
                         ship_cover_parts_part_id : PartIdList;
                         var ship_breaches_id : IntList&;
                         var ship_breaches_pos : Point3List&;
                         var ship_breaches_normal : Point3List&;
                         var ship_breaches_size : FloatList&;
                         var ship_breaches_amount_to_repair : FloatList&;
                         var ship_breaches_depth_scale : FloatList&;
                         var ship_breaches_next_check : FloatList&;
                         var ship_breaches_part_id : PartIdList&;
                         var ship_breaches_cover_id : IntList&;
                         var ship_breaches_leaked_amount : FloatList&;
                         var ship_breaches_offender : BreachOffenderDataList&;
                         var ship_unwatering_remaining_time : float&)
  if evt.id < 0
    return

  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return

  var cover_id = -1
  let part_id = evt.partId
  for i in iter_range(ship_cover_parts_part_id)
    if ship_cover_parts_part_id[i].id == part_id.id
      cover_id = i
      break
  if cover_id < 0
    return

  let box = (*unit).boundingBox
  let ship_props = as_ship(unit).shipProps
  var pos = evt.localPos
  pos.x = clamp(pos.x, box.boxMin.x, box.boxMax.x);
  pos.y = clamp(pos.y, box.boxMin.y, box.boxMax.y);
  pos.z = clamp(pos.z, box.boxMin.z, box.boxMax.z);
  let size = min(evt.size, box.width.x / 8.f); // max diameter is 1/4 of length
  let amountToRepair = cvt(size, ship_props.breachSizeToRepair.x, ship_props.breachSizeToRepair.y, ship_props.breachSizeToRepair.z, ship_props.breachSizeToRepair.w);

  // TODO: probably we dont need to set max breach count
  let MAX_BREACHES_COUNT = 100
  var breach_id_to_remove = -1
  if length(ship_breaches_id) >= MAX_BREACHES_COUNT
    var min_size = size
    for breach_id, breach_size in ship_breaches_id, ship_breaches_size
      if min_size >= breach_size
        min_size = breach_size
        breach_id_to_remove = breach_id
    if breach_id_to_remove == -1
      return

  fixup_breaches_soa(ship_breaches_id, ship_breaches_offender)
  ship_breaches_id |> push(evt.id)
  ship_breaches_pos |> push(pos)
  ship_breaches_normal |> push(evt.localNormal)
  ship_breaches_size |> push(size)
  ship_breaches_amount_to_repair |> push(amountToRepair)
  ship_breaches_depth_scale |> push(0.0f)
  ship_breaches_next_check |> push(float(get_app().usefulTotalTime))
  ship_breaches_part_id |> push(part_id)
  ship_breaches_cover_id |> push(cover_id)
  ship_breaches_leaked_amount |> push(0.0f)
  ship_breaches_offender |> push(evt.offender)

  sendEvent(eid, [[EventShipOnGotBreach breachId=evt.id, localPos=evt.localPos, offender=evt.offender]])
  if ship_unwatering_remaining_time > 0.0f || ship_damage_control_running
    ship_unwatering_remaining_time = -1.0f
    sendEvent(eid, [[EventShipRequestRepairBreaches repair=true]])

  if breach_id_to_remove != -1
    sendEvent(eid, [[EventShipRemoveBreach breachId=breach_id_to_remove]])


[es]
def add_fatal_breach_handle_es(evt : EventShipAddFatalBreach;
                               eid : EntityId;
                               uid : int;
                               var ship_breaches_next_id : int&;
                               var ship_breaches_fatal_part_id : PartId&;
                               ship_cover_parts_part_id : PartIdList;
                               ship_cover_parts_water : Point3List)
  if ship_breaches_fatal_part_id.valid
    return

  let unit = get_unit(uid)
  let ship = unit |> as_ship()
  if ship == null || unit.isDelayed
    return

  let part_id = evt.partId
  let ship_props = ship.shipProps
  for i in iter_range(ship_cover_parts_part_id)
    if ship_cover_parts_part_id[i].id == part_id.id
      ship_breaches_fatal_part_id = part_id
      if unit.isAuthority
        sendEvent(eid, [[EventShipAddBreach
          id=ship_breaches_next_id++,
          partId=part_id,
          size=ship_cover_parts_water[i].y / (ship_props.fatalBreachDrownTime * 50.0f * ship_props.breachWaterMassMult),
          localPos = evt.localPos,
          localNormal = evt.localNormal,
          offender = evt.offender
        ]])
      break


def calc_pump_mass_vel(unit : Unit?;
                       ship_pumps_part_id : IntList;
                       ship_cover_parts_water : Point3List;
                       ship_damage_control_unwatering_speed_mult : float;
                       ship_water_mass_vel_mut : float) : float
  assume unit_dm = *unit.visual
  let ship_props = as_ship(unit).shipProps

  var num_cover_parts = 0
  for water in ship_cover_parts_water
    if water.x > 0.0f
      num_cover_parts++

  if num_cover_parts > 0
    var pumps_total_rel_hp = 0.0f
    var pumps_count = 0
    for pump_part_id in ship_pumps_part_id
      let partId = unit_dm |> dm_get_remap(pump_part_id)
      if partId |> dm_part_id_valid()
        pumps_count++
        pumps_total_rel_hp += unit_dm |> dm_get_rel_hp(pump_part_id)

    let pump_readiness = lerp(get_difficulty_config().shipBrokenPumpMaxWaterMassVelMult, 1.0, safediv(pumps_total_rel_hp, float(pumps_count)))
    return (ship_water_mass_vel_mut * ship_props.breachWaterMassVel * ship_damage_control_unwatering_speed_mult *
            pump_readiness / float(num_cover_parts))

  return 0.0f


def calc_time_to_unwater(unit : Unit?;
                         ship_pumps_part_id : IntList;
                         ship_cover_parts_water : Point3List;
                         ship_damage_control_unwatering_speed_mult : float;
                         ship_water_mass_vel_mut : float)
  let pump_water_mass_vel = abs(calc_pump_mass_vel(unit,
    ship_pumps_part_id,
    ship_cover_parts_water,
    ship_damage_control_unwatering_speed_mult,
    ship_water_mass_vel_mut
  ))

  var res_time = 0.0f
  var count_parts = 0
  if pump_water_mass_vel > 0.0f
    for water in ship_cover_parts_water
      if water.x > 0.0f
        res_time += water.x / pump_water_mass_vel
        count_parts++
    if count_parts > 0
      res_time /= float(count_parts)

  return res_time


[es(after=ship_repair_breaches_update_es)]
def ship_unwatering_update_es(info : UpdateStageInfoAct;
                              uid : int;
                              ship_breaches_amount_to_repair : FloatList;
                              ship_pumps_part_id : IntList;
                              ship_cover_parts_water : Point3List;
                              ship_damage_control_unwatering_speed_mult : float;
                              ship_water_mass_vel_mut : float;
                              var ship_unwatering_remaining_time : float&)
  if ship_unwatering_remaining_time > 0.0f
    // update unwatering time, if has no breaches
    if !has_any_breaches(ship_breaches_amount_to_repair)
      let unit = get_unit(uid)
      if unit == null || unit.isDelayed
        return

      ship_unwatering_remaining_time = calc_time_to_unwater(unit,
        ship_pumps_part_id,
        ship_cover_parts_water,
        ship_damage_control_unwatering_speed_mult,
        ship_water_mass_vel_mut
      )
    else
      ship_unwatering_remaining_time = -1.0f


[es]
def ship_request_repair_breaches_handle_es(evt : EventShipRequestRepairBreaches;
                                           uid : int;
                                           var ship_repair_breaches_remaining_time : float&;
                                           ship_repair_crew_alive_mult : float;
                                           ship_damage_control_unwatering_speed_mult : float;
                                           ship_breaches_amount_to_repair : FloatList;
                                           var ship_unwatering_remaining_time : float&;
                                           ship_pumps_part_id : IntList;
                                           ship_cover_parts_water : Point3List;
                                           ship_water_mass_vel_mut : float)
  if evt.repair
    if ship_repair_breaches_remaining_time <= 0.0f && ship_unwatering_remaining_time <= 0.0f
      let unit = get_unit(uid)
      let ship = unit |> as_ship()
      if ship != null && !unit.isDelayed && !ship.isVeryFewCrew
        let repair_speed_mult = ship_repair_crew_alive_mult * ship.shipProps.breachRepairSpeed * ship_damage_control_unwatering_speed_mult
        let time_to_repair = calc_time_to_repair_breaches(repair_speed_mult, ship_breaches_amount_to_repair)
        if time_to_repair > 0.0f
          ship_repair_breaches_remaining_time = time_to_repair
        elif ship_repair_breaches_remaining_time <= 0.0f
          let time_to_unwater = calc_time_to_unwater(unit,
            ship_pumps_part_id,
            ship_cover_parts_water,
            ship_damage_control_unwatering_speed_mult,
            ship_water_mass_vel_mut
          )
          if time_to_unwater > 0.0f
            ship_unwatering_remaining_time = time_to_unwater
  else
    ship_repair_breaches_remaining_time = 0.0f
    ship_unwatering_remaining_time = 0.0f


[es(no_order)]
def ship_repair_parts_update_es(info : UpdateStageInfoAct;
                                uid : int;
                                var ship_repair_part_idx : int&;
                                var ship_repair_part_remaining_time : float&;
                                ship_repair_parts_part_id : IntList;
                                ship_repair_parts_time : FloatList;
                                ship_repair_parts_hp : FloatList)
  var unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  assume unit_dm = *unit.visual

  // this seems to be some kind of auto repair, which does not depend on crew or any speed multipliers
  if ship_repair_part_idx >= 0
    ship_repair_part_remaining_time -= info.dt
    if ship_repair_part_remaining_time <= 0.0f
      unit_dm |> dm_set_rel_hp(ship_repair_parts_part_id[ship_repair_part_idx], ship_repair_parts_hp[ship_repair_part_idx], false)
      ship_repair_part_idx = -1

  if ship_repair_part_idx < 0
    for i in 0..length(ship_repair_parts_part_id)
      if unit_dm |> dm_get_rel_hp(ship_repair_parts_part_id[i]) > 0.0f
        continue
      ship_repair_part_idx = i
      ship_repair_part_remaining_time = ship_repair_parts_time[i]
      break


[es(after=ship_repair_parts_update_es)]
def ship_breaches_add_water_update_es(info : UpdateStageInfoAct;
                                      eid : EntityId;
                                      uid : int;
                                      ship_phys_velocity_sq : float;
                                      ship_phys_ground_collision : bool;
                                      var ship_additional_water_left_side : float&;
                                      var ship_additional_water_right_side : float&;
                                      ship_breaches_fatal_part_id : PartId;
                                      ship_breaches_part_id : PartIdList;
                                      ship_breaches_cover_id : IntList;
                                      ship_breaches_pos : Point3List;
                                      ship_breaches_size : FloatList;
                                      ship_breaches_amount_to_repair : FloatList;
                                      var ship_breaches_next_check : FloatList&;
                                      var ship_breaches_depth_scale : FloatList&;
                                      var ship_breaches_leaked_amount : FloatList&;
                                      ship_cover_parts_part_id : PartIdList;
                                      var ship_cover_parts_water : Point3List&;
                                      ship_cover_parts_compartment_id : IntList;
                                      ship_cover_parts_inner_parts : IPoint2List;
                                      ship_inner_parts_ids : IntList;
                                      ship_inner_parts_critical_water : FloatList;
                                      ship_compartments_cover_parts : IPoint2List)
  let unit = get_unit(uid)
  let ship = unit |> as_ship()
  if ship == null || unit.isDelayed
    return
  assume dmData = unit.dmData
  let ship_props = ship.shipProps
  let is_dead = !unit.isAlive
  let current_time = float(get_app().usefulTotalTime)

  for part_id, cover_id, pos, size, amount_to_repair, next_check, depth_scale, leaked_amount in ship_breaches_part_id, ship_breaches_cover_id, ship_breaches_pos, ship_breaches_size, ship_breaches_amount_to_repair, ship_breaches_next_check, ship_breaches_depth_scale, ship_breaches_leaked_amount
    let is_fatal = is_dead || part_id.id == ship_breaches_fatal_part_id.id

    var water_mass_velocity = 0.0f
    if amount_to_repair > 0.0f
      water_mass_velocity = size * (50.0f + ship_phys_velocity_sq) * ship_props.breachWaterMassMult

    // update depth scale
    if !is_fatal && current_time > next_check
      let world_pos = unit.unitTm * pos
      let bottom_world_pos = world_pos - float3(0.0f, size, 0.0f)
      var breach_underwater = false
      var water_height = 0.0f
      get_app().currentScene |> scene_get_water_height(/* out */ water_height, /* out */ breach_underwater, bottom_world_pos, /* trace height */ 100.0f, /* check 3d water */ true)
      depth_scale = breach_underwater ? min((water_height - (world_pos.y - size)) / (2.0f * size), 1.0f) : -1.0f;
      next_check = current_time + 1.0f

    // add water to breach
    if depth_scale > 0.0 || is_fatal
      let water_delta = (is_fatal ? 1.0f : depth_scale) * water_mass_velocity * info.dt
      let compartment_id = ship_cover_parts_compartment_id[cover_id]
      let cover_parts_range = compartment_id >= 0 ? ship_compartments_cover_parts[compartment_id] : int2(cover_id, cover_id + 1)

      // add water to cover parts
      for i in cover_parts_range.x..cover_parts_range.y
        // calculate max water in cover part
        var max_water = ship_cover_parts_water[i].y
        if !is_part_dead(dmData, ship_cover_parts_part_id[i]) // if part is not dead
          max_water *= ship_cover_parts_water[i].z // *= maxWaterAlive

        // add water to part
        let prev_water = ship_cover_parts_water[i].x
        ship_cover_parts_water[i].x = min(max(ship_cover_parts_water[i].x + water_delta, 0.0f), max_water);
        leaked_amount += water_delta
        if !ship_phys_ground_collision
          if pos.z > 0.0
            ship_additional_water_left_side = min(max(ship_additional_water_left_side + water_delta, 0.0f), ship_props.additionalSideWaterThreshold);
          else
            ship_additional_water_right_side = min(max(ship_additional_water_right_side + water_delta, 0.0f), ship_props.additionalSideWaterThreshold);

        // check if some parts has drowned
        let inner_parts_range = ship_cover_parts_inner_parts[i]
        for j in inner_parts_range.x..inner_parts_range.y
          let crit_water_level = ship_inner_parts_critical_water[j]
          if ship_cover_parts_water[i].x > crit_water_level && prev_water <= crit_water_level
            sendEvent(eid, [[EventShipPartDrowned partId=ship_inner_parts_ids[j]]])


[es(after=ship_breaches_add_water_update_es)]
def ship_breaches_pump_water_update_es(info : UpdateStageInfoAct;
                                       eid : EntityId;
                                       uid : int;
                                       var ship_phys_additional_water : float&;
                                       var ship_phys_water_leaking : bool&;
                                       var ship_phys_avg_breach_pos : float3&;
                                       var ship_cover_parts_water : Point3List&;
                                       ship_cover_parts_pos : Point3List;
                                       ship_cover_parts_compartment_id : IntList;
                                       ship_cover_parts_inner_parts : IPoint2List;
                                       ship_inner_parts_ids : IntList;
                                       ship_inner_parts_critical_water : FloatList;
                                       ship_pumps_part_id : IntList;
                                       ship_damage_control_unwatering_speed_mult : float;
                                       ship_water_mass_vel_mut : float;
                                       ship_unwatering_remaining_time : float)
  // we will not pump water if the process was stopped
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return

  var additional_water = 0.0f
  var avg_breach = float3(0.0f, 0.0f, 0.0f)
  var avg_breach_weight = 0.0f

  // The logic here differs from original one, in original logic pumps will always function, when there are no
  // breaches, and stopping unwatering manually will not actually stop it, and just will remove time penalty.
  // Here we fix it by not pumping water, when unwatering is not in progress
  let pump_water_mass_vel = ship_unwatering_remaining_time > 0.0f ? calc_pump_mass_vel(unit,
    ship_pumps_part_id,
    ship_cover_parts_water,
    ship_damage_control_unwatering_speed_mult,
    ship_water_mass_vel_mut
  ) : 0.0f

  for part_water, part_pos, compartment_id, inner_parts_range in ship_cover_parts_water, ship_cover_parts_pos, ship_cover_parts_compartment_id, ship_cover_parts_inner_parts
    if part_water.x <= 0.0f
      continue

    // update water level
    let prev_water = part_water.x
    part_water.x = max(0.0f, part_water.x + pump_water_mass_vel * info.dt)

    // restore pumped out parts
    for j in inner_parts_range.x..inner_parts_range.y
      let crit_water_level = ship_inner_parts_critical_water[j]
      if part_water.x <= crit_water_level && prev_water > crit_water_level
        sendEvent(eid, [[EventShipDrownedPartRestored partId=ship_inner_parts_ids[j]]])

    // calculate average breach position and total water amount
    additional_water += part_water.x
    let water_scale = min(part_water.x / part_water.y, 1.0f)
    avg_breach += part_pos * water_scale
    avg_breach_weight += water_scale
    if compartment_id >= 0
      avg_breach += float3(part_pos.x, part_pos.y, -part_pos.z) * water_scale
      avg_breach_weight += water_scale

  ship_phys_additional_water = additional_water
  ship_phys_water_leaking = avg_breach_weight > 0.0f
  if avg_breach_weight > 0.0f
    ship_phys_avg_breach_pos = avg_breach / avg_breach_weight


[es(tag=server)]
def ship_water_net_sync_es(info : UpdateStageInfoAct;
                           eid : EntityId;
                           ship_additional_water_left_side : float;
                           ship_additional_water_right_side : float;
                           ship_cover_parts_water : Point3List;
                           var ship_water_next_net_sync : float&)
  let current_time = float(get_app().usefulTotalTime)
  if ship_water_next_net_sync < current_time
    ship_water_next_net_sync = current_time + 5.0f
    send_water_net_sync_event(eid,
      ship_additional_water_left_side,
      ship_additional_water_right_side,
      ship_cover_parts_water)


def send_water_net_sync_event(eid : EntityId;
                              ship_additional_water_left_side : float;
                              ship_additional_water_right_side : float;
                              ship_cover_parts_water : Point3List)
  using() <| $(var cover_parts_water : FloatList)
    cover_parts_water |> reserve(length(ship_cover_parts_water))
    for part_water in ship_cover_parts_water
      cover_parts_water |> push(part_water.x)
    send_net_event(eid, [[EventShipWaterNetSync
      waterLeftSide = ship_additional_water_left_side,
      waterRightSide = ship_additional_water_right_side,
      coverPartsWater = ecs_addr(cover_parts_water)
    ]])


[es(tag=netClient)]
def ship_handle_water_net_sync_es(evt : EventShipWaterNetSync;
                                  var ship_additional_water_left_side : float&;
                                  var ship_additional_water_right_side : float&;
                                  var ship_cover_parts_water : Point3List&)
  ship_additional_water_left_side = evt.waterLeftSide
  ship_additional_water_right_side = evt.waterRightSide
  for part_water, cur_water in ship_cover_parts_water, *evt.coverPartsWater
    part_water.x = cur_water


def send_breaches_net_sync_event(eid : EntityId;
                                 ship_breaches_id : IntList;
                                 ship_breaches_pos : Point3List;
                                 ship_breaches_size : FloatList;
                                 ship_breaches_amount_to_repair : FloatList;
                                 ship_breaches_depth_scale : FloatList;
                                 ship_breaches_part_id : PartIdList;
                                 ship_breaches_cover_id : IntList;
                                 ship_breaches_leaked_amount : FloatList)
  let len = ship_breaches_id |> length()
  using() <| $(var breaches_ids : IntList)
    using() <| $(var breaches_pos_and_size : Point4List)
      using() <| $(var breaches_repair_progress : FloatList)
        breaches_ids |> reserve(len * 3)
        breaches_repair_progress |> reserve(len * 3)
        breaches_pos_and_size |> reserve(len)
        for i in 0..len
          breaches_ids |> push(ship_breaches_id[i])
          breaches_ids |> push(int(ship_breaches_part_id[i].packed))
          breaches_ids |> push(ship_breaches_cover_id[i])
          breaches_repair_progress |> push(ship_breaches_amount_to_repair[i])
          breaches_repair_progress |> push(ship_breaches_leaked_amount[i])
          breaches_repair_progress |> push(ship_breaches_depth_scale[i])
          let pos = ship_breaches_pos[i]
          breaches_pos_and_size |> push(float4(pos.x, pos.y, pos.z, ship_breaches_size[i]))
        send_net_event(eid, [[EventShipBreachesNetSync
          breachesIds = ecs_addr(breaches_ids),
          breachesPosAndSize = ecs_addr(breaches_pos_and_size),
          breachesRepairProgress = ecs_addr(breaches_repair_progress)
        ]])


[es(tag=netClient)]
def ship_handle_breaches_net_sync_es(evt : EventShipBreachesNetSync;
                                     var ship_breaches_id : IntList&;
                                     var ship_breaches_pos : Point3List&;
                                     var ship_breaches_normal : Point3List&;
                                     var ship_breaches_size : FloatList&;
                                     var ship_breaches_amount_to_repair : FloatList&;
                                     var ship_breaches_depth_scale : FloatList&;
                                     var ship_breaches_next_check : FloatList&;
                                     var ship_breaches_part_id : PartIdList&;
                                     var ship_breaches_cover_id : IntList&;
                                     var ship_breaches_leaked_amount : FloatList&;
                                     var ship_breaches_offender : BreachOffenderDataList&)
  let len = *evt.breachesPosAndSize |> length()
  ship_breaches_id |> resize(len)
  ship_breaches_pos |> resize(len)
  ship_breaches_normal |> resize(len)
  ship_breaches_size |> resize(len)
  ship_breaches_amount_to_repair |> resize(len)
  ship_breaches_depth_scale |> resize(len)
  ship_breaches_next_check |> resize(len)
  ship_breaches_part_id |> resize(len)
  ship_breaches_cover_id |> resize(len)
  ship_breaches_leaked_amount |> resize(len)
  ship_breaches_offender |> resize(len)

  assume packed_ids = *evt.breachesIds
  assume packed_pos_and_size = *evt.breachesPosAndSize
  assume packed_repair_progress = *evt.breachesRepairProgress
  for i in 0..len
    let pos_and_size = packed_pos_and_size[i]
    ship_breaches_pos[i] = float3(pos_and_size.x, pos_and_size.y, pos_and_size.z)
    ship_breaches_size[i] = pos_and_size.w
    ship_breaches_id[i] = packed_ids[i * 3]
    ship_breaches_part_id[i] := PartId(uint(packed_ids[i * 3 + 1]))
    ship_breaches_cover_id[i] = packed_ids[i * 3 + 2]
    ship_breaches_amount_to_repair[i] = packed_repair_progress[i * 3]
    ship_breaches_leaked_amount[i] = packed_repair_progress[i * 3 + 1]
    ship_breaches_depth_scale[i] = packed_repair_progress[i * 3 + 2]
    ship_breaches_normal[i] = float3(0, 1, 0)
    ship_breaches_next_check[i] = 0.0f


[es(tag=server)]
def ship_handle_net_sync_request_es(evt : EventShipRequestNetSync;
                                    eid : EntityId;
                                    ship_additional_water_left_side : float;
                                    ship_additional_water_right_side : float;
                                    ship_cover_parts_water : Point3List;
                                    ship_breaches_id : IntList;
                                    ship_breaches_pos : Point3List;
                                    ship_breaches_size : FloatList;
                                    ship_breaches_amount_to_repair : FloatList;
                                    ship_breaches_depth_scale : FloatList;
                                    ship_breaches_part_id : PartIdList;
                                    ship_breaches_cover_id : IntList;
                                    ship_breaches_leaked_amount : FloatList)
  send_breaches_net_sync_event(eid,
    ship_breaches_id,
    ship_breaches_pos,
    ship_breaches_size,
    ship_breaches_amount_to_repair,
    ship_breaches_depth_scale,
    ship_breaches_part_id,
    ship_breaches_cover_id,
    ship_breaches_leaked_amount)
  send_water_net_sync_event(eid,
    ship_additional_water_left_side,
    ship_additional_water_right_side,
    ship_cover_parts_water)
