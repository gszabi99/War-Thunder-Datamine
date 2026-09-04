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

def rgb(r, g, b, a : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, float(a) / 255.0)))


struct PropStorage
  fontId : int = 0


struct Props
  bgColor : E3DCOLOR = rgb(5, 5, 2)
  phosphorColor : E3DCOLOR = rgb(180, 170, 40)
  dimColor : E3DCOLOR = rgb(120, 110, 25)

  elementsLineWidth : float = 3.0
  markingsLineWidth : float = 2.0

  displayRadius : float = 0.7
  originY : float = 0.495
  markingsFontSize : int = 18


class F104Radar : Canvas
  params : PropStorage = PropStorage()
  props : Props = Props()

  hero : Unit?
  fmw : FlightModelWrap?
  hasLockedTarget : bool = false
  lockedDistRel : float = 0.0
  lockedDistRate : float = 0.0
  origin : float2 = float2(0.0)

  def F104Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_params : PropStorage&; in_props : Props = Props())
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    params.fontId = in_params.fontId
    props = in_props
    setFont(params.fontId)
    origin = float2(0.0, props.originY)

    hero = get_watched_not_delayed_hero()
    fmw = as_fmw(hero)
    return if fmw == null

    using() <| $(var toi : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, toi)
        lockedDistRate = toi.distanceRate


  def circlePoint(angle_deg : float; radius : float)
    let a = (angle_deg - 90.0) * degToRad
    return float2(cos(a) * radius, sin(a) * radius)

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


  def drawRangeRateCircle()
    return if !hasLockedTarget
    setColor(props.phosphorColor)
    setLineWidth(props.markingsLineWidth)

    let rLarge = props.displayRadius * 0.6
    let distAbs = lockedDistRel * get_radar_hud_distance_max() * 1000.0
    let r = distAbs > 10000.0 ? rLarge : rLarge * 0.6

    let maxClosureRateKts = 1200.0
    let closingSpeedKts = clamp(-lockedDistRate * 1.94384, 0.0, maxClosureRateKts)
    let gapHalf = 7.5
    let gapCenter = 90.0 - (closingSpeedKts / maxClosureRateKts) * 360.0
    drawArc(0.0, 0.0, r, gapCenter + gapHalf, gapCenter - gapHalf + 360.0)


  def drawRangeScale()
    setColor(props.phosphorColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    let boxX = -props.displayRadius - 0.02
    let boxY = props.displayRadius - 0.03
    let cellW = 0.04
    let cellH = 0.025

    for i in range(0, 3)
      let x = boxX + float(i) * cellW
      setFillColor(props.bgColor)
      drawBox(float2(x, boxY), float2(x + cellW, boxY + cellH))

    let labels = fixed_array<int>(20, 40, 80)
    for i in range(0, 3)
      let x = boxX + float(i) * cellW + cellW * 0.5
      drawStrAnchored(float2(x, boxY + cellH * 0.5), "{labels[i]}", AnchorHorz.Center, AnchorVert.Center)

    drawStrAnchored(float2(boxX - 0.01, boxY - 0.02), "RANGE", AnchorHorz.Left, AnchorVert.Center)


  def drawArtificialHorizon()
    setColor(props.phosphorColor)
    setLineWidth(props.elementsLineWidth)

    let r = props.displayRadius
    let oy = 0.014
    let rollRad = fmw != null ? -fmw.roll * degToRad : 0.0
    let pitchOff = fmw != null ? fmw.tangage * 0.005 : 0.0

    let cosR = cos(rollRad)
    let sinR = sin(rollRad)
    let cy = oy + clamp(pitchOff, -r * 0.5, r * 0.5)

    let gapHalf = r * 0.50
    let lineLen = r - gapHalf
    let lineOfs = r * 0.15
    let dx = cosR
    let dy = -sinR

    let lStart = gapHalf + lineOfs
    let lEnd = lStart + lineLen
    drawLine(float2(-lEnd * dx, cy + lEnd * dy), float2(-lStart * dx, cy + lStart * dy))
    drawLine(float2(lStart * dx, cy - lStart * dy), float2(lEnd * dx, cy - lEnd * dy))


  def drawRangeSweep()
    setColor(props.phosphorColor)
    setLineWidth(props.markingsLineWidth)

    let azRel = get_radar_hud_azimuth()
    let halfAz = (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * 0.5
    let azAngle = (azRel * 2.0 - 1.0) * halfAz
    let r = props.displayRadius

    let sweepLen = r
    let dx = sin(azAngle)
    let dy = -cos(azAngle)
    drawLine(origin, origin + float2(dx * sweepLen, dy * sweepLen))


  def drawRangeGate()
    setColor(props.phosphorColor)
    setLineWidth(props.elementsLineWidth)

    let distRel = get_radar_hud_cue_distance() * get_radar_hud_target_distance()
    if distRel <= 0.0
      return
    let r = props.displayRadius * distRel
    let halfAz = (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * 0.5 * radToDeg

    drawArc(origin.x, origin.y, r, 90.0 - halfAz, 90.0 + halfAz)


  def azimuthRelToAngle(azRel : float)
    let halfAz = (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * 0.5
    return (azRel * 2.0 - 1.0) * halfAz

  def toRadarPos(azimuthRel : float; distRel : float)
    let angle = azimuthRelToAngle(azimuthRel)
    let r = props.displayRadius * distRel
    return origin + float2(sin(angle) * r, -cos(angle) * r)


  def drawGround()
    let lt = origin - float2(props.displayRadius, props.displayRadius)
    let size = float2(props.displayRadius * 2.0, props.displayRadius * 2.0)
    let pos = toAbsPos(lt)
    let absSize = toAbsXY(size)
    render_ground_reflection(*ctx, absSize, pos, props.phosphorColor, int2(20, 10), false)


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

        let targetPos = toRadarPos(azimuthRel, distanceRel)

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
          setLineWidth(props.markingsLineWidth)
          let lockCircleR = props.displayRadius * 0.08
          drawEllipse(targetPos, float2(lockCircleR))


  def drawMarkings()
    setColor(props.phosphorColor)
    setFontSize(props.markingsFontSize)
    setLineWidth(props.markingsLineWidth)

    drawRangeScale()


  def drawHud()
    drawArtificialHorizon()
    drawRangeSweep()
    drawRangeGate()
    drawGround()
    setLineWidth(props.elementsLineWidth)
    drawTargets()
    drawRangeRateCircle()


  def draw()
    return if hero == null
    setFullCanvasViewport()
    drawBackground()
    drawMarkings()
    drawHud()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new F104Radar(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
