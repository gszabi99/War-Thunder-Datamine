require %gameLibs.das.math.base
require %rGui.utils.canvas_common
require %rGui.planeCockpit.mfdZ19_common

require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require math
require Plane


struct PropStorage
  fontId : int


class Component : Canvas
  isValid   : bool = false
  propulsion : Propulsion? = null

  @safe_when_uninitialized engines : EngineData[2]
  @safe_when_uninitialized rotor  : RotorData


  def Component(var gui_ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, gui_ctx, rdata, rstate)
    var hero = get_watched_not_delayed_hero()
    return if hero == null
    var fmw = hero.as_fmw()
    return if fmw == null
    var fm = fmw.fm
    return if fm == null
    propulsion = fm.EI
    return if propulsion == null || propulsion.numEngines < 1 || propulsion.numEngines > 2

    isValid = true
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFont(props.fontId)
    setFontSize(14)

    engines[0] <- get_engine_data(propulsion, 0)
    if propulsion.numEngines == 2
      engines[1] <- get_engine_data(propulsion, 1)
    else
      engines[1] := engines[0]
    rotor <- get_rotor_data(propulsion, 0)


  def drawTicks(pos : float2; gauge_h, width : float; count : int; yellow_frac, red_frac : float; flip : bool)
    for i in 0 .. count + 1
      let tickT = float(i) / float(count)
      let tickY = pos.y - gauge_h * tickT
      setColor(tickT > red_frac ? COLOR_RED : (tickT > yellow_frac ? COLOR_YELLOW : COLOR_GREEN))
      drawLine(float2(pos.x, tickY), float2(pos.x + (flip ? -width : width), tickY))


  def drawVertGauge(pos : float2; size : float2; size_h : float2; val : float; val_txt : string;
                    min_val : float; max_val : float; yellow_start : float = 0.0; red_start : float = 0.0;
                    ticks_left : bool = true; ticks_right : bool = true)
    let lt = float2(pos.x - size_h.x, pos.y - size_h.y)
    let rb = float2(pos.x + size_h.x, pos.y + size_h.y)
    let linewidth = float2(toRelY(lineWidthHdpx)) // To deal with AA issues
    let tickWidth = 0.005

    let t = clamp((val - min_val) / (max_val - min_val), 0.0, 1.0)
    setFillColor(COLOR_GREEN)
    setColor(COLOR_NULL)
    drawBox(float2(lt.x, rb.y - size.y) - linewidth, rb + linewidth)

    var yellowFrac, redFrac = 1.0
    if abs(yellow_start) > FLT_EPSILON
      yellowFrac = clamp((yellow_start + 1.0 - min_val) / (max_val - min_val), 0.0, 1.0)
      setFillColor(COLOR_YELLOW)
      drawBox(float2(lt.x, rb.y - size.y) - linewidth, float2(rb.x, rb.y - size.y * yellowFrac) + linewidth)
    if abs(red_start) > FLT_EPSILON
      redFrac = clamp((red_start + 1.0 - min_val) / (max_val - min_val), 0.0, 1.0)
      setFillColor(COLOR_RED)
      drawBox(float2(lt.x, lt.y) - linewidth, float2(rb.x, rb.y - size.y * redFrac) + linewidth)

    let needleY = rb.y - size.y * t
    setFillColor(COLOR_BLACK)
    if needleY > lt.y
      drawBox(lt, float2(rb.x, needleY))

    setLineWidth(2.0)
    if ticks_right
      drawTicks(float2(rb.x, rb.y), size.y, tickWidth, 20, yellowFrac, redFrac, false)
    else
      setColor(COLOR_BLACK)
      drawLine(rb, float2(rb.x, needleY))
    if ticks_left
      drawTicks(float2(lt.x, rb.y), size.y, tickWidth, 20, yellowFrac, redFrac, true)
    else
      setColor(COLOR_BLACK)
      drawLine(float2(lt.x, rb.y), float2(lt.x, needleY))
    setLineWidth(1.0)

    setColor(COLOR_GREEN)
    let offsetY = 0.01
    var posX = pos.x
    var anchorH = AnchorHorz.Center
    if ticks_left && !ticks_right
      posX -= size_h.x
      anchorH = AnchorHorz.Right
    elif ticks_right && !ticks_left
      posX += size_h.x
      anchorH = AnchorHorz.Left
    drawStrAnchored(float2(posX, lt.y - offsetY), val_txt, anchorH, AnchorVert.Bottom)


  def drawOsbLeft()
    let margin = float2(0.01, 0.12)
    let count = 5
    let pos = float2(-0.5) + margin
    let step = (1.0 - margin.y * 2.0) / float(count - 1)

    setColor(COLOR_GREEN)
    setFillColor(COLOR_NULL)
    let c1Bbox = drawStrAnchored(pos, "发动机", AnchorHorz.Left, AnchorVert.Center)
    setColor(COLOR_WHITE)
    drawBBox(c1Bbox, 0.005)
    setColor(COLOR_GREEN)

    drawStrAnchored(float2(pos.x, pos.y + step), "传动液压", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(pos.x, pos.y + step * 2.0), "电器", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(pos.x, pos.y + step * 3.0), "历程", AnchorHorz.Left, AnchorVert.Center)


  def drawOsbBot()
    let margin = float2(0.06, 0.03)
    let count = 7
    let pos = float2(-0.5 + margin.x, 0.5 - margin.y)
    let step = (1.0 - margin.x * 2.0) / float(count - 1)
    drawStrAnchored(float2(pos.x + step * 2.0, pos.y), "火控", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(pos.x + step * 3.0, pos.y), "主菜单", AnchorHorz.Center, AnchorVert.Center)


  def drawLbl(pos : float2; lbl : string)
    setColor(COLOR_GREEN)
    drawStrAnchored(pos, lbl, AnchorHorz.Center, AnchorVert.Top)


  def drawGauges()
    let size = float2(0.03, 0.3)
    let hSize = size * 0.5

    var tPos = float2(-0.25, -0.37 + hSize.y)
    let tStep = 0.2
    let tLblY = tPos.y + hSize.y + 0.02

    var bPos = float2(-0.32, 0.05 + hSize.y)
    let bStep = 0.168
    let bLblY = bPos.y + hSize.y + 0.02

    assume e0 = engines[0]
    assume e1 = engines[1]

    drawVertGauge(float2(tPos.x - hSize.x, tPos.y), size, hSize, e0.turbineRpmRel, "{roundi(e0.turbineRpmRel)}", 0.0, 130.0, 100.0, 110.0, true, false)
    drawVertGauge(float2(tPos.x + hSize.x, tPos.y), size, hSize, e1.turbineRpmRel, "{roundi(e1.turbineRpmRel)}", 0.0, 130.0, 100.0, 110.0, false, true)
    drawLbl(float2(tPos.x, tLblY), "Np")

    tPos.x += tStep
    drawVertGauge(float2(tPos.x - hSize.x, tPos.y), size, hSize, e0.torqueRel, fmt(":.1f", e0.torqueRel), 0.0, 130.0, 100.0, 110.0, true, false)
    drawVertGauge(float2(tPos.x + hSize.x, tPos.y), size, hSize, e1.torqueRel, fmt(":.1f", e1.torqueRel), 0.0, 130.0, 100.0, 110.0, false, true)
    drawLbl(float2(tPos.x, tLblY), "Q")

    tPos.x += tStep
    drawVertGauge(float2(tPos.x - hSize.x, tPos.y), size, hSize, e0.turbineRpmRel, "{roundi(e0.turbineRpmRel)}", 0.0, 130.0, 100.0, 110.0, true, false)
    drawVertGauge(float2(tPos.x + hSize.x, tPos.y), size, hSize, e1.turbineRpmRel, "{roundi(e1.turbineRpmRel)}", 0.0, 130.0, 100.0, 110.0, false, true)
    drawLbl(float2(tPos.x, tLblY), "Ng")

    tPos.x += tStep
    drawVertGauge(float2(tPos.x - hSize.x, tPos.y), size, hSize, e0.turbineTemp, "{roundi(e0.turbineTemp)}", 0.0, e0.turbineTempMax[2], e0.turbineTempMax[0], e0.turbineTempMax[1], true, false)
    drawVertGauge(float2(tPos.x + hSize.x, tPos.y), size, hSize, e1.turbineTemp, "{roundi(e1.turbineTemp)}", 0.0, e1.turbineTempMax[2], e1.turbineTempMax[0], e1.turbineTempMax[1], false, true)
    drawLbl(float2(tPos.x, tLblY), "T4 5")

    drawVertGauge(float2(bPos.x - hSize.x, bPos.y), size, hSize, rotor.nr, "{roundi(rotor.nr)}", 0.0, 500.0, 400.0, 450.0, true, true)
    drawLbl(float2(bPos.x - hSize.x, bLblY), "Nr")

    bPos.x += bStep
    drawVertGauge(float2(bPos.x - hSize.x, bPos.y), size, hSize, e0.oilLvlRel, "{roundi(e0.oilLvlRel)}", 0.0, 100.0, 0.0, 0.0, true, false)
    drawVertGauge(float2(bPos.x + hSize.x, bPos.y), size, hSize, e1.oilLvlRel, "{roundi(e1.oilLvlRel)}", 0.0, 100.0, 0.0, 0.0, false, true)
    drawLbl(float2(bPos.x, bLblY), "OLP")

    bPos.x += bStep
    drawVertGauge(float2(bPos.x - hSize.x, bPos.y), size, hSize, e0.fuelPresRel, fmt(":.1f", e0.fuelPresRel), 0.0, 1.0, 0.0, 0.0, true, false)
    drawVertGauge(float2(bPos.x + hSize.x, bPos.y), size, hSize, e1.fuelPresRel, fmt(":.1f", e1.fuelPresRel), 0.0, 1.0, 0.0, 0.0, false, true)
    drawLbl(float2(bPos.x, bLblY), "Fp")

    bPos.x += bStep
    drawVertGauge(float2(bPos.x - hSize.x, bPos.y), size, hSize, e0.oilTemp, "{roundi(e0.oilTemp)}", 0.0, e0.oilTempMax[2], e0.oilTempMax[0], e0.oilTempMax[1], true, false)
    drawVertGauge(float2(bPos.x + hSize.x, bPos.y), size, hSize, e1.oilTemp, "{roundi(e1.oilTemp)}", 0.0, e1.oilTempMax[2], e1.oilTempMax[0], e1.oilTempMax[1], false, true)
    drawLbl(float2(bPos.x, bLblY), "Tm")

    bPos.x += bStep
    drawVertGauge(float2(bPos.x - hSize.x, bPos.y), size, hSize, e0.oilPresRel, fmt(":.2f", e0.oilPresRel), 0.0, 1.0, 0.0, 0.0, true, false)
    drawVertGauge(float2(bPos.x + hSize.x, bPos.y), size, hSize, e1.oilPresRel, fmt(":.2f", e1.oilPresRel), 0.0, 1.0, 0.0, 0.0, false, true)
    drawLbl(float2(bPos.x, bLblY), "Pm")


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawOsbLeft()
    drawOsbBot()
    drawGauges()
    restoreViewport()


[export]
def render(var gui_ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(gui_ctx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
