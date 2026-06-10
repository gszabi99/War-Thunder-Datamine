require ecs
require ecs.common
require ecs.safe
require Unit
require IGroundModel
require DagorMath
require DagorRandom
require Mission
require math.base
require DagorSystem
require strings
require app
require Weapon
require Mission
require Grid
require %appGame.wt_events

struct TargetCandidate
  eid : EntityId
  freeCapacity : float
  dist : float

let columnTanksSpeed = 20.

def sort_candidates(var candidates : array<TargetCandidate>&)
  sort(candidates) <| $(a, b)
    return max(1., a.freeCapacity) / a.dist > max(1., b.freeCapacity) / b.dist

[es(tag=server, on_appear)]
def on_equip_storage_appear_es(evt : Event;
                               var equip_storage__current : float&;
                               equip_storage__capacity : float)
  equip_storage__current = rnd_float(equip_storage__capacity * 0.2, equip_storage__capacity * 0.4)

def create_unit(template_name : string;
                settings_obj : Object const?;
                transform : float3x4;
                team : int;
                check_visibility_target : bool = true;
                move_speed_k_at_shooting : float = 1.;
                death_substract_tickets : int = 5;
                target__tag : das_string const? = null)
  if template_name.empty()
    logerr("Empty template name for unit creation")
    return INVALID_ENTITY_ID
  var unitEid = INVALID_ENTITY_ID
  let unitName = settings_obj?.name ?? ""
  if unitName == ""
    logerr("Empty unit name for unit creation")
    return INVALID_ENTITY_ID
  var templateName = template_name
  templateName += "+unit_init_params"
  using() <| $(var disabledTriggers : IntList)
    unitEid = createEntity(templateName) <| $(init)
      init |> set("unit__className", unitName)
      init |> set("transform", transform)
      init |> set("team", team)
      init |> set("unit__ownsUnitId", true)
      init |> set("setting__toGround", true)
      init |> set("setting__dontCreateChar", settings_obj?.dontCreateChar ?? false)

      let mods = get_ecs_StringList(settings_obj, "mods")
      if mods != null
        init |> set("unit_params__modList", *mods)
      let bulletNameList = get_ecs_StringList(settings_obj, "bulletNames")
      if bulletNameList != null
        init |> set("setting__bullets", *bulletNameList)
      let bulletsCountList = get_ecs_IntList(settings_obj, "bulletsCount")
      if bulletsCountList != null
        init |> set("setting__bulletsCount", *bulletsCountList)

      init |> set("aimer_custom_setting__checkVisibilityTarget", check_visibility_target)
      init |> set("aimer_custom_setting__ignoreStopForFire", true)
      init |> set("aimer_custom_setting__targetAAA", false)
      init |> set("aimer_custom_setting__moveSpeedKAtShooting", move_speed_k_at_shooting)
      disabledTriggers |> push(int(WeaponTriggerGroups.TRIGGER_GROUP_MACHINE_GUN))
      disabledTriggers |> push(int(WeaponTriggerGroups.TRIGGER_GROUP_COAXIAL_GUN))
      init |> set("custom_gun_properties__tiggerGroupNo", disabledTriggers)
      init |> set("custom_gun_properties__aimMaxDist", 0.)

      init |> set("unit_params__rearmTimeOnField", 20.)
      init |> set("on_death_substract_team_tickets_num", death_substract_tickets)
      if target__tag != null
        init |> set("nuclear_escalation_target__tag", *target__tag)
  return unitEid

