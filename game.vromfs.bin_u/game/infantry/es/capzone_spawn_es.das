require ecs
require %appGame.wt_events
require %game.events
require DagorRandom
require math.base
require Mission
require %appGame.infantry.es.team_common


[es(tag=server, REQUIRE=infantry_spawn__capzoneEid)]
def get_zone_entity_by_id_es(evt : EventGetZoneEntityById;
                             eid : EntityId;
                             capture_zone__zoneId : int)
  if capture_zone__zoneId == evt.zoneId
    evt.result = eid


[es(tag=gameClient, REQUIRE=infantry_spawn_zone_proxy, track=dynamic_respawn__prevPositionsClient, on_appear)]
def infantry_spawn_track_positions_client(evt : Event;
                                          dynamic_respawn__prevPositionsClient : Point3List;
                                          var dynamic_respawn__prevPositions : Point3List&)
  dynamic_respawn__prevPositions := dynamic_respawn__prevPositionsClient


[es(tag=server)]
def infantry_spawn_proxy_update_es(info : ParallelUpdateFrameDelayed;
                                   infantry_spawn__capzoneEid : EntityId;
                                   var capzone__hasEnemyInside : bool&;
                                   var infantry_spawn__owningTeam : int&;
                                   var infantry_spawn__hasEnoughSuppliesForSpawn : bool&)
  query(infantry_spawn__capzoneEid) <| $ [es] (capzone__capTeam : int;
                                               capzone__owningTeam : int;
                                               teamPresence : Object;
                                               supply_node__points : float const?;
                                               supply_node__spawnCost : float = 0.0)
    let ownerCount = team_presence_count(teamPresence, capzone__capTeam)
    var totalCount = 0
    for presence in teamPresence
      let arr = get_ecs_array(presence.value)
      if arr != null
        totalCount += length(*arr)
    let hasEnemy = totalCount > ownerCount
    if capzone__hasEnemyInside != hasEnemy
      capzone__hasEnemyInside = hasEnemy
    if infantry_spawn__owningTeam != capzone__owningTeam
      infantry_spawn__owningTeam = capzone__owningTeam
    let hasEnoughSupplies = supply_node__points == null || *supply_node__points >= supply_node__spawnCost
    if infantry_spawn__hasEnoughSuppliesForSpawn != hasEnoughSupplies
      infantry_spawn__hasEnoughSuppliesForSpawn = hasEnoughSupplies


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
                             infantry_spawn__capzoneEid : EntityId;
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
    if evt.verified
      query(infantry_spawn__capzoneEid) <| $ [es] (var supply_node__points : float&;
                                                   supply_node__spawnCost : float)
        if supply_node__points < supply_node__spawnCost
          evt.verified = false
          print("[SPSQUAD] spawn unit {eid} on zone {proxyEid} REJECTED: supplies {supply_node__points} < {supply_node__spawnCost}")
        else
          supply_node__points -= supply_node__spawnCost
  if dynamic_respawn__spawnOnUnitEid != null
    *dynamic_respawn__spawnOnUnitEid = evt.verified ? proxyEid : INVALID_ENTITY_ID


def private gather_enemy_points(bot_team : int; var points : array<float3>)
  query() <| $ [es(REQUIRE_NOT=(plantSiteAiZone, capzoneSector))] (capzone__owningTeam : int; active : bool; transform : float3x4)
    if active && capzone__owningTeam != bot_team && capzone__owningTeam != TEAM_UNASSIGNED
      push(points, transform[3])
  if empty(points)
    get_respawn_points() <| $(active, resptype, team, pos)
      if active && team != bot_team && team > 0 && resptype == "human"
        push(points, pos)


[es(tag=server)]
def select_bot_spawn_zone_es(evt : EventSelectBotSpawnZone)
  var candidates : array<EntityId>
  query() <| $ [es(REQUIRE=infantry_spawn_zone_proxy)] (eid : EntityId;
                                                        infantry_spawn__owningTeam : int;
                                                        capzone__hasEnemyInside : bool;
                                                        dynamic_respawn__prevPositions : Point3List)
    if infantry_spawn__owningTeam == evt.team && !capzone__hasEnemyInside && !empty(dynamic_respawn__prevPositions)
      push(candidates, eid)
  let numZones = length(candidates)
  if numZones == 0
    return
  let randomShare = rnd_float(0., 1.)
  var chosenEid = INVALID_ENTITY_ID
  if numZones == 1
    if randomShare >= evt.frontZoneShare
      return
    chosenEid = candidates[0]
  else
    if randomShare >= evt.frontZoneShare + evt.otherZonesShare
      return
    var enemyPoints : array<float3>
    gather_enemy_points(evt.team, enemyPoints)
    var frontIdx = 0
    var bestDistSq = FLT_MAX
    for i in range(numZones)
      query(candidates[i]) <| $ [es] (transform : float3x4)
        for p in enemyPoints
          let distSq = length_sq(transform[3] - p)
          if distSq < bestDistSq
            bestDistSq = distSq
            frontIdx = i
    if randomShare < evt.frontZoneShare
      chosenEid = candidates[frontIdx]
    else
      var otherIdx = rnd_int(0, numZones - 2)
      if otherIdx >= frontIdx
        otherIdx++
      chosenEid = candidates[otherIdx]
  query(chosenEid) <| $ [es] (capture_zone__zoneId : int; dynamic_respawn__prevPositions : Point3List)
    evt.zoneId = capture_zone__zoneId
    evt.pos = dynamic_respawn__prevPositions[rnd_int(0, length(dynamic_respawn__prevPositions) - 1)]
