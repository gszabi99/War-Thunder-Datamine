options gen2 = false

module avionics_common shared public

require %dasGameLibs.math.base
require %game.utils.utils_common

require DagorMath
require FlightControl
require FlightModelWrap
require GamePhys
require GuidanceLock
require hud
require math
require RadarHud
require Sensors
require strings
require Unit
require Weapon
require WTCamera

// ****************************************************************************
// ***  Util  *****************************************************************
// ****************************************************************************

[generic, hint(alwaysinline)]
def operator ==(i : int; e : CockpitSightMode | WeaponTriggerType)
  return i == int(e)

[hint(alwaysinline)]
def private safediv_point2(p1 : float2; p2 : float2) : float2
  return float2(safediv(p1.x, p2.x), safediv(p1.y, p2.y))

struct ScreenPos
  isScreenPosValid : bool
  screenPos      : float2

// ****************************************************************************
// ***  Flight  ***************************************************************
// ****************************************************************************

struct Visual
  quat  : quat
  vel   : float3
  pos   : float3
  euler : float3

def get_visual(at_time : double, hero : Unit const?) : Visual
  var visual : Visual
  visual.quat = hero.calcPosVelQuatAtTime(at_time, visual.pos, visual.vel, visual.quat)
  quat_to_euler(visual.quat, visual.euler.x, visual.euler.y, visual.euler.z)
  return visual

struct FlightPathMarker : ScreenPos

def get_flight_path_marker(vel_vec : float3;
                           world_to_screen : block<(world_pos : float3 const&; var screen_pos : float2&) : bool>;
                           ease_in_factor : float = 5.f) : FlightPathMarker
  var fpm : FlightPathMarker
  if vel_vec.length_sq() > ease_in_factor
    if world_to_screen |> invoke(vel_vec, fpm.screenPos)
      fpm.isScreenPosValid = true
  else
    if world_to_screen |> invoke(vel_vec, fpm.screenPos)
      fpm.screenPos *= vel_vec.length_sq() / ease_in_factor
      fpm.isScreenPosValid = true
  return fpm

def get_load_factor(local_accel_y : double) : float
  return float(local_accel_y) * safeinv(gravity()) + 1.f

// ****************************************************************************
// ***  Weapons  **************************************************************
// ****************************************************************************

def get_armed_status(fmw : FlightModelWrap const?) : bool
  return !(fmw.isOnGround || fmw.fm.currentAlt < fmw.minAltitudeForDropShells)

enum WeaponMode
  INVALID = 0
  AA_MIN
  AA_GUN_MIN
  AA_GUN_UNRANGED
  AA_GUN_RANGED
  AA_GUN_MAX
  AA_MISSILE
  AA_MAX
  AG_MIN
  AG_GUN
  AG_ROCKET
  AG_MISSILE
  AG_BOMB_CCRP
  AG_BOMB_CCIP
  AG_MAX

enum MasterMode
  INVALID = 0
  AA
  AG
  DGFT
  NAV

[generic, hint(alwaysinline)]
def operator >(a : WeaponMode, b : WeaponMode) : auto
  return int(a) > int(b)

[generic, hint(alwaysinline)]
def operator <(a : WeaponMode, b : WeaponMode) : auto
  return int(a) < int(b)

struct Guidance
  isActive     : bool
  guidanceType : GuidanceType
  lockState    : GuidanceLockState

def get_guidance(selected_wpn : Weapon const?) : Guidance
  var guidance : Guidance
  with guidance
    lockState = GuidanceLockState.RESULT_INVALID
    guidanceType = GuidanceType.TYPE_INVALID
    if selected_wpn != null
      guidanceType = get_weapon_guidance_type(selected_wpn)
      if selected_wpn.trigger_no == WeaponTriggerType.AAM_TRIGGER
        lockState = get_aam_guidance_lock_state()
      elif selected_wpn.trigger_no == WeaponTriggerType.AGM_TRIGGER
        lockState = get_agm_guidance_lock_state()
      elif selected_wpn.trigger_no == WeaponTriggerType.GUIDED_BOMBS_TRIGGER
        lockState = get_bomb_guidance_lock_state()
    if lockState != GuidanceLockState.RESULT_INVALID && guidanceType != GuidanceType.TYPE_INVALID
      isActive = true
  return <- guidance

struct AamSeeker : ScreenPos

def get_hud_aam_seeker() : AamSeeker // TODO: Decouple from hud/darg, get worldpos instead
  var aamSeeker : AamSeeker
  if get_ils_aam_tracker_visible()
    aamSeeker.isScreenPosValid = true
    aamSeeker.screenPos = get_ils_aam_tracker_pos()
  return <- aamSeeker

