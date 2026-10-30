require ecs
require app
require math.base
require DagorDebug3D
require DagorMath
require DngWalkerai
require pathfinder
require %game.utils.utils_common
require %appGame.infantry.ai.ai_team_nav_zones_common
require %game.events


[es(tag=server, on_appear)]
def team_grouping_zones_init(evt : Event;
                             var team_grouping__numZones : int&;
                             var team_grouping_zones__nextIdx : int&;
                             var team_grouping_zones__freeList : IntList&;
                             var team_grouping_zones__commonData : IPoint3List&;
                             var team_grouping_zones__lastPosRads : Point4List&;
                             var team_grouping_zones__lastHeights : Point2List&;
                             var team_grouping_zones__moveTracing : Point4List&;
                             var team_grouping_members__next : IntList&;
                             var team_grouping_members__eids : EidList&;
                             var team_grouping_members__free : IntList&)
  if team_grouping__numZones > MAX_NAV_GROUPS_PER_TEAM
    team_grouping__numZones = MAX_NAV_GROUPS_PER_TEAM

  let numZones = team_grouping__numZones
  team_grouping_zones__nextIdx = 0

  team_grouping_zones__freeList |> clear()
  for i in range(numZones)
    team_grouping_zones__freeList |> push(i)

  team_grouping_zones__commonData |> clear()
  team_grouping_zones__lastPosRads |> clear()
  team_grouping_zones__lastHeights |> clear()
  team_grouping_zones__moveTracing |> clear()

  team_grouping_zones__commonData |> resize(numZones)
  team_grouping_zones__lastPosRads |> resize(numZones)
  team_grouping_zones__lastHeights |> resize(numZones)
  team_grouping_zones__moveTracing |> resize(numZones)

  for i in range(numZones)
    team_grouping_zones__commonData[i].x = walker_agent_nav_allocAreaId()
    team_grouping_zones__commonData[i].y = 0
    team_grouping_zones__commonData[i].z = -1

  team_grouping_members__next |> clear()
  team_grouping_members__eids |> clear()
  team_grouping_members__free |> clear()


