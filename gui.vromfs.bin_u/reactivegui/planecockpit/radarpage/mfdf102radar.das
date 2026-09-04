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
require Sensors


def rgb(r, g, b : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0)))


struct PropStorage
  fontId : int = 0


struct Props
  bgColor : E3DCOLOR = rgb(5, 5, 2)
  phosphorColor : E3DCOLOR = rgb(180, 170, 40)

  innerRadius : float = 0.30
  centerRadius : float = 0.035
  reticleLineWidth : float = 2.0
  barSpacing : float = 0.058
  markingsFontSize : int = 30
  labelFontSize : int = 30


class F102Radar : Canvas
  params : PropStorage = PropStorage()
  props : Props = Props()

  hero : Unit?
  fmw : FlightModelWrap?
  hasLockedTarget : bool = false
  lockedDistRel : float = 0.0
  lockedDistRate : float = 0.0

  def F102Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_params : PropStorage&; in_props : Props = Props())
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    params.fontId = in_params.fontId
    props = in_props
    setFont(params.fontId)

    hero = get_watched_not_delayed_hero()
    fmw = as_fmw(hero)
    return if fmw == null

    using() <| $(var toi : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, toi)
        lockedDistRate = toi.distanceRate


  def drawArc(cx : float; cy : float; radius : float; angle_start : float; angle_end : float)
    let aStart = angle_start * degToRad
    let aEnd = angle_end * degToRad
    let prevFill = fillColor
    setFillColor(E3DCOLOR(0x00000000))
    drawSector(float2(cx, cy), float2(radius), float2(-aEnd, -aStart))
    setFillColor(prevFill)


  def drawBackground()
    setFillColor(props.bgColor)
    setColor(props.bgColor)
    drawBox(float2(-0.5), float2(0.5))


  def drawRangingBars()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth)
    setFontSize(props.labelFontSize)

    let ri = props.innerRadius
    let rc = props.centerRadius
    let sp = props.barSpacing
    let labelOfs = 0.018
    let tickLen = 0.051
    let sideOfs = 0.11

    let rightShorten = ri * 0.15
    for i in range(0, 5)
      let barY = float(i - 2) * sp
      drawLine(float2(rc + rightShorten, barY), float2(ri, barY))
      if i != 2
        drawStrAnchored(float2(ri + labelOfs, barY), "{5 - i}", AnchorHorz.Left, AnchorVert.Center)

    for i in range(0, 5)
      let barY = float(i - 2) * sp + sp
      drawLine(float2(-ri, barY), float2(-(rc + rightShorten), barY))
      drawStrAnchored(float2(-(ri + labelOfs), barY), "{5 - i}", AnchorHorz.Right, AnchorVert.Center)

    let nineX = ri + sideOfs
    drawStrAnchored(float2(-nineX, 0.0), "9", AnchorHorz.Center, AnchorVert.Center)
    drawLine(float2(-(ri + tickLen), 0.0), float2(-(nineX - 0.015), 0.0))
    drawStrAnchored(float2(nineX, 0.0), "3", AnchorHorz.Center, AnchorVert.Center)
    drawLine(float2(ri + tickLen, 0.0), float2(nineX - 0.015, 0.0))


  def drawTopScale()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth)
    setFontSize(props.markingsFontSize)

    let ri = props.innerRadius
    let tickLen = 0.025
    let numOfs = 0.035
    let titleOfs = 0.095

    for i in range(0, 7)
      let bx = (float(i) / 6.0 * 2.0 - 1.0) * ri
      let tickTop = -ri - tickLen
      drawLine(float2(bx, -ri), float2(bx, tickTop))
      let val = abs(3 - i) * 20
      drawStrAnchored(float2(bx, tickTop - numOfs), "{val}", AnchorHorz.Center, AnchorVert.Center)

    let titleX = ri * 0.24
    let titleY = -ri - tickLen - numOfs - titleOfs
    drawStrAnchored(float2(-titleX, titleY), "OPENING", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(titleX, titleY), "CLOSING", AnchorHorz.Center, AnchorVert.Center)
    drawLine(float2(0.0, titleY - 0.055), float2(0.0, titleY + 0.055))


  def drawBottomScale()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth)
    setFontSize(props.markingsFontSize)

    let ri = props.innerRadius
    let tickLen = 0.025
    let numOfs = 0.035

    for i in range(0, 7)
      let bx = (float(i) / 6.0 * 2.0 - 1.0) * ri
      let tickBot = ri + tickLen
      drawLine(float2(bx, ri), float2(bx, tickBot))
      let val = abs(3 - i) * 20
      drawStrAnchored(float2(bx, tickBot + numOfs), "{val}", AnchorHorz.Center, AnchorVert.Center)


  def drawBottomSixMark()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth)
    setFontSize(props.markingsFontSize)
    let ri = props.innerRadius
    let tickLen = 0.025
    let numOfs = 0.035
    let baseY = ri + tickLen + numOfs
    let markTop = baseY + numOfs
    let markBot = markTop + tickLen
    drawLine(float2(0.0, markTop), float2(0.0, markBot))
    drawStrAnchored(float2(0.0, markBot + numOfs), "6", AnchorHorz.Center, AnchorVert.Center)


  def toBscopePos(azimuthRel : float; distanceRel : float)
    let ri = props.innerRadius
    return float2((azimuthRel * 2.0 - 1.0) * ri, (1.0 - distanceRel * 2.0) * ri)


  def drawRangeRateCircle()
    return if !hasLockedTarget
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth)

    let rLarge = props.innerRadius * 0.95
    let distAbs = lockedDistRel * get_radar_hud_distance_max() * 1000.0
    let r = distAbs > 10000.0 ? rLarge : rLarge * 0.85

    let maxClosureRateKts = 1200.0
    let closingSpeedKts = clamp(-lockedDistRate * 1.94384, 0.0, maxClosureRateKts)
    let gapHalf = 7.5
    let gapCenter = 90.0 - (closingSpeedKts / maxClosureRateKts) * 360.0
    drawArc(0.0, 0.0, r, gapCenter + gapHalf, gapCenter - gapHalf + 360.0)


  def drawArtificialHorizon()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth + 1.0)

    let r = props.innerRadius
    let rollRad = fmw != null ? -fmw.roll * degToRad : 0.0
    let pitchOff = fmw != null ? fmw.tangage * 0.005 : 0.0

    let cosR = cos(rollRad)
    let sinR = sin(rollRad)
    let cy = clamp(pitchOff, -r * 0.5, r * 0.5)

    let gapHalf = r * 0.25
    let lineLen = r * 1.2
    let lineOfs = r * 0.15
    let dx = cosR
    let dy = -sinR

    let lStart = gapHalf + lineOfs
    let lEnd = lStart + lineLen
    drawLine(float2(-lEnd * dx, cy + lEnd * dy), float2(-lStart * dx, cy + lStart * dy))
    drawLine(float2(lStart * dx, cy - lStart * dy), float2(lEnd * dx, cy - lEnd * dy))


  def drawGround()
    let ri = props.innerRadius
    let lt = float2(-ri, -ri)
    let size = float2(ri * 2.0, ri * 2.0)
    let pos = toAbsPos(lt)
    let absSize = toAbsXY(size)
    render_ground_reflection(*ctx, absSize, pos, props.phosphorColor, int2(20, 10), true)

  def drawSweepLine()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth)

    let azRel = get_radar_hud_azimuth()
    let ri = props.innerRadius
    let bx = (azRel * 2.0 - 1.0) * ri
    drawLine(float2(bx, -ri), float2(bx, ri))


  def drawRangeGate()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth + 1.0)

    let distRel = get_radar_hud_cue_distance() * get_radar_hud_target_distance()
    if distRel <= 0.0
      return
    let ri = props.innerRadius
    let by = (1.0 - distRel * 2.0) * ri
    drawLine(float2(-ri, by), float2(ri, by))


  def drawTargets()
    Radar`foreach_visible_target() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        var distanceRel = 0.0
        if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
          distanceRel = target.distanceRel

        var azimuthRel = 0.5
        if get_radar_hud_has_azimuth_scale()
          azimuthRel = target.azimuthRel

        let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
        let alphaColor = (1. - target.ageRel) * signalRel

        let targetPos = toBscopePos(azimuthRel, distanceRel)

        let col4 = float4(Color4(props.phosphorColor)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setFillColor(col)
        setColor(E3DCOLOR(0x00000000))
        drawEllipse(targetPos, float2(0.012))

        if target.isSelected
          hasLockedTarget = true
          lockedDistRel = distanceRel
          setFillColor(E3DCOLOR(0x00000000))
          setColor(props.phosphorColor)
          setLineWidth(props.reticleLineWidth)
          let lockCircleR = props.innerRadius * 0.08
          drawEllipse(targetPos, float2(lockCircleR))


  def drawReticle()
    drawRangingBars()
    drawTopScale()
    drawBottomScale()
    drawBottomSixMark()

  def drawHud()
    drawArtificialHorizon()
    drawSweepLine()
    drawRangeGate()
    drawGround()
    drawTargets()
    drawRangeRateCircle()

  def draw()
    return if hero == null
    setFullCanvasViewport()
    drawBackground()
    drawReticle()
    drawHud()
    restoreViewport()


[export]
def draw_radar_hud(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new F102Radar(guiCtx, rdata, rstate, props).draw()

[export, unused_argument(props)]
def setup_radar_data(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