[es(tag=server, no_order)]
def equip_storage_update_es(act : UpdateStageInfoAct;
                            unit__ref aka storage_unit__ref : UnitRef;
                            equip_storage__capacity aka factory_equip_storage__capacity : float;
                            equip_factory__productionRate : float;
                            equip_factory__equipForSendColumn : float;
                            equip_factory__maxUnitsCount : int;
                            var equip_storage__current aka factory_equip_storage__current : float&;
                            equip_factory__columnUnitsSettings1 : Array;
                            equip_factory__columnUnitsSettings2 : Array;
                            var equip_factory__columnUnits : EidList&;
                            var equip_factory__currentColumnTarget : EntityId&;
                            fuel_factory : Tag const?;
                            ammo_factory : Tag const?)
  if storage_unit__ref.unit.isDelayed
    return
  if !storage_unit__ref.unit.isAlive
    factory_equip_storage__current = 0.
    return
  factory_equip_storage__current = clamp(factory_equip_storage__current + equip_factory__productionRate * act.dt, 0., factory_equip_storage__capacity)

  if factory_equip_storage__current >= equip_factory__equipForSendColumn
    let existUnitsCount = equip_factory__columnUnits |> length()
    assume columnUnitSettings = storage_unit__ref.unit.army == 1 ? equip_factory__columnUnitsSettings1 : equip_factory__columnUnitsSettings2
    var needUnits = 0
    for i in range(0, columnUnitSettings |> length())
      let obj = columnUnitSettings[i] as Object
      if obj != null
        needUnits += obj.count ?? 1
    if existUnitsCount > equip_factory__maxUnitsCount - needUnits
      return

    equip_factory__currentColumnTarget = INVALID_ENTITY_ID
    var targetCandidates : array<TargetCandidate>
    if fuel_factory != null
      query() <| $ [es(REQUIRE=fuel_storage)] (eid : EntityId;
                                               unit__ref aka target_unit__ref : UnitRef;
                                               equip_storage__current aka target_equip_storage__current : float;
                                               equip_storage__capacity aka target_equip_storage__capacity : float)
        if !target_unit__ref.unit.isDelayed && target_unit__ref.unit.isAlive && target_unit__ref.unit.army == storage_unit__ref.unit.army && target_equip_storage__current < target_equip_storage__capacity
          targetCandidates.emplace(TargetCandidate(eid = eid, freeCapacity = target_equip_storage__capacity - target_equip_storage__current, dist = length(storage_unit__ref.unit.pos - target_unit__ref.unit.pos)))
    if ammo_factory != null
      query() <| $ [es(REQUIRE=ammo_storage)] (eid : EntityId;
                                               unit__ref aka target_unit__ref : UnitRef;
                                               equip_storage__current aka target_equip_storage__current : float;
                                               equip_storage__capacity aka target_equip_storage__capacity : float)
        if !target_unit__ref.unit.isDelayed && target_unit__ref.unit.isAlive && target_unit__ref.unit.army == storage_unit__ref.unit.army && target_equip_storage__current < target_equip_storage__capacity
          targetCandidates.emplace(TargetCandidate(eid = eid, freeCapacity = target_equip_storage__capacity - target_equip_storage__current, dist = length(storage_unit__ref.unit.pos - target_unit__ref.unit.pos)))

    if targetCandidates |> length() <= 0
      return

    sort_candidates(targetCandidates)
    let idx = rnd_int(0, min(2, length(targetCandidates) - 1))
    equip_factory__currentColumnTarget = targetCandidates[idx].eid
    using() <| $(var columnUnits : EidList)
      var j = 0
      for i in range(0, columnUnitSettings |> length())
        let obj = columnUnitSettings[i] as Object
        if obj != null
          var unitTransform = storage_unit__ref.unit.unitTm
          unitTransform[3] += unitTransform[2] * float(j) * 10.
          let templateName = obj.templateName ?? "tank+nuclear_escalation_tank"
          let count = obj.count ?? 1
          for _k in range(0, count)
            let unitEid = create_unit(templateName, obj, unitTransform, storage_unit__ref.unit.army)
            if unitEid != INVALID_ENTITY_ID
              equip_factory__columnUnits |> push(unitEid)
              columnUnits |> push(unitEid)
              unitTransform[3] += unitTransform[2] * 10.
              ++j
      if columnUnits |> length() > 0
        factory_equip_storage__current -= equip_factory__equipForSendColumn
        createEntity("units_column") <| $(init)
          init |> set("units_column__units", columnUnits)
          init |> set("units_column__target", equip_factory__currentColumnTarget)
          init |> set("units_column__captureCheckTimer", rnd_float(0., 1.))
          init |> set("units_column__transportedEquipment", equip_factory__equipForSendColumn / float(needUnits))

[es(tag=server, no_order)]
def equip_storage_repair_update_es(act : UpdateStageInfoAct;
                                   var unit__ref aka storage_unit__ref : UnitRef&;
                                   equip_storage__repairTime : float;
                                   var equip_storage__current : float&;
                                   var equip_storage__repairTimer : float&;
                                   units_spawn_on_init__units : EidList const?)
  if equip_storage__repairTimer > 0.
    equip_storage__repairTimer -= act.dt
    if equip_storage__repairTimer <= 0.
      equip_storage__repairTimer = -1.
      *storage_unit__ref.unit |> repair()
      if units_spawn_on_init__units != null
        for unitEid in *units_spawn_on_init__units
          query(unitEid) <| $ [es] (var unit__ref aka spawned_unit__ref : UnitRef)
            if !spawned_unit__ref.unit.isDelayed
              *spawned_unit__ref.unit |> repair()
      return
  if storage_unit__ref.unit.isDelayed || storage_unit__ref.unit.isAlive
    return
  equip_storage__current = 0.
  if equip_storage__repairTimer < 0.
    equip_storage__repairTimer = equip_storage__repairTime
    if units_spawn_on_init__units != null
      for unitEid in *units_spawn_on_init__units
        query(unitEid) <| $ [es] (var restore_unit_by_timer__restoreAtTime : float&)
          if restore_unit_by_timer__restoreAtTime > 0.
            restore_unit_by_timer__restoreAtTime = get_sync_time() + equip_storage__repairTime