[es(tag=server, no_order)]
def team_grouping_zones_join_members(info : ParallelUpdateFrameDelayed;
                                     eid aka team_eid : EntityId;
                                     team__id : int;
                                     var walker_custom_nav : CustomNav&;
                                     var team_grouping__round : int&;
                                     team_grouping__numZones : int;
                                     team_grouping__minMaxMembers : int2;
                                     team_grouping__tickJoins : int;
                                     team_grouping_zones__joinRadius : float;
                                     var team_grouping_zones__freeList : IntList&;
                                     var team_grouping_zones__commonData : IPoint3List&;
                                     team_grouping_zones__lastPosRads : Point4List&;
                                     team_grouping_zones__lastHeights : Point2List&;
                                     var team_grouping__nextTimeCheckJoins : float&;
                                     team_grouping__checkDeltaTime : float)
  let curTime = get_sync_time()
  if curTime < team_grouping__nextTimeCheckJoins
    return
  team_grouping__nextTimeCheckJoins = curTime + team_grouping__checkDeltaTime

  let numZones = team_grouping__numZones

  var joinList : array<EntityId>
  var nexts : array<EntityId>
  joinList |> reserve(team_grouping__tickJoins)
  nexts |> reserve(team_grouping__tickJoins)
  var totalMembers = 0
  query() <| $ [es] (eid : EntityId; team : int; isAlive : bool;
                     human_grouping__round : int;
                     human_grouping__team : int;
                     human_grouping__zone : int)
    if team == team__id && isAlive
      ++totalMembers
      let singleTryJoin = (human_grouping__team == team__id && human_grouping__zone >= 0 && human_grouping__zone < numZones && team_grouping_zones__commonData[human_grouping__zone].y == 1)
      if human_grouping__team != team__id || singleTryJoin
        if human_grouping__round < team_grouping__round
          if length(joinList) < team_grouping__tickJoins
            joinList |> push(eid)
        else
          if length(nexts) < team_grouping__tickJoins
            nexts |> push(eid)

  var moved = 0
  while length(joinList) < team_grouping__tickJoins && length(nexts) > 0
    let moveEid = nexts[0]
    joinList |> push(moveEid)
    nexts |> erase(0)
    ++moved
  if moved > 0
    team_grouping__round += 1

  let minMaxMembers = team_grouping__minMaxMembers
  let maxZoneMembers = clamp(numZones > 0 ? ((totalMembers + numZones - 1) / numZones) : 0, minMaxMembers.x, minMaxMembers.y)

  for joinEid in joinList
    query(joinEid) <| $ [es] (transform : float3x4;
                              var human_grouping__round : int&;
                              var human_grouping__team : int&;
                              var human_grouping__zone : int&)
      human_grouping__round = team_grouping__round

      let searchPos = transform[3]
      let searchRad = team_grouping_zones__joinRadius

      let wasMember = human_grouping__team == team__id && human_grouping__zone >= 0 && human_grouping__zone < numZones
      let singleTryJoin = wasMember && team_grouping_zones__commonData[human_grouping__zone].y == 1

      var joinZoneIdx = -1
      var joinZoneCount = maxZoneMembers
      var zonesAround = 0
      walker_custom_nav_getNearCylAreasByUserTag(walker_custom_nav, searchPos, searchRad, CUSTOMNAV_TAG_GROUPING) <| $(area_id, area_data)
        let areaPosRad = walker_custom_nav_getCylAreaBBoxPosRadius(walker_custom_nav, area_id)
        if distance_sq(searchPos, areaPosRad.xyz) < square(searchRad + areaPosRad.w)
          let zoneIdx = area_data
          if zoneIdx >= 0 && zoneIdx < numZones
            let posRad = team_grouping_zones__lastPosRads[zoneIdx]
            let heights = team_grouping_zones__lastHeights[zoneIdx]
            if is_point_in_nav_grouping_zone(searchPos, posRad, heights)
              ++zonesAround
              let count = team_grouping_zones__commonData[zoneIdx].y
              if count < joinZoneCount && (!wasMember || (singleTryJoin && zoneIdx != human_grouping__zone))
                
                
                joinZoneIdx = zoneIdx
                joinZoneCount = count
        return false

      var alloced = false
      if joinZoneIdx < 0 && zonesAround == 0 && !empty(team_grouping_zones__freeList) && !wasMember
        joinZoneIdx = team_grouping_zones__freeList |> back()
        team_grouping_zones__freeList |> pop()
        alloced = true

      if joinZoneIdx >= 0
        
        
        var joined = false
        query(team_eid) <| $ [es] (var team_grouping_members__next : IntList&;
                                   var team_grouping_members__eids : EidList&;
                                   var team_grouping_members__free : IntList&)
          var newFirstMemberIdx = -1
          if empty(team_grouping_members__free)
            newFirstMemberIdx = length(team_grouping_members__eids)
            team_grouping_members__next |> push(-1)
            team_grouping_members__eids |> push(joinEid)
          else
            newFirstMemberIdx = team_grouping_members__free |> back()
            team_grouping_members__free |> pop()
            team_grouping_members__next[newFirstMemberIdx] = -1
            team_grouping_members__eids[newFirstMemberIdx] = joinEid

          if newFirstMemberIdx >= 0
            if singleTryJoin
              assume wasZoneData = team_grouping_zones__commonData[human_grouping__zone]
              
              walker_custom_nav_areaRemove(walker_custom_nav, wasZoneData.x)
              team_grouping_members__free |> push(wasZoneData.z)
              wasZoneData.y = 0
              wasZoneData.z = -1
              team_grouping_zones__freeList |> push(human_grouping__zone)
            human_grouping__team = team__id
            human_grouping__zone = joinZoneIdx
            let wasFirstMember = team_grouping_zones__commonData[joinZoneIdx].z
            team_grouping_members__next[newFirstMemberIdx] = wasFirstMember
            team_grouping_zones__commonData[joinZoneIdx].y += 1
            team_grouping_zones__commonData[joinZoneIdx].z = newFirstMemberIdx
            team_grouping_zone_update_custom_nav(team_eid, joinZoneIdx, alloced)
            
            joined = true
        if !joined && alloced
          error("!!! FAILED DEALLOC joinZoneIdx={joinZoneIdx}")
          team_grouping_zones__freeList |> push(joinZoneIdx)


