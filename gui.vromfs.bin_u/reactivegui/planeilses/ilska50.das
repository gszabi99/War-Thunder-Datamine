require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require %rGui.utils.hsd_common
require %rGui.utils.weaponslots_common

require app
require DagorMath
require DagorStdGuiRender
require DagorSystem
require DagorTime
require darg
require FlightControl
require FlightModelWrap
require HeroManager
require math
require %gameLibs.das.math.base
require RadarHud
require Plane
require Sensors
require strings
require Unit
require Weapon
require hud
require WTCamera

enum IlsMode
  defaultMode
  rocketMode
  AGMMode
  cannonMode


let
  HDG_SPAN_DEG       = 30.0   // heading scale width, degrees
  HDG_STEP_DEG       = 5.0    // heading scale tick step
  IAS_SCALE_MAX_KMH  = 500.0  // indicated airspeed scale is fixed, -100..500
  IAS_SCALE_MIN_KMH  = -100.0 // indicated airspeed scale is fixed, -100..500
  IAS_SCALE_STEP_KMH = 100.0  // indicated airspeed scale tick step
  PITCH_REL_PER_DEG  = 0.02   // pitch scale factor - fraction of ILS height per degree
  PITCH_STEP_DEG     = 5.0    // pitch scale tick step
  GEOM_ALT_MAX_M     = 50.0   // geometric altitude scale is shown below this altitude (item 19)
  GEOM_ALT_STEP_M    = 5.0    // geometric altitude scale tick step
  VERT_SPEED_MAX_MPS = 30.0   // vertical speed scale +-30 m/s (VR-30 vario)
  VERT_SPEED_STEP    = 10.0   // vertical speed scale tick step
  OVERLOAD_MIN       = -1.0   // normal load factor scale, lower limit
  OVERLOAD_MAX       = 3.0    // normal load factor scale, upper limit
  OVERLOAD_STEP      = 0.5    // load factor scale tick step
  VEL_VECTOR_MAX_KMH = 50.0   // ground speed vector is shown below this speed (item 31)
  GRAVITY_MPS2       = 9.807  // to convert linear acceleration into load factor
  ILS_PROBE_DIST_M   = 1000.0 // probe point distance used to measure the ILS scale
  ROCKET_RANGE_MAX_M = 4000.0 // range scale limit of the rocket sight mark
  AGM_RANGE_MAX_M    = 10000.0// range scale limit of the ATGM sight mark
  CANNON_RANGE_MAX_M = 2000.0 // range scale limit of the cannon sight mark


struct Colors
  green  = E3DCOLOR(0xFF_00FF00)

struct PropStorage
  fontId : int


