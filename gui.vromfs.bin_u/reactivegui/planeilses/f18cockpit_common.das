require darg
require math
require strings
require app
require hud
require DagorSystem
require DagorMath
require DagorStdGuiRender
require Plane
require FlightModelWrap
require HeroManager
require Unit
require Sensors
require RadarHud
require Mission
require FlightControl
require Weapon
require WTCamera
require GuidanceLock
require %game.utils.utils_common
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

struct PropStorage
  fontId : int
  ilsFovDeg : float

struct Ccrp
  isActive : bool
  timeToRelease : float

struct Tracking
  isActive : bool
  pos : float3
  distance : float
  distanceRate : float
  dirNorm : float3
  angVel : float3

  screenPosValid : bool
  screenPos : float2

  ilsPosValid : bool
  ilsPos : float2

struct Guidance
  isActive : bool
  guidanceType : GuidanceType
  lockState : GuidanceLockState

  screenPosValid : bool
  screenPos : float2

  ilsPosValid : bool
  ilsPos : float2

struct Radar
  isEmitting : bool
  isVerticalScan : bool
  isAcmMode : bool
  isTrkMode : bool
  isTwsMode : bool
  azimuthMin : float
  azimuthMax : float
  elevationMin : float
  elevationMax : float

struct PointOfInterest
  isSet : bool
  pos : float3
  ilsPosValid : bool
  ilsPos : float2

let airGunDistance = 1000.0
let groundGunDistance = 2000.0
let groundRocketDistance = 10000.0 / metrToFeet
let bombingDistance = 10000.0

