require ecs
require ecs.common
require Unit
require %appGame.infantry.es.team_common

def find_zone_by_id(id : int)
  var zoneEid = INVALID_ENTITY_ID
  find_query() <| $ [es] (eid : EntityId; capture_zone__zoneId : int)
    if capture_zone__zoneId != id
      return false
    zoneEid = eid
    return true
  return zoneEid

def add_capturer(zone_eid : EntityId;
                 visitor : EntityId;
                 team : int)
  if visitor == INVALID_ENTITY_ID || team == TEAM_UNASSIGNED
    return
  query(zone_eid) <| $ [es] (var teamPresence : Object&)
    let teamId = "{team}"
    var presence = getRW_ecs_array(teamPresence, teamId)
    if presence == null
      teamPresence |> push_to_object(teamId) <| $(var arr : Array)
        push(arr, visitor)
    else
      push(*presence, visitor)

def remove_capturer(zone_eid : EntityId;
                    visitor : EntityId;
                    team : int = TEAM_UNASSIGNED)
  if visitor == INVALID_ENTITY_ID || team == TEAM_UNASSIGNED
    return
  query(zone_eid) <| $ [es] (var teamPresence : Object&)
    if team != TEAM_UNASSIGNED
      let teamId = "{team}"
      var presence = getRW_ecs_array(teamPresence, teamId)
      if presence != null
        let idx = (*presence) |> find_index(visitor)
        if idx >= 0
          (*presence) |> erase(idx)
      else
        teamPresence |> push_to_object(teamId) <| $ [unused_argument(arr)] (var arr : Array) {}
    else
      for presence in teamPresence
        var presenceArr = getRW_ecs_array(presence.value)
        if presenceArr != null
          let idx = (*presenceArr) |> find_index(visitor)
          if idx >= 0
            (*presenceArr) |> erase(idx)

[es(tag=server, track=isAlive)]
def on_capturer_death_es(evt : Event;
                         eid : EntityId;
                         isAlive : bool;
                         team : int;
                         var capturer__capZonesIn : EidList&)
  if !isAlive && !empty(capturer__capZonesIn)
    remove_capturer(capturer__capZonesIn[0], eid, team)
    clear(capturer__capZonesIn)

[es(tag=server, on_disappear)]
def on_capturer_disappear_es(evt : Event;
                             eid : EntityId;
                             isAlive : bool;
                             team : int;
                             var capturer__capZonesIn : EidList&)
  if isAlive && !empty(capturer__capZonesIn)
    remove_capturer(capturer__capZonesIn[0], eid, team)
    clear(capturer__capZonesIn)

[es(tag=server, no_order)]
def capturer_es(info : UpdateStageInfoAct;
                eid : EntityId;
                unit__ref : UnitRef;
                team : int;
                capturer__updatePeriod : float;
                var capturer__nextUpdateAt : float&;
                var capturer__capZonesIn : EidList;
                isAlive : bool = true)
  if info.curTime < capturer__nextUpdateAt || !isAlive
    return
  let updateTimeOveflow = info.curTime - capturer__nextUpdateAt
  if updateTimeOveflow < capturer__updatePeriod
    capturer__nextUpdateAt += capturer__updatePeriod
  else 
    capturer__nextUpdateAt = info.curTime + capturer__updatePeriod * eid_frnd(eid)

  let prevCapZoneEid = empty(capturer__capZonesIn) ? INVALID_ENTITY_ID : capturer__capZonesIn[0]
  clear(capturer__capZonesIn)

  let capZone = unit__ref.unit.capture_.cz
  if capZone == null
    remove_capturer(prevCapZoneEid, eid, team)
    return

  let capZoneEid = find_zone_by_id(capZone.id)
  push(capturer__capZonesIn, capZoneEid)
  if capZoneEid != prevCapZoneEid
    remove_capturer(prevCapZoneEid, eid, team)
    add_capturer(capZoneEid, eid, team)
