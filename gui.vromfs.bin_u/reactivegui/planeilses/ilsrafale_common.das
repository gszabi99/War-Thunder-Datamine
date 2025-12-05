module ilsRafale_common public

require app
require DagorMath
require FlightControl
require FlightModelWrap
require GamePhys
require GuidanceLock
require hud
require math
require Mission
require Plane
require RadarHud
require Sensors
require strings
require Unit
require Weapon

require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

let shared
  AIR_GUN_DISTANCE = 1000.0
  GROUND_GUN_DISTANCE = 2000.0
  BOMBING_DISTANCE = 10000.0
  BLINKS_PER_SEC = 4.0

struct Limits
  center : float2
  radius : float2

struct Tracking
  isActive       : bool
  pos            : float3
  distance       : float
  distanceRate   : float
  dirNorm        : float3
  angVel         : float3
  screenPosValid : bool
  screenPos      : float2

struct SensorPoi
  isSet          : bool
  pos            : float3
  distance       : float
  screenPosValid : bool
  screenPos      : float2

struct Radar
  isEmitting     : bool
  isVerticalScan : bool
  isAcmMode      : bool
  isTrkMode      : bool
  azimuthMin     : float
  azimuthMax     : float
  elevationMin   : float
  elevationMax   : float

struct AamSeeker
  screenPosValid : bool
  screenPos      : float2

[safe_when_uninitialized]
struct CommonState
  hero            : Unit const?
  fmw             : FlightModelWrap?
  wc              : WeaponController const?
  app             : AcesApp const?
  secondaryWeapon : Weapon?

  tracking    : Tracking
  spi         : SensorPoi
  radar       : Radar
  aamSeeker  : AamSeeker
  tvvPos      : float2
  totalTime   : float
  bulletCount : int
  shellCount  : int

  isDogFight          : bool
  isAirGunMode        : bool
  isGroundGunMode     : bool
  isAamMode           : bool
  isBombingCcrpMode   : bool
  isBombingCcipMode   : bool
  isBombingGuidedMode : bool

def init_hud(var state : CommonState&; var canvas : Canvas&; var fmw : FlightModelWrap?; hero : Unit const?; wc : WeaponController const?; app : AcesApp const?)
  with state
    init_common(state, fmw, hero, wc, app)
    var screenPos : float2

    if world_to_ils_screen(fmw, tracking.pos, screenPos)
      tracking.screenPosValid = true
      tracking.screenPos = canvas.toRelPos(screenPos)

    if world_to_ils_screen(fmw, spi.pos, screenPos)
      spi.screenPosValid = true
      spi.screenPos = canvas.toRelPos(screenPos)

    if get_ils_aam_tracker_visible()
      aamSeeker.screenPosValid = true
      aamSeeker.screenPos = get_ils_aam_tracker_pos()


def init_hmd(var state : CommonState&; var canvas : Canvas&; var fmw : FlightModelWrap?; hero : Unit const?; wc : WeaponController const?; app : AcesApp const?)
  with state
    init_common(state, fmw, hero, wc, app)
    var screenPos : float2

    if world_to_hmd_screen(tracking.pos, screenPos)
      tracking.screenPosValid = true
      tracking.screenPos = canvas.toRelPos(screenPos)

    if world_to_hmd_screen(spi.pos, screenPos)
      spi.screenPosValid = true
      spi.screenPos = canvas.toRelPos(screenPos)

    if get_aam_tracker_visible()
      aamSeeker.screenPosValid = true
      aamSeeker.screenPos = get_screen_aam_tracker_pos()


