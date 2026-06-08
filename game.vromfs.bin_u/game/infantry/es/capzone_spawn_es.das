require ecs
require %appGame.wt_events
require %game.events
require %appGame.infantry.es.team_common


[es(tag=server, REQUIRE=infantry_spawn__capzoneEid)]
def get_zone_entity_by_id_es(evt : EventGetZoneEntityById;
                             eid : EntityId;
                             capture_zone__zoneId : int)
  if capture_zone__zoneId == evt.zoneId
    evt.result = eid


def private copy_capzone_navmesh_to_proxy(capzone_eid : EntityId;
                                          capzone__insideNavmeshPositions : Point3List;
                                          capzone__nearestNavmeshPos : float3;
                                          capzone__hasNearestNavmeshPos : bool;
                                          var dynamic_respawn__prevPositions : Point3List&;
                                          var dynamic_respawn__prevPositionsClient : Point3List&)
  clear(dynamic_respawn__prevPositions)
  if !empty(capzone__insideNavmeshPositions)
    dynamic_respawn__prevPositions := capzone__insideNavmeshPositions
  elif capzone__hasNearestNavmeshPos
    push(dynamic_respawn__prevPositions, capzone__nearestNavmeshPos)
  else
    print("[SPSQUAD] proxy init: no navmesh positions for capzone {capzone_eid}")
  dynamic_respawn__prevPositionsClient := dynamic_respawn__prevPositions


[es(tag=server, on_appear, after=(capzone_init_nearest_navmesh_point))]
def capzone_init_spawn_proxy_positions_es(evt : Event;
                                          eid : EntityId;
                                          capzone__insideNavmeshPositions : Point3List;
                                          capzone__nearestNavmeshPos : float3;
                                          capzone__hasNearestNavmeshPos : bool)
  query() <| $ [es] (infantry_spawn__capzoneEid : EntityId;
                     var dynamic_respawn__prevPositions : Point3List&;
                     var dynamic_respawn__prevPositionsClient : Point3List&)
    if infantry_spawn__capzoneEid == eid && empty(dynamic_respawn__prevPositions)
      copy_capzone_navmesh_to_proxy(eid, capzone__insideNavmeshPositions, capzone__nearestNavmeshPos,
                                    capzone__hasNearestNavmeshPos, dynamic_respawn__prevPositions,
                                    dynamic_respawn__prevPositionsClient)


[es(tag=server, on_appear)]
def infantry_spawn_proxy_init_positions_es(evt : Event;
                                           infantry_spawn__capzoneEid : EntityId;
                                           var dynamic_respawn__prevPositions : Point3List&;
                                           var dynamic_respawn__prevPositionsClient : Point3List&)
  query(infantry_spawn__capzoneEid) <| $ [es] (capzone__insideNavmeshPositions : Point3List;
                                               capzone__nearestNavmeshPos : float3;
                                               capzone__hasNearestNavmeshPos : bool)
    if empty(dynamic_respawn__prevPositions)
      copy_capzone_navmesh_to_proxy(infantry_spawn__capzoneEid, capzone__insideNavmeshPositions, capzone__nearestNavmeshPos,
                                    capzone__hasNearestNavmeshPos, dynamic_respawn__prevPositions,
                                    dynamic_respawn__prevPositionsClient)


[es(tag=server, on_event=EventLevelLoaded, after=capzone_init_all_nearest_navmesh_points)]
def infantry_spawn_proxy_init_positions_after_level_load(evt : Event)
  query() <| $ [es(REQUIRE_NOT=moveable_capzone)] (eid : EntityId;
                                                   capzone__insideNavmeshPositions : Point3List;
                                                   capzone__nearestNavmeshPos : float3;
                                                   capzone__hasNearestNavmeshPos : bool)
    find_query() <| $ [es(REQUIRE=infantry_spawn_zone_proxy)] (infantry_spawn__capzoneEid : EntityId;
                                                               var dynamic_respawn__prevPositions : Point3List&;
                                                               var dynamic_respawn__prevPositionsClient : Point3List&)
      if eid == infantry_spawn__capzoneEid && empty(dynamic_respawn__prevPositions)
        copy_capzone_navmesh_to_proxy(eid, capzone__insideNavmeshPositions, capzone__nearestNavmeshPos,
                                      capzone__hasNearestNavmeshPos, dynamic_respawn__prevPositions,
                                      dynamic_respawn__prevPositionsClient)
        return true
      return false


