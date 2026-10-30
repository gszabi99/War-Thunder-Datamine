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


let MAIN_HALF = 0.396
let MAIN_HALF_Y = 0.45
let MAIN_OFS_X = -0.04
let MAIN_OFS_Y = -0.02
let RIGHT_STRIP_W = 0.055
let PARTITION_GAP = 0.02
let BOTTOM_GAP = 0.015


def make_lightning_props()
  var p = Props()
  p.elementsLineWidth = 3.5
  p.markingsLineWidth = 2.0
  p.radarBoxHalfSize = float2(MAIN_HALF, MAIN_HALF_Y)
  p.radarBoxPos = float2(MAIN_OFS_X, MAIN_OFS_Y)
  return p


class LightningRadar : F101RadarBase
  hasLockedTarget : bool = false
  lockedDistRel : float = 0.0
  lockedDistRate : float = 0.0
  fmw : FlightModelWrap?

  def LightningRadar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_params : PropStorage&)
    F101RadarBase`F101RadarBase(self, guiCtx, rdata, rstate, in_params, make_lightning_props())
    fmw = as_fmw(hero)
    if hero != null
      using() <| $(var toi : TargetOfInterest#)
        if hero.sensors.getSelectedTargetOfInterest(hero.detector, toi)
          lockedDistRate = toi.distanceRate

  def drawCorrectedEllipse(center : float2; radius : float)
    drawEllipse(center, float2(radius, radius))

  def drawCorrectedArc(center : float2; radius : float; startDeg : float; spanDeg : float)
    let startRad = -(startDeg - 90.0) * degToRad
    let endRad = -(startDeg + spanDeg - 90.0) * degToRad
    let prevFill = fillColor
    setFillColor(E3DCOLOR(0x00000000))
    drawSector(center, float2(radius, radius), float2(endRad, startRad))
    setFillColor(prevFill)

  def drawRoundedRect(rl : float; rt : float; rr : float; rb : float; cornerR : float; arcSteps : int = 6)
    drawLine(float2(rl + cornerR, rt), float2(rr - cornerR, rt))
    drawLine(float2(rl + cornerR, rb), float2(rr - cornerR, rb))
    drawLine(float2(rl, rt + cornerR), float2(rl, rb - cornerR))
    drawLine(float2(rr, rt + cornerR), float2(rr, rb - cornerR))
    let corners = fixed_array(
      float2(rl + cornerR, rt + cornerR),
      float2(rr - cornerR, rt + cornerR),
      float2(rr - cornerR, rb - cornerR),
      float2(rl + cornerR, rb - cornerR))
    let startAngles = fixed_array(270.0, 0.0, 90.0, 180.0)
    let stepDeg = 90.0 / float(arcSteps)
    for center, startA in corners, startAngles
      for si in range(arcSteps)
        let deg0 = startA + float(si) * stepDeg
        let deg1 = startA + float(si + 1) * stepDeg
        drawLine(center + circlePoint(deg0, cornerR), center + circlePoint(deg1, cornerR))

  def drawDisplayFrame()
    let cx = MAIN_OFS_X
    let cy = MAIN_OFS_Y
    let hx = MAIN_HALF
    let hy = MAIN_HALF_Y
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    drawRoundedRect(cx - hx, cy - hy, cx + hx, cy + hy, 0.025, 8)

  def drawCenterTicks()
    let cx = MAIN_OFS_X
    let cy = MAIN_OFS_Y
    let tickHalfLen = 0.025
    let numTicks = 4
    let startY = cy - 0.14
    let stepY = -0.0765
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    for i in range(numTicks)
      let y = startY + float(i) * stepY
      drawLine(float2(cx - tickHalfLen, y), float2(cx + tickHalfLen, y))

  def drawCenterChevrons()
    let cx = MAIN_OFS_X
    let cy = MAIN_OFS_Y
    let chevronSize = 0.025
    let hx = MAIN_HALF
    let offsetFromEdge = 0.015
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    let lx = cx - hx + offsetFromEdge
    drawLine(float2(lx, cy - chevronSize), float2(lx + chevronSize, cy))
    drawLine(float2(lx + chevronSize, cy), float2(lx, cy + chevronSize))
    let rx = cx + hx - offsetFromEdge
    drawLine(float2(rx, cy - chevronSize), float2(rx - chevronSize, cy))
    drawLine(float2(rx - chevronSize, cy), float2(rx, cy + chevronSize))

  def drawLeftScale()
    let cx = MAIN_OFS_X
    let cy = MAIN_OFS_Y
    let rightEdge = cx - MAIN_HALF
    let tickLen = 0.03
    let labelOfs = -0.01
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.smallFontSize)
    let topY = cy - MAIN_HALF_Y
    let botY = cy + MAIN_HALF_Y
    let numSlots = 9
    let step = (botY - topY) / float(numSlots + 1)
    for i in range(numSlots)
      let y = topY + float(i + 1) * step
      if i % 2 == 0
        let num = 8 - i / 2
        drawStrAnchored(float2(rightEdge - tickLen - labelOfs, y), "{num}", AnchorHorz.Right, AnchorVert.Center)
      else
        drawLine(float2(rightEdge - tickLen, y), float2(rightEdge, y))

  def drawPartition()
    let cx = MAIN_OFS_X
    let cy = MAIN_OFS_Y
    let topY = cy - MAIN_HALF_Y
    let botY = cy + MAIN_HALF_Y
    let partX = cx + MAIN_HALF + PARTITION_GAP * 0.5
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    drawLine(float2(partX, topY), float2(partX, botY))

  def getElevMarkerBounds() : float2
    let cy = MAIN_OFS_Y
    let scalePad = 0.03
    let topY = cy - MAIN_HALF_Y + scalePad
    let botY = cy + MAIN_HALF_Y - scalePad
    let elevMin = get_radar_hud_elevation_min()
    let elevMax = get_radar_hud_elevation_max()
    let elevCur = get_radar_hud_elevation()
    var elevRel = 0.5
    if elevMax > elevMin
      elevRel = clamp((elevCur - elevMin) / (elevMax - elevMin), 0.0, 1.0)
    let markerY = lerp(botY, topY, elevRel)
    let markerH = 0.025
    return float2(markerY - markerH, markerY + markerH)

  def drawRightScale()
    let cx = MAIN_OFS_X
    let cy = MAIN_OFS_Y
    let stripLeft = cx + MAIN_HALF + PARTITION_GAP
    let stripRight = stripLeft + RIGHT_STRIP_W
    let topY = cy - MAIN_HALF_Y
    let botY = cy + MAIN_HALF_Y
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.smallFontSize)
    drawRoundedRect(stripLeft, topY, stripRight, botY, 0.02)
    let scalePad = 0.03
    let numMarks = 6
    let step = (botY - topY - 2.0 * scalePad) / float(numMarks - 1)
    let tickLen = 0.012
    let labelOfs = 0.01
    let rangeVals = fixed_array("40", "30", "20", "10", "0", "10")
    for i in range(numMarks)
      let y = topY + scalePad + float(i) * step
      drawLine(float2(stripRight, y), float2(stripRight + tickLen, y))
      drawStrAnchored(float2(stripRight + tickLen + labelOfs, y), rangeVals[i], AnchorHorz.Left, AnchorVert.Center)
    for i in range(numMarks - 1)
      let y = topY + scalePad + (float(i) + 0.5) * step
      drawLine(float2(stripRight, y), float2(stripRight + tickLen, y))

  def drawBottomScale()
    let cx = MAIN_OFS_X
    let cy = MAIN_OFS_Y
    let padding = 0.04
    let leftX = cx - MAIN_HALF + padding
    let rightX = cx + MAIN_HALF - padding
    let tickTop = cy + MAIN_HALF_Y
    let tickLen = 0.02
    let labelY = tickTop + BOTTOM_GAP + 0.02
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.smallFontSize)
    let numSlots = 11
    let step = (rightX - leftX) / float(numSlots - 1)
    let azLabels = fixed_array("40", "20", "0", "20", "40")
    let shortTick = tickLen * 0.6
    for i in range(numSlots)
      let x = leftX + float(i) * step
      if i % 2 == 1
        let idx = i / 2
        drawLine(float2(x, tickTop), float2(x, tickTop + tickLen))
        drawStrAnchored(float2(x, labelY), azLabels[idx], AnchorHorz.Center, AnchorVert.Center)
      else
        drawLine(float2(x, tickTop), float2(x, tickTop + shortTick))

  def drawElevationMarker()
    let cx = MAIN_OFS_X
    let stripLeft = cx + MAIN_HALF + PARTITION_GAP
    let stripRight = stripLeft + RIGHT_STRIP_W
    let markerBounds = getElevMarkerBounds()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFillColor(E3DCOLOR(0x00000000))
    drawRoundedRect(stripLeft, markerBounds.x, stripRight, markerBounds.y, 0.008)

  def drawAimingCircle()
    let cx = MAIN_OFS_X
    let cy = MAIN_OFS_Y
    let outerR = 0.09
    let innerR = 0.065
    let dotR = 0.005
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFillColor(E3DCOLOR(0x00000000))
    drawEllipse(float2(cx, cy), float2(outerR, outerR))
    drawEllipse(float2(cx, cy), float2(innerR, innerR))
    setFillColor(props.markingsColor)
    drawCircle(float2(cx, cy), dotR)
    setFillColor(E3DCOLOR(0x00000000))

  def drawRangeRateCircle()
    return if !hasLockedTarget
    setColor(props.elementColor)
    setLineWidth(props.markingsLineWidth)
    let rLarge = 0.28
    let distAbs = lockedDistRel * get_radar_hud_distance_max() * 1000.0
    let r = distAbs > 10000.0 ? rLarge : rLarge * 0.6
    let maxClosureRateKts = 1200.0
    let closingSpeedKts = clamp(-lockedDistRate * 1.94384, 0.0, maxClosureRateKts)
    let gapHalf = 7.5
    let gapCenter = 90.0 - (closingSpeedKts / maxClosureRateKts) * 360.0
    let arcStart = gapCenter + gapHalf
    let arcSpan = 360.0 - 2.0 * gapHalf
    drawCorrectedArc(float2(MAIN_OFS_X, MAIN_OFS_Y), r, arcStart, arcSpan)

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
        drawEllipse(targetPos, float2(targetR, targetR))
        if target.isSelected
          hasLockedTarget = true
          lockedDistRel = distanceRel

  def drawHorizonLine()
    let cx = MAIN_OFS_X
    let cy = MAIN_OFS_Y
    setColor(props.elementColor)
    setLineWidth(props.elementsLineWidth)
    let rollRad = fmw != null ? -fmw.roll * degToRad : 0.0
    let pitchOff = fmw != null ? fmw.tangage * 0.003 : 0.0
    let cosR = cos(rollRad)
    let sinR = sin(rollRad)
    let centerY = cy + clamp(pitchOff, -0.3, 0.3)
    let gapHalf = 0.09
    let lineLen = 0.22
    let nx = cosR
    let ny = sinR
    drawLine(float2(cx - gapHalf * nx, centerY + gapHalf * ny),
             float2(cx - (gapHalf + lineLen) * nx, centerY + (gapHalf + lineLen) * ny))
    drawLine(float2(cx + gapHalf * nx, centerY - gapHalf * ny),
             float2(cx + (gapHalf + lineLen) * nx, centerY - (gapHalf + lineLen) * ny))

  def drawMissileRange()
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
      drawSteeringCircle(float2(MAIN_OFS_X, MAIN_OFS_Y))
      drawMissileRange()
    drawRangeRateCircle()

  def override drawMarkings()
    setColor(props.markingsColor)
    setFontSize(props.markingsFontSize)
    setLineWidth(props.markingsLineWidth)
    drawDisplayFrame()
    drawCenterTicks()
    drawCenterChevrons()
    drawLeftScale()
    drawPartition()
    drawRightScale()
    drawBottomScale()
    drawElevationMarker()
    drawAimingCircle()


[export]
def draw_radar_hud(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new LightningRadar(guiCtx, rdata, rstate, props).draw()

[export]
def setup_radar_data(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getFontId()
