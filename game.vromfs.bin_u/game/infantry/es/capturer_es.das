require ecs
require ecs.common
require Unit
require %appGame.infantry.es.team_common

def find_zone_by_id(id : int)
  var zoneEid = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=teamPresence)] (eid : EntityId; capture_zone__zoneId : int)
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

def leave_sector(var sector_eid : EntityId&;
                 visitor : EntityId;
                 team : int)
  if sector_eid == INVALID_ENTITY_ID
    return
  remove_capturer(sector_eid, visitor, team)
  sector_eid = INVALID_ENTITY_ID

def is_pos_in_sector(sector_eid : EntityId;
                     proxy_eid : EntityId;
                     pos : float3) : bool
  var inside = false
  query(sector_eid) <| $ [es] (capzone_sector__parentEid : EntityId;
                               capzone_sector__points : Point2List)
    inside = capzone_sector__parentEid == proxy_eid && is_point_in_poly(pos.xz, capzone_sector__points)
  return inside

def find_sector_for_pos(proxy_eid : EntityId;
                        pos : float3;
                        prev_sector_eid : EntityId) : EntityId
  if is_pos_in_sector(prev_sector_eid, proxy_eid, pos)
    return prev_sector_eid
  var found = INVALID_ENTITY_ID
  query(prev_sector_eid) <| $ [es] (capzone_sector__neighborEids : EidList)
    for neighborEid in capzone_sector__neighborEids
      if is_pos_in_sector(neighborEid, proxy_eid, pos)
        found = neighborEid
        break
  if found != INVALID_ENTITY_ID
    return found
  query(proxy_eid) <| $ [es] (sectored_capzone__sectorEids : EidList)
    for sectorEid in sectored_capzone__sectorEids
      if is_pos_in_sector(sectorEid, proxy_eid, pos)
        found = sectorEid
        break
  if found == INVALID_ENTITY_ID
    query(prev_sector_eid) <| $ [es] (capzone_sector__parentEid : EntityId)
      if capzone_sector__parentEid == proxy_eid
        found = prev_sector_eid
  return found

def update_sector_presence(proxy_eid : EntityId;
                           pos : float3;
                           visitor : EntityId;
                           team : int;
                           var sector_eid : EntityId&)
  let newSector = find_sector_for_pos(proxy_eid, pos, sector_eid)
  if newSector == sector_eid
    return
  leave_sector(sector_eid, visitor, team)
  if newSector != INVALID_ENTITY_ID
    add_capturer(newSector, visitor, team)
    sector_eid = newSector

[es(tag=server, track=isAlive)]
def on_capturer_death_es(evt : Event;
                         eid : EntityId;
                         isAlive : bool;
                         team : int;
                         var capturer__capZonesIn : EidList&;
                         var capturer__sectorEid : EntityId&)
  if !isAlive && !empty(capturer__capZonesIn)
    remove_capturer(capturer__capZonesIn[0], eid, team)
    leave_sector(capturer__sectorEid, eid, team)
    clear(capturer__capZonesIn)

[es(tag=server, on_disappear)]
def on_capturer_disappear_es(evt : Event;
                             eid : EntityId;
                             isAlive : bool;
                             team : int;
                             var capturer__capZonesIn : EidList&;
                             var capturer__sectorEid : EntityId&)
  if isAlive && !empty(capturer__capZonesIn)
    remove_capturer(capturer__capZonesIn[0], eid, team)
    leave_sector(capturer__sectorEid, eid, team)
    clear(capturer__capZonesIn)

[es(tag=server, no_order)]
def capturer_es(info : UpdateStageInfoAct;
                eid : EntityId;
                unit__ref : UnitRef;
                team : int;
                capturer__updatePeriod : float;
                var capturer__nextUpdateAt : float&;
                var capturer__capZonesIn : EidList;
                var capturer__sectorEid : EntityId&;
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
    leave_sector(capturer__sectorEid, eid, team)
    remove_capturer(prevCapZoneEid, eid, team)
    return

  let capZoneEid = find_zone_by_id(capZone.id)
  push(capturer__capZonesIn, capZoneEid)
  if capZoneEid != prevCapZoneEid
    remove_capturer(prevCapZoneEid, eid, team)
    add_capturer(capZoneEid, eid, team)
  if has(capZoneEid, "sectoredCapzone")
    update_sector_presence(capZoneEid, unit__ref.unit.pos, eid, team, capturer__sectorEid)
  else
    leave_sector(capturer__sectorEid, eid, team)
