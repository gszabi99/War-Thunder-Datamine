require ecs
require Mission
require app
require Unit
require %appGame.wt_events

[es(tag=server)]
def on_airfield_bombing_zone_damaged_es(evt : EventOnBombingZoneDamaged;
                                        spawnedOnAirfieldId : int;
                                        team : int;
                                        airfield__ticketsByDestroy : int;
                                        var airfield__isDestroyed : bool&)
  if spawnedOnAirfieldId < 0 || spawnedOnAirfieldId != evt.airfieldId
    return
  if !airfield__isDestroyed && evt.hp <= 0.
    airfield__isDestroyed = true
    change_mp_tickets_for_team(team, -airfield__ticketsByDestroy)
  elif airfield__isDestroyed && evt.hp > 0.
    airfield__isDestroyed = false

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
  if spawnedOnAirfieldId < 0 || spawnedOnAirfieldId != evt.airfieldId
    return
  for unitEid in units_spawn_on_init__units
    query(unitEid) <| $ [es] (unit__ref : UnitRef;
                              var restore_unit_by_timer__restoreAtTime : float&;
                              var restore_unit_by_timer__isRestoringActive : bool&)
      restore_unit_by_timer__isRestoringActive = evt.active
      if !evt.active
        restore_unit_by_timer__restoreAtTime = -1.
      elif !unit__ref.unit.isDelayed && !unit__ref.unit.isAlive
        restore_unit_by_timer__restoreAtTime = get_sync_time()
