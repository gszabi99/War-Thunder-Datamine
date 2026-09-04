require %gameLibs.das.math
require %gameLibs.das.math.base
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require app
require DagorMath
require DagorStdGuiRender
require darg
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
  smoothedAoa : float = 0.0
  prevTime    : float = -1.0

let
  COLOR_BLACK  = E3DCOLOR(uint4(0, 0, 0, 255))
  COLOR_WHITE  = E3DCOLOR(uint4(255, 255, 255, 255))
  COLOR_SKY    = E3DCOLOR(uint4(0, 50, 200, 255))
  COLOR_GROUND = E3DCOLOR(uint4(255, 60, 0, 255))
  COLOR_YELLOW = E3DCOLOR(uint4(255, 200, 0, 255))
  COLOR_RED    = E3DCOLOR(uint4(220, 30, 30, 255))
  COLOR_TRI     = E3DCOLOR(uint4(0, 10, 200, 255))
  COLOR_TRI_GND   = E3DCOLOR(uint4(255, 20, 0, 255))
  COLOR_NULL      = E3DCOLOR(0x0)
  COLOR_LIGHT_BLUE = E3DCOLOR(uint4(0, 50, 200, 255))
  COLOR_PIL_BOX    = E3DCOLOR(uint4(0, 20, 120, 255))

  HOR_OFFSET_Y = 0.18
  BALL_R       = 0.22
  RING_R_IN    = 0.255
  RING_R_OUT   = 0.280

  DIAL_SCALE   = 0.85
  DIAL_R       = 0.165
  SPD_CTR      = float2(-0.23, -0.23)
  ALT_CTR      = float2(0.23, -0.23)
  SPD_OFFSET   = float2(0.03, -0.04)
  ALT_OFFSET   = float2(-0.03, -0.04)

  ARC_R        = 0.22
  ARC_HALF     = PI * 0.38

  BAR_FONT_SIZE = 13

