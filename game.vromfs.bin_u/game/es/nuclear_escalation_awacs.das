require ecs
require ecs.common
require ecs.safe
require Unit
require %appGame.wt_events
require %game.unit.unit_events

def find_or_create_awacs_controller(army : int) : EntityId
  var controllerEid = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=nuclear_escalation_awacs_rotation__team)] (nuclear_escalation_awacs_rotation__team : int; eid : EntityId)
    if nuclear_escalation_awacs_rotation__team == army
      controllerEid = eid
      return true
    return false
  if controllerEid != INVALID_ENTITY_ID
    return controllerEid
  return createEntitySync("nuclear_escalation_awacs_rotation") <| $(init)
    init |> set("nuclear_escalation_awacs_rotation__team", army)

[es(tag=server, on_appear, track=nuclear_escalation_awacs__isActive, after=unit_init_completed_es)]
def awacs_sensor_sync_es(evt : Event;
                         unit__ref : UnitRef;
                         nuclear_escalation_awacs__isActive : bool;
                         var nuclear_escalation_awacs__detectedUnits : EidList&)
  *unit__ref.unit |> changeSensorPowerModeByCond(!nuclear_escalation_awacs__isActive)
  if !nuclear_escalation_awacs__isActive
    nuclear_escalation_awacs__detectedUnits |> clear()

[es(tag=server, on_event=(EventUnitDelayedStatusChanged, EventOnUnitDead, EventUnitRepair, EventUnitRespawn), after=unit_init_completed_es, REQUIRE=nuclear_escalation_awacs__isActive)]
def awacs_roster_sync_es(evt : Event;
                         eid : EntityId;
                         var unit__ref : UnitRef&)
  unit__ref.unit.earlyWarning = true
  let army = unit__ref.unit.army
  let isInService = !unit__ref.unit.isDelayed && unit__ref.unit.isAlive
  let controllerEid = find_or_create_awacs_controller(army)
  query(controllerEid) <| $ [es] (var nuclear_escalation_awacs_rotation__roster : EidList&)
    let idx = find_index(nuclear_escalation_awacs_rotation__roster, eid)
    if isInService
      if idx == -1
        nuclear_escalation_awacs_rotation__roster |> push(eid)
    elif idx != -1
      nuclear_escalation_awacs_rotation__roster |> erase(idx)
  if !isInService
    set(eid, "nuclear_escalation_awacs__isActive", false)

[es(tag=server, no_order, REQUIRE=nuclear_escalation_awacs_rotation__team)]
def awacs_rotation_update_es(act : UpdateStageInfoAct;
                             nuclear_escalation_awacs_rotation__roster : EidList;
                             var nuclear_escalation_awacs_rotation__activeEid : EntityId&;
                             var nuclear_escalation_awacs_rotation__windowTimer : float&;
                             var nuclear_escalation_awacs_rotation__isRestPhase : bool&;
                             nuclear_escalation_awacs_rotation__workTime : float;
                             nuclear_escalation_awacs_rotation__restTime : float)
  let count = nuclear_escalation_awacs_rotation__roster |> length()
  if count == 0
    nuclear_escalation_awacs_rotation__activeEid = INVALID_ENTITY_ID
    return

  if count == 1
    let onlyRadar = nuclear_escalation_awacs_rotation__roster[0]
    if nuclear_escalation_awacs_rotation__activeEid != onlyRadar
      nuclear_escalation_awacs_rotation__activeEid = onlyRadar
      nuclear_escalation_awacs_rotation__isRestPhase = false
      nuclear_escalation_awacs_rotation__windowTimer = nuclear_escalation_awacs_rotation__workTime
    nuclear_escalation_awacs_rotation__windowTimer -= act.dt
    if nuclear_escalation_awacs_rotation__windowTimer <= 0.
      nuclear_escalation_awacs_rotation__isRestPhase = !nuclear_escalation_awacs_rotation__isRestPhase
      nuclear_escalation_awacs_rotation__windowTimer = nuclear_escalation_awacs_rotation__isRestPhase ? nuclear_escalation_awacs_rotation__restTime : nuclear_escalation_awacs_rotation__workTime
    set(onlyRadar, "nuclear_escalation_awacs__isActive", !nuclear_escalation_awacs_rotation__isRestPhase)
  else
    nuclear_escalation_awacs_rotation__isRestPhase = false
    var activeIdx = find_index(nuclear_escalation_awacs_rotation__roster, nuclear_escalation_awacs_rotation__activeEid)
    if activeIdx == -1
      activeIdx = 0
      nuclear_escalation_awacs_rotation__windowTimer = nuclear_escalation_awacs_rotation__workTime
    else
      nuclear_escalation_awacs_rotation__windowTimer -= act.dt
      if nuclear_escalation_awacs_rotation__windowTimer <= 0.
        activeIdx = (activeIdx + 1) % count
        nuclear_escalation_awacs_rotation__windowTimer = nuclear_escalation_awacs_rotation__workTime
    let newActive = nuclear_escalation_awacs_rotation__roster[activeIdx]
    if nuclear_escalation_awacs_rotation__activeEid != newActive
      if nuclear_escalation_awacs_rotation__activeEid != INVALID_ENTITY_ID
        set(nuclear_escalation_awacs_rotation__activeEid, "nuclear_escalation_awacs__isActive", false)
      nuclear_escalation_awacs_rotation__activeEid = newActive
    set(newActive, "nuclear_escalation_awacs__isActive", true)
