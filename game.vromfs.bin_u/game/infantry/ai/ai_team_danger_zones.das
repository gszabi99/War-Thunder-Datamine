require ecs
require app
require math.base
require DagorDebug3D
require DagorSystem
require DagorMath
require DagorRandom
require Unit
require IGroundModel
require vehicle
require Weapon
require walkerai
require DngWalkerai
require Dacoll
require pathfinder
require %appGame.wt_events
require %appGame.infantry.es.team_common
require %appGame.infantry.es.vehicle_turrets_common
require %appGame.infantry.ai.walker_vehicles_danger_common
require %appGame.infantry.ai.ai_team_danger_zones_common
require %game.utils.utils_common
require %game.events

[es(tag=server, on_appear)]
def team_danger_zones_init(evt : Event;
                           var turret_danger_zones__list : int3&;
                           var turret_danger_zones__prevNext : IPoint2List&;
                           var turret_danger_zones__areasData  : IntList&;
                           var turret_danger_zones__areasTime : FloatList&;
                           var death_danger_zones__list : int3&;
                           var death_danger_zones__prevNext : IPoint2List&;
                           var death_danger_zones__areasData  : IntList&;
                           var death_danger_zones__areasTime : FloatList&)
  let TURRET_DANGER_ZONES_INIT_CAPACITY = 64
  let DEATH_DANGER_ZONES_INIT_CAPACITY = 64
  danger_zones_list_init(TURRET_DANGER_ZONES_INIT_CAPACITY, turret_danger_zones__list, turret_danger_zones__prevNext,
                         turret_danger_zones__areasData, turret_danger_zones__areasTime)
  danger_zones_list_init(DEATH_DANGER_ZONES_INIT_CAPACITY, death_danger_zones__list, death_danger_zones__prevNext,
                         death_danger_zones__areasData, death_danger_zones__areasTime)

[es(tag=server, on_appear)]
def danger_vehicle_appear_es(evt : Event;
                             team aka vehicle_team : int;
                             eid : EntityId;
                             unit__ref : UnitRef;
                             unit_tag__tank : Tag const?)
  let unit = unit__ref.unit
  var isDanger = false
  if unit != null && unit.isVehicle && unit_tag__tank != null
    let wc = unit.weap
    if length(wc.turret) > 0
      isDanger = true

  if isDanger
    query() <| $ [es] (team__id : int;
                       var turret_danger_zones__vehicleList : EidList&;
                       var turret_danger_zones__vehicleMainAreaList : IntList&)
      if team__id == vehicle_team
        return
      turret_danger_zones__vehicleList |> push(eid)
      turret_danger_zones__vehicleMainAreaList |> push(-1)