class Component : Canvas
  isValid : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  app : AcesApp? = null
  fcm : FlightControlMode? = null
  colors : Colors = Colors()

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    if hero == null
      return

    fmw = hero.as_fmw()
    if fmw == null
      return

    fm = fmw.fm
    if fm == null
      return

    app = get_app()
    if app == null
      return

    fcm = app.flightControlMode
    if fcm == null
      return

    isValid = true
    setLineWidth(1.0)
    setColor(colors.green)
    setOrigin(0.625 * canvasSize) // model is a bit different, center is set visually
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(18)


  def setFontSizeRel(relHeight : float)
    setFontSize(roundi(toAbsY(relHeight)))


  def getGroundSpeedKmh()
    return length(float2(hero.vel.x, hero.vel.z)) * mpsToKmh * (dot(float2(hero.vel.x, hero.vel.z), float2(hero.unitTm[0].x, hero.unitTm[0].z)) >= 0 ? 1.0 : -1.0)


  def getIasKmh()
    return fmw.ias * mpsToKmh * (dot(float2(hero.vel.x, hero.vel.z), float2(hero.unitTm[0].x, hero.unitTm[0].z)) >= 0 ? 1.0 : -1.0)

  def getRadioAltM()
    return float(fm.input.currentAlt)


  def getBaroAltM()
    return hero.unitTm[3].y - app.currentScene.waterLevel


  def getHeadingDeg()
    var hdg = atan2(hero.unitTm[0].x, hero.unitTm[0].z) * radToDeg
    if hdg < 0.0
      hdg += 360.0
    return hdg


  def getVertSpeedMps()
    return fm.vertSpeed

  def getOverload()
    return float(fm.localAccel.y) / GRAVITY_MPS2 + 1.0

  def getVelocityBody()
    var sinHdg = 0.0
    var cosHdg = 0.0
    sincos(atan2(hero.unitTm[0].x, hero.unitTm[0].z), sinHdg, cosHdg)
    let velRight = hero.vel.x * cosHdg - hero.vel.z * sinHdg
    let velFwd = hero.vel.x * sinHdg + hero.vel.z * cosHdg
    return float2(velRight, velFwd)

  def getSelectedTrigger()
    var trigger = -1
    get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
      trigger = weapon?.trigger_no ?? -1
    return trigger

  def getTrackedPointWorld(var worldPos : float3&)
    var hasTarget = false
    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        hasTarget = true
        worldPos = target.from + target.dirNorm * target.distance
    if hasTarget
      return true
    if fcm.ctrlMap.isAimLockEnabled
      worldPos = fcm.ctrlMap.aimLockPos
      return true
    return false

  def getTargetDistM()
    var worldPos = float3(0.0)
    if !getTrackedPointWorld(worldPos)
      return -1.0
    return length(worldPos - hero.pos)

  def isOpticLinkLost()
    return fcm.ctrlMap.isAimLockEnabled && !fcm.ctrlMap.isAimLockInGimbals

  def isAutoTrackActive()
    var worldPos = float3(0.0)
    if !getTrackedPointWorld(worldPos)
      return false
    return !isOpticLinkLost()

  def isLaserRanging()
    return isAutoTrackActive() && fcm.ctrlMap.isLaserDesignatorEnabled

  def isOverspeed()
    let velNeverExceed = fm.cache.wingProps.velNeverExceed
    return velNeverExceed > 0.0 && fm.cache.indSpeed > velNeverExceed

  def isLaunchAllowed()
    let dist = getTargetDistM()
    if dist < 0.0
      return false
    let distMax = get_agm_launch_zone_dist_max()
    if distMax <= 0.0
      return true
    return dist >= get_agm_launch_zone_dist_min() && dist <= distMax

  def getIlsPos(worldPos : float3; var ilsPos : float2&)
    var absPos = float2(0.0)
    if !world_to_ils_screen(fmw, worldPos, absPos)
      return false
    ilsPos = toRelPos(absPos)
    return true

  def getBoresightIlsPos(var ilsPos : float2&)
    return getIlsPos(hero.pos + hero.unitTm[0] * ILS_PROBE_DIST_M, ilsPos)

  def getIlsRelPerRad()
    let probeAngle = 5.0 * degToRad
    var basePos = float2(0.0)
    var probePos = float2(0.0)
    if !getBoresightIlsPos(basePos)
      return 0.0
    let probeDir = hero.unitTm[0] * cos(probeAngle) + hero.unitTm[1] * sin(probeAngle)
    if !getIlsPos(hero.pos + probeDir * ILS_PROBE_DIST_M, probePos)
      return 0.0
    return length(probePos - basePos) / probeAngle

  def getTargetIlsPos(var ilsPos : float2&)
    var worldPos = float3(0.0)
    if !getTrackedPointWorld(worldPos)
      return false
    return getIlsPos(worldPos, ilsPos)

  def getCannonAimIlsPos(var ilsPos : float2&)
    if fcm == null
      return false
    if fcm.isCannonFireDirectionValid
      return getIlsPos((hero.unitTm * fcm.averageCannonPosition) + fcm.cannonAimDirection, ilsPos)
    if fcm.isCannonAimValid
      return getIlsPos(fcm.cannonAimPosition, ilsPos)
    return false

  def getRocketAimIlsPos(var ilsPos : float2&)
    if fcm == null || !fcm.isRocketImpactValid
      return false
    return getIlsPos(fcm.rocketImpactPosition, ilsPos)

  def getAgmAimIlsPos(var ilsPos : float2&)
    var absPos = float2(0.0)
    if !get_ils_agm_tracker_pos(fmw, absPos)
      return false
    ilsPos = toRelPos(absPos)
    return true

  def getIlsMode()
    let trigger = getSelectedTrigger()
    if fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET)
      return IlsMode.defaultMode
    if trigger == int(WeaponTriggerType.AGM_TRIGGER)
      return IlsMode.AGMMode
    if trigger == int(WeaponTriggerType.ROCKETS_TRIGGER)
      return IlsMode.rocketMode
    if (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS))
      return IlsMode.cannonMode
    return IlsMode.defaultMode