def get_hmd_aam_seeker() : AamSeeker
  var aamSeeker : AamSeeker
  if get_aam_tracker_visible()
    aamSeeker.isScreenPosValid = true
    aamSeeker.screenPos = get_screen_aam_tracker_pos()
  return <- aamSeeker

struct GunBoresight : ScreenPos

def get_gun_boresight(hero : Unit const?;
                      world_to_screen : block<(world_pos : float3 const&; var screen_pos : float2&) : bool>) : GunBoresight
  assume wc = hero.weap
  var boresightPos : GunBoresight
  get_weapons_by_trigger_group(wc.Weapons, WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY) <| $(weapons : array<Weapon const? const> const#)
    for w in weapons
      let isGun = (w.trigger_no == int(WeaponTriggerType.MACHINE_GUNS_TRIGGER) ||
        w.trigger_no == int(WeaponTriggerType.CANNONS_TRIGGER) ||
        w.trigger_no == int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER))
      if !isGun
        continue
      var weaponTm : float3x4
      weapon_calcShootTm(w, hero.unitTm, weaponTm)
      let gunVec = weaponTm * float3(10000.0, 0.0, 0.0)
      if world_to_screen |> invoke(gunVec, boresightPos.screenPos)
        boresightPos.isScreenPosValid = true
  return <- boresightPos

// ****************************************************************************
// ***   Sensors   ************************************************************
// ****************************************************************************

struct Track : ScreenPos
  isActive         : bool
  worldPos         : float3
  distance         : float
  distanceRate     : float
  dirNorm          : float3
  angVel           : float3

