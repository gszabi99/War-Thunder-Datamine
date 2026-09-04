require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.radar_common
require DagorStdGuiRender
require DagorMath
require math
require darg
require RadarHud
require HeroManager
require FlightModelWrap
require Unit
require Sensors


def rgb(r, g, b : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0)))


struct PropStorage
  fontId : int = 0


struct Props
  bgColor : E3DCOLOR = rgb(5, 5, 2)
  phosphorColor : E3DCOLOR = rgb(175, 25, 0)

  innerRadius : float = 0.253
  circleRadius : float = 0.18
  reticleLineWidth : float = 2.0
  sweepDotRadius : float = 0.0107
  lockCircleRadius : float = 0.0299


class Su15Radar : Canvas
  params : PropStorage = PropStorage()
  props : Props = Props()

  hero : Unit?
  fmw : FlightModelWrap?

  def Su15Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_params : PropStorage&; in_props : Props = Props())
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    params.fontId = in_params.fontId
    props = in_props
    setFont(params.fontId)
    hero = get_watched_not_delayed_hero()
    fmw = as_fmw(hero)


  def drawBackground()
    setFillColor(props.bgColor)
    setColor(props.bgColor)
    drawBox(float2(-0.5), float2(0.5))


  def drawMainCircle()
    let lineR = props.innerRadius * 1.15
    let tick2Y = lineR * 2.0 / 3.0
    let circleY = tick2Y * 0.03
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth)
    setFillColor(E3DCOLOR(0x00000000))
    drawEllipse(float2(0.0, circleY), float2(props.circleRadius))


  def drawCrosshair()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth)

    let lineR = props.innerRadius * 1.15
    let tickLen = 0.020
    let numTicks = 3
    let tickStep = lineR / float(numTicks)

    drawLine(float2(-lineR, 0.0), float2(lineR, 0.0))
    drawLine(float2(0.0, -lineR), float2(0.0, lineR))

    for i in range(1, numTicks + 1)
      let x = float(i) * tickStep
      drawLine(float2(x, -tickLen), float2(x, tickLen))
      drawLine(float2(-x, -tickLen), float2(-x, tickLen))

    for i in range(1, numTicks + 1)
      let y = float(i) * tickStep
      drawLine(float2(-tickLen, y), float2(tickLen, y))
      drawLine(float2(-tickLen, -y), float2(tickLen, -y))


  def drawGround()
    let lineR = props.innerRadius * 1.15
    let lt = float2(-lineR, -lineR)
    let size = float2(lineR * 2.0, lineR * 2.0)
    let pos = toAbsPos(lt)
    let absSize = toAbsXY(size)
    render_ground_reflection(*ctx, absSize, pos, props.phosphorColor, int2(20, 10), true)


  def drawArtificialHorizon()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth + 1.0)

    let r = props.innerRadius
    let rollRad = fmw != null ? -fmw.roll * degToRad : 0.0
    let pitchOff = fmw != null ? fmw.tangage * 0.005 : 0.0

    let cosR = cos(rollRad)
    let sinR = sin(rollRad)
    let cy = clamp(pitchOff, -r * 0.5, r * 0.5)

    let gapHalf = r * 0.1
    let lineLen = r * 1.15
    let lineOfs = r * 0.12
    let dx = cosR
    let dy = -sinR

    let lStart = gapHalf + lineOfs
    let lEnd = lStart + lineLen
    drawLine(float2(-lEnd * dx, cy + lEnd * dy), float2(-lStart * dx, cy + lStart * dy))
    drawLine(float2(lStart * dx, cy - lStart * dy), float2(lEnd * dx, cy - lEnd * dy))


  def drawSweepLine()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth)

    let azRel = get_radar_hud_azimuth()
    let lineR = props.innerRadius * 1.15
    let bx = (azRel * 2.0 - 1.0) * lineR
    let dotR = props.sweepDotRadius
    let dotOfs = dotR * 0.7

    setFillColor(props.phosphorColor)
    setColor(E3DCOLOR(0x00000000))
    drawEllipse(float2(bx, -lineR - dotOfs), float2(dotR))
    drawEllipse(float2(bx, lineR + dotOfs), float2(dotR))


  def drawRangeGate()
    setColor(props.phosphorColor)
    setLineWidth(props.reticleLineWidth + 1.0)
    setFillColor(E3DCOLOR(0x00000000))

    let distRel = get_radar_hud_cue_distance() * get_radar_hud_target_distance()
    if distRel <= 0.0
      return
    let lineR = props.innerRadius * 1.15
    let by = (1.0 - distRel * 2.0) * lineR
    drawLine(float2(-lineR, by), float2(lineR, by))


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

        let lineR = props.innerRadius * 1.15
        let tx = (azimuthRel * 2.0 - 1.0) * lineR
        let ty = (1.0 - distanceRel * 2.0) * lineR
        let targetPos = float2(tx, ty)

        let col4 = float4(Color4(props.phosphorColor)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setFillColor(col)
        setColor(E3DCOLOR(0x00000000))
        drawEllipse(targetPos, float2(0.012))

        if target.isSelected
          setFillColor(E3DCOLOR(0x00000000))
          setColor(props.phosphorColor)
          setLineWidth(props.reticleLineWidth)
          drawEllipse(targetPos, float2(props.lockCircleRadius))


  def drawRangeLabels()
    setColor(props.phosphorColor)
    setFontSize(25)
    let lineR = props.innerRadius * 1.15
    let labelX = -0.5 + 0.09
    drawStrAnchored(float2(labelX, -lineR), "30", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(labelX, 0.0), "20", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(labelX, lineR), "10", AnchorHorz.Left, AnchorVert.Center)


  def draw()
    return if hero == null
    setFullCanvasViewport()
    drawBackground()
    drawGround()
    drawMainCircle()
    drawCrosshair()
    drawArtificialHorizon()
    drawSweepLine()
    drawRangeGate()
    drawTargets()
    drawRangeLabels()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Su15Radar(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