[es(tag=server, no_order)]
def trace_vehicle_danger_zones(info : ParallelUpdateFrameDelayed;
                               turret_danger_zones__checkDeltaTime : float;
                               turret_danger_zones__vehicleMainAreaRadius : float;
                               turret_danger_zones__frustumAngles : float2 = float2(60.0, 20.0);
                               turret_danger_zones__shootDistance : float = 100.0;
                               turret_danger_zones__areaHeight : float = 5.0;
                               turret_danger_zones__areaWeightCenter : float = 10000.0;
                               turret_danger_zones__areaWeightSide : float = 1000.0;
                               turret_danger_zones__areaDuration : float = 10.0;
                               turret_danger_zones__areaFadeTimeStart : float = 7.0;
                               turret_danger_zones__areaCloseRadius : float = 4.0;
                               turret_danger_zones__areaFarRadius : float = 10.0;
                               var walker_custom_nav : CustomNav&;
                               var turret_danger_zones__currentVehicleIdx : int&;
                               var turret_danger_zones__lastCheckTime : float&;
                               var turret_danger_zones__vehicleList : EidList&;
                               var turret_danger_zones__vehicleMainAreaList : IntList&;
                               var turret_danger_zones__list : int3&;
                               var turret_danger_zones__prevNext : IPoint2List&;
                               var turret_danger_zones__areasData  : IntList&;
                               var turret_danger_zones__areasTime : FloatList&)
  if info.curTime < turret_danger_zones__lastCheckTime + turret_danger_zones__checkDeltaTime
    return
  turret_danger_zones__lastCheckTime = info.curTime

  var vehicleEid = INVALID_ENTITY_ID
  while vehicleEid == INVALID_ENTITY_ID && !empty(turret_danger_zones__vehicleList)
    turret_danger_zones__currentVehicleIdx = (turret_danger_zones__currentVehicleIdx) % length(turret_danger_zones__vehicleList)
    let checkEid = turret_danger_zones__vehicleList[turret_danger_zones__currentVehicleIdx]
    query(checkEid) <| $ [es] (unit__ref : UnitRef)
      let unit = unit__ref.unit
      if unit == null || !unit.isAlive
        return
      if is_vehicle_combat_inactive(unit)
        return
      vehicleEid = checkEid
    if vehicleEid == INVALID_ENTITY_ID
      turret_danger_zones__vehicleList |> erase(turret_danger_zones__currentVehicleIdx)
      turret_danger_zones__vehicleMainAreaList |> erase(turret_danger_zones__currentVehicleIdx)

  query(vehicleEid) <| $ [es] (transform : float3x4; unit__ref : UnitRef)
    let unit = unit__ref.unit
    let wc = unit.weap
    if length(wc.turret) == 0
      return

    let frustumAngles = turret_danger_zones__frustumAngles
    let shootDistance = turret_danger_zones__shootDistance
    let areaHeight = turret_danger_zones__areaHeight
    let areaWeightCenter = turret_danger_zones__areaWeightCenter
    let areaWeightSide = turret_danger_zones__areaWeightSide
    let areaDuration = turret_danger_zones__areaDuration
    let areaFadeTimeStart = turret_danger_zones__areaFadeTimeStart
    let areaCloseRadius = turret_danger_zones__areaCloseRadius
    let areaFarRadius = turret_danger_zones__areaFarRadius

    assume vehicleMainArea = turret_danger_zones__vehicleMainAreaList[turret_danger_zones__currentVehicleIdx]
    let mainAreaDistThresholdSq = square(turret_danger_zones__vehicleMainAreaRadius * 0.5f)
    let isNewMainArea = vehicleMainArea < 0
    var areaCenter = float3()
    if isNewMainArea
      vehicleMainArea = walker_agent_nav_allocAreaId()
    else
      let areaBBox = walker_custom_nav_getAreaBBox(walker_custom_nav, vehicleMainArea)
      areaCenter = areaBBox.center
    if isNewMainArea || distance_sq(transform[3], areaCenter) > mainAreaDistThresholdSq
      let areaRadius = float2(turret_danger_zones__vehicleMainAreaRadius, areaHeight)
      walker_custom_nav_areaUpdateCylinder(walker_custom_nav, vehicleMainArea, transform[3], areaRadius, areaWeightCenter, areaWeightSide, true)

    find_turret_weapon(wc, int(WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY)) <| $(weapon)
      var gunTm : float3x4
      weapon_calcShootTm(weapon, unit.unitTm, gunTm)
      let turretPos = gunTm[3]
      let turretDir = gunTm[0]
      let hRad = deg_to_rad(rnd_float(-frustumAngles.x, frustumAngles.x))
      let vRad = deg_to_rad(rnd_float(-frustumAngles.y, frustumAngles.y))
      let forward = normalize(turretDir)
      let up = float3(0.f, 1.f, 0.f)
      let right = abs(forward.y) < 0.9 ? normalize(cross(forward, up)) : normalize(cross(forward, float3(1.f, 0.f, 0.f)))
      let realUp = cross(right, forward)
      var rotTm = float3x4()
      rotTm[0] = right
      rotTm[1] = realUp
      rotTm[2] = forward
      let dirLocal = normalize(float3(sin(hRad) * cos(vRad), sin(vRad), cos(hRad) * cos(vRad)))
      let randDir = normalize(rotTm * dirLocal)
      var hitNorm : float3
      var dist = shootDistance
      if traceray_normalized(turretPos, randDir, dist, hitNorm, ETF_ALL)
        let areaRadius = float2(cvt(dist, 0.0, shootDistance, areaCloseRadius, areaFarRadius), areaHeight)
        var areaPos = turretPos + randDir * dist
        var areaIdx = -1
        var areaId = -1
        walker_custom_nav_getNearCylAreasByUserTag(walker_custom_nav, areaPos, areaRadius.x, CUSTOMNAV_TAG_TURRETDANGER) <| $(area_id, area_data)
          let nearAreaPosRadius = walker_custom_nav_getCylAreaBBoxPosRadius(walker_custom_nav, area_id)
          if distance_sq(areaPos, nearAreaPosRadius.xyz) < square(nearAreaPosRadius.w)
            areaId = area_id
            areaIdx = area_data
            areaPos = nearAreaPosRadius.xyz
            return true
          return false
        if areaId >= 0
          danger_zones_list_remove(areaIdx, turret_danger_zones__list, turret_danger_zones__prevNext)
        areaId = areaId < 0 ? walker_agent_nav_allocAreaId() : areaId
        areaIdx = danger_zones_list_insertSorted(areaId, info.curTime + areaDuration,
                                       turret_danger_zones__list,
                                       turret_danger_zones__prevNext,
                                       turret_danger_zones__areasData,
                                       turret_danger_zones__areasTime)
        walker_custom_nav_areaUpdateFadingCylinder(walker_custom_nav, areaId, areaPos, areaRadius, areaWeightCenter, areaWeightSide,
                                                   info.curTime + areaFadeTimeStart, info.curTime + areaDuration, true)
        walker_custom_nav_setAreaUserTagData(walker_custom_nav, areaId, CUSTOMNAV_TAG_TURRETDANGER, areaIdx)
      return true

  turret_danger_zones__currentVehicleIdx += 1