class FA18CockpitElementBase : Canvas
  isValid : bool
  ilsFovDeg : float
  defaultLineWidth : float
  defaultLineWidthHdpxRel : float
  defaultFontSize : int = 35

  hero : Unit?
  fmw : FlightModelWrap?
  fm : FlightModel?
  cockpit : FlightModelCockpit?
  wc : WeaponController?
  fcm : FlightControlMode?
  secondaryWeapon : Weapon?
  totalTime : float
  heading : float
  gearProgress : float

  radar : Radar
  tracking : Tracking
  aamGuidance : Guidance
  agmGuidance : Guidance
  poi : PointOfInterest
  ccrp : Ccrp

  isDogFight : bool
  isAirGunMode : bool
  isGroundGunMode : bool
  isGroundRocketMode : bool
  isAamMode : bool
  isAgmMode : bool
  isBombingCcrpMode : bool
  isBombingCcipMode : bool
  isBombingGuidedMode : bool

  def FA18CockpitElementBase(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    fmw = hero.as_fmw()
    wc = hero.weap
    fcm = get_app().flightControlMode
    return if fmw == null || wc == null || fcm == null

    fm = fmw.fm
    cockpit = fmw.cockpit
    return if fm == null || cockpit == null

    isValid = true
    ilsFovDeg = props.ilsFovDeg
    setColor(*cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS))
    defaultLineWidth = floor(4.0 * cockpit.ilsLineWidthScale)
    setLineWidth(defaultLineWidth)
    defaultLineWidthHdpxRel = toRelY(lineWidthHdpx)

    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)

    totalTime = float(get_total_time())

    let forward = hero.unitTm[0]
    heading = atan2(forward.x, forward.z)
    gearProgress = fm.appliedCT.gear

    get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
      secondaryWeapon := weapon

    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        tracking.isActive = true
        tracking.pos = target.from + target.dirNorm * target.distance
        tracking.distance = target.distance
        tracking.distanceRate = target.distanceRate
        tracking.dirNorm = target.dirNorm
        tracking.angVel = target.angVel

        var screenPos : float2
        if world_to_screen(tracking.pos, screenPos)
          tracking.screenPosValid = true
          tracking.screenPos = screenPos

        var ilsPos : float2
        if world_to_ils_screen(fmw, tracking.pos, ilsPos)
          tracking.ilsPosValid = true
          tracking.ilsPos = toRelPos(ilsPos)

    let aamLockState = get_aam_guidance_lock_state()
    let aamGuidanceType = get_cur_weapon_guidance_type()
    if aamLockState != GuidanceLockState.RESULT_INVALID && aamGuidanceType != GuidanceType.TYPE_INVALID
      aamGuidance.isActive = true
      aamGuidance.lockState = aamLockState
      aamGuidance.guidanceType = aamGuidanceType

      if get_aam_tracker_visible()
        aamGuidance.screenPosValid = true
        aamGuidance.screenPos = toRelPos(get_screen_aam_tracker_pos())

      if get_ils_aam_tracker_visible()
        aamGuidance.ilsPosValid = true
        aamGuidance.ilsPos = toRelPos(get_ils_aam_tracker_pos())

    let agmLockState = get_agm_guidance_lock_state()
    let agmGuidanceType = get_cur_weapon_guidance_type()
    if agmLockState != GuidanceLockState.RESULT_INVALID && agmGuidanceType != GuidanceType.TYPE_INVALID
      agmGuidance.isActive = true
      agmGuidance.lockState = agmLockState
      agmGuidance.guidanceType = agmGuidanceType
      if get_agm_tracker_visible()
        var ilsPosAbs : float2
        agmGuidance.ilsPosValid = get_ils_agm_tracker_pos(fmw, ilsPosAbs)
        agmGuidance.ilsPos = toRelPos(ilsPosAbs)

    if get_point_of_interest(poi.pos)
      poi.isSet = true
      var ilsPos : float2
      if world_to_ils_screen(fmw, poi.pos, ilsPos)
        poi.ilsPosValid = true
        poi.ilsPos = toRelPos(ilsPos)

    radar.isEmitting = get_radar_hud_is_emitting() || get_radar_hud_is_emitting2()
    radar.azimuthMin = get_radar_hud_scan_azimuth_min()
    radar.azimuthMax = get_radar_hud_scan_azimuth_max()
    radar.elevationMin = get_radar_hud_scan_elevation_min()
    radar.elevationMax = get_radar_hud_scan_elevation_max()
    radar.isAcmMode = find(get_radar_hud_mode_name(), "ACM") >= 0
    radar.isTrkMode = find(get_radar_hud_mode_name(), "track") >= 0
    radar.isTwsMode = find(get_radar_hud_mode_name(), "TWS") >= 0
    radar.isVerticalScan = radar.elevationMax - radar.elevationMin > 2.0 * (radar.azimuthMax - radar.azimuthMin)


    isAirGunMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) && secondaryWeapon == null))

    isGroundGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS)

    isGroundRocketMode = (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.ROCKETS_TRIGGER))

    isAamMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) || (secondaryWeapon != null &&
      secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)))

    isAgmMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_ROCKET) && secondaryWeapon != null &&
      secondaryWeapon.trigger_no == int(WeaponTriggerType.AGM_TRIGGER))

    isDogFight = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (radar.isAcmMode || (radar.isTrkMode && tracking.isActive && tracking.distance < 2.0 * airGunDistance))))

    let isBombTrigger = (secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER) ||
      secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)))

    isBombingCcrpMode = poi.isSet && isBombTrigger && fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO)

    isBombingCcipMode = !poi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS) &&
       (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)))

    isBombingGuidedMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) &&
      (secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))))

    if isBombingCcrpMode
      ccrp.isActive = true
      ccrp.timeToRelease = get_time_before_bomb_release()

  def drawFlightParams()
    let pos = float2(-0.48, -0.03)
    setTextAnchorHorz(AnchorHorz.Right)
    setCaretPosition(pos)
    setLineSpacing(1.4)
    setFontSize(defaultFontSize)

    let verts = fixed_array<float2>(
      float2(1.0, 0.0),
      float2(0.9, 0.0),
      float2(0.3, 1.0),
      float2(0.1, 1.0),
      float2(0.0, 0.75),
      float2(0.0, 0.25),
      float2(0.1, 0.0),
      float2(0.3, 0.0),
      float2(0.9, 1.0),
      float2(1.0, 1.0))

    let sizeMult = getFontAscent()
    let scale = float2(1.5 * sizeMult, sizeMult)
    let offset = float2(-0.015, -sizeMult)

    let alphaVerts = verts.to_array().scale(scale).translate(pos + offset)
    drawPolyLine(alphaVerts)
    let aoaStr = fmt(":>5.1f", fm.aoa)

    setTextAnchorHorz(AnchorHorz.Left)
    printStrLn(" {aoaStr}")

    if fmw.fm.appliedCT.gear == 0.0
      let machStr = fmt(":>6.2f", fmw.fm.Mach)
      let overloadStr = fmt(":>5.1f", fm.localAccel.length() / 9.81 + 1.0)
      let maxOverloadStr = fmt(":>6.1f", cockpit.maxG)
      printStrLn("M{machStr}")
      printStrLn("G{overloadStr}")
      printStrLn(maxOverloadStr)

  def drawAltitude()
    // TODO: Make numbers blinking on low altitudes
    let pos = float2(0.4, -0.25)
    var altitude = roundi(fm.currentAlt * metrToFeet)

    if abs(fm.vertSpeed * metrToFeet) < 40.0
      altitude = altitude / 10 * 10
    else
      altitude = altitude / 100 * 100

    setFontSize(defaultFontSize)
    setTextAnchorHorz(AnchorHorz.Right)
    drawIntWithBiggerThousands(pos, altitude, 1.25, true, 2)

  def drawIntegratedAirSpeed()
    let pos = float2(-0.3, -0.25)
    let ias = roundi(fmw.ias * mpsToKnots)
    setFontSize(floori(float(defaultFontSize) * 1.15))
    setTextAnchorHorz(AnchorHorz.Right)
    drawIntWithBiggerThousands(pos, ias, 1.15, true, 1)

  def drawHeadingTape(value : float; pos : float2; size : float2)
    let lt = pos - 0.5 * size
    let rb = pos + 0.5 * size
    let count = 3
    let stepRel = size.x / float(count)
    let heading10deg = (0.5 * float(count + 1) - value * 36.0 / PI2) % 36.0
    let linesOffset = fract(heading10deg) * stepRel
    let dotsOffset = fract(0.5 + heading10deg) * stepRel
    setFontSize(defaultFontSize)
    setViewport(lt, rb)

    for i in range(0, count + 1)
      let x = lt.x + (float(i) - 0.5) * stepRel
      let lineTop = float2(x + linesOffset, rb.y - 0.35 * size.y)
      let lineBottom = float2(x + linesOffset, rb.y - defaultLineWidthHdpxRel)
      let dotPos = float2(x + dotsOffset, rb.y - defaultLineWidthHdpxRel)
      let str = fmt(":03", ((36 - floori(heading10deg) + i) % 36) * 10)
      let strSize = getStringSize(str, 2)
      drawLine(lineTop, lineBottom)
      drawDot(dotPos)
      let fontDescend = getFontDescent()
      let strPos = lineTop + float2(0.0, -fontDescend)
      drawStrAnchored(strPos, str, AnchorHorz.Center, AnchorVert.Bottom)

    restoreViewport()
    let arrPos = pos + float2(0.00, 0.5 * size.y)
    let arrHeight = 0.02
    let arrHalfWidth = 0.012
    drawLine(arrPos, arrPos + float2(arrHalfWidth, arrHeight))
    drawLine(arrPos, arrPos + float2(-arrHalfWidth, arrHeight))


  def drawSelectedAirWeapon()
    var pos = float2(0.0, 0.23)
    setFontSize(floori(float(defaultFontSize) * 1.15))
    setTextAnchorHorz(AnchorHorz.Center)

    if isAirGunMode
      let bulletsCount = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
      drawStr(pos, "GUN", 3)
      pos.y += 0.032
      drawStr(pos, "{bulletsCount}")
    elif isAamMode
      let rawName = get_hud_cur_weapon_name()
      return if rawName.empty()
      let shellCount = get_hud_cur_weapon_shell_count()
      let name1 = loc("{rawName}/f_15e/1")
      let name2 = loc("{rawName}/f_15e/2")
      drawStr(pos, "{name1}{name2} {shellCount}")


  def drawSelectedGroundWeapon()
    let pos = float2(0.33, -0.05)
    setFontSize(defaultFontSize)
    setCaretPosition(pos)
    setLineSpacing(1.0)

    if isGroundGunMode
      let bulletsCount = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
      let bulletsStr = bulletsCount > 0 ? fmt(":>4d", bulletsCount) : " XXX"
      printStrLn("CCIP")
      printStr("GUN{bulletsStr}")
    elif isGroundRocketMode
      let rocketsCount = wc.Weapons.countBullets(int(WeaponTriggerType.ROCKETS_TRIGGER))
      let rocketsStr = rocketsCount > 0 ? fmt(":>4d", rocketsCount) : " XXX"
      printStrLn("CCIP")
      printStr("RKT{rocketsStr}")
    elif isAgmMode
      let text = "MAVF"
      let size = getStringSize(text)
      printStr(text)
      if agmGuidance.isActive && agmGuidance.lockState != GuidanceLockState.RESULT_TRACKING
        drawLine(pos + float2(0.0, -size.y), pos + float2(size.x, 0.0))
        drawLine(pos + float2(0.0, 0.0), pos + float2(size.x, -size.y))
    elif isBombingCcipMode
      printStrLn("CCIP")
    elif isBombingCcrpMode || isBombingGuidedMode
      printStrLn("AUTO")
      let tth = (*wc).getLastGuidedWeaponHitTime(int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
      let timeToShowZeroValue = 2.0

      if tth > totalTime - timeToShowZeroValue
        let time = clamp(roundi(tth - totalTime), 0, 99)
        let timeStr = fmt(":>2d", time)
        printStr("{timeStr} TTI")
      elif ccrp.timeToRelease > 0.0 && ccrp.timeToRelease < 100.0
        let timeStr = fmt(":>2d", ceili(ccrp.timeToRelease))
        printStrLn("{timeStr} REL")

      let distanceStr = fmt(":>4.1f", length(poi.pos - hero.pos) * metrToMile)
      setTextAnchorHorz(AnchorHorz.Left)
      let distanceOffset = float2(-0.037, 0.09)
      drawStr(pos + distanceOffset, "{distanceStr} TGT")

      if fcm.ctrlMap.isLaserDesignatorEnabled
        setTextAnchorHorz(AnchorHorz.Center)
        drawStr(float2(0.0, -0.30), "LTD/R")


  def drawRadarAirTracking(var pos : float2; origin : float2 = float2(0.0); scale : float = 1.0)
    let isAirCombatMode = isAamMode || isAirGunMode
    return if !isAirCombatMode || (!radar.isTrkMode && !radar.isTwsMode) || !tracking.isActive

    let boresightToTarget = pos - origin
    let length = length(boresightToTarget)
    let dir = boresightToTarget / length

    let size = 0.1 * scale
    let indent = float2(0.25 * size)
    let outOfCanvas = isOutOfCanvas(pos, indent)

    if outOfCanvas
      let t = traceRayToCanvasEdges(origin, dir, indent)
      pos = origin + t * dir

    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    if !outOfCanvas || isBlink
      let points = fixed_array<float2>(
        float2(-0.5, 0.0),
        float2(0.0, -0.5),
        float2(0.5, 0.0),
        float2(0.0, 0.5))

      let verts = points.to_array().scale(float2(size)).translate(pos)
      drawClosedPolyLine(verts)

    let arrowLength = 0.15 * scale
    if length > arrowLength + 0.065
      let to = origin + arrowLength * dir
      let headSize = float2(0.01, 0.05) * scale
      drawLine(origin, to)
      drawArrowHead(to, dir, headSize)


  def drawRadarAirTrackingInfo()
    let isAirCombatMode = isAamMode || isAirGunMode
    return if !isAirCombatMode || !tracking.isActive

    let pos = float2(0.3, -0.07)
    setFontSize(defaultFontSize)
    setLineSpacing(1.0)
    setCaretPosition(pos)
    setTextAnchorHorz(AnchorHorz.Left)
    let distanceRateStr = fmt(":d", roundi(-tracking.distanceRate * mpsToKnots))
    printStrLn("{distanceRateStr} Vc")

    if isAirGunMode
      let distanceStr = fmt(":d", roundi(tracking.distance * metrToFeet))
      printStrLn("{distanceStr} FT")
    elif isAamMode
      let distanceStr = fmt(":.1f", tracking.distance * metrToNavMile)
      printStrLn("{distanceStr} RNG")



  def drawAamReticle(targetPos : float2; pos : float2; scale : float = 1.0)
    return if !isAamMode || !tracking.isActive

    pushAxes(axesOrigin, axesScale * scale)

    let radius = 0.2
    drawCircle(pos, radius)

    let velRel = tracking.dirNorm * tracking.distanceRate + tracking.angVel * tracking.distance
    let velAbs = hero.vel + velRel
    let tmInv : float3x3 = float3x3(inverse(hero.unitTm))
    let velDir = fast_normalize(-(tmInv * velAbs).zx)
    let arrowLength = 0.05
    let arrowSize = float2(0.005, 0.025)
    drawLine(pos + velDir * radius, pos + velDir * (radius + arrowLength))
    drawArrowHead(pos + velDir * (radius + arrowLength), velDir, arrowSize)

    let hasDgftDist = get_radar_hud_aam_launch_zone_dist_dgft_max() > 0.0
    let maxDist = get_radar_hud_aam_launch_zone_dist_max()
    let minDist = get_radar_hud_aam_launch_zone_dist_min()
    let maxNoEscapeRange = get_radar_hud_aam_launch_zone_dist_dgft_max()
    let curDist = get_radar_hud_aam_launch_zone_dist()
    let curDistAngle = PI - clamp(curDist, 0.0, 1.0) * PI2
    let minDistAngle = PI - clamp(minDist, 0.0, 1.0) * PI2
    let maxDistAngle = PI - clamp(maxDist, 0.0, 1.0) * PI2
    let maxNoEscapeAngle = PI - clamp(maxNoEscapeRange, 0.0, 1.0) * PI2

    let halfLineWidthRel = 0.5 * defaultLineWidthHdpxRel
    setLineWidth(1.5 * defaultLineWidth)
    drawSector(pos, float2(radius - halfLineWidthRel), float2(-PI_2, PI_2 - curDistAngle))
    setLineWidth(defaultLineWidth)
    var dir = float2(0.0, -1.0)
    let serifLength = 0.015
    drawLine(pos + dir * radius, pos + dir * (radius - serifLength))
    sincos(curDistAngle, dir.x, dir.y)
    drawLine(pos + dir * radius, pos + dir * (radius - serifLength))

    let triangle = fixed_array<float2>(
      float2(0.0, 0.0),
      float2(0.6, 1.0),
      float2(-0.6, 1.0))

    let triangleSize = float2(0.02)
    sincos(maxDistAngle, dir.x, dir.y)
    let curDistTriangleVerts = triangle.to_array().scale(triangleSize).rotate(-dir.x, dir.y).translate(pos + dir * (radius + halfLineWidthRel))
    drawClosedPolyLine(curDistTriangleVerts)
    sincos(minDistAngle, dir.x, dir.y)
    let minDistTriangleVerts = triangle.to_array().scale(triangleSize).rotate(-dir.x, dir.y).translate(pos + dir * (radius + halfLineWidthRel))
    drawClosedPolyLine(minDistTriangleVerts)
    sincos(maxNoEscapeAngle, dir.x, dir.y)
    let maxNoEscapeTriangleVerts = triangle.to_array().scale(triangleSize).rotate(-dir.x, dir.y).translate(pos + dir * (radius + halfLineWidthRel))
    drawClosedPolyLine(maxNoEscapeTriangleVerts)

    popAxes()

    let blinksPerSecond = 2.5
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    let isGuidanceReady = aamGuidance.lockState == GuidanceLockState.RESULT_TRACKING || aamGuidance.lockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH
    let isInRange = curDist > minDist && curDist < maxDist
    if isGuidanceReady && isInRange && isBlink
      setFontSize(defaultFontSize)
      let offset = -0.055 - getFontDescent()
      drawStrAnchored(targetPos + float2(0.0, offset), "SHOOT", AnchorHorz.Center, AnchorVert.Bottom)

    let steeringDir = -toRelXY((tmInv * velRel).zy)
    let steeringDotPos = targetPos + steeringDir
    let lastFillColor = fillColor
    setFillColor(color)
    drawCircle(steeringDotPos, 0.007)
    setFillColor(lastFillColor)


  def drawAamGuidance(position : float2; defaultPos : float2)
    return if !isAamMode || !aamGuidance.isActive || aamGuidance.guidanceType != GuidanceType.TYPE_OPTICAL

    var pos : float2
    let isTracking = int(aamGuidance.lockState) >= int(GuidanceLockState.RESULT_TRACKING)
    if isTracking
      pos = position
    else
      pos = defaultPos

    let radius = 0.04
    let indent = float2(0.75 * radius)
    let outOfCanvas = isOutOfCanvas(pos, indent)

    if outOfCanvas
      let dir = fast_normalize(pos - defaultPos)
      let t = traceRayToCanvasEdges(defaultPos, dir, indent)
      pos = defaultPos + t * dir

    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    if !outOfCanvas || isBlink
      drawCircle(pos, radius)