[es(tag=server, on_appear, REQUIRE=unit_tag__gm)]
def on_column_unit_appear_es(evt : Event;
                             eid : EntityId;
                             var unit__ref : UnitRef&)
  query() <| $ [es] (equip_factory__columnUnits : EidList&; equip_factory__currentColumnTarget : EntityId; tank_factory : Tag const?)
    if find_index(equip_factory__columnUnits, eid) != -1
      let tm = get_TMatrix(equip_factory__currentColumnTarget, "transform")
      if tm != null && *tm != IDENT_TM
        set_destination_way_point(unit__ref.unit, "USE_SPLINE", *tm, columnTanksSpeed)
      if tank_factory != null
        var gm = unit__ref.unit |> as_gm()
        gm.slowWhenEnemyNear = 0.2
        gm.slowWhenEnemyNearDistance = 300.
  find_query() <| $ [es] (units_column__units : EidList&; spg_units_column__fireDist : float)
    if find_index(units_column__units, eid) != -1
      var gm = unit__ref.unit |> as_gm()
      (*gm) |> set_gun_properties_from_mission(int(WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY),
         false, spg_units_column__fireDist, -1., -1., -1., -1.)
      return true
    return false

let arrivedDistSq = 20. * 20.
let arrivedDist = 20.
[es(tag=server, REQUIRE_NOT=spg_units_column, after=tank_column_capture_check_es)]
def units_column_update_es(act : UpdateStageInfoAct;
                           eid : EntityId;
                           var units_column__units : EidList&;
                           units_column__target : EntityId;
                           units_column__transportedEquipment : float)
  if units_column__units |> length() == 0
    destroyEntity(eid)
  if units_column__target == INVALID_ENTITY_ID
    return
  var targetTm = IDENT_TM
  var foundSomething = false
  var hasAlive = false
  query(units_column__target) <| $ [es] (unit__ref aka target_unit__ref : UnitRef; var equip_storage__current : float&;
                                         equip_storage__capacity : float)
    if target_unit__ref.unit != null && !target_unit__ref.unit.isDelayed
      targetTm = target_unit__ref.unit.unitTm
    for unitEid in units_column__units
      query(unitEid) <| $ [es] (unit__ref aka column_unit_unit__ref : UnitRef)
        if !column_unit_unit__ref.unit.isDelayed
          hasAlive = hasAlive || column_unit_unit__ref.unit.isAlive
          foundSomething = true
          if column_unit_unit__ref.unit.isAlive && length_sq(targetTm[3]) > 0. && length_sq(column_unit_unit__ref.unit.pos - targetTm[3]) < arrivedDistSq
            equip_storage__current = min(equip_storage__current + units_column__transportedEquipment, equip_storage__capacity)
            destroyEntity(unitEid)

  query(units_column__target) <| $ [es] (strongpoint__radius : float;
                                         var units_spawn_on_init__units : EidList;
                                         var team : int&;
                                         strongpoint__ticketsByCapture : int;
                                         transform : float3x4;
                                         units_spawn_on_init__positions : TMatrixList)
    var arrived = INVALID_ENTITY_ID

    for unitEid in units_column__units
      query(unitEid) <| $ [es] (var unit__ref aka column_unit__ref : UnitRef&)
        if !column_unit__ref.unit.isDelayed
          hasAlive = hasAlive || column_unit__ref.unit.isAlive
          foundSomething = true
          if column_unit__ref.unit.isAlive && length_sq(column_unit__ref.unit.pos - transform[3]) < strongpoint__radius * strongpoint__radius
            let idx = units_spawn_on_init__units |> length()
            arrived = unitEid 

            if idx == 0 && team != column_unit__ref.unit.army
              change_mp_tickets_for_team(team, -strongpoint__ticketsByCapture)
              team = column_unit__ref.unit.army
            if idx < units_spawn_on_init__positions |> length()
              set_destination_way_point(column_unit__ref.unit, "HALT", transform, 0.)
              let vel = float3(0.)
              reset_movesys_vel(column_unit__ref.unit, vel)
              units_spawn_on_init__units |> push(unitEid)
              var tm = transform * units_spawn_on_init__positions[idx]
              drop_object_on_ground_normal(tm, true, 3000.)
              *column_unit__ref.unit |> teleportToPos(false, tm[3])
              column_unit__ref.unit |> setOrientation(tm[0], tm[1]);
            else
              destroyEntity(unitEid)
    if arrived != INVALID_ENTITY_ID
      let idx = find_index(units_column__units, arrived)
      if idx != -1
        units_column__units |> erase(idx)

  if foundSomething && !hasAlive
    destroyEntity(eid)

[es(tag=server, on_disappear, on_event=EventOnUnitDead, REQUIRE=unit_tag__gm)]
def on_column_unit_disappear_es(evt : Event;
                                eid : EntityId)
  query() <| $ [es] (var equip_factory__columnUnits : EidList&)
    let idx = find_index(equip_factory__columnUnits, eid)
    if idx != -1
      equip_factory__columnUnits |> erase(idx)

  query() <| $ [es(REQUIRE=strongpoint__radius)] (var units_spawn_on_init__units : EidList&)
    let idx = find_index(units_spawn_on_init__units, eid)
    if idx != -1
      units_spawn_on_init__units |> erase(idx)
  query() <| $ [es] (var units_column__units : EidList&)
    let idx = find_index(units_column__units, eid)
    if idx != -1
      units_column__units |> erase(idx)








[es(tag=server, on_appear)]
def on_tank_storage_appear_es(evt : Event;
                              var tank_factory__spawnPoints : float&;
                              tank_factory__spawnThreshold : float)
  tank_factory__spawnPoints = rnd_float(tank_factory__spawnThreshold * 0.5, tank_factory__spawnThreshold * 0.8)