def private init_common(var state : CommonState&; var fmw : FlightModelWrap?; hero : Unit const?; wc : WeaponController const?; app : AcesApp const?)
  state.hero = hero
  state.fmw  = fmw
  state.wc   = wc
  state.app  = app

  with state
    with radar
      isEmitting     = get_radar_hud_is_emitting() || get_radar_hud_is_emitting2()
      azimuthMin     = get_radar_hud_scan_azimuth_min()
      azimuthMax     = get_radar_hud_scan_azimuth_max()
      elevationMin   = get_radar_hud_scan_elevation_min()
      elevationMax   = get_radar_hud_scan_elevation_max()
      isAcmMode      = find(get_radar_hud_mode_name(), "ACM") >= 0
      isTrkMode      = find(get_radar_hud_mode_name(), "track") >= 0
      isVerticalScan = radar.elevationMax - radar.elevationMin > 2.0 * (radar.azimuthMax - radar.azimuthMin)

    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        with tracking
          isActive     = true
          pos          = target.from + target.dirNorm * target.distance
          distance     = target.distance
          distanceRate = target.distanceRate
          dirNorm      = target.dirNorm
          angVel       = target.angVel

    if get_point_of_interest(spi.pos)
      spi.isSet = true
      spi.distance = metrToNavMile * length(spi.pos - hero.unitTm[3])

    totalTime = float(get_total_time())
    tvvPos = -(float3x3(inverse(hero.unitTm)) * normalize(hero.vel)).zy
    get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
      secondaryWeapon := weapon

    bulletCount = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
    shellCount = get_hud_cur_weapon_shell_count()

    isAirGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS)
    isGroundGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS)
    isAamMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (secondaryWeapon == null || secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)))
    isDogFight = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (state.radar.isAcmMode || (state.radar.isTrkMode && state.tracking.isActive && state.tracking.distance < 2.0 * AIR_GUN_DISTANCE))))
    isBombingCcrpMode = spi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) &&
      (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)))
    isBombingCcipMode = !spi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS) &&
       (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)))
    isBombingGuidedMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) &&
      (secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))))


def clamp_pos(pos : float2; var out_pos : float2&; lim : Limits& const)
  if is_out_of_ellipse(pos, lim.center, lim.radius)
    let dir = fast_normalize(pos)
    let t  = trace_ray_to_ellipse(float2(0.0), dir, lim.center, lim.radius)
    out_pos = dir * t
    return false
  out_pos = pos
  return true


def draw_tracking_air_target_mark(state : CommonState& const; var canvas : Canvas&; lim : Limits& const)
  with state
    let size = 0.1
    let dash = 0.3 * size
    let space = size - 2.0 * dash
    let angle = -fmw.roll / 180.0 * PI

    if state.radar.isTrkMode && state.tracking.isActive && state.tracking.screenPosValid
      let pos = state.tracking.screenPos
      var clampedPos : float2
      let isTargetOnScreen = clamp_pos(pos, clampedPos, lim)

      let isBlink = fract(BLINKS_PER_SEC * state.totalTime) < 0.5

      let gunTargetSize = 0.7 * size
      let gunTargetDash = 0.24 * gunTargetSize
      let gunTargetSpace = 0.5 * (gunTargetSize - 3.0 * gunTargetDash)
      canvas.drawDashedRect(clampedPos, float2(gunTargetSize), float2(gunTargetDash), float2(gunTargetSpace))
      if secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)
        let scale = 1.25
        canvas.drawDashedRect(clampedPos, float2(scale * gunTargetSize), float2(scale * gunTargetDash), float2(scale * gunTargetSpace))
      if isTargetOnScreen || isBlink
        canvas.drawDashedRect(clampedPos, float2(size), float2(dash), float2(space), angle)
        let tm : float3x3 = float3x3(inverse(hero.unitTm))
        let velRel = state.tracking.dirNorm * state.tracking.distanceRate + state.tracking.angVel * state.tracking.distance
        let velAbs = hero.vel + velRel
        let velAbsDirection = -fast_normalize((tm * velAbs).zx)
        let velRelDirection = -fast_normalize((tm * velRel).zx)
        canvas.drawLine(clampedPos + 0.75 * size * velAbsDirection, clampedPos + 1.75 * size * velAbsDirection)
        canvas.drawLine(clampedPos + 0.75 * size * velRelDirection, clampedPos + 1.25 * size * velRelDirection)
      if !isTargetOnScreen
        let arrowOffset = 0.15
        let arrowLength = float2(0.02, 0.06)
        let arrowLineLength = 0.03
        let arrowStart = fast_normalize(clampedPos) * (length(clampedPos) - arrowOffset)
        let arrowEnd = fast_normalize(clampedPos) * (length(clampedPos) - arrowOffset - arrowLineLength)
        canvas.drawArrowHead(arrowStart, clampedPos, arrowLength)
        canvas.drawLine(arrowStart, arrowEnd)

        let textPos = fast_normalize(clampedPos) * (length(clampedPos) - arrowOffset - arrowLineLength - 0.05)
        let angleToTarget = acos(dot(state.tracking.dirNorm, hero.unitTm[0])) * radToDeg
        let arrowText = fmt(":03d", roundi(angleToTarget))
        canvas.drawStrAnchored(textPos, arrowText, AnchorHorz.Center, AnchorVert.Center)

    elif isDogFight
      canvas.drawDashedRect(float2(0.0), float2(size), float2(dash), float2(space), angle)


