require darg
require math
require strings
require app
require hud
require DagorSystem
require DagorMath
require DagorStdGuiRender
require FlightModelWrap
require HeroManager
require Unit
require Sensors
require RadarHud
require Mission
require FlightControl
require Weapon
require %rGui.utils.canvas
require %rGui.utils.constants

let airGunDistance = 1000.0
let groundGunDistance = 2000.0
let bombingDistance = 10000.0

// Adjust this value for each ILS to keep zero line on the horizon when pitching
let ilsFovDeg : float = 18.0

struct PropStorage
  fontId : int
  isMetricUnits : bool

struct Tracking
  isActive : bool = false
  pos : float3 = float3(0.0, 0.0, 0.0)
  distance : float = 0.0
  ilsPosValid : bool = false
  ilsPos : float2 = float2(0.0, 0.0)

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
  isValid : bool = false
  isMetricUnits : bool = true

  hero : Unit? = null
  fmw : FlightModelWrap? = null
  wc : WeaponController? = null
  secondaryWeapon : Weapon? = null
  tvvPos : float2 = float2(0.0, 0.0)
  heading : float = 0.0
  gearProgress : float = 0.0

  radar : Radar
  tracking : Tracking
  spi : SensorPoi

  isDogFight : bool = false
  isAirGunMode : bool = false
  isGroundGunMode : bool = false
  isBombingCcrpMode : bool = false
  isBombingCcipMode : bool = false
  isBombingGuidedMode : bool = false

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    fmw = hero |> as_fmw()
    wc = hero.weap
    return if fmw == null || wc == null

    isValid = true
    isMetricUnits = props.isMetricUnits
    setColor(*fmw.cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS))
    setLineWidth(floor(6.0 * fmw.cockpit.ilsLineWidthScale))
    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)

    tvvPos = -(float3x3(inverse(hero.unitTm)) * normalize(hero.vel)).zy;

    let forward = hero.unitTm[0]
    heading = atan2(forward.x, forward.z)

    if get_point_of_interest(spi.pos)
      spi.isSet = true
      spi.distance = (isMetricUnits ? 1.0 : metrToMile) * length(spi.pos - hero.unitTm[3])
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

    isAirGunMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (secondaryWeapon == null || secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER))))

    isGroundGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS)

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


  def drawRadarAltitude()
    return if abs(fmw.roll) > 60.0 || abs(fmw.tangage) > 30.0

    let pos = float2(0.25, -0.18)
    let radarAltitude = min(99999.0, fmw.fm.alt * (isMetricUnits ? 1.0 : metrToFeet))
    let altStr = fmt(":>5d", roundi(radarAltitude))
    setTextDirection(TextDirection.Right)
    setFontSize(40)
    drawStr(pos, "H{altStr}", 6)


  def drawBarometricAltitude()
    let pos = float2(0.3, -0.33)
    let radius = 0.08
    let smallerFontSize = 35
    let biggerFontSize = roundi(1.25 * float(smallerFontSize))
    let halfDotSize = 0.003
    let barometricAltitude = min(99999.0, hero.unitTm[3].y - get_app().currentScene.waterLevel)

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

    let verts <- array<float2>(
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
    let heading10deg = (0.5 * float(count + 1) - heading * 36.0 / PI2) % 36.0;
    let linesOffset = fract(heading10deg) * stepRel
    let dotsOffset = fract(0.5 + heading10deg) * stepRel
    let lineWidthRel = toRelY(lineWidth)
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
    setRotation(tvvPos, -fmw.roll / 180.0 * PI)

    for i in range(-count, count + 1)
      let markTangage5deg = floori(tangage5deg) - i
      if abs(markTangage5deg) > 18
        continue
      let markOffset = marksVertOffset + float(i) * stepRel
      let pos = tvvPos + float2(0.0, markOffset)
      let markEndY = float(markTangage5deg) / 18.0 * markWidth
      if markTangage5deg > 0
        let p0 = float2(markStartX, 0.0);
        let p1 = float2(markEndX, markEndY);
        let p2 = float2(markEndX, markEndY + dashWidth);
        drawLine(pos + p0, pos + p1)
        drawLine(pos + p1, pos + p2)
        drawLine(pos + invX(p0), pos + invX(p1))
        drawLine(pos + invX(p1), pos + invX(p2))
      elif markTangage5deg < 0
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(markStartX - 2.5 * dashWidth, 0.0)
        let p2 = float2(markEndX, markEndY)
        let p3 = float2(markEndX, markEndY + dashWidth)
        let adjDashWidth = length(p2 - p1) / 7.0
        drawDashedLine(pos + p0, pos + p1, dashWidth, dashWidth)
        drawDashedLine(pos + p1, pos + p2, adjDashWidth, adjDashWidth)
        drawLine(pos + p2, pos + p3)
        drawDashedLine(pos + invX(p0), pos + invX(p1), dashWidth, dashWidth)
        drawDashedLine(pos + invX(p1), pos + invX(p2), adjDashWidth, adjDashWidth)
        drawLine(pos + invX(p2), pos + invX(p3))
      else // horizon with heading markers
        let headingLineStart = pos - float2(1.0, 0.0)
        let headingLineEnd = pos + float2(1.0, 0.0)
        drawLine(headingLineStart, headingLineEnd)
        let heading5deg = heading * 72.0 / PI2;
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
    let str = isMetricUnits ? "{disti} KM" : "{disti} NM"
    setTextDirection(TextDirection.Left)
    setFontSize(30)
    drawStr(pos, str)


  def drawAoa()
    let pos = float2(-0.48, 0.1)
    let aoaStr = fmt(":>5.1f", fmw.fm.aoa)
    setTextDirection(TextDirection.Right)
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
    setTextDirection(TextDirection.Left)
    drawStr(pos, string(indicatedAirSpeed))

    if fmw.fm.mach >= 0.4
      pos.y += 0.032
      setFontSize(29, true)
      drawStr(pos, fmt(":4.2f", fmw.fm.mach), 4)


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
        bulletImpactLines |> push(toRelPos(p * absMul))


    bulletImpactLines |> resize(max(0, bulletImpactLines.length() - 1))
    return if bulletImpactLines |> empty()
    drawPolyLine(bulletImpactLines)


  def drawUnifiedTargetMarkWithRange()
    return if !get_ils_target_pos_valid()

    var pos = toRelPos(get_ils_target_pos())
    var dist01 = 0.0
    var distMin01 = 0.0
    var distMax01 = 0.0
    var shouldDraw = false

    if isAirGunMode && tracking.isActive && tracking.distance < airGunDistance
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

      let polyPoints <- array<float2>(
        pos + p1,
        pos + invY(p2),
        pos - p2,
        pos + invX(p1),
        pos + invX(p2),
        pos + p2)

      drawClosedPolyLine(polyPoints)
      drawLine(tvvPos, pos)


  def drawTrackingAirTargetMark()
    let size = 0.1
    let dash = 0.3 * size
    let space = size - 2.0 * dash
    let angle = -fmw.roll / 180.0 * PI

    if radar.isTrkMode && tracking.isActive && tracking.ilsPosValid
      var ilsPos = tracking.ilsPos
      let blinksPerSecond = 4.0
      let isBlink = fract(blinksPerSecond * float(get_total_time())) < 0.5
      let maxOffs = float2(0.5 - size)
      let clampedPos = clamp(ilsPos, -maxOffs, maxOffs)
      let gunTargetSize = 0.7 * size
      let gunTargetDash = 0.24 * gunTargetSize
      let gunTargetSpace = 0.5 * (gunTargetSize - 3.0 * gunTargetDash)
      drawDashedRect(clampedPos, float2(gunTargetSize), float2(gunTargetDash), float2(gunTargetSpace))
      if secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)
        let scale = 1.25
        drawDashedRect(clampedPos, float2(scale * gunTargetSize), float2(scale * gunTargetDash), float2(scale * gunTargetSpace))
      if clampedPos == ilsPos || isBlink
        drawDashedRect(clampedPos, float2(size), float2(dash), float2(space), angle)

    elif isDogFight
      drawDashedRect(float2(0.0), float2(size), float2(dash), float2(space), angle)


  def drawTrackingGroundTargetMark()
    return if !tracking.isActive || !tracking.ilsPosValid

    let size = 0.1
    let dash = 0.3 * size
    let space = size - 2.0 * dash
    var ilsPos = tracking.ilsPos
    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * float(get_total_time())) < 0.5
    let maxOffs = float2(0.5 - size)
    let clampedPos = clamp(ilsPos, -maxOffs, maxOffs)
    let gunTargetSize = 0.7 * size
    let gunTargetDash = 0.24 * gunTargetSize
    let gunTargetSpace = 0.5 * (gunTargetSize - 3.0 * gunTargetDash)
    if clampedPos == ilsPos || isBlink
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

    let crossModel <- array<float2>(
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
    let rawName = get_hud_cur_weapon_name()
    return if rawName.empty()

    let pos = float2(-0.3, 0.45)
    let shellCount = get_hud_cur_weapon_shell_count()
    let name = loc("{rawName}/rafale")
    setFontSize(40)
    setTextDirection(TextDirection.Right)
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


  def drawAamTrackingMark()
    let aamLockState = get_aam_guidance_lock_state()
    return if aamLockState != GuidanceLockState.RESULT_TRACKING && aamLockState != GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH

    let size = 0.032
    let pos = get_ils_aam_tracker_visible() ? toRelPos(get_ils_aam_tracker_pos()) : tracking.ilsPos
    let maxOffs = float2(0.5 - size)
    let clampedPos = clamp(pos, -maxOffs, maxOffs)
    let guidanceType = get_cur_weapon_guidance_type()
    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * float(get_total_time())) < 0.5
    return if isBlink && clampedPos != pos

    // TODO: make different indications for different guidance types
    if guidanceType == GuidanceType.TYPE_SARH || guidanceType == GuidanceType.TYPE_ARH
      drawCircle(clampedPos, size)

  def drawIrAamSeeker()
    let aamLockState = get_aam_guidance_lock_state()
    if int(aamLockState) <= int(GuidanceLockState.RESULT_STANDBY)
      return
    if get_cur_weapon_guidance_type() != GuidanceType.TYPE_OPTICAL
      return

    let size = 0.032
    let pos = get_ils_aam_tracker_visible() ? toRelPos(get_ils_aam_tracker_pos()) : tracking.ilsPos
    let maxOffs = float2(0.5 - size)
    let clampedPos = clamp(pos, -maxOffs, maxOffs)
    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * float(get_total_time())) < 0.5
    if isBlink && clampedPos != pos
      return
    drawCircle(clampedPos, size)
    if aamLockState != GuidanceLockState.RESULT_TRACKING
      return
    drawCircle(clampedPos, size * 1.25)

  def drawCcrpMark()
    return if !isBombingCcrpMode

    let timeMarkWidth = 0.05
    let zeroMarkRadius = 0.005
    let timeToRelease = get_time_before_bomb_release()
    var sina, cosa : float
    sincos(-fmw.roll / 180.0 * PI, sina, cosa)
    let down = rotate(float2(0.0, 1.0), sina, cosa)
    let right = rotate(float2(timeMarkWidth, 0.0), sina, cosa)
    let targetPos = toRelPos(get_ils_target_pos())
    drawLine(targetPos, targetPos + 10.0 * down)
    drawLine(targetPos, targetPos - 10.0 * down)
    let zeroOffset = dot(-down, tvvPos - targetPos)
    let timeOffset = 0.03 * timeToRelease + zeroOffset
    let zeroPos = targetPos - down * zeroOffset
    let timePos = targetPos - down * timeOffset
    let upLeft = timePos - right
    let upRight = timePos + right
    drawCircle(zeroPos, zeroMarkRadius)

    if timeToRelease > 0.0
      drawLine(upLeft, upRight)


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
    drawAamTrackingMark()
    drawCcrpMark()
    restoreViewport()
    drawIrAamSeeker()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.isMetricUnits = getBool(props, "isMetricUnits", true)