[es(tag=server, no_order, REQUIRE=tank_factory)]
def tank_storage_update_es(act : UpdateStageInfoAct;
                           unit__ref aka storage_unit__ref : UnitRef;
                           tank_factory__baseProductionRate : float;
                           tank_factory__fuelConsumeRate : float;
                           tank_factory__ammoConsumeRate : float;
                           tank_factory__consumeInterval : float;
                           tank_factory__spawnThreshold : float;
                           equip_factory__maxUnitsCount : int;
                           equip_factory__columnUnitsSettings1 : Array;
                           equip_factory__columnUnitsSettings2 : Array;
                           tank_factory__spgColumnUnitsSettings1 : Array;
                           tank_factory__spgColumnUnitsSettings2 : Array;
                           tank_factory__spgColummProbability : float;
                           var tank_factory__spawnPoints : float&;
                           var tank_factory__consumeTimer : float&;
                           var equip_factory__columnUnits : EidList&;
                           var equip_factory__currentColumnTarget : EntityId&;
                           tank_factory__fuelStorage : EntityId;
                           tank_factory__ammoStorage : EntityId)
  if storage_unit__ref.unit.isDelayed
    return
  if !storage_unit__ref.unit.isAlive
    tank_factory__spawnPoints = 0.
    return
  let army = storage_unit__ref.unit.army

  
  tank_factory__consumeTimer -= act.dt
  if tank_factory__consumeTimer <= 0.
    tank_factory__consumeTimer = tank_factory__consumeInterval

    
    var pointsGain = tank_factory__baseProductionRate * tank_factory__consumeInterval

    
    var fuelConsumed = 0.
    let fuelToConsume = tank_factory__fuelConsumeRate * tank_factory__consumeInterval
    query(tank_factory__fuelStorage) <| $ [es(REQUIRE=fuel_storage)] (unit__ref aka fuel_unit__ref : UnitRef;
                                                                      var equip_storage__current : float&)
      if !fuel_unit__ref.unit.isDelayed && fuel_unit__ref.unit.isAlive && fuel_unit__ref.unit.army == army
        let consumed = min(fuelToConsume - fuelConsumed, equip_storage__current)
        if consumed > 0.
          equip_storage__current -= consumed
          fuelConsumed += consumed

    
    var ammoConsumed = 0.
    let ammoToConsume = tank_factory__ammoConsumeRate * tank_factory__consumeInterval
    query(tank_factory__ammoStorage) <| $ [es(REQUIRE=ammo_storage)] (unit__ref aka ammo_unit__ref : UnitRef;
                                                                      var equip_storage__current : float&)
      if !ammo_unit__ref.unit.isDelayed && ammo_unit__ref.unit.isAlive && ammo_unit__ref.unit.army == army
        let consumed = min(ammoToConsume - ammoConsumed, equip_storage__current)
        if consumed > 0.
          equip_storage__current -= consumed
          ammoConsumed += consumed

    pointsGain += fuelConsumed + ammoConsumed
    tank_factory__spawnPoints = clamp(tank_factory__spawnPoints + pointsGain, 0., tank_factory__spawnThreshold)

  
  if tank_factory__spawnPoints >= tank_factory__spawnThreshold
    let existUnitsCount = equip_factory__columnUnits |> length()
    let isSpg = gfrnd() < tank_factory__spgColummProbability
    assume columnUnitSettings = (isSpg ?
                               (army == 1 ? tank_factory__spgColumnUnitsSettings1 : tank_factory__spgColumnUnitsSettings2) :
                               (army == 1 ? equip_factory__columnUnitsSettings1 : equip_factory__columnUnitsSettings2))
    var needUnits = 0
    for i in range(0, columnUnitSettings |> length())
      let obj = columnUnitSettings[i] as Object
      if obj != null
        needUnits += obj.count ?? 1
    if existUnitsCount <= equip_factory__maxUnitsCount - needUnits
      
      equip_factory__currentColumnTarget = INVALID_ENTITY_ID
      if !isSpg
        equip_factory__currentColumnTarget = INVALID_ENTITY_ID
        var targetCandidates : array<TargetCandidate>
        query() <| $ [es(REQUIRE=equip_factory__maxUnitsCount)] (eid : EntityId;
                                                                 unit__ref aka target_unit__ref : UnitRef)
          if !target_unit__ref.unit.isDelayed && target_unit__ref.unit.isAlive && target_unit__ref.unit.army != army
            let dist = length(storage_unit__ref.unit.pos - target_unit__ref.unit.pos)
            targetCandidates.emplace(TargetCandidate(eid = eid, freeCapacity = 0., dist = dist))
        query() <| $ [es] (eid : EntityId;
                           team : int;
                           transform : float3x4;
                           units_spawn_on_init__units : EidList)
          if team != army || (team == army && units_spawn_on_init__units |> length() <= 0)
            let dist = length(storage_unit__ref.unit.pos - transform[3])
            targetCandidates.emplace(TargetCandidate(eid = eid, freeCapacity = 0., dist = dist))
        query() <| $ [es(REQUIRE=airfield_aa__nuclearEscalationField)] (eid : EntityId;
                                                                        team : int;
                                                                        transform : float3x4)
          if team != army
            let dist = length(storage_unit__ref.unit.pos - transform[3])
            targetCandidates.emplace(TargetCandidate(eid = eid, freeCapacity = 0., dist = dist))
        if targetCandidates |> length() <= 0
          return
        sort_candidates(targetCandidates)
        let idx = rnd_int(0, min(2, length(targetCandidates) - 1))
        equip_factory__currentColumnTarget = targetCandidates[idx].eid

        if equip_factory__currentColumnTarget == INVALID_ENTITY_ID
          return

      using() <| $(var columnUnits : EidList)
        var j = 0
        for i in range(0, columnUnitSettings |> length())
          let obj = columnUnitSettings[i] as Object
          if obj != null
            var unitTransform = storage_unit__ref.unit.unitTm
            unitTransform[3] += unitTransform[2] * float(j) * 10.
            let templateName = obj.templateName ?? "tank+nuclear_escalation_tank"
            let count = obj.count ?? 1
            for _k in range(0, count)
              let unitEid = create_unit(templateName, obj, unitTransform, storage_unit__ref.unit.army, !isSpg, 0.1)
              equip_factory__columnUnits |> push(unitEid)
              columnUnits |> push(unitEid)
              unitTransform[3] += unitTransform[2] * 10.
              ++j
        if columnUnits |> length() > 0
          tank_factory__spawnPoints -= tank_factory__spawnThreshold
          createEntity(isSpg ? "spg_units_column" : "units_column") <| $(init)
            init |> set("units_column__units", columnUnits)
            init |> set("units_column__target", equip_factory__currentColumnTarget)
            init |> set("units_column__captureCheckTimer", rnd_float(0., 1.)) 

