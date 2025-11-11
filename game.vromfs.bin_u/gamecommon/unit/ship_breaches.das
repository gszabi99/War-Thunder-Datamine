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
require %game.dm.dm_events
require %game.unit.unit_events
require %game.unit.repair_system_events
require %game.unit.ship_events
require %game.utils.component_bundle_macro
require %dasGameLibs.math.base


[with_bundle(v)]
def load_cover_parts(blk : DataBlock&; add_compartment : bool;
                     unit : Unit?;
                     var loading_errors : array<string>&;
                     var v : tuple<
                       ship_cover_parts__partId : PartIdList;
                       ship_cover_parts__water : Point4List;
                       ship_cover_parts__pos : Point3List;
                       ship_cover_parts__weight : FloatList;
                       ship_cover_parts__compartmentId : IntList;
                       ship_cover_parts__innerPartsRange : IPoint2List;
                       ship_compartments__coverPartsRange : IPoint2List;
                       ship_cover_parts__innerPartsId : PartIdList;
                       ship_cover_parts__innerPartsCriticalWater : FloatList
                       >) : float
  assume unit_dm = *unit.visual
  let compartment_id = add_compartment ? length(v.ship_compartments__coverPartsRange) : -1
  let cover_parts_start = length(v.ship_cover_parts__partId)
  var cover_parts_end = cover_parts_start
  var weights_sum = 0.0f
  blk |> datablock_for_each_block("cover") <| $(cover)
    let cover_part_name = cover |> datablock_getStr("part", "")
    let weight = cover |> datablock_getReal("weight", 1.0f)
    let max_water_alive = cover |> datablock_getReal("maxWaterAlive", 1.0f)
    if weight <= 0.0f || max_water_alive < 0.0f || max_water_alive > 1.0f
      loading_errors |> push("invalid cover part {cover_part_name} maxWaterAlive={max_water_alive} or weight={weight}")
      return
    let cover_part_no = get_dm_part_id_by_dm_name(cover_part_name)
    let cover_part_id = unit_dm |> dm_get_remap(cover_part_no)

    if dm_part_id_valid(cover_part_id)
      v.ship_cover_parts__partId |> push(cover_part_id)
      v.ship_cover_parts__water |> push(float4(0.f, 0.f, 0.f, max_water_alive))
      v.ship_cover_parts__weight |> push(weight)
      v.ship_cover_parts__compartmentId |> push(compartment_id)

      if cover |> datablock_param_exists("pos", -1)
        v.ship_cover_parts__pos |> push(cover |> datablock_getPoint3("pos", float3(0, 0, 0)))
      else
        let node = unit_dm |> dm_get_collision_node_by_part_id(cover_part_no)
        assert(node != null)
        v.ship_cover_parts__pos |> push(node.tm * node.modelBBox.center)

      let inner_parts_start = length(v.ship_cover_parts__innerPartsId)
      var inner_parts_end = inner_parts_start
      cover |> datablock_get_block("innerParts") <| $(inner_parts)
        inner_parts |> datablock_for_each_block() <| $(inner_part)
          let inner_part_name = inner_part |> datablock_getStr("partNo", "")
          let inner_part_no = get_dm_part_id_by_dm_name(inner_part_name)
          let inner_part_id = unit_dm |> dm_get_remap(inner_part_no)
          if !dm_part_id_valid(inner_part_id)
            if inner_part_no < 0
              loading_errors |> push("invalid inner part partNo '{inner_part_name}', part is skipped")
            return
          let crit_water_level = inner_part |> datablock_getReal("critWaterLevel", 1.0f)
          assert(crit_water_level >= 0.0f && crit_water_level <= 1.0f)
          v.ship_cover_parts__innerPartsId |> push(inner_part_id)
          v.ship_cover_parts__innerPartsCriticalWater |> push(crit_water_level)
          inner_parts_end++
      v.ship_cover_parts__innerPartsRange |> push(int2(inner_parts_start, inner_parts_end))

      weights_sum += weight
      cover_parts_end++
    elif cover_part_no < 0
      loading_errors |> push("invalid cover part '{cover_part_name}'")

  if add_compartment
    v.ship_compartments__coverPartsRange |> push(int2(cover_parts_start, cover_parts_end))
  return weights_sum


[es(on_event=EventUnitRepair, on_event=EventUnitRespawn)]
def ship_repair_handler_es(evt : Event;
                           var ship_cover_parts__water : Point4List&;
                           var ship_breaches__id : IntList&;
                           var ship_breaches__pos : Point3List&;
                           var ship_breaches__normal : Point3List&;
                           var ship_breaches__size : FloatList&;
                           var ship_breaches__amountToRepair : FloatList&;
                           var ship_breaches__depthScale : FloatList&;
                           var ship_breaches__nextCheck : FloatList&;
                           var ship_breaches__partId : PartIdList&;
                           var ship_breaches__coverId : IntList&;
                           var ship_breaches__leakedAmount : FloatList&;
                           var ship_breaches__offender : BreachOffenderDataList&;
                           var ship_breaches__fatalPartId : PartId&;
                           var ship__repairBreachesRemainingTime : float&;
                           var ship__unwateringRemainingTime : float&;
                           var ship_flooding__waterLeftSide : float&;
                           var ship_flooding__waterRightSide : float&;
                           var ship_flooding__floodStep : int&)
  for water in ship_cover_parts__water
    water.x = 0.0f
    water.y = 0.0f

  ship_breaches__id |> clear()
  ship_breaches__pos |> clear()
  ship_breaches__normal |> clear()
  ship_breaches__size |> clear()
  ship_breaches__amountToRepair |> clear()
  ship_breaches__depthScale |> clear()
  ship_breaches__nextCheck |> clear()
  ship_breaches__partId |> clear()
  ship_breaches__coverId |> clear()
  ship_breaches__leakedAmount |> clear()
  ship_breaches__offender |> clear()
  ship_breaches__fatalPartId = PartId()

  ship__repairBreachesRemainingTime = -1.0f
  ship__unwateringRemainingTime = -1.0f
  ship_flooding__waterLeftSide = 0.0f
  ship_flooding__waterRightSide = 0.0f
  ship_flooding__floodStep = 1


