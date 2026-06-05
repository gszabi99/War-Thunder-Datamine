require %gameLibs.das.math
require %gameLibs.das.math.base
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require app
require DagorMath
require DagorStdGuiRender
require darg
require DagorDataBlock
require FlightModelWrap
require GamePhys
require HeroManager
require math
require Plane
require strings
require Unit

struct PropStorage
  fontId : int
  fontSize : int = 20
  labelFontSize : int = 20
  horMask : Picture const? = null

let
  COLOR_BLACK  = E3DCOLOR(uint4(0, 0, 0, 255))
  COLOR_WHITE  = E3DCOLOR(uint4(255, 255, 255, 255))
  COLOR_SKY    = E3DCOLOR(uint4(0, 50, 200, 255))
  COLOR_GROUND = E3DCOLOR(uint4(255, 60, 0, 255))
  COLOR_YELLOW = E3DCOLOR(uint4(255, 200, 0, 255))
  BALL_R       = 0.2758
  RING_R_IN    = 0.3267
  RING_R_OUT   = 0.3734
  DEG_PER_UNIT = 0.0056
  VS_RANGE     = 20.0

class Component : Canvas
  isValid : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  app : AcesApp? = null
  pitchDeg  : float = 0.0
  rollDeg   : float = 0.0
  headingRad : float = 0.0
  iasMps    : float = 0.0
  altM      : float = 0.0
  machNum   : float = 0.0
  vertSpeed : float = 0.0
  pressurePa : float = 101325.0
  slipAngleDeg : float = 0.0
  fontSize       : int = 30
  labelFontSize  : int = 30
  horMask : Picture const? = null

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
                rstate : RenderState& const; props : PropStorage&)
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
    fontSize      = props.fontSize
    labelFontSize = props.labelFontSize
    horMask       = props.horMask
    pitchDeg  = fmw.tangage
    rollDeg   = fmw.roll
    let fwd = hero.unitTm[0]
    headingRad = atan2(fwd.x, fwd.z)
    iasMps    = fmw.ias
    altM      = hero.unitTm[3].y - app.currentScene.waterLevel
    machNum   = fmw.fm.cache.Mach
    vertSpeed = fmw.fm.vertSpeed
    pressurePa = GamePhys::pressure(altM)
    let zVel = dot(hero.vel, hero.unitTm[1])
    let projVel = hero.vel - hero.unitTm[1] * zVel
    if length(projVel) > 0.1
      let cr = cross(normalize(projVel), normalize(hero.unitTm[0]))
      slipAngleDeg = asin(clamp(length(cr), -1.0, 1.0)) * radToDeg * -sign(dot(cr, hero.unitTm[1]))
    setColor(COLOR_WHITE)
    setLineWidth(2.0)
    setFont(props.fontId)
    setFontSize(fontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)

  def drawBackground()
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(float2(-0.5, -0.5), float2(0.5, 0.5))

  def drawAviaHorizont()
    let horY = BALL_R * cvt(pitchDeg, -30.0, 30.0, -1.0, 1.0)
    setViewport(float2(-BALL_R, -BALL_R), float2(BALL_R, BALL_R))
    setColor(COLOR_SKY)
    setFillColor(COLOR_SKY)
    drawBox(float2(-0.5, -0.5), float2(0.5, horY))
    setColor(COLOR_GROUND)
    setFillColor(COLOR_GROUND)
    drawBox(float2(-0.5, horY), float2(0.5, 0.5))
    setColor(COLOR_WHITE)
    setFillColor(E3DCOLOR(0x0))
    drawLine(float2(-BALL_R, horY), float2(BALL_R, horY))
    let triRatio = 0.3 / 2.1
    let upW = (horY + BALL_R) * triRatio
    let dnW = (BALL_R - horY) * triRatio
    let COLOR_TRI = E3DCOLOR(uint4(0, 10, 200, 255))
    let COLOR_TRI_GND = E3DCOLOR(uint4(255, 20, 0, 255))
    setColor(COLOR_TRI)
    setFillColor(COLOR_TRI)
    var triUp = array<float2>()
    triUp |> push(float2(0.0, horY))
    triUp |> push(float2(-upW, -BALL_R))
    triUp |> push(float2(upW, -BALL_R))
    drawFilledPolyOutlined(triUp)
    setColor(COLOR_TRI_GND)
    setFillColor(COLOR_TRI_GND)
    var triDn = array<float2>()
    triDn |> push(float2(0.0, horY))
    triDn |> push(float2(-dnW, BALL_R))
    triDn |> push(float2(dnW, BALL_R))
    drawFilledPolyOutlined(triDn)
    setColor(COLOR_WHITE)
    setFillColor(E3DCOLOR(0x0))
    let aviaFontSize = int(float(fontSize) * 0.8)
    setFontSize(aviaFontSize)
    for i in range(-5, 7)
      let markVal = (int(pitchDeg) / 5) * 5 + i * 5
      let markY = (pitchDeg - float(markVal)) * BALL_R / 30.0
      setColor(COLOR_WHITE)
      if markVal != 0
        if abs(markVal % 10) > 0
          drawLine(float2(-BALL_R * 0.12, markY), float2(BALL_R * 0.12, markY))
        else
          drawLine(float2(-BALL_R * 0.30, markY), float2(-BALL_R * 0.12, markY))
          drawLine(float2(BALL_R * 0.12, markY), float2(BALL_R * 0.30, markY))
        if abs(markVal % 10) == 0
          drawStrAnchored(float2(0.0, markY), "{abs(markVal)}", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    resetViewTm()
    setRotation(float2(0.0, 0.0), rollDeg * degToRad)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_WHITE)
    drawCircle(float2(0.0, 0.0), 0.004)
    setFillColor(E3DCOLOR(0x0))
    let gap = 0.044
    let wing = fixed_array(
      float2(-gap, 0.0),
      float2(-0.076, 0.0),
      float2(-0.090, 0.033),
      float2(-0.102, 0.0),
      float2(-0.219, 0.0))
    let stab = fixed_array(
      float2(0.0, -gap),
      float2(0.0, -0.11))
    setLineWidth(2.0)
    drawPolyLine(wing.to_array())
    drawPolyLine(wing.to_array().inv_x())
    drawPolyLine(stab.to_array())
    resetViewTm()
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    for i in range(-9, 10)
      var angle = float(i) * 5.0
      let angleM = abs(angle)
      if angleM > 45.0 || (angleM != 45.0 && angleM % 10.0 > 0.0) || angleM == 40.0
        continue
      if angle == 0.0
        let tp <- to_array_move(fixed_array(
          float2(0.0, -BALL_R * 0.92),
          float2(-BALL_R * 0.04, -BALL_R),
          float2(BALL_R * 0.04, -BALL_R)))
        drawFilledPolyOutlined(tp)
      else
        angle += 90.0
        var sinA, cosA : float
        sincos(angle * degToRad, sinA, cosA)
        setLineWidth(3.0)
        drawLine(float2(-cosA * BALL_R, -sinA * BALL_R), float2(-cosA * BALL_R * 0.9, -sinA * BALL_R * 0.9))
        setLineWidth(2.0)
    unsafe
      let m = reinterpret<Picture?>(horMask)
      setColor(COLOR_BLACK)
      let maskScale = 1.08
      drawPicture(float2(-BALL_R * maskScale, -BALL_R * maskScale), float2(BALL_R * 2.0 * maskScale, BALL_R * 2.0 * maskScale), m)
    restoreViewport()

  def drawCircleFrame()
    let n = 32
    let outerHw = 0.5
    var topHalf = array<float2>()
    var botHalf = array<float2>()
    topHalf |> push(float2(-outerHw, 0.0))
    topHalf |> push(float2(-outerHw, -outerHw))
    topHalf |> push(float2(outerHw, -outerHw))
    topHalf |> push(float2(outerHw, 0.0))
    botHalf |> push(float2(-outerHw, 0.0))
    botHalf |> push(float2(-outerHw, outerHw))
    botHalf |> push(float2(outerHw, outerHw))
    botHalf |> push(float2(outerHw, 0.0))
    for i in range(n + 1)
      let angle = PI * float(i) / float(n)
      var s, c : float
      sincos(angle, s, c)
      topHalf |> push(float2(RING_R_OUT * c, -RING_R_OUT * s))
      botHalf |> push(float2(RING_R_OUT * c, RING_R_OUT * s))
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawFilledPoly(topHalf)
    drawFilledPoly(botHalf)
    setColor(COLOR_WHITE)
    setFillColor(E3DCOLOR(0x0))
    drawCircle(float2(0.0, 0.0), RING_R_OUT)

  def drawCompassRing()
    setFontSize(int(float(fontSize) * 0.96))
    var hrSin, hrCos : float
    sincos(-headingRad, hrSin, hrCos)
    let totalSteps = 36
    let tickLen3 = RING_R_IN + (RING_R_OUT - RING_R_IN) * 2.0 / 3.0
    for i in range(totalSteps)
      let angleDeg = float(i) * 10.0
      var s, c : float
      sincos(angleDeg * degToRad, s, c)
      let lxIn  = s * tickLen3
      let lyIn  = -c * tickLen3
      let lxOut = s * RING_R_OUT
      let lyOut = -c * RING_R_OUT
      drawLine(float2(lxIn * hrCos - lyIn * hrSin, lxIn * hrSin + lyIn * hrCos),
               float2(lxOut * hrCos - lyOut * hrSin, lxOut * hrSin + lyOut * hrCos))
      if i % 3 == 0
        let compassHdg = (int(angleDeg) + 360) % 360
        let lx = s * (RING_R_IN - 0.01)
        let ly = -c * (RING_R_IN - 0.01)
        drawStrAnchored(float2(lx * hrCos - ly * hrSin, lx * hrSin + ly * hrCos),
                        fmt(":02d", compassHdg / 10), AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    setColor(COLOR_WHITE)
    let triH = 0.018
    let triW = 0.011
    let triY = -(RING_R_OUT + 0.007)
    var tri = array<float2>()
    tri |> push(float2(0.0, triY))
    tri |> push(float2(-triW, triY - triH))
    tri |> push(float2(triW, triY - triH))
    drawFilledPoly(tri)
    setColor(COLOR_YELLOW)
    let arrBase = -(RING_R_IN - 0.014)
    let arrTip  = -(BALL_R - 0.028)
    let arrW = 0.008
    var arr = array<float2>()
    arr |> push(float2(0.0, arrTip))
    arr |> push(float2(-arrW, arrBase))
    arr |> push(float2(arrW, arrBase))
    drawFilledPoly(arr)

  def drawSpeedBox()
    let ias = iasMps * MPS_TO_KPH
    let str = "{int(ias)}"
    let lt = float2(-0.49, -0.49)
    let rb = float2(-0.289, -0.375)
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(lt, rb)
    setColor(COLOR_WHITE)
    setFillColor(E3DCOLOR(0x0))
    drawBox(lt, rb)
    setFontSize(int(float(fontSize) * 1.05))
    drawStrAnchored(float2(rb.x - 0.01, (lt.y + rb.y) * 0.5), str, AnchorHorz.Right, AnchorVert.Center)
    setFontSize(int(float(labelFontSize) * 1.2))
    drawStrAnchored(float2(lt.x + 0.02, rb.y + 0.016), "КМ/Ч", AnchorHorz.Left, AnchorVert.Top)
    setFontSize(fontSize)

  def drawAltBox()
    let alt = altM
    let str = "{int(alt)}"
    let lt = float2(0.289, -0.49)
    let rb = float2(0.49, -0.375)
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(lt, rb)
    setColor(COLOR_WHITE)
    setFillColor(E3DCOLOR(0x0))
    drawBox(lt, rb)
    setFontSize(int(float(fontSize) * 1.05))
    drawStrAnchored(float2(lt.x + 0.01, (lt.y + rb.y) * 0.5), str, AnchorHorz.Left, AnchorVert.Center)
    setFontSize(fontSize - 3)
    drawStrAnchored(float2(rb.x - 0.02, rb.y + 0.01), "М", AnchorHorz.Right, AnchorVert.Top)
    setFontSize(fontSize)

  def drawVertSpeedScale()
    let vsOffset = float2(0.07, 0.0)
    let vsR = RING_R_OUT * 1.05
    let arcHalf = PI * 0.2
    setColor(COLOR_WHITE)
    setFillColor(E3DCOLOR(0x0))
    setLineWidth(2.0)
    drawSector(vsOffset, float2(vsR, vsR), float2(-arcHalf, arcHalf))
    for step in range(-2, 3)
      let v = float(step * 10)
      let angle = -v / VS_RANGE * arcHalf
      var sinA, cosA : float
      sincos(angle, sinA, cosA)
      drawLine(vsOffset + float2(cosA * (vsR + 0.005), sinA * (vsR + 0.005)),
               vsOffset + float2(cosA * (vsR - 0.02), sinA * (vsR - 0.02)))
      if step != 0
        let labelR = vsR - 0.06
        drawStrAnchored(vsOffset + float2(cosA * labelR, sinA * labelR), "{abs(int(v))}", AnchorHorz.Center, AnchorVert.Center)
    let clamped = clamp(vertSpeed, -VS_RANGE, VS_RANGE)
    let needleAngle = -clamped / VS_RANGE * arcHalf
    var sinN, cosN : float
    sincos(needleAngle, sinN, cosN)
    let tipC   = vsOffset + float2(cosN * vsR, sinN * vsR)
    let baseCc = vsOffset + float2(cosN * vsR * 0.80, sinN * vsR * 0.80)
    let arrow <- to_array_move(fixed_array(
      tipC,
      baseCc + float2(-sinN * 0.0144, cosN * 0.0144),
      baseCc + float2(sinN * 0.0144, -cosN * 0.0144)))
    setFillColor(COLOR_WHITE)
    drawFilledPolyOutlined(arrow)
    setFillColor(E3DCOLOR(0x0))
    let charH = float(fontSize) / axesScale.y * 1.1
    let msPos = vsOffset + float2(vsR - 0.12, 0.0)
    drawStrAnchored(msPos - float2(0.0, charH * 0.5), "М", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(msPos + float2(0.0, charH * 0.5), "С", AnchorHorz.Center, AnchorVert.Center)

  def drawMach()
    let str = "{fmt(":1.2f", machNum)}М"
    let lt = float2(-0.49, 0.375)
    let rb = float2(-0.289, 0.49)
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(lt, rb)
    setColor(COLOR_WHITE)
    setFillColor(E3DCOLOR(0x0))
    drawBox(lt, rb)
    setFontSize(int(float(fontSize) * 1.05))
    drawStrAnchored(float2(lt.x + 0.01, (lt.y + rb.y) * 0.5), str, AnchorHorz.Left, AnchorVert.Center)
    setFontSize(fontSize)

  def drawPressure()
    let hpa = roundi(pressurePa * 0.01)
    let str = "{hpa}.0"
    let lt = float2(0.289, 0.375)
    let rb = float2(0.49, 0.49)
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(lt, rb)
    setColor(COLOR_WHITE)
    setFillColor(E3DCOLOR(0x0))
    drawBox(lt, rb)
    setFontSize(int(float(fontSize) * 1.05))
    drawStrAnchored(float2(rb.x - 0.01, (lt.y + rb.y) * 0.5), str, AnchorHorz.Right, AnchorVert.Center)
    setFontSize(labelFontSize)
    drawStrAnchored(float2(lt.x + 0.02, lt.y - 0.01), "QFE", AnchorHorz.Left, AnchorVert.Bottom)
    setFontSize(fontSize)

  def drawSlipAngle()
    let span    = 10.0
    let tubeW   = 0.28
    let tubeH   = 0.044
    let center  = float2(-0.065, 0.44)
    setColor(COLOR_BLACK)
    setFillColor(COLOR_WHITE)
    drawBox(center - float2(tubeW * 0.5, tubeH * 0.5), center + float2(tubeW * 0.5, tubeH * 0.5))
    setColor(COLOR_BLACK)
    for i in range(5)
      let x = lerp(-tubeW * 0.45, tubeW * 0.45, float(i) / 4.0)
      drawLine(center + float2(x, -tubeH * 0.4), center + float2(x, tubeH * 0.4))
    let ballR = tubeH * 0.38
    let slipX = clamp(slipAngleDeg / span, -0.48, 0.48) * tubeW * 0.5
    setFillColor(COLOR_BLACK)
    drawCircle(center + float2(slipX, 0.0), ballR)
    setFillColor(E3DCOLOR(0x0))

  def draw()
    return if !isValid
    setFullCanvasViewport()
    let savedOrigin = axesOrigin
    setOrigin(axesOrigin - float2(0.08 * axesScale.x, 0.0))
    drawBackground()
    drawAviaHorizont()
    drawCircleFrame()
    drawCompassRing()
    setOrigin(savedOrigin)
    drawSpeedBox()
    drawAltBox()
    drawVertSpeedScale()
    drawMach()
    drawPressure()
    drawSlipAngle()
    restoreViewport()

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId        = getInt(props, "fontId", 0)
  propStorage.fontSize      = getInt(props, "fontSize", 14)
  propStorage.labelFontSize = getInt(props, "labelFontSize", 11)
  propStorage.horMask       = getPicture(props, "horMask")
