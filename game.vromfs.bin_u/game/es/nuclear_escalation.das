require ecs
require ecs.common
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

[es(tag=server, no_order)]
def equip_storage_update_es(act : UpdateStageInfoAct;
                            unit__ref aka storage_unit__ref : UnitRef;
                            equip_storage__capacity aka factory_equip_storage__capacity : float;
                            equip_factory__productionRate : float;
                            equip_factory__equipForSendColumn : float;
                            equip_factory__maxUnitsCount : int;
                            var equip_storage__current aka factory_equip_storage__current : float&;
                            equip_factory__columnUnitNames1 : StringList;
                            equip_factory__columnUnitNames2 : StringList;
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
  let existUnitsCount = equip_factory__columnUnits |> length()
  assume columnUnitsNames = storage_unit__ref.unit.army == 1 ? equip_factory__columnUnitNames1 : equip_factory__columnUnitNames2
  if factory_equip_storage__current >= equip_factory__equipForSendColumn && existUnitsCount <= equip_factory__maxUnitsCount - columnUnitsNames |> length()
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
    let unitCnt = columnUnitsNames |> length()
    using() <| $(var columnUnits : EidList)
      for unit, i in columnUnitsNames, range(0, unitCnt)
        var unitTransform = storage_unit__ref.unit.unitTm
        unitTransform[3] += unitTransform[2] * float(i) * 10.
        var templateName = "tank+delayed_destroy_dead_unit+aimer_custom_setting+custom_gun_properties+disable_radar_on_start+unit_death_substract_team_tickets_5"
        if string(unit) |> find("/") != -1
          templateName = "simple_tank+delayed_destroy_dead_unit+aimer_custom_setting+custom_gun_properties+disable_radar_on_start+unit_death_substract_team_tickets_5"
        using() <| $(var disabledTriggers : IntList)
          let unitEid = createEntity(templateName) <| $(init)
            init |> set("unit__className", unit)
            init |> set("transform", unitTransform)
            init |> set("team", storage_unit__ref.unit.army)
            init |> set("unit__ownsUnitId", true)
            init |> set("aimer_custom_setting__ignoreStopForFire", true)
            disabledTriggers |> push(int(WeaponTriggerGroups.TRIGGER_GROUP_MACHINE_GUN))
            disabledTriggers |> push(int(WeaponTriggerGroups.TRIGGER_GROUP_COAXIAL_GUN))
            init |> set("custom_gun_properties__tiggerGroupNo", disabledTriggers)
            init |> set("custom_gun_properties__aimMaxDist", 0.)
          equip_factory__columnUnits |> push(unitEid)
          columnUnits |> push(unitEid)
      if columnUnits |> length() > 0
        factory_equip_storage__current -= equip_factory__equipForSendColumn
        createEntity("units_column") <| $(init)
          init |> set("units_column__units", columnUnits)
          init |> set("units_column__target", equip_factory__currentColumnTarget)
          init |> set("units_column__captureCheckTimer", rnd_float(0., 1.))
          init |> set("units_column__transportedEquipment", equip_factory__equipForSendColumn / float(unitCnt))

[es(tag=server, no_order)]
def equip_storage_repair_update_es(act : UpdateStageInfoAct;
                                   var unit__ref : UnitRef&;
                                   equip_storage__repairTime : float;
                                   var equip_storage__current : float&;
                                   var equip_storage__repairTimer : float&)
  if equip_storage__repairTimer > 0.
    equip_storage__repairTimer -= act.dt
    if equip_storage__repairTimer <= 0.
      equip_storage__repairTimer = -1.
      *unit__ref.unit |> repair()
      return
  if unit__ref.unit.isDelayed || unit__ref.unit.isAlive
    return
  equip_storage__current = 0.
  if equip_storage__repairTimer < 0.
    equip_storage__repairTimer = equip_storage__repairTime

[es(tag=server, on_appear, REQUIRE=unit_tag__gm)]
def on_column_unit_appear_es(evt : Event;
                             eid : EntityId;
                             var unit__ref : UnitRef&)
  query() <| $ [es] (equip_factory__columnUnits : EidList&; equip_factory__currentColumnTarget : EntityId; tank_factory : Tag const?)
    if find_index(equip_factory__columnUnits, eid) != -1
      var tm = IDENT_TM
      query(equip_factory__currentColumnTarget) <| $ [es] (unit__ref aka target_unit__ref : UnitRef)
        tm = target_unit__ref.unit.unitTm
      query(equip_factory__currentColumnTarget) <| $ [es(REQUIRE=strongpoint__radius)] (transform : float3x4)
        tm = transform
      if tm != IDENT_TM
        set_destination_way_point(unit__ref.unit, "USE_SPLINE", tm, columnTanksSpeed)
      if tank_factory != null
        var gm = unit__ref.unit |> as_gm()
        gm.slowWhenEnemyNear = 0.2
        gm.slowWhenEnemyNearDistance = 300.

[es(tag=server, no_order, REQUIRE_NOT=spg_units_column)]
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
          if column_unit_unit__ref.unit.isAlive && length_sq(targetTm[3]) > 0. && length_sq(column_unit_unit__ref.unit.pos - targetTm[3]) < 400.
            equip_storage__current = min(equip_storage__current + units_column__transportedEquipment, equip_storage__capacity)
            destroyEntity(unitEid)

  query(units_column__target) <| $ [es] (strongpoint__radius : float;
                                         var strongpoint__units : EidList;
                                         transform : float3x4;
                                         object_group_spawn_units__positions : TMatrixList)
    var arrived = INVALID_ENTITY_ID

    for unitEid in units_column__units
      query(unitEid) <| $ [es] (var unit__ref aka column_unit_unit__ref : UnitRef&)
        if !column_unit_unit__ref.unit.isDelayed
          hasAlive = hasAlive || column_unit_unit__ref.unit.isAlive
          foundSomething = true
          if column_unit_unit__ref.unit.isAlive && length_sq(column_unit_unit__ref.unit.pos - transform[3]) < strongpoint__radius * strongpoint__radius
            let idx = strongpoint__units |> length()
            arrived = unitEid

            if idx < object_group_spawn_units__positions |> length()
              set_destination_way_point(column_unit_unit__ref.unit, "HALT", transform, 0.)
              let vel = float3(0.)
              reset_movesys_vel(column_unit_unit__ref.unit, vel)
              strongpoint__units |> push(unitEid)
              var tm = transform * object_group_spawn_units__positions[idx]
              drop_object_on_ground_normal(tm, true, 3000.)
              *column_unit_unit__ref.unit |> teleportToPos(false, tm[3])
              column_unit_unit__ref.unit |> setOrientation(tm[0], tm[1]);
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

  query() <| $ [es] (var strongpoint__units : EidList&)
    let idx = find_index(strongpoint__units, eid)
    if idx != -1
      strongpoint__units |> erase(idx)
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
                           equip_factory__columnUnitNames1 : StringList;
                           equip_factory__columnUnitNames2 : StringList;
                           tank_factory__spgColumnUnitNames1 : StringList;
                           tank_factory__spgColumnUnitNames2 : StringList;
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
    assume columnUnitsNames = (isSpg ?
                               (army == 1 ? tank_factory__spgColumnUnitNames1 : tank_factory__spgColumnUnitNames2) :
                               (army == 1 ? equip_factory__columnUnitNames1 : equip_factory__columnUnitNames2))
    let columnSize = columnUnitsNames |> length()
    if existUnitsCount <= equip_factory__maxUnitsCount - columnSize
      
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
                           strongpoint__units : EidList)
          if team != army || (team == army && strongpoint__units |> length() <= 0)
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
        for unit, i in columnUnitsNames, range(0, columnSize)
          var unitTransform = storage_unit__ref.unit.unitTm
          unitTransform[3] += unitTransform[2] * float(i) * 10.
          var templateName = "tank+delayed_destroy_dead_unit+aimer_custom_setting+custom_gun_properties+disable_radar_on_start+unit_death_substract_team_tickets_5"
          if string(unit) |> find("/") != -1
            templateName = "simple_tank+delayed_destroy_dead_unit+aimer_custom_setting+custom_gun_properties+disable_radar_on_start+unit_death_substract_team_tickets_5"
          using() <| $(var disabledTriggers : IntList)
            let unitEid = createEntity(templateName) <| $(init)
              init |> set("unit__className", unit)
              init |> set("transform", unitTransform)
              init |> set("team", army)
              init |> set("unit__ownsUnitId", true)
              init |> set("aimer_custom_setting__checkVisibilityTarget", !isSpg)
              init |> set("aimer_custom_setting__ignoreStopForFire", true)
              init |> set("aimer_custom_setting__targetAAA", false)
              init |> set("aimer_custom_setting__moveSpeedKAtShooting", 0.1)
              disabledTriggers |> push(int(WeaponTriggerGroups.TRIGGER_GROUP_MACHINE_GUN))
              disabledTriggers |> push(int(WeaponTriggerGroups.TRIGGER_GROUP_COAXIAL_GUN))
              init |> set("custom_gun_properties__tiggerGroupNo", disabledTriggers)
              init |> set("custom_gun_properties__aimMaxDist", 0.)
            columnUnits |> push(unitEid)
            equip_factory__columnUnits |> push(unitEid)
        if columnUnits |> length() > 0
          tank_factory__spawnPoints -= tank_factory__spawnThreshold
          createEntity(isSpg ? "spg_units_column" : "units_column") <| $(init)
            init |> set("units_column__units", columnUnits)
            init |> set("units_column__target", equip_factory__currentColumnTarget)
            init |> set("units_column__captureCheckTimer", rnd_float(0., 1.)) 


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
  
  query() <| $ [es(REQUIRE=equip_storage__capacity)] (var unit__ref aka target_unit__ref : UnitRef&;
                                                      tank_factory__fuelStorage : EntityId const?;
                                                      tank_factory__ammoStorage : EntityId const?)
    if target_unit__ref.unit.isDelayed
      return

    var captured = false
    var newArmy = 0
    for unitEid in units_column__units
      query(unitEid) <| $ [es] (unit__ref aka column_unit__ref : UnitRef)
        if !column_unit__ref.unit.isDelayed && column_unit__ref.unit.isAlive && column_unit__ref.unit.army != target_unit__ref.unit.army
          if length_sq(column_unit__ref.unit.pos - target_unit__ref.unit.pos) < 400.
            captured = true
            newArmy = column_unit__ref.unit.army
      if captured
        break

    if !captured
      return
    *target_unit__ref.unit |> setArmy(newArmy)
    
    if tank_factory__fuelStorage != null && *tank_factory__fuelStorage != INVALID_ENTITY_ID
      query(*tank_factory__fuelStorage) <| $ [es] (var unit__ref aka fuel_unit__ref : UnitRef&)
        if !fuel_unit__ref.unit.isDelayed && fuel_unit__ref.unit.army != newArmy
          *fuel_unit__ref.unit |> setArmy(newArmy)
    if tank_factory__ammoStorage != null && *tank_factory__ammoStorage != INVALID_ENTITY_ID
      query(*tank_factory__ammoStorage) <| $ [es] (var unit__ref aka ammo_unit__ref : UnitRef&)
        if !ammo_unit__ref.unit.isDelayed && ammo_unit__ref.unit.army != newArmy
          *ammo_unit__ref.unit |> setArmy(newArmy)
  
  find_query() <| $ [es] (strongpoint__units : EidList;
                          var team : int&;
                          strongpoint__radius : float;
                          transform : float3x4)
    var found = false
    for unitEid in units_column__units
      query(unitEid) <| $ [es] (unit__ref aka column_unit__ref : UnitRef)
        if (!column_unit__ref.unit.isDelayed &&
         column_unit__ref.unit.isAlive && column_unit__ref.unit.army != team &&
         strongpoint__units |> length() <= 0 &&
         length_sq(column_unit__ref.unit.pos - transform[3]) < strongpoint__radius * strongpoint__radius)
          found = true
          team = column_unit__ref.unit.army
      if found
        return true
    return false