[es, with_bundle(v)]
def ship_init_cover_parts_handle_es(evt : CmdInitComponent;
                                    var unit__ref : UnitRef;
                                    var v : tuple<
                                      ship_cover_parts__disableDeadParts : bool;
                                      ship_cover_parts__partId : PartIdList;
                                      ship_cover_parts__water : Point4List;
                                      ship_cover_parts__pos : Point3List;
                                      ship_cover_parts__weight : FloatList;
                                      ship_cover_parts__compartmentId : IntList;
                                      ship_cover_parts__innerPartsRange : IPoint2List;
                                      ship_compartments__coverPartsRange : IPoint2List;
                                      ship_cover_parts__innerPartsId : PartIdList;
                                      ship_cover_parts__innerPartsCriticalWater : FloatList
                                      >) : void
  let unit = unit__ref.unit
  assert(unit != null)
  if unit == null
    return

  v.ship_cover_parts__partId |> clear()
  v.ship_cover_parts__water |> clear()
  v.ship_cover_parts__pos |> clear()
  v.ship_cover_parts__weight |> clear()
  v.ship_cover_parts__compartmentId |> clear()
  v.ship_cover_parts__innerPartsRange |> clear()
  v.ship_compartments__coverPartsRange |> clear()
  v.ship_cover_parts__innerPartsId |> clear()
  v.ship_cover_parts__innerPartsCriticalWater |> clear()

  v.ship_cover_parts__disableDeadParts = *evt.modelBlk |> datablock_getBool("shipsDisableDeadCoverParts", get_game_params().shipsDisableDeadCoverParts)

  var loading_errors : array<string>
  *evt.modelBlk |> datablock_get_block("shipCover") <| $(blk)
    var weights_sum = load_cover_parts(blk, false, unit, loading_errors) <| v

    blk |> datablock_for_each_block("compartment") <| $(compartment)
      weights_sum += load_cover_parts(compartment, true, unit, loading_errors) <| v

    let ship = unit |> as_ship()
    let ship_props = ship.shipProps
    for weight, water, inner_parts in v.ship_cover_parts__weight, v.ship_cover_parts__water, v.ship_cover_parts__innerPartsRange
      weight = safediv(weight, weights_sum)
      water.z = ship_props.additionalWaterCoverPartsThreshold * weight
      for i in range(inner_parts.x, inner_parts.y)
        v.ship_cover_parts__innerPartsCriticalWater[i] *= water.z

  if !empty(loading_errors)
    var msg = "failed to load cover parts for {unit.props.fileName}:"
    for err in loading_errors
      msg += "\n  " + err
    logerr(msg)


[es(tag=netClient, after=ship_init_cover_parts_handle_es)]
def ship_request_net_sync_on_load_es(evt : CmdInitComponent; eid : EntityId)
  send_net_event(eid, EventShipRequestNetSync())


[es]
def ship_init_mod_handle_es(evt : CmdInitComponent;
                            var unit__ref : UnitRef;
                            var ship__waterMassVelMult : float&)
  let unit = unit__ref.unit
  assert(unit != null)
  if unit != null && unit.modBlk != null
    let defaultVal = unit.isHumanPlayer ? 1.0f : 0.0f
    ship__waterMassVelMult = unit.modBlk |> datablock_getReal("waterMassVelMult", defaultVal)


[es]
def ship_init_damage_parts_handle_es(evt : EventShipInitDamageParts;
                                     var ship__pumpsPartId : IntList&)
  ship__pumpsPartId := evt.pumps


[es]
def ship_init_repair_parts_info_handle_es(evt : CmdInitComponent;
                                          var unit__ref : UnitRef;
                                          var ship_repair__partsPartId : IntList&;
                                          var ship_repair__partsTime : FloatList&;
                                          var ship_repair__partsHp : FloatList&)
  let unit = unit__ref.unit
  assert(unit != null)
  if unit == null
    return
  assume dm = *unit.visual

  *evt.modelBlk |> datablock_get_block("partsToRepair") <| $(blk)
    blk |> datablock_for_each_block() <| $(part_info)
      let partNo = get_dm_part_id_by_dm_name(part_info.getBlockName)
      let partId = dm |> dm_get_remap(partNo)
      if !partId |> dm_part_id_valid()
        return
      ship_repair__partsPartId |> push(partNo)
      ship_repair__partsTime |> push(part_info |> datablock_getReal("time", 60.0f))
      ship_repair__partsHp |> push(part_info |> datablock_getReal("hp", 0.5f))



[es]
def ship_copy_from_handle_es(evt : EventShipCopyFrom;
                             var ship_flooding__waterLeftSide : float&;
                             var ship_flooding__waterRightSide : float&)
  var additional_water_left_side = ship_flooding__waterLeftSide
  var additional_water_right_side = ship_flooding__waterRightSide

  query(evt.eid) <| $ [es] (
                            ship_flooding__waterLeftSide : float;
                            ship_flooding__waterRightSide : float
                            )
    additional_water_left_side = ship_flooding__waterLeftSide
    additional_water_right_side = ship_flooding__waterRightSide

  ship_flooding__waterLeftSide = additional_water_left_side
  ship_flooding__waterRightSide = additional_water_right_side


[with_bundle(v)]
def is_cover_part_dead_cover_id(unit : Unit const?; cover_id : int; v : tuple<ship_cover_parts__disableDeadParts : bool; ship_cover_parts__partId : PartIdList>) : bool
  return v.ship_cover_parts__disableDeadParts && is_part_dead(unit.dmData, v.ship_cover_parts__partId[cover_id])