def private remove_expired_danger_zones(cur_time : float;
                                        areas_data : IntList;
                                        areas_time : FloatList;
                                        var areas_list : int3&;
                                        var areas_prev_next : IPoint2List&;
                                        var walker_custom_nav : CustomNav&)
  var cur = areas_list.x
  while cur != -1 && cur_time > areas_time[cur]
    let areaId = areas_data[cur]
    walker_custom_nav_areaRemove(walker_custom_nav, areaId)
    cur = danger_zones_list_remove(cur, areas_list, areas_prev_next)

[es(tag=server, no_order)]
def ai_vehicle_danger_zones_fading(info : ParallelUpdateFrameDelayed;
                                   team_danger_zones__checkFadingDeltaTime : float;
                                   turret_danger_zones__areasData  : IntList;
                                   turret_danger_zones__areasTime : FloatList;
                                   death_danger_zones__areasData : IntList;
                                   death_danger_zones__areasTime : FloatList;
                                   var walker_custom_nav : CustomNav&;
                                   var team_danger_zones__lastCheckFadingTime : float&;
                                   var turret_danger_zones__list : int3&;
                                   var turret_danger_zones__prevNext : IPoint2List&;
                                   var death_danger_zones__list : int3&;
                                   var death_danger_zones__prevNext : IPoint2List&)
  let curTime = info.curTime
  if curTime < team_danger_zones__lastCheckFadingTime + team_danger_zones__checkFadingDeltaTime
    return
  team_danger_zones__lastCheckFadingTime = curTime

  walker_custom_nav_updateFadeSyncTime(curTime)

  remove_expired_danger_zones(curTime, turret_danger_zones__areasData, turret_danger_zones__areasTime,
                              turret_danger_zones__list, turret_danger_zones__prevNext, walker_custom_nav)

  remove_expired_danger_zones(curTime, death_danger_zones__areasData, death_danger_zones__areasTime,
                              death_danger_zones__list, death_danger_zones__prevNext, walker_custom_nav)


