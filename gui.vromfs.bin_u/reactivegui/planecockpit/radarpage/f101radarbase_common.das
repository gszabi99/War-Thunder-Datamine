module F101RadarBase_common public
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
require WTCamera
require Sensors


def rgb(r, g, b : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0)))

def rgb(r, g, b, a : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, float(a) / 255.0)))


struct PropStorage
  fontId : int = 0


struct Props
  bgColor : E3DCOLOR = rgb(5, 5, 2)
  lineGradientEdgeColor : E3DCOLOR = rgb(0, 0, 0, 0)
  elementColor : E3DCOLOR = rgb(175, 25, 0)
  markingsColor : E3DCOLOR = rgb(175, 25, 0)
  elementsLineWidth : float = 3.0
  markingsLineWidth : float = 1.5
  radarBoxHalfSize : float2 = float2(0.115, 0.261)
  radarBoxPos : float2 = float2(0.0, -0.045)
  displayRadius : float = 0.336
  targetRadius : float = 0.02
  lockedTargetCrossSize : float = 0.09
  markingsFontSize : int = 20
  smallFontSize : int = 20


class F101RadarBase : Canvas
  props : Props = Props()
  lt : float2 = float2(0.0)
  rb : float2 = float2(0.0)
  hero : Unit?

  def F101RadarBase(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_params : PropStorage&; in_props : Props = Props())
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    setFont(in_params.fontId)
    props = in_props
    lt = props.radarBoxPos - props.radarBoxHalfSize
    rb = props.radarBoxPos + props.radarBoxHalfSize
    hero = get_watched_not_delayed_hero()
    let fmw = as_fmw(hero)
    return if fmw == null

  def circlePoint(angle_deg : float; radius : float)
    let a = (angle_deg - 90.0) * degToRad
    return float2(cos(a) * radius, sin(a) * radius)

  def drawArc(radius : float; angle_start : float; angle_end : float; segments : int = 64)
    for i in range(segments)
      let t0 = float(i) / float(segments)
      let t1 = float(i + 1) / float(segments)
      let a0 = lerp(angle_start, angle_end, t0)
      let a1 = lerp(angle_start, angle_end, t1)
      drawLine(circlePoint(a0, radius), circlePoint(a1, radius))

  def drawBackground()
    setFillColor(props.bgColor)
    setColor(props.bgColor)
    drawBox(float2(-0.5), float2(0.5))

  def drawGround()
    let pos = toAbsPos(lt)
    let size = toAbsXY(rb - lt)
    render_ground_reflection(*ctx, size, pos, props.elementColor, int2(20, 10), true)

  def azimuthRelToX(azimuthRel : float)
    return lerp(lt.x, rb.x, azimuthRel)

  def azimuthDegToX(azimuthDeg : float)
    let halfSizeAzimuthDeg = (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * radToDeg * 0.5
    return cvt(azimuthDeg, -halfSizeAzimuthDeg, halfSizeAzimuthDeg, lt.x, rb.x)

  def distRelToY(distRel : float)
    return lerp(rb.y, lt.y, distRel)

  def toRadarPos(azimuthRel : float; distRel : float)
    return float2(azimuthRelToX(azimuthRel), distRelToY(distRel))

  def drawCueAt(pos : float2)
    setFillColor(E3DCOLOR(0x00000000))
    setColor(props.elementColor)
    let rad = get_radar_hud_cue_azimuth_half_width_rel() * (rb - lt)
    drawEllipse(pos, rad)

  def drawCue()
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
        let targetPos = toRadarPos(azimuthRel, distanceRel)
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

  def drawInstantaneousAzimuth()
    let x = azimuthRelToX(get_radar_hud_azimuth())
    drawGradientLine(float2(x, -0.5), float2(x, 0.5), 1.0, 3.0)

  def drawBScopeStatus()
    setViewport(props.radarBoxPos - props.radarBoxHalfSize, props.radarBoxPos + props.radarBoxHalfSize)
    setFillColor(props.elementColor)
    setColor(props.lineGradientEdgeColor)
    drawInstantaneousAzimuth()
    restoreViewport()

  def drawMarkings()
    pass

  def drawHud()
    setViewport(float2(-0.5), float2(0.5))
    drawGround()
    restoreViewport()
    setViewport(lt, rb)
    setLineWidth(props.elementsLineWidth)
    drawTargets()
    restoreViewport()
    drawBScopeStatus()

  def draw()
    return if hero == null
    setFullCanvasViewport()
    drawBackground()
    drawHud()
    drawMarkings()
    restoreViewport()
