require ecs
require ecs.common
require %game.events
require math.base
require %appGame.infantry.es.team_common
require AnimV20
require GeomNodeTree
require DagorMath
require Grid
require RendInst
require CollRes
require Dacoll
require GridCollision
require CollisionTraces
require matching

struct DoorData
  eid : EntityId
  handle : uint64
  score : float
  dir : float3
  lookAt : bool

def can_use_vehicle(player_team : int; restrict_to_team : int; player_group : int64; vehicle_group : int64; vehicle_eid : EntityId; soldier_eid : EntityId)
  return ((restrict_to_team == TEAM_UNASSIGNED || is_teams_friendly(player_team, restrict_to_team)) &&
    (vehicle_group == int64(INVALID_SQUAD_ID) || player_group == vehicle_group)) && !is_vehicle_locked_for_entity(soldier_eid, vehicle_eid)

def is_vehicle_locked_for_entity(soldier_eid : EntityId; vehicle_eid : EntityId)
  var locked = false
  query(vehicle_eid) <| $ [es(REQUIRE=vehicle__onlyOwnerSquadCanUse)] (ownedBySquad : EntityId)
    query(soldier_eid) <| $ [es] (squad_member__squad : EntityId; human_anim__vehicleSelected : EntityId)
      locked = human_anim__vehicleSelected != vehicle_eid && squad_member__squad != ownedBySquad
  return locked