def get_track(hero : Unit const?;
              world_to_screen : block<(world_pos : float3 const&; var screen_pos : float2&) : bool>) : Track
  var track : Track
  using() <| $(var target : TargetOfInterest#)
    if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
      track.isActive = true
      track.worldPos = target.from + target.dirNorm * target.distance
      track.distance = target.distance
      track.distanceRate = target.distanceRate
      track.dirNorm = target.dirNorm
      track.angVel = target.angVel
      if world_to_screen |> invoke(track.worldPos, track.screenPos)
        track.isScreenPosValid = true
  return track

struct SensorPointOfInterest : ScreenPos
  isSet            : bool
  worldPos         : float3
  distance         : float

def get_sensor_point_of_interest(hero : Unit const?;
                                 world_to_screen : block<(world_pos : float3 const&; var screen_pos : float2&) : bool>) : SensorPointOfInterest
  var spi : SensorPointOfInterest
  if get_point_of_interest(spi.worldPos)
    spi.isSet = true
    spi.distance = length(spi.worldPos - hero.pos)
    if world_to_screen |> invoke(spi.worldPos, spi.screenPos)
      spi.isScreenPosValid = true
  return spi

bitfield RadarStateFlags
  ACM
  TRK
  TWS
  HDN
  HMD
  GMT
  MEM
  IRST
  NONE = bitfield(0)

struct RadarState
  flags           : RadarStateFlags
  azimuthMin      : float
  azimuthMax      : float
  elevationMin    : float
  elevationMax    : float
  displayRangeMin : float
  displayRangeMax : float
  isVerticalScan  : bool
  isEmitting      : bool
  modeName        : string

def get_radar_state() : RadarState
  var state : RadarState
  with state
    azimuthMin = get_radar_hud_scan_azimuth_min()
    azimuthMax = get_radar_hud_scan_azimuth_max()
    elevationMin = get_radar_hud_scan_elevation_min()
    elevationMax = get_radar_hud_scan_elevation_max()
    displayRangeMax = get_radar_hud_distance_max()
    displayRangeMin = get_radar_hud_distance_min()
    isVerticalScan = elevationMax - elevationMin > 2.0 * (azimuthMax - azimuthMin)
    isEmitting = get_radar_hud_is_emitting() || get_radar_hud_is_emitting2()
    modeName = get_radar_hud_mode_name()
    flags.set_flag(RadarStateFlags.NONE, true)
    flags.set_flag(RadarStateFlags.ACM, find(modeName, "ACM") >= 0)
    flags.set_flag(RadarStateFlags.TRK, find(modeName, "track") >= 0)
    flags.set_flag(RadarStateFlags.TWS, find(modeName, "TWS") >= 0)
    flags.set_flag(RadarStateFlags.HDN, find(modeName, "HDN") >= 0)
    flags.set_flag(RadarStateFlags.HMD, find(modeName, "HMD") >= 0)
    flags.set_flag(RadarStateFlags.GMT, find(modeName, "GTM") >= 0)
    flags.set_flag(RadarStateFlags.MEM, find(modeName, "memory") >= 0)
    flags.set_flag(RadarStateFlags.IRST, get_radar_hud_is_irst() && find(modeName, "IRST") >= 0)
  return state

struct GunGyro : ScreenPos

def get_gun_gyro_pos(fcm : FlightControlMode const?;
                     fm_props : FlightModelProps const?;
                     hero_tm : float3x4 const&;
                     world_to_screen : block<(world_pos : float3 const&; var screen_pos : float2&) : bool>) : GunGyro
  var gunGyroPos : GunGyro
  if fcm.isCannonFireDirectionValid
    let dir = (hero_tm * fcm.averageCannonPosition) + fcm.cannonAimDirection
    gunGyroPos.isScreenPosValid = world_to_screen |> invoke(dir, gunGyroPos.screenPos)
  elif fcm.isCannonAimValid
    var offsetPitchRotTm : float3x4
    rotzTM(fm_props.staticAimPitch, offsetPitchRotTm)
    var gyroOffset = inverse(hero_tm) * fcm.cannonAimPosition
    gyroOffset = offsetPitchRotTm * gyroOffset
    let dir = hero_tm * gyroOffset
    gunGyroPos.isScreenPosValid = world_to_screen |> invoke(dir, gunGyroPos.screenPos)
  return <- gunGyroPos

// ****************************************************************************
// ***   HUD/HMD helpers   ****************************************************
// ****************************************************************************

struct LimitsEllipse
  center : float2
  radius : float2

def clamp_pos(pos : float2 const&; var out_pos : float2&; lim : LimitsEllipse& const) : bool
  if is_out_of_ellipse(pos, lim.center, lim.radius)
    let dir = fast_normalize(pos)
    let t  = trace_ray_to_ellipse(float2(0.0), dir, lim.center, lim.radius)
    out_pos = dir * t
    return false
  out_pos = pos
  return true

def is_out_of_ellipse(pos : float2; center : float2; radius : float2) : bool
  let offset = pos - center
  let scaled = safediv_point2(offset, radius)
  return dot(scaled, scaled) > 1.0

def trace_ray_to_ellipse(pos : float2; dir : float2; center : float2; radius : float2) : float
  let scaledPos = safediv_point2(pos - center, radius)
  let scaledDir = safediv_point2(dir, radius)
  let a = dot(scaledDir, scaledDir)
  let b = 2.0 * dot(scaledPos, scaledDir)
  let c = dot(scaledPos, scaledPos) - 1.0 // 1.0 is radius^2
  let discriminant = b * b - 4.0 * a * c
  if discriminant < 0.0
    return 1e10
  let t = (-b + safe_sqrt(discriminant)) / (2.0 * a)
  return t

def world_pos_to_hud(pos : float3 const&; hero_tm : float3x4 const&; hud_fov : float2)
  let dirVec = pos - hero_tm[3]
  return world_vec_to_hud(dirVec, hero_tm, hud_fov)

def world_vec_to_hud(dir_vec : float3 const&; hero_tm : float3x4 const&; hud_fov : float2)
  var localVec = quat_mul_vec(math::quat(inverse(hero_tm)), dir_vec)
  let isBehind = localVec.x < 0.0 // Point in rear hemisphere
  if isBehind
    localVec.x = -localVec.x
  localVec = fast_normalize(localVec)
  let screenX = (atan2(localVec.x, localVec.z) - HALF_PI)
  let screenY = safe_asin(localVec.y)
  let result = float2(screenX / hud_fov.x, -screenY / hud_fov.y)
  return !isBehind ? result : result * 100.0

def angle_to_hud(angle : float2; hud_fov : float2)
  return float2(angle.x / hud_fov.x, -angle.y / hud_fov.y)

// ****************************************************************************
// ***   Fuel              ****************************************************
// ****************************************************************************

struct FuelState
  max : float
  maxAvailable : float
  current : float

  currentInternal : float
  currentExternal : float

  hasAvailableExternals : bool

def get_fuel_state(mass : Mass&;
                   external_tank_callback : block<(index : int; current, max : float)>)
  var state : FuelState

  state.max = getFuelMassMax(mass)
  state.current = getFuelMassCurrent(mass, 0)

  state.currentInternal = 0.0
  state.currentExternal = 0.0

  var externalTankNum = 0
  let numTanks = mass.props.numTanks
  for i in range(numTanks)
    let tankProps = mass.props |> getFuelTankProps(i)
    if tankProps.fuelSystemNum != 0
      continue

    let tankState = mass.state |> getFuelTankState(i)
    if !tankState.available
      continue

    state.maxAvailable += tankProps.capacity

    if tankProps.external
      state.currentExternal += tankState.currentFuel
      external_tank_callback(externalTankNum, tankState.currentFuel, tankProps.capacity)
      externalTankNum++

      state.hasAvailableExternals = true
    else
      state.currentInternal += tankState.currentFuel

  return state