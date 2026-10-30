require %rGui.planeCockpit.radarPage.F101RadarBase_common
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.radar_common
require DagorStdGuiRender
require DagorMath
require math
require darg
require RadarHud
require Sensors
require FlightModelWrap
require Unit


def make_f8e_props()
  var p = Props()
  p.elementsLineWidth = 3.5
  p.markingsLineWidth = 2.0
  p.radarBoxHalfSize = float2(0.495, 0.485)
  p.radarBoxPos = float2(0.0, 0.0)
  return p


class F8ERadar : F101RadarBase
  aspect : float = 1.0
  hasLockedTarget : bool = false
  lockedDistRel : float = 0.0
  lockedDistRate : float = 0.0
  fmw : FlightModelWrap?

  def F8ERadar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_params : PropStorage&)
    F101RadarBase`F101RadarBase(self, guiCtx, rdata, rstate, in_params, make_f8e_props())
    aspect = canvasSize.x / canvasSize.y
    fmw = as_fmw(hero)
    if hero != null
      using() <| $(var toi : TargetOfInterest#)
        if hero.sensors.getSelectedTargetOfInterest(hero.detector, toi)
          lockedDistRate = toi.distanceRate

  def drawCorrectedEllipse(center : float2; radius : float)
    drawEllipse(center, float2(radius, radius * aspect))

  def drawCorrectedArc(center : float2; radius : float; startDeg : float; spanDeg : float)
    let startRad = -(startDeg - 90.0) * degToRad
    let endRad = -(startDeg + spanDeg - 90.0) * degToRad
    let prevFill = fillColor
    setFillColor(E3DCOLOR(0x00000000))
    drawSector(center, float2(radius, radius * aspect), float2(endRad, startRad))
    setFillColor(prevFill)

  def drawDisplayFrame()
    let halfW = props.radarBoxHalfSize.x
    let halfH = props.radarBoxHalfSize.y
    let cornerR = 0.03
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    drawLine(float2(-halfW + cornerR, -halfH), float2(halfW - cornerR, -halfH))
    drawLine(float2(-halfW + cornerR, halfH), float2(halfW - cornerR, halfH))
    drawLine(float2(-halfW, -halfH + cornerR), float2(-halfW, halfH - cornerR))
    drawLine(float2(halfW, -halfH + cornerR), float2(halfW, halfH - cornerR))
    let corners = fixed_array(
      float2(-halfW + cornerR, -halfH + cornerR),
      float2(halfW - cornerR, -halfH + cornerR),
      float2(halfW - cornerR, halfH - cornerR),
      float2(-halfW + cornerR, halfH - cornerR))
    let startAngles = fixed_array(270.0, 0.0, 90.0, 180.0)
    let steps = 8
    let stepDeg = 90.0 / float(steps)
    for center, startA in corners, startAngles
      for i in range(steps)
        let deg0 = startA + float(i) * stepDeg
        let deg1 = startA + float(i + 1) * stepDeg
        drawLine(center + circlePoint(deg0, cornerR), center + circlePoint(deg1, cornerR))

  def drawHorizontalTicks(rowY : float; dir : float)
    let tickLen = 0.042
    let gap = 0.08
    let tickStep = 0.11
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    for i in range(3)
      let x = -gap - float(2 - i) * tickStep
      drawLine(float2(x, rowY), float2(x, rowY + tickLen * dir))
    for i in range(3)
      let x = gap + float(i) * tickStep
      drawLine(float2(x, rowY), float2(x, rowY + tickLen * dir))

  def drawLeftTicks()
    let leftX = -props.radarBoxHalfSize.x
    let halfH = props.radarBoxHalfSize.y
    let tickLen = 0.048
    let numTicks = 7
    let chevronSize = 0.02
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    let step = halfH * 2.0 * 0.85 / float(numTicks - 1)
    let startY = -float(3) * step
    for i in range(numTicks)
      let y = startY + float(i) * step
      drawLine(float2(leftX, y), float2(leftX + tickLen, y))
      if i == 3
        let cx = leftX + tickLen + 0.005 + chevronSize
        drawLine(float2(cx, y - chevronSize), float2(cx - chevronSize, y))
        drawLine(float2(cx - chevronSize, y), float2(cx, y + chevronSize))

  def drawRightTicks()
    let rightX = props.radarBoxHalfSize.x
    let tickLen = 0.048
    let groupStep = 0.04
    let singleOffset = groupStep * 3.25
    let chevronSize = 0.02
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    let groupStartY = -float(2) * groupStep
    for i in range(5)
      let y = groupStartY + float(i) * groupStep
      drawLine(float2(rightX, y), float2(rightX - tickLen, y))
      if i == 2
        let cx = rightX - tickLen - 0.005 - chevronSize
        drawLine(float2(cx, y - chevronSize), float2(cx + chevronSize, y))
        drawLine(float2(cx + chevronSize, y), float2(cx, y + chevronSize))
    let topSingleY = groupStartY - singleOffset
    drawLine(float2(rightX, topSingleY), float2(rightX - tickLen, topSingleY))
    let botSingleY = groupStartY + 4.0 * groupStep + singleOffset
    drawLine(float2(rightX, botSingleY), float2(rightX - tickLen, botSingleY))

  def drawAimingCircle()
    let circR = 0.10
    let dotR = 0.006
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFillColor(E3DCOLOR(0x00000000))
    drawCorrectedEllipse(float2(0.0, 0.0), circR)
    setFillColor(props.markingsColor)
    drawCircle(float2(0.0, 0.0), dotR)
    setFillColor(E3DCOLOR(0x00000000))

  def drawTiltMark()
    let rightX = props.radarBoxHalfSize.x
    let markLen = 0.03
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    drawLine(float2(rightX - markLen, 0.0), float2(rightX, 0.0))

  def drawRangeRateCircle()
    return if !hasLockedTarget
    setColor(props.elementColor)
    setLineWidth(props.markingsLineWidth)
    let rLarge = 0.35
    let distAbs = lockedDistRel * get_radar_hud_distance_max() * 1000.0
    let r = distAbs > 10000.0 ? rLarge : rLarge * 0.6
    let maxClosureRateKts = 1200.0
    let closingSpeedKts = clamp(-lockedDistRate * 1.94384, 0.0, maxClosureRateKts)
    let gapHalf = 7.5
    let gapCenter = 90.0 - (closingSpeedKts / maxClosureRateKts) * 360.0
    let arcStart = gapCenter + gapHalf
    let arcSpan = 360.0 - 2.0 * gapHalf
    drawCorrectedArc(float2(0.0, 0.0), r, arcStart, arcSpan)

  def drawSteeringCircle(pos : float2)
    setFillColor(E3DCOLOR(0x00000000))
    setColor(props.elementColor)
    setLineWidth(props.markingsLineWidth)
    drawCorrectedEllipse(pos, 0.04)

  def override drawTargets()
    let targetR = props.targetRadius * 0.85
    hasLockedTarget = false
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
        let targetPos = toRadarPos(azimuthRel, distanceRel)
        let col4 = float4(Color4(props.elementColor)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setFillColor(col)
        setColor(E3DCOLOR(0x00000000))
        drawEllipse(targetPos, float2(targetR, targetR * aspect))
        if target.isSelected
          hasLockedTarget = true
          lockedDistRel = distanceRel

  def drawHorizonLine()
    setColor(props.elementColor)
    setLineWidth(props.elementsLineWidth)
    let rollRad = fmw != null ? -fmw.roll * degToRad : 0.0
    let pitchOff = fmw != null ? fmw.tangage * 0.003 * aspect : 0.0
    let cosR = cos(rollRad)
    let sinR = sin(rollRad)
    let cy = clamp(pitchOff, -0.3, 0.3)
    let gapHalf = 0.12
    let lineLen = 0.30
    let nx = cosR
    let ny = sinR * aspect
    drawLine(float2(-gapHalf * nx, cy + gapHalf * ny),
             float2(-(gapHalf + lineLen) * nx, cy + (gapHalf + lineLen) * ny))
    drawLine(float2(gapHalf * nx, cy - gapHalf * ny),
             float2((gapHalf + lineLen) * nx, cy - (gapHalf + lineLen) * ny))

  def drawMissileRange()
    return if !hasLockedTarget
    return if !get_radar_hud_aam_launch_zone_visible()
    setColor(props.elementColor)
    setLineWidth(props.elementsLineWidth)
    let strobeLen = 0.06
    let leftEdge = lt.x
    let distMax = get_radar_hud_aam_launch_zone_dist_max()
    if distMax > 0.0
      let yMax = distRelToY(distMax)
      drawLine(float2(leftEdge, yMax), float2(leftEdge + strobeLen, yMax))
    let distMin = get_radar_hud_aam_launch_zone_dist_min()
    if distMin > 0.0
      let yMin = distRelToY(distMin)
      drawLine(float2(leftEdge, yMin), float2(leftEdge + strobeLen, yMin))

  def override drawHud()
    setViewport(float2(-0.5), float2(0.5))
    drawGround()
    restoreViewport()
    setViewport(lt, rb)
    setLineWidth(props.elementsLineWidth)
    drawTargets()
    restoreViewport()
    drawBScopeStatus()
    drawHorizonLine()
    if hasLockedTarget
      drawSteeringCircle(float2(0.0, 0.0))
      drawMissileRange()
    drawRangeRateCircle()

  def override drawMarkings()
    setColor(props.markingsColor)
    setFontSize(props.markingsFontSize)
    setLineWidth(props.markingsLineWidth)
    drawDisplayFrame()
    drawHorizontalTicks(-props.radarBoxHalfSize.y, 1.0)
    drawHorizontalTicks(props.radarBoxHalfSize.y, -1.0)
    drawLeftTicks()
    drawRightTicks()
    drawTiltMark()
    drawAimingCircle()


[export]
def draw_radar_hud(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new F8ERadar(guiCtx, rdata, rstate, props).draw()

[export]
def setup_radar_data(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getFontId()