def team_grouping_zone_update_custom_nav(team_eid : EntityId; zone_idx : int; new_zone : bool)
  query(team_eid) <| $ [es] (team__id : int;
                             var walker_custom_nav : CustomNav&;
                             team_grouping_zones__commonData : IPoint3List;
                             var team_grouping_zones__lastPosRads : Point4List&;
                             var team_grouping_zones__lastHeights : Point2List&;
                             var team_grouping_zones__moveTracing : Point4List&;
                             team_grouping_members__eids : EidList;
                             team_grouping_members__next : IntList;
                             team_grouping_zones__addRadius : float;
                             team_grouping_zones__maxRadius : float;
                             team_grouping_zones__addHeights : float2;
                             team_grouping_zones__mainWeight : float;
                             team_grouping_zones__edgeWeight : float)
    var zonePos = float2()
    var zoneHeights = float2()

    let membersCount = team_grouping_zones__commonData[zone_idx].y
    var positions : array<float3>
    positions |> reserve(membersCount)

    var memberIdx = team_grouping_zones__commonData[zone_idx].z
    for _i in range(membersCount)
      if memberIdx < 0
        break
      let memberEid = team_grouping_members__eids[memberIdx]
      query(memberEid) <| $ [es] (transform : float3x4)
        let pos = transform[3]
        positions |> push(pos)
        zonePos.x += pos.x
        zonePos.y += pos.z
        if length(positions) == 1
          zoneHeights = float2(pos.y, pos.y)
        else
          zoneHeights.x = min(zoneHeights.x, pos.y)
          zoneHeights.y = max(zoneHeights.y, pos.y)
      memberIdx = team_grouping_members__next[memberIdx]

    let divCoef = safeinv(float(length(positions)))
    zonePos.x *= divCoef
    zonePos.y *= divCoef

    zoneHeights.x += team_grouping_zones__addHeights.x
    zoneHeights.y += team_grouping_zones__addHeights.y

    var zoneRad = 0.0
    for pos in positions
      let dist = distance(pos.xz, zonePos.xy)
      zoneRad = max(zoneRad, dist)
    zoneRad = min(zoneRad + team_grouping_zones__addRadius, team_grouping_zones__maxRadius)

    assume refMoveTrace = team_grouping_zones__moveTracing[zone_idx]
    var moveDelta = float2()
    if !new_zone
      let MOVE_DELTA_DIST = 5.0
      moveDelta = refMoveTrace.xy
      if length_sq(moveDelta) > square(MOVE_DELTA_DIST)
        moveDelta = normalize(moveDelta) * MOVE_DELTA_DIST

    let areaId = team_grouping_zones__commonData[zone_idx].x
    let areaWeight1 = team_grouping_zones__mainWeight
    let areaWeight2 = team_grouping_zones__edgeWeight
    let areaHt = zoneHeights.y - zoneHeights.x
    let areaRadHt = float2(zoneRad, areaHt * 0.5)
    let areaPos = float3(zonePos.x + moveDelta.x, zoneHeights.x + areaHt * 0.5, zonePos.y + moveDelta.y)
    let areaMask = uint(team_nav_grouping_zones_usage_mask(team__id, zone_idx))

    assume refLastPosRad = team_grouping_zones__lastPosRads[zone_idx]
    assume refLastHeights = team_grouping_zones__lastHeights[zone_idx]

    let updatedPosRad = float4(areaPos.x, 0.0, areaPos.z, zoneRad)
    if new_zone
      refMoveTrace = float4(0.0, 0.0, zonePos.x, zonePos.y)
    else
      let dh1 = abs(refLastHeights.x - zoneHeights.x)
      let dh2 = abs(refLastHeights.y - zoneHeights.y)
      let MIN_SAME_HEIGHT = 3.5
      if dh1 < MIN_SAME_HEIGHT && dh2 < MIN_SAME_HEIGHT
        let MIN_UPDATE_DIST = 3.5
        if distance_sq(zonePos.xy, refMoveTrace.zw) < square(MIN_UPDATE_DIST)
          let MIN_UPDATE_DRAD = 3.5
          if abs(refLastPosRad.w - updatedPosRad.w) < MIN_UPDATE_DRAD
            return

    walker_custom_nav_areaUpdateFadingCylinder(walker_custom_nav, areaId, areaPos, areaRadHt, areaWeight1, areaWeight2, -1.f, -1.f, areaMask, true)
    walker_custom_nav_setAreaUserTagData(walker_custom_nav, areaId, CUSTOMNAV_TAG_GROUPING, zone_idx)

    refLastPosRad = updatedPosRad
    refLastHeights = zoneHeights

    if !new_zone
      refMoveTrace.x = zonePos.x - refMoveTrace.z
      refMoveTrace.y = zonePos.y - refMoveTrace.w
      refMoveTrace.z = zonePos.x
      refMoveTrace.w = zonePos.y


def private free_grouping_zone_member_iter(var zone_data : int3&; var idx : int&; prev_idx : int; next_idx : int; var nexts : IntList&; var frees : IntList&)
  frees |> push(idx)
  if prev_idx < 0
    zone_data.z = next_idx
  else
    nexts[prev_idx] = next_idx
  idx = prev_idx
  zone_data.y -= 1