[with_bundle(v)]
def is_cover_part_dead_part_id(unit : Unit const?; part_id : PartId; v : tuple<ship_cover_parts__disableDeadParts : bool>) : bool
  return v.ship_cover_parts__disableDeadParts && is_part_dead(unit.dmData, part_id)


[with_bundle(v)]
def has_any_repairable_breaches(unit : Unit const?; v : tuple<
                                  ship_cover_parts__disableDeadParts : bool;
                                  ship_breaches__amountToRepair : FloatList;
                                  ship_breaches__coverId : IntList;
                                  ship_cover_parts__partId : PartIdList
                                  >) : bool
  assume dmData = unit.dmData
  let allow_dead_covers = get_difficulty_config().shipAllowRepairBreachesInDeadCovers
  for amount_to_repair, cover_id in v.ship_breaches__amountToRepair, v.ship_breaches__coverId
    if amount_to_repair > 0.0f && (allow_dead_covers || !is_cover_part_dead_cover_id(unit, cover_id) <| v)
      return true
  return false


[with_bundle(v)]
def calc_repair_speed_mult(unit : Unit const?; v : tuple<
                             ship_damage_control__isPresetBased : bool;
                             ship_damage_control__repairSpeedMult : float;
                             ship_damage_control__unwateringSpeedMult : float
                             >) : float
  let ship = as_ship(unit)
  var repair_speed_mult = (ship != null ? ship.crewAliveMult : 1.0f) * ship.shipProps.breachRepairSpeed
  if v.ship_damage_control__isPresetBased
    repair_speed_mult *= v.ship_damage_control__repairSpeedMult
  else
    repair_speed_mult *= v.ship_damage_control__unwateringSpeedMult
  return repair_speed_mult


[with_bundle(v)]
def calc_time_to_repair_breaches(unit : Unit const?; repair_speed_mult : float;
                                 v : tuple<
                                   ship_cover_parts__disableDeadParts : bool;
                                   ship_breaches__amountToRepair : FloatList;
                                   ship_breaches__coverId : IntList;
                                   ship_cover_parts__partId : PartIdList
                                   >) : float
  var time = 0.0f
  let allow_dead_covers = get_difficulty_config().shipAllowRepairBreachesInDeadCovers
  for amount_to_repair, cover_id in v.ship_breaches__amountToRepair, v.ship_breaches__coverId
    if allow_dead_covers || !is_cover_part_dead_cover_id(unit, cover_id) <| v
      time = max(time, amount_to_repair / repair_speed_mult)
  return time


[with_bundle(v)]
def calc_pump_mass_vel(unit : Unit const?;
                       v : tuple<
                         ship__pumpsPartId : IntList;
                         ship_cover_parts__water : Point4List;
                         ship_damage_control__unwateringSpeedMult : float;
                         ship__waterMassVelMult : float
                         >) : float
  let ship = as_ship(unit)
  if ship == null
    return 0.0f
  assume unit_dm = *unit.visual
  let ship_props = ship.shipProps

  var num_cover_parts = 0
  for water in v.ship_cover_parts__water
    if water.x > 0.0f
      num_cover_parts++

  if num_cover_parts > 0
    var pumps_total_rel_hp = 0.0f
    var pumps_count = 0
    for pump_part_id in v.ship__pumpsPartId
      let partId = unit_dm |> dm_get_remap(pump_part_id)
      if partId |> dm_part_id_valid()
        pumps_count++
        pumps_total_rel_hp += unit_dm |> dm_get_rel_hp(pump_part_id)

    let pump_readiness = lerp(get_difficulty_config().shipBrokenPumpMaxWaterMassVelMult, 1.0, safediv(pumps_total_rel_hp, float(pumps_count)))
    return (v.ship__waterMassVelMult * ship_props.breachWaterMassVel * v.ship_damage_control__unwateringSpeedMult *
            pump_readiness / float(num_cover_parts))

  return 0.0f


[with_bundle(v)]
def calc_time_to_unwater(unit : Unit const?;
                         v : tuple<
                           ship_cover_parts__disableDeadParts : bool;
                           ship__pumpsPartId : IntList;
                           ship_cover_parts__water : Point4List;
                           ship_cover_parts__partId : PartIdList;
                           ship_damage_control__unwateringSpeedMult : float;
                           ship__waterMassVelMult : float
                           >) : float
  let pump_water_mass_vel = abs(calc_pump_mass_vel(unit) <| v)

  var res_time = 0.0f
  var count_parts = 0
  if pump_water_mass_vel > 0.0f
    for water, part_id in v.ship_cover_parts__water, v.ship_cover_parts__partId
      if water.x > 0.0f && !is_cover_part_dead_part_id(unit, part_id) <| v
        res_time += water.x / pump_water_mass_vel
        count_parts++
    if count_parts > 0
      res_time /= float(count_parts)

  return res_time


