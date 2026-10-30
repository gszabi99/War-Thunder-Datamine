require ecs
require ecs.common
require math
require DagorMath
require Mission
require Unit
require %appGame.infantry.es.team_common
require %appGame.infantry.es.capzones_common

let
  MAX_TICK_PERIODS = 2.0

def private find_strongpoint_proxy(name : string) : EntityId
  var found = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=strongpoint)] (eid : EntityId; capture_zone__name : string)
    if capture_zone__name != name
      return false
    found = eid
    return true
  return found

def private is_team_linked(team : int;
                           neighbor_eids : EidList;
                           owner_by_eid : table<EntityId; int>;
                           strongpoint_owner : int) : bool
  if strongpoint_owner == team
    return true
  for neighborEid in neighbor_eids
    if (owner_by_eid?[neighborEid] ?? TEAM_UNASSIGNED) == team
      return true
  return false

[es(tag=server, on_appear, REQUIRE=capzoneSector)]
def capzone_sector_link_strongpoint_es(evt : Event;
                                       capzone_sector__strongpointName : string;
                                       var capzone_sector__strongpointEid : EntityId&)
  if !empty(capzone_sector__strongpointName)
    capzone_sector__strongpointEid = find_strongpoint_proxy(capzone_sector__strongpointName)

[es(tag=server, on_appear, REQUIRE=strongpoint)]
def capzone_strongpoint_link_sectors_es(evt : Event;
                                        eid : EntityId;
                                        capture_zone__name : string)
  let strongpointEid = eid
  let strongpointName = capture_zone__name
  query() <| $ [es] (capzone_sector__strongpointName : string;
                     var capzone_sector__strongpointEid : EntityId&)
    if capzone_sector__strongpointEid == INVALID_ENTITY_ID && capzone_sector__strongpointName == strongpointName
      capzone_sector__strongpointEid = strongpointEid

def private collect_sectors(proxy_eid : EntityId; var sector_eids : EidList&)
  var byIndex : array<EntityId>
  query() <| $ [es] (eid : EntityId;
                     capzone_sector__parentEid : EntityId;
                     capzone_sector__index : int)
    if capzone_sector__parentEid != proxy_eid || capzone_sector__index < 0
      return
    if length(byIndex) <= capzone_sector__index
      resize(byIndex, capzone_sector__index + 1)
    byIndex[capzone_sector__index] = eid
  for sectorEid in byIndex
    if sectorEid != INVALID_ENTITY_ID
      push(sector_eids, sectorEid)

[es(tag=server, on_appear, REQUIRE=sectoredCapzone)]
def sectored_capzone_collect_sectors_es(evt : Event;
                                        eid : EntityId;
                                        var sectored_capzone__sectorEids : EidList&)
  collect_sectors(eid, sectored_capzone__sectorEids)

[es(tag=server, on_appear, REQUIRE=capzoneSector)]
def capzone_sector_register_es(evt : Event;
                               eid : EntityId;
                               capzone_sector__parentEid : EntityId;
                               capzone_sector__strongpointName : string;
                               var capzone_sector__strongpointEid : EntityId&)
  let sectorEid = eid
  query(capzone_sector__parentEid) <| $ [es] (var sectored_capzone__sectorEids : EidList&)
    if !has_value(sectored_capzone__sectorEids, sectorEid)
      push(sectored_capzone__sectorEids, sectorEid)
  if !empty(capzone_sector__strongpointName)
    capzone_sector__strongpointEid = find_strongpoint_proxy(capzone_sector__strongpointName)

def private add_vehicle_presence(zone_id : int;
                                 sector_eids : EidList;
                                 var presence1 : array<int>&;
                                 var presence2 : array<int>&)
  query() <| $ [es(REQUIRE=unit_tag__tank, REQUIRE_NOT=human_controlled_vehicle)] (unit__ref : UnitRef; team : int)
    let vehicle = unit__ref.unit
    if vehicle == null || vehicle.capture_.cz == null || vehicle.capture_.cz.id != zone_id
      return
    let pos = vehicle.pos.xz
    for i in range(length(sector_eids))
      var inside = false
      query(sector_eids[i]) <| $ [es] (capzone_sector__points : Point2List)
        inside = is_point_in_poly(pos, capzone_sector__points)
      if inside
        if team == 1
          presence1[i]++
        elif team == 2
          presence2[i]++
        break

