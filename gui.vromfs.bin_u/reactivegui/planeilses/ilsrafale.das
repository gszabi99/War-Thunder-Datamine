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
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

let airGunDistance = 1000.0
let groundGunDistance = 2000.0
let bombingDistance = 10000.0

struct PropStorage
  fontId : int
  isMetricUnits : bool
  ilsFovDeg : float

struct Tracking
  isActive : bool
  pos : float3
  distance : float
  distanceRate : float
  dirNorm : float3
  angVel : float3
  ilsPosValid : bool
  ilsPos : float2

struct Radar
  isEmitting : bool
  isVerticalScan : bool
  isAcmMode : bool
  isTrkMode : bool
  azimuthMin : float
  azimuthMax : float
  elevationMin : float
  elevationMax : float

struct SensorPoi
  isSet : bool
  pos : float3
  distance : float
  ilsPosValid : bool
  ilsPos : float2

enum TvvType
  Circle
  RoundedBox
  Box

class Component : Canvas
  isValid : bool
  isMetricUnits : bool
  ilsFovDeg : float

  hero : Unit?
  fmw : FlightModelWrap?
  wc : WeaponController?
  secondaryWeapon : Weapon?
  totalTime : float
  tvvPos : float2
  heading : float
  gearProgress : float

  radar : Radar
  tracking : Tracking
  spi : SensorPoi

  isDogFight : bool
  isAirGunMode : bool
  isGroundGunMode : bool
  isAamMode : bool
  isBombingCcrpMode : bool
  isBombingCcipMode : bool
  isBombingGuidedMode : bool

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    fmw = hero.as_fmw()
    wc = hero.weap
    return if fmw == null || wc == null

    isValid = true
    isMetricUnits = props.isMetricUnits
    ilsFovDeg = props.ilsFovDeg
    setColor(*fmw.cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS))
    setLineWidth(floor(6.0 * fmw.cockpit.ilsLineWidthScale))
    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)

    totalTime = float(get_total_time())
    tvvPos = -(float3x3(inverse(hero.unitTm)) * normalize(hero.vel)).zy

    let forward = hero.unitTm[0]
    heading = atan2(forward.x, forward.z)

    if get_point_of_interest(spi.pos)
      spi.isSet = true
      spi.distance = (isMetricUnits ? 0.001 : metrToNavMile) * length(spi.pos - hero.unitTm[3])
      var ilsPos : float2
      if world_to_ils_screen(fmw, spi.pos, ilsPos)
        spi.ilsPosValid = true
        spi.ilsPos = toRelPos(ilsPos)

    gearProgress = fmw.fm.appliedCT.gear

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
        var ilsPos : float2
        if world_to_ils_screen(fmw, tracking.pos, ilsPos)
          tracking.ilsPosValid = true
          tracking.ilsPos = toRelPos(ilsPos)

    radar.isEmitting = get_radar_hud_is_emitting() || get_radar_hud_is_emitting2()
    radar.azimuthMin = get_radar_hud_scan_azimuth_min()
    radar.azimuthMax = get_radar_hud_scan_azimuth_max()
    radar.elevationMin = get_radar_hud_scan_elevation_min()
    radar.elevationMax = get_radar_hud_scan_elevation_max()
    radar.isAcmMode = find(get_radar_hud_mode_name(), "ACM") >= 0
    radar.isTrkMode = find(get_radar_hud_mode_name(), "track") >= 0
    radar.isVerticalScan = radar.elevationMax - radar.elevationMin > 2.0 * (radar.azimuthMax - radar.azimuthMin)

    isAirGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS)

    isGroundGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS)

    isAamMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (secondaryWeapon == null || secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)))

    isDogFight = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (radar.isAcmMode || (radar.isTrkMode && tracking.isActive && tracking.distance < 2.0 * airGunDistance))))

    isBombingCcrpMode = spi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) &&
      (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)))

    isBombingCcipMode = !spi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS) &&
       (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)))

    isBombingGuidedMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) &&
      (secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))))


  def drawTvvMark(tvvType : TvvType)
    let sideLines = 0.05
    let upLine = 0.022
    var rbVec : float2

    if tvvType == TvvType.Box
      rbVec = float2(0.015, 0.012)
      drawBox(tvvPos - rbVec, tvvPos + rbVec)
    elif tvvType == TvvType.RoundedBox
      rbVec = float2(0.015, 0.012)
      let rounding = 0.01
      drawRoundedBox(tvvPos - rbVec, tvvPos + rbVec, float4(rounding))
    else
      rbVec = float2(0.012, 0.012)
      drawCircle(tvvPos, rbVec.x)

    let horzLineStart = float2(rbVec.x, 0.0)
    let horzLineEnd = float2(sideLines, 0.0)
    let vertLineStart = float2(0.0, rbVec.y)
    let vertLineEnd = float2(0.0, upLine)
    drawLine(tvvPos - horzLineStart, tvvPos - horzLineEnd)
    drawLine(tvvPos + horzLineStart, tvvPos + horzLineEnd)
    drawLine(tvvPos - vertLineStart, tvvPos - vertLineEnd)
    let showGear = gearProgress > 0.0 && fract(gearProgress * 10.0) < 0.5

    if showGear
      let legOffset = 0.038
      let downLine = 0.018
      let sizeLegStart = float2(legOffset, 0.0)
      let sideLegEnd = float2(legOffset, downLine)
      let inv = float2(-1.0, 1.0)
      drawLine(tvvPos + inv * sizeLegStart, tvvPos + inv * sideLegEnd)
      drawLine(tvvPos + sizeLegStart, tvvPos + sideLegEnd)
      drawLine(tvvPos + float2(0.0, rbVec.y), tvvPos + float2(0.0, downLine))


  def convertAltitude(alt : float)
    let roundTo = 10.0
    let h = min(99999.0, roundTo * 0.5 + alt * (isMetricUnits ? 1.0 : metrToFeet))
    return h - (h % roundTo) - roundTo * 0.5

  def drawRadarAltitude()
    return if abs(fmw.roll) > 60.0 || abs(fmw.tangage) > 30.0

    let pos = float2(0.25, -0.18)
    let radarAltitude = convertAltitude(fmw.fm.currentAlt)
    let altStr = fmt(":>5d", roundi(radarAltitude))
    setTextAnchorHorz(AnchorHorz.Left)
    setFontSize(40)
    drawStr(pos, "H{altStr}", 6)


  def drawBarometricAltitude()
    let pos = float2(0.3, -0.33)
    let radius = 0.08
    let smallerFontSize = 35
    let biggerFontSize = roundi(1.25 * float(smallerFontSize))
    let halfDotSize = 0.003
    let barometricAltitude = convertAltitude(hero.unitTm[3].y - get_app().currentScene.waterLevel)

    for i in range(0, 10)
      let angle = PI2 / 10.0 * float(i)
      var sina, cosa : float
      sincos(angle, sina, cosa)
      let dotPos = pos + float2(sina, cosa) * radius
      let lt = dotPos - float2(halfDotSize)
      let rb = dotPos + float2(halfDotSize)
      drawBox(lt, rb)

    let arrowPos = pos + float2(0.0, -radius * 0.95)
    let arrowAngle = PI2 * fract(barometricAltitude / 1000.0)

    let verts = array<float2>(
      arrowPos + radius * float2(0.0, 0.0),
      arrowPos + radius * float2(0.12, 0.28),
      arrowPos + radius * float2(-0.12, 0.28)
    )

    setRotation(pos, arrowAngle)
    drawFilledPoly(verts)
    resetViewTm()

    let altStr = fmt(":>5d", roundi(barometricAltitude))
    setCaretPosition(pos + float2(-0.7 * radius, 0.2 * radius))
    setFontSize(biggerFontSize)
    printStr(altStr, 3)
    setFontSize(smallerFontSize)
    printStr(slice(altStr, 3))


  def drawHeadingTape()
    let pos = float2(0.0, -0.4)
    let size = float2(0.25, 0.06)
    let lt = pos - 0.5 * size
    let rb = pos + 0.5 * size
    let count = 3
    let stepRel = size.x / float(count)
    let heading10deg = (0.5 * float(count + 1) - heading * 36.0 / PI2) % 36.0
    let linesOffset = fract(heading10deg) * stepRel
    let dotsOffset = fract(0.5 + heading10deg) * stepRel
    let lineWidthRel = toRelY(lineWidthHdpx)
    setFontSize(roundi(toAbsY(0.65 * size.y)))
    setViewport(lt, rb)

    for i in range(0, count + 1)
      let x = lt.x + (float(i) - 0.5) * stepRel
      let lineTop = float2(x + linesOffset, rb.y - 0.35 * size.y)
      let lineBottom = float2(x + linesOffset, rb.y - lineWidthRel)
      let dotPos = float2(x + dotsOffset, rb.y - lineWidthRel)
      let str = fmt(":02", (36 - floori(heading10deg) + i) % 36)
      let strSize = getStringSize(str, 2)
      let strPos = lineTop - float2(0.5 * strSize.x, 0.3 * strSize.y)
      drawLine(lineTop, lineBottom)
      drawDot(dotPos)
      drawStr(strPos, str, 2)

    restoreViewport()
    drawLine(float2(pos.x, rb.y - lineWidthRel), float2(pos.x, rb.y + 0.8 * size.y))


  def drawPitchLadder()
    let stepDeg = 5.0
    let stepRel = stepDeg / ilsFovDeg

    let spaceWidth = 0.1
    let markWidth = 0.09
    let dashWidth = 0.01
    let count = roundi(toRelY(length(canvasSize)) / stepRel)
    let tangage5deg = fmw.tangage / 5.0
    let marksVertOffset = fract(tangage5deg) * stepRel
    let markStartX = 0.5 * spaceWidth + markWidth
    let markEndX = 0.5 * spaceWidth
    let roll = fmw.roll * degToRad
    var sina = 0.0
    var cosa = 0.0
    sincos(roll, sina, cosa)
    let tvvRotated = rotate(tvvPos, sina, cosa)
    let zeroPos = float2(tvvRotated.x, 0.0)
    setRotation(float2(0.0), -roll)

    for i in range(-count, count + 1)
      let markTangage5deg = floori(tangage5deg) - i
      if abs(markTangage5deg) > 18
        continue
      let markOffset = marksVertOffset + float(i) * stepRel
      let pos = zeroPos + float2(0.0, markOffset)
      let markEndY = float(markTangage5deg) / 18.0 * markWidth
      if markTangage5deg > 0
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(markEndX, markEndY)
        let p2 = float2(markEndX, markEndY + dashWidth)
        drawLine(pos + p0, pos + p1)
        drawLine(pos + p1, pos + p2)
        drawLine(pos + inv_x(p0), pos + inv_x(p1))
        drawLine(pos + inv_x(p1), pos + inv_x(p2))
      elif markTangage5deg < 0
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(markStartX - 2.5 * dashWidth, 0.0)
        let p2 = float2(markEndX, markEndY)
        let p3 = float2(markEndX, markEndY + dashWidth)
        let adjDashWidth = length(p2 - p1) / 7.0
        drawDashedLine(pos + p0, pos + p1, dashWidth, dashWidth)
        drawDashedLine(pos + p1, pos + p2, adjDashWidth, adjDashWidth)
        drawLine(pos + p2, pos + p3)
        drawDashedLine(pos + inv_x(p0), pos + inv_x(p1), dashWidth, dashWidth)
        drawDashedLine(pos + inv_x(p1), pos + inv_x(p2), adjDashWidth, adjDashWidth)
        drawLine(pos + inv_x(p2), pos + inv_x(p3))
      else // horizon with heading markers
        let headingLineStart = pos - float2(1.0, 0.0)
        let headingLineEnd = pos + float2(1.0, 0.0)
        drawLine(headingLineStart, headingLineEnd)
        let heading5deg = heading * 72.0 / PI2
        let headingMarksHeight = 0.03
        let headingMarksStep = 0.3
        let headingMarksCount = ceili(1.0 / headingMarksStep)
        let headingMarksOffset = -fract(heading5deg) * headingMarksStep
        for j in range(-headingMarksCount, headingMarksCount + 1)
          let headingMarkOffset = headingMarksOffset + float(j) * headingMarksStep
          let headingMarkUp = pos + float2(headingMarkOffset, -0.5 * headingMarksHeight)
          let headingMarkDown = pos + float2(headingMarkOffset, 0.5 * headingMarksHeight)
          drawLine(headingMarkUp, headingMarkDown)

      if markTangage5deg != 0 && markTangage5deg % 2 == 0
        let str = fmt(":02", abs(markTangage5deg * 5))
        let strSize = getStringSize(str, 2)
        let dx = markStartX + 0.005
        let dy = 0.45 * strSize.y
        drawStr(pos + float2(dx, dy), str, 2)
        drawStr(pos + float2(-dx - strSize.x, dy), str, 2)

    resetViewTm()


  def drawSpiMark()
    return if !spi.isSet || !spi.ilsPosValid
    drawCrossReticle(spi.ilsPos, float2(0.05), float2(0.025))


  def drawDistanceToSpi()
    return if !spi.isSet

    let pos = float2(0.49, -0.1)
    let disti = roundi(spi.distance)
    let str = spi.distance >= 10. ? (isMetricUnits ? "{disti} KM" : "{disti} NM") : (isMetricUnits ? "{fmt(":.1f", spi.distance)} KM" : "{fmt(":.1f", spi.distance)} NM")
    setTextAnchorHorz(AnchorHorz.Right)
    setFontSize(30)
    drawStr(pos, str)


  def drawAoa()
    let pos = float2(-0.48, 0.1)
    let aoaStr = fmt(":>5.1f", fmw.fm.aoa)
    setTextAnchorHorz(AnchorHorz.Left)
    drawStr(pos, "AOA{aoaStr}")


  def drawOverload()
    let pos = float2(0.42, 0.1)
    let overload = fmw.fm.localAccel.length() / 9.81 + 1.0
    setCaretPosition(pos)
    printStrLn(" G", 2)
    let overloadStr = fmt(":>3.1f", overload)
    printStr(overloadStr)


  def drawAirSpeed()
    var pos = float2(-0.2, -0.3)
    let indicatedAirSpeed = roundi((isMetricUnits ? mpsToKmh : mpsToKnots) * fmw.ias)
    setFontSize(40)
    setTextAnchorHorz(AnchorHorz.Right)
    drawStr(pos, string(indicatedAirSpeed))

    if fmw.fm.Mach >= 0.4
      pos.y += 0.032
      setFontSize(29, true)
      drawStr(pos, fmt(":4.2f", fmw.fm.Mach), 4)


  def drawRadarStatus()
    return if !radar.isEmitting

    let pos = float2(-0.5, -0.2)
    setFontSize(40)
    setCaretPosition(pos)
    printStr(get_radar_hud_is_irst() ? "MXD" : "RDR", 3)


  def drawOperatingMode()
    setFontSize(40)

    if isDogFight
      setCaretPosition(float2(-0.5, 0.0))
      printStr("DGFT")

    if gearProgress > 0.0 && fmw.isLandingStarted
      setCaretPosition(float2(-0.45, -0.1))
      printStr("APP")
      return


  def drawBulletImpactLines()
    return if !isDogFight || !get_bullet_impact_line_enabled()

    let absMul = 0.01 * canvasSize
    var bulletImpactLines : array<float2>
    get_bullet_impact_points(0) <| $(var points : array<float2>#)
      for p in points
        if p.x == -1.0 && p.y == -1.0
          continue
        bulletImpactLines.push(toRelPos(p * absMul))


    bulletImpactLines.resize(max(0, bulletImpactLines.length() - 1))
    return if bulletImpactLines.empty()
    drawPolyLine(bulletImpactLines)


  def drawUnifiedTargetMarkWithRange()
    return if !get_ils_target_pos_valid()

    let pos = toRelPos(get_ils_target_pos())
    var dist01 = 0.0
    var distMin01 = 0.0
    var distMax01 = 0.0
    var shouldDraw = false

    if (isAirGunMode || isAamMode) && tracking.isActive && tracking.distance < airGunDistance
      dist01 = clamp(tracking.distance / airGunDistance, 0.0, 1.0)
      distMin01 = 0.0
      distMax01 = 1.0
      shouldDraw = true
    elif isGroundGunMode && !tracking.isActive
      dist01 = clamp(get_hud_dist_to_target() / groundGunDistance, 0.0, 1.0)
      distMin01 = 0.0
      distMax01 = 1.0
      shouldDraw = true
    elif isBombingCcipMode
      dist01 = clamp(get_hud_dist_to_target() / bombingDistance, 0.0, 1.0)
      shouldDraw = true
    elif isBombingGuidedMode
      dist01 = clamp(get_hud_dist_to_target() / bombingDistance, 0.0, 1.0)
      shouldDraw = spi.isSet

    return if !shouldDraw

    let size = 0.2
    let minAngle = -0.5 * PI
    let maxAngle = 1.5 * PI
    let angle = lerp(minAngle, maxAngle, dist01)

    drawCrossReticle(pos, float2(size), float2(0.85 * size))
    drawSector(pos, float2(0.425 * size), float2(minAngle, angle))
    drawCircle(pos, 0.03 * size)

    if isBombingCcipMode
      let p0 = size * float2(0.28, 0.0)
      let p1 = size * float2(0.13, 0.0)
      let p2 = size * float2(0.1, 0.12)
      drawLine(pos + p0, pos + p1)
      drawLine(pos - p0, pos - p1)

      let polyPoints = array<float2>(
        pos + p1,
        pos + inv_y(p2),
        pos - p2,
        pos + inv_x(p1),
        pos + inv_x(p2),
        pos + p2)

      drawClosedPolyLine(polyPoints)
      drawLine(tvvPos, pos)


  def drawTrackingAirTargetMark()
    let size = 0.1
    let dash = 0.3 * size
    let space = size - 2.0 * dash
    let angle = -fmw.roll / 180.0 * PI
    if radar.isTrkMode && tracking.isActive && tracking.ilsPosValid
      let ilsPos = tracking.ilsPos
      var clampedPos : float2
      let isTargetOnScreen = clampPos(ilsPos, clampedPos)

      let blinksPerSecond = 4.0
      let isBlink = fract(blinksPerSecond * totalTime) < 0.5

      let gunTargetSize = 0.7 * size
      let gunTargetDash = 0.24 * gunTargetSize
      let gunTargetSpace = 0.5 * (gunTargetSize - 3.0 * gunTargetDash)
      drawDashedRect(clampedPos, float2(gunTargetSize), float2(gunTargetDash), float2(gunTargetSpace))
      if secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)
        let scale = 1.25
        drawDashedRect(clampedPos, float2(scale * gunTargetSize), float2(scale * gunTargetDash), float2(scale * gunTargetSpace))
      if isTargetOnScreen || isBlink
        drawDashedRect(clampedPos, float2(size), float2(dash), float2(space), angle)
        let tm : float3x3 = float3x3(inverse(hero.unitTm))
        let velRel = tracking.dirNorm * tracking.distanceRate + tracking.angVel * tracking.distance
        let velAbs = hero.vel + velRel
        let velAbsDirection = -fast_normalize((tm * velAbs).zx)
        let velRelDirection = -fast_normalize((tm * velRel).zx)
        drawLine(clampedPos + 0.75 * size * velAbsDirection, clampedPos + 1.75 * size * velAbsDirection)
        drawLine(clampedPos + 0.75 * size * velRelDirection, clampedPos + 1.25 * size * velRelDirection)
      if !isTargetOnScreen
        let arrowOffset = 0.15
        let arrowLength = float2(0.02, 0.06)
        let arrowLineLength = 0.03
        let arrowStart = fast_normalize(clampedPos) * (length(clampedPos) - arrowOffset)
        let arrowEnd = fast_normalize(clampedPos) * (length(clampedPos) - arrowOffset - arrowLineLength)
        drawArrowHead(arrowStart, clampedPos, arrowLength)
        drawLine(arrowStart, arrowEnd)

        let textPos = fast_normalize(clampedPos) * (length(clampedPos) - arrowOffset - arrowLineLength - 0.05)
        let angleToTarget = acos(dot(tracking.dirNorm, hero.unitTm[0])) * radToDeg
        let arrowText = fmt(":03d", roundi(angleToTarget))
        drawStrAnchored(textPos, arrowText, AnchorHorz.Center, AnchorVert.Center)

    elif isDogFight
      drawDashedRect(float2(0.0), float2(size), float2(dash), float2(space), angle)


  def drawTrackingGroundTargetMark()
    return if !tracking.isActive || !tracking.ilsPosValid

    let size = 0.1
    let ilsPos = tracking.ilsPos
    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    var clampedPos : float2
    let isTargetOnScreen = clampPos(ilsPos, clampedPos)
    let gunTargetSize = 0.7 * size
    let gunTargetDash = 0.24 * gunTargetSize
    let gunTargetSpace = 0.5 * (gunTargetSize - 3.0 * gunTargetDash)
    if isTargetOnScreen || isBlink
      drawDashedRect(clampedPos, float2(gunTargetSize), float2(gunTargetDash), float2(gunTargetSpace))


  def drawRadarScanArea()
    return if !radar.isEmitting || radar.isTrkMode

    if radar.isVerticalScan
      let top = float2(0.0, -0.49)
      let bottom = float2(0.0, 0.25)
      let halfWidth = 0.008
      let dash = 0.015
      let space = 0.01
      drawDashedLine(top, bottom, dash, space)
      drawLine(bottom - float2(halfWidth, 0.0), bottom + float2(halfWidth, 0.0))
    elif radar.isAcmMode
      let angleToRelPos = 360.0 / PI2 / ilsFovDeg
      let size = float2(radar.azimuthMax - radar.azimuthMin, radar.elevationMax - radar.elevationMin) * angleToRelPos
      let offset = float2(radar.azimuthMin, radar.elevationMin) * angleToRelPos + size * 0.5
      let dash = size * 0.1
      let space = size - 2.0 * dash
      drawDashedRect(offset, size, float2(dash), float2(space), 0.0)
      drawDashedEllipse(offset, float2(0.3), PI2 / 8.0, PI2 / 8.0, PI / 8.0)


  def drawRadarCross()
    return if !radar.isEmitting || radar.isVerticalScan || radar.isAcmMode || radar.isTrkMode

    let pos = float2(0.4, 0.0)
    let size = 0.12
    var sina, cosa : float
    sincos(-fmw.roll / 180.0 * PI, sina, cosa)
    let voffs = -0.1
    let fuente = 0.03
    let halfRectSize = float2(0.2, 0.5) * float2(radar.azimuthMax - radar.azimuthMin, radar.elevationMax - radar.elevationMin)

    let crossModel = array<float2>(
      float2(-0.5, voffs), float2(0.5, voffs),
      float2(-0.5, voffs - fuente), float2(-0.5, voffs + fuente),
      float2(0.5, voffs - fuente), float2(0.5, voffs + fuente),
      float2(0.0, -0.5), float2(0.0, 0.5),
      float2(-fuente, -0.5), float2(fuente, -0.5),
      float2(-fuente, 0.5), float2(fuente, 0.5),
      float2(-halfRectSize.x, voffs - halfRectSize.y), float2(halfRectSize.x, voffs - halfRectSize.y),
      float2(-halfRectSize.x, voffs + halfRectSize.y), float2(halfRectSize.x, voffs + halfRectSize.y),
      float2(-halfRectSize.x, voffs - halfRectSize.y), float2(-halfRectSize.x, voffs + halfRectSize.y),
      float2(halfRectSize.x, voffs - halfRectSize.y), float2(halfRectSize.x, voffs + halfRectSize.y),
    )

    for i in range(0..length(crossModel) / 2)
      let p0 = rotate(crossModel[i * 2], sina, cosa)
      let p1 = rotate(crossModel[i * 2 + 1], sina, cosa)
      drawLine(pos + size * p0, pos + size * p1)


  def drawSelectedWeapon()
    let pos = float2(-0.3, 0.36)
    setFontSize(40)
    setTextAnchorHorz(AnchorHorz.Left)

    if isAirGunMode || isGroundGunMode
      let bulletsCountPos = float2(-0.01, 0.31)
      let bulletsCount = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
      let bulletsCountText = bulletsCount > 0 ? "{bulletsCount}" : "OUT OF AMMO"
      drawStr(pos, "GUN")
      drawStr(bulletsCountPos, bulletsCountText)
    else
      let rawName = get_hud_cur_weapon_name()
      return if rawName.empty()
      let shellCount = get_hud_cur_weapon_shell_count()
      let name = loc("{rawName}/rafale")
      drawStr(pos, "{shellCount} {name}")


  def drawAttitudeIndicator()
    return if abs(fmw.roll) < 70.0 && fmw.tangage > -30.0 && fmw.tangage < 7.0

    let pos = float2(-0.32, 0.2)
    let radius = 0.02
    let savedColor = color

    setFillColor(color)
    drawCircle(pos, radius)

    setRotation(pos, -fmw.roll / 180.0 * PI)
    setColor(BLACK)
    setFillColor(BLACK)
    let dy = fmw.tangage / 90.0 * radius
    drawBox(pos - float2(radius), pos + float2(radius, dy))
    resetViewTm()

    setColor(savedColor)
    setFillColor(TRANSPARENT)
    drawCircle(pos, radius)


  def drawAamEmTrackingMark()
    let aamLockState = get_aam_guidance_lock_state()
    return if int(aamLockState) <= int(GuidanceLockState.RESULT_STANDBY)

    let guidanceType = get_cur_weapon_guidance_type()
    return if guidanceType != GuidanceType.TYPE_SARH && guidanceType != GuidanceType.TYPE_ARH

    let radius = 0.032
    let pos = get_ils_aam_tracker_visible() ? toRelPos(get_ils_aam_tracker_pos()) : tracking.ilsPos
    var clampedPos : float2
    let isTargetOnScreen = clampPos(pos, clampedPos)
    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    return if isBlink && !isTargetOnScreen

    drawCircle(clampedPos, radius)


  def drawAamIrTrackingMark()
    let aamLockState = get_aam_guidance_lock_state()
    return if int(aamLockState) <= int(GuidanceLockState.RESULT_STANDBY)
    return if get_cur_weapon_guidance_type() != GuidanceType.TYPE_OPTICAL

    let radius = 0.032
    let pos = get_ils_aam_tracker_visible() ? toRelPos(get_ils_aam_tracker_pos()) : tracking.ilsPos
    var clampedPos : float2
    let isTargetOnScreen = clampPos(pos, clampedPos)
    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    return if isBlink && !isTargetOnScreen

    drawCircle(clampedPos, radius)
    if aamLockState == GuidanceLockState.RESULT_TRACKING
      drawCircle(clampedPos, radius * 1.25)


  def drawShootIndicator()
    let guidanceType = get_cur_weapon_guidance_type()
    return if guidanceType != GuidanceType.TYPE_OPTICAL && guidanceType != GuidanceType.TYPE_SARH && guidanceType != GuidanceType.TYPE_ARH

    let aamLockState = get_aam_guidance_lock_state()
    return if aamLockState != GuidanceLockState.RESULT_TRACKING && aamLockState != GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH

    let pos = float2(0.0, 0.2)
    setFontSize(35)
    setTextAnchorHorz(AnchorHorz.Center)
    drawStr(pos, "SHOOT")


  def drawCcrpMark()
    return if !isBombingCcrpMode || !spi.ilsPosValid

    let poiPosLocal = inverse(hero.unitTm) * spi.pos
    let isBehind = poiPosLocal.x < 0.0
    return if isBehind

    let timeMarkWidth = 0.05
    let zeroMarkRadius = 0.005
    let timeToRelease = get_time_before_bomb_release()

    var sina = 0.0
    var cosa = 0.0
    sincos(-fmw.roll * degToRad, sina, cosa)
    let up = float2(sina, -cosa)
    let targetPos = spi.ilsPos
    let rayLength = length(targetPos) + 1.0
    drawLine(targetPos, targetPos + rayLength * up)
    drawLine(targetPos, targetPos - rayLength * up)

    let zeroOffset = dot(up, tvvPos - targetPos)
    let timeOffset = 0.03 * timeToRelease + zeroOffset
    let zeroPos = targetPos + up * zeroOffset
    let timePos = targetPos + up * timeOffset
    let right = float2(cosa, sina)
    let upLeft = timePos - right * timeMarkWidth
    let upRight = timePos + right * timeMarkWidth
    drawCircle(zeroPos, zeroMarkRadius)

    if timeToRelease > 0.0
      drawLine(upLeft, upRight)


  def drawApproachSpeed()
    return if !tracking.isActive
    setFontSize(35)
    setTextAnchorHorz(AnchorHorz.Left)
    let approachSpeed = tracking.distanceRate * (isMetricUnits ? 1.0 : metrToFeet)
    let str = fmt(":>5d", roundi(-approachSpeed))
    let pos = float2(0.12, 0.1)
    let size = getStringSize(str)
    let padding = float2(0.005)
    drawBox(pos - padding, pos + size + padding)
    drawStr(pos + float2(0.0, size.y), str)

  def drawLaunchDistanceIndicator()
    return if (!isAamMode && !isAirGunMode) || !get_radar_hud_aam_launch_zone_visible()

    let distMax = get_radar_hud_aam_launch_zone_dist_max()
    let distMaxDgft = get_radar_hud_aam_launch_zone_dist_dgft_max() / distMax
    let distMin = get_radar_hud_aam_launch_zone_dist_min() / distMax
    let dist = clamp(get_radar_hud_aam_launch_zone_dist() / distMax, 0.0, 1.05)

    let pos = float2(0.25, 0.115)
    let size = float2(0.04, 0.25)
    let mid = pos.x
    let top = pos.y
    let bottom = top + size.y
    let serifRight = mid + 0.25 * size.x
    drawLine(float2(mid, top), float2(serifRight, top))
    drawLine(float2(mid, bottom), float2(serifRight, bottom))
    drawLine(float2(mid, top), float2(mid, bottom))

    let distX = mid + 0.5 * size.x
    let distMinX = mid - 0.5 * size.x
    let distMaxDgftX = mid - 0.75 * size.x
    let distY = bottom - size.y * dist
    let distY1 = distY - 0.25 * size.x
    let distY2 = distY + 0.25 * size.x
    let distMinY = bottom - size.y * distMin
    let distMaxDgftY = bottom - size.y * distMaxDgft
    drawLine(float2(mid, distMinY), float2(distMinX, distMinY))
    drawLine(float2(mid, distMaxDgftY), float2(distMaxDgftX, distMaxDgftY))
    drawLine(float2(mid, distY), float2(distX, distY1))
    drawLine(float2(mid, distY), float2(distX, distY2))

    let distance = tracking.distance * (isMetricUnits ? 0.001 : metrToNavMile)
    let distanceStr = round(distance * 10.0) > 99.0 ? fmt(":>3d", roundi(distance)) : fmt(":>4.1f", distance)
    setFontSize(35)
    setTextAnchorHorz(AnchorHorz.Left)
    drawStr(float2(distX, distY + 0.012), "{distanceStr}")

  def drawCriticalSpeedWarning()
    return if !fmw.isCriticallyLowSpeed

    let blinksPerSecond = 1.5
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    return if !isBlink

    let pos = float2(0, -0.28)
    setTextAnchorHorz(AnchorHorz.Center)
    drawStr(pos, "TOO SLOW")

  def clampPos(pos : float2; var outPos : float2&; lim : float2 = float2(0.4))
    let margin = float2(0.5) - lim
    if isOutOfCanvas(pos, margin)
      let dir = fast_normalize(pos)
      let t  = traceRayToCanvasEdges(float2(0.0), fast_normalize(pos), margin)
      outPos = dir * t
      return false
    outPos = pos
    return true

  def draw()
    return if !isValid

    setFullCanvasViewport()

    drawTvvMark(TvvType.Circle)
    drawRadarAltitude()
    drawBarometricAltitude()
    drawHeadingTape()
    drawPitchLadder()
    drawAoa()
    drawOverload()
    drawDistanceToSpi()
    drawSpiMark()
    drawAirSpeed()
    drawRadarStatus()
    drawOperatingMode()
    drawBulletImpactLines()
    drawTrackingAirTargetMark()
    drawTrackingGroundTargetMark()
    drawRadarScanArea()
    drawRadarCross()
    drawUnifiedTargetMarkWithRange()
    drawSelectedWeapon()
    drawAttitudeIndicator()
    drawAamEmTrackingMark()
    drawAamIrTrackingMark()
    drawCcrpMark()
    drawApproachSpeed()
    drawLaunchDistanceIndicator()
    drawShootIndicator()
    drawCriticalSpeedWarning()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.isMetricUnits = getBool(props, "isMetricUnits", true)
  propStorage.ilsFovDeg = getFloat(props, "ilsFovDeg", 20.0)