[es(no_order), with_bundle(v)]
def ship_repair_breaches_update_es(info : UpdateStageInfoAct;
                                   eid : EntityId;
                                   unit__ref : UnitRef;
                                   v : tuple<
                                     ship_damage_control__isPresetBased : bool;
                                     ship_cover_parts__disableDeadParts : bool;
                                     ship__repairBreachesRemainingTime : float -const;
                                     repair_system_remaining_repair_time : float;
                                     ship_damage_control__unwateringSpeedMult : float;
                                     ship_damage_control__repairSpeedMult : float;
                                     ship_breaches__id : IntList;
                                     ship_breaches__amountToRepair : FloatList -const;
                                     ship_breaches__coverId : IntList;
                                     ship_cover_parts__water : Point4List;
                                     ship_cover_parts__partId : PartIdList;
                                     ship__pumpsPartId : IntList;
                                     ship__waterMassVelMult : float;
                                     ship__unwateringRemainingTime : float -const
                                     >) : void
  let unit = unit__ref.unit
  let ship = unit |> as_ship()
  if ship == null || unit.isDelayed
    return

  let was_repairing_breaches = v.ship__repairBreachesRemainingTime > 0.0f
  if v.ship__repairBreachesRemainingTime > 0.0f || v.repair_system_remaining_repair_time > 0.0f && v.ship_damage_control__isPresetBased
    let repair_speed_mult = calc_repair_speed_mult(unit) <| v
    v.ship__repairBreachesRemainingTime = calc_time_to_repair_breaches(unit, repair_speed_mult) <| v

    let allow_dead_covers = get_difficulty_config().shipAllowRepairBreachesInDeadCovers
    for breach_id, amount_to_repair, cover_id in v.ship_breaches__id, v.ship_breaches__amountToRepair, v.ship_breaches__coverId
      if !allow_dead_covers && is_cover_part_dead_cover_id(unit, cover_id) <| v
        continue
      if amount_to_repair > 0.0f
        amount_to_repair -= repair_speed_mult * info.dt
      if amount_to_repair <= 0.0f
        amount_to_repair = 0.0f
        sendEvent(eid, EventShipRemoveBreach(breachId = breach_id))

  if was_repairing_breaches && v.ship__repairBreachesRemainingTime <= 0.0f
    v.ship__unwateringRemainingTime = calc_time_to_unwater(unit) <| v
    sendEvent(eid, EventShipSyncWater())


def soa_safe_erase(var arr; idx)
  if idx < length(arr)
    erase(arr, idx)


[es]
def ship_remove_breach_handle_es(evt : EventShipRemoveBreach;
                                 eid : EntityId;
                                 var ship_breaches__id : IntList&;
                                 var ship_breaches__pos : Point3List&;
                                 var ship_breaches__normal : Point3List&;
                                 var ship_breaches__size : FloatList&;
                                 var ship_breaches__amountToRepair : FloatList&;
                                 var ship_breaches__depthScale : FloatList&;
                                 var ship_breaches__nextCheck : FloatList&;
                                 var ship_breaches__partId : PartIdList&;
                                 var ship_breaches__coverId : IntList&;
                                 var ship_breaches__leakedAmount : FloatList&;
                                 var ship_breaches__offender : BreachOffenderDataList&)
  for i in iter_range(ship_breaches__id)
    if ship_breaches__id[i] == evt.breachId
      let local_pos = ship_breaches__pos[i]
      ship_breaches__id |> soa_safe_erase(i)
      ship_breaches__pos |> soa_safe_erase(i)
      ship_breaches__normal |> soa_safe_erase(i)
      ship_breaches__size |> soa_safe_erase(i)
      ship_breaches__amountToRepair |> soa_safe_erase(i)
      ship_breaches__depthScale |> soa_safe_erase(i)
      ship_breaches__nextCheck |> soa_safe_erase(i)
      ship_breaches__partId |> soa_safe_erase(i)
      ship_breaches__coverId |> soa_safe_erase(i)
      ship_breaches__leakedAmount |> soa_safe_erase(i)
      ship_breaches__offender |> soa_safe_erase(i)
      sendEvent(eid, EventShipOnRemoveBreach(localPos = local_pos))
      break


def soa_safe_emplace(var arr; idx; item)
  let len = length(arr)
  if len == idx
    arr |> push(item)
  else
    if len < idx
      arr |> resize(idx + 1)
    arr[idx] = item


[es]
def add_breach_handle_es(evt : EventShipAddBreach;
                         eid : EntityId;
                         unit__ref : UnitRef;
                         ship_damage_control__isPresetBased : bool;
                         ship_cover_parts__partId : PartIdList;
                         var ship_breaches__id : IntList&;
                         var ship_breaches__pos : Point3List&;
                         var ship_breaches__normal : Point3List&;
                         var ship_breaches__size : FloatList&;
                         var ship_breaches__amountToRepair : FloatList&;
                         var ship_breaches__depthScale : FloatList&;
                         var ship_breaches__nextCheck : FloatList&;
                         var ship_breaches__partId : PartIdList&;
                         var ship_breaches__coverId : IntList&;
                         var ship_breaches__leakedAmount : FloatList&;
                         var ship_breaches__offender : BreachOffenderDataList&;
                         var ship__unwateringRemainingTime : float&)
  if evt.id < 0
    return

  let unit = unit__ref.unit
  let ship = as_ship(unit)
  if ship == null || unit.isDelayed
    return

  var cover_id = -1
  let part_id = evt.partId
  for i in iter_range(ship_cover_parts__partId)
    if ship_cover_parts__partId[i].id == part_id.id
      cover_id = i
      break
  if cover_id < 0
    return

  let box = (*unit).boundingBox
  let ship_props = ship.shipProps
  var pos = evt.localPos
  pos.x = clamp(pos.x, box.boxMin.x, box.boxMax.x)
  pos.y = clamp(pos.y, box.boxMin.y, box.boxMax.y)
  pos.z = clamp(pos.z, box.boxMin.z, box.boxMax.z)
  let size = min(evt.size, box.width.x / 8.f) 
  let amountToRepair = cvt(size, ship_props.breachSizeToRepair.x, ship_props.breachSizeToRepair.y, ship_props.breachSizeToRepair.z, ship_props.breachSizeToRepair.w)

  
  let MAX_BREACHES_COUNT = 100
  var breach_id_to_remove = -1
  if length(ship_breaches__id) >= MAX_BREACHES_COUNT
    var min_size = size
    for breach_id, breach_size in ship_breaches__id, ship_breaches__size
      if min_size >= breach_size
        min_size = breach_size
        breach_id_to_remove = breach_id
    if breach_id_to_remove == -1
      return

  let idx = length(ship_breaches__id)
  ship_breaches__id |> soa_safe_emplace(idx, evt.id)
  ship_breaches__pos |> soa_safe_emplace(idx, pos)
  ship_breaches__normal |> soa_safe_emplace(idx, evt.localNormal)
  ship_breaches__size |> soa_safe_emplace(idx, size)
  ship_breaches__amountToRepair |> soa_safe_emplace(idx, amountToRepair)
  ship_breaches__depthScale |> soa_safe_emplace(idx, 0.0f)
  ship_breaches__nextCheck |> soa_safe_emplace(idx, float(get_app().usefulTotalTime))
  ship_breaches__partId |> soa_safe_emplace(idx, part_id)
  ship_breaches__coverId |> soa_safe_emplace(idx, cover_id)
  ship_breaches__leakedAmount |> soa_safe_emplace(idx, 0.0f)
  ship_breaches__offender |> soa_safe_emplace(idx, evt.offender)

  sendEvent(eid, EventShipOnGotBreach(breachId = evt.id, localPos = evt.localPos, offender = evt.offender))
  if ship__unwateringRemainingTime > 0.0f
    ship__unwateringRemainingTime = -1.0f
    sendEvent(eid, EventShipSyncWater())
    sendEvent(eid, EventShipRequestRepairBreaches(repair = true))
  elif ship_damage_control__isPresetBased
    sendEvent(eid, EventShipRequestRepairBreaches(repair = true))

  if breach_id_to_remove != -1
    sendEvent(eid, EventShipRemoveBreach(breachId = breach_id_to_remove))