[es(tag=server, no_order, REQUIRE=human)]
def ai_death_danger_zones_on_soldier_die(evt : EventEntityDied;
                                         transform : float3x4)
  query() <| $ [es] (team__id : int;
                     death_danger_zones__areaBaseDuration : float = 15.0;
                     death_danger_zones__areaMaxDuration : float = 90.0;
                     death_danger_zones__areaBaseRadius : float = 4.0;
                     death_danger_zones__areaMaxRadius : float = 12.0;
                     death_danger_zones__areaBaseWeight : float = 50.0;
                     death_danger_zones__areaMaxWeight : float = 500.0;
                     death_danger_zones__areaMergeCoef : float = 1.5;
                     death_danger_zones__areaSideWeightCoef : float = 0.8;
                     death_danger_zones__areaHeight : float = 3.0;
                     var walker_custom_nav : CustomNav&;
                     var death_danger_zones__list : int3&;
                     var death_danger_zones__areasData : IntList&;
                     var death_danger_zones__areasTime : FloatList&;
                     var death_danger_zones__prevNext : IPoint2List&)
    if team__id != evt.victimTeam
      return

    let curTime = get_sync_time()
    var areaId = -1
    var areaPos = transform[3]
    var areaDuration = death_danger_zones__areaBaseDuration
    var areaRadius = death_danger_zones__areaBaseRadius
    var totalAreaWeight = death_danger_zones__areaBaseWeight * square(death_danger_zones__areaBaseRadius)

    let MAX_CHECK_MERGE_COUNT = 3
    var checkMergeCount = 0
    var isCheckMerge = true
    var mergeAreasData : array<int2>
    while isCheckMerge && checkMergeCount < MAX_CHECK_MERGE_COUNT
      walker_custom_nav_getNearCylAreasByUserTag(walker_custom_nav, areaPos, areaRadius, CUSTOMNAV_TAG_DEATH) <| $(area_id, area_data)
        let nearAreaPosRadius = walker_custom_nav_getCylAreaBBoxPosRadius(walker_custom_nav, area_id)
        let nearAreaPos = nearAreaPosRadius.xyz
        let nearAreaRadius = nearAreaPosRadius.w
        let mergeRadiusSq = square(max(nearAreaRadius, areaRadius))
        if distance_sq(areaPos, nearAreaPos) < mergeRadiusSq
          let nearAreaWeight = walker_custom_nav_getAreaCurrentWeight(walker_custom_nav, area_id).x
          let nearAreaDuration = death_danger_zones__areasTime[area_data] - curTime
          totalAreaWeight += nearAreaWeight * square(nearAreaRadius) * death_danger_zones__areaMergeCoef

          mergeAreasData |> push(int2(area_id, area_data))
          let dist = distance(areaPos, nearAreaPos)

          if dist + min(nearAreaRadius, areaRadius) <= max(nearAreaRadius, areaRadius)
            if nearAreaRadius > areaRadius
              areaPos = nearAreaPos
              areaRadius = nearAreaRadius
            areaDuration = min(areaDuration + nearAreaDuration, death_danger_zones__areaMaxDuration)
            return false

          let dir = (nearAreaPos - areaPos) / dist
          areaPos = areaPos + dir * ((dist + nearAreaRadius - areaRadius) * 0.5f)
          areaRadius = min((dist + nearAreaRadius + areaRadius) * 0.5f, death_danger_zones__areaMaxRadius)
          areaDuration = min(areaDuration + nearAreaDuration, death_danger_zones__areaMaxDuration)
        return false

      for mergeData in mergeAreasData
        walker_custom_nav_areaRemove(walker_custom_nav, mergeData.x)
        danger_zones_list_remove(mergeData.y, death_danger_zones__list, death_danger_zones__prevNext)

      checkMergeCount += 1
      if mergeAreasData |> empty()
        isCheckMerge = false
      mergeAreasData |> clear()

    areaId = walker_agent_nav_allocAreaId()
    let areaIdx = danger_zones_list_insertSorted(areaId, curTime + areaDuration,
                                                 death_danger_zones__list,
                                                 death_danger_zones__prevNext,
                                                 death_danger_zones__areasData,
                                                 death_danger_zones__areasTime)

    let areaWeight = min(totalAreaWeight / square(areaRadius), death_danger_zones__areaMaxWeight)
    let sideWeight = areaWeight * death_danger_zones__areaSideWeightCoef
    let areaRadiusHeight = float2(areaRadius, death_danger_zones__areaHeight)
    walker_custom_nav_areaUpdateFadingCylinder(walker_custom_nav, areaId, areaPos, areaRadiusHeight, areaWeight, sideWeight,
                                               curTime, curTime + areaDuration, true)
    walker_custom_nav_setAreaUserTagData(walker_custom_nav, areaId, CUSTOMNAV_TAG_DEATH, areaIdx)
