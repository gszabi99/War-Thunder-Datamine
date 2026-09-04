require darg
require DagorStdGuiRender
require DagorMath
require DagorMathUtils
require math
require FlightModelWrap
require FlightControl
require HeroManager
require Plane
require Unit
require app
require hud
require WTVr
require strings
require %rGui.utils.canvas_common
require %rGui.utils.constants_common


struct PropStorage
  fontId : int


def set_color_alpha(col : E3DCOLOR)
  let col4 = is_hmd_enabled() ? float4(Color4(col)) * 0.5 : float4(Color4(col)) * 0.3
  return E3DCOLOR(Color4(col4))


class Component : Canvas
  isValid : bool = false
  unit : Unit? = null
  fmw : FlightModelWrap? = null
  defaultFontSize : int = 20
  baseLineW : float = 3.0

  heading : float = 0.0
  barAlt : float = 0.0
  radAlt : float = 0.0
  ias : float = 0.0
  roc : float = 0.0
  pitchDeg : float = 0.0
  rollDeg : float = 0.0

  iasKmh : float = 0.0
  velWorld : float3

  hasTarget : bool = false
  targetAbsPos : float2


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    unit = get_watched_not_delayed_hero()
    fmw = as_fmw(unit)
    return if fmw == null || fmw.cockpit == null

    heading = norm_ang_deg((dir_to_angles(unit.unitTm[0]).x + PI * 0.5) * radToDeg)
    barAlt = (unit.unitTm[3].y - get_app().currentScene.waterLevel) * metrToFeet
    let fm = fmw.fm
    radAlt = fm.input.currentAlt * metrToFeet
    ias = fmw.ias * mpsToKnots
    roc = fm.vertSpeed * mpsToFpm * 0.01
    pitchDeg = fmw.tangage
    rollDeg = fmw.roll
    iasKmh = fmw.ias * 3.6
    velWorld = unit.vel

    var poiWorldPos : float3
    if get_point_of_interest(poiWorldPos)
      var hmdPos : float2
      if world_to_hmd_screen(poiWorldPos, hmdPos)
        let margin = 0.3
        if hmdPos.x >= rdata.size.x * margin && hmdPos.x <= rdata.size.x * (1.0 - margin) && hmdPos.y >= rdata.size.y * margin && hmdPos.y <= rdata.size.y * (1.0 - margin)
          hasTarget = true
          targetAbsPos = hmdPos

    setColor(set_color_alpha(*fmw.cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS)))
    baseLineW = floor(3.0 * fmw.cockpit.ilsLineWidthScale)
    setLineWidth(baseLineW)
    setFont(props.fontId)
    defaultFontSize = floori(20.0 * float(rdata.size.y) / 1080.0)
    isValid = true


  def drawCompassTape()
    let tapeWidth = 0.156
    let tapeHeight = 0.025
    let tapeY = -0.225
    let pos = toAbsPos(float2(0.0, tapeY))
    let size = toAbsXY(float2(tapeWidth, tapeHeight))
    pushAxes(pos, size)

    setViewport(float2(-0.5, -1.0), float2(0.5, 1.0))

    let degreesHalfWidth = 25
    let step = 10

    let headingI = roundi(heading / float(step))
    let count = degreesHalfWidth / step

    setFontSize(defaultFontSize)
    var fctx : StdGuiFontContext
    get_font_context(fctx, font.id, 0, 0, font.size)
    let fontHt = float(get_font_ascent(fctx) - get_font_descent(fctx))
    let tickHalf = fontHt / size.y * 0.5

    let halfStepT = float(step) / float(degreesHalfWidth * 2) * 0.5

    for i in range(-count, count + 1)
      let angleI = headingI + i
      let angle = float(angleI * step)
      let t = -(heading - angle) / float(degreesHalfWidth * 2)

      drawLine(float2(t, -tickHalf), float2(t, tickHalf))
      let labelDeg = norm_ang_deg(angle + float(step) * 0.5)
      let labelVal = roundi(labelDeg) / 10
      drawStrAnchored(float2(t + halfStepT, 0.0), "{labelVal}", AnchorHorz.Center, AnchorVert.Center)

    restoreViewport()
    popAxes()


  def drawCompassValue()
    let tapeY = -0.225
    let tapeHeight = 0.025
    let boxHalfH = 0.012
    let tailLen = 0.0036
    let boxCenterY = tapeY - tapeHeight * 0.5 - boxHalfH - tailLen
    let pos = float2(0.0, boxCenterY)

    setFontSize(defaultFontSize)
    setFillColor(TRANSPARENT)
    setLineWidth(baseLineW)
    let boxHalf = float2(0.01, boxHalfH)
    drawBox(pos - boxHalf, pos + boxHalf)
    drawStrAnchored(pos, fmt(":03d", roundi(heading) % 360), AnchorHorz.Center, AnchorVert.Center)
    drawLine(float2(0.0, boxCenterY + boxHalfH), float2(0.0, tapeY - tapeHeight * 0.5))


  def drawBarAlt()
    setFontSize(defaultFontSize)
    let pos = float2(-0.114, -0.01)
    setFillColor(TRANSPARENT)
    setLineWidth(baseLineW)
    let boxHalf = float2(0.01, 0.012)
    drawBox(pos - boxHalf, pos + boxHalf)
    drawStrAnchored(pos, "{roundi(barAlt)}", AnchorHorz.Center, AnchorVert.Center)


  def drawRadAlt()
    let barX = -0.075
    let barTop = -0.12
    let barBot = 0.13
    let barHeight = barBot - barTop

    drawLine(float2(barX, barTop), float2(barX, barBot))

    let tickLen = 0.01
    let tickLeft = tickLen * 0.8
    let tickRight = tickLen * 0.2
    for i in range(0, 4)
      let frac = float(i) / 3.0
      let y = barTop + frac * barHeight
      drawLine(float2(barX - tickLeft, y), float2(barX + tickRight, y))

    let t = clamp(radAlt / 500.0, 0.0, 1.0)
    let markerY = clamp(barBot - t * barHeight, barTop, barBot)

    let boxHalf = float2(0.01, 0.012)
    let triWidth = 0.006
    let boxCenterX = barX + triWidth + boxHalf.x
    let boxPos = float2(boxCenterX, markerY)

    setFontSize(defaultFontSize)
    setFillColor(TRANSPARENT)
    drawBox(boxPos - boxHalf, boxPos + boxHalf)
    drawStrAnchored(boxPos, "{roundi(radAlt)}", AnchorHorz.Center, AnchorVert.Center)

    let triTipX = barX
    let triBaseX = boxPos.x - boxHalf.x
    let triHalfH = boxHalf.y
    drawLine(float2(triTipX, markerY), float2(triBaseX, markerY - triHalfH))
    drawLine(float2(triTipX, markerY), float2(triBaseX, markerY + triHalfH))
    drawLine(float2(triBaseX, markerY - triHalfH), float2(triBaseX, markerY + triHalfH))


  def drawAirspeed()
    setFontSize(floori(float(defaultFontSize) * 1.1))
    let pos = float2(0.08, -0.01)
    setFillColor(TRANSPARENT)
    setLineWidth(baseLineW)
    drawBox(pos - float2(0.02, 0.013), pos + float2(0.02, 0.013))
    drawStrAnchored(pos, fmt(":03d", roundi(ias)), AnchorHorz.Center, AnchorVert.Center)


  def drawBankAngle()
    let cx = 0.0
    let cy = 0.085
    let radius = 0.085
    let aspect = canvasSize.x / canvasSize.y

    let tickLen = 0.004
    for angle in [240.0, 255.0, 270.0, 285.0, 300.0]
      let a = angle * degToRad
      let dx = cos(a)
      let dy = -sin(a) * aspect
      let outerR = radius
      let innerR = radius - tickLen
      drawLine(float2(cx + dx * innerR, cy + dy * innerR), float2(cx + dx * outerR, cy + dy * outerR))

    let triSize = 0.008
    let triR = radius - tickLen
    let rollRadRaw = rollDeg * degToRad + PI * 1.5
    let rollRad = clamp(rollRadRaw, PI * 4.0 / 3.0, PI * 5.0 / 3.0)
    var sinA, cosA : float
    sincos(rollRad, sinA, cosA)
    let tipR = triR
    let baseR = triR - triSize
    let tipX = cx + cos(rollRad) * tipR
    let tipY = cy - sin(rollRad) * tipR * aspect
    let halfBase = triSize * 0.4
    let perpX = -sin(rollRad)
    let perpY = -cos(rollRad) * aspect
    let baseCX = cx + cos(rollRad) * baseR
    let baseCY = cy - sin(rollRad) * baseR * aspect
    let b1x = baseCX + perpX * halfBase
    let b1y = baseCY + perpY * halfBase
    let b2x = baseCX - perpX * halfBase
    let b2y = baseCY - perpY * halfBase
    drawLine(float2(tipX, tipY), float2(b1x, b1y))
    drawLine(float2(tipX, tipY), float2(b2x, b2y))
    drawLine(float2(b1x, b1y), float2(b2x, b2y))


  def rotatePoint(p : float2; cx : float; cy : float; sinR : float; cosR : float) : float2
    let aspect = canvasSize.x / canvasSize.y
    let dx = p.x - cx
    let dy = p.y - cy
    return float2(cx + dx * cosR - dy * sinR / aspect, cy + dx * sinR * aspect + dy * cosR)

  def drawRotatedLine(a : float2; b : float2; cx : float; cy : float; sinR : float; cosR : float)
    drawLine(rotatePoint(a, cx, cy, sinR, cosR), rotatePoint(b, cx, cy, sinR, cosR))

  def drawPitchSymbol()
    let halfBot = 0.022
    let slopeW = 0.008
    let slopeH = 0.019
    let offset = 0.09
    let pitchScale = 0.002
    let horizonY = clamp(pitchDeg * pitchScale, -0.1, 0.1)

    let rollRad = -rollDeg * degToRad
    var sinR, cosR : float
    sincos(rollRad, sinR, cosR)

    let topX = halfBot - slopeW

    let botCy = horizonY + offset
    let botTopY = botCy
    let botBotY = botCy + slopeH
    drawRotatedLine(float2(-topX, botTopY), float2(-halfBot, botBotY), 0.0, horizonY, sinR, cosR)
    drawRotatedLine(float2(-halfBot, botBotY), float2(halfBot, botBotY), 0.0, horizonY, sinR, cosR)
    drawRotatedLine(float2(halfBot, botBotY), float2(topX, botTopY), 0.0, horizonY, sinR, cosR)

    let topCy = horizonY - offset
    let mirrorTopY = topCy
    let mirrorBotY = topCy - slopeH
    drawRotatedLine(float2(-topX, mirrorTopY), float2(-halfBot, mirrorBotY), 0.0, horizonY, sinR, cosR)
    drawRotatedLine(float2(halfBot, mirrorBotY), float2(topX, mirrorTopY), 0.0, horizonY, sinR, cosR)
    let dashLen = halfBot * 0.3
    let gap = halfBot * 0.11
    drawRotatedLine(float2(-halfBot, mirrorBotY), float2(-halfBot + dashLen, mirrorBotY), 0.0, horizonY, sinR, cosR)
    drawRotatedLine(float2(-halfBot + dashLen + gap, mirrorBotY), float2(-gap * 0.5, mirrorBotY), 0.0, horizonY, sinR, cosR)
    drawRotatedLine(float2(gap * 0.5, mirrorBotY), float2(halfBot - dashLen - gap, mirrorBotY), 0.0, horizonY, sinR, cosR)
    drawRotatedLine(float2(halfBot - dashLen, mirrorBotY), float2(halfBot, mirrorBotY), 0.0, horizonY, sinR, cosR)


  def drawHorizon()
    setLineWidth(baseLineW)
    let halfLen = 0.08
    let pitchScale = 0.002
    let yOff = pitchDeg * pitchScale
    let cy = clamp(yOff, -0.1, 0.1)

    let p1 = rotatePoint(float2(-halfLen, cy), 0.0, cy, sin(-rollDeg * degToRad), cos(-rollDeg * degToRad))
    let p2 = rotatePoint(float2(halfLen, cy), 0.0, cy, sin(-rollDeg * degToRad), cos(-rollDeg * degToRad))
    drawLine(p1, p2)


  def drawGroundSpeedVector()
    let speed = length(velWorld)
    if speed < 1.0
      return
    let vLen = clamp(ias / 150.0 * 0.06, 0.0, 0.06)
    if vLen < 0.005
      return

    let pitchScale = 0.002
    let horizonY = clamp(pitchDeg * pitchScale, -0.1, 0.1)
    let offset = 0.0765
    let slopeH = 0.019
    let rollRad = -rollDeg * degToRad
    var sinR, cosR : float
    sincos(rollRad, sinR, cosR)
    let origin = rotatePoint(float2(0.0, horizonY + offset + slopeH * 0.5), 0.0, horizonY, sinR, cosR)

    let circleR = 0.004
    let aspect = canvasSize.x / canvasSize.y
    for i in range(0, 12)
      let a1 = float(i) * 2.0 * PI / 12.0
      let a2 = float(i + 1) * 2.0 * PI / 12.0
      drawLine(float2(origin.x + cos(a1) * circleR, origin.y - sin(a1) * circleR * aspect), float2(origin.x + cos(a2) * circleR, origin.y - sin(a2) * circleR * aspect))

    let velHorLen = sqrt(velWorld.x * velWorld.x + velWorld.z * velWorld.z)

    let vertAngleDeg = atan2(velWorld.y, max(velHorLen, 0.1)) * radToDeg
    let vertDevDeg = vertAngleDeg - pitchDeg

    var driftDeg = 0.0
    if velHorLen > 0.5
      let trackDeg = norm_ang_deg((dir_to_angles(velWorld).x + PI * 0.5) * radToDeg)
      driftDeg = heading - trackDeg
      if driftDeg > 180.0
        driftDeg -= 360.0
      if driftDeg < -180.0
        driftDeg += 360.0

    let dirX = -driftDeg * pitchScale
    let dirY = -vertDevDeg * pitchScale
    let dirLen = sqrt(dirX * dirX + dirY * dirY)

    var normDirX, normDirY : float
    if dirLen > 0.001
      normDirX = dirX / dirLen
      normDirY = dirY / dirLen
    else
      normDirX = 0.0
      normDirY = -1.0

    let aspCorr = 1.0 / sqrt(normDirX * normDirX * aspect * aspect + normDirY * normDirY)
    let perpAspCorr = 1.0 / sqrt(normDirY * normDirY * aspect * aspect + normDirX * normDirX)
    let adjLen = vLen * aspCorr

    let endX = origin.x + normDirX * adjLen
    let endY = origin.y + normDirY * adjLen
    drawLine(float2(origin.x, origin.y), float2(endX, endY))

    let tickPerpSize = 0.003 * perpAspCorr
    let maxTicks = min(floori(iasKmh / 50.0), 10)
    for i in range(1, maxTicks + 1)
      let tickFrac = float(i) * 50.0 / iasKmh
      let tickX = origin.x + normDirX * adjLen * tickFrac
      let tickY = origin.y + normDirY * adjLen * tickFrac
      let perpDx = -normDirY * tickPerpSize
      let perpDy = normDirX * tickPerpSize
      drawLine(float2(tickX - perpDx, tickY - perpDy), float2(tickX + perpDx, tickY + perpDy))

    let arrowAlongSize = 0.0068 * aspCorr
    let arrowPerpSize = 0.0068 * 0.5 * perpAspCorr
    let arrowDx = normDirX * arrowAlongSize
    let arrowDy = normDirY * arrowAlongSize
    let perpX = -normDirY * arrowPerpSize
    let perpY = normDirX * arrowPerpSize
    drawLine(float2(endX, endY), float2(endX - arrowDx + perpX, endY - arrowDy + perpY))
    drawLine(float2(endX, endY), float2(endX - arrowDx - perpX, endY - arrowDy - perpY))


  def drawTargetReticle()
    return if !hasTarget
    let sz = toAbsX(0.012)
    pushAxes(targetAbsPos, float2(1.0))

    drawLine(float2(sz * 0.3, 0.0), float2(sz, 0.0))
    drawLine(float2(-sz * 0.3, 0.0), float2(-sz, 0.0))
    drawLine(float2(0.0, sz * 0.3), float2(0.0, sz))
    drawLine(float2(0.0, -sz * 0.3), float2(0.0, -sz))

    popAxes()

  def drawCenterMark()
    let horzLen = 0.02
    let gap = 0.006
    let vertLen = horzLen * 0.5
    let cy = 0.0

    drawLine(float2(-gap - horzLen, cy), float2(-gap, cy))
    drawLine(float2(gap, cy), float2(gap + horzLen, cy))
    drawLine(float2(-gap, cy), float2(-gap, cy + vertLen))
    drawLine(float2(gap, cy), float2(gap, cy + vertLen))


  def draw()
    return if !isValid
    setFullCanvasViewport()

    drawHorizon()
    drawPitchSymbol()
    drawCenterMark()
    drawGroundSpeedVector()
    drawCompassTape()
    drawCompassValue()
    drawBarAlt()
    drawRadAlt()
    drawAirspeed()
    drawBankAngle()
    drawTargetReticle()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
