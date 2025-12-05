module walker_vehicles_danger_common shared

require DagorMath
require DagorRandom
require DagorSystem
require ecs
require math.base
require pathfinder
require %appGame.infantry.es.team_common
require %appGame.infantry.es.vehicle_turrets_common
require %game.utils.utils_common
require vehicle
require Weapon
require Dacoll
require Unit
require Grid
require DngWalkerai

struct VehicleDangerZoneData
  center : float2
  radiusDir : float2
  maxDeviationAngle : float

struct VehicleDangerZoneParams
  maxSpeed : float = 40.0
  minSpeed : float = 1.0
  effectiveSpeedExp : float = 0.5
  maxPath : float = 40.0
  maxDeviationAngle : float = PI / 8.0
  drivingTime : float = 2.0

struct TurretDangerZoneData
  center : float3
  radiusDir : float3
  maxDeviationAngle : float

struct TurretDangerZoneParams
  maxDeviationAngle : float = PI / 8.0
  maxShootDistance : float = 50.0

enum DangerEscapeType
  ESCAPE_HIDE = 0
  ESCAPE_RUN = 1

struct DangerEscapeData
  escapeType : DangerEscapeType
  pos : float3



[generic]
def private is_point_in_sector(pos : auto(TT);
                               center : TT;
                               radius_dir : TT;
                               angle : float)
  let diff = pos - center
  let distSq = length_sq(diff)
  let radiusSq = length_sq(radius_dir)
  if distSq > radiusSq
    return false
  if angle > PI - 0.001 
    return true
  let deviationAngle = acos(safediv(dot(diff, radius_dir), sqrt(distSq * radiusSq)))
  return deviationAngle <= angle


def calc_vehicle_driving_zone_params(vehicle_pos : float2;
                                     vehicle_vel : float2;
                                     vehicle_radius : float;
                                     vehicle_params : VehicleDangerZoneParams)
  let speed = length(vehicle_vel)
  if speed < vehicle_params.minSpeed
    return VehicleDangerZoneData(center = vehicle_pos, radiusDir = float2(vehicle_radius, 0), maxDeviationAngle = PI)

  let dir = vehicle_vel / speed
  let offsetLen = vehicle_radius / sin(vehicle_params.maxDeviationAngle)
  let center = vehicle_pos - dir * offsetLen

  
  
  
  let effectiveSpeed = vehicle_params.maxSpeed * pow(speed / vehicle_params.maxSpeed, vehicle_params.effectiveSpeedExp)
  let effectivePath = min(effectiveSpeed * vehicle_params.drivingTime, vehicle_params.maxPath)
  let radiusDir = dir * (offsetLen + effectivePath + vehicle_radius)
  return VehicleDangerZoneData(center = center, radiusDir = radiusDir, maxDeviationAngle = vehicle_params.maxDeviationAngle)


def calc_turret_danger_max_len(gunTm : float3x4; forwardDist : float2; sideDist : float2)
  var maxLen = -1.0f
  let numSteps = 1
  for i in range(-numSteps, numSteps + 1)
    let absI = int(abs(float(i)))
    let rowEven = (absI % 2) == 0
    for j in range(absI - numSteps, numSteps + 1 - absI)
      let absJ = int(abs(float(j)))
      let colEven = (absJ % 2) == 0
      if rowEven == colEven
        let startPt = gunTm[3]
        let dir = (gunTm[0] * forwardDist.y +
                   gunTm[2] * sideDist.x * (float(j) / float(numSteps)) +
                   gunTm[1] * sideDist.y * (float(i) / float(numSteps)))
        var len = length(dir)
        if len > VERY_SMALL_NUMBER
          let dirN = dir / len
          var norm : float3
          traceray_normalized(startPt, dirN, len, norm)
          maxLen = max(maxLen, dot(dirN, gunTm[0]) * len)
  return maxLen