[es(tag=gameClient, REQUIRE=infantry_spawn_zone_proxy, track=dynamic_respawn__prevPositionsClient, on_appear)]
def infantry_spawn_track_positions_client(evt : Event;
                                          dynamic_respawn__prevPositionsClient : Point3List;
                                          var dynamic_respawn__prevPositions : Point3List&)
  dynamic_respawn__prevPositions := dynamic_respawn__prevPositionsClient


[es(tag=server)]
def infantry_spawn_proxy_update_es(info : ParallelUpdateFrameDelayed;
                                   infantry_spawn__capzoneEid : EntityId;
                                   var capzone__hasEnemyInside : bool&;
                                   var infantry_spawn__owningTeam : int&)
  query(infantry_spawn__capzoneEid) <| $ [es] (capzone__capTeam : int;
                                               capzone__owningTeam : int;
                                               teamPresence : Object)
    let ownerTeamStr = "{capzone__capTeam}"
    var ownerCount = 0
    let ownerArr = get_ecs_array(teamPresence, ownerTeamStr)
    if ownerArr != null
      ownerCount = length(*ownerArr)
    var totalCount = 0
    for presence in teamPresence
      let arr = get_ecs_array(presence.value)
      if arr != null
        totalCount += length(*arr)
    let hasEnemy = totalCount > ownerCount
    if capzone__hasEnemyInside != hasEnemy
      capzone__hasEnemyInside = hasEnemy
    var owningTeam = infantry_spawn__owningTeam
    if capzone__owningTeam != TEAM_UNASSIGNED
      owningTeam = capzone__owningTeam
    elif capzone__capTeam != infantry_spawn__owningTeam
      owningTeam = TEAM_UNASSIGNED
    if infantry_spawn__owningTeam != owningTeam
      infantry_spawn__owningTeam = owningTeam


[es(tag=server, REQUIRE=human)]
def squadmates_spawn_calculation_and_verify_zone(evt : EventCalcAndVerifySpawnTm;
                                                 eid : EntityId;
                                                 team : int;
                                                 var dynamic_respawn__spawnOnUnitEid : EntityId?)
  let proxyEid = evt.spawnOnEid

  if !has(proxyEid, "infantry_spawn_zone_proxy")
    return

  evt.verified = false
  query(proxyEid) <| $ [es] (infantry_spawn__owningTeam : int;
                             capzone__hasEnemyInside : bool;
                             dynamic_respawn__prevPositions : Point3List)
    if infantry_spawn__owningTeam != team || capzone__hasEnemyInside
      print("[SPSQUAD] zone spawn on zone {proxyEid} REJECTED: owningTeam={infantry_spawn__owningTeam} spawnerTeam={team} hasEnemy={capzone__hasEnemyInside}")
      return
    if empty(dynamic_respawn__prevPositions)
      print("[SPSQUAD] zone spawn on zone {proxyEid} REJECTED: no positions")
      return
    let requestPosValid = length(evt.requestPos) > 0.
    if requestPosValid
      for pos in dynamic_respawn__prevPositions
        if length_sq(pos - evt.requestPos) < 0.01
          evt.verified = true
          evt.spawnTm[3] = evt.requestPos
          print("[SPSQUAD] spawn unit {eid} on zone {proxyEid} VERIFIED requestPos=({evt.requestPos})")
          break
    if !evt.verified
      print("[SPSQUAD] spawn unit {eid} on zone {proxyEid} REJECTED: requestPos=({evt.requestPos}) does not match any known position")
  if dynamic_respawn__spawnOnUnitEid != null
    *dynamic_respawn__spawnOnUnitEid = evt.verified ? proxyEid : INVALID_ENTITY_ID