[es]
def add_fatal_breach_handle_es(evt : EventShipAddFatalBreach;
                               eid : EntityId;
                               unit__ref : UnitRef;
                               var ship_breaches__nextId : int&;
                               var ship_breaches__fatalPartId : PartId&;
                               ship_cover_parts__partId : PartIdList;
                               ship_cover_parts__water : Point4List)
  if ship_breaches__fatalPartId.valid
    return

  let unit = unit__ref.unit
  let ship = unit |> as_ship()
  if ship == null || unit.isDelayed
    return

  let part_id = evt.partId
  let ship_props = ship.shipProps
  for i in iter_range(ship_cover_parts__partId)
    if ship_cover_parts__partId[i].id == part_id.id
      ship_breaches__fatalPartId = part_id
      if unit.isAuthority
        sendEvent(eid, EventShipAddBreach(
          id = ship_breaches__nextId++,
          partId = part_id,
          size = ship_cover_parts__water[i].z / (ship_props.fatalBreachDrownTime * 50.0f * ship_props.breachWaterMassMult),
          localPos = evt.localPos,
          localNormal = evt.localNormal,
          offender = evt.offender
        ))
      break


[es(after=ship_repair_breaches_update_es), with_bundle(v)]
def ship_unwatering_update_es(info : UpdateStageInfoAct;
                              eid : EntityId;
                              unit__ref : UnitRef;
                              v : tuple<
                                ship_cover_parts__disableDeadParts : bool;
                                ship_breaches__amountToRepair : FloatList;
                                ship_breaches__coverId : IntList;
                                ship__pumpsPartId : IntList;
                                ship_cover_parts__water : Point4List;
                                ship_cover_parts__partId : PartIdList;
                                ship_damage_control__unwateringSpeedMult : float;
                                ship__waterMassVelMult : float;
                                ship__unwateringRemainingTime : float -const
                                >)
  if v.ship__unwateringRemainingTime > 0.0f
    let unit = unit__ref.unit
    if unit.isDelayed
      return
    
    if !has_any_repairable_breaches(unit, v)
      v.ship__unwateringRemainingTime = calc_time_to_unwater(unit) <| v
    else
      v.ship__unwateringRemainingTime = -1.0f
      sendEvent(eid, EventShipSyncWater())


[es, with_bundle(v)]
def ship_request_repair_breaches_handle_es(evt : EventShipRequestRepairBreaches;
                                           eid : EntityId;
                                           unit__ref : UnitRef;
                                           v : tuple<
                                             ship_cover_parts__disableDeadParts : bool;
                                             ship_damage_control__isPresetBased : bool;
                                             ship__repairBreachesRemainingTime : float -const;
                                             ship_damage_control__repairSpeedMult : float;
                                             ship_damage_control__unwateringSpeedMult : float;
                                             ship_breaches__amountToRepair : FloatList;
                                             ship_breaches__coverId : IntList;
                                             ship__unwateringRemainingTime : float -const;
                                             ship__pumpsPartId : IntList;
                                             ship_cover_parts__water : Point4List;
                                             ship_cover_parts__partId : PartIdList;
                                             ship__waterMassVelMult : float
                                             >)
  if evt.repair
    if v.ship__repairBreachesRemainingTime <= 0.0f && v.ship__unwateringRemainingTime <= 0.0f
      let unit = unit__ref.unit
      let ship = unit |> as_ship()
      if ship != null && !unit.isDelayed && !ship.isVeryFewCrew && !ship.isCoverDestroyed
        let repair_speed_mult = calc_repair_speed_mult(unit) <| v
        let time_to_repair = calc_time_to_repair_breaches(unit, repair_speed_mult) <| v
        if time_to_repair > 0.0f
          v.ship__repairBreachesRemainingTime = time_to_repair
        elif v.ship__repairBreachesRemainingTime <= 0.0f
          let time_to_unwater = calc_time_to_unwater(unit) <| v
          if time_to_unwater > 0.0f
            v.ship__unwateringRemainingTime = time_to_unwater
      sendEvent(eid, EventShipSyncWater())
  else
    v.ship__repairBreachesRemainingTime = 0.0f
    v.ship__unwateringRemainingTime = 0.0f
    sendEvent(eid, EventShipSyncWater())