def gather_danger_vehicle_and_turret_data(agent_pos : float3;
                                          agent_team : int;
                                          vehicle_params : VehicleDangerZoneParams;
                                          turret_params : TurretDangerZoneParams;
                                          var vehicle_data_arr : array<VehicleDangerZoneData>&;
                                          var turret_data_arr : array<TurretDangerZoneData>&)
  let checkDistance = vehicle_params.maxSpeed * vehicle_params.drivingTime
  let maxCheckVehicles = 3
  var checkedVehicles = 0
  for_each_entity_in_grid(ecs_hash("vehicles"), BSphere3(agent_pos, checkDistance), GridEntCheck BOUNDING) <| $(vehicle_eid : EntityId)
    query(vehicle_eid) <| $ [es(REQUIRE_NOT=(airplane, deadEntity))] (transform : float3x4;
                                                                      unit__ref : UnitRef;
                                                                      team aka vehicle_team : int;
                                                                      vehicle_net_phys : VehiclePhysActor;
                                                                      turret_avoid_nav__forwardDist = float2(-10.0, 80.0);
                                                                      turret_avoid_nav__sideDist = float2(10.0, 6.0))
      if is_teams_friendly(agent_team, vehicle_team)
        return
      let unit = unit__ref.unit
      if unit == null || !unit.isAlive
        return

      if get_crewman_alive_count(unit) <= 0
        return

      let unitBbox = unit.boundingBox.width
      let vehiclePos = transform[3].xz
      let vehicleVel = float3(vehicle_net_phys.phys.currentState.velocity).xz 
      let vehicleRadiusMult = 0.5
      let vehicleRadius = sqrt(square(unitBbox.x) + square(unitBbox.z)) * vehicleRadiusMult
      let vehicleData = calc_vehicle_driving_zone_params(vehiclePos, vehicleVel, vehicleRadius, vehicle_params)
      push(vehicle_data_arr, vehicleData)

      checkedVehicles++

      let wc = unit.weap
      if length(wc.turret) == 0
        return
      iterate_turret_weapons(wc, int(WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY)) <| $(weapon)
        var gunTm : float3x4
        weapon_calcShootTm(weapon, unit.unitTm, gunTm)
        let turretDistance = calc_turret_danger_max_len(gunTm, turret_avoid_nav__forwardDist, turret_avoid_nav__sideDist)
        let shootDistance = min(turretDistance, turret_params.maxShootDistance)
        if shootDistance < 0.0
          return
        let turretPos = gunTm[3]
        let turretDir = gunTm[0]
        
        let turretData = TurretDangerZoneData(center = turretPos, radiusDir = shootDistance * turretDir, maxDeviationAngle = turret_params.maxDeviationAngle)
        push(turret_data_arr, turretData)

    if checkedVehicles >= maxCheckVehicles
      return


def is_agent_in_vehicle_danger_zones(agent_pos : float3;
                                     vehicleDatas : array<VehicleDangerZoneData>;
                                     turretDatas : array<TurretDangerZoneData>)
  for data in turretDatas
    if is_point_in_sector(agent_pos, data.center, data.radiusDir, data.maxDeviationAngle)
      return true
  for data in vehicleDatas
    if is_point_in_sector(agent_pos.xz, data.center, data.radiusDir, data.maxDeviationAngle)
      return true
  return false


def is_agent_in_vehicle_danger_zones(agent_pos : float3;
                                     vehicleDatas : array<VehicleDangerZoneData>)
  for data in vehicleDatas
    if is_point_in_sector(agent_pos.xz, data.center, data.radiusDir, data.maxDeviationAngle)
      return true
  return false


def vehicle_danger_zone_gradient(pos : float2; zone_data : VehicleDangerZoneData; mult : float = 500.0)
  let radius = length(zone_data.radiusDir)
  if radius < 0.001
    return float2()
  let diff = pos - zone_data.center
  let dist = length(diff)
  if dist < 0.001 || dist > radius
    return float2()

  if zone_data.maxDeviationAngle > PI - 0.001
    return 2.0 * (1.0 - 1.1 * radius / dist) * float2(diff.x, diff.y)

  let X = zone_data.radiusDir / radius
  let Y = float2(-X.y, X.x)
  let diffRel = float2(dot(diff, X), dot(diff, Y))
  assume x = diffRel.x
  assume y = diffRel.y

  let angle = atan2(y, x)
  if abs(angle) > zone_data.maxDeviationAngle
    return float2()

  let XX = diff / dist
  let YY = float2(-XX.y, XX.x)
  let ang = acos(safediv(dot(diff, zone_data.radiusDir), dist * radius))
  let sgn = sign(diff.x * zone_data.radiusDir.y - diff.y * zone_data.radiusDir.x)
  let gradRel = mult * (1.1 * zone_data.maxDeviationAngle - ang) * sgn * square(ang) * YY
  return gradRel