def draw_tracking_ground_target_mark(state : CommonState& const; var canvas : Canvas&; lim : Limits& const)
  with state
    return if !tracking.isActive || !tracking.screenPosValid

    let size = 0.1
    let pos = tracking.screenPos
    let isBlink = fract(BLINKS_PER_SEC * totalTime) < 0.5
    var clampedPos : float2
    let isTargetOnScreen = clamp_pos(pos, clampedPos, lim)
    let gunTargetSize = 0.7 * size
    let gunTargetDash = 0.24 * gunTargetSize
    let gunTargetSpace = 0.5 * (gunTargetSize - 3.0 * gunTargetDash)
    if isTargetOnScreen || isBlink
      canvas.drawDashedRect(clampedPos, float2(gunTargetSize), float2(gunTargetDash), float2(gunTargetSpace))


def draw_air_speed(state : CommonState& const; var canvas : Canvas; var pos : float2; ft_sz : int; is_metric : bool = false)
  with state
    let indicatedAirSpeed = roundi((is_metric ? mpsToKmh : mpsToKnots) * fmw.ias)
    canvas.setFontSize(ft_sz)
    canvas.setTextAnchorHorz(AnchorHorz.Right)
    canvas.drawStr(pos, string(indicatedAirSpeed))

    if fmw.fm.Mach >= 0.4
      canvas.setFontSize(roundi(float(ft_sz) * 0.72), true)
      pos.y += canvas.getLineSpacing()
      canvas.drawStr(pos, fmt(":4.2f", fmw.fm.Mach), 4)


def draw_radar_status(state : CommonState& const; var canvas : Canvas; var pos : float2; ft_sz : int)
  with state
    return if !radar.isEmitting

    canvas.setFontSize(ft_sz)
    canvas.setCaretPosition(pos)
    canvas.printStr(get_radar_hud_is_irst() ? "MXD" : "RDR", 3)


def draw_spi_mark(state : CommonState& const; var canvas : Canvas&; lim : Limits& const)
  with state
    return if !state.spi.isSet || !state.spi.screenPosValid

    var clampedPos : float2
    let isBlink = fract(BLINKS_PER_SEC * totalTime) < 0.5
    let isTargetOnScreen = clamp_pos(state.spi.screenPos, clampedPos, lim)
    if isTargetOnScreen || isBlink
      canvas.drawCrossReticle(clampedPos, float2(0.05), float2(0.025))


