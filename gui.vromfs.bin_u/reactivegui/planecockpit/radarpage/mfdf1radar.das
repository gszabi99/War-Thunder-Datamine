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
require app
require Sensors


def rgb(red, green, blue : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(red) / 255.0, float(green) / 255.0, float(blue) / 255.0, 1.0)))


struct PropStorage
  fontId : int = 0


struct Props
  bgColor       : E3DCOLOR = rgb(0, 0, 0)
  scopeColor    : E3DCOLOR = rgb(180, 170, 40)
  lineWidth     : float = 4.5
  thinLineWidth : float = 3.5
  scopeRadius   : float = 0.44
  centerCircleR : float = 0.014
  markFontSize  : int = 32


class F1Radar : Canvas
  params  : PropStorage = PropStorage()
  props   : Props = Props()
  hero    : Unit?
  fmw     : FlightModelWrap?
  hasLockedTarget : bool = false
  lockedDistRel : float = 0.0
  lockedDistRate : float = 0.0


  def F1Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
              rstate : RenderState& const; inParams : PropStorage&;
              inProps : Props = Props())
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    params.fontId = inParams.fontId
    props = inProps
    setFont(params.fontId)
    hero = get_watched_not_delayed_hero()
    fmw = as_fmw(hero)
    return if fmw == null
    using() <| $(var toi : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, toi)
        lockedDistRate = toi.distanceRate


  def drawBackground()
    setFillColor(props.bgColor)
    setColor(props.bgColor)
    drawBox(float2(-0.5), float2(0.5))


  def drawCrosshair()
    setColor(props.scopeColor)
    setLineWidth(props.thinLineWidth)
    let rad = props.scopeRadius
    let margin = rad * 0.15
    let lineEnd = rad - margin

    let tickHalf = 0.018
    let horzTickHalf = tickHalf * 0.60
    let longTickHalf = tickHalf * 1.15
    let fifthPos = lineEnd * 0.80

    drawLine(float2(0.0, -lineEnd), float2(0.0, 0.0))
    drawLine(float2(0.0, 0.0), float2(0.0, fifthPos))
    drawLine(float2(-fifthPos, 0.0), float2(fifthPos, 0.0))

    setFillColor(E3DCOLOR(0x00000000))
    drawCircle(float2(0.0), props.centerCircleR)

    let tickStep = fifthPos / 5.0
    for idx in range(1, 6)
      let dist = float(idx) * tickStep
      drawLine(float2(-horzTickHalf, -dist), float2(horzTickHalf, -dist))
      drawLine(float2(-horzTickHalf, dist), float2(horzTickHalf, dist))
      drawLine(float2(-dist, -horzTickHalf), float2(-dist, horzTickHalf))
      drawLine(float2(dist, -horzTickHalf), float2(dist, horzTickHalf))

    drawLine(float2(-longTickHalf, -fifthPos), float2(longTickHalf, -fifthPos))
    drawLine(float2(-longTickHalf, fifthPos), float2(longTickHalf, fifthPos))
    drawLine(float2(-fifthPos, -longTickHalf), float2(-fifthPos, longTickHalf))
    drawLine(float2(fifthPos, -longTickHalf), float2(fifthPos, longTickHalf))

    let combStep = tickStep * 0.5
    let combShort = horzTickHalf
    let combLong = longTickHalf
    for side in range(0, 2)
      let xSign = side == 0 ? -1.0 : 1.0
      let xBase = xSign * fifthPos
      for idx in range(1, 5)
        let yOff = float(idx) * combStep
        drawLine(float2(xBase - combShort, yOff), float2(xBase + combShort, yOff))
        drawLine(float2(xBase - combShort, -yOff), float2(xBase + combShort, -yOff))
      let combEnd = 5.0 * combStep
      drawLine(float2(xBase - combLong, combEnd), float2(xBase + combLong, combEnd))
      drawLine(float2(xBase - combLong, -combEnd), float2(xBase + combLong, -combEnd))


  def drawRadialTick(clockHours : float; tickOuter : float; tickLen : float)
    let deg = clockHours * 30.0 - 90.0
    let ang = deg * degToRad
    let co = cos(ang)
    let si = sin(ang)
    drawLine(float2(co * tickOuter, si * tickOuter), float2(co * (tickOuter - tickLen), si * (tickOuter - tickLen)))

  def drawScaleLabels()
    setColor(props.scopeColor)
    setFontSize(props.markFontSize)
    let labelR = 0.43
    let tickStart = labelR - 0.04
    let tickLen = 0.025 * 0.70
    let deg12 = 12.0 * 30.0 - 90.0
    let deg15 = 15.0 * 30.0 - 90.0
    let deg18 = 18.0 * 30.0 - 90.0
    let deg19 = 19.0 * 30.0 - 90.0
    let deg20 = 20.0 * 30.0 - 90.0
    let deg21 = 21.0 * 30.0 - 90.0

    drawStrAnchored(float2(cos(deg12 * degToRad) * labelR, sin(deg12 * degToRad) * labelR), "0", AnchorHorz.Center, AnchorVert.Center)

    drawStrAnchored(float2(cos(deg15 * degToRad) * labelR, sin(deg15 * degToRad) * labelR), "3", AnchorHorz.Center, AnchorVert.Center)
    drawRadialTick(13.0, tickStart, tickLen)
    drawRadialTick(15.0, tickStart, tickLen)
    drawRadialTick(16.0, tickStart, tickLen)
    drawRadialTick(17.0, tickStart, tickLen)

    drawStrAnchored(float2(cos(deg18 * degToRad) * labelR, sin(deg18 * degToRad) * labelR), "6", AnchorHorz.Center, AnchorVert.Center)
    drawRadialTick(18.0, tickStart, tickLen)
    drawRadialTick(18.0 + 1.0 / 3.0, tickStart, tickLen)
    drawRadialTick(18.0 + 2.0 / 3.0, tickStart, tickLen)

    drawStrAnchored(float2(cos(deg19 * degToRad) * labelR, sin(deg19 * degToRad) * labelR), "9", AnchorHorz.Center, AnchorVert.Center)
    drawRadialTick(19.0, tickStart, tickLen)
    drawRadialTick(19.0 + 1.0 / 3.0, tickStart, tickLen)
    drawRadialTick(19.0 + 2.0 / 3.0, tickStart, tickLen)

    drawStrAnchored(float2(cos(deg20 * degToRad) * labelR, sin(deg20 * degToRad) * labelR), "12", AnchorHorz.Center, AnchorVert.Center)
    drawRadialTick(20.0, tickStart, tickLen)
    drawRadialTick(20.0 + 1.0 / 3.0, tickStart, tickLen)
    drawRadialTick(20.0 + 2.0 / 3.0, tickStart, tickLen)

    drawStrAnchored(float2(cos(deg21 * degToRad) * labelR, sin(deg21 * degToRad) * labelR), "15", AnchorHorz.Center, AnchorVert.Center)
    drawRadialTick(21.0, tickStart, tickLen)
    drawRadialTick(23.0, tickStart, tickLen)


  def drawArc(cx : float; cy : float; radius : float; angleStart : float; angleEnd : float)
    let aStart = angleStart * degToRad
    let aEnd = angleEnd * degToRad
    let prevFill = fillColor
    setFillColor(E3DCOLOR(0x00000000))
    drawSector(float2(cx, cy), float2(radius), float2(-aEnd, -aStart))
    setFillColor(prevFill)

  def drawRangeRateCircle()
    return if !hasLockedTarget
    setColor(props.scopeColor)
    setLineWidth(props.thinLineWidth)
    let ext = getScanExtent()
    let rLarge = ext * 0.6
    let distAbs = lockedDistRel * get_radar_hud_distance_max() * 1000.0
    let circleR = distAbs > 10000.0 ? rLarge : rLarge * 0.6
    let maxClosureRateKts = 1200.0
    let closingSpeedKts = clamp(-lockedDistRate * 1.94384, 0.0, maxClosureRateKts)
    let gapHalf = 7.5
    let gapCenter = 90.0 - (closingSpeedKts / maxClosureRateKts) * 360.0
    drawArc(0.0, 0.0, circleR, gapCenter + gapHalf, gapCenter - gapHalf + 360.0)


  def getScanExtent() : float
    let rad = props.scopeRadius
    let margin = rad * 0.15
    let lineEnd = rad - margin
    return lineEnd * 0.80

  def toRadarPos(azimuthRel : float; distRel : float) : float2
    let ext = getScanExtent()
    return float2((azimuthRel * 2.0 - 1.0) * ext, (1.0 - distRel * 2.0) * ext)


  def drawGround()
    let ext = getScanExtent()
    let lt = float2(-ext, -ext)
    let size = float2(ext * 2.0, ext * 2.0)
    let pos = toAbsPos(lt)
    let absSize = toAbsXY(size)
    render_ground_reflection(*ctx, absSize, pos, props.scopeColor, int2(20, 10), true)

  def drawSweep()
    setColor(props.scopeColor)
    setLineWidth(props.thinLineWidth)
    let azRel = get_radar_hud_azimuth()
    let ext = getScanExtent()
    let bx = (azRel * 2.0 - 1.0) * ext
    drawLine(float2(bx, -ext), float2(bx, ext))


  def drawTargets()
    Radar`foreach_visible_target() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        var distanceRel = 0.0
        if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.0
          distanceRel = target.distanceRel

        var azimuthRel = 0.5
        if get_radar_hud_has_azimuth_scale()
          azimuthRel = target.azimuthRel

        let signalRel = target.signalRel < 0.01 ? 0.0 : cvt(target.signalRel, 0.05, 1.0, 0.3, 1.0)
        let alphaColor = (1.0 - target.ageRel) * signalRel
        let targetPos = toRadarPos(azimuthRel, distanceRel)

        let col4 = float4(Color4(props.scopeColor)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setFillColor(col)
        setColor(E3DCOLOR(0x00000000))
        drawEllipse(targetPos, float2(0.012))

        if target.isSelected
          hasLockedTarget = true
          lockedDistRel = distanceRel
          setFillColor(E3DCOLOR(0x00000000))
          setColor(props.scopeColor)
          setLineWidth(props.thinLineWidth)
          let lockCircleR = getScanExtent() * 0.08
          drawEllipse(targetPos, float2(lockCircleR))


  def drawArtificialHorizon()
    return if fmw == null
    setColor(props.scopeColor)
    setLineWidth(props.thinLineWidth)
    let ext = getScanExtent()
    let tickStep = ext / 5.0
    let gapHalf = tickStep * 3.0
    let lineEnd = ext
    let rollRad = -fmw.roll * degToRad
    let cosR = cos(rollRad)
    let sinR = sin(rollRad)
    drawLine(float2(-lineEnd * cosR, lineEnd * -sinR), float2(-gapHalf * cosR, gapHalf * -sinR))
    drawLine(float2(gapHalf * cosR, gapHalf * sinR), float2(lineEnd * cosR, lineEnd * sinR))

  def drawRangeGate()
    setColor(props.scopeColor)
    setLineWidth(props.lineWidth)
    let distRel = get_radar_hud_cue_distance() * get_radar_hud_target_distance()
    if distRel <= 0.0
      return
    let ext = getScanExtent()
    let by = (1.0 - distRel * 2.0) * ext
    drawLine(float2(-ext, by), float2(ext, by))


  def draw()
    return if hero == null
    setFullCanvasViewport()
    drawBackground()
    pushLocalAxes(float2(0.0, 0.0), float2(1.0))

    drawCrosshair()
    drawScaleLabels()
    drawArtificialHorizon()
    drawSweep()
    drawGround()
    drawRangeGate()
    drawTargets()
    drawRangeRateCircle()

    popAxes()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; props : PropStorage&)
  new F1Radar(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