[es(tag=server, no_order)]
def team_grouping_zones_update_zones(info : ParallelUpdateFrameDelayed;
                                     eid aka team_eid : EntityId;
                                     team__id : int;
                                     var walker_custom_nav : CustomNav&;
                                     team_grouping__numZones : int;
                                     team_grouping__tickZones : int;
                                     team_grouping_zones__kickRadius : float;
                                     team_grouping_zones__notKickDist : float;
                                     var team_grouping_zones__freeList : IntList&;
                                     var team_grouping_zones__commonData : IPoint3List&;
                                     var team_grouping_members__next : IntList&;
                                     team_grouping_members__eids : EidList;
                                     var team_grouping_members__free : IntList&;
                                     var team_grouping_zones__nextIdx : int&;
                                     var team_grouping__nextTimeCheckZones : float&;
                                     team_grouping__checkDeltaTime : float)
  let curTime = get_sync_time()
  if curTime < team_grouping__nextTimeCheckZones
    return
  team_grouping__nextTimeCheckZones = curTime + team_grouping__checkDeltaTime

  for _ in range(team_grouping__tickZones)
    let zoneIdx = team_grouping_zones__nextIdx
    team_grouping_zones__nextIdx = (zoneIdx + 1) % team_grouping__numZones

    assume zoneData = team_grouping_zones__commonData[zoneIdx]
    assume refZoneCount = zoneData.y
    if refZoneCount <= 0
      continue

    var zonePos = float2()

    var positions : array<float3>
    positions |> reserve(refZoneCount)

    var prevMemberIdx = -1
    var memberIdx = zoneData.z
    for _i in range(refZoneCount)
      if memberIdx < 0
        break
      let memberEid = team_grouping_members__eids[memberIdx]
      let nextMemberIdx = team_grouping_members__next[memberIdx]
      var gotMember = false
      query(memberEid) <| $ [es] (transform : float3x4;
                                  team : int; isAlive : bool;
                                  var human_grouping__team : int&;
                                  var human_grouping__zone : int&)
        gotMember = true
        if human_grouping__team != team__id || team != team__id || !isAlive
          
          if human_grouping__team == team__id
            human_grouping__team = -1
            human_grouping__zone = -1
          free_grouping_zone_member_iter(zoneData, memberIdx, prevMemberIdx, nextMemberIdx, team_grouping_members__next, team_grouping_members__free)
          return

        let pos = transform[3]
        positions |> push(pos)
        zonePos.x += pos.x
        zonePos.y += pos.z
      if !gotMember
        error("MEMBER {memberIdx} eid={memberEid} EXCLUDED FROM GROUP {zoneIdx} OF TEAM {team__id} ~ gotMember FALSE")
        free_grouping_zone_member_iter(zoneData, memberIdx, prevMemberIdx, nextMemberIdx, team_grouping_members__next, team_grouping_members__free)
      prevMemberIdx = memberIdx
      memberIdx = nextMemberIdx

    if refZoneCount <= 0
      walker_custom_nav_areaRemove(walker_custom_nav, zoneData.x)
      team_grouping_zones__freeList |> push(zoneIdx)
      continue

    let divCoef = safeinv(float(length(positions)))
    zonePos.x *= divCoef
    zonePos.y *= divCoef

    prevMemberIdx = -1
    memberIdx = zoneData.z
    for _i in range(refZoneCount)
      if memberIdx < 0
        break
      let memberEid = team_grouping_members__eids[memberIdx]
      let nextMemberIdx = team_grouping_members__next[memberIdx]
      query(memberEid) <| $ [es] (transform : float3x4;
                                  var human_grouping__team : int&;
                                  var human_grouping__zone : int&)
        let pos = transform[3]
        var memberTooFar = false
        if distance_sq(pos.xz, zonePos) > square(team_grouping_zones__kickRadius)
          memberTooFar = true
          for otherPos in positions
            if pos != otherPos && distance_sq(pos, otherPos) < square(team_grouping_zones__notKickDist)
              memberTooFar = false
              break
        if memberTooFar
          
          if human_grouping__team == team__id
            human_grouping__team = -1
            human_grouping__zone = -1
          free_grouping_zone_member_iter(zoneData, memberIdx, prevMemberIdx, nextMemberIdx, team_grouping_members__next, team_grouping_members__free)
      prevMemberIdx = memberIdx
      memberIdx = nextMemberIdx

    if refZoneCount <= 0
      walker_custom_nav_areaRemove(walker_custom_nav, zoneData.x)
      team_grouping_zones__freeList |> push(zoneIdx)
      continue

    team_grouping_zone_update_custom_nav(team_eid, zoneIdx, false)