def capture_blocked(target_pos : float3; new_army : int; radius : float)
  var found = false
  find_entity_in_grid(ecs_hash("vehicles"), BSphere3(target_pos, radius), GridEntCheck.POS) <| $(objEid : EntityId)
    query(objEid) <| $ [es(REQUIRE=unit_tag__tank)] (unit__ref aka any_enemy_unit__ref : UnitRef)
      if !any_enemy_unit__ref.unit.isDelayed && any_enemy_unit__ref.unit.isAlive && any_enemy_unit__ref.unit.army != new_army
        found = true
    return found
  return found


[es(tag=server, no_order)]
def tank_column_capture_check_es(act : UpdateStageInfoAct;
                                 units_column__target : EntityId;
                                 units_column__units : EidList;
                                 var units_column__captureCheckTimer : float&;
                                 units_column__captureCheckInterval : float)
  if units_column__target == INVALID_ENTITY_ID
    return
  if units_column__captureCheckTimer > 0.
    units_column__captureCheckTimer -= act.dt
    return
  units_column__captureCheckTimer = units_column__captureCheckInterval
  
  query() <| $ [es(REQUIRE=equip_factory__maxUnitsCount)] (var unit__ref aka target_unit__ref : UnitRef&;
                                                           equip_storage__ticketsByCapture : int;
                                                           tank_factory__fuelStorage : EntityId const?;
                                                           tank_factory__ammoStorage : EntityId const?)
    if target_unit__ref.unit.isDelayed
      return

    var captured = false
    var newArmy = 0
    for unitEid in units_column__units
      query(unitEid) <| $ [es] (unit__ref aka column_unit__ref : UnitRef)
        if !column_unit__ref.unit.isDelayed && column_unit__ref.unit.isAlive && column_unit__ref.unit.army != target_unit__ref.unit.army
          if length_sq(column_unit__ref.unit.pos - target_unit__ref.unit.pos) < arrivedDistSq * 4.
            captured = true
            newArmy = column_unit__ref.unit.army
      if captured
        break

    if !captured
      return
    if capture_blocked(target_unit__ref.unit.pos, newArmy, arrivedDist * 2.)
      return
    change_mp_tickets_for_team(target_unit__ref.unit.army, -equip_storage__ticketsByCapture)
    *target_unit__ref.unit |> setArmy(newArmy)
    
    if tank_factory__fuelStorage != null && *tank_factory__fuelStorage != INVALID_ENTITY_ID
      query(*tank_factory__fuelStorage) <| $ [es] (var unit__ref aka fuel_unit__ref : UnitRef&)
        if !fuel_unit__ref.unit.isDelayed && fuel_unit__ref.unit.army != newArmy
          *fuel_unit__ref.unit |> setArmy(newArmy)
    if tank_factory__ammoStorage != null && *tank_factory__ammoStorage != INVALID_ENTITY_ID
      query(*tank_factory__ammoStorage) <| $ [es] (var unit__ref aka ammo_unit__ref : UnitRef&)
        if !ammo_unit__ref.unit.isDelayed && ammo_unit__ref.unit.army != newArmy
          *ammo_unit__ref.unit |> setArmy(newArmy)
  
  find_query() <| $ [es] (units_spawn_on_init__units : EidList;
                          var team : int&;
                          strongpoint__ticketsByCapture : int;
                          strongpoint__radius : float;
                          transform : float3x4)
    var found = false
    for unitEid in units_column__units
      query(unitEid) <| $ [es] (unit__ref aka column_unit__ref : UnitRef)
        if (!column_unit__ref.unit.isDelayed &&
         column_unit__ref.unit.isAlive && column_unit__ref.unit.army != team &&
         units_spawn_on_init__units |> length() <= 0 &&
         length_sq(column_unit__ref.unit.pos - transform[3]) < strongpoint__radius * strongpoint__radius)
          found = true
          if !capture_blocked(transform[3], column_unit__ref.unit.army, strongpoint__radius)
            change_mp_tickets_for_team(team, -strongpoint__ticketsByCapture)
            team = column_unit__ref.unit.army
      if found
        return true
    return false
  
  query(units_column__target) <| $ [es(REQUIRE=airfield_aa__nuclearEscalationField)] (var team : int&;
                                                                                      airfield_aa__ticketsByCapture : int;
                                                                                      transform : float3x4)
    for unitEid in units_column__units
      query(unitEid) <| $ [es] (unit__ref aka column_unit__ref : UnitRef)
        if (!column_unit__ref.unit.isDelayed &&
         column_unit__ref.unit.isAlive &&
         length_sq(column_unit__ref.unit.pos - transform[3]) < 50. * 50.)
          if column_unit__ref.unit.army != team
            if !capture_blocked(transform[3], column_unit__ref.unit.army, 50.)
              change_mp_tickets_for_team(team, -airfield_aa__ticketsByCapture)
              team = column_unit__ref.unit.army
          destroyEntity(unitEid)