// default mode

  def drawGeomAltIndex(pos : float2; size : float2)
    let index <- array<float2>(
      float2(pos.x, pos.y),
      float2(pos.x - size.x, pos.y - 0.5 * size.y),
      float2(pos.x - size.x, pos.y + 0.5 * size.y))
    drawClosedPolyLine(index)

  def drawGeomAltScale(pos : float2; size : float2)
    let altM = getRadioAltM()
    if altM > GEOM_ALT_MAX_M
      return

    let halfHt = 0.5 * size.y
    let topY = pos.y - halfHt
    let bottomY = pos.y + halfHt

    drawLine(float2(pos.x, topY), float2(pos.x, bottomY))

    let stepCount = roundi(GEOM_ALT_MAX_M / GEOM_ALT_STEP_M)
    for i in 0 .. stepCount + 1
      let y = bottomY - float(i) / float(stepCount) * size.y
      let tickLen = (i % 2 == 0) ? size.x : 0.5 * size.x
      drawLine(float2(pos.x, y), float2(pos.x + tickLen, y))

    setFontSizeRel(1.8 * size.x)
    let labelX = pos.x + 1.35 * size.x
    drawStrAnchored(float2(labelX, topY), "{roundi(GEOM_ALT_MAX_M)}", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(labelX, bottomY), "0", AnchorHorz.Left, AnchorVert.Center)

    let indexY = bottomY - clamp(altM, 0.0, GEOM_ALT_MAX_M) / GEOM_ALT_MAX_M * size.y
    drawGeomAltIndex(float2(pos.x, indexY), float2(0.9 * size.x, 1.3 * size.x))

  def drawVertSpeedIndex(pos : float2; size : float2)
    let index <- array<float2>(
      float2(pos.x, pos.y),
      float2(pos.x - size.x, pos.y - 0.5 * size.y),
      float2(pos.x - size.x, pos.y + 0.5 * size.y))
    drawClosedPolyLine(index)

  def drawVertSpeedScale(pos : float2; size : float2)
    let halfHt = 0.5 * size.y
    let topY = pos.y - halfHt
    let bottomY = pos.y + halfHt

    drawLine(float2(pos.x, topY), float2(pos.x, bottomY))

    let stepCount = roundi(2.0 * VERT_SPEED_MAX_MPS / VERT_SPEED_STEP)
    for i in 0 .. stepCount + 1
      let y = bottomY - float(i) / float(stepCount) * size.y
      let tickLen = (i % 3 == 0) ? size.x : 0.5 * size.x
      drawLine(float2(pos.x, y), float2(pos.x + tickLen, y))

    setFontSizeRel(1.8 * size.x)
    let labelX = pos.x + 1.35 * size.x
    drawStrAnchored(float2(labelX, topY), "+{roundi(VERT_SPEED_MAX_MPS)}", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(labelX, pos.y), "0", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(labelX, bottomY), "-{roundi(VERT_SPEED_MAX_MPS)}", AnchorHorz.Left, AnchorVert.Center)

    let vertSpeed = clamp(getVertSpeedMps(), -VERT_SPEED_MAX_MPS, VERT_SPEED_MAX_MPS)
    let indexY = pos.y - vertSpeed / VERT_SPEED_MAX_MPS * halfHt
    drawVertSpeedIndex(float2(pos.x, indexY), float2(0.9 * size.x, 1.3 * size.x))

  def drawOverloadIndex(pos : float2; size : float2)
    let index <- array<float2>(
      float2(pos.x, pos.y),
      float2(pos.x + size.x, pos.y - 0.5 * size.y),
      float2(pos.x + size.x, pos.y + 0.5 * size.y))
    drawClosedPolyLine(index)

  def drawOverloadScale(pos : float2; size : float2)
    let halfHt = 0.5 * size.y
    let topY = pos.y - halfHt
    let bottomY = pos.y + halfHt
    let rangeG = OVERLOAD_MAX - OVERLOAD_MIN

    drawLine(float2(pos.x, topY), float2(pos.x, bottomY))

    let stepCount = roundi(rangeG / OVERLOAD_STEP)
    for i in 0 .. stepCount + 1
      let val = OVERLOAD_MIN + float(i) * OVERLOAD_STEP
      let y = bottomY - (val - OVERLOAD_MIN) / rangeG * size.y
      let isMajor = abs(val - float(roundi(val))) < 0.01
      let tickLen = isMajor ? size.x : 0.5 * size.x
      drawLine(float2(pos.x, y), float2(pos.x - tickLen, y))

    setFontSizeRel(1.8 * size.x)
    let labelX = pos.x - 1.35 * size.x
    let zeroY = bottomY + OVERLOAD_MIN / rangeG * size.y
    drawStrAnchored(float2(labelX, topY), "{roundi(OVERLOAD_MAX)}", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(labelX, zeroY), "0", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(labelX, bottomY), "{abs(roundi(OVERLOAD_MIN))}", AnchorHorz.Right, AnchorVert.Center)

    let overload = clamp(getOverload(), OVERLOAD_MIN, OVERLOAD_MAX)
    let indexY = bottomY - (overload - OVERLOAD_MIN) / rangeG * size.y
    drawOverloadIndex(float2(pos.x, indexY), float2(0.9 * size.x, 1.3 * size.x))

  def drawVelocityVector(pos : float2; size : float)
    if abs(getGroundSpeedKmh()) > VEL_VECTOR_MAX_KMH
      return

    let velBody = getVelocityBody()
    let scale = size / (VEL_VECTOR_MAX_KMH / mpsToKmh)
    let tip = pos + float2(velBody.x * scale, -velBody.y * scale)
    let markRadius = 0.15 * size
    if length(tip - pos) > markRadius
      drawLine(pos, tip)
    drawCircle(pos, markRadius)

  def drawGroundSpeed(pos : float2; size : float2)
    let groundSpeed = getGroundSpeedKmh()
    setFontSizeRel(size.y)
    drawStrAnchored(pos, "{groundSpeed >= 0 ? "+" : "-"}{fmt(":03d", roundi(abs(groundSpeed)))}", AnchorHorz.Left, AnchorVert.Center)

  def drawCmdOverspeed(pos : float2; size : float2)
    setFontSizeRel(size.y)
    drawStrAnchored(pos, "V", AnchorHorz.Left, AnchorVert.Center)


  def drawCmdTargetTracked(pos : float2; size : float2)
    setFontSizeRel(size.y)
    drawStrAnchored(pos, isLaserRanging() ? "ТА-ИД" : "ТА", AnchorHorz.Left, AnchorVert.Center)

  def drawCmdOpticLinkLost(pos : float2; size : float2)
    setFontSizeRel(size.y)
    drawStrAnchored(pos, "П", AnchorHorz.Left, AnchorVert.Center)

  def drawCmdLaunchAllowed(pos : float2; size : float2)
    setFontSizeRel(size.y)
    drawStrAnchored(pos, "С", AnchorHorz.Left, AnchorVert.Center)

  def drawDiscreteCommands(pos : float2; size : float2)
    var line = pos
    if isOverspeed()
      drawCmdOverspeed(line, size)
      line += float2(0.0, size.y)
    if isAutoTrackActive()
      drawCmdTargetTracked(line, size)
      line += float2(0.0, size.y)
    if isOpticLinkLost()
      drawCmdOpticLinkLost(line, size)
      line += float2(0.0, size.y)
    if isLaunchAllowed()
      drawCmdLaunchAllowed(line, size)
      line += float2(0.0, size.y)

