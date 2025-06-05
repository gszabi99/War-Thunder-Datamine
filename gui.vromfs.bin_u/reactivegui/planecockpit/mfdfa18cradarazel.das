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

// elevation over distance
class RadarAzElFormatFrame : Canvas
  frameHalfSizeRel : float2 = float2(0.375)
  scaleMarkLength : float = 0.05
  dugoutHeight : float = 0.05
  targetBoxHalfSize : float2 = float2(0.025, 0.01)
  baseScale : float = 0.95
  buttonCollumnX = array<float>(
    -0.32, -0.16, 0.0, 0.16, 0.32
  )
  buttonRowY = array<float>(
    -0.32, -0.14, 0.0, 0.2, 0.35
  )

  unit : Unit?
  fmw : FlightModelWrap?

  baseColor : E3DCOLOR

  halfSizeAzimuthDeg : float = 0.0

  ownshipHeading : float = 0.0
  ownshipAltitude : float = 0.0

  azimuthMin : float = 0.0
  azimuthMax : float = 0.0
  azimuthTotalCoverage : float = 0.0

  isEmitting : bool = false

  elevationScaleHalfRange : float = 20.0
  elevationScaleMin : float = -20.0
  elevationScaleMax : float = 20.0

  minElevation : float = 0.0
  maxElevation : float = 0.0

  minScanElevation : float = 0.0
  maxScanElevation : float = 0.0

  def RadarAzElFormatFrame(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    scaleMarkLength = data.scaleMarkLength
    dugoutHeight = data.dugoutHeight
    baseScale = data.baseScale
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

    isEmitting = get_radar_hud_is_emitting()
    return if !isEmitting

    azimuthMin = get_radar_hud_azimuth_min() * radToDeg
    azimuthMax = get_radar_hud_azimuth_max() * radToDeg
    azimuthTotalCoverage = azimuthMax - azimuthMin

    minElevation = get_radar_hud_elevation_min() * radToDeg
    maxElevation = get_radar_hud_elevation_max() * radToDeg

    minScanElevation = get_radar_hud_scan_elevation_min() * radToDeg
    maxScanElevation = get_radar_hud_scan_elevation_max() * radToDeg

    let scanCenterElevation = (minScanElevation + maxScanElevation) * 0.5

    if scanCenterElevation > maxElevation - elevationScaleHalfRange
      elevationScaleMax = maxElevation
      elevationScaleMin = maxElevation - 2.0 * elevationScaleHalfRange
    elif scanCenterElevation < minElevation + elevationScaleHalfRange
      elevationScaleMax = minElevation + 2.0 * elevationScaleHalfRange
      elevationScaleMin = minElevation
    else
      elevationScaleMin = scanCenterElevation - elevationScaleHalfRange
      elevationScaleMax = scanCenterElevation + elevationScaleHalfRange

  // helpers
  def azimuthToX(deg : float)
    return cvt(deg, -halfSizeAzimuthDeg, halfSizeAzimuthDeg, -0.5, 0.5)

  def azimuthRelToDeg(azimuthRel : float)
    return lerp(azimuthMin, azimuthMax, azimuthRel)

  def degToY(deg : float)
    return cvt(deg, elevationScaleMin, elevationScaleMax, 0.5, -0.5)

  def elRelToDeg(elRel : float)
    return lerp(minElevation, maxElevation, elRel)

  def elevationRelToY(elRel : float)
    let deg = elRelToDeg(elRel)
    return cvt(deg, elevationScaleMin, elevationScaleMax, 0.5, -0.5)
    // todo targets with unknown range are displayed at the dugout

  def toRadarPos(azimuthDeg : float; elRel : float)
    return float2(azimuthToX(azimuthDeg), elevationRelToY(elRel))

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

    setTextAnchorHorz(AnchorHorz.Right)
    setTextAnchorVert(AnchorVert.Top)
    setCaretPosition(float2(-frameHalfSizeRel.x * 0.8, frameHalfSizeRel.y + 0.005))

    let ownshipAirSpeedKnts = fmw.ias * mpsToKnots
    let ownshipAirSpeedKntsText = fmt(":d", roundi(ownshipAirSpeedKnts))
    printStrLn(ownshipAirSpeedKntsText)

    let ownshipAirSpeedMachText = fmt(":.2f", fmw.fm.Mach)
    printStrLn(ownshipAirSpeedMachText)

    let operationalModeText = isEmitting ? "OPR" : "STBY"
    drawStrAnchored(float2(-0.4, -0.46), operationalModeText, AnchorHorz.Right, AnchorVert.Bottom)

    drawStrAnchored(-frameHalfSizeRel + float2(-0.005, 0.0), getModeName(), AnchorHorz.Right, AnchorVert.Top)

    let azCoverageText = fmt(":.0f", azimuthTotalCoverage) + "°"
    drawStrAnchored(float2(buttonCollumnX[1], 0.5), azCoverageText, AnchorHorz.Center, AnchorVert.Bottom)

    let elevationScaleMinText = fmt(":.0f", elevationScaleMin) + "°"
    let elevationScaleMaxText = fmt(":.0f", elevationScaleMax) + "°"

    drawStrAnchored(float2(frameHalfSizeRel.x + 0.02, -frameHalfSizeRel.y - dugoutHeight), elevationScaleMaxText, AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(frameHalfSizeRel + float2(0.02, 0.0), elevationScaleMinText, AnchorHorz.Center, AnchorVert.Top)

    let scanBarsCount = get_radar_scan_bars_count()
    if scanBarsCount > 0
      let scanElevationBarsCountText = "{scanBarsCount}B"
      drawStrAnchored(float2(buttonCollumnX[0], -0.5), scanElevationBarsCountText, AnchorHorz.Center, AnchorVert.Top)

  def drawStatics()
    drawStrAnchored(float2(buttonCollumnX[1], -0.5), "ALL", AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(float2(buttonCollumnX[1], -0.46), "IFF", AnchorHorz.Center, AnchorVert.Top)

    let fovBBox = drawStrAnchored(float2(buttonCollumnX[3], -0.5), "FOV", AnchorHorz.Center, AnchorVert.Top)
    drawBBox(fovBBox, 0.01)

    let IDBox = drawStrAnchored(float2(buttonCollumnX[4], -0.5), "ID", AnchorHorz.Center, AnchorVert.Top)
    drawBBox(IDBox, 0.01)
    drawStrAnchored(float2(buttonCollumnX[4], -0.45), "FULL", AnchorHorz.Center, AnchorVert.Top)

    let leftTextX = -0.46
    let vertTextPadding = 0.005
    let horzPadding = 0.01
    let textBoxPadding = 0.005

    drawStrVerticalAnchored(float2(leftTextX, buttonRowY[1]), "STORES", vertTextPadding, AnchorHorz.Right, AnchorVert.Center)
    drawStrVerticalAnchored(float2(leftTextX + horzPadding, buttonRowY[1]), "DISPLAY", vertTextPadding, AnchorHorz.Left, AnchorVert.Center)

    let LSBBox = drawStrVerticalAnchored(float2(leftTextX, buttonRowY[3]), "L+S", vertTextPadding, AnchorHorz.Right, AnchorVert.Center)
    drawBBox(LSBBox, textBoxPadding)
    drawStrVerticalAnchored(float2(leftTextX + horzPadding, buttonRowY[3]), "INT", vertTextPadding, AnchorHorz.Left, AnchorVert.Center)

    drawStrVerticalAnchored(float2(leftTextX, buttonRowY[4]), "AUTO", vertTextPadding, AnchorHorz.Right, AnchorVert.Center)
    drawStrVerticalAnchored(float2(leftTextX + horzPadding, buttonRowY[4]), "INT", vertTextPadding, AnchorHorz.Left, AnchorVert.Center)

    let rightTextX = 0.46

    drawStrVerticalAnchored(float2(rightTextX, buttonRowY[0]), "EL", vertTextPadding, AnchorHorz.Right, AnchorVert.Center)
    drawStrVerticalAnchored(float2(rightTextX + horzPadding, buttonRowY[0]), "SCALE", vertTextPadding, AnchorHorz.Left, AnchorVert.Center)

    drawArrowHead(float2(rightTextX, buttonRowY[1]), float2(0.0, -1.0), float2(0.025, 0.05))
    drawArrowHead(float2(rightTextX, buttonRowY[2]), float2(0.0, 1.0), float2(0.025, 0.05))

    let IFFRangeY = (buttonRowY[1] + buttonRowY[2]) * 0.5
    drawStrVerticalAnchored(float2(rightTextX - 0.03, IFFRangeY), "IFF", vertTextPadding, AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(rightTextX, IFFRangeY), "80", AnchorHorz.Center, AnchorVert.Center)

    drawStrVerticalAnchored(float2(rightTextX, buttonRowY[4]), "IFF", vertTextPadding, AnchorHorz.Right, AnchorVert.Center)
    drawStrVerticalAnchored(float2(rightTextX + horzPadding, buttonRowY[4]), "DCLTR", vertTextPadding, AnchorHorz.Left, AnchorVert.Center)

    drawStrAnchored(float2(buttonCollumnX[0], 0.5), "EXP", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(buttonCollumnX[3], 0.5), "RSET", AnchorHorz.Center, AnchorVert.Bottom)

  def drawFrame()
    setFillColor(TRANSPARENT)
    drawBox(float2(-0.5, -0.5), float2(0.5, -0.5 - dugoutHeight)) // dugout
    drawBox(float2(-0.5, -0.5), float2(0.5, 0.5)) // main box

  def drawScales()
    setViewport(float2(-0.5, -0.5), float2(0.5, 0.5))

    let azimuthMarks = array<float>(
      -60.0, -30.0, 0.0, 30.0, 60.0
    )

    let horizonY = clamp(degToY(0.0), -0.5, 0.5)

    for azimuthMark in azimuthMarks
      let x = azimuthToX(azimuthMark)
      drawLine(float2(x, horizonY - scaleMarkLength), float2(x, horizonY + scaleMarkLength))
    drawLine(float2(-0.5, horizonY), float2(0.5, horizonY))

    restoreViewport()

  def drawInstantaneousAzimuth() // B-sweep
    let instantaneousAzimuth = azimuthRelToDeg(get_radar_hud_azimuth())
    let azimuthX = azimuthToX(instantaneousAzimuth)
    drawLine(float2(azimuthX, -0.5 - dugoutHeight - 0.005), float2(azimuthX, 0.5))

  def drawRadarFoV()
    let minAz = azimuthToX(get_radar_hud_scan_azimuth_min() * radToDeg)
    let maxAz = azimuthToX(get_radar_hud_scan_azimuth_max() * radToDeg)
    setColor(yellow)
    drawBox(float2(minAz, degToY(minScanElevation)), float2(maxAz, degToY(maxScanElevation)))
    setColor(baseColor)

  def drawTargets()
    setViewport(float2(-0.5, -0.5 - dugoutHeight), float2(0.5, 0.5))

    foreach_targets() <| $(var target; i)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        var azimuth = 0.0
        if get_radar_hud_has_azimuth_scale()
          azimuth = azimuthRelToDeg(target.azimuthRel)

        let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
        let alphaColor = (1. - target.ageRel) * signalRel

        let targetPos = toRadarPos(azimuth, target.elevationRel)

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
    restoreViewport()

  def draw()
    pushAxes(toAbsPos(float2(0.0, 0.0)), canvasSize * baseScale)
    drawState()
    drawStatics()

    let size = toAbsXY(frameHalfSizeRel * 2.0)
    let pos = toAbsPos(float2(0.0, 0.0))
    pushAxes(pos, size) // [-0.5. 0.5]
    drawFrame()
    drawScales()
    drawInstantaneousAzimuth()
    drawRadarFoV()
    drawTargets()

    popAxes()
    popAxes()


[export]
def render(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  new RadarAzElFormatFrame(ctx, rdata, rstate, data).draw()

[export]
def setup(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", get_hud_color())
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.lineWidth = props |> getFloat("lineWidth", 1.) * 1.
  storage.scaleMarkLength = props |> getFloat("scaleMarkLength", 0.05)
  storage.dugoutHeight = props |> getFloat("dugoutHeight", 0.05)
  storage.baseScale = props |> getFloat("baseScale", 0.95)
