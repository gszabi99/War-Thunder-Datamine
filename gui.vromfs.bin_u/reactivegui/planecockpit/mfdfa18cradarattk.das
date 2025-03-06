require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.radar_common
require %rGui.planeCockpit.mfdFA18C_common
require darg
require DagorStdGuiRender
require math
require DagorMath
require RadarHud
require DagorSystem
require FlightModelWrap
require FlightControl
require RadarHud
require strings
require Unit
require HeroManager
require app
require DagorMathUtils
require GamePhys
require hud

let yellow = E3DCOLOR(Color4(float4(1., 1., 0., 1.)))

def foreach_targets(blk : block<(target : RadarTarget const const#; i : int) : void>)
  get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
    for i, t in iter_range(targets), targets
      invoke(blk, t, i)

// azimuth over distance
class RadarATTKFormatFrame : MfdFA18CBase
  unit : Unit?
  fmw : FlightModelWrap?

  baseColor : E3DCOLOR

  halfSizeAzimuthDeg : float = 0.0

  ownshipHeading : float = 0.0
  ownshipAltitude : float = 0.0

  scanAzimuthMin : float = 0.0
  scanAzimuthTotalCoverage : float = 0.0

  azimuthMin : float = 0.0
  azimuthMax : float = 0.0
  azimuthTotalCoverage : float = 0.0

  verticalRange : float = 1.0 // distance in naitucal miles or velocity in knots

  isEmitting : bool = false

  def RadarATTKFormatFrame(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
    MfdFA18CBase`MfdFA18CBase(self, guiCtx, rdata, rstate)

    baseColor = data.color

    setColor(data.color)
    setFont(data.fontId)
    setFontSize(data.fontSize)
    setLineWidth(data.lineWidth)

    unit = get_watched_not_delayed_hero()
    fmw = as_fmw(unit)
    return if fmw == null

    halfSizeAzimuthDeg = (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * radToDeg * 0.5

    ownshipHeading = norm_ang_deg((dir_to_angles(unit.unitTm[0]).x + PI * 0.5) * radToDeg)
    ownshipAltitude = (unit.unitTm[3].y - get_app().currentScene.waterLevel)

    scanAzimuthMin = get_radar_hud_scan_azimuth_min() * radToDeg
    let scanAzimuthMax = get_radar_hud_scan_azimuth_max() * radToDeg
    scanAzimuthTotalCoverage = scanAzimuthMax - scanAzimuthMin

    azimuthMin = get_radar_hud_azimuth_min() * radToDeg
    azimuthMax = get_radar_hud_azimuth_max() * radToDeg
    azimuthTotalCoverage = azimuthMax - azimuthMin

    verticalRange = get_radar_hud_distance_max() * (get_radar_hud_velocity_search() ? mpsToKnots : kmetrToNavMile)

    isEmitting = get_radar_hud_is_emitting()
    return if !isEmitting

  // helpers
  def azimuthToX(deg : float)
    return cvt(deg, -halfSizeAzimuthDeg, halfSizeAzimuthDeg, -0.5, 0.5)

  def azimuthRelToDeg(azimuthRel : float)
    return lerp(azimuthMin, azimuthMax, azimuthRel)

  def distRelToY(distanceRel : float)
    if distanceRel >= 0.0
      return lerp(0.5, -0.5, distanceRel)
    else
      // targets with unknown range are displayed at the dugout
      return -0.5 - dugoutHeight * 0.5

  def isInDistanceRange(distanceRel : float)
    return distanceRel <= 1.0

  def toRadarPos(azimuthDeg : float; distanceRel : float)
    return float2(azimuthToX(azimuthDeg), distRelToY(distanceRel))

  def getModeName()
    let mode = Radar`getModeName()
    if mode |> find("TWS") != -1
      return "TWS"
    if mode |> find("track") != -1
      return "STT"
    if mode |> find("ACM") != -1
      return "ACM"
    if mode |> find("VS") != -1
      return "VS"
    return "RWS"

  // draw
  def drawState()
    let ownshipHeadingText = fmt(":03d", roundi(ownshipHeading)) + "°"
    drawStrAnchored(float2(0.0, -frameHalfSizeRel.y - dugoutHeight), ownshipHeadingText, AnchorHorz.Right, AnchorVert.Bottom)

    let ownshipAltitudeText = fmt(":d", roundi(ownshipAltitude * metrToFeet))
    drawStrAnchored(frameHalfSizeRel + float2(0.0, 0.005), ownshipAltitudeText, AnchorHorz.Right, AnchorVert.Top)

    setTextAnchorHorz(AnchorHorz.Right)
    setTextAnchorVert(AnchorVert.Top)
    setCaretPosition(float2(-frameHalfSizeRel.x * 0.8, frameHalfSizeRel.y + 0.005))

    let ownshipAirSpeedKnts = fmw.ias * mpsToKnots
    let ownshipAirSpeedKntsText = fmt(":d", roundi(ownshipAirSpeedKnts))
    printStrLn(ownshipAirSpeedKntsText)

    let ownshipAirSpeedMachText = fmt(":.2f", fmw.fm.Mach)
    printStrLn(ownshipAirSpeedMachText)

    let operationalModeText = isEmitting ? "OPR" : "STBY"
    drawStrAnchored(float2(-0.36, -0.46), operationalModeText, AnchorHorz.Right, AnchorVert.Bottom)

    drawStrAnchored(-frameHalfSizeRel + float2(-0.005, 0.0), getModeName(), AnchorHorz.Right, AnchorVert.Top)

    let azCoverageText = fmt(":.0f", azimuthTotalCoverage) + "°"
    drawStrAnchored(float2(buttonCollumnX[1], 0.5), azCoverageText, AnchorHorz.Center, AnchorVert.Bottom)

    let rangeScaleReferenceText = fmt(":.0f", verticalRange)
    drawStrAnchored(float2(frameHalfSizeRel.x + 0.005, -frameHalfSizeRel.y), rangeScaleReferenceText, AnchorHorz.Left, AnchorVert.Center)

    let scanBarsCount = get_radar_scan_bars_count()
    if scanBarsCount > 0
      let scanElevationBarsCountText = "{scanBarsCount}B"
      drawStrAnchored(float2(-0.35, -0.5), scanElevationBarsCountText, AnchorHorz.Left, AnchorVert.Top)

    if get_radar_hud_cue_visible()
      // TDC Control Indicator Diamond
      let size = 0.02
      let pos = float2(frameHalfSizeRel.x + 0.025, -frameHalfSizeRel.y - dugoutHeight - 0.025) + float2(size) * 0.5
      drawLine(pos + float2(size, 0), pos + float2(0, size))
      drawLine(pos + float2(0, size), pos + float2(-size, 0))
      drawLine(pos + float2(-size, 0), pos + float2(0, -size))
      drawLine(pos + float2(0, -size), pos + float2(size, 0))
      drawDot(pos)

  def drawStatics()
    drawStrAnchored(float2(buttonCollumnX[1], -0.5), "SIL", AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(float2(buttonCollumnX[2], -0.5), "ERASE", AnchorHorz.Center, AnchorVert.Top)

    drawStrAnchored(-frameHalfSizeRel - float2(0.0, dugoutHeight), "C11", AnchorHorz.Right, AnchorVert.Bottom)

    drawStrVerticalAnchored(float2(-0.48, 0.15), "RDR", 0.001)
    drawStrVerticalAnchored(float2(-0.44, 0.15), "PRI", 0.001)

    drawStrAnchored(float2(-0.44, 0.27), "HI", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(-0.44, 0.27 + 0.01), "INTL", AnchorHorz.Center, AnchorVert.Top)

    drawStrAnchored(float2(-frameHalfSizeRel.x - 0.015, frameHalfSizeRel.y), "7", AnchorHorz.Right, AnchorVert.Bottom)

    drawStrAnchored(float2(buttonCollumnX[0], 0.5), "MODE", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(buttonCollumnX[3], 0.5), "CHAN", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(buttonCollumnX[4], 0.5), "DATA", AnchorHorz.Center, AnchorVert.Bottom)

    drawArrowHead(float2(0.48, -0.35), float2(0.0, -1.0), float2(0.025, 0.05))
    drawArrowHead(float2(0.48, -0.15), float2(0.0, 1.0), float2(0.025, 0.05))

    drawStrVerticalAnchored(float2(0.48, buttonRowY[2]), "SET", 0.001)
    drawStrVerticalAnchored(float2(0.48, buttonRowY[3]), "RESET", 0.001)
    let NCTRbbox = drawStrVerticalAnchored(float2(0.48, buttonRowY[4]), "NCTR", 0.001)
    drawBBox(NCTRbbox)

  def drawSelectedWeapon()
    let rawName = get_hud_cur_weapon_name()
    return if rawName.empty()
    let shellCount = get_hud_cur_weapon_shell_count()
    let name1 = loc("{rawName}/f_15e/1")
    let name2 = loc("{rawName}/f_15e/2")
    drawStrAnchored(float2(frameHalfSizeRel.x, -frameHalfSizeRel.y - dugoutHeight), "{name1}{name2} {shellCount}", AnchorHorz.Right, AnchorVert.Bottom)

  def drawFrame()
    setFillColor(TRANSPARENT)
    drawBox(float2(-0.5, -0.5), float2(0.5, -0.5 - dugoutHeight)) // dugout
    drawBox(float2(-0.5, -0.5), float2(0.5, 0.5)) // main box

  def drawScales()
    let azimuthMarks = array<float>(
      -60.0, -30.0, 0.0, 30.0, 60.0
    )
    for azimuthMark in azimuthMarks
      let x = azimuthToX(azimuthMark)
      let y = -0.5 + scaleMarkLength
      drawLine(float2(x, -0.5), float2(x, y))
      drawLine(float2(x, 0.5), float2(x, -y))

    let rangeMarksRel = array<float>(
      0.25, 0.5, 0.75
    )
    for rangeRel in rangeMarksRel
      let x = -0.5 + scaleMarkLength
      let y = lerp(+0.5, -0.5, rangeRel)
      drawLine(float2(-0.5, y), float2(x, y))
      drawLine(float2(0.5, y), float2(-x, y))

    // antena elevation carret
    let elevationY = lerp(0.5, -0.5, get_radar_hud_elevation())
    let arrowPos = float2(-0.5, elevationY)
    let scanElevationMarkLength : float = 0.025

    drawLine(arrowPos, arrowPos + float2(scanElevationMarkLength, scanElevationMarkLength))
    drawLine(arrowPos, arrowPos + float2(scanElevationMarkLength, -scanElevationMarkLength))

    let scanElevationMarks = array<float>(
      0.25, 0.5, 0.75
    )
    for yRel in scanElevationMarks
      let x = -0.5 - scanElevationMarkLength
      let y = lerp(+0.5, -0.5, yRel)
      drawLine(float2(-0.5, y), float2(x, y))

    let scanElevationSmallerMarks = array<float>(
      0.33, 0.416, 0.58, 0.66
    )
    for yRel in scanElevationSmallerMarks
      let scanElevatioSmallerMarkLength = 0.0125
      let x = -0.5 - scanElevatioSmallerMarkLength
      let y = lerp(+0.5, -0.5, yRel)
      drawLine(float2(-0.5, y), float2(x, y))

  def drawInstantaneousAzimuth() // B-sweep
    let instantaneousAzimuth = azimuthRelToDeg(get_radar_hud_azimuth())
    let azimuthX = azimuthToX(instantaneousAzimuth)
    drawLine(float2(azimuthX, -0.5 - dugoutHeight - 0.005), float2(azimuthX, 0.5))

  def drawTargets()
    setViewport(float2(-0.5, -0.5 - dugoutHeight), float2(0.5, 0.5))

    var drewLaunchZone = false
    foreach_targets() <| $(var target; i)
      if target.targetType == int(RadarTargetType TYPE_TARGET)
        var distanceRel = -1.0
        if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
          distanceRel = target.distanceRel

        var azimuth = 0.0
        if get_radar_hud_has_azimuth_scale()
          azimuth = azimuthRelToDeg(target.azimuthRel)

        let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
        let alphaColor = (1. - target.ageRel) * signalRel

        let targetPos = toRadarPos(azimuth, distanceRel)
        let col4 = float4(Color4(color)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setFillColor(col)
        setColor(col)

        drawBox(targetPos - targetBoxHalfSize, targetPos + targetBoxHalfSize)

        setColor(yellow)
        if target.isSelected
          drawStrAnchored(targetPos, "{i + 1}", AnchorHorz.Center, AnchorVert.Center)

        let padding = 0.01
        if target.isEnemy
          let l = targetPos - float2(targetBoxHalfSize.x + padding, 0.0)
          let r = targetPos + float2(targetBoxHalfSize.x + padding, 0.0)
          let t = targetPos - float2(0.0, targetBoxHalfSize.x + padding)
          drawLine(l, t)
          drawLine(t, r)
        else
          setFillColor(TRANSPARENT)
          drawSector(targetPos, float2(targetBoxHalfSize.x + padding), float2(-PI, 0))

        let targetElevation = target.elevationRel + ownshipAltitude
        if target.losSpeed < 3000.0
          let velDir = float2(-target.losHorSpeed, -target.losSpeed) * 0.0002
          let velocityOffset = normalize(velDir) * 0.03
          drawLine(targetPos + velocityOffset, targetPos + velocityOffset + velDir)

        if target.isDetected || target.isTracked
          let targetAltitudeText = fmt(":.1f", target.height * metrToFeet * 0.001)
          drawStrAnchored(targetPos + float2(0.05, 0.0), targetAltitudeText, AnchorHorz.Left, AnchorVert.Center)

          let taretSpeedSq = target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed + target.losVerSpeed * target.losVerSpeed
          let machVal = sqrt(taretSpeedSq) / atmosphere_sonicSpeed(target.height)
          let machText = fmt(":.1f", machVal)
          drawStrAnchored(targetPos + float2(-0.05, 0.0), machText, AnchorHorz.Right, AnchorVert.Center)

        setColor(baseColor)

        if get_radar_hud_aam_launch_zone_visible() && target.isDetected || target.isTracked && !drewLaunchZone
          let minDistY = distRelToY(get_radar_hud_aam_launch_zone_dist_min())
          let maxDistY = distRelToY(get_radar_hud_aam_launch_zone_dist_max())

          drawLine(float2(targetPos.x, minDistY), float2(targetPos.x, maxDistY))

          let aamLaunchZoneWidth = 0.1
          let lMax = float2(targetPos.x - aamLaunchZoneWidth, maxDistY)
          let rMax = float2(targetPos.x + aamLaunchZoneWidth, maxDistY)
          drawLine(lMax, rMax)

          let lMin = float2(targetPos.x - aamLaunchZoneWidth, minDistY)
          let rMin = float2(targetPos.x + aamLaunchZoneWidth, minDistY)
          drawLine(lMin, rMin)

          drewLaunchZone = true
    restoreViewport()

  def drawThrottleDesignatorController()
    return if !get_radar_hud_cue_visible()

    let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
    let cueAzimuth = get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() - get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange, 0.)

    let halfDistGateWidthRel = 0.5 * get_radar_hud_cue_dist_width_rel()
    let distRel = halfDistGateWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - 2. * halfDistGateWidthRel)
    let cueAzimuthMin = (cueAzimuth - get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange) * radToDeg
    let cueAzimuthMax = (cueAzimuth + get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange) * radToDeg
    let radiusMin = distRel - halfDistGateWidthRel
    let radiusMax = distRel + halfDistGateWidthRel

    let azimuth = cueAzimuth * radToDeg
    let pos = toRadarPos(azimuth, distRel)

    setColor(yellow)
    let lt = toRadarPos(cueAzimuthMin, radiusMax)
    let lb = toRadarPos(cueAzimuthMin, radiusMin)
    drawLine(lt, lb)

    let rt = toRadarPos(cueAzimuthMax, radiusMax)
    let rb = toRadarPos(cueAzimuthMax, radiusMin)
    drawLine(rt, rb)

    var hmin = 0.0
    var hmax = 0.0
    if Radar`getCueHeights(hmin, hmax)
      let hmaxText = fmt(":d", roundi(hmax * metrToFeet * 0.001))
      drawStrAnchored((lt + rt) * 0.5, hmaxText, AnchorHorz.Center, AnchorVert.Bottom)

      let hminText = fmt(":d", roundi(hmin * metrToFeet * 0.001))
      drawStrAnchored((lb + rb) * 0.5, hminText, AnchorHorz.Center, AnchorVert.Top)

    setColor(baseColor)
    drawTDCBearingAngle(azimuth, distRel)

  def drawTDCBearingAngle(azimuthDelta : float; distOrVelRel : float)
    let azimuth = norm_ang_deg(ownshipHeading + azimuthDelta)
    let azimuthText = fmt(":d", roundi(azimuth)) + "°"

    let dist = distOrVelRel * verticalRange
    let distanceText = fmt(":.1f", dist)

    let bearingDataText = "BRA    " + azimuthText + "/" + distanceText
    drawStrAnchored(float2(-0.5 + scaleMarkLength + 0.01, 0.5 - scaleMarkLength - 0.01), bearingDataText, AnchorHorz.Left, AnchorVert.Bottom)

  def draw()
    pushAxes(toAbsPos(float2(0.0, 0.0)), canvasSize * baseScale)
    drawState()
    drawStatics()
    drawSelectedWeapon()

    let size = toAbsXY(frameHalfSizeRel * 2.0)
    let pos = toAbsPos(float2(0.0, 0.0))
    pushAxes(pos, size) // [-0.5. 0.5]
    drawFrame()
    drawScales()
    drawInstantaneousAzimuth()
    drawTargets()
    drawThrottleDesignatorController()

    popAxes()
    popAxes()


[export, unused_argument(rstate)]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  new RadarATTKFormatFrame(ctx, rdata, rstate, data).draw()

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.lineWidth = props |> getFloat("lineWidth", 1.) * 1.