def turret_danger_zone_gradient(pos : float3; zone_data : TurretDangerZoneData)
  let dir = normalize(pos - zone_data.center)
  let radiusDirNorm = normalize(zone_data.radiusDir)
  if dot(dir, radiusDirNorm) < cos(zone_data.maxDeviationAngle)
    return float2()

  let dir2D = float2(sqrt(dot(dir.xz, dir.xz)), dir.y)
  let radiusDir2D = normalize(float2(sqrt(dot(zone_data.radiusDir.xz, zone_data.radiusDir.xz)), zone_data.radiusDir.y))
  let mult = cvt(dot(dir2D, radiusDir2D), cos(zone_data.maxDeviationAngle), 1.0, 100.0, 500.0)
  let centerXZ = zone_data.center.xz
  let radiusDirXZ = normalize(zone_data.radiusDir.xz) * length(zone_data.radiusDir)
  let turretFlatData = VehicleDangerZoneData(center = centerXZ, radiusDir = radiusDirXZ, maxDeviationAngle = zone_data.maxDeviationAngle)
  return vehicle_danger_zone_gradient(pos.xz, turretFlatData, mult)


def total_danger_zone_gradient(pos : float3; vehicle_datas : array<VehicleDangerZoneData>; turret_datas : array<TurretDangerZoneData>)
  var res : float2
  for data in vehicle_datas
    res += vehicle_danger_zone_gradient(pos.xz, data)
  for data in turret_datas
    res += turret_danger_zone_gradient(pos, data)
  return res


def total_danger_zone_gradient(pos : float3; vehicle_datas : array<VehicleDangerZoneData>)
  var res : float2
  for data in vehicle_datas
    res += vehicle_danger_zone_gradient(pos.xz, data)
  return res


