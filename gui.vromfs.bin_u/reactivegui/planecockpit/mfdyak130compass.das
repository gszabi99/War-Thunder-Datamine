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
require strings
require Unit


struct PropStorage
  fontId : int = 0
  fontSize : int = 16


let
  COLOR_BLACK      = E3DCOLOR(uint4(0, 0, 0, 255))
  COLOR_WHITE      = E3DCOLOR(uint4(255, 255, 255, 255))
  COLOR_GREEN      = E3DCOLOR(uint4(0, 200, 0, 255))
  COLOR_GREEN_DIM  = E3DCOLOR(uint4(0, 120, 0, 255))
  COLOR_ORANGE     = E3DCOLOR(uint4(255, 160, 0, 255))
  COLOR_SKY        = E3DCOLOR(uint4(0, 50, 200, 255))
  COLOR_GROUND     = E3DCOLOR(uint4(255, 60, 0, 255))
  COLOR_NULL       = E3DCOLOR(0x0)

  COMPASS_R        = 0.28
  COMPASS_CTR      = float2(0.0, 0.05)
  RING_COUNT       = 5


class Component : Canvas
  isValid      : bool             = false
  hero         : Unit?            = null
  fmw          : FlightModelWrap? = null
  app          : AcesApp?         = null
  headingRad   : float            = 0.0
  pitchDeg     : float            = 0.0
  rollDeg      : float            = 0.0
  iasMps       : float            = 0.0
  tasKph       : float            = 0.0
  altM         : float            = 0.0
  altGeomM     : float            = 0.0
  fontSize     : int              = 16


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
                rstate : RenderState& const; var props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    if hero == null
      return
    fmw = hero.as_fmw()
    if fmw == null
      return
    app = get_app()
    if app == null
      return
    isValid = true
    fontSize = props.fontSize

    let fwd = hero.unitTm[0]
    headingRad = atan2(fwd.x, fwd.z)
    pitchDeg   = fmw.tangage
    rollDeg    = fmw.roll
    iasMps     = fmw.ias
    assume fm = *fmw.fm
    tasKph     = fm.speed * MPS_TO_KPH
    altM       = hero.unitTm[3].y - app.currentScene.waterLevel
    altGeomM   = fm.input.currentAlt

    setColor(COLOR_GREEN)
    setLineWidth(1.5)
    setFont(props.fontId)
    setFontSize(fontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.x * 1.25, canvasSize.y))


  def drawBackground()
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(float2(-0.5, -0.5), float2(0.5, 0.5))


  def drawRangeRings()
    setFillColor(COLOR_NULL)
    setLineWidth(1.0)
    for i in range(1, RING_COUNT + 1)
      let r = COMPASS_R * float(i) / float(RING_COUNT)
      if i == RING_COUNT
        setColor(COLOR_GREEN)
      else
        setColor(COLOR_WHITE)
      drawCircle(COMPASS_CTR, r)
    setLineWidth(1.5)
    setColor(COLOR_GREEN)


  def drawCrosshair()
    setColor(COLOR_WHITE)
    setLineWidth(1.0)
    let c = COMPASS_CTR
    let r = COMPASS_R
    drawLine(c - float2(0.0, r), c + float2(0.0, r))
    drawLine(c - float2(r, 0.0), c + float2(r, 0.0))
    setLineWidth(1.5)
    setColor(COLOR_GREEN)


  def drawAircraftSymbol()
    let c = COMPASS_CTR
    let innerR = COMPASS_R / float(RING_COUNT)
    let wingW = innerR * 0.9
    let noseLen = 0.03

    setRotation(c, rollDeg * degToRad)

    setColor(COLOR_WHITE)
    setLineWidth(4.0)
    drawLine(c - float2(0.0, noseLen), c)
    drawLine(c - float2(wingW, 0.0), c + float2(wingW, 0.0))

    resetViewTm()

    setColor(COLOR_WHITE)
    setLineWidth(4.0)
    let halfGap = innerR * 0.5
    drawLine(c - float2(innerR + halfGap, 0.0), c - float2(innerR, 0.0))
    drawLine(c + float2(innerR, 0.0), c + float2(innerR + halfGap, 0.0))

    setLineWidth(1.5)
    setColor(COLOR_GREEN)


  def drawHeadingScale()
    setColor(COLOR_GREEN)
    let smallFont = int(float(fontSize) * 0.75)
    setFontSize(smallFont)
    let ctr = COMPASS_CTR
    let r = COMPASS_R
    let minorTick = 0.014
    let hdgDeg = norm_ang(headingRad) * radToDeg
    var sinH, cosH : float
    sincos(-headingRad, sinH, cosH)

    for i in range(36)
      let angleDeg = float(i) * 10.0
      var s, c : float
      sincos(angleDeg * degToRad, s, c)
      let isMajor = (i % 3) == 0
      let tl = minorTick
      let oxOut = s * r
      let oyOut = -c * r
      let rxOut = oxOut * cosH - oyOut * sinH
      let ryOut = oxOut * sinH + oyOut * cosH
      let oxIn = s * (r + tl)
      let oyIn = -c * (r + tl)
      let rxIn = oxIn * cosH - oyIn * sinH
      let ryIn = oxIn * sinH + oyIn * cosH
      drawLine(ctr + float2(rxOut, ryOut), ctr + float2(rxIn, ryIn))
      if isMajor
        let markDeg = (int(angleDeg) + 360) % 360
        let lbl = markDeg == 0 ? "С" : (markDeg == 90 ? "В" : (markDeg == 180 ? "Ю" : (markDeg == 270 ? "З" : fmt(":d", markDeg / 10))))
        let labelR = r + tl + 0.015
        let lxL = s * labelR
        let lyL = -c * labelR
        let rlx = lxL * cosH - lyL * sinH
        let rly = lxL * sinH + lyL * cosH
        drawStrAnchored(ctr + float2(rlx, rly), lbl, AnchorHorz.Center, AnchorVert.Center)

    setFillColor(COLOR_GREEN)
    let triY = ctr.y - r - 0.005
    let triW = 0.008
    let triH = 0.012
    drawFilledPoly(to_array_move(fixed_array(
      float2(ctr.x, triY),
      float2(ctr.x - triW, triY - triH),
      float2(ctr.x + triW, triY - triH))))
    setFillColor(COLOR_NULL)

    let hdg = roundi(hdgDeg) % 360
    let boxY = triY - triH - 0.015
    setFillColor(COLOR_BLACK)
    let boxHW = 0.025
    let boxHH = 0.012
    drawBox(float2(ctr.x - boxHW, boxY - boxHH), float2(ctr.x + boxHW, boxY + boxHH))
    setColor(COLOR_GREEN)
    setFillColor(COLOR_NULL)
    drawBox(float2(ctr.x - boxHW, boxY - boxHH), float2(ctr.x + boxHW, boxY + boxHH))
    drawStrAnchored(float2(ctr.x, boxY), fmt(":03d", hdg), AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  def drawSpeeds()
    setColor(COLOR_GREEN)
    let smallFont = int(float(fontSize) * 0.8)
    setFontSize(smallFont)
    let lx = -0.25
    let ly = COMPASS_CTR.y - COMPASS_R - 0.15
    let iasKph = iasMps * MPS_TO_KPH
    drawStrAnchored(float2(lx, ly), fmt(":d", floori(iasKph)), AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(lx, ly + 0.025), fmt(":d", floori(tasKph)), AnchorHorz.Right, AnchorVert.Top)
    setFontSize(fontSize)


  def drawAltitudes()
    setColor(COLOR_GREEN)
    let smallFont = int(float(fontSize) * 0.8)
    setFontSize(smallFont)
    let rx = 0.25
    let ry = COMPASS_CTR.y - COMPASS_R - 0.15
    drawStrAnchored(float2(rx, ry), fmt(":d", floori(altM)), AnchorHorz.Left, AnchorVert.Top)
    setColor(COLOR_ORANGE)
    drawStrAnchored(float2(rx, ry + 0.025), fmt(":d", floori(altGeomM)), AnchorHorz.Left, AnchorVert.Top)
    setColor(COLOR_GREEN)
    setFontSize(fontSize)


  def drawPitchScale()
    let scaleX = 0.30
    let scaleW = 0.04
    let scaleHalfH = 0.08
    let tickW = 0.008
    let smallFont = int(float(fontSize) * 0.6)
    let pitchRange = 30.0
    let ctrY = COMPASS_CTR.y

    let lt = float2(scaleX, ctrY - scaleHalfH)
    let rb = float2(scaleX + scaleW, ctrY + scaleHalfH)

    let horY = ctrY + pitchDeg * scaleHalfH / pitchRange

    setColor(COLOR_SKY)
    setFillColor(COLOR_SKY)
    let skyBot = clamp(horY, lt.y, rb.y)
    if skyBot > lt.y
      drawBox(lt, float2(rb.x, skyBot))

    setColor(COLOR_GROUND)
    setFillColor(COLOR_GROUND)
    let gndTop = clamp(horY, lt.y, rb.y)
    if gndTop < rb.y
      drawBox(float2(lt.x, gndTop), rb)

    if horY > lt.y && horY < rb.y
      setColor(COLOR_WHITE)
      drawLine(float2(lt.x, horY), float2(rb.x, horY))

    setFillColor(COLOR_NULL)

    setColor(COLOR_WHITE)
    setFontSize(smallFont)
    for i in range(-2, 3)
      let markVal = (floori(pitchDeg / 10.0)) * 10 + i * 10
      let markY = ctrY + (pitchDeg - float(markVal)) * scaleHalfH / pitchRange
      if markY < lt.y || markY > rb.y
        continue
      drawLine(float2(lt.x, markY), float2(lt.x + tickW, markY))
      drawStrAnchored(float2(lt.x + tickW + 0.003, markY), fmt(":d", abs(markVal)), AnchorHorz.Left, AnchorVert.Center)

    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    drawBox(lt, rb)

    setFillColor(COLOR_WHITE)
    drawFilledPoly(to_array_move(fixed_array(
      float2(lt.x, ctrY),
      float2(lt.x - 0.01, ctrY - 0.006),
      float2(lt.x - 0.01, ctrY + 0.006))))
    setFillColor(COLOR_NULL)
    setColor(COLOR_GREEN)
    setFontSize(fontSize)


  def drawOsbLabels()
    let smallFont = int(float(fontSize) * 0.85)
    setFontSize(smallFont)
    setColor(COLOR_GREEN)
    let off = 0.04
    drawStrAnchored(float2(-0.24, -0.5 + off), "ПИЛ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.12, -0.5 + off), "НВГ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0, -0.5 + off), "ИТО", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.12, -0.5 + off), "КИСС", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.24, -0.5 + off), "ТВ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.12, 0.475), "ПНО", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.12, 0.475), "ФИЛ-О", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  def drawBorder()
    let rx = 0.35
    let ry = 0.44
    setColor(COLOR_GREEN)
    setLineWidth(2.0)
    drawLine(float2(-rx, -ry), float2(rx, -ry))
    drawLine(float2(rx, -ry), float2(rx, ry))
    drawLine(float2(rx, ry), float2(-rx, ry))
    drawLine(float2(-rx, ry), float2(-rx, -ry))
    setLineWidth(1.5)


  def draw()
    return if !isValid
    setFullCanvasViewport()

    drawBackground()
    drawRangeRings()
    drawCrosshair()
    drawAircraftSymbol()
    drawHeadingScale()
    drawSpeeds()
    drawAltitudes()
    drawPitchScale()
    drawOsbLabels()
    drawBorder()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; var props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId   = getInt(props, "fontId", 0)
  propStorage.fontSize = getInt(props, "fontSize", 16)