[es(no_order)]
def ship_repair_parts_update_es(info : UpdateStageInfoAct;
                                var unit__ref : UnitRef;
                                var ship_repair__partIdx : int&;
                                var ship_repair__partRemainingTime : float&;
                                ship_repair__partsPartId : IntList;
                                ship_repair__partsTime : FloatList;
                                ship_repair__partsHp : FloatList)
  var unit = unit__ref.unit
  if unit.isDelayed
    return
  assume unit_dm = *unit.visual

  
  if ship_repair__partIdx >= 0
    ship_repair__partRemainingTime -= info.dt
    if ship_repair__partRemainingTime <= 0.0f
      unit_dm |> dm_set_rel_hp(ship_repair__partsPartId[ship_repair__partIdx], ship_repair__partsHp[ship_repair__partIdx], false)
      ship_repair__partIdx = -1

  if ship_repair__partIdx < 0
    for i in 0..length(ship_repair__partsPartId)
      if unit_dm |> dm_get_rel_hp(ship_repair__partsPartId[i]) > 0.0f
        continue
      ship_repair__partIdx = i
      ship_repair__partRemainingTime = ship_repair__partsTime[i]
      break


[es(after=ship_repair_parts_update_es)]
def ship_breaches_add_water_update_es(info : UpdateStageInfoAct;
                                      eid : EntityId;
                                      var unit__ref : UnitRef;
                                      ship_phys_proxy__velocitySq : float;
                                      ship_phys_proxy__groundCollision : bool;
                                      ship_breaches__fatalPartId : PartId;
                                      ship_breaches__partId : PartIdList;
                                      ship_breaches__coverId : IntList;
                                      ship_breaches__pos : Point3List;
                                      ship_breaches__size : FloatList;
                                      ship_breaches__amountToRepair : FloatList;
                                      var ship_breaches__nextCheck : FloatList&;
                                      var ship_breaches__depthScale : FloatList&;
                                      var ship_breaches__leakedAmount : FloatList&;
                                      ship_cover_parts__partId : PartIdList;
                                      var ship_cover_parts__water : Point4List&;
                                      ship_cover_parts__compartmentId : IntList;
                                      ship_cover_parts__innerPartsRange : IPoint2List;
                                      ship_cover_parts__innerPartsId : PartIdList;
                                      ship_cover_parts__innerPartsCriticalWater : FloatList;
                                      ship_compartments__coverPartsRange : IPoint2List)
  let unit = unit__ref.unit
  let ship = unit |> as_ship()
  if ship == null || unit.isDelayed
    return
  assume dmData = unit.dmData
  let ship_props = ship.shipProps
  let is_dead = !unit.isAlive
  let current_time = float(get_app().usefulTotalTime)

  for part_id, cover_id, pos, size, amount_to_repair, next_check, depth_scale, leaked_amount in ship_breaches__partId, ship_breaches__coverId, ship_breaches__pos, ship_breaches__size, ship_breaches__amountToRepair, ship_breaches__nextCheck, ship_breaches__depthScale, ship_breaches__leakedAmount
    let is_fatal = is_dead || part_id.id == ship_breaches__fatalPartId.id

    var water_mass_velocity = 0.0f
    if amount_to_repair > 0.0f
      water_mass_velocity = size * (50.0f + ship_phys_proxy__velocitySq) * ship_props.breachWaterMassMult

    
    if !is_fatal && current_time > next_check
      let world_pos = unit.unitTm * pos
      let bottom_world_pos = world_pos - float3(0.0f, size, 0.0f)
      var breach_underwater = false
      var water_height = 0.0f
      get_app().currentScene |> scene_get_water_height( water_height,  breach_underwater, bottom_world_pos,  100.0f,  true)
      depth_scale = breach_underwater ? min((water_height - (world_pos.y - size)) / (2.0f * size), 1.0f) : -1.0f
      next_check = current_time + 1.0f

    
    if depth_scale > 0.0 || is_fatal
      let water_delta = (is_fatal ? 1.0f : depth_scale) * water_mass_velocity * info.dt
      let compartment_id = ship_cover_parts__compartmentId[cover_id]
      let cover_parts_range = compartment_id >= 0 ? ship_compartments__coverPartsRange[compartment_id] : int2(cover_id, cover_id + 1)

      
      for i in cover_parts_range.x..cover_parts_range.y
        
        var max_water = ship_cover_parts__water[i].z
        if !is_part_dead(dmData, ship_cover_parts__partId[i]) 
          max_water *= ship_cover_parts__water[i].w 

        
        let prev_water = ship_cover_parts__water[i].x
        ship_cover_parts__water[i].x = min(max(ship_cover_parts__water[i].x + water_delta, 0.0f), max_water)
        let isWaterAdding = !is_equal_float(prev_water, ship_cover_parts__water[i].x)
        if !ship_phys_proxy__groundCollision && isWaterAdding
          let total_water = ship_cover_parts__water[i].x
          ship_cover_parts__water[i].y = clamp(ship_cover_parts__water[i].y + sign(pos.z) * water_delta, -total_water, total_water)
        leaked_amount += water_delta

        
        if prev_water < max_water && ship_cover_parts__water[i].x == max_water
          sendEvent(eid, EventShipSyncWater())

        
        let inner_parts_range = ship_cover_parts__innerPartsRange[i]
        for j in inner_parts_range.x..inner_parts_range.y
          let crit_water_level = ship_cover_parts__innerPartsCriticalWater[j]
          if ship_cover_parts__water[i].x > crit_water_level && prev_water <= crit_water_level
            sendEvent(eid, EventShipPartDrowned(packedPartId = ship_cover_parts__innerPartsId[j].packed))