[es(tag=server, on_appear)]
def init_assembly_area_es(evt : Event;
                          eid : EntityId;
                          transform : float3x4;
                          assembly_area__tankFactoryTempl : string;
                          assembly_area__fuelStorageTempl : string;
                          assembly_area__ammoStorageTempl : string;
                          assembly_area__tankFactoryUnitName : string;
                          assembly_area__fuelStorageUnitName : string;
                          assembly_area__ammoStorageUnitName : string;
                          team : int;
                          units_spawn_on_init__positions : TMatrixList;
                          units_spawn_on_init__positionNames : StringList;
                          nuclear_escalation_target__tag : string)
  var fuelStorageEid = INVALID_ENTITY_ID
  var ammoStorageEid = INVALID_ENTITY_ID
  if !assembly_area__fuelStorageTempl.empty() && !assembly_area__fuelStorageUnitName.empty()
    var tm = IDENT_TM
    for i in range(0, units_spawn_on_init__positionNames |> length())
      if units_spawn_on_init__positionNames[i] == "fuel_storage"
        tm = units_spawn_on_init__positions[i]
        break
    fuelStorageEid = createEntity(assembly_area__fuelStorageTempl + "+unit_init_params") <| $(init)
      init |> set("unit__className", assembly_area__fuelStorageUnitName)
      init |> set("transform", transform * tm)
      init |> set("unit__ownsUnitId", true)
      init |> set("team", team)
      init |> set("setting__toGround", true)
      init |> set("nuclear_escalation_target__tag", nuclear_escalation_target__tag)
  if !assembly_area__ammoStorageTempl.empty() && !assembly_area__ammoStorageUnitName.empty()
    var tm = IDENT_TM
    for i in range(0, units_spawn_on_init__positionNames |> length())
      if units_spawn_on_init__positionNames[i] == "ammo_storage"
        tm = units_spawn_on_init__positions[i]
        break
    ammoStorageEid = createEntity(assembly_area__ammoStorageTempl + "+unit_init_params") <| $(init)
      init |> set("unit__className", assembly_area__ammoStorageUnitName)
      init |> set("transform", transform * tm)
      init |> set("unit__ownsUnitId", true)
      init |> set("team", team)
      init |> set("setting__toGround", true)
      init |> set("nuclear_escalation_target__tag", nuclear_escalation_target__tag)
  if !assembly_area__tankFactoryTempl.empty() && !assembly_area__tankFactoryUnitName.empty()
    createEntity(assembly_area__tankFactoryTempl + "+unit_init_params") <| $(init)
      init |> set("unit__className", assembly_area__tankFactoryUnitName)
      init |> set("transform", transform)
      init |> set("unit__ownsUnitId", true)
      init |> set("setting__toGround", true)
      init |> set("team", team)
      init |> set("tank_factory__fuelStorage", fuelStorageEid)
      init |> set("tank_factory__ammoStorage", ammoStorageEid)
      init |> set("units_spawn_on_init__positions", units_spawn_on_init__positions)
      init |> set("units_spawn_on_init__positionNames", units_spawn_on_init__positionNames)
      init |> set("nuclear_escalation_target__tag", nuclear_escalation_target__tag)
  destroyEntity(eid)

