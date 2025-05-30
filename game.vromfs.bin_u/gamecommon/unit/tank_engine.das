require ecs
require net
require dm
require Unit
require UnitFx
require WTDamageModel
require IGroundModel
require DagorDataBlock
require %game.unit.unit_events
require %game.dm.dm_events


[es(tag=server, no_order)]
def tank_engine_updater_es(act : UpdateStageInfoAct;
                           eid : EntityId;
                           unit__ref : UnitRef;
                           var unit_fx : UnitFx;
                           tank_engine__overheatDelay : float;
                           tank_engine__overheatDamageCooldown : float&;
                           tank_engine__engine_parts : PartIdList;
                           tank_engine__overheatDamage : float;
                           tank_engine__overheatDamageType : int;
                           tank_engine__overheatOffender : OffenderData;
                           tank_engine__brokenRadiatorFxEventId : int;
                           repair_system_remaining_repair_time : float;
                           var tank_engine__overheat : bool&;
                           var tank_engine__overheatDamageTime : float&)
  let unit = unit__ref.unit
  if unit.isDelayed
    return
  let gm = unit |> as_gm()
  if gm == null || !gm.isEngineWorking
    tank_engine__overheatDamageTime = -1.f
    return

  if tank_engine__overheat && tank_engine__overheatDamageType >= 0 && repair_system_remaining_repair_time <= 0.0f
    if tank_engine__overheatDamageTime < 0.0
      tank_engine__overheatDamageTime = act.curTime + tank_engine__overheatDelay
    elif act.curTime > tank_engine__overheatDamageTime
      tank_engine__overheatDamageTime += tank_engine__overheatDamageCooldown
      let seed = 0
      var hasDamage = false
      for partId in tank_engine__engine_parts
        if get_part_hp(unit.dmData, partId) > 0.0
          do_unit_part_damage(eid, partId, tank_engine__overheatOffender, tank_engine__overheatDamage, tank_engine__overheatDamageType, seed)
          hasDamage = true
      if !hasDamage
        tank_engine__overheat = false
        send_net_event(eid, EventEngineOverheatDamage(start = false))
        unit_fx |> stopFxEvent(tank_engine__brokenRadiatorFxEventId)


[es(tag=server)]
def tank_engine_init_es(evt : CmdInitComponent;
                        var unit__ref : UnitRef;
                        var unit_fx : UnitFx;
                        var tank_engine__overheatDelay : float&;
                        var tank_engine__overheatDamage : float&;
                        var tank_engine__overheatDamageType : int&;
                        var tank_engine__overheatDamageCooldown : float&;
                        var tank_engine__radiator_parts : PartIdList&;
                        var tank_engine__engine_parts : PartIdList&;
                        var tank_engine__brokenRadiatorFxEventId : int&)
  var unit = unit__ref.unit
  assert(unit != null)
  if unit == null || !unit.isGroundModel
    return

  let tankEngineModelBlk = *evt.modelBlk |> datablock_get_block_by_name("tankEngine")
  let commonBlk = get_common_unit_systems_blk()
  let tankEngineCommonBlk = commonBlk != null ? *commonBlk |> datablock_get_block_by_name("tankEngine") : null
  if tankEngineModelBlk == null && tankEngineCommonBlk == null
    return

  assume tankEngineBlk = tankEngineModelBlk != null ? *tankEngineModelBlk : *tankEngineCommonBlk
  tankEngineBlk |> datablock_get_block("engine") <| $(engineBlk)
    tank_engine__overheatDelay = engineBlk |> datablock_getReal("overheatDelay", tank_engine__overheatDelay)
    tank_engine__overheatDelay = engineBlk |> datablock_getReal("overheatDelay", tank_engine__overheatDelay)
    tank_engine__overheatDamage = engineBlk |> datablock_getReal("overheatDamage", tank_engine__overheatDamage)
    let damageTypeName = engineBlk |> datablock_getStr("overheatDamageType", "")
    tank_engine__overheatDamageType = find_damage_type_id_by_name(damageTypeName)
    tank_engine__overheatDamageCooldown = engineBlk |> datablock_getReal("overheatDamageCooldown", tank_engine__overheatDamageCooldown)
    engineBlk |> datablock_for_each_param("part") <| $(i, t)
      if t == int(DataBlockParamType.TYPE_STRING)
        let partName = engineBlk |> datablock_getStr(i)
        let partId = find_part_id(unit.dmData, partName)
        if partId.valid
          tank_engine__engine_parts |> push(partId)
    tankEngineBlk |> datablock_get_block("radiator") <| $(radiatorBlk)
      let brokenRadiatorFxEvenName = radiatorBlk |> datablock_getStr("brokenFxEvent", "")
      tank_engine__brokenRadiatorFxEventId = unit_fx |> getEventIdByName(brokenRadiatorFxEvenName)
      radiatorBlk |> datablock_for_each_param("part") <| $(i, t)
        if t == int(DataBlockParamType.TYPE_STRING)
          let partName = radiatorBlk |> datablock_getStr(i)
          let partId = find_part_id(unit.dmData, partName)
          if partId.valid
            tank_engine__radiator_parts |> push(partId)


[es(tag=server)]
def tank_engine_on_damage_es(evt : EventUnitDamage;
                             eid : EntityId;
                             var unit__ref : UnitRef;
                             var unit_fx : UnitFx;
                             tank_engine__radiator_parts : PartIdList;
                             tank_engine__overheatDamageTime : float;
                             tank_engine__brokenRadiatorFxEventId : int;
                             var tank_engine__overheatOffender : OffenderData&;
                             var tank_engine__overheat : bool&)
  var unit = unit__ref.unit
  if unit.isDelayed
    return
  if int(evt.hpFixed) == 0 && tank_engine__overheatDamageTime < 0.0
    var containPart = false
    for partId in tank_engine__radiator_parts
      if evt.partId.id == partId.id
        containPart = true
        break
    if containPart
      tank_engine__overheat = true
      send_net_event(eid, EventEngineOverheatDamage(start = true))
      tank_engine__overheatOffender = evt.offender
      let zero = float3(0.0f)
      let up = float3(0.0f, 1.0f, 0.0f)
      unit_fx |> startFxEvent(tank_engine__brokenRadiatorFxEventId, unit, evt.partId, zero, up)


[es(tag=server)]
def tank_engine_respawn_handle(evt : EventUnitRespawn;
                               eid : EntityId;
                               tank_engine__brokenRadiatorFxEventId : int;
                               var unit_fx : UnitFx;
                               var tank_engine__overheatDamageTime : float&;
                               var tank_engine__overheat : bool&)
  tank_engine__overheat = false
  send_net_event(eid, EventEngineOverheatDamage(start = false))
  tank_engine__overheatDamageTime = -1.0
  unit_fx |> stopFxEvent(tank_engine__brokenRadiatorFxEventId)


[es(tag=server)]
def tank_engine_repair_handle(evt : EventUnitRepair;
                              eid : EntityId;
                              tank_engine__brokenRadiatorFxEventId : int;
                              var unit_fx : UnitFx;
                              var tank_engine__overheatDamageTime : float&;
                              var tank_engine__overheat : bool&)
  tank_engine__overheat = false
  send_net_event(eid, EventEngineOverheatDamage(start = false))
  tank_engine__overheatDamageTime = -1.0
  unit_fx |> stopFxEvent(tank_engine__brokenRadiatorFxEventId)


[es(tag=server)]
def tank_engine_on_part_restored_es(evt : EventDamagePartRestored;
                                    eid : EntityId;
                                    tank_engine__radiator_parts : PartIdList;
                                    tank_engine__brokenRadiatorFxEventId : int;
                                    var unit_fx : UnitFx;
                                    var tank_engine__overheatDamageTime : float&;
                                    var tank_engine__overheat : bool&)
  let evtPartId = unpack_part_id(evt.packedPartId)
  var containPart = false
  for partId in tank_engine__radiator_parts
    if evtPartId.id == partId.id
      containPart = true
      break
  if containPart
    tank_engine__overheat = false
    send_net_event(eid, EventEngineOverheatDamage(start = false))
    tank_engine__overheatDamageTime = -1.0
    unit_fx |> stopFxEvent(tank_engine__brokenRadiatorFxEventId)