[es(REQUIRE=hero, after=(hero_human_use_stationary_gun_object_es, hero_human_pre_use_object_es), before=push_door_es )]
def hero_human_use_door_object_es(info : ParallelUpdateFrameDelayed;
                                  bindedCamera : EntityId;
                                  animchar : AnimcharBaseComponent;
                                  human_use_object__useDoorDist : float = 2.5;
                                  human_use_object__doorLimitCosine : float = 0.8;
                                  human_use_object__nodeId : int = 0;
                                  human_use_object__lockDoorUse : bool = false;
                                  human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                  var human_use_object__selectedObject : EntityId&;
                                  var human_use_object__lookAtSelected : bool&)
  
  if human_use_object__selectedObject != INVALID_ENTITY_ID || human_use_object__lockDoorUse
    return

  let attachedToGun = human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
  if attachedToGun
    return

  let camTm = get_TMatrix(bindedCamera, "transform") ?? IDENT_TM
  let traceDir = camTm[2]
  let tracePos = (human_use_object__nodeId > 0 ? *animchar.nodeTree |> geomtree_getNodeWpos(human_use_object__nodeId)
                                               : camTm[3])

  let traceEnd = tracePos + traceDir * human_use_object__useDoorDist
  let doorsSphereRadius = human_use_object__useDoorDist * 0.3
  let doorsSpherePos = tracePos + traceDir * doorsSphereRadius
  let doorsSphere = BSphere3(doorsSpherePos, doorsSphereRadius)
  var doorsData : array<DoorData>
  for_each_entity_in_grid(ecs_hash("doors"), doorsSphere, GridEntCheck.BOUNDING) <| $(doorEid : EntityId)
    query(doorEid) <| $ [es(REQUIRE=isDoor)] (ri_extra : RiExtraComponent)
      let riType = int(handle_to_ri_type(ri_extra.handle))
      let collRes = get_rigen_extra_coll_res(riType)
      if collRes == null
        return
      var tm : float3x4
      get_rigen_extra_matrix(ri_extra.handle, tm)

      var wbox = collRes.vFullBBox
      bbox3f_init(wbox, mat44f(tm), collRes.vFullBBox)
      let minDistSq = v_distance_sq_to_bbox(wbox.bmin, wbox.bmax, float4(tracePos, 1.0))
      if minDistSq > square(human_use_object__useDoorDist)
        return
      let boxCenter = (collRes.vFullBBox.bmin + collRes.vFullBBox.bmax).xyz * 0.5
      let center = tm * boxCenter
      let dir = center - tracePos
      let dot = dot(normalize(dir), traceDir)
      let lookAt = v_test_segment_box_intersection(tracePos, traceEnd, wbox) != 0
      if dot < human_use_object__doorLimitCosine && !lookAt
        return
      let score = 1.0 - dot
      doorsData |> push(DoorData(eid = doorEid, handle = ri_extra.handle, score = score, dir = dir, lookAt = lookAt))

    sort(doorsData) <| $(a; b)
      return a.score < b.score

    using() <| $(var riDesc : RendInstDesc#)
      for data in doorsData
        let dir = data.dir
        let dirLen = length(dir)
        let dirNormalized = dir * safeinv(dirLen)
        var t = dirLen
        var pmid : int
        var norm : float3
        traceray_normalized(tracePos, dirNormalized, t, pmid, norm, ETF_RI, riDesc, -1)

        var isCorrectDoor = riDesc.riExtraHandle == data.handle
        if !isCorrectDoor
          let additionalHandles = get_ecs_UInt64List(data.eid, "door_ri_extra__handles")
          if additionalHandles != null
            isCorrectDoor = find_index(*additionalHandles, riDesc.riExtraHandle) != -1

        if riDesc.isValid && riDesc.isRiExtra && !isCorrectDoor
          riDesc |> invalidate()
          continue

        human_use_object__selectedObject = data.eid
        human_use_object__lookAtSelected = data.lookAt
        return


def is_vehicle_has_free_player_seats(vehicle_eid : EntityId;
                                     player_eid : EntityId)
  var seatFound = false
  query(vehicle_eid) <| $ [es] (vehicle_seats__seatEids : EidList)
    for seatEid in vehicle_seats__seatEids
      query(seatEid) <| $ [es] (seats_order__canPlaceManually : bool = true;
                                seat__ownerEid : EntityId = INVALID_ENTITY_ID;
                                seat__playerEid : EntityId = INVALID_ENTITY_ID)
        if (seats_order__canPlaceManually && (
          (seat__ownerEid == INVALID_ENTITY_ID) ||
          (seat__playerEid == player_eid) ||
          !(get_bool(seat__ownerEid, "isAlive") ?? true)))
          seatFound = true
      if seatFound
        break
  return seatFound


def can_request_ammo_from(squad_eid : EntityId;
                          target_eid : EntityId)
  if !squad_eid || !(get_bool(squad_eid, "squad__isLeaderNeedsAmmo") ?? true)
    return false
  var res = false
  query(target_eid) <| $ [es(REQUIRE=human)] (squad_member__squad : EntityId;
                                              isAlive : bool;
                                              isDowned : bool)
    if isAlive && !isDowned
      res = (squad_member__squad == squad_eid)
  return res


[es(REQUIRE=hero, after=(hero_human_use_door_object_es, hero_human_pre_use_object_es) )]
def hero_human_use_human_object_es(info : ParallelUpdateFrameDelayed;
                                   eid : EntityId;
                                   possessedByPlr : EntityId;
                                   squad_member__playerEid : EntityId;
                                   animchar : AnimcharBaseComponent;
                                   human_use_object__useDist : float;
                                   human_weap__throwMode : bool;
                                   team aka team_human : int = TEAM_UNASSIGNED;
                                   human_use_object__nodeId : int = 0;
                                   bindedCamera : EntityId;
                                   squad_member__squad : EntityId = INVALID_ENTITY_ID;
                                   human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                   human_use_object__lockVehicleUse : bool = false;
                                   var human_use_object__selectedObject : EntityId&)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return
  let camTm = get_TMatrix(bindedCamera, "transform") ?? IDENT_TM
  let traceDir = camTm[2]
  var tracePos = (human_use_object__nodeId > 0 ? *animchar.nodeTree |> geomtree_getNodeWpos(human_use_object__nodeId)
                                               : camTm[3])

  using() <| $(var entities : IntersectedEntities)
    var dist = human_use_object__useDist
    trace_entities_in_grid(ecs_hash("humans"), tracePos, traceDir, dist, eid, entities, SortIntersections.NO)
    trace_entities_in_grid(ecs_hash("vehicles"), tracePos, traceDir, dist, INVALID_ENTITY_ID, entities, SortIntersections.YES)

    let canUseVehicles = !human_use_object__lockVehicleUse && human_attached_gun__attachedGunEid == INVALID_ENTITY_ID && !human_weap__throwMode
    var prevDist = 0.0
    for entity in entities
      if eid == entity.eid
        continue

      var traceDist = entity.t - prevDist
      tracePos += traceDir * traceDist
      prevDist = entity.t
      var norm : float3
      if traceray_normalized(tracePos, traceDir, traceDist, norm)
        return 

      if canUseVehicles
        query(entity.eid) <| $ [es(REQUIRE=vehicle_seats__seats)] (isAlive : bool = true;
                                                                   vehicle_seats__restrictToTeam : int = TEAM_UNASSIGNED;
                                                                   vehicle_seats__restrictToGroup : int64 = int64(INVALID_SQUAD_ID))
          if !isAlive
            return
          let playerGroup = get_int64(squad_member__playerEid, "groupId") ?? int64(INVALID_SQUAD_ID)
          if !can_use_vehicle(team_human, vehicle_seats__restrictToTeam, playerGroup, vehicle_seats__restrictToGroup, entity.eid, eid)
            return
          if is_vehicle_has_free_player_seats(entity.eid, possessedByPlr)
            human_use_object__selectedObject = entity.eid
        if human_use_object__selectedObject != INVALID_ENTITY_ID
          break

      let isLootable = has(entity.eid, "lootable")
      let isLootableGunOnly = has(entity.eid, "lootableGunOnly")
      let isAlive = get_bool(entity.eid, "isAlive") ?? true
      if isLootable && !isLootableGunOnly && !isAlive
        let itemContainer = getRW_ecs_EidList(entity.eid, "itemContainer")
        if itemContainer != null && length(*itemContainer) > 0
          human_use_object__selectedObject = entity.eid
          break
      if can_request_ammo_from(squad_member__squad, entity.eid)
        human_use_object__selectedObject = entity.eid
        break


[es(REQUIRE=hero, after=hero_human_pre_use_object_es)]
def hero_human_use_downed_human_object_es(info : ParallelUpdateFrameDelayed;
                                          animchar : AnimcharBaseComponent;
                                          team aka team_hero : int;
                                          bindedCamera : EntityId;
                                          total_kits__targetRevive : int = 0;
                                          human_reviver__maxDistance : float2 = float2(0.0, 0.0);
                                          human_reviver__maxAngle : float = 45.0;
                                          human_use_object__nodeId : int = 0;
                                          var human_use_object__selectedObject : EntityId&)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return
  if total_kits__targetRevive == 0
    return
  let camTm = get_TMatrix(bindedCamera, "transform") ?? IDENT_TM
  let tracePos = (human_use_object__nodeId > 0 ? *animchar.nodeTree |> geomtree_getNodeWpos(human_use_object__nodeId)
                                               : camTm[3])
  find_query() <| $ [es(REQUIRE=human)] (eid : EntityId;
                                         team : int;
                                         transform : float3x4;
                                         isDowned : bool)
    if team != team_hero || !isDowned
      return false

    let offset = transform[3] - tracePos
    let dist = length(offset)
    let dir = offset * safeinv(dist)
    if dist > human_reviver__maxDistance.x
      return false

    if dot(camTm[2], dir) < cos(deg_to_rad(human_reviver__maxAngle))
      return false
    var t = dist
    var norm : float3
    traceray_normalized(tracePos, dir, t, norm)
    if t - dist > FLT_EPSILON
      return false

    human_use_object__selectedObject = eid
    return true