[es(tag=server, on_appear, on_event=EventUnitDelayedStatusChanged, after=unit_init_completed_es)]
def units_spawn_on_init_es(evt : Event;
                           team : int;
                           active : bool const?;
                           transform : float3x4;
                           units_spawn_on_init__positions : TMatrixList;
                           units_spawn_on_init__positionNames : StringList;
                           units_spawn_on_init__unitSettings : Array const?;
                           units_spawn_on_init__unitSettingsTeam1 : Array const?;
                           units_spawn_on_init__unitSettingsTeam2 : Array const?;
                           var units_spawn_on_init__units : EidList&;
                           nuclear_escalation_target__tag : das_string const?)
  if active != null && *active == false
    return
  if units_spawn_on_init__units |> length() > 0
    return
  let unitSettingsAny = units_spawn_on_init__unitSettings
  let unitSettingsByTeam = team == 1 ? units_spawn_on_init__unitSettingsTeam1 : units_spawn_on_init__unitSettingsTeam2
  let unitSettings : Array const? = (unitSettingsAny != null && *unitSettingsAny |> length() > 0) ? unitSettingsAny : unitSettingsByTeam
  if unitSettings == null
    return
  var nextNameSearchIndex : table<string; int>
  for unit in *unitSettings
    let obj = unit as Object
    if obj != null
      let templateName = obj.templateName ?? "tank+nuclear_escalation_tank"
      let spawnName = obj.spawnName ?? ""
      for _ in range(0, obj.count ?? 1)
        var tm = IDENT_TM
        let startIdx = nextNameSearchIndex?[spawnName] ?? 0
        if !spawnName.empty()
          for j in range(startIdx, units_spawn_on_init__positionNames |> length())
            if units_spawn_on_init__positionNames[j] == spawnName
              tm = units_spawn_on_init__positions[j]
              nextNameSearchIndex[spawnName] = j + 1
              break
        elif startIdx < units_spawn_on_init__positions |> length()
          tm = units_spawn_on_init__positions[startIdx]
          nextNameSearchIndex[spawnName] = startIdx + 1
          let posName = units_spawn_on_init__positionNames |> length() > startIdx ? "{units_spawn_on_init__positionNames[startIdx]}" : ""
          if !posName.empty()
            nextNameSearchIndex[posName] = startIdx + 1
        let unitEid = create_unit(templateName, obj, transform * tm, team, true, 1., 5, nuclear_escalation_target__tag)
        if unitEid != INVALID_ENTITY_ID
          units_spawn_on_init__units |> push(unitEid)

let distSqToAlly = 300. * 300.

[es(tag=server, no_order)]
def spg_units_column_update_es(act : UpdateStageInfoAct;
                               eid : EntityId;
                               var units_column__units : EidList&;
                               var units_column__target : EntityId&;
                               spg_units_column__fireDist : float;
                               var spg_units_column__readyToFire : bool&;
                               var spg_units_column__changeStateTimer : float&;
                               spg_units_column__changeStateTime : float)
  if units_column__units |> length() <= 0
    destroyEntity(eid)
  spg_units_column__changeStateTimer -= act.dt
  var targetPos = float3(0.)
  if units_column__target != INVALID_ENTITY_ID
    query(units_column__target) <| $ [es] (unit__ref : UnitRef)
      if unit__ref.unit == null || unit__ref.unit.isDelayed || !unit__ref.unit.isAlive
        units_column__target = INVALID_ENTITY_ID
      else
        targetPos = unit__ref.unit.pos
  if units_column__target == INVALID_ENTITY_ID
    var columnPos = float3(0.)
    var army = 0
    query(units_column__units[0]) <| $ [es] (var unit__ref : UnitRef&)
      if !unit__ref.unit.isDelayed
        columnPos = unit__ref.unit.pos
        army = unit__ref.unit.army
    if length_sq(columnPos) > 0.
      var nearestSq = FLT_MAX
      query() <| $ [es(REQUIRE=unit_tag__tank)] (eid aka target_eid : EntityId; unit__ref : UnitRef)
        if (!unit__ref.unit.isDelayed && unit__ref.unit.isAlive && army != unit__ref.unit.army &&
         length_sq(unit__ref.unit.pos - columnPos) < nearestSq)
          nearestSq = length_sq(unit__ref.unit.pos - columnPos)
          units_column__target = target_eid
          targetPos = unit__ref.unit.pos

  let fireNow = spg_units_column__readyToFire
  if spg_units_column__changeStateTimer < 0.
    spg_units_column__readyToFire = false
  var deadUnit = INVALID_ENTITY_ID
  var blockedByAlly = false
  for unitEid, i in units_column__units, range(units_column__units |> length())
    query(unitEid) <| $ [es(REQUIRE=unit_tag__gm)] (var unit__ref aka column_unit__ref : UnitRef&)
      if column_unit__ref.unit.isDelayed || !column_unit__ref.unit.isAlive
        deadUnit = unitEid
        return

      let state = get_move_sys_state(column_unit__ref.unit)
      if fireNow
        if state != int(MoveSysState.ST_HALT)
          set_destination_way_point(column_unit__ref.unit, "HALT", IDENT_TM, 0.)
      elif state == int(MoveSysState.ST_HALT) && length_sq(targetPos) > 0.
        var targetTm = IDENT_TM
        targetTm[3] = targetPos
        set_destination_way_point(column_unit__ref.unit, "USE_SPLINE", targetTm, columnTanksSpeed)
      if spg_units_column__changeStateTimer < 0.
        if !blockedByAlly
          query() <| $ [es(REQUIRE=unit_tag__fortification)] (var unit__ref aka fort_unit__ref : UnitRef&)
            if (!fort_unit__ref.unit.isDelayed && fort_unit__ref.unit.isAlive &&
             fort_unit__ref.unit.army == column_unit__ref.unit.army && length_sq(fort_unit__ref.unit.pos - column_unit__ref.unit.pos) < distSqToAlly)
              blockedByAlly = true
        var gm = column_unit__ref.unit |> as_gm()
        (*gm) |> set_fire_type(blockedByAlly ? GroundModelFireType.FT_DONT_AIM : GroundModelFireType.FT_FIRE_ANY, true)
        if length_sq(targetPos) > 0.
          let canFire = !blockedByAlly && length_sq(targetPos - column_unit__ref.unit.pos) <= spg_units_column__fireDist * spg_units_column__fireDist
          if i == 0
            spg_units_column__readyToFire = canFire
          else
            spg_units_column__readyToFire = spg_units_column__readyToFire && canFire

  if spg_units_column__changeStateTimer < 0.
    spg_units_column__changeStateTimer = spg_units_column__changeStateTime
  if deadUnit != INVALID_ENTITY_ID
    let idx = find_index(units_column__units, deadUnit)
    if idx != -1
      units_column__units |> erase(idx)