[es(after=ship_breaches_add_water_update_es), with_bundle(v)]
def ship_breaches_pump_water_update_es(info : UpdateStageInfoAct;
                                       eid : EntityId;
                                       unit__ref : UnitRef;
                                       v : tuple<
                                         ship_cover_parts__disableDeadParts : bool;
                                         ship_phys_proxy__additionalWater : float -const;
                                         ship_phys_proxy__waterLeaking : bool -const;
                                         ship_phys_proxy__avgBreachPos : float3 -const;
                                         ship_cover_parts__partId : PartIdList;
                                         ship_cover_parts__water : Point4List -const;
                                         ship_cover_parts__pos : Point3List;
                                         ship_cover_parts__compartmentId : IntList;
                                         ship_cover_parts__innerPartsRange : IPoint2List;
                                         ship_cover_parts__innerPartsId : PartIdList;
                                         ship_cover_parts__innerPartsCriticalWater : FloatList;
                                         ship__pumpsPartId : IntList;
                                         ship_damage_control__unwateringSpeedMult : float;
                                         ship__waterMassVelMult : float;
                                         ship__unwateringRemainingTime : float;
                                         ship_flooding__waterLeftSide : float -const;
                                         ship_flooding__waterRightSide : float -const
                                         >)
  
  let unit = unit__ref.unit
  let ship = as_ship(unit)
  if ship == null || unit.isDelayed
    return

  var additional_water = 0.0f
  var avg_breach = float3(0.0f, 0.0f, 0.0f)
  var avg_breach_weight = 0.0f

  
  
  
  let pump_water_mass_vel = v.ship__unwateringRemainingTime > 0.0f ? calc_pump_mass_vel(unit) <| v : 0.0f

  var totalWaterLeftSide = 0.0f
  var totalWaterRightSide = 0.0f
  for part_water, part_pos, compartment_id, inner_parts_range, part_id in v.ship_cover_parts__water, v.ship_cover_parts__pos, v.ship_cover_parts__compartmentId, v.ship_cover_parts__innerPartsRange, v.ship_cover_parts__partId
    if part_water.x <= 0.0f
      continue

    assume dmData = unit.dmData
    let is_dead_cover = is_cover_part_dead_part_id(unit, part_id) <| v

    if is_dead_cover
      let maxWater = part_water.z
      let waterDir = sign(part_water.y)
      let counter_flooding_level = ship == null ? 0.f : ship.shipProps.deadCoverCounterfloodingRel
      let balance = safediv(v.ship_flooding__waterLeftSide - v.ship_flooding__waterRightSide, ship.shipProps.additionalSideWaterThreshold)
      let threshold = (counter_flooding_level - 0.5f) * 2.f
      let needCounterFlooding = waterDir > 0.f ? balance > -threshold : balance < threshold
      ship.shipProps.additionalSideWaterThreshold
      if counter_flooding_level > 0.f && is_equal_float(part_water.x, part_water.z) && needCounterFlooding
        if is_equal_float(part_water.x, part_water.y)
          *ship |> onStraighteningRoll()
        let pumpedDelta = ship.shipProps.counterFloodingWaterMassVel * info.dt
        part_water.y = clamp(part_water.y - waterDir * pumpedDelta, -maxWater, maxWater)
    else
      
      let prev_water = part_water.x
      let roll_ratio = part_water.y / part_water.x
      part_water.x = max(0.0f, part_water.x + pump_water_mass_vel * info.dt)
      part_water.y = part_water.x * roll_ratio

      
      for j in inner_parts_range.x..inner_parts_range.y
        let crit_water_level = v.ship_cover_parts__innerPartsCriticalWater[j]
        if part_water.x <= crit_water_level && prev_water > crit_water_level
          sendEvent(eid, EventShipDrownedPartRestored(packedPartId = v.ship_cover_parts__innerPartsId[j].packed))

    
    additional_water += part_water.x
    let water_scale = min(part_water.x / part_water.z, 1.0f)
    avg_breach += part_pos * water_scale
    avg_breach_weight += water_scale
    if compartment_id >= 0
      avg_breach += float3(part_pos.x, part_pos.y, -part_pos.z) * water_scale
      avg_breach_weight += water_scale

    totalWaterLeftSide += (part_water.x + part_water.y) / 2.0f
    totalWaterRightSide += (part_water.x - part_water.y) / 2.0f

  v.ship_flooding__waterLeftSide = clamp(totalWaterLeftSide, 0.0f, ship.shipProps.additionalSideWaterThreshold)
  v.ship_flooding__waterRightSide = clamp(totalWaterRightSide, 0.0f, ship.shipProps.additionalSideWaterThreshold)
  v.ship_phys_proxy__additionalWater = additional_water
  v.ship_phys_proxy__waterLeaking = avg_breach_weight > 0.0f
  if avg_breach_weight > 0.0f
    v.ship_phys_proxy__avgBreachPos = avg_breach / avg_breach_weight


def send_water_net_sync_event(eid : EntityId;
                              ship_cover_parts__water : Point4List)
  using() <| $(var cover_parts_water : FloatList)
    let partsCount = length(ship_cover_parts__water)
    cover_parts_water |> resize(partsCount * 2)
    for i in 0..partsCount
      cover_parts_water[i] = ship_cover_parts__water[i].x
      cover_parts_water[partsCount + i] = ship_cover_parts__water[i].y
    send_net_event(eid, EventShipWaterNetSync(
      unitVersion = uint8(0),
      coverPartsWaterAndBalance = ecs_addr(cover_parts_water)
    ))


[es(tag=netClient)]
def ship_handle_water_net_sync_es(evt : EventShipWaterNetSync;
                                  eid : EntityId;
                                  unit__ref : UnitRef;
                                  var ship_cover_parts__water : Point4List&)
  let unit = unit__ref.unit
  assume cover_parts_water = *evt.coverPartsWaterAndBalance
  let partsCount = length(ship_cover_parts__water)
  let receivedPartsCount = length(cover_parts_water) / 2
  if receivedPartsCount != partsCount
    logerr("EventShipWaterNetSync: invalid cover parts count received from server for {unit.props.fileName} eid:{eid}, while versions match {evt.unitVersion}, part count: {partsCount}/{receivedPartsCount}")
    return

  for i in 0..partsCount
    ship_cover_parts__water[i].x = cover_parts_water[i]
    ship_cover_parts__water[i].y = cover_parts_water[partsCount + i]


