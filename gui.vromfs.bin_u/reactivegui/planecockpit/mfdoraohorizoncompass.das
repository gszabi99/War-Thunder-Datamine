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


let
  CLR      = E3DCOLOR(0xFF_00CC00)
  CLR_LIME = E3DCOLOR(0xFF_80FF00)
  CLR_BG   = E3DCOLOR(0xFF_000000)
  CLR_NONE = E3DCOLOR(0x00_000000)
  CLR_SKY  = E3DCOLOR(uint4(0, 50, 200, 255))
  CLR_GND  = E3DCOLOR(uint4(60, 2, 0, 255))
  CLR_WHT  = E3DCOLOR(0xFF_FFFFFF)


struct PropStorage
  fontId : int
  horMask : Picture const? = null


class Component : Canvas
  isValid   : bool = false
  hero      : Unit? = null
  fmw       : FlightModelWrap? = null
  pitchDeg  : float = 0.0
  rollDeg   : float = 0.0
  hdgDeg    : float = 0.0
  horMask   : Picture const? = null

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
    isValid  = true
    horMask  = props.horMask
    pitchDeg = fmw.tangage
    rollDeg  = fmw.roll
    hdgDeg   = (atan2(hero.unitTm[0].x, hero.unitTm[0].z) * radToDeg + 360.0) % 360.0
    setLineWidth(1.5)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFont(props.fontId)
    setFontSize(9)
    setColor(CLR)

  def drawRoundCircle(pos : float2; radius : float)
    drawEllipse(pos, float2(radius, radius))

  def drawAttitudeIndicator()
    let cx = 0.0
    let cy = -0.20
    let radius = 0.226
    let pitchScale = radius / 50.0
    let lt = float2(-0.5, -0.5)
    let rb = float2(0.5, 0.12)

    setViewport(lt, rb)
    setRotation(float2(cx, cy), -rollDeg * degToRad)

    let horY = cy + pitchDeg * pitchScale

    setColor(CLR_SKY)
    setFillColor(CLR_SKY)
    drawBox(float2(cx - 0.6, cy - 0.6), float2(cx + 0.6, horY))
    setColor(CLR_GND)
    setFillColor(CLR_GND)
    drawBox(float2(cx - 0.6, horY), float2(cx + 0.6, cy + 0.6))

    setColor(CLR_WHT)
    setFillColor(CLR_NONE)
    drawLine(float2(cx - 0.35, horY), float2(cx + 0.35, horY))

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

    setFontSize(14)
    for i in range(0, 61)
      let markVal = floori(pitchDeg) + (i - 30)
      if markVal == 0
        continue
      let markY = cy + (pitchDeg - float(markVal)) * pitchScale
      if abs(markVal) % 10 == 0
        drawLine(float2(cx - radius * 0.40, markY), float2(cx + radius * 0.40, markY))
        drawStrAnchored(float2(cx - radius * 0.45, markY), "{abs(markVal)}", AnchorHorz.Right, AnchorVert.Center)
        drawStrAnchored(float2(cx + radius * 0.45, markY), "{abs(markVal)}", AnchorHorz.Left, AnchorVert.Center)
      elif abs(markVal) % 5 == 0
        drawLine(float2(cx - radius * 0.20, markY), float2(cx + radius * 0.20, markY))
      else
        drawLine(float2(cx - radius * 0.05, markY), float2(cx + radius * 0.05, markY))

    setColor(CLR_WHT)
    let arcR = radius * 0.85
    for tick in range(0, 7)
      let deg = -30.0 + float(tick) * 10.0
      let aRad = (deg - 90.0) * degToRad
      var sina, cosa = 0.0
      sincos(aRad, sina, cosa)
      let tickLen = abs(deg) < 25.0 ? 0.012 : 0.018
      drawLine(float2(cx + (arcR - tickLen) * cosa, cy + (arcR - tickLen) * sina), float2(cx + arcR * cosa, cy + arcR * sina))

    setFillColor(CLR_WHT)
    let triTop <- to_array_move(fixed_array(
      float2(cx, cy - arcR + 0.002),
      float2(cx - radius * 0.04, cy - arcR + 0.018),
      float2(cx + radius * 0.04, cy - arcR + 0.018)))
    drawFilledPolyOutlined(triTop)
    setFillColor(CLR_NONE)

    resetViewTm()

    setColor(CLR_LIME)
    setFillColor(CLR_LIME)
    drawFilledPolyOutlined([
      float2(cx,                cy - 0.010),
      float2(cx - 0.04, cy - 0.002),
      float2(cx - 0.11, cy + 0.005),
      float2(cx - 0.10, cy + 0.012),
      float2(cx - 0.05, cy + 0.007),
      float2(cx,                cy + 0.012)])
    drawFilledPolyOutlined([
      float2(cx,                cy - 0.010),
      float2(cx + 0.04, cy - 0.002),
      float2(cx + 0.11, cy + 0.005),
      float2(cx + 0.10, cy + 0.012),
      float2(cx + 0.05, cy + 0.007),
      float2(cx,        cy + 0.012)])
    setFillColor(CLR_NONE)

    setColor(CLR_WHT)
    setFontSize(8)
    drawStrAnchored(float2(cx - 0.12, lt.y + 0.015), "Prop. {fmt(":03d", int(pitchDeg))}", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(cx + 0.12, lt.y + 0.015), "Valjanji {fmt(":03d", int(rollDeg))}", AnchorHorz.Right, AnchorVert.Top)
    setFontSize(9)
    restoreViewport()

  def drawMask()
    let cy = -0.20
    let maskR = 0.30
    setColor(CLR_BG)
    setFillColor(CLR_BG)
    let pad = 0.006
    let edge = 0.7
    drawBox(float2(-edge, -edge), float2(-maskR + pad, cy + maskR))
    drawBox(float2(maskR - pad, -edge), float2(edge, cy + maskR))
    drawBox(float2(-edge, -edge), float2(edge, cy - maskR + pad))
    drawBox(float2(-edge, cy + maskR - pad), float2(edge, cy + maskR + 0.1))
    setFillColor(CLR_NONE)
    unsafe
      let m = reinterpret<Picture?>(horMask)
      if m == null
        return
      setColor(CLR_BG)
      drawPicture(float2(-maskR, cy - maskR), float2(maskR * 2.0, maskR * 2.0), m)

  def drawCompass()
    let cx = 0.0
    let cy = 0.30
    let pos = float2(cx, cy)
    let roseR = 0.1373
    let hdgRad = hdgDeg * degToRad
    var sina, cosa = 0.0

    setColor(CLR_BG)
    setFillColor(CLR_BG)
    drawRoundCircle(pos, roseR + 0.005)
    setFillColor(CLR_NONE)

    setColor(CLR)
    for i in range(0, 72)
      let tickDeg = float(i * 5)
      let screenAngle = (tickDeg - hdgDeg) * degToRad - PI_2
      sincos(screenAngle, sina, cosa)
      let isCardinal = (i % 18) == 0
      let isMajor = (i % 2) == 0
      var innerR = roseR - 0.008
      if isCardinal
        innerR = roseR - 0.025
      elif isMajor
        innerR = roseR - 0.016
      let dir = float2(cosa, sina)
      drawLine(pos + innerR * dir, pos + roseR * dir)

    setFontSize(14)
    for i in range(0, 12)
      let tickDeg = float(i * 30)
      let screenAngle = (tickDeg - hdgDeg) * degToRad - PI_2
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

    setFillColor(CLR)
    setColor(CLR)
    let boxPos = float2(cx, cy - roseR - 0.015)
    let boxHW = 0.025
    let boxHH = 0.012
    drawBox(boxPos - float2(boxHW, boxHH), boxPos + float2(boxHW, boxHH))
    setColor(CLR_BG)
    setFontSize(7)
    drawStrAnchored(boxPos, fmt(":03d", int(hdgDeg)), AnchorHorz.Center, AnchorVert.Center)
    setFillColor(CLR_NONE)
    setColor(CLR)

    let symScale = 0.04
    drawLine(pos + float2(0.0, -symScale), pos + float2(0.0, symScale * 0.5))
    drawLine(pos + float2(-symScale * 0.8, 0.0), pos + float2(symScale * 0.8, 0.0))
    drawLine(pos + float2(-symScale * 0.3, symScale * 0.5), pos + float2(symScale * 0.3, symScale * 0.5))
    drawRoundCircle(pos, symScale * 0.15)

    let northAngle = -hdgRad - PI_2
    sincos(northAngle, sina, cosa)
    let ndir = float2(cosa, sina)
    setColor(CLR)
    setLineWidth(2.0)
    drawLine(pos - roseR * 0.85 * ndir, pos + roseR * 0.85 * ndir)
    setLineWidth(1.5)

    setFontSize(9)
    drawStrAnchored(float2(-0.35, cy - roseR - 0.01), "TCN 00.0", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(0.35, cy - roseR - 0.01), "DTK {fmt(":03d", int(hdgDeg))}", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(-0.35, cy + roseR + 0.005), "TTG", AnchorHorz.Left, AnchorVert.Bottom)
    drawStrAnchored(float2(0.35, cy + roseR + 0.005), "VOR1", AnchorHorz.Right, AnchorVert.Bottom)

  def draw()
    return if !isValid
    setFullCanvasViewport()
    setColor(CLR_BG)
    setFillColor(CLR_BG)
    drawBox(float2(-0.5, -0.5), float2(0.5, 0.5))
    setFillColor(CLR_NONE)
    drawAttitudeIndicator()
    drawMask()
    drawCompass()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
  propStorage.horMask = props |> getPicture("horMask")