[es(tag=server, on_event=EventOnUnitDead)]
def activate_delayed_destroy_timer_es(evt : Event;
                                      delayed_destroy_dead_unit__time : float;
                                      var entity_destroyer__destroyAtTime : float&)
  entity_destroyer__destroyAtTime = get_sync_time() + delayed_destroy_dead_unit__time

[es(tag=server, track=team)]
def change_team_of_child_units_es(evt : Event;
                                  team aka parent_team : int;
                                  units_spawn_on_init__units : EidList)
  for unitEid in units_spawn_on_init__units
    query(unitEid) <| $ [es] (var team aka child_team : int&)
      child_team = parent_team

[es(tag=server, track=team)]
def change_team_of_airfield_es(evt : Event;
                               team : int;
                               spawnedOnAirfieldId : int)
  if spawnedOnAirfieldId >= 0
    var af = get_airfield_by_id(spawnedOnAirfieldId)
    if af != null
      *af |> captureField(team)

[es(tag=server)]
def on_airfield_active_state_changed_es(evt : EventAirfieldActiveStateChanged;
                                        spawnedOnAirfieldId : int;
                                        units_spawn_on_init__units : EidList)
  if spawnedOnAirfieldId >= 0 && spawnedOnAirfieldId == evt.airfieldId
    if evt.active
      for unitEid in units_spawn_on_init__units
        query(unitEid) <| $ [es] (var restore_unit_by_timer__restoreAtTime : float&)
          if restore_unit_by_timer__restoreAtTime > 0.
            restore_unit_by_timer__restoreAtTime = get_sync_time()

[es(on_event=CmdUnitAttackTarget, REQUIRE_NOT=unit_init_attack_type__targets)]
def on_unit_attack_nuclear_escalation_target_es(evt : Event;
                                                var unit__ref aka hunter_unit__ref : UnitRef&;
                                                nuclear_escalation_target_hunter__hash : uint64)
  var nearestSq = FLT_MAX
  var targetUnit = null
  if nuclear_escalation_target_hunter__hash == uint64(0)
    return
  query() <| $ [es(REQUIRE=unit_tag__gm)] (unit__ref aka target_unit__ref : UnitRef; nuclear_escalation_target__hash : uint64)
    if target_unit__ref.unit.isDelayed || nuclear_escalation_target__hash == uint64(0)
      return
    if nuclear_escalation_target_hunter__hash != nuclear_escalation_target__hash || !target_unit__ref.unit.isAlive || hunter_unit__ref.unit.army == target_unit__ref.unit.army
      return
    let distSq = length_sq(target_unit__ref.unit.pos - hunter_unit__ref.unit.pos)
    if distSq < nearestSq
      nearestSq = distSq
      targetUnit = target_unit__ref.unit
  if targetUnit != null
    var gm = as_gm(hunter_unit__ref.unit)
    if gm != null
      add_unit_for_target(*gm, targetUnit)
      set_unit_attack_type(hunter_unit__ref.unit, "attack_target")
  else
    set_unit_attack_type(hunter_unit__ref.unit, "dont_aim")

[es(tag=server, on_appear)]
def on_nuclear_escalation_target_appear_es(evt : Event;
                                           var nuclear_escalation_target__hash : uint64&;
                                           nuclear_escalation_target__tag : string)
  if nuclear_escalation_target__tag.empty()
    return
  nuclear_escalation_target__hash = hash(nuclear_escalation_target__tag)

[es(tag=server, on_appear)]
def on_nuclear_escalation_target_hunter_appear_es(evt : Event;
                                                  var nuclear_escalation_target_hunter__hash : uint64&;
                                                  nuclear_escalation_target_hunter__target_tag : string)
  if nuclear_escalation_target_hunter__target_tag.empty()
    return
  nuclear_escalation_target_hunter__hash = hash(nuclear_escalation_target_hunter__target_tag)