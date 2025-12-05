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

// ****************************************************************************
// ***  Util  *****************************************************************
// ****************************************************************************

[generic, hint(alwaysinline)]
def private operator ==(i : int; e : CockpitSightMode | WeaponTriggerType)
  return i == int(e)

[hint(alwaysinline)]
def private safediv_point2(p1 : float2; p2 : float2) : float2
  return float2(safediv(p1.x, p2.x), safediv(p1.y, p2.y))

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

struct FlightPathMarker
  isScreenPosValid : bool
  screenPos        : float2

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
  AA_DOGFIGHT
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

def get_weapon_mode(sight_mode : int; trigger_no : int; is_track_active : bool; is_spi_set : bool) : WeaponMode
  if sight_mode == CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS
    return is_track_active ? WeaponMode.AA_GUN_RANGED : WeaponMode.AA_GUN_UNRANGED
  if sight_mode == CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET && trigger_no == WeaponTriggerType.AAM_TRIGGER
    return WeaponMode.AA_MISSILE
  if sight_mode == CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS
    return WeaponMode.AG_GUN
  if sight_mode == CockpitSightMode.HUD_SIGHT_MODE_GROUND_ROCKET && trigger_no == WeaponTriggerType.ROCKETS_TRIGGER
    return WeaponMode.AG_ROCKET
  if trigger_no == WeaponTriggerType.AGM_TRIGGER
    return WeaponMode.AG_MISSILE
  if trigger_no == WeaponTriggerType.BOMBS_TRIGGER || trigger_no == WeaponTriggerType.GUIDED_BOMBS_TRIGGER
    if sight_mode == CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO && is_spi_set
      return WeaponMode.AG_BOMB_CCRP
    if sight_mode == CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS && !is_spi_set
      return WeaponMode.AG_BOMB_CCIP
  return WeaponMode.INVALID

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
  return guidance

// ****************************************************************************
// ***   Sensors   ************************************************************
// ****************************************************************************

struct Track
  isActive         : bool
  worldPos         : float3
  distance         : float
  distanceRate     : float
  dirNorm          : float3
  angVel           : float3
  isScreenPosValid : bool
  screenPos        : float2

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

struct SensorPointOfInterest
  isSet            : bool
  worldPos         : float3
  distance         : float
  isScreenPosValid : bool
  screenPos        : float2

def get_sensor_point_of_interest(hero_pos : float3 const&;
                                 world_to_screen : block<(world_pos : float3; var screen_pos : float2&) : bool>) : SensorPointOfInterest
  var spi : SensorPointOfInterest
  if get_point_of_interest(spi.worldPos)
    spi.isSet = true
    spi.distance = length(spi.worldPos - hero_pos)
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
  IRST
  OFF = bitfield(0)

struct RadarState
  flags           : RadarStateFlags
  azimuthMin      : float
  azimuthMax      : float
  elevationMin    : float
  elevationMax    : float
  displayRangeMin : float
  displayRangeMax : float
  isVerticalScan  : bool

def get_radar_state() : RadarState
  var state : RadarState
  if !get_radar_hud_is_emitting() && !get_radar_hud_is_emitting2()
    return state
  with state
    azimuthMin = get_radar_hud_scan_azimuth_min()
    azimuthMax = get_radar_hud_scan_azimuth_max()
    elevationMin = get_radar_hud_scan_elevation_min()
    elevationMax = get_radar_hud_scan_elevation_max()
    displayRangeMax = get_radar_hud_distance_max()
    displayRangeMin = get_radar_hud_distance_min()
    isVerticalScan = elevationMax - elevationMin > 2.0 * (azimuthMax - azimuthMin)
    let radarModeName = get_radar_hud_mode_name()
    flags.set_flag(RadarStateFlags.ACM, find(radarModeName, "ACM") >= 0)
    flags.set_flag(RadarStateFlags.TRK, find(radarModeName, "track") >= 0)
    flags.set_flag(RadarStateFlags.TWS, find(radarModeName, "TWS") >= 0)
    flags.set_flag(RadarStateFlags.HDN, find(radarModeName, "HDN") >= 0)
    flags.set_flag(RadarStateFlags.HMD, find(radarModeName, "HMD") >= 0)
    flags.set_flag(RadarStateFlags.GMT, find(radarModeName, "GTM") >= 0)
    flags.set_flag(RadarStateFlags.IRST, get_radar_hud_is_irst() && find(radarModeName, "IRST") >= 0)
  return state

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