// common elements

  def drawAltitude(pos : float2; size : float2)

    let radioAltDisplayThreshold = 300.0

    setFontSizeRel(size.y)
    let radioAltM = getRadioAltM()
    let isRadioAlt = radioAltM < radioAltDisplayThreshold
    let str = isRadioAlt ? "{fmt(":03d", roundi(radioAltM))}р" : "{roundi(getBaroAltM())}"
    drawStrAnchored(pos, str, AnchorHorz.Right, AnchorVert.Center)

  def drawHeadingIndex(pos : float2; size : float2)
    let index <- array<float2>(
      float2(pos.x, pos.y),
      float2(pos.x - 0.5 * size.x, pos.y + size.y),
      float2(pos.x + 0.5 * size.x, pos.y + size.y))
    drawClosedPolyLine(index)

  def drawHeadingScale(pos : float2; size : float2)
    let halfSize = 0.5 * size
    let baseY = pos.y + halfSize.y
    let lt = float2(pos.x - halfSize.x, pos.y - halfSize.y)
    let rb = float2(pos.x + halfSize.x, baseY)
    let hdg = getHeadingDeg()

    drawLine(float2(lt.x, baseY), float2(rb.x, baseY))

    setFontSizeRel(0.55 * size.y)
    setViewport(lt, rb)
    let firstTickDeg = floor((hdg - 0.5 * HDG_SPAN_DEG) / HDG_STEP_DEG) * HDG_STEP_DEG
    let tickCount = roundi(HDG_SPAN_DEG / HDG_STEP_DEG) + 2
    for i in 0 .. tickCount
      let tickHdgDeg = firstTickDeg + float(i) * HDG_STEP_DEG
      let x = pos.x + (tickHdgDeg - hdg) / HDG_SPAN_DEG * size.x
      if x < lt.x || x > rb.x
        continue
      let tickDeg = ((roundi(tickHdgDeg) % 360) + 360) % 360
      let isMajor = (tickDeg % 10 == 0)
      let tickHt = isMajor ? 0.35 * size.y : 0.2 * size.y
      let tickTop = float2(x, baseY - tickHt)
      drawLine(float2(x, baseY), tickTop)
      if isMajor
        drawStrAnchored(tickTop, fmt(":02d", tickDeg / 10), AnchorHorz.Center, AnchorVert.Bottom)
    restoreViewport()

    drawHeadingIndex(float2(pos.x, baseY), float2(0.5 * size.y, 0.4 * size.y))

  def drawIasIndex(pos : float2; size : float2)
    let index <- array<float2>(
      float2(pos.x, pos.y),
      float2(pos.x + size.x, pos.y - 0.5 * size.y),
      float2(pos.x + size.x, pos.y + 0.5 * size.y))
    drawClosedPolyLine(index)

  def drawIasScale(pos : float2; size : float2)
    let halfHt = 0.5 * size.y
    let topY = pos.y - halfHt
    let bottomY = pos.y + halfHt

    drawLine(float2(pos.x, topY), float2(pos.x, bottomY))

    let stepCount = roundi((IAS_SCALE_MAX_KMH - IAS_SCALE_MIN_KMH) / IAS_SCALE_STEP_KMH)
    let stepLen = size.y / float(stepCount)
    let zeroPos = bottomY - stepLen;
    for i in 0 .. stepCount + 1
      let y = bottomY - float(i) * stepLen;
      let tickLen = size.x
      drawLine(float2(pos.x, y), float2(pos.x - tickLen, y))

    setFontSizeRel(1.3 * size.x)
    let labelX = pos.x - 1.35 * size.x
    drawStrAnchored(float2(labelX, topY), "{roundi(IAS_SCALE_MAX_KMH)}", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(labelX, bottomY), "{roundi(IAS_SCALE_MIN_KMH)}", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(labelX, zeroPos), "0", AnchorHorz.Right, AnchorVert.Center)

    let ias = clamp(getIasKmh(), IAS_SCALE_MIN_KMH, IAS_SCALE_MAX_KMH)
    let indexY = bottomY - (ias - IAS_SCALE_MIN_KMH) / (IAS_SCALE_MAX_KMH - IAS_SCALE_MIN_KMH) * size.y
    drawIasIndex(float2(pos.x, indexY), float2(0.9 * size.x, 1.3 * size.x))


  def drawPitchLadder(pos : float2; size : float2)
    let pitchDeg = fmw.tangage
    let outerHalf = 0.5 * size.x
    let innerHalf = 0.28 * size.x
    let minorHalf = 0.14 * size.x
    let horizonHalf = 1.4 * outerHalf
    let degRange = 0.5 * size.y / PITCH_REL_PER_DEG
    let firstMarkDeg = ceil((pitchDeg - degRange) / PITCH_STEP_DEG) * PITCH_STEP_DEG
    let markCount = floori(2.0 * degRange / PITCH_STEP_DEG) + 1

    setFontSizeRel(0.25 * size.x)
    for i in 0 .. markCount
      let markDeg = firstMarkDeg + float(i) * PITCH_STEP_DEG
      if abs(markDeg) > 90.0
        continue
      let mark = roundi(markDeg)
      let y = pos.y + (pitchDeg - markDeg) * PITCH_REL_PER_DEG
      if mark == 0
        drawLine(float2(pos.x - horizonHalf, y), float2(pos.x - innerHalf, y))
        drawLine(float2(pos.x + innerHalf, y), float2(pos.x + horizonHalf, y))
      elif mark % 10 == 0
        drawLine(float2(pos.x - outerHalf, y), float2(pos.x - innerHalf, y))
        drawLine(float2(pos.x + innerHalf, y), float2(pos.x + outerHalf, y))
        drawStrAnchored(float2(pos.x, y), "{abs(mark)}", AnchorHorz.Center, AnchorVert.Center)
      else
        drawLine(float2(pos.x - minorHalf, y), float2(pos.x + minorHalf, y))

  def drawRollScale(pos : float2; size : float)
    let radius = 1.0 * size
    for i in 0 .. 7
      if i == 3
        continue
      let markDeg = float(i) * 30.0
      var sina = 0.0
      var cosa = 0.0
      sincos(markDeg * degToRad, sina, cosa)
      let dir = float2(cosa, sina)
      drawLine(pos + dir * radius, pos + dir * (radius + 0.2 * size))

  def drawAircraftSymbol(pos : float2; size : float)
    var sina = 0.0
    var cosa = 0.0
    sincos(-fmw.roll * degToRad, sina, cosa)

    let halfSpan = 1.0 * size
    let markRadius = 0.5 * size
    let wingInner = 1.0 * markRadius
    drawLine(pos + rotate(float2(-halfSpan, 0.0), sina, cosa), pos + rotate(float2(-wingInner, 0.0), sina, cosa))
    drawLine(pos + rotate(float2(wingInner, 0.0), sina, cosa), pos + rotate(float2(halfSpan, 0.0), sina, cosa))

    let segments = 8
    var prevPoint = pos + rotate(float2(-markRadius, 0.0), sina, cosa)
    for i in 1 .. segments + 1
      let angle = PI * float(i) / float(segments)
      let point = pos + rotate(float2(-markRadius * cos(angle), markRadius * sin(angle)), sina, cosa)
      drawLine(prevPoint, point)
      prevPoint = point