[es(tag=server, no_order, REQUIRE=sectoredCapzone)]
def sectored_capzone_update_es(info : UpdateStageInfoAct;
                               eid : EntityId;
                               capture_zone__zoneId : int;
                               active : bool;
                               capzone__owningTeam : int;
                               sectored_capzone__updatePeriod : float;
                               sectored_capzone__canCaptureByVehicles : bool;
                               var sectored_capzone__nextUpdateAt : float&;
                               var sectored_capzone__lastUpdateAt : float&;
                               sectored_capzone__sectorEids : EidList)
  if info.curTime < sectored_capzone__nextUpdateAt
    return
  let updateTimeOverflow = info.curTime - sectored_capzone__nextUpdateAt
  if updateTimeOverflow < sectored_capzone__updatePeriod
    sectored_capzone__nextUpdateAt += sectored_capzone__updatePeriod
  else
    sectored_capzone__nextUpdateAt = info.curTime + sectored_capzone__updatePeriod * eid_frnd(eid)

  let dt = sectored_capzone__lastUpdateAt > 0.0 ? min(info.curTime - sectored_capzone__lastUpdateAt, MAX_TICK_PERIODS * sectored_capzone__updatePeriod) : sectored_capzone__updatePeriod
  sectored_capzone__lastUpdateAt = info.curTime

  let zoneId = capture_zone__zoneId
  let sectorCount = length(sectored_capzone__sectorEids)
  if sectorCount == 0
    return

  var owners : array<int>
  var capTeams : array<int>
  var progresses : array<float>
  var presence1 : array<int>
  var presence2 : array<int>
  var strongpointOwners : array<int>
  var ownerByEid : table<EntityId; int>
  resize(owners, sectorCount)
  resize(capTeams, sectorCount)
  resize(progresses, sectorCount)
  resize(presence1, sectorCount)
  resize(presence2, sectorCount)
  resize(strongpointOwners, sectorCount)
  for i in range(sectorCount)
    let sectorEid = sectored_capzone__sectorEids[i]
    var strongpointEid = INVALID_ENTITY_ID
    query(sectorEid) <| $ [es] (capzone_sector__owningTeam : int;
                                capzone_sector__capTeam : int;
                                capzone_sector__progress : float;
                                teamPresence : Object;
                                capzone_sector__strongpointEid : EntityId)
      strongpointEid = capzone_sector__strongpointEid
      owners[i] = capzone_sector__owningTeam
      capTeams[i] = capzone_sector__capTeam
      progresses[i] = capzone_sector__progress
      presence1[i] = team_presence_count(teamPresence, 1)
      presence2[i] = team_presence_count(teamPresence, 2)
    ownerByEid[sectorEid] = owners[i]
    strongpointOwners[i] = strongpoint_owner(strongpointEid)
  if sectored_capzone__canCaptureByVehicles
    add_vehicle_presence(zoneId, sectored_capzone__sectorEids, presence1, presence2)

  for i in range(sectorCount)
    let sectorEid = sectored_capzone__sectorEids[i]
    let p1 = presence1[i]
    let p2 = presence2[i]
    var owner = owners[i]
    var capTeam = capTeams[i]
    var progress = progresses[i]
    if p1 == 0 && p2 == 0 && (progress == 0.0 || (owner != TEAM_UNASSIGNED && abs(progress) >= 1.0))
      continue
    var linked1 = false
    var linked2 = false
    var rate = 0.0
    query(sectorEid) <| $ [es] (capzone_sector__neighborEids : EidList;
                                capzone_sector__captureTime : float;
                                capzone_sector__timeMultiplier : float)
      linked1 = is_team_linked(1, capzone_sector__neighborEids, ownerByEid, strongpointOwners[i])
      linked2 = is_team_linked(2, capzone_sector__neighborEids, ownerByEid, strongpointOwners[i])
      let fullTime = capzone_sector__captureTime * capzone_sector__timeMultiplier
      rate = safediv(dt, fullTime)
    let n1 = (owner == 1 || linked1) ? p1 : 0
    let n2 = (owner == 2 || linked2) ? p2 : 0
    let wdiff = n1 - n2
    let leader = wdiff > 0 ? 1 : (wdiff < 0 ? 2 : TEAM_UNASSIGNED)
    if leader != TEAM_UNASSIGNED && owner != leader
      capTeam = leader
      let dir = leader == 1 ? -1.0 : 1.0
      progress = clamp(progress + dir * sqrt(float(abs(wdiff))) * rate, -1.0, 1.0)
      if owner != TEAM_UNASSIGNED && owner != leader
        owner = TEAM_UNASSIGNED
      if owner == TEAM_UNASSIGNED && abs(progress) >= 1.0
        owner = leader
    elif owner == TEAM_UNASSIGNED && progress != 0.0
      progress -= sign(progress) * min(rate, abs(progress))
      if progress == 0.0
        capTeam = TEAM_UNASSIGNED
    if owner == owners[i] && capTeam == capTeams[i] && progress == progresses[i]
      continue
    query(sectorEid) <| $ [es] (var capzone_sector__owningTeam : int&;
                                var capzone_sector__capTeam : int&;
                                var capzone_sector__progress : float&)
      capzone_sector__owningTeam = owner
      capzone_sector__capTeam = capTeam
      capzone_sector__progress = progress
    owners[i] = owner

  let settlementActive = active
  for i in range(sectorCount)
    ownerByEid[sectored_capzone__sectorEids[i]] = owners[i]
  for i in range(sectorCount)
    let owner = owners[i]
    let strongpointOwner = strongpointOwners[i]
    query(sectored_capzone__sectorEids[i]) <| $ [es] (capzone_sector__neighborEids : EidList;
                                                      capzone_sector__capTeam : int;
                                                      capzone_sector__progress : float;
                                                      var active aka sector_active : bool&;
                                                      var capzone__owningTeam aka sector_capzone__owningTeam : int&;
                                                      var capzone__capTeam : int&;
                                                      var capzone__progress : float&)
      let canCapture1 = owner != 1 && is_team_linked(1, capzone_sector__neighborEids, ownerByEid, strongpointOwner)
      let canCapture2 = owner != 2 && is_team_linked(2, capzone_sector__neighborEids, ownerByEid, strongpointOwner)
      sector_active = settlementActive && (canCapture1 || canCapture2)
      sector_capzone__owningTeam = canCapture1 == canCapture2 ? TEAM_UNASSIGNED : (canCapture1 ? 2 : 1)
      capzone__capTeam = capzone_sector__capTeam
      capzone__progress = abs(capzone_sector__progress)

  var allOwner = owners[0]
  var enemyOwned = false
  for owner in owners
    if owner != allOwner
      allOwner = TEAM_UNASSIGNED
    if capzone__owningTeam != TEAM_UNASSIGNED && owner != TEAM_UNASSIGNED && owner != capzone__owningTeam
      enemyOwned = true
  if allOwner != TEAM_UNASSIGNED && capzone__owningTeam != allOwner
    capture_zone_set_army(zoneId, allOwner)
  elif enemyOwned
    capture_zone_set_army(zoneId, 0)

[es(tag=server, on_event=EventMissionUnload, REQUIRE=capzoneSector)]
def capzone_sector_mission_unload(evt : Event; eid : EntityId)
  destroyEntity(eid)

[es(tag=server, on_event=EventMissionUnload, REQUIRE=sectoredCapzone)]
def sectored_capzone_mission_unload(evt : Event; eid : EntityId)
  destroyEntity(eid)