[es(tag=server, on_event=EventFlightStart)]
def init_assembly_area_es(evt : Event;
                          assembly_area__fuelStorageName : string;
                          assembly_area__ammoStorageName : string;
                          assembly_area__tankStorageName : string;
                          var assembly_area__fuelStorage : EntityId&;
                          var assembly_area__ammoStorage : EntityId&;
                          var assembly_area__tankStorage : EntityId&)
  query() <| $ [es(REQUIRE=equip_storage__current)] (eid : EntityId; unit__missionName : string)
    if unit__missionName == assembly_area__fuelStorageName
      assembly_area__fuelStorage = eid
    elif unit__missionName == assembly_area__ammoStorageName
      assembly_area__ammoStorage = eid
    elif unit__missionName == assembly_area__tankStorageName
      assembly_area__tankStorage = eid

  if assembly_area__tankStorage == INVALID_ENTITY_ID
    return
  query(assembly_area__tankStorage) <| $ [es] (var tank_factory__fuelStorage : EntityId&; var tank_factory__ammoStorage : EntityId&)
    tank_factory__fuelStorage = assembly_area__fuelStorage
    tank_factory__ammoStorage = assembly_area__ammoStorage

[es(tag=server, on_appear)]
def on_strongpoint_appear_es(evt : Event;
                             team : int;
                             transform : float3x4;
                             object_group_spawn_units__positions : TMatrixList;
                             object_group_spawn_units__namesTeam1 : StringList;
                             object_group_spawn_units__namesTeam2 : StringList;
                             var strongpoint__units : EidList&)
  assume unitList = team == 1 ? object_group_spawn_units__namesTeam1 : object_group_spawn_units__namesTeam2
  for unit, tm in unitList, object_group_spawn_units__positions
    var templateName = "tank+delayed_destroy_dead_unit+custom_gun_properties+disable_radar_on_start+unit_death_substract_team_tickets_5"
    if string(unit) |> find("/") != -1
      templateName = "simple_tank+delayed_destroy_dead_unit+custom_gun_properties+disable_radar_on_start+unit_death_substract_team_tickets_5"
    using() <| $(var disabledTriggers : IntList)
      let unitEid = createEntity(templateName) <| $(init)
        init |> set("unit__className", unit)
        init |> set("transform", transform * tm)
        init |> set("team", team)
        init |> set("unit__ownsUnitId", true)
        disabledTriggers |> push(int(WeaponTriggerGroups.TRIGGER_GROUP_MACHINE_GUN))
        disabledTriggers |> push(int(WeaponTriggerGroups.TRIGGER_GROUP_COAXIAL_GUN))
        init |> set("custom_gun_properties__tiggerGroupNo", disabledTriggers)
        init |> set("custom_gun_properties__aimMaxDist", 0.)
      strongpoint__units |> push(unitEid)

let distSqToAlly = 50. * 50.

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