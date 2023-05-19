require ecs
require dm
require Unit
require UnitFx
require WTDamageModel
require DagorDataBlock
require %game.unit.unit_events

[es(tag=server)]
def tank_engine_updater_es(act : UpdateStageInfoAct;
                           eid : EntityId;
                           uid : int;
                           tank_engine__overheatDelay : float;
                           tank_engine__overheatDamageCooldown : float&;
                           tank_engine__engine_parts : PartIdList;
                           tank_engine__overheatDamage : float;
                           tank_engine__overheatDamageType : int;
                           tank_engine__overheatOffender : OffenderData;
                           tank_engine__brokenRadiatorFxEventId : int;
                           var tank_engine__overheat : bool&;
                           var tank_engine__overheatDamageTime : float&)
  var unit = get_unit(uid)

  if tank_engine__overheat && tank_engine__overheatDamageType >= 0
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
        *get_unit_fx(unit) |> stopFxEvent(tank_engine__brokenRadiatorFxEventId)

[es(tag=server)]
def tank_engine_init_es(evt : CmdInitComponent;
                        uid : int;
                        var tank_engine__overheatDelay : float&;
                        var tank_engine__overheatDamage : float&;
                        var tank_engine__overheatDamageType : int&;
                        var tank_engine__overheatDamageCooldown : float&;
                        var tank_engine__radiator_parts : PartIdList&;
                        var tank_engine__engine_parts : PartIdList&;
                        var tank_engine__brokenRadiatorFxEventId : int&)
  var unit = get_unit(uid)
  assert(unit != null)
  if !unit.isGroundModel
    return

  assume blk = *evt.modelBlk
  blk |> datablock_get_block("tankEngine") <| $(tankEngineBlk)
    tankEngineBlk |> datablock_get_block("engine") <| $(engineBlk)
      tank_engine__overheatDelay = engineBlk |> datablock_getReal("overheatDelay", tank_engine__overheatDelay)
      tank_engine__overheatDamage = engineBlk |> datablock_getReal("overheatDamage", tank_engine__overheatDamage)
      let damageTypeName = engineBlk |> datablock_getStr("overheatDamageType", "")
      tank_engine__overheatDamageType = find_damage_type_id_by_name(damageTypeName)
      tank_engine__overheatDamageCooldown = engineBlk |> datablock_getReal("overheatDamageCooldown", tank_engine__overheatDamageCooldown)
      engineBlk |> datablock_for_each_param("part") <| $(i, t)
        if t == int(DataBlockParamType TYPE_STRING)
          let partName = engineBlk |> datablock_getStr(i)
          let partId = find_part_id(unit.dmData, partName)
          if partId.valid
            tank_engine__engine_parts |> push(partId)
    tankEngineBlk |> datablock_get_block("radiator") <| $(radiatorBlk)
      let brokenRadiatorFxEvenName = radiatorBlk |> datablock_getStr("brokenFxEvent", "")
      tank_engine__brokenRadiatorFxEventId = *get_unit_fx(unit) |> getEventIdByName(brokenRadiatorFxEvenName)
      radiatorBlk |> datablock_for_each_param("part") <| $(i, t)
        if t == int(DataBlockParamType TYPE_STRING)
          let partName = radiatorBlk |> datablock_getStr(i)
          let partId = find_part_id(unit.dmData, partName)
          if partId.valid
            tank_engine__radiator_parts |> push(partId)

[es(tag=server)]
def tank_engine_on_damage_es(evt : EventUnitDamage;
                             uid : int;
                             tank_engine__radiator_parts : PartIdList;
                             tank_engine__overheatDamageTime : float;
                             tank_engine__brokenRadiatorFxEventId : int;
                             var tank_engine__overheatOffender : OffenderData&;
                             var tank_engine__overheat : bool&)
  var unit = get_unit(uid)

  if int(evt.hpFixed) == 0 && tank_engine__overheatDamageTime < 0.0
    var containPart = false
    for partId in tank_engine__radiator_parts
      if evt.partId.id == partId.id
        containPart = true
        break
    if containPart
      tank_engine__overheat = true
      tank_engine__overheatOffender = evt.offender
      *get_unit_fx(unit) |> startFxEvent(tank_engine__brokenRadiatorFxEventId, unit, false)

[es(tag=server)]
def tank_engine_respawn_handle(evt : EventUnitRespawn;
                               var tank_engine__overheatDamageTime : float&;
                               var tank_engine__overheat : bool&)
  tank_engine__overheat = false
  tank_engine__overheatDamageTime = -1.0

[es(tag=server)]
def tank_engine_repair_handle(evt : EventUnitRepair;
                              var tank_engine__overheatDamageTime : float&;
                              var tank_engine__overheat : bool&)
  tank_engine__overheat = false
  tank_engine__overheatDamageTime = -1.0