// combat modes

  def drawRangeSector(center : float2; radius : float; relRange : float)
    let startAngle = 1.5 * PI
    setLineWidth(2.0)
    drawSector(center, float2(radius), float2(startAngle, startAngle + 2.0 * PI * clamp(relRange, 0.0, 1.0)))
    setLineWidth(1.0)

  def drawRangeMark(center : float2; radius : float; relRange : float; markLen : float)
    if relRange <= 0.0 || relRange > 1.0
      return
    var sina = 0.0
    var cosa = 0.0
    sincos(1.5 * PI + 2.0 * PI * relRange, sina, cosa)
    let dir = float2(cosa, sina)
    drawLine(center + dir * radius, center + dir * (radius + markLen))

  def drawTargetRange(pos : float2; size : float2)
    let dist = getTargetDistM()
    if dist < 0.0
      return
    setFontSizeRel(size.y)
    drawStrAnchored(pos, "{fmt(":.1f", dist * 0.001)}", AnchorHorz.Left, AnchorVert.Center)

  def drawTargetLosIndex(pos : float2; size : float)
    var ilsPos = float2(0.0)
    if !getTargetIlsPos(ilsPos)
      return
    let markPos = pos + ilsPos
    let halfSize = 0.5 * size
    drawLine(markPos + float2(-halfSize, 0.0), markPos + float2(halfSize, 0.0))
    drawLine(markPos + float2(0.0, -halfSize), markPos + float2(0.0, halfSize))
    drawCircle(markPos, 0.25 * size)

  def drawRocketSight(pos : float2; size : float)
    var ilsPos = float2(0.0)
    if !getRocketAimIlsPos(ilsPos)
      return
    let markPos = pos + ilsPos
    drawCircle(markPos, size)

    let dist = getTargetDistM()
    if dist < 0.0
      return
    drawRangeSector(markPos, 1.4 * size, dist / ROCKET_RANGE_MAX_M)

  def drawAgmSight(pos : float2; size : float)
    var ilsPos = float2(0.0)
    if !getAgmAimIlsPos(ilsPos)
      return
    let markPos = pos + ilsPos
    drawCircle(markPos, size)

    let dist = getTargetDistM()
    if dist < 0.0
      return
    let distMax = get_agm_launch_zone_dist_max()
    let rangeMax = distMax > 0.0 ? distMax : AGM_RANGE_MAX_M
    let ringRadius = 1.4 * size
    drawRangeSector(markPos, ringRadius, dist / rangeMax)
    drawRangeMark(markPos, ringRadius, distMax / rangeMax, 0.5 * size)
    drawRangeMark(markPos, ringRadius, get_agm_launch_zone_dist_min() / rangeMax, 0.5 * size)

  def drawCannonSight(pos : float2; size : float)
    var ilsPos = float2(0.0)
    if !getCannonAimIlsPos(ilsPos)
      return
    let markPos = pos + ilsPos
    drawCircle(markPos, size)
    drawDot(markPos)

    let dist = getTargetDistM()
    if dist < 0.0
      return
    drawRangeSector(markPos, 1.4 * size, dist / CANNON_RANGE_MAX_M)

  def drawSensorFovFrame(pos : float2; size : float2)
    let azMin = get_radar_hud_scan_azimuth_min()
    let azMax = get_radar_hud_scan_azimuth_max()
    let elMin = get_radar_hud_scan_elevation_min()
    let elMax = get_radar_hud_scan_elevation_max()
    if azMax <= azMin || elMax <= elMin
      return

    let relPerRad = getIlsRelPerRad()
    if relPerRad <= 0.0
      return

    var boresight = float2(0.0)
    if !getBoresightIlsPos(boresight)
      return

    let center = pos + boresight + float2(0.5 * (azMin + azMax) * relPerRad, -0.5 * (elMin + elMax) * relPerRad)
    let halfSize = float2(
      max(0.5 * (azMax - azMin) * relPerRad, 0.5 * size.x),
      max(0.5 * (elMax - elMin) * relPerRad, 0.5 * size.y))
    drawBox(center - halfSize, center + halfSize)

  def drawRocketMode(pos : float2; size : float2)
    drawRocketSight(pos, 0.05 * size.x)
    drawTargetLosIndex(pos, 0.04 * size.x)
    drawTargetRange(pos + float2(-0.3 * size.x, 0.3 * size.y), float2(0.15 * size.x, 0.08 * size.y))

  def drawAGMMode(pos : float2; size : float2)
    drawSensorFovFrame(pos, float2(0.25 * size.x, 0.25 * size.y))
    drawAgmSight(pos, 0.05 * size.x)
    drawTargetLosIndex(pos, 0.04 * size.x)
    drawTargetRange(pos + float2(-0.3 * size.x, 0.3 * size.y), float2(0.15 * size.x, 0.08 * size.y))

  def drawCannonMode(pos : float2; size : float2)
    drawCannonSight(pos, 0.04 * size.x)
    drawTargetLosIndex(pos, 0.04 * size.x)
    drawTargetRange(pos + float2(-0.3 * size.x, 0.3 * size.y), float2(0.15 * size.x, 0.08 * size.y))

  def drawCommon(pos : float2; size : float2)
    drawGroundSpeed(pos + float2(-0.45 * size.x, -0.4 * size.y), float2(0.15 * size.x, 0.08 * size.y))
    drawHeadingScale(pos + float2(0.0 * size.x, -0.4 * size.y), float2(0.45 * size.x, 0.08 * size.y))
    drawAltitude(pos + float2(0.45 * size.x, -0.4 * size.y), float2(0.15 * size.x, 0.08 * size.y))
    drawIasScale(pos + float2(-0.3 * size.x, -0.03 * size.y), float2(0.035 * size.x, 0.5 * size.y))
    drawPitchLadder(pos, float2(0.2 * size.x, 0.5 * size.y))
    drawRollScale(pos, 0.2 * size.x)
    drawAircraftSymbol(pos, 0.1 * size.x)
    drawDiscreteCommands(pos + float2(-0.45 * size.x, -0.15 * size.y), float2(0.1 * size.x, 0.07 * size.y))

  def drawDefaultMode(pos : float2; size : float2)
    drawGeomAltScale(pos + float2(0.28 * size.x, 0.0 * size.y), float2(0.035 * size.x, 0.4 * size.y))
    drawVertSpeedScale(pos + float2(0.3 * size.x, 0.0 * size.y), float2(0.03 * size.x, 0.55 * size.y))
    drawOverloadScale(pos + float2(-0.35 * size.x, 0.35 * size.y), float2(0.02 * size.x, 0.18 * size.y))
    drawVelocityVector(pos, 0.25 * size.x)

  def draw(props : PropStorage&)
    if !isValid
      return
    let pos = float2(0.0)
    let size = float2(1.0)
    drawCommon(pos, size)

    let mode = getIlsMode()

    if mode == IlsMode.defaultMode
      drawDefaultMode(pos, size)
    if mode == IlsMode.rocketMode
      drawRocketMode(pos, size)
    if mode == IlsMode.AGMMode
      drawAGMMode(pos, size)
    if mode == IlsMode.cannonMode
      drawCannonMode(pos, size)

    return


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw(props)


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId =  props |> getInt("fontId", 0)