def send_breaches_net_sync_event(eid : EntityId;
                                 ship_breaches__id : IntList;
                                 ship_breaches__pos : Point3List;
                                 ship_breaches__size : FloatList;
                                 ship_breaches__amountToRepair : FloatList;
                                 ship_breaches__depthScale : FloatList;
                                 ship_breaches__partId : PartIdList;
                                 ship_breaches__coverId : IntList;
                                 ship_breaches__leakedAmount : FloatList)
  let len = ship_breaches__id |> length()
  using() <| $(var breaches_ids : IntList)
    using() <| $(var breaches_pos_and_size : Point4List)
      using() <| $(var breaches_repair_progress : FloatList)
        breaches_ids |> reserve(len * 3)
        breaches_repair_progress |> reserve(len * 3)
        breaches_pos_and_size |> reserve(len)
        for i in 0..len
          breaches_ids |> push(ship_breaches__id[i])
          breaches_ids |> push(int(ship_breaches__partId[i].packed))
          breaches_ids |> push(ship_breaches__coverId[i])
          breaches_repair_progress |> push(ship_breaches__amountToRepair[i])
          breaches_repair_progress |> push(ship_breaches__leakedAmount[i])
          breaches_repair_progress |> push(ship_breaches__depthScale[i])
          let pos = ship_breaches__pos[i]
          breaches_pos_and_size |> push(float4(pos.x, pos.y, pos.z, ship_breaches__size[i]))
        send_net_event(eid, EventShipBreachesNetSync(
          unitVersion = uint8(0),
          breachesIds = ecs_addr(breaches_ids),
          breachesPosAndSize = ecs_addr(breaches_pos_and_size),
          breachesRepairProgress = ecs_addr(breaches_repair_progress)
        ))


[es(tag=netClient)]
def ship_handle_breaches_net_sync_es(evt : EventShipBreachesNetSync;
                                     ship_cover_parts__partId : PartIdList;
                                     var ship_breaches__id : IntList&;
                                     var ship_breaches__pos : Point3List&;
                                     var ship_breaches__normal : Point3List&;
                                     var ship_breaches__size : FloatList&;
                                     var ship_breaches__amountToRepair : FloatList&;
                                     var ship_breaches__depthScale : FloatList&;
                                     var ship_breaches__nextCheck : FloatList&;
                                     var ship_breaches__partId : PartIdList&;
                                     var ship_breaches__coverId : IntList&;
                                     var ship_breaches__leakedAmount : FloatList&;
                                     var ship_breaches__offender : BreachOffenderDataList&)
  let len = *evt.breachesPosAndSize |> length()
  ship_breaches__id |> resize(len)
  ship_breaches__pos |> resize(len)
  ship_breaches__normal |> resize(len)
  ship_breaches__size |> resize(len)
  ship_breaches__amountToRepair |> resize(len)
  ship_breaches__depthScale |> resize(len)
  ship_breaches__nextCheck |> resize(len)
  ship_breaches__partId |> resize(len)
  ship_breaches__coverId |> resize(len)
  ship_breaches__leakedAmount |> resize(len)
  ship_breaches__offender |> resize(len)

  assume packed_ids = *evt.breachesIds
  assume packed_pos_and_size = *evt.breachesPosAndSize
  assume packed_repair_progress = *evt.breachesRepairProgress
  for i in 0..len
    let pos_and_size = packed_pos_and_size[i]
    ship_breaches__pos[i] = float3(pos_and_size.x, pos_and_size.y, pos_and_size.z)
    ship_breaches__size[i] = pos_and_size.w
    ship_breaches__id[i] = packed_ids[i * 3]
    ship_breaches__partId[i] := PartId(uint(packed_ids[i * 3 + 1]))
    ship_breaches__coverId[i] = min(length(ship_cover_parts__partId) - 1, packed_ids[i * 3 + 2])
    ship_breaches__amountToRepair[i] = packed_repair_progress[i * 3]
    ship_breaches__leakedAmount[i] = packed_repair_progress[i * 3 + 1]
    ship_breaches__depthScale[i] = packed_repair_progress[i * 3 + 2]
    ship_breaches__normal[i] = float3(0, 1, 0)
    ship_breaches__nextCheck[i] = 0.0f


[es(tag=server)]
def ship_handle_net_sync_request_es(evt : EventShipRequestNetSync; eid : EntityId)
  sendEvent(eid, EventShipSyncWater())
  sendEvent(eid, EventShipSyncBreaches())


[es(tag=server)]
def ship_send_water_net_sync_es(evt : EventShipSyncWater;
                                eid : EntityId;
                                ship_cover_parts__water : Point4List)
  send_water_net_sync_event(eid, ship_cover_parts__water)


[es(tag=server)]
def ship_send_breaches_net_sync_es(evt : EventShipSyncBreaches;
                                   eid : EntityId;
                                   ship_breaches__id : IntList;
                                   ship_breaches__pos : Point3List;
                                   ship_breaches__size : FloatList;
                                   ship_breaches__amountToRepair : FloatList;
                                   ship_breaches__depthScale : FloatList;
                                   ship_breaches__partId : PartIdList;
                                   ship_breaches__coverId : IntList;
                                   ship_breaches__leakedAmount : FloatList)
  send_breaches_net_sync_event(eid,
    ship_breaches__id,
    ship_breaches__pos,
    ship_breaches__size,
    ship_breaches__amountToRepair,
    ship_breaches__depthScale,
    ship_breaches__partId,
    ship_breaches__coverId,
    ship_breaches__leakedAmount)