def draw_radar_target_data(state : CommonState& const; var canvas : Canvas; pos_mach : float2; pos_dist : float2; pos_alt : float2; ft_sz : int; use_space : bool = false)
  with state
    return if !tracking.isActive || tracking.distance == 0.0

    let targetBaroAlt = tracking.pos.y - state.app.currentScene.waterLevel
    let tangVel = tracking.angVel * tracking.distance
    let relVel = tangVel + tracking.distanceRate * tracking.dirNorm
    let targetVel = hero.vel + relVel
    let targetSpd = length(targetVel)
    let targetMach = targetSpd / atmosphere_sonicSpeed(targetBaroAlt)
    let targetDist = min(tracking.distance * metrToNavMile, 1e3 - 1e-3)

    canvas.setFontSize(ft_sz)
    let space = use_space ? " " : ""
    canvas.drawStrAnchored(pos_mach, "M{space}{fmt(":.2f", targetMach)}", AnchorHorz.Left, AnchorVert.Bottom)
    canvas.drawStrAnchored(pos_dist, "{fmt(":3.1f", targetDist)}{space}NM", AnchorHorz.Center, AnchorVert.Bottom)
    canvas.drawStrAnchored(pos_alt, "FL{space}{fmt(":03", roundi(targetBaroAlt * metrToFeet * 1e-2))}", AnchorHorz.Right, AnchorVert.Bottom)


def draw_load_factor(state : CommonState& const; var canvas : Canvas; pos : float2; ft_sz : int)
  with state
    let load = float(fmw.fm.localAccel.y) * safeinv(gravity()) + 1.f
    canvas.setTextAnchorHorz(AnchorHorz.Left)
    canvas.setFontSize(ft_sz)
    canvas.setCaretPosition(pos)
    canvas.printStrLn("  G", 3)
    canvas.setTextAnchorHorz(AnchorHorz.Right)
    canvas.printStr(fmt(": 2.1f", load))


def draw_radar_alt(state : CommonState& const; var canvas : Canvas; pos : float2; ft_sz : int; is_metric : bool = false)
  with state
    return if abs(fmw.roll) > 60.0 || abs(fmw.tangage) > 30.0

    let alt = fmw.fm.currentAlt * (is_metric ? 1.0 : metrToFeet)
    let altQuant = alt < 100.0 ? floori(alt / 5.0) * 5 : floori(alt / 10.0) * 10
    let altStr = fmt(":>5d", altQuant)
    canvas.setFontSize(ft_sz)
    canvas.setTextAnchorHorz(AnchorHorz.Left)
    canvas.drawStr(pos, "H{altStr}")


def draw_baro_alt(state : CommonState& const; var canvas : Canvas; pos : float2; ft_sz : int; is_metric : bool = false)
  with state
    let alt = (hero.pos.y - app.currentScene.waterLevel) * (is_metric ? 1.0 : metrToFeet)
    let altQuant = floori(alt / 10.0) * 10
    let altStr = fmt(":>5d", altQuant)
    canvas.setCaretPosition(pos)
    canvas.setFontSize(ft_sz)
    canvas.printStr(altStr, 3)
    canvas.setFontSize(roundi(0.75 * float(ft_sz)))
    canvas.printStr(slice(altStr, 3))


