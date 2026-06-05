require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require math
require Unit
require Plane
require GamePhys


let
  CLR_GRN  = E3DCOLOR(0xFF_00CC00)
  CLR_YEL  = E3DCOLOR(0xFF_FFCC00)
  CLR_RED  = E3DCOLOR(0xFF_FF2020)
  CLR_NONE = E3DCOLOR(0x00_000000)
  CLR_BG   = E3DCOLOR(0xFF_000000)
  CLR_WHT  = E3DCOLOR(0xFF_FFFFFF)

  ZERO_KELVIN = -273.15


struct EngState
  rpm1  : float = 0.0
  rpm2  : float = 0.0
  temp1 : float = 0.0
  temp2 : float = 0.0
  fuelKg : float = 0.0


struct PropStorage
  fontId : int


class Component : Canvas
  isValid    : bool = false
  aspect     : float = 1.0
  eng        : EngState = EngState()

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&; in_eng : EngState)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    eng = in_eng
    isValid = true
    setLineWidth(1.5)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y * 1.1))
    aspect = 0.675
    setFont(props.fontId)
    setFontSize(12)
    setColor(CLR_GRN)
    setFillColor(CLR_NONE)

  def drawRoundCircle(pos : float2; radius : float)
    drawEllipse(pos, float2(radius, radius * aspect))

  def drawGauge(pos : float2; radius : float; value : float; minVal : float; maxVal : float; lbl : string)
    let startAngle = 122.5
    let endAngle = 417.5
    let span = endAngle - startAngle

    setLineWidth(2.5)
    let arcN = 60
    for i in range(0, arcN)
      let a0 = startAngle + span * float(i) / float(arcN)
      let a1 = startAngle + span * float(i + 1) / float(arcN)
      let valAtArc = minVal + (maxVal - minVal) * float(i) / float(arcN)
      if valAtArc < 100.0
        setColor(CLR_RED)
      elif valAtArc < 150.0
        setColor(CLR_YEL)
      else
        setColor(CLR_GRN)
      var s0, c0, s1, c1 = 0.0
      sincos(a0 * degToRad, s0, c0)
      sincos(a1 * degToRad, s1, c1)
      let r0 = radius * 0.92
      drawLine(pos + r0 * float2(c0, s0 * aspect), pos + r0 * float2(c1, s1 * aspect))
    setLineWidth(1.5)

    let majorCount = 6
    let minorPerMajor = 5
    let totalTicks = majorCount * minorPerMajor
    let minorStep = span / float(totalTicks)
    setColor(CLR_WHT)
    for i in range(0, totalTicks + 1)
      let angle = startAngle + float(i) * minorStep
      var sina, cosa = 0.0
      sincos(angle * degToRad, sina, cosa)
      let dir = float2(cosa, sina * aspect)
      if i % minorPerMajor == 0
        setLineWidth(2.5)
        drawLine(pos + radius * 0.96 * dir, pos + radius * 0.78 * dir)
        setLineWidth(1.5)
      else
        drawLine(pos + radius * 0.92 * dir, pos + radius * 0.85 * dir)

    setFontSize(15)
    for i in range(0, majorCount + 1)
      let angle = startAngle + float(i * minorPerMajor) * minorStep
      var sina, cosa = 0.0
      sincos(angle * degToRad, sina, cosa)
      let textR = radius * 0.68
      let val = minVal + (maxVal - minVal) * float(i) / float(majorCount)
      drawStrAnchored(pos + textR * float2(cosa, sina * aspect), "{int(val)}", AnchorHorz.Center, AnchorVert.Center)

    let normalizedVal = clamp((value - minVal) / (maxVal - minVal), 0.0, 1.0)
    let needleAngle = startAngle + normalizedVal * span
    var needleSin, needleCos = 0.0
    sincos(needleAngle * degToRad, needleSin, needleCos)
    setColor(CLR_RED)
    setLineWidth(2.0)
    drawLine(pos, pos + radius * 0.75 * float2(needleCos, needleSin * aspect))
    setLineWidth(1.5)

    setColor(CLR_RED)
    setFillColor(CLR_RED)
    drawRoundCircle(pos, radius * 0.06)
    setFillColor(CLR_NONE)

    setColor(CLR_WHT)
    setFontSize(15)
    drawStrAnchored(pos + float2(0.0, -radius * 0.40 * aspect), lbl, AnchorHorz.Center, AnchorVert.Center)

  def drawSmallGauge(pos : float2; radius : float; value : float; minVal : float; maxVal : float; lbl : string)
    let startAngle = 135.0
    let endAngle = 375.0
    let span = endAngle - startAngle

    let arcN = 40
    for i in range(0, arcN)
      let a0 = startAngle + span * float(i) / float(arcN)
      let a1 = startAngle + span * float(i + 1) / float(arcN)
      let frac = float(i) / float(arcN)
      if frac > 0.85
        setColor(CLR_RED)
      elif frac > 0.7
        setColor(CLR_YEL)
      else
        setColor(CLR_GRN)
      var s0, c0, s1, c1 = 0.0
      sincos(a0 * degToRad, s0, c0)
      sincos(a1 * degToRad, s1, c1)
      let r0 = radius * 0.88
      drawLine(pos + r0 * float2(c0, s0 * aspect), pos + r0 * float2(c1, s1 * aspect))

    setColor(CLR_WHT)
    let tickCount = 5
    let tickStep = span / float(tickCount)
    for i in range(0, tickCount + 1)
      let angle = startAngle + float(i) * tickStep
      var sina, cosa = 0.0
      sincos(angle * degToRad, sina, cosa)
      let outerR = radius * 0.84
      let innerR = radius * 0.72
      drawLine(pos + outerR * float2(cosa, sina * aspect), pos + innerR * float2(cosa, sina * aspect))

    let normalizedVal = clamp((value - minVal) / (maxVal - minVal), 0.0, 1.0)
    let needleAngle = startAngle + normalizedVal * span
    var needleSin, needleCos = 0.0
    sincos(needleAngle * degToRad, needleSin, needleCos)
    setColor(CLR_RED)
    setLineWidth(1.5)
    drawLine(pos, pos + radius * 0.65 * float2(needleCos, needleSin * aspect))

    setColor(CLR_YEL)
    setFontSize(14)
    drawStrAnchored(pos + float2(0.0, radius * 0.2), lbl, AnchorHorz.Center, AnchorVert.Center)

  def drawInfoPanel()
    setColor(CLR_GRN)
    setFontSize(15)

    let leftX = -1.15
    let rightX = 0.68
    let row1 = 0.32
    let rowStep = 0.06

    drawStrAnchored(float2(leftX, row1), "Ost.gor", AnchorHorz.Left, AnchorVert.Center)
    setColor(CLR_YEL)
    drawStrAnchored(float2(leftX + 0.28, row1), "{int(eng.fuelKg / 0.8)} Lt", AnchorHorz.Left, AnchorVert.Center)

    setColor(CLR_GRN)
    drawStrAnchored(float2(leftX, row1 + rowStep), "Gen. V", AnchorHorz.Left, AnchorVert.Center)
    setColor(CLR_YEL)
    drawStrAnchored(float2(leftX + 0.28, row1 + rowStep), "28.5", AnchorHorz.Left, AnchorVert.Center)

    setColor(CLR_GRN)
    drawStrAnchored(float2(rightX, row1), "Ost.gor", AnchorHorz.Left, AnchorVert.Center)
    setColor(CLR_YEL)
    drawStrAnchored(float2(rightX + 0.28, row1), "{int(eng.fuelKg / 0.8)} Lt", AnchorHorz.Left, AnchorVert.Center)

    setColor(CLR_GRN)
    drawStrAnchored(float2(rightX, row1 + rowStep), "Gen.A", AnchorHorz.Left, AnchorVert.Center)
    setColor(CLR_YEL)
    drawStrAnchored(float2(rightX + 0.28, row1 + rowStep), "800 Amp", AnchorHorz.Left, AnchorVert.Center)

  def drawLabels()
    setColor(CLR_WHT)
    setFontSize(12)
    drawStrAnchored(float2(-0.42, -0.48), "R.P.M", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.42, -0.48), "R.P.M", AnchorHorz.Center, AnchorVert.Center)

  def drawDivider()
    setColor(CLR_YEL)
    setLineWidth(1.0)
    drawLine(float2(0.0, -0.47), float2(0.0, 0.44))
    setColor(CLR_WHT)
    setFontSize(15)
    drawStrAnchored(float2(-0.06, -0.4), "Levi", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(0.06, -0.4), "Desni", AnchorHorz.Left, AnchorVert.Center)

  def draw()
    return if !isValid
    setFullCanvasViewport()
    setColor(CLR_BG)
    setFillColor(CLR_BG)
    drawBox(float2(-1.0, -0.5), float2(1.0, 0.5))
    setFillColor(CLR_NONE)

    drawLabels()
    drawDivider()

    let rpmOffset = 120.0
    let rpmFade = 6.0
    let rpmVal1 = eng.rpm1 < 0.1 ? 0.0 : eng.rpm1 < rpmFade ? (eng.rpm1 / rpmFade) * (eng.rpm1 + rpmOffset) : clamp(eng.rpm1 + rpmOffset, 0.0, 290.0)
    let rpmVal2 = eng.rpm2 < 0.1 ? 0.0 : eng.rpm2 < rpmFade ? (eng.rpm2 / rpmFade) * (eng.rpm2 + rpmOffset) : clamp(eng.rpm2 + rpmOffset, 0.0, 290.0)
    drawGauge(float2(-0.590, -0.10), 0.457, rpmVal1, 0.0, 300.0, "Kp/cm2")
    drawGauge(float2(0.590, -0.10), 0.457, rpmVal2, 0.0, 300.0, "Kp/cm2")

    drawSmallGauge(float2(-0.238, 0.30), 0.201, eng.temp1, 0.0, 1000.0, "T\xC2\xB0 Levo")
    drawSmallGauge(float2(0.238, 0.30), 0.201, eng.temp2, 0.0, 1000.0, "T\xC2\xB0 Desno")

    drawInfoPanel()
    restoreViewport()


[export, unused_argument(rstate)]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  var es = EngState()
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  var fmw = hero |> as_fmw()
  if fmw == null
    return
  if fmw.fm == null
    return
  if fmw.fm.EI != null && fmw.fm.EI.numEngines > 0
    assume propulsion = *(fmw.fm.EI)
    propulsion_getEngine(propulsion, 0) <| $(mainEngine)
      es.rpm1 = mainEngine.omegaRel * 100.0
      es.temp1 = mainEngine.waterTemp + ZERO_KELVIN
      if fmw.fm.EI.numEngines > 1
        propulsion_getEngine(propulsion, 1) <| $(secondEngine)
          es.rpm2 = secondEngine.omegaRel * 100.0
          es.temp2 = secondEngine.waterTemp + ZERO_KELVIN
  es.fuelKg = getFuelMassCurrent(fmw.fm.M, 0)
  new Component(guiCtx, rdata, rstate, props, es).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