def find_safe_point_from_vehicles(agent_pos : float3;
                                  danger_pos : float3;
                                  wish_pos : float3;
                                  escape_radius : float;
                                  vehicle_datas : array<VehicleDangerZoneData>;
                                  turret_datas : array<TurretDangerZoneData>;
                                  var escape_type : DangerEscapeType&)
  let wishDir = wish_pos - danger_pos
  let wishDirNormalized = normalize(wishDir)
  let predictedDangerThreshold = 3.0
  let isPredictedDanger = length_sq(danger_pos - agent_pos) > predictedDangerThreshold
  let preferWishDir = wish_pos != float3() && length_sq(wishDir) > square(predictedDangerThreshold)

  var isMaxThreatTurret = false
  var maxThreatVehicleData : VehicleDangerZoneData
  for data in vehicle_datas
    if is_point_in_sector(danger_pos.xz, data.center, data.radiusDir, data.maxDeviationAngle)
      maxThreatVehicleData = data
  for data in turret_datas
    if is_point_in_sector(danger_pos, data.center, data.radiusDir, data.maxDeviationAngle)
      let turretFlatData = VehicleDangerZoneData(center = data.center.xz,
                                                 radiusDir = normalize(data.radiusDir.xz) * length(data.radiusDir),
                                                 maxDeviationAngle = data.maxDeviationAngle)
      maxThreatVehicleData = turretFlatData
      isMaxThreatTurret = true

  let vehicleDir = normalize(maxThreatVehicleData.radiusDir)
  let vehiclePerpLeftDir = float2(-vehicleDir.y, vehicleDir.x)
  var points : array<DangerEscapeData>
  if preferWishDir
    var canEscapeToWishDir = true
    if isPredictedDanger && !isMaxThreatTurret
      let safeDistThreshold = 3.0
      let agentSpeed = 2.0
      let agentToPosDist = length(danger_pos.xz - agent_pos.xz)
      let vehicleToPosDist = length(maxThreatVehicleData.center - danger_pos.xz)
      canEscapeToWishDir = safediv(agentToPosDist + safeDistThreshold, agentSpeed) < safediv(vehicleToPosDist, length(maxThreatVehicleData.radiusDir))
    if canEscapeToWishDir
      points |> push(DangerEscapeData(escapeType = DangerEscapeType.ESCAPE_RUN, pos = danger_pos + wishDirNormalized * escape_radius))
  if isPredictedDanger && !isMaxThreatTurret
    
    let allowedAngle = deg_to_rad(50.0)
    if abs(dot(vehiclePerpLeftDir, wishDirNormalized.xz)) > cos(allowedAngle)
      let fromVehicleDist = 4.0
      let sideDir = dot(wishDirNormalized.xz, vehiclePerpLeftDir) > 0.0 ? vehiclePerpLeftDir : -vehiclePerpLeftDir
      let safePosXZ = maxThreatVehicleData.center + (-vehicleDir + sideDir) * fromVehicleDist
      let safePos = float3(safePosXZ.x, danger_pos.y, safePosXZ.y)
      points |> push(DangerEscapeData(escapeType = DangerEscapeType.ESCAPE_RUN, pos = safePos))
  var preferredPerpDir : float2
  var preferredEscapeType : DangerEscapeType
  if preferWishDir
    preferredPerpDir = dot(wishDirNormalized.xz, vehiclePerpLeftDir) > 0.0 ? vehiclePerpLeftDir : -vehiclePerpLeftDir
    preferredEscapeType = DangerEscapeType.ESCAPE_RUN
  else
    preferredPerpDir = dot(agent_pos.xz - maxThreatVehicleData.center, vehiclePerpLeftDir) > 0.0 ? vehiclePerpLeftDir : -vehiclePerpLeftDir
    preferredEscapeType = DangerEscapeType.ESCAPE_HIDE
  points |> push(DangerEscapeData(escapeType = preferredEscapeType, pos = agent_pos + float3(preferredPerpDir.x, 0, preferredPerpDir.y) * escape_radius))
  points |> push(DangerEscapeData(escapeType = preferredEscapeType, pos = agent_pos - float3(preferredPerpDir.x, 0, preferredPerpDir.y) * escape_radius))
  if !isPredictedDanger && dot(agent_pos.xz - maxThreatVehicleData.center, vehicleDir) > 0.0
    points |> push(DangerEscapeData(escapeType = DangerEscapeType.ESCAPE_HIDE, pos = agent_pos + float3(vehicleDir.x, 0, vehicleDir.y) * escape_radius))

  for escapePoint in points
    var res = escapePoint.pos
    let gradientSteps = 5
    let gradientStepSize = 2.0
    if is_agent_in_vehicle_danger_zones(res, vehicle_datas, turret_datas)
      for _ in range(gradientSteps)
        let grad = -gradientStepSize * normalize(total_danger_zone_gradient(res, vehicle_datas, turret_datas))
        let gradPos = res + float3(grad.x, 0.0, grad.y)
        res = gradPos

      if is_agent_in_vehicle_danger_zones(res, vehicle_datas, turret_datas)
        continue

    let projExtents = float3(1.5, 5.0, 1.5)
    if !project_to_nearest_navmesh_point_avoid_obstacles(res, projExtents)
      continue

    let traceHeight = float3(0.0, 1.0, 0.0)
    let traceRadius = 0.2
    var queryOut = ShapeQueryOutput()
    let blocked = sphere_cast(agent_pos + traceHeight, res + traceHeight, traceRadius, queryOut)
    if blocked
      continue

    let extents = float3(0.1, 5.0, 0.1)
    let maxPathDist = 20.0
    var hasPath = false
    find_path(agent_pos, res, extents, 0.5, 1.0) <| $(path)
      let numPoints = length(path)
      if numPoints <= 1
        return
      var totalPathDist = 0.0
      for j in range(numPoints - 1)
        let pt1 = path[j]
        let pt2 = path[j + 1]
        let partPathDist = length(pt2 - pt1)
        totalPathDist += partPathDist
        if totalPathDist > maxPathDist
          return
      hasPath = true
    if !hasPath
      continue

    escape_type = escapePoint.escapeType
    return res

  return float3()