def draw_dynamic_launch_zone(state : CommonState& const; var canvas : Canvas; pos : float2; size : float2; ft_sz : int; is_metric : bool = false)
  with state
    return if (!isAamMode && !isAirGunMode) || !get_radar_hud_aam_launch_zone_visible()

    let distMax = get_radar_hud_aam_launch_zone_dist_max()
    let distMaxDgft = get_radar_hud_aam_launch_zone_dist_dgft_max() / distMax
    let distMin = get_radar_hud_aam_launch_zone_dist_min() / distMax
    let dist = clamp(get_radar_hud_aam_launch_zone_dist() / distMax, 0.0, 1.05)

    let mid = pos.x
    let top = pos.y
    let bottom = top + size.y
    let serifRight = mid + 0.25 * size.x
    canvas.drawLine(float2(mid, top), float2(serifRight, top))
    canvas.drawLine(float2(mid, bottom), float2(serifRight, bottom))
    canvas.drawLine(float2(mid, top), float2(mid, bottom))

    let distX = mid + 0.5 * size.x
    let distMinX = mid - 0.5 * size.x
    let distMaxDgftX = mid - 0.75 * size.x
    let distY = bottom - size.y * dist
    let distY1 = distY - 0.25 * size.x
    let distY2 = distY + 0.25 * size.x
    let distMinY = bottom - size.y * distMin
    let distMaxDgftY = bottom - size.y * distMaxDgft
    canvas.drawLine(float2(mid, distMinY), float2(distMinX, distMinY))
    canvas.drawLine(float2(mid, distMaxDgftY), float2(distMaxDgftX, distMaxDgftY))
    canvas.drawLine(float2(mid, distY), float2(distX, distY1))
    canvas.drawLine(float2(mid, distY), float2(distX, distY2))

    let distance = state.tracking.distance * (is_metric ? 0.001 : metrToNavMile)
    let distanceStr = round(distance * 10.0) > 99.0 ? fmt(":>3d", roundi(distance)) : fmt(":>4.1f", distance)
    canvas.setFontSize(ft_sz)
    canvas.setTextAnchorHorz(AnchorHorz.Left)
    canvas.drawStr(float2(distX, distY + 0.012), "{distanceStr}")


def draw_closure_rate(state : CommonState& const; var canvas : Canvas; pos : float2; ft_sz : int; is_metric : bool = false)
  with state
    return if !tracking.isActive
    canvas.setFontSize(ft_sz)
    canvas.setTextAnchorHorz(AnchorHorz.Left)
    let approachSpeed = state.tracking.distanceRate * (is_metric ? 1.0 : metrToFeet)
    let str = fmt(":>5d", roundi(-approachSpeed))
    let size = canvas.getStringSize(str)
    let padding = float2(0.005)
    canvas.drawBox(pos - padding, pos + size + padding)
    canvas.drawStr(pos + float2(0.0, size.y), str)


def draw_aam_em_tracking_mark(state : CommonState& const; var canvas : Canvas; lim : Limits& const)
  with state
    let aamLockState = get_aam_guidance_lock_state()
    return if int(aamLockState) <= int(GuidanceLockState.RESULT_STANDBY)

    let guidanceType = get_cur_weapon_guidance_type()
    return if guidanceType != GuidanceType.TYPE_SARH && guidanceType != GuidanceType.TYPE_ARH

    let radius = 0.032
    let pos = aamSeeker.screenPosValid ? canvas.toRelPos(aamSeeker.screenPos) : tracking.screenPos
    var clampedPos : float2
    let isTargetOnScreen = clamp_pos(pos, clampedPos, lim)
    let isBlink = fract(BLINKS_PER_SEC * totalTime) < 0.5
    return if isBlink && !isTargetOnScreen

    canvas.drawCircle(clampedPos, radius)


def draw_aam_ir_tracking_mark(state : CommonState& const; var canvas : Canvas; lim : Limits& const)
  with state
    let aamLockState = get_aam_guidance_lock_state()
    return if int(aamLockState) <= int(GuidanceLockState.RESULT_STANDBY)
    return if get_cur_weapon_guidance_type() != GuidanceType.TYPE_OPTICAL
    return if !aamSeeker.screenPosValid

    let radius = 0.032
    let pos = canvas.toRelPos(aamSeeker.screenPos)
    var clampedPos : float2
    let isTargetOnScreen = clamp_pos(pos, clampedPos, lim)
    let isBlink = fract(BLINKS_PER_SEC * state.totalTime) < 0.5
    return if isBlink && !isTargetOnScreen

    canvas.drawCircle(clampedPos, radius)
    if aamLockState == GuidanceLockState.RESULT_TRACKING
      canvas.drawCircle(clampedPos, radius * 1.25)