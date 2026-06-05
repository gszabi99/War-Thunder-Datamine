require %gameLibs.das.math.base
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require math
require Plane
require Unit


let
  CLR      = E3DCOLOR(0xFF_80FF00)
  CLR_DIM  = E3DCOLOR(0xFF_406000)
  CLR_RED  = E3DCOLOR(0xFF_FF2020)
  CLR_BG   = E3DCOLOR(0xFF_000000)
  CLR_NONE = E3DCOLOR(0x00_000000)
  CLR_SKY  = E3DCOLOR(uint4(0, 50, 200, 255))
  CLR_GND  = E3DCOLOR(uint4(60, 2, 0, 255))
  CLR_WHT  = E3DCOLOR(0xFF_FFFFFF)
  CLR_GRN  = E3DCOLOR(0xFF_00CC00)
  CLR_GREY = E3DCOLOR(0xFF_444444)

  GRID_L = -0.585
  GRID_T = -0.46
  COL_W  = 0.39
  ROW_H  = 0.3067
  GR     = 0.105


struct PropStorage
  fontId : int


def ccx(col : int) : float
  return GRID_L + COL_W * (float(col) + 0.5)

def ccy(row : int) : float
  return GRID_T + ROW_H * (float(row) + 0.5)

def clt(col : int; row : int) : float2
  return float2(GRID_L + COL_W * float(col), GRID_T + ROW_H * float(row))

def crb(col : int; row : int) : float2
  return float2(GRID_L + COL_W * float(col + 1), GRID_T + ROW_H * float(row + 1))


class Component : Canvas
  isValid   : bool = false
  hero      : Unit? = null
  fmw       : FlightModelWrap? = null
  appRef    : AcesApp? = null
  pitchDeg  : float = 0.0
  rollDeg   : float = 0.0
  hdgDeg    : float = 0.0
  iasKph    : float = 0.0
  altM      : float = 0.0
  vs        : float = 0.0

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    if hero == null
      return
    fmw = hero.as_fmw()
    if fmw == null
      return
    let fm = fmw.fm
    if fm == null
      return
    appRef = get_app()
    if appRef == null
      return
    isValid  = true
    pitchDeg = fmw.tangage
    rollDeg  = fmw.roll
    hdgDeg   = (atan2(hero.unitTm[0].x, hero.unitTm[0].z) * RAD_TO_DEG + 360.0) % 360.0
    iasKph   = fmw.ias * MPS_TO_KPH
    altM     = hero.unitTm[3].y - appRef.currentScene.waterLevel
    vs       = fm.vertSpeed
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(9)
    setColor(CLR)

  // ════════════════ helpers ════════════════

  def drawTick(pos : float2; size : float; angle_deg : float; len : float)
    var sina, cosa = 0.0
    sincos(angle_deg * DEG_TO_RAD, sina, cosa)
    let d = float2(sina, -cosa)
    drawLine(pos + (size - len) * d, pos + size * d)

  def drawTicks(pos : float2; angle0 : float; step : float; size : float; len : float; count : int)
    var angle = angle0
    for _ in range(0, count)
      drawTick(pos, size, angle, len)
      angle += step

  def drawNeedle(pos : float2; size : float; aDeg : float)
    var sina, cosa = 0.0
    sincos(aDeg * DEG_TO_RAD, sina, cosa)
    var pts = to_array_move(fixed_array(
      float2(0.04, 0.0),
      float2(0.04, 0.80),
      float2(0.0, 1.0),
      float2(-0.04, 0.80),
      float2(-0.04, 0.0)))
    setFillColor(CLR)
    drawFilledPolyOutlined(pts.scale(float2(size)).rotate(-sina, -cosa).translate(pos))
    setFillColor(CLR_NONE)

  def drawGaugeBg(pos : float2; size : float)
    setColor(CLR)
    setFillColor(CLR_BG)
    drawCircle(pos, size)
    setFillColor(CLR_NONE)
    setColor(CLR)

  // ════════════════ layout ════════════════

  def drawBackground()
    setColor(CLR_BG)
    setFillColor(CLR_BG)
    drawBox(float2(-0.5, -0.5), float2(0.5, 0.5))
    setFillColor(CLR_NONE)

  def drawGrid()
    setColor(CLR_WHT)
    setFillColor(CLR_NONE)
    // left and right columns: 3 rows each
    for row in range(0, 3)
      drawBox(clt(0, row), crb(0, row))
      drawBox(clt(2, row), crb(2, row))
    // middle column: 2 cells (attitude 60%, compass 40%)
    let midSplit = GRID_T + ROW_H * 1.5
    drawBox(float2(GRID_L + COL_W, GRID_T), float2(GRID_L + COL_W * 2.0, midSplit))
    drawBox(float2(GRID_L + COL_W, midSplit), float2(GRID_L + COL_W * 2.0, GRID_T + ROW_H * 3.0))

  def drawSideLabels()
    setFontSize(11)
    let y0 = -0.38
    let x = 0.628
    let dy = 0.153
    setColor(CLR)
    drawStrAnchored(float2(-x, y0),            "BAL",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy),       "MFD",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy * 2.0), "B/W",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy * 3.0), "E-O",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy * 4.0), "Corr", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy * 5.0), "Wnd",  AnchorHorz.Center, AnchorVert.Center)
    setColor(CLR_RED)
    drawStrAnchored(float2(x, y0), "FCS", AnchorHorz.Center, AnchorVert.Center)
    setColor(CLR)
    drawStrAnchored(float2(x, y0 + dy),       "PFD",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x, y0 + dy * 2.0), "NAV",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x, y0 + dy * 3.0), "STP",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x, y0 + dy * 4.0), "A-AE", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x, y0 + dy * 5.0), "Exit", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(9)

  // ════════════════ 1. Brzinomer — speedometer (0,0) ════════════════

  def drawSpeedometer()
    let pos = float2(ccx(0), ccy(0))
    let radius = GR * 0.85
    let angle0 = 30.0
    let span = 300.0
    let spdMin = 100.0
    let spdMax = 1100.0
    let spdRange = spdMax - spdMin
    let degPer100 = span / 10.0
    var sina0, cosa0, sina1, cosa1 = 0.0
    // black fill background
    setColor(CLR_BG)
    setFillColor(CLR_BG)
    drawCircle(pos, radius)
    setFillColor(CLR_NONE)
    // colored arcs FIRST (below white arc and ticks)
    let arcR0 = radius
    let arcN = 60
    setLineWidth(2.0)
    // green: 175 to 950 km/h
    let greenStartA = angle0 + (175.0 - spdMin) / spdRange * span
    let greenEndA = angle0 + (950.0 - spdMin) / spdRange * span
    setColor(CLR_GRN)
    let greenSpan = greenEndA - greenStartA
    for layer in range(0, 3)
      let rr = arcR0 + float(layer) * 0.003
      for i in range(0, arcN)
        let aa = greenStartA + greenSpan * float(i) / float(arcN)
        let ab = greenStartA + greenSpan * float(i + 1) / float(arcN)
        sincos(aa * DEG_TO_RAD, sina0, cosa0)
        sincos(ab * DEG_TO_RAD, sina1, cosa1)
        drawLine(pos + rr * float2(sina0, -cosa0), pos + rr * float2(sina1, -cosa1))
    // yellow: 950 to 1025 km/h
    let yellowStartA = angle0 + (950.0 - spdMin) / spdRange * span
    let yellowEndA = angle0 + (1025.0 - spdMin) / spdRange * span
    setColor(CLR)
    let yellowSpan = yellowEndA - yellowStartA
    for layer in range(0, 3)
      let rr = arcR0 + float(layer) * 0.003
      for i in range(0, 10)
        let aa = yellowStartA + yellowSpan * float(i) / 10.0
        let ab = yellowStartA + yellowSpan * float(i + 1) / 10.0
        sincos(aa * DEG_TO_RAD, sina0, cosa0)
        sincos(ab * DEG_TO_RAD, sina1, cosa1)
        drawLine(pos + rr * float2(sina0, -cosa0), pos + rr * float2(sina1, -cosa1))
    // red: 1025 to 1100 km/h
    let redStartA = angle0 + (1025.0 - spdMin) / spdRange * span
    let redEndA = angle0 + span
    setColor(CLR_RED)
    let redSpan = redEndA - redStartA
    for layer in range(0, 3)
      let rr = arcR0 + float(layer) * 0.003
      for i in range(0, 10)
        let aa = redStartA + redSpan * float(i) / 10.0
        let ab = redStartA + redSpan * float(i + 1) / 10.0
        sincos(aa * DEG_TO_RAD, sina0, cosa0)
        sincos(ab * DEG_TO_RAD, sina1, cosa1)
        drawLine(pos + rr * float2(sina0, -cosa0), pos + rr * float2(sina1, -cosa0))
    setLineWidth(1.0)
    // white circle arc and ticks ON TOP
    setColor(CLR_WHT)
    let circleN = 80
    for i in range(0, circleN)
      let aa = angle0 + span * float(i) / float(circleN)
      let ab = angle0 + span * float(i + 1) / float(circleN)
      sincos(aa * DEG_TO_RAD, sina0, cosa0)
      sincos(ab * DEG_TO_RAD, sina1, cosa1)
      drawLine(pos + radius * float2(sina0, -cosa0), pos + radius * float2(sina1, -cosa1))
    // major ticks OUTWARD (every 100 km/h, 11 ticks: 100..1100)
    drawTicks(pos, angle0, degPer100, radius + 0.014, 0.014, 11)
    // minor ticks OUTWARD (every 20 km/h, skip major positions)
    let minorStep = span / 50.0
    for i in range(0, 51)
      if i % 5 != 0
        let angle = angle0 + float(i) * minorStep
        drawTick(pos, radius + 0.008, angle, 0.008)
    setColor(CLR_WHT)
    // labels outside the arcs
    setFontSize(15)
    for i in range(0, 11)
      let angle = angle0 + float(i) * degPer100
      sincos(angle * DEG_TO_RAD, sina0, cosa0)
      drawStrAnchored(pos + (radius + 0.028) * float2(sina0, -cosa0), "{(i + 1) * 100}", AnchorHorz.Center, AnchorVert.Center)
    // needle
    let spd = clamp(iasKph, spdMin, spdMax)
    let needleA = angle0 + (spd - spdMin) / spdRange * span
    // red counterweight (draw before needle)
    sincos(needleA * DEG_TO_RAD, sina0, cosa0)
    let tailTip = pos + radius * 0.22 * float2(-sina0, cosa0)
    let perpD = float2(sina0, cosa0)
    setColor(CLR_RED)
    setFillColor(CLR_RED)
    drawFilledPolyOutlined([tailTip, pos + 0.007 * perpD, pos - 0.007 * perpD])
    setFillColor(CLR_NONE)
    setColor(CLR)
    drawNeedle(pos, radius * 0.80, needleA)
    // center dot
    setFillColor(CLR)
    drawCircle(pos, 0.005)
    setFillColor(CLR_NONE)
    // title
    setFontSize(9)
    drawStrAnchored(pos + float2(0.0, 0.020), "Brzinomer", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.0, 0.035), "[Km/h]", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(9)

  // ════════════════ 2. Valjanji — attitude indicator (1,0) ════════════════

  def drawAttitudeIndicator()
    let cx = ccx(1)
    let midSplit = GRID_T + ROW_H * 1.5
    let cy = (GRID_T + midSplit) * 0.5
    let pos = float2(cx, cy)
    let lt = float2(GRID_L + COL_W + 0.002, GRID_T + 0.002)
    let rb = float2(GRID_L + COL_W * 2.0 - 0.002, midSplit - 0.002)
    let radius = (midSplit - GRID_T) * 0.4
    let pitchScale = radius / 50.0
    // clip to cell
    setViewport(lt, rb)
    // rotate for roll
    setRotation(pos, -rollDeg * DEG_TO_RAD)
    // pitch offset — unified scale
    let horY = cy + pitchDeg * pitchScale
    // sky
    setColor(CLR_SKY)
    setFillColor(CLR_SKY)
    drawBox(float2(cx - 0.3, cy - 0.3), float2(cx + 0.3, horY))
    // ground
    setColor(CLR_GND)
    setFillColor(CLR_GND)
    drawBox(float2(cx - 0.3, horY), float2(cx + 0.3, cy + 0.3))
    // horizon line with vertical ticks
    setColor(CLR_WHT)
    setFillColor(CLR_NONE)
    drawLine(float2(cx - 0.2, horY), float2(cx + 0.2, horY))
    // heading tape on horizon line — ticks every 5°, numbers every 30°
    setFontSize(8)
    let hdgRange = 70.0
    let unitsPerDeg = 0.4 / hdgRange
    let hdgStartI = floori((hdgDeg - hdgRange * 0.5) / 5.0) * 5
    for i in range(0, 16)
      let markHdg = float(hdgStartI) + float(i) * 5.0
      let dx = (markHdg - hdgDeg) * unitsPerDeg
      let tx = cx + dx
      if tx < cx - 0.19
        continue
      if tx > cx + 0.19
        continue
      let normalizedHdg = (int(markHdg + 3600.0)) % 360
      let hasNumber = normalizedHdg % 30 == 0
      let isMajor = normalizedHdg % 10 == 0
      let tickH = isMajor ? 0.012 : 0.007
      drawLine(float2(tx, horY), float2(tx, horY - tickH))
      if hasNumber
        drawStrAnchored(float2(tx, horY - tickH - 0.006), "{normalizedHdg / 10}", AnchorHorz.Center, AnchorVert.Center)
    // pitch ladder — dense center ticks every 1°, lines at 5° and 10°
    setFontSize(14)
    for i in range(0, 61)
      let markVal = floori(pitchDeg) + (i - 30)
      if markVal == 0
        continue
      let markY = cy + (pitchDeg - float(markVal)) * pitchScale
      if abs(markVal) % 10 == 0
        // 10° lines: full width through center
        drawLine(float2(cx - radius * 0.40, markY), float2(cx + radius * 0.40, markY))
        drawStrAnchored(float2(cx - radius * 0.45, markY), "{abs(markVal)}", AnchorHorz.Right, AnchorVert.Center)
        drawStrAnchored(float2(cx + radius * 0.45, markY), "{abs(markVal)}", AnchorHorz.Left, AnchorVert.Center)
      elif abs(markVal) % 5 == 0
        // 5° lines: shorter
        drawLine(float2(cx - radius * 0.20, markY), float2(cx + radius * 0.20, markY))
      else
        // 1° ticks: small center marks
        drawLine(float2(cx - radius * 0.05, markY), float2(cx + radius * 0.05, markY))
    // roll ticks at top (no arc line, only ticks)
    setColor(CLR_WHT)
    let arcR = radius * 0.85
    // roll ticks at 10°, 20°, 30°
    for tick in range(0, 7)
      let deg = -30.0 + float(tick) * 10.0
      let aRad = (deg - 90.0) * DEG_TO_RAD
      var sina, cosa = 0.0
      sincos(aRad, sina, cosa)
      let tickLen = abs(deg) < 25.0 ? 0.012 : 0.018
      drawLine(float2(cx + (arcR - tickLen) * cosa, cy + (arcR - tickLen) * sina), float2(cx + arcR * cosa, cy + arcR * sina))
    // roll pointer triangle (rotates with horizon)
    setFillColor(CLR_WHT)
    let triTop <- to_array_move(fixed_array(
      float2(cx, cy - arcR + 0.002),
      float2(cx - radius * 0.04, cy - arcR + 0.018),
      float2(cx + radius * 0.04, cy - arcR + 0.018)))
    drawFilledPolyOutlined(triTop)
    setFillColor(CLR_NONE)
    // end rotation
    resetViewTm()
    // static B-2 silhouette (yellow, does NOT rotate)
    setColor(CLR)
    setFillColor(CLR)
    // left half: nose → left tip → trailing edge notch → back to center
    drawFilledPolyOutlined([
      float2(cx,        cy - 0.010),
      float2(cx - 0.04, cy - 0.002),
      float2(cx - 0.11, cy + 0.005),
      float2(cx - 0.10, cy + 0.012),
      float2(cx - 0.05, cy + 0.007),
      float2(cx,        cy + 0.012)])
    // right half (mirror)
    drawFilledPolyOutlined([
      float2(cx,        cy - 0.010),
      float2(cx + 0.04, cy - 0.002),
      float2(cx + 0.11, cy + 0.005),
      float2(cx + 0.10, cy + 0.012),
      float2(cx + 0.05, cy + 0.007),
      float2(cx,        cy + 0.012)])
    setFillColor(CLR_NONE)
    // title
    setColor(CLR_WHT)
    setFontSize(6)
    drawStrAnchored(float2(cx - 0.08, lt.y + 0.012), "Prop. {fmt(":03d", int(pitchDeg))}", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(cx + 0.08, lt.y + 0.012), "Valjanji {fmt(":03d", int(rollDeg))}", AnchorHorz.Right, AnchorVert.Top)
    setFontSize(9)
    restoreViewport()

  // ════════════════ 3. Visina — altimeter (2,0) ════════════════

  def drawAltimeter()
    let pos = float2(ccx(2), ccy(0))
    let radius = GR * 0.80
    let majorStep = 36.0
    // black fill background (no visible circle outline)
    setColor(CLR_BG)
    setFillColor(CLR_BG)
    drawCircle(pos, radius)
    setFillColor(CLR_NONE)
    // white ticks pointing OUTWARD
    setColor(CLR_WHT)
    // major ticks outward (every 100m, 10 ticks)
    drawTicks(pos, 0.0, majorStep, radius + 0.014, 0.014, 10)
    // minor ticks (1 between each major = every 18°, skip major positions)
    for i in range(0, 20)
      if i % 2 != 0
        let angle = float(i) * majorStep / 2.0
        drawTick(pos, radius + 0.008, angle, 0.008)
    // numbers 0-9 white, outside ticks
    setFontSize(14)
    for i in range(0, 10)
      let angle = float(i) * majorStep
      var sina, cosa = 0.0
      sincos(angle * DEG_TO_RAD, sina, cosa)
      drawStrAnchored(pos + (radius + 0.025) * float2(sina, -cosa), "{i}", AnchorHorz.Center, AnchorVert.Center)
    // digital readout box LEFT side (drum counter style)
    setColor(CLR_WHT)
    setFillColor(CLR_BG)
    let boxLt = pos + float2(-0.088, -0.020)
    let boxRb = pos + float2(-0.008, 0.020)
    drawBox(boxLt, boxRb)
    // digit separators
    let digitW = (boxRb.x - boxLt.x) / 4.0
    for i in range(1, 4)
      let lx = boxLt.x + float(i) * digitW
      drawLine(float2(lx, boxLt.y), float2(lx, boxRb.y))
    setFillColor(CLR_NONE)
    // draw each digit in its cell
    setFontSize(14)
    let altInt = int(clamp(altM, 0.0, 9999.0))
    let d0 = altInt / 1000
    let d1 = (altInt / 100) % 10
    let d2 = (altInt / 10) % 10
    let d3 = altInt % 10
    drawStrAnchored(float2(boxLt.x + digitW * 0.5, pos.y), "{d0}", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(boxLt.x + digitW * 1.5, pos.y), "{d1}", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(boxLt.x + digitW * 2.5, pos.y), "{d2}", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(boxLt.x + digitW * 3.5, pos.y), "{d3}", AnchorHorz.Center, AnchorVert.Center)
    // needles
    setColor(CLR)
    let hundredsAngle = (altM % 1000.0) * 360.0 / 1000.0
    drawNeedle(pos, radius * 0.78, hundredsAngle)
    let thousandsAngle = altM * 360.0 / 10000.0
    drawNeedle(pos, radius * 0.50, thousandsAngle)
    // center dot
    setFillColor(CLR_WHT)
    drawCircle(pos, 0.005)
    setFillColor(CLR_NONE)
    // title
    setColor(CLR)
    setFontSize(9)
    drawStrAnchored(pos + float2(0.0, 0.04), "Visina", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.0, 0.055), "[m] x 1000", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(9)

  // ════════════════ 4. Ug.Kursa — course display (0,1) ════════════════

  def drawCourseDisplay()
    let cx = ccx(0)
    let cy = ccy(1)
    let lt = clt(0, 1)
    let rb = crb(0, 1)
    let pos = float2(cx, cy)
    let compassR = 0.12
    let frameR = compassR * 0.92
    // 1. white static frame ┌ ┐ └ ┘ (drawn first, below compass)
    setColor(CLR_WHT)
    let cornerL = 0.033
    let flt = pos + float2(-frameR, -frameR)
    let frt = pos + float2(frameR, -frameR)
    let flb = pos + float2(-frameR, frameR)
    let frb = pos + float2(frameR, frameR)
    // top-left ┌
    drawLine(flt, flt + float2(cornerL, 0.0))
    drawLine(flt, flt + float2(0.0, cornerL))
    // top-right ┐
    drawLine(frt, frt + float2(-cornerL, 0.0))
    drawLine(frt, frt + float2(0.0, cornerL))
    // bottom-left └
    drawLine(flb, flb + float2(cornerL, 0.0))
    drawLine(flb, flb + float2(0.0, -cornerL))
    // bottom-right ┘
    drawLine(frb, frb + float2(-cornerL, 0.0))
    drawLine(frb, frb + float2(0.0, -cornerL))
    // 2. rotating heading numbers every 30°
    setColor(CLR)
    setFontSize(14)
    for i in range(0, 12)
      let bearingDeg = float(i * 30)
      let screenAngle = (bearingDeg - hdgDeg) * DEG_TO_RAD - PI_2
      var sina, cosa = 0.0
      sincos(screenAngle, sina, cosa)
      let numCenter = pos + compassR * float2(cosa, sina)
      drawStrAnchored(numCenter, "{int(bearingDeg)}", AnchorHorz.Center, AnchorVert.Center)
    // white lubber line from center to top
    setColor(CLR_WHT)
    setLineWidth(2.0)
    drawLine(pos, float2(cx, cy - compassR + 0.02))
    setLineWidth(1.0)
    // text readouts
    setColor(CLR)
    setFontSize(7)
    let tx = cx - compassR * 0.65
    let ty = cy - 0.02
    setColor(CLR)
    drawStrAnchored(float2(tx, ty), "Vetar 00", AnchorHorz.Left, AnchorVert.Top)
    setColor(CLR)
    drawStrAnchored(float2(tx, ty + 0.022), "Prav.Vetar", AnchorHorz.Left, AnchorVert.Top)
    setColor(CLR_RED)
    drawStrAnchored(float2(tx + 0.08, ty + 0.022), "0", AnchorHorz.Left, AnchorVert.Top)
    setColor(CLR)
    drawStrAnchored(float2(tx, ty + 0.044), "Ug.Kursa", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx + 0.08, ty + 0.044), "{fmt(":03d", int(hdgDeg))}", AnchorHorz.Left, AnchorVert.Top)
    setFontSize(9)

  // ════════════════ 5. Compass — TCN/DTK (1,1) ════════════════

  def drawCompass()
    let cx = ccx(1)
    let midSplit = GRID_T + ROW_H * 1.5
    let gridBot = GRID_T + ROW_H * 3.0
    let cy = (midSplit + gridBot) * 0.5
    let pos = float2(cx, cy)
    let lt = float2(GRID_L + COL_W, midSplit)
    let rb = float2(GRID_L + COL_W * 2.0, gridBot)
    let cellH = gridBot - midSplit
    let cellW = COL_W
    let halfCell = min(cellH, cellW) * 0.5
    let roseR = halfCell * 0.805
    let ringR = roseR + 0.01
    let hdgRad = hdgDeg * DEG_TO_RAD
    var sina, cosa = 0.0
    // compass rose — rotating ticks (no outer ring circle)
    setColor(CLR)
    for i in range(0, 72)
      let tickDeg = float(i * 5)
      let screenAngle = (tickDeg - hdgDeg) * DEG_TO_RAD - PI_2
      sincos(screenAngle, sina, cosa)
      let isCardinal = (i % 18) == 0
      let isMajor = (i % 2) == 0
      var innerR = roseR - 0.008
      if isCardinal
        innerR = roseR - 0.025
      elif isMajor
        innerR = roseR - 0.016
      drawLine(pos + innerR * float2(cosa, sina), pos + roseR * float2(cosa, sina))
    // compass labels every 30°
    setFontSize(14)
    for i in range(0, 12)
      let tickDeg = float(i * 30)
      let screenAngle = (tickDeg - hdgDeg) * DEG_TO_RAD - PI_2
      sincos(screenAngle, sina, cosa)
      let textR = roseR - 0.035
      var lbl = ""
      if i == 0
        lbl = "N"
      elif i == 3
        lbl = "E"
      elif i == 6
        lbl = "S"
      elif i == 9
        lbl = "W"
      else
        lbl = "{i * 3}"
      drawStrAnchored(pos + textR * float2(cosa, sina), lbl, AnchorHorz.Center, AnchorVert.Center)
    // heading box at top
    setFillColor(CLR)
    setColor(CLR)
    let boxPos = float2(cx, cy - ringR - 0.015)
    let boxHW = 0.025
    let boxHH = 0.012
    drawBox(boxPos - float2(boxHW, boxHH), boxPos + float2(boxHW, boxHH))
    setColor(CLR_BG)
    setFontSize(7)
    drawStrAnchored(boxPos, fmt(":03d", int(hdgDeg)), AnchorHorz.Center, AnchorVert.Center)
    setFillColor(CLR_NONE)
    setColor(CLR)
    // aircraft symbol at center
    let symScale = 0.04
    drawLine(pos + float2(0.0, -symScale), pos + float2(0.0, symScale * 0.5))
    drawLine(pos + float2(-symScale * 0.8, 0.0), pos + float2(symScale * 0.8, 0.0))
    drawLine(pos + float2(-symScale * 0.3, symScale * 0.5), pos + float2(symScale * 0.3, symScale * 0.5))
    drawCircle(pos, symScale * 0.15)
    // heading needle through entire circle
    let northAngle = -hdgRad - PI_2
    sincos(northAngle, sina, cosa)
    let ndir = float2(cosa, sina)
    setColor(CLR)
    setLineWidth(2.0)
    drawLine(pos - roseR * 0.85 * ndir, pos + roseR * 0.85 * ndir)
    setLineWidth(1.0)
    // labels
    setFontSize(9)
    drawStrAnchored(float2(lt.x + 0.01, lt.y + 0.005), "TCN 00.0", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(rb.x - 0.01, lt.y + 0.005), "DTK {fmt(":03d", int(hdgDeg))}", AnchorHorz.Right, AnchorVert.Top)
    // bottom labels
    drawStrAnchored(float2(lt.x + 0.01, rb.y - 0.015), "TTG", AnchorHorz.Left, AnchorVert.Bottom)
    drawStrAnchored(float2(rb.x - 0.01, rb.y - 0.015), "VOR1", AnchorHorz.Right, AnchorVert.Bottom)
    setFontSize(9)

  // ════════════════ 6. Vert.Brz — vertical speed (2,1) ════════════════

  def drawVerticalSpeed()
    let pos = float2(ccx(2), ccy(1))
    let radius = GR * 0.80
    // scale -5..+5, 0 at left (270°), gap at right
    // -5 at 120°, +5 at 60° (clockwise through 270°), 300° arc
    let startA = 120.0
    let totalSpan = 300.0
    let stepA = totalSpan / 10.0
    // black fill background
    setColor(CLR_BG)
    setFillColor(CLR_BG)
    drawCircle(pos, radius)
    setFillColor(CLR_NONE)
    // white ticks pointing outward
    setColor(CLR_WHT)
    let endNudge = 22.5
    // major ticks (11 ticks: -5..+5, with ±5 and ±4 nudged)
    let midNudge = 11.25
    for i in range(0, 11)
      var angle = startA + float(i) * stepA
      if i == 0
        angle -= endNudge
      elif i == 1
        angle -= midNudge
      elif i == 9
        angle += midNudge
      elif i == 10
        angle += endNudge
      drawTick(pos, radius + 0.014, angle, 0.014)
    // minor ticks: 4 per interval, only between -2 and +2
    for majorIdx in range(3, 7)
      let baseA = startA + float(majorIdx) * stepA
      for j in range(1, 5)
        let angle = baseA + float(j) * stepA / 5.0
        drawTick(pos, radius + 0.008, angle, 0.008)
    // numbers white, outside ticks
    setColor(CLR_WHT)
    setFontSize(14)
    for i in range(0, 11)
      let val = i - 5
      var angle = startA + float(i) * stepA
      if i == 0
        angle -= endNudge
      elif i == 1
        angle -= midNudge
      elif i == 9
        angle += midNudge
      elif i == 10
        angle += endNudge
      var sina, cosa = 0.0
      sincos(angle * DEG_TO_RAD, sina, cosa)
      drawStrAnchored(pos + (radius + 0.027) * float2(sina, -cosa), "{val}", AnchorHorz.Center, AnchorVert.Center)
    // needle (vs in m/sina, scale in units of 10 m/sina)
    let reading = clamp(vs / 10.0, -5.0, 5.0)
    let needleA = startA + (reading + 5.0) * stepA
    drawNeedle(pos, radius * 0.80, needleA)
    // center dot
    setFillColor(CLR)
    drawCircle(pos, 0.005)
    setFillColor(CLR_NONE)
    // title
    setFontSize(9)
    drawStrAnchored(pos + float2(0.01, 0.025), "Vert.Brz", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.01, 0.04), "[m/sec]x10", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(9)

  // ════════════════ 7. ADI Calibration (0,2) ════════════════

  def drawAdiCalibration()
    let cx = ccx(0)
    let cy = ccy(2)
    let lt = clt(0, 2)
    let rb = crb(0, 2)
    setColor(CLR)
    // title
    setFontSize(9)
    drawStrAnchored(float2(cx, lt.y + 0.01), "ADI Calibration", AnchorHorz.Center, AnchorVert.Top)
    // buttons
    let btnY = rb.y - 0.015
    setFillColor(CLR_GREY)
    setColor(CLR)
    drawBox(float2(cx - 0.10, btnY - 0.010), float2(cx - 0.04, btnY + 0.010))
    drawBox(float2(cx - 0.03, btnY - 0.010), float2(cx + 0.04, btnY + 0.010))
    drawBox(float2(cx + 0.05, btnY - 0.010), float2(cx + 0.11, btnY + 0.010))
    setFillColor(CLR_NONE)
    setFontSize(8)
    drawStrAnchored(float2(cx - 0.07, btnY), "Test", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(cx + 0.005, btnY), "Set=0", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(cx + 0.08, btnY), "Save", AnchorHorz.Center, AnchorVert.Center)
    // wind info
    setFontSize(8)
    let wY = lt.y + 0.035
    drawStrAnchored(float2(lt.x + 0.01, wY), "Wind Dir: 0", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(lt.x + 0.01, wY + 0.018), "Wind Val: 0", AnchorHorz.Left, AnchorVert.Top)
    // deviation bars
    let barX = lt.x + 0.06
    let barW = 0.16
    let barH = 0.014
    let barStartY = wY + 0.045
    let barStep = 0.022
    let barLabels = to_array_move(fixed_array<string>("Roll:", "Pitch:", "Yaw:"))
    let barValues = to_array_move(fixed_array(rollDeg, pitchDeg, 0.0))
    for i in range(0, 3)
      let by = barStartY + float(i) * barStep
      // label
      drawStrAnchored(float2(lt.x + 0.01, by + barH * 0.5), barLabels[i], AnchorHorz.Left, AnchorVert.Center)
      // background bar
      setColor(CLR_GREY)
      setFillColor(CLR_GREY)
      drawBox(float2(barX, by), float2(barX + barW, by + barH))
      // center line
      setColor(CLR)
      drawLine(float2(barX + barW * 0.5, by), float2(barX + barW * 0.5, by + barH))
      // green fill
      let maxVal = i == 0 ? 45.0 : 30.0
      let norm = clamp(barValues[i] / maxVal, -1.0, 1.0)
      let fillW = norm * barW * 0.5
      setColor(CLR_GRN)
      setFillColor(CLR_GRN)
      let center = barX + barW * 0.5
      if fillW > 0.0
        drawBox(float2(center, by + 0.001), float2(center + fillW, by + barH - 0.001))
      elif fillW < 0.0
        drawBox(float2(center + fillW, by + 0.001), float2(center, by + barH - 0.001))
      setFillColor(CLR_NONE)
      // value text
      setColor(CLR)
      drawStrAnchored(float2(barX + barW + 0.005, by + barH * 0.5), fmt(":.1f", barValues[i]), AnchorHorz.Left, AnchorVert.Center)
    setColor(CLR)
    setFontSize(9)

  // ════════════════ 8. Nav info — bottom center compass (1,2) ════════════════

  def drawNavInfo()
    let cx = ccx(1)
    let cy = ccy(2)
    let lt = clt(1, 2)
    let rb = crb(1, 2)
    let pos = float2(cx, cy)
    let radius = 0.08
    // small compass
    setColor(CLR)
    setFillColor(CLR_BG)
    drawCircle(pos, radius)
    setFillColor(CLR_NONE)
    let hdgRad = hdgDeg * DEG_TO_RAD
    // ticks
    for i in range(0, 36)
      let screenAngle = (float(i * 10) - hdgDeg) * DEG_TO_RAD - PI_2
      var sina, cosa = 0.0
      sincos(screenAngle, sina, cosa)
      let tickLen = (i % 9) == 0 ? 0.012 : 0.005
      drawLine(pos + (radius - tickLen) * float2(cosa, sina), pos + radius * float2(cosa, sina))
    // north needle
    let northAngle = -hdgRad - PI_2
    var sina, cosa = 0.0
    sincos(northAngle, sina, cosa)
    setFillColor(CLR)
    let tip = pos + radius * 0.7 * float2(cosa, sina)
    let base1 = pos + float2(-sina * 0.008, cosa * 0.008)
    let base2 = pos + float2(sina * 0.008, -cosa * 0.008)
    drawFilledPolyOutlined([tip, base1, base2])
    setFillColor(CLR_NONE)
    // labels
    setFontSize(9)
    drawStrAnchored(float2(lt.x + 0.01, rb.y - 0.015), "TTG", AnchorHorz.Left, AnchorVert.Bottom)
    drawStrAnchored(float2(rb.x - 0.01, rb.y - 0.015), "VOR1", AnchorHorz.Right, AnchorVert.Bottom)
    setFontSize(9)

  // ════════════════ 9. GPS display (2,2) ════════════════

  def drawGpsDisplay()
    let lt = clt(2, 2)
    let rb = crb(2, 2)
    let tx = lt.x + 0.008
    let ty = lt.y + 0.005
    let lh = 0.017
    setColor(CLR)
    setFontSize(7)
    // title
    drawStrAnchored(float2(tx, ty), "GPS [Gauss-Kruger projekcija]", AnchorHorz.Left, AnchorVert.Top)
    setColor(CLR)
    let posX = hero.unitTm[3].x
    let posZ = hero.unitTm[3].z
    let groundSpd = length(float2(hero.vel.x, hero.vel.z)) * MPS_TO_KPH
    let y0 = ty + lh * 1.2
    drawStrAnchored(float2(tx, y0),              "Longitude [GK]:", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx, y0 + lh),         "Latitude [GK]:", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx, y0 + lh * 2.0),   "Altitude [GK]:", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx, y0 + lh * 3.0),   "D: R.527 oSat:", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx, y0 + lh * 4.0),   "UTM Zone:", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx, y0 + lh * 5.0),   "UTM N:", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx, y0 + lh * 6.0),   "Ground velocity:", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx, y0 + lh * 7.0),   "Ground heading:", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx, y0 + lh * 8.0),   "PDOP:", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(tx, y0 + lh * 9.0),   "P.Star: H = 0 m", AnchorHorz.Left, AnchorVert.Top)
    // values
    let vx = rb.x - 0.008
    drawStrAnchored(float2(vx, y0),              fmt(":.1f", posX), AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(vx, y0 + lh),         fmt(":.1f", posZ), AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(vx, y0 + lh * 2.0),   fmt(":.1f", altM), AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(vx, y0 + lh * 3.0),   "8", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(vx, y0 + lh * 4.0),   "34T", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(vx, y0 + lh * 5.0),   fmt(":.0f", posZ), AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(vx, y0 + lh * 6.0),   fmt(":.1f", groundSpd), AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(vx, y0 + lh * 7.0),   fmt(":03d", int(hdgDeg)), AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(vx, y0 + lh * 8.0),   "1.2", AnchorHorz.Right, AnchorVert.Top)
    setFontSize(12)

  // ════════════════ main draw ════════════════

  def draw()
    return if !isValid
    setFullCanvasViewport()
    drawBackground()
    drawGrid()
    drawSideLabels()
    drawSpeedometer()
    drawAttitudeIndicator()
    drawAltimeter()
    drawCourseDisplay()
    drawCompass()
    drawVerticalSpeed()
    drawAdiCalibration()
    drawGpsDisplay()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
