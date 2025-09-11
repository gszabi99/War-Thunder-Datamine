require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.radar_common
require DagorStdGuiRender
require DagorMath
require math
require hud
require darg
require RadarHud
require HeroManager
require FlightModelWrap
require Unit
require strings
require app
require WTCamera
require DagorDebug3D
require Sensors

struct CanvasParams
  fontId : int = 0

struct Props
  bgColor : E3DCOLOR = E3DCOLOR(0x01013a11)
  lineGradientEdgeColor : E3DCOLOR = E3DCOLOR(0x000000)
  elementColor : E3DCOLOR = E3DCOLOR(0x01448044)
  markingsColor : E3DCOLOR = E3DCOLOR(0xFF000000)

  elementsLineWidth : float = 3.0
  markingsLineWIdth : float = 1.0

  radarBoxHalfSize : float2 = float2(0.4, 0.42)
  radarBoxPos : float2 = float2(-0.05, 0.0)

  targetRadius = 0.02
  lockedTargetCrossSize = 0.09

  markingsFontSize : int = 13

class F106Radar : Canvas
  params : CanvasParams = CanvasParams()
  props : Props = Props()

  leftOffset : float = 0.0
  rightOffset : float = 0.0
  topOffset : float = 0.0
  botOffset : float = 0.0
  lt : float2 = float2(0.0)
  rb : float2 = float2(0.0)

  hero : Unit?
  fmw : FlightModelWrap?

  def F106Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; inParams : CanvasParams&; inProps : Props = Props())
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    params = inParams
    props = inProps
    setFont(params.fontId)

    leftOffset = 0.5 + props.radarBoxPos.x - props.radarBoxHalfSize.x
    rightOffset = 1.0 - leftOffset - props.radarBoxHalfSize.x * 2.0
    botOffset = 0.5 + props.radarBoxPos.y - props.radarBoxHalfSize.y
    topOffset = 1.0 - botOffset - props.radarBoxHalfSize.y * 2.0
    lt = props.radarBoxPos - props.radarBoxHalfSize
    rb = props.radarBoxPos + props.radarBoxHalfSize

    hero = get_watched_not_delayed_hero()
    fmw = as_fmw(hero)

  def drawGround()
    let pos = toAbsPos(lt)
    let size = toAbsXY(rb - lt)
    render_ground_reflection(*ctx, size, pos, E3DCOLOR(0xAAAAFFFF), int2(20, 10), true)

  def drawBackground()
    setFillColor(props.bgColor)
    setColor(props.bgColor)
    drawBox(float2(-0.5), float2(0.5))

  def drawAzimuthMarkings()
    let size = float2(toAbsX(props.radarBoxHalfSize.x * 2.0), -canvasSize.y)
    let pos = toAbsPos(float2(props.radarBoxPos.x - props.radarBoxHalfSize.x, 0.5))
    pushAxes(pos, size) // [0, 1] y - up

    let markedLineOffsetBot = botOffset * 0.6
    let markedLineOffsetTop = topOffset * 0.6

    let azimuthRange = (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * radToDeg * 0.5
    let azimuthMarked = fixed_array<float>(-40.0, -20.0, 20.0, 40.0)
    for az in azimuthMarked
      let x = cvt(az, -azimuthRange, azimuthRange, 0.0, 1.0)
      let text = fmt(":d", floori(abs(az)))
      drawLine(float2(x, markedLineOffsetBot), float2(x, botOffset))
      drawStrAnchored(float2(x, 0.01), text, AnchorHorz.Center, AnchorVert.Bottom)

      drawLine(float2(x, 1.0 - markedLineOffsetTop), float2(x, 1.0 - topOffset))
      drawStrAnchored(float2(x, 1.0 - 0.01), text, AnchorHorz.Center, AnchorVert.Top)

    drawLine(float2(0.5, markedLineOffsetBot), float2(0.5, botOffset))
    drawStrAnchored(float2(0.5, 0.01), "0", AnchorHorz.Center, AnchorVert.Bottom)

    let unmarkedLineOffsetBot = botOffset * 0.25
    let unmarkedLineOffsetTop = topOffset * 0.25

    let azimuthUnmarkedBot = fixed_array<float>(-50.0, -30.0, -10.0, 10.0, 30.0, 50.0)
    for az in azimuthUnmarkedBot
      let x = cvt(az, -azimuthRange, azimuthRange, 0.0, 1.0)
      drawLine(float2(x, unmarkedLineOffsetBot), float2(x, botOffset))

    let azimuthUnmarkedTop = fixed_array<float>(-30.0, -10.0, 10.0, 30.0)
    for az in azimuthUnmarkedTop
      let x = cvt(az, -azimuthRange, azimuthRange, 0.0, 1.0)
      drawLine(float2(x, 1.0 - unmarkedLineOffsetTop), float2(x, 1.0 - topOffset))

    let xMinus50Az = cvt(-50.0, -azimuthRange, azimuthRange, 0.0, 1.0)
    drawLine(float2(xMinus50Az, 1.0), float2(xMinus50Az, 1.0 - topOffset * 0.5))

    let xPlus50Az = cvt(50.0, -azimuthRange, azimuthRange, 0.0, 1.0)
    drawLine(float2(xPlus50Az, 1.0), float2(xPlus50Az, 1.0 - topOffset * 0.5))

    drawLine(float2(0.5, 1.0 - unmarkedLineOffsetTop), float2(0.5, 1.0 - topOffset))

    popAxes()

  def getLeftMarkingY(i : int)
    let t = float(i) / float(8)
    return lerp(props.radarBoxPos.y - props.radarBoxHalfSize.y, props.radarBoxPos.y + props.radarBoxHalfSize.y, t)

  def drawLeftMarkings()
    for i in range(1, 8)
      let y = getLeftMarkingY(i)
      let len = i % 2 == 1 ? leftOffset * 0.5 : leftOffset
      drawLine(float2(-0.5 + leftOffset - len, y), float2(-0.5 + leftOffset, y))

    drawStrAnchored(float2(-0.5 + leftOffset, getLeftMarkingY(2) - 0.01), "1", AnchorHorz.Right, AnchorVert.Bottom)
    drawStrAnchored(float2(-0.5 + leftOffset, getLeftMarkingY(2) + 0.01), "2", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(-0.5 + leftOffset * 0.5 - 0.01, getLeftMarkingY(3) + 0.01), "3", AnchorHorz.Right, AnchorVert.Bottom)
    drawStrAnchored(float2(-0.5 + leftOffset * 0.5 - 0.01, getLeftMarkingY(5) + 0.01), "4", AnchorHorz.Right, AnchorVert.Bottom)
    drawStrAnchored(float2(-0.5 + leftOffset, getLeftMarkingY(6) - 0.01), "5", AnchorHorz.Right, AnchorVert.Bottom)
    drawStrAnchored(float2(-0.5 + leftOffset, getLeftMarkingY(6) + 0.01), "6", AnchorHorz.Right, AnchorVert.Top)

  def drawEdges()
    drawLine(float2(-0.5, -0.5 + topOffset * 0.5), float2(-0.4, -0.5 + topOffset * 0.5))
    drawLine(float2(-0.5 + leftOffset, -0.5 + topOffset * 0.5), float2(-0.5 + leftOffset, -0.5 + topOffset))

    drawLine(float2(-0.5, 0.5 - botOffset), float2(-0.4, 0.5 - botOffset))
    drawLine(float2(-0.5 + leftOffset, 0.5 - botOffset), float2(-0.5 + leftOffset, 0.5 - botOffset - topOffset * 0.5))

    drawLine(float2(0.5, -0.5 + topOffset * 0.5), float2(0.5 - rightOffset - 0.05, -0.5 + topOffset * 0.5))
    drawLine(float2(0.5 - rightOffset, -0.5 + topOffset * 0.5), float2(0.5 - rightOffset, -0.5 + topOffset))

    drawLine(float2(0.5, 0.5 - botOffset), float2(0.5 - rightOffset - 0.05, 0.5 - botOffset))
    drawLine(float2(0.5 - rightOffset, 0.5 - botOffset), float2(0.5 - rightOffset, 0.5 - botOffset - topOffset * 0.5))

  def drawRightMarkings()
    let size = float2(toAbsX(rightOffset), -canvasSize.y)
    let pos = toAbsPos(float2(props.radarBoxPos.x + props.radarBoxHalfSize.x, 0.5))
    pushAxes(pos, size) // [0, 1] y - up

    drawStrAnchored(float2(-0.05, 0.93), "ΔH", AnchorHorz.Right, AnchorVert.Bottom)

    drawStrAnchored(float2(0.0, 0.9), "30", AnchorHorz.Right, AnchorVert.Center)
    for i in range(1, 10)
      let t = float(i) / 10.0
      let y = lerp(0.5 + props.radarBoxPos.y - props.radarBoxHalfSize.y, 0.5 + props.radarBoxPos.y + props.radarBoxHalfSize.y, t)
      drawLine(float2(0.0, y), float2(0.25, y))

    drawLine(float2(0.0, 0.5 + props.radarBoxPos.y), float2(1.0, 0.5 + props.radarBoxPos.y))

    drawLine(float2(0.25, 0.9), float2(0.25, 0.5 + props.radarBoxPos.y))
    drawLine(float2(0.3, 0.2), float2(0.3, 0.5 + props.radarBoxPos.y))
    drawStrAnchored(float2(0.3, 0.195), "10", AnchorHorz.Center, AnchorVert.Top)
    drawLine(float2(0.3, 0.0), float2(0.3, 0.17))

    drawLine(float2(0.5, 1.0), float2(0.5, 0.865))
    drawStrAnchored(float2(0.5, 0.86), "20", AnchorHorz.Center, AnchorVert.Top)
    drawLine(float2(0.5, 0.84), float2(0.5, 0.25))
    drawStrAnchored(float2(0.5, 0.245), "5", AnchorHorz.Center, AnchorVert.Top)
    drawLine(float2(0.5, 0.22), float2(0.5, 0.0))

    drawLine(float2(0.75, 1.0), float2(0.75, 0.755))
    drawStrAnchored(float2(0.75, 0.75), "10", AnchorHorz.Center, AnchorVert.Top)
    drawLine(float2(0.75, 0.725), float2(0.75, 0.5))

    drawLine(float2(0.25, 0.87), float2(0.75, 0.68))
    drawStrAnchored(float2(0.77, 0.7), "5", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(0.77, 0.65), "10", AnchorHorz.Left, AnchorVert.Center)
    drawLine(float2(0.25, 0.7), float2(0.75, 0.60))
    drawStrAnchored(float2(0.77, 0.60), "20", AnchorHorz.Left, AnchorVert.Center)
    drawLine(float2(0.25, 0.6), float2(0.75, 0.54))
    drawStrAnchored(float2(0.77, 0.54), "40", AnchorHorz.Left, AnchorVert.Bottom)
    drawLine(float2(0.25, 0.55), float2(0.75, 0.51))

    drawLine(float2(0.33, 0.42), float2(0.5, 0.45))
    drawLine(float2(0.55, 0.45), float2(0.765, 0.45))
    drawStrAnchored(float2(0.77, 0.45), "10", AnchorHorz.Left, AnchorVert.Center)

    drawLine(float2(0.33, 0.335), float2(0.5, 0.4))
    drawLine(float2(0.55, 0.4), float2(0.765, 0.4))
    drawStrAnchored(float2(0.77, 0.4), "5", AnchorHorz.Left, AnchorVert.Center)

    drawLine(float2(0.33, 0.25), float2(0.5, 0.34))
    drawLine(float2(0.55, 0.34), float2(0.765, 0.34))
    drawStrAnchored(float2(0.77, 0.34), "3", AnchorHorz.Left, AnchorVert.Center)

    popAxes()

  def drawMarkings()
    setColor(props.markingsColor)
    setFontSize(props.markingsFontSize)
    setLineWidth(props.markingsLineWIdth)

    drawAzimuthMarkings()
    drawLeftMarkings()
    drawEdges()
    drawRightMarkings()

    let centralOffset = 0.03
    let lineLength = 0.06
    drawLine(props.radarBoxPos - float2(lineLength + centralOffset, 0), props.radarBoxPos - float2(centralOffset, 0))
    drawLine(props.radarBoxPos + float2(lineLength + centralOffset, 0), props.radarBoxPos + float2(centralOffset, 0))

  def isCScope()
    return fmw != null && fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) || get_radar_hud_is_irst()

  def azimuthRelToX(azimuthRel : float)
    return lerp(lt.x, rb.x, azimuthRel)

  def azimuthDegToX(azimuthDeg : float)
    let halfSizeAzimuthDeg = (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * radToDeg * 0.5
    return cvt(azimuthDeg, -halfSizeAzimuthDeg, halfSizeAzimuthDeg, lt.x, rb.x)

  def distRelToY(distRel : float)
    return lerp(rb.y, lt.y, distRel)

  def toRadarPos(azimuthRel : float; distRel : float)
    let x = azimuthRelToX(azimuthRel)
    let y = distRelToY(distRel)
    return float2(x, y)

  def drawCueAt(pos : float2)
    setFillColor(E3DCOLOR(0x00000000))
    setColor(props.elementColor)
    let rad = get_radar_hud_cue_azimuth_half_width_rel() * (rb - lt)
    drawEllipse(pos, rad)

  def drawCue()
    return if isCScope()
    let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
    let cueAzimuth = get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() - get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange, 0.)
    let halfDistGateWidthRel = 0.5 * get_radar_hud_cue_dist_width_rel()
    let distRel = halfDistGateWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - 2. * halfDistGateWidthRel)
    let azimuth = cueAzimuth * radToDeg
    let pos = float2(azimuthDegToX(azimuth), distRelToY(distRel))
    drawCueAt(pos)

  def drawTargets()
    var hasDetectedTarget = false
    Radar`foreach_visible_target() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        var distanceRel = 0.0
        if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
          distanceRel = target.distanceRel

        var azimuthRel = 0.0
        if get_radar_hud_has_azimuth_scale()
          azimuthRel = target.azimuthRel

        let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
        let alphaColor = (1. - target.ageRel) * signalRel

        let targetPos = toRadarPos(azimuthRel, isCScope() ? target.elevationRel : distanceRel)

        let col4 = float4(Color4(props.elementColor)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setFillColor(col)
        setColor(E3DCOLOR(0x00000000))

        drawCircle(targetPos, props.targetRadius)

        if target.isSelected
          setColor(props.elementColor)
          drawCross(targetPos, float2(props.lockedTargetCrossSize))

        if target.isDetected || target.isSelected
          drawCueAt(targetPos)
          hasDetectedTarget = true
    if !hasDetectedTarget && get_radar_hud_cue_visible()
      drawCue()

  def drawCCIP()
    let app = get_app()
    if app == null || hero == null
      return
    if fmw == null || fmw.sightMode != int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS)
      return
    let fcm = app.flightControlMode
    if fcm == null || !fcm.cannonGyroCalculator.isAimValid
      return

    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        let impactPos = fcm.cannonGyroCalculator.aimPoint
        let dirToImpactPos = impactPos - hero.pos
        let localDir = quat_mul_vec(math::quat(inverse(hero.unitTm)), dirToImpactPos)

        let azimuth = atan2(localDir.x, localDir.z) - PI_2
        let elevation = atan2(localDir.y, localDir.xz.length())

        let azimuthRel = cvt(azimuth, get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)
        let elevationRel = cvt(elevation, get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), 0.0, 1.0)

        let CCIPRadarPos = toRadarPos(azimuthRel, elevationRel)

        let targetPos = target.from + target.dirNorm * target.distance

        if target.hasRange
          let err = cross(targetPos - impactPos, target.dirNorm)
          let errorSq = length_sq(err)

          let minErrorSq = 2.0
          let maxErrorSq = 50.0
          let minMarkSizeMult = 0.5
          let maxMarkSizeMult = 1.0

          let CCIPMarkerHalfSize = props.lockedTargetCrossSize * 0.5 * cvt(errorSq, minErrorSq, maxErrorSq, maxMarkSizeMult, minMarkSizeMult)
          drawLine(CCIPRadarPos - float2(0.0, CCIPMarkerHalfSize), CCIPRadarPos + float2(0.0, CCIPMarkerHalfSize))
          drawLine(CCIPRadarPos - float2(CCIPMarkerHalfSize, 0.0), CCIPRadarPos + float2(CCIPMarkerHalfSize, 0.0))
        else
          let CCIPMarkerHalfSize = props.lockedTargetCrossSize * 0.5
          drawLine(CCIPRadarPos - float2(0.0, CCIPMarkerHalfSize), CCIPRadarPos + float2(0.0, CCIPMarkerHalfSize))
          drawLine(CCIPRadarPos - float2(CCIPMarkerHalfSize * 2.0, 0.0), CCIPRadarPos + float2(CCIPMarkerHalfSize, 0.0))

  def drawInstantaneousAzimuth()
    let top = azimuthRelToX(get_radar_hud_azimuth())
    let bottom = azimuthRelToX(get_radar_hud_azimuth())
    drawGradientLine(float2(top, -0.5), float2(bottom, 0.5), 2.0, 6.0)

  def drawHorizon()
    return if fmw == null
    let rotation = -fmw.roll * degToRad
    setRotation(props.radarBoxPos, rotation)
    drawGradientLine(props.radarBoxPos - float2(1.0, 0.0), props.radarBoxPos + float2(1.0, 0.0), 2.0, 6.0)
    resetViewTm()

  def drawBScopeStatus()
    return if isCScope()

    setViewport(props.radarBoxPos - props.radarBoxHalfSize, props.radarBoxPos + props.radarBoxHalfSize)
    setFillColor(props.elementColor)
    setColor(props.lineGradientEdgeColor)
    drawInstantaneousAzimuth()
    drawHorizon()
    restoreViewport()

  def drawHUD()
    setViewport(float2(-0.5), float2(0.5))

    drawGround()

    setLineWidth(props.elementsLineWidth)

    drawTargets()

    restoreViewport()

    drawBScopeStatus()
    drawCCIP()

  def drawMFD()
    drawBackground()
    drawHUD()
    drawMarkings()


[export]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  new F106Radar(ctx, rdata, rstate, data).drawMFD()

[export]
def draw_radar_hud_reflector(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  var props = Props()
  props.radarBoxHalfSize = float2(0.5)
  props.radarBoxPos = float2(0.0)
  new F106Radar(ctx, rdata, rstate, data, props).drawHUD()

[export, unused_argument(props), unused_argument(storage)]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()