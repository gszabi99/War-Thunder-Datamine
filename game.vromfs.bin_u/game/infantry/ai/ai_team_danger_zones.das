require ecs
require math.base
require DagorDebug3D
require DagorSystem
require DagorMath
require DagorRandom
require Unit
require vehicle
require Weapon
require walkerai
require DngWalkerai
require Dacoll
require pathfinder
require %appGame.infantry.es.team_common
require %appGame.infantry.es.vehicle_turrets_common
require %game.utils.utils_common
require %game.events


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
                               var turret_danger_zones__areasData  : IntList&;
                               var turret_danger_zones__areasTime : FloatList&;
                               var turret_danger_zones__areasPosition : Point3List&)
  if info.curTime < turret_danger_zones__lastCheckTime + turret_danger_zones__checkDeltaTime
    return
  turret_danger_zones__lastCheckTime = info.curTime

  var vehicleEid = INVALID_ENTITY_ID
  while vehicleEid == INVALID_ENTITY_ID && !empty(turret_danger_zones__vehicleList)
    turret_danger_zones__currentVehicleIdx = (turret_danger_zones__currentVehicleIdx) % length(turret_danger_zones__vehicleList)
    let checkEid = turret_danger_zones__vehicleList[turret_danger_zones__currentVehicleIdx]
    query(checkEid) <| $ [es] (unit__ref : UnitRef)
      let unit = unit__ref.unit
      if unit != null && unit.isAlive
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
        for idx, existingAreaPos in iter_range(turret_danger_zones__areasPosition), turret_danger_zones__areasPosition
          if distance_sq(areaPos, existingAreaPos) < square(areaRadius.x)
            areaIdx = idx
            areaId = turret_danger_zones__areasData[idx]
            areaPos = existingAreaPos
            break
        if areaId >= 0
          turret_danger_zones__areasData |> erase(areaIdx)
          turret_danger_zones__areasTime |> erase(areaIdx)
          turret_danger_zones__areasPosition |> erase(areaIdx)
        areaId = areaId < 0 ? walker_agent_nav_allocAreaId() : areaId
        turret_danger_zones__areasData |> push(areaId)
        turret_danger_zones__areasTime |> push(info.curTime + areaDuration)
        turret_danger_zones__areasPosition |> push(areaPos)
        walker_custom_nav_areaUpdateFadingCylinder(walker_custom_nav, areaId, areaPos, areaRadius, areaWeightCenter, areaWeightSide,
                                             info.curTime + areaFadeTimeStart, info.curTime + areaDuration, true)
        query() <| $ [es] (var turret_danger_zones__areasDebugData : Point4List&;
                           var turret_danger_zones__areasDebugTimes : Point2List&)
          draw_debug_line_buffered(turretPos, turretPos + randDir * dist, E3DCOLOR(0xFF0006FF), 300)
          turret_danger_zones__areasDebugData |> push(float4(areaPos, areaRadius.x))
          turret_danger_zones__areasDebugTimes |> push(float2(info.curTime + areaFadeTimeStart, info.curTime + areaDuration))
      return true

  turret_danger_zones__currentVehicleIdx += 1


[es(tag=server, no_order)]
def ai_vehicle_danger_zones_fading(info : ParallelUpdateFrameDelayed;
                                   turret_danger_zones__checkFadingDeltaTime : float;
                                   var walker_custom_nav : CustomNav&;
                                   var turret_danger_zones__lastCheckFadingTime : float&;
                                   var turret_danger_zones__areasData  : IntList&;
                                   var turret_danger_zones__areasTime : FloatList&;
                                   var turret_danger_zones__areasPosition : Point3List&)
  let curTime = info.curTime
  if curTime < turret_danger_zones__lastCheckFadingTime + turret_danger_zones__checkFadingDeltaTime
    return
  turret_danger_zones__lastCheckFadingTime = curTime

  walker_custom_nav_updateFadeSyncTime(curTime)

  var removeCount = 0
  for i in iter_range(turret_danger_zones__areasData)
    if curTime > turret_danger_zones__areasTime[i]
      let areaId = turret_danger_zones__areasData[i]
      walker_custom_nav_areaRemove(walker_custom_nav, areaId)
      ++removeCount
    else
      break

  if removeCount > 0
    turret_danger_zones__areasData |> erase(0, removeCount)
    turret_danger_zones__areasTime |> erase(0, removeCount)
    turret_danger_zones__areasPosition |> erase(0, removeCount)