class Component : Canvas
  isValid      : bool             = false
  hero         : Unit?            = null
  fmw          : FlightModelWrap? = null
  app          : AcesApp?         = null
  pitchDeg     : float            = 0.0
  rollDeg      : float            = 0.0
  headingRad   : float            = 0.0
  iasMps       : float            = 0.0
  altM         : float            = 0.0
  aoaDeg       : float            = 0.0
  fontSize     : int              = 20

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
    pitchDeg = fmw.tangage
    rollDeg  = fmw.roll
    let fwd = hero.unitTm[0]
    headingRad = atan2(fwd.x, fwd.z)
    iasMps  = fmw.ias
    altM    = hero.unitTm[3].y - app.currentScene.waterLevel
    let rawAoa  = fmw.fm.aoa
    let curTime = get_sync_time()
    let dt      = props.prevTime < 0.0 ? 0.0 : clamp(curTime - props.prevTime, 0.0, 0.1)
    props.prevTime = curTime
    let alpha  = 1.0 - exp(-dt / 0.5)
    props.smoothedAoa = lerp(props.smoothedAoa, rawAoa, alpha)
    aoaDeg = props.smoothedAoa
    setColor(COLOR_WHITE)
    setLineWidth(1.0)
    setFont(props.fontId)
    setFontSize(fontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)

  def drawBackground()
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(float2(-0.5, -0.5), float2(0.5, 0.5))

  def drawAviaHorizont()
    let horY = BALL_R * cvt_ex(pitchDeg, -30.0, 30.0, -1.0, 1.0)
    setViewport(float2(-BALL_R * 0.75, -BALL_R), float2(BALL_R * 0.75, BALL_R))
    setColor(COLOR_SKY)
    setFillColor(COLOR_SKY)
    drawBox(float2(-0.5, -0.5), float2(0.5, horY))
    setColor(COLOR_GROUND)
    setFillColor(COLOR_GROUND)
    drawBox(float2(-0.5, horY), float2(0.5, 0.5))
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    drawLine(float2(-BALL_R, horY), float2(BALL_R, horY))
    let triRatio = 0.3 / 2.1
    let upW = (horY + BALL_R) * triRatio
    let dnW = (BALL_R - horY) * triRatio
    setColor(COLOR_TRI)
    setFillColor(COLOR_TRI)
    var triUp = array<float2>()
    triUp |> push(float2(0.0,   horY))
    triUp |> push(float2(-upW,  -BALL_R))
    triUp |> push(float2(upW,  -BALL_R))
    drawFilledPolyOutlined(triUp)
    setColor(COLOR_TRI_GND)
    setFillColor(COLOR_TRI_GND)
    var triDn = array<float2>()
    triDn |> push(float2(0.0,   horY))
    triDn |> push(float2(-dnW,   BALL_R))
    triDn |> push(float2(dnW,   BALL_R))
    drawFilledPolyOutlined(triDn)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    let pitchFontSize = int(float(fontSize) * 0.8)
    setFontSize(pitchFontSize)
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

    let frameR = BALL_R
    let frameOuter = BALL_R * 1.5
    let arcN = 20
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    var topHalf = array<float2>()
    topHalf |> push(float2(-frameOuter, frameOuter))
    topHalf |> push(float2(-frameOuter, 0.0))
    topHalf |> push(float2(-frameR, 0.0))
    for i in range(arcN + 1)
      let a = PI * float(i) / float(arcN)
      topHalf |> push(float2(-cos(a) * frameR, sin(a) * frameR))
    topHalf |> push(float2(frameR, 0.0))
    topHalf |> push(float2(frameOuter, 0.0))
    topHalf |> push(float2(frameOuter, frameOuter))
    drawFilledPoly(topHalf)
    var bottomHalf = array<float2>()
    bottomHalf |> push(float2(-frameOuter, -frameOuter))
    bottomHalf |> push(float2(-frameOuter, 0.0))
    bottomHalf |> push(float2(-frameR, 0.0))
    for i in range(arcN + 1)
      let a = -PI * float(i) / float(arcN)
      bottomHalf |> push(float2(-cos(a) * frameR, sin(a) * frameR))
    bottomHalf |> push(float2(frameR, 0.0))
    bottomHalf |> push(float2(frameOuter, 0.0))
    bottomHalf |> push(float2(frameOuter, -frameOuter))
    drawFilledPoly(bottomHalf)

    restoreViewport()
    setRotation(float2(0.0, 0.0), rollDeg * degToRad)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    let cirR = 0.028
    let wingEnd = 0.195
    let wing = fixed_array(
      float2(-cirR,    0.0),
      float2(-0.027,   0.0),
      float2(-0.07,   0.033),
      float2(-0.1,   0.0),
      float2(-wingEnd, 0.0))
    let stab = fixed_array(
      float2(0.0, -cirR),
      float2(0.0, -0.11))
    setLineWidth(2.0)
    drawPolyLine(wing.to_array())
    drawPolyLine(wing.to_array().inv_x())
    drawPolyLine(stab.to_array())
    drawCircle(float2(0.0), cirR)
    setFillColor(COLOR_WHITE)
    drawCircle(float2(0.0), cirR * 0.15)
    setLineWidth(2.0)
    resetViewTm()
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)

  def drawCircleFrame()
    let n = 32
    let outerHw = 0.7
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
      botHalf |> push(float2(RING_R_OUT * c,  RING_R_OUT * s))
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawFilledPoly(topHalf)
    drawFilledPoly(botHalf)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    drawCircle(float2(0.0), RING_R_OUT)

  def drawCompassRing()
    setFontSize(int(float(fontSize) * 0.90))
    var hrSin, hrCos : float
    sincos(-headingRad, hrSin, hrCos)
    let majorTickR = RING_R_IN + (RING_R_OUT - RING_R_IN) * 0.54
    let minorTickR = RING_R_IN + (RING_R_OUT - RING_R_IN) * 0.77
    for i in range(72)
      let angleDeg = float(i) * 5.0
      var s, c : float
      sincos(angleDeg * degToRad, s, c)
      let tickR = (i % 2 == 0) ? majorTickR : minorTickR
      let lxIn  =  s * tickR
      let lyIn  = -c * tickR
      let lxOut =  s * RING_R_OUT
      let lyOut = -c * RING_R_OUT
      drawLine(float2(lxIn  * hrCos - lyIn  * hrSin, lxIn  * hrSin + lyIn  * hrCos),
               float2(lxOut * hrCos - lyOut * hrSin, lxOut * hrSin + lyOut * hrCos))
      if i % 6 == 0
        let hdg = (int(angleDeg) + 360) % 360
        let lx = s * (RING_R_IN - 0.001)
        let ly = -c * (RING_R_IN - 0.001)
        drawStrAnchored(float2(lx * hrCos - ly * hrSin, lx * hrSin + ly * hrCos),
                        "{hdg / 10}", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    let ring1R = BALL_R * 1.0
    let ring2R = BALL_R * 1.05
    setLineWidth(2.5)
    drawCircle(float2(0.0), ring1R)
    setLineWidth(1.0)
    drawCircle(float2(0.0), ring2R)
    setLineWidth(2.0)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_WHITE)
    let majLen = 0.0072
    let minLen = 0.0048
    let rectHW = 0.0024
    for i in range(7)
      let angDeg = 90.0 + float(i) * 30.0
      var s, c : float
      sincos(angDeg * degToRad, s, c)
      let r1 = ring1R
      let r2 = ring1R - 2.0 * majLen
      var rect = array<float2>()
      rect |> push(float2(s * r1 - c * rectHW, -c * r1 - s * rectHW))
      rect |> push(float2(s * r1 + c * rectHW, -c * r1 + s * rectHW))
      rect |> push(float2(s * r2 + c * rectHW, -c * r2 + s * rectHW))
      rect |> push(float2(s * r2 - c * rectHW, -c * r2 - s * rectHW))
      drawFilledPolyOutlined(rect)
    for i in range(6)
      let angDeg = 105.0 + float(i) * 30.0
      var s, c : float
      sincos(angDeg * degToRad, s, c)
      let r1 = ring1R
      let r2 = ring1R - 2.0 * minLen
      var rect = array<float2>()
      rect |> push(float2(s * r1 - c * rectHW, -c * r1 - s * rectHW))
      rect |> push(float2(s * r1 + c * rectHW, -c * r1 + s * rectHW))
      rect |> push(float2(s * r2 + c * rectHW, -c * r2 + s * rectHW))
      rect |> push(float2(s * r2 - c * rectHW, -c * r2 - s * rectHW))
      drawFilledPolyOutlined(rect)
    let triH  = 0.018
    let triW  = 0.011
    let triY  = -(RING_R_OUT + 0.007)
    var tri = array<float2>()
    tri |> push(float2(0.0, triY))
    tri |> push(float2(-triW, triY - triH))
    tri |> push(float2(triW, triY - triH))
    setColor(COLOR_WHITE)
    drawFilledPoly(tri)

  def drawHeadingBox()
    let hdgDeg = norm_ang(headingRad) * radToDeg
    let hdg = roundi(hdgDeg) % 360
    let str = fmt(":03d", hdg)
    let boxPos = float2(0.0, -RING_R_OUT - 0.04)
    let halfSz = getStringSize(str) * 0.5 + float2(0.022, 0.010)
    pushLocalAxes(boxPos, halfSz)
    setFillColor(COLOR_BLACK)
    drawBox(float2(-1.0), float2(1.0))
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    drawBox(float2(-1.0), float2(1.0))
    drawStrAnchored(float2(0.0), str, AnchorHorz.Center, AnchorVert.Center)
    popAxes()

  def drawPitchArc()
    let scaleScreenDegreesLength = 80.0
    let scaleRange = float2(degToRad * (-(scaleScreenDegreesLength * 0.5)),
      degToRad * (scaleScreenDegreesLength * 0.5))

    let scaleRadius = 0.35
    let scaleHalfWidth = 0.03

    let innerRadius = scaleRadius - scaleHalfWidth
    let outerRadius = scaleRadius + scaleHalfWidth
    drawSector(float2(0.0), float2(innerRadius), scaleRange)
    drawSector(float2(0.0), float2(outerRadius), scaleRange)

    var sinBot, cosBot, sinTop, cosTop : float
    sincos(scaleRange.x, sinBot, cosBot)
    sincos(scaleRange.y, sinTop, cosTop)
    drawLine(float2(cosBot * innerRadius, sinBot * innerRadius), float2(cosBot * outerRadius, sinBot * outerRadius))
    drawLine(float2(cosTop * innerRadius, sinTop * innerRadius), float2(cosTop * outerRadius, sinTop * outerRadius))

    let pitchScaleMaxAngle = 25.0
    let pitchScaleMinAngle = -25.0
    let pitchScaleAngleRange = pitchScaleMaxAngle - pitchScaleMinAngle

    let majorTickLen = 0.02
    let minorTickLen = 0.012
    var sinA, cosA : float
    for i in 0..int(pitchScaleAngleRange) + 1
      let pitchVal = int(pitchScaleMinAngle) + i

      let t = float(i) / pitchScaleAngleRange
      let angle = -lerp(scaleRange.x, scaleRange.y, t)
      sincos(angle, sinA, cosA)
      setColor(COLOR_WHITE)
      let isMajor = pitchVal % 5 == 0
      let isMinorVisible = pitchVal >= -10 && pitchVal <= 10
      if isMajor || isMinorVisible
        let tickLen = isMajor ? majorTickLen : minorTickLen
        let r0 = outerRadius
        let r1 = r0 - tickLen
        drawLine(float2(cosA * r0, sinA * r0), float2(cosA * r1, sinA * r1))

      if pitchVal % 10 == 0
        let labelR = outerRadius - 0.025
        setFontSize(int(float(fontSize) * 0.8))
        drawStrAnchored(float2(cosA * labelR, sinA * labelR),
                        "{abs(pitchVal)}", AnchorHorz.Right, AnchorVert.Center)
        setFontSize(fontSize)

    let clampedPitch = clamp(pitchDeg, pitchScaleMinAngle, pitchScaleMaxAngle)
    let rotationAngle = cvt(-clampedPitch, pitchScaleMinAngle, pitchScaleMaxAngle, -scaleScreenDegreesLength, scaleScreenDegreesLength) * 0.5 * degToRad
    setRotation(float2(0.0), rotationAngle)
    setColor(COLOR_WHITE)
    let ptrHalf = 0.008
    let ptrTipX = scaleRadius
    let ptrBodyStart = scaleRadius - 0.02
    let ptrTailX = scaleRadius - 0.06
    setFillColor(COLOR_WHITE)
    drawFilledPoly([float2(ptrTipX, 0.0), float2(ptrBodyStart, ptrHalf), float2(ptrTailX, ptrHalf), float2(ptrTailX, -ptrHalf), float2(ptrBodyStart, -ptrHalf)])
    resetViewTm()

  def drawAoaArc()
    let scaleScreenDegreesLength = 80.0
    let scaleRange = float2(degToRad * (180.0 - scaleScreenDegreesLength * 0.5),
      degToRad * (180.0 + scaleScreenDegreesLength * 0.5))

    let scaleRadius = 0.35
    let scaleHalfWidth = 0.03

    let innerRadius = scaleRadius - scaleHalfWidth
    let outerRadius = scaleRadius + scaleHalfWidth
    drawSector(float2(0.0), float2(innerRadius), scaleRange)
    drawSector(float2(0.0), float2(outerRadius), scaleRange)

    var sinBot, cosBot, sinTop, cosTop : float
    sincos(scaleRange.x, sinBot, cosBot)
    sincos(scaleRange.y, sinTop, cosTop)
    drawLine(float2(cosBot * innerRadius, sinBot * innerRadius), float2(cosBot * outerRadius, sinBot * outerRadius))
    drawLine(float2(cosTop * innerRadius, sinTop * innerRadius), float2(cosTop * outerRadius, sinTop * outerRadius))


    let aoaScaleMaxAngle = 32.0
    let aoaScaleMinAngle = -8.0
    let aoaScaleAngleRange = aoaScaleMaxAngle - aoaScaleMinAngle

    let criticalAngle = 27.5

    let critT = (criticalAngle - aoaScaleMinAngle) / aoaScaleAngleRange
    let redRange = float2(lerp(scaleRange.x, scaleRange.y, critT), scaleRange.y)
    setColor(COLOR_RED)
    drawSector(float2(0.0), float2(outerRadius), redRange)

    let majorTickLen = 0.02
    let minorTickLen = 0.012
    var sinA, cosA : float
    for i in 0..int(aoaScaleAngleRange) + 1
      let aoaVal = int(aoaScaleMinAngle) + i

      let t = float(i) / aoaScaleAngleRange
      let angle = lerp(scaleRange.x, scaleRange.y, t)
      sincos(angle, sinA, cosA)
      setColor(float(aoaVal) >= criticalAngle ? COLOR_RED : COLOR_WHITE)
      let isMajor = aoaVal % 5 == 0
      let tickLen = isMajor ? majorTickLen : minorTickLen
      let r0 = outerRadius
      let r1 = r0 - tickLen
      drawLine(float2(cosA * r0, sinA * r0), float2(cosA * r1, sinA * r1))

      if aoaVal % 10 == 0
        let labelR = outerRadius - 0.025
        setColor(COLOR_WHITE)
        setFontSize(int(float(fontSize) * 0.8))
        drawStrAnchored(float2(cosA * labelR, sinA * labelR),
                        "{aoaVal}", AnchorHorz.Left, AnchorVert.Center)
        setFontSize(fontSize)

    let clampedAoa = clamp(aoaDeg, aoaScaleMinAngle, aoaScaleMaxAngle)
    let rotationAngle = cvt(clampedAoa, aoaScaleMinAngle, aoaScaleMaxAngle, -scaleScreenDegreesLength, scaleScreenDegreesLength) * 0.5 * degToRad
    setRotation(float2(0.0), rotationAngle)
    setColor(COLOR_WHITE)
    drawFilledPoly([float2(0.0, 0.0), float2(0.05, 0.0), float2(0.05, -0.02), float2(0.04, -0.01)].translate(float2(-scaleRadius, 0.0)))
    resetViewTm()


  def drawRoundDial(ctr : float2; max_val : float; val : float; lbl : string; scale : float; dialFontSize : int = -1; val2 : float = -1.0; max_val2 : float = -1.0; dispVal : float = -1.0; innerRingScale : float = -1.0)
    let dr      = DIAL_R * scale
    let tick    = 0.022 * scale
    let lblOff  = 0.045 * scale
    let minTick = 0.012 * scale
    let halfW   = 0.050 * scale
    let halfH   = 0.02 * scale
    setColor(COLOR_WHITE)
    setFillColor(COLOR_BLACK)
    drawCircle(ctr, dr)
    setFillColor(COLOR_NULL)
    var sina, cosa : float
    let baseFontSz  = (dialFontSize > 0 ? dialFontSize : fontSize)
    let smallFontSz = int(float(baseFontSz) * 0.9)
    setFontSize(smallFontSz)
    for i in 0..10
      let angle = float(i) * TWOPI / 10.0 - PI_2
      sincos(angle, sina, cosa)
      let r1 = dr - tick
      drawLine(ctr + float2(cosa * r1, sina * r1),
               ctr + float2(cosa * dr, sina * dr))
      let labelR = dr - lblOff
      drawStrAnchored(ctr + float2(cosa * labelR, sina * labelR),
                      "{i}", AnchorHorz.Center, AnchorVert.Center)
      for j in 1..5
        let minorAngle = angle + float(j) * TWOPI / 50.0
        sincos(minorAngle, sina, cosa)
        let mr1 = dr - minTick
        drawLine(ctr + float2(cosa * mr1, sina * mr1),
                 ctr + float2(cosa * dr,  sina * dr))
    setFontSize(fontSize)
    if innerRingScale > 0.0
      let irR    = dr * innerRingScale
      let irTick = 0.012 * scale
      drawCircle(ctr, irR)
      for i in 0..10
        let angle = float(i) * TWOPI / 10.0 - PI_2
        sincos(angle, sina, cosa)
        drawLine(ctr + float2(cosa * (irR - irTick), sina * (irR - irTick)),
                 ctr + float2(cosa * irR,             sina * irR))
    let needleAngle = clamp(val, 0.0, max_val) / max_val * TWOPI - PI_2
    sincos(needleAngle, sina, cosa)
    let ndlTipR  = dr * 0.72
    let ndlBaseR = -(dr * 0.08)
    let ndlTailR = -(dr * 0.14)
    let ndlHwBase = 0.009 * scale
    let ndlHwTail = 0.004 * scale
    let perpX = -sina
    let perpY =  cosa
    var needle = array<float2>()
    needle |> push(ctr + float2(cosa * ndlTipR,                        sina * ndlTipR))
    needle |> push(ctr + float2(cosa * ndlBaseR - perpX * ndlHwBase,   sina * ndlBaseR - perpY * ndlHwBase))
    needle |> push(ctr + float2(cosa * ndlTailR - perpX * ndlHwTail,   sina * ndlTailR - perpY * ndlHwTail))
    needle |> push(ctr + float2(cosa * ndlTailR + perpX * ndlHwTail,   sina * ndlTailR + perpY * ndlHwTail))
    needle |> push(ctr + float2(cosa * ndlBaseR + perpX * ndlHwBase,   sina * ndlBaseR + perpY * ndlHwBase))
    setFillColor(COLOR_WHITE)
    drawFilledPolyOutlined(needle)
    setFillColor(COLOR_NULL)
    if max_val2 > 0.0
      let needleAngle2 = clamp(val2, 0.0, max_val2) / max_val2 * TWOPI - PI_2
      var s2, c2 : float
      sincos(needleAngle2, s2, c2)
      let px2 = -s2
      let py2 =  c2
      let tip2R = ndlTipR * 0.80
      var needle2 = array<float2>()
      needle2 |> push(ctr + float2(c2 * tip2R,                       s2 * tip2R))
      needle2 |> push(ctr + float2(c2 * ndlBaseR - px2 * ndlHwBase,  s2 * ndlBaseR - py2 * ndlHwBase))
      needle2 |> push(ctr + float2(c2 * ndlTailR - px2 * ndlHwTail,  s2 * ndlTailR - py2 * ndlHwTail))
      needle2 |> push(ctr + float2(c2 * ndlTailR + px2 * ndlHwTail,  s2 * ndlTailR + py2 * ndlHwTail))
      needle2 |> push(ctr + float2(c2 * ndlBaseR + px2 * ndlHwBase,  s2 * ndlBaseR + py2 * ndlHwBase))
      setFillColor(COLOR_WHITE)
      drawFilledPolyOutlined(needle2)
      setFillColor(COLOR_NULL)
    drawCircle(ctr, 0.006 * scale)

    let displayValue = int(dispVal >= 0.0 ? dispVal : val)
    let valStr = "{displayValue}"
    let valBoxCtr = ctr + float2(0.0, -0.040 * scale)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_BLACK)
    drawBox(valBoxCtr - float2(halfW, halfH), valBoxCtr + float2(halfW, halfH))
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    drawBox(valBoxCtr - float2(halfW, halfH), valBoxCtr + float2(halfW, halfH))
    drawStrAnchored(valBoxCtr, valStr, AnchorHorz.Center, AnchorVert.Center)
    let smallLblSz = int(float(fontSize) * 0.65)
    setFontSize(smallLblSz)
    drawStrAnchored(ctr + float2(0.0, halfH + 0.016 * scale), lbl, AnchorHorz.Center, AnchorVert.Top)
    setFontSize(fontSize)

  def drawSpdDial(dialFontSize : int = -1)
    drawRoundDial(SPD_CTR + SPD_OFFSET, 1000.0, iasMps * MPS_TO_KPH, "", DIAL_SCALE, dialFontSize)

  def drawAltDial(dialFontSize : int = -1)
    drawRoundDial(ALT_CTR + ALT_OFFSET, 1000.0, altM % 1000.0, "", DIAL_SCALE, dialFontSize, altM, 10000.0, altM, 0.58)

  def drawTopBar()
    setColor(COLOR_LIGHT_BLUE)
    setFillColor(COLOR_LIGHT_BLUE)
    drawBox(float2(-0.5, -0.5), float2(0.5, -0.44))
    let smallSz = BAR_FONT_SIZE
    setFontSize(smallSz)
    let step = 1.0 / 6.0
    let lblY = -0.455
    let pilX = -0.5 + step * 0.9
    let pilSz = getStringSize("ПИЛ") * 0.5 + float2(0.010, 0.006)
    pushLocalAxes(float2(pilX, lblY), pilSz)
    setFillColor(COLOR_PIL_BOX)
    setColor(COLOR_PIL_BOX)
    drawBox(float2(-1.0), float2(1.0))
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    drawStrAnchored(float2(0.0), "ПИЛ", AnchorHorz.Center, AnchorVert.Center)
    popAxes()
    setColor(COLOR_WHITE)
    drawStrAnchored(float2(-0.5 + step * 1.6, lblY), "ТО",   AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.5 + step * 2.3, lblY), "РЭП",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.5 + step * 3.0, lblY), "ОПС",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.5 + step * 3.7, lblY), "СИСТ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.5 + step * 4.3, lblY), "ИЛС",  AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    setFillColor(COLOR_NULL)

  def draw()
    return if !isValid
    setFullCanvasViewport()
    let savedOrigin = axesOrigin
    setOrigin(axesOrigin + float2(0.0, HOR_OFFSET_Y * axesScale.y))
    drawBackground()
    drawAviaHorizont()
    drawCircleFrame()
    drawCompassRing()
    drawHeadingBox()
    drawAoaArc()
    drawPitchArc()
    setOrigin(savedOrigin)
    drawTopBar()
    drawSpdDial()
    drawAltDial()
    restoreViewport()

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; var props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId     = getInt(props, "fontId", 0)
  propStorage.fontSize   = getInt(props, "fontSize", 20)
