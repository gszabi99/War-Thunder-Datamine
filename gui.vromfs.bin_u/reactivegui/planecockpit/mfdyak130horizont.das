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
  horMask : Picture const? = null


let
  COLOR_BLACK      = E3DCOLOR(uint4(0, 0, 0, 255))
  COLOR_WHITE      = E3DCOLOR(uint4(255, 255, 255, 255))
  COLOR_GREEN      = E3DCOLOR(uint4(0, 200, 0, 255))
  COLOR_GREEN_DIM  = E3DCOLOR(uint4(0, 120, 0, 255))
  COLOR_SKY        = E3DCOLOR(uint4(0, 50, 200, 255))
  COLOR_GROUND     = E3DCOLOR(uint4(255, 60, 0, 255))
  COLOR_YELLOW     = E3DCOLOR(uint4(255, 220, 0, 255))
  COLOR_RED        = E3DCOLOR(uint4(220, 30, 30, 255))
  COLOR_NULL       = E3DCOLOR(0x0)

  // Layout constants — matching reference layout
  HOR_CY       = -0.16         // horizon vertical center (upper area)
  BALL_R       = 0.165         // horizon ball radius (smaller)
  RING_R_IN    = 0.185
  RING_R_OUT   = 0.205

  COMPASS_CTR  = float2(0.0, 0.30)    // compass — bottom center (raised to fit border)
  COMPASS_R    = 0.117                 // compass radius (same as spd/alt dials)

  SPD_CTR      = float2(-0.20, 0.12)  // speed dial — middle left, under horizon
  ALT_CTR      = float2(0.20, 0.12)   // altitude dial — middle right, under horizon
  DIAL_R       = 0.125                 // dial radius
  DIAL_SCALE   = 0.72

  ARC_R        = 0.27                  // Pitch arc radius (tighter to horizon)

  RPM_X        = -0.29                 // engine RPM bar X (inside border)
  RPM_Y0       = 0.24                  // RPM bar top
  RPM_Y1       = 0.42                  // RPM bar bottom
  RPM_W        = 0.010                 // RPM bar half-width
  RPM_GAP      = 0.026                 // gap between L/R bars

  BAR_FONT_SIZE = 13

  GSCALE_BAR_X      = -0.31          // G-force bar horizontal position
  GSCALE_TICK_SIZE  = 0.027          // Y distance per 1g in upper scale
  GSCALE_UPPER_MIN  = -2.0           // upper scale lower bound (g)
  GSCALE_UPPER_MAX  = 10.0           // upper scale upper bound (g)
  GSCALE_LOWER_MIN  = -10.0          // lower scale lower bound (g)
  GSCALE_UPPER_TICKS = int(GSCALE_UPPER_MAX - GSCALE_UPPER_MIN)
  GSCALE_LOWER_TICKS = 2             // lower scale spans this many tick-size steps
  GSCALE_UPPER_HEIGHT = float(GSCALE_UPPER_TICKS) * GSCALE_TICK_SIZE
  GSCALE_LOWER_HEIGHT = float(GSCALE_LOWER_TICKS) * GSCALE_TICK_SIZE

  AOA_ARC_CTR      = float2(-0.025, HOR_CY)  // arc center
  AOA_ARC_R        = BALL_R + 0.055          // arc radius
  AOA_LIMITS       = float2(-10.0, 47.0)     // min/max AoA (degrees)
  AOA_DISPLAY_MULT = 2.4                     // visual degrees per AoA degree (0° AoA = right)
  AOA_SAFE_RANGE   = float2(-8.0, 26.0)      // safe AoA range (white); red outside


def calcGScaleY(g : float) : float
  let gc = clamp(g, GSCALE_LOWER_MIN, GSCALE_UPPER_MAX)
  let upperBot = HOR_CY - GSCALE_UPPER_MIN * GSCALE_TICK_SIZE
  let upperTop = upperBot - GSCALE_UPPER_HEIGHT
  let lowerBot = upperBot + GSCALE_LOWER_HEIGHT
  if gc >= GSCALE_UPPER_MIN
    return cvt(gc, GSCALE_UPPER_MIN, GSCALE_UPPER_MAX, upperBot, upperTop)
  else
    return cvt(gc, GSCALE_UPPER_MIN, GSCALE_LOWER_MIN, upperBot, lowerBot)


def calcAoaArcAngle(aoa : float) : float
  let ac = clamp(aoa, AOA_LIMITS.x, AOA_LIMITS.y)
  return PI + ac * AOA_DISPLAY_MULT * degToRad


class Component : Canvas
  isValid      : bool             = false
  hero         : Unit?            = null
  fmw          : FlightModelWrap? = null
  app          : AcesApp?         = null
  pitchDeg     : float            = 0.0
  rollDeg      : float            = 0.0
  headingRad   : float            = 0.0
  iasMps       : float            = 0.0
  tasKph       : float            = 0.0
  altM         : float            = 0.0
  altGeomM     : float            = 0.0
  aoaDeg       : float            = 0.0
  machNum      : float            = 0.0
  vyMps        : float            = 0.0
  nyG          : float            = 1.0
  sideSlipDeg  : float            = 0.0
  rpmL         : float            = 0.0
  rpmR         : float            = 0.0
  fontSize     : int              = 20
  horMask      : Picture const?   = null


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
    horMask  = props.horMask

    pitchDeg   = fmw.tangage
    rollDeg    = fmw.roll
    let fwd    = hero.unitTm[0]
    headingRad = atan2(fwd.x, fwd.z)
    iasMps     = fmw.ias
    tasKph     = fmw.fm.speed * MPS_TO_KPH
    altM       = hero.unitTm[3].y - app.currentScene.waterLevel
    altGeomM   = fmw.fm.input.currentAlt
    machNum    = fmw.fm.cache.Mach
    vyMps      = hero.vel.y
    nyG        = float(fmw.fm.localAccel.y) / 9.81

    let rawAoa  = fmw.fm.aoa
    let curTime = get_sync_time()
    let dt      = props.prevTime < 0.0 ? 0.0 : clamp(curTime - props.prevTime, 0.0, 0.1)
    props.prevTime = curTime
    let alpha   = 1.0 - exp(-dt / 0.5)
    props.smoothedAoa = lerp(props.smoothedAoa, rawAoa, alpha)
    aoaDeg     = props.smoothedAoa

    sideSlipDeg = fmw.fm.aos

    if fmw.fm.EI.numEngines > 0
      assume propulsion = *(fmw.fm.EI)
      propulsion_getEngine(propulsion, 0) <| $(eng)
        rpmL = eng.omegaRel * 100.0
      if fmw.fm.EI.numEngines > 1
        propulsion_getEngine(propulsion, 1) <| $(eng)
          rpmR = eng.omegaRel * 100.0

    setColor(COLOR_GREEN)
    setLineWidth(1.5)
    setFont(props.fontId)
    setFontSize(fontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.x * 1.25, canvasSize.y))


  // ── Background ──
  def drawBackground()
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(float2(-0.5, -0.5), float2(0.5, 0.5))


  // ── Border ──
  def drawBorder()
    let rx = 0.35
    let ry = 0.44
    setColor(COLOR_GREEN)
    drawLine(float2(-rx, -ry), float2(rx, -ry))
    drawLine(float2(rx, -ry),  float2(rx,  ry))
    drawLine(float2(rx,  ry),  float2(-rx,  ry))
    drawLine(float2(-rx,  ry), float2(-rx, -ry))


  // ── Top bar: ПИЛ  НВГ  ИТО  КИСС ──
  def drawTopBar()
    let smallSz = BAR_FONT_SIZE
    setFontSize(smallSz)
    let off = 0.04
    setColor(COLOR_GREEN)
    setFillColor(COLOR_NULL)
    drawStrAnchored(float2(-0.24,  -0.5 + off), "ПИЛ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.12, -0.5 + off), "НВГ",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0,   -0.5 + off), "ИТО",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.12,  -0.5 + off), "КИСС", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    setFillColor(COLOR_NULL)

    // ── Side labels ──
    let lx = -0.38
    let rx = 0.38
    let borderRy = 0.44
    let borderTop = -0.44
    let stp = 0.03

    // ДМР
    let dmrY = borderTop + 0.08
    setFillColor(COLOR_GREEN)
    setColor(COLOR_GREEN)
    drawBox(float2(lx - 0.015, dmrY - 0.015), float2(lx + 0.015, dmrY + stp * 2.0 + 0.015))
    setColor(COLOR_BLACK)
    setFillColor(COLOR_NULL)
    setFontSize(smallSz)
    drawStrAnchored(float2(lx, dmrY),             "Д", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, dmrY + stp),       "М", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, dmrY + stp * 2.0), "Р", AnchorHorz.Center, AnchorVert.Center)

    // СБРОС
    setColor(COLOR_GREEN)
    let sbY = dmrY + 0.14
    drawStrAnchored(float2(lx, sbY),             "С", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, sbY + stp),       "Б", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, sbY + stp * 2.0), "Р", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, sbY + stp * 3.0), "О", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, sbY + stp * 4.0), "С", AnchorHorz.Center, AnchorVert.Center)

    // АРК
    let arkY = 0.0 - stp
    drawStrAnchored(float2(lx, arkY),             "А", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, arkY + stp),       "Р", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, arkY + stp * 2.0), "К", AnchorHorz.Center, AnchorVert.Center)

    // ПУСК
    let puskY = borderRy - stp * 3.0
    drawStrAnchored(float2(lx, puskY),             "П", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, puskY + stp),       "У", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, puskY + stp * 2.0), "С", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(lx, puskY + stp * 3.0), "К", AnchorHorz.Center, AnchorVert.Center)

    // ВЫЗВ
    let vyY = borderTop + 0.08
    drawStrAnchored(float2(rx, vyY),             "В", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(rx, vyY + stp),       "Ы", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(rx, vyY + stp * 2.0), "З", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(rx, vyY + stp * 3.0), "В", AnchorHorz.Center, AnchorVert.Center)

    // ФОН
    let fonY = borderRy - stp * 2.0
    drawStrAnchored(float2(rx, fonY),             "Ф", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(rx, fonY + stp),       "О", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(rx, fonY + stp * 2.0), "Н", AnchorHorz.Center, AnchorVert.Center)

    setColor(COLOR_GREEN)
    setFontSize(fontSize)


  // ── Artificial Horizon (1-8) ──
  def drawAviaHorizont()
    let cy = HOR_CY
    let ballRV = BALL_R * 1.15
    let horY = cy + ballRV * cvt_ex(pitchDeg, -30.0, 30.0, -1.0, 1.0)
    setViewport(float2(-BALL_R * 0.99, cy - ballRV), float2(BALL_R * 0.99, cy + ballRV))
    // sky
    setColor(COLOR_SKY)
    setFillColor(COLOR_SKY)
    drawBox(float2(-0.5, -0.5), float2(0.5, horY))
    // ground
    setColor(COLOR_GROUND)
    setFillColor(COLOR_GROUND)
    drawBox(float2(-0.5, horY), float2(0.5, 0.5))
    // pitch ladder (6)
    let pitchFontSize = int(float(fontSize) * 0.7)
    setFontSize(pitchFontSize)
    for i in range(-6, 8)
      let markVal = (int(pitchDeg) / 5) * 5 + i * 5
      let markY = cy + (pitchDeg - float(markVal)) * ballRV / 30.0
      let markColor = markY < horY ? COLOR_BLACK : COLOR_WHITE
      setColor(markColor)
      if markVal != 0
        if abs(markVal % 10) > 0
          drawLine(float2(-BALL_R * 0.10, markY), float2(BALL_R * 0.10, markY))
        else
          drawLine(float2(-BALL_R * 0.28, markY), float2(-BALL_R * 0.10, markY))
          drawLine(float2(BALL_R * 0.10, markY), float2(BALL_R * 0.28, markY))
        if abs(markVal % 10) == 0
          drawStrAnchored(float2(0.0, markY), "{abs(markVal)}", AnchorHorz.Center, AnchorVert.Center)
    // roll ticks
    // 30° at top (near horizon line), then down to 60°
    setColor(COLOR_WHITE)
    setLineWidth(1.5)
    let pitchFontSz = int(float(fontSize) * 0.7)
    let tickLen = 0.025
    let rollAngles = fixed_array(0.0, 15.0, 30.0, 45.0, 60.0)
    let rollLabels = fixed_array("", "", "30", "", "60")
    for idx in range(min(length(rollAngles), length(rollLabels)))
      let ang = rollAngles[idx]
      let radL = (180.0 - ang) * degToRad  // left side, going down from horizon
      let radR = ang * degToRad             // right side, going down from horizon
      var sL, cL, sR, cR : float
      sincos(radL, sL, cL)
      sincos(radR, sR, cR)
      // outer point at mask edge
      let oxL = cL * BALL_R
      let oyL = cy + sL * ballRV
      let oxR = cR * BALL_R
      let oyR = cy + sR * ballRV
      // direction toward center (0, cy)
      let dxL = -oxL
      let dyL = cy - oyL
      let lenL = sqrt(dxL * dxL + dyL * dyL)
      let dxR = -oxR
      let dyR = cy - oyR
      let lenR = sqrt(dxR * dxR + dyR * dyR)
      drawLine(float2(oxL, oyL), float2(oxL + dxL / lenL * tickLen, oyL + dyL / lenL * tickLen))
      drawLine(float2(oxR, oyR), float2(oxR + dxR / lenR * tickLen, oyR + dyR / lenR * tickLen))
      if rollLabels[idx] != ""
        setFontSize(pitchFontSz)
        let lblOffL = tickLen + 0.016
        let lblOffR = tickLen + 0.016
        drawStrAnchored(float2(oxL + dxL / lenL * lblOffL, oyL + dyL / lenL * lblOffL),
                        rollLabels[idx], AnchorHorz.Center, AnchorVert.Center)
        drawStrAnchored(float2(oxR + dxR / lenR * lblOffR, oyR + dyR / lenR * lblOffR),
                        rollLabels[idx], AnchorHorz.Center, AnchorVert.Center)
        setFontSize(fontSize)
    setFontSize(fontSize)
    resetViewTm()

    // mask
    unsafe
      let m = reinterpret<Picture?>(horMask)
      setColor(COLOR_BLACK)
      setFillColor(COLOR_BLACK)
      let maskMargin = 0.01
      drawPicture(float2(-BALL_R - maskMargin, cy - ballRV - maskMargin), float2(BALL_R * 2.0 + maskMargin * 2.0, ballRV * 2.0 + maskMargin * 2.0), m)

    restoreViewport()
    setColor(COLOR_GREEN)

    // aircraft silhouette
    setRotation(float2(0.0, cy), rollDeg * degToRad)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    let wingEnd = 0.14
    let wingGap = 0.028
    let wing = fixed_array(
      float2(-wingGap,   cy),
      float2(-0.053,   cy),
      float2(-0.065,    cy + 0.015),
      float2(-0.077,   cy),
      float2(-wingEnd, cy))
    let stab = fixed_array(
      float2(0.0, cy - wingGap),
      float2(0.0, cy - 0.08))
    setLineWidth(1.7)
    drawPolyLine(wing.to_array())
    drawPolyLine(wing.to_array().inv_x())
    drawPolyLine(stab.to_array())
    setFillColor(COLOR_WHITE)
    drawCircle(float2(0.0, cy), 0.004)
    setFillColor(COLOR_NULL)
    setLineWidth(1.5)
    resetViewTm()
    setColor(COLOR_GREEN)
    setFillColor(COLOR_NULL)



  // ── Heading compass dial (10-13) ──
  def drawCompassDial()
    let ctr = COMPASS_CTR
    let r = COMPASS_R
    setColor(COLOR_WHITE)
    setFillColor(COLOR_BLACK)
    drawCircle(ctr, r)
    setFillColor(COLOR_NULL)
    // rotating compass ring
    let smallFont = int(float(fontSize) * 0.7)
    setFontSize(smallFont)
    var hrSin, hrCos : float
    sincos(-headingRad, hrSin, hrCos)
    let majorTickR = r * 0.88
    for i in range(36)
      let angleDeg = float(i) * 10.0
      var s, c : float
      sincos(angleDeg * degToRad, s, c)
      let lxIn  =  s * majorTickR
      let lyIn  = -c * majorTickR
      let lxOut =  s * r
      let lyOut = -c * r
      drawLine(ctr + float2(lxIn  * hrCos - lyIn  * hrSin, lxIn  * hrSin + lyIn  * hrCos),
               ctr + float2(lxOut * hrCos - lyOut * hrSin, lxOut * hrSin + lyOut * hrCos))
      if i % 3 == 0
        let hdg = (int(angleDeg) + 360) % 360
        let labelR = r * 0.70
        let lx =  s * labelR
        let ly = -c * labelR
        let lblStr = hdg == 0 ? "С" : (hdg == 90 ? "В" : (hdg == 180 ? "Ю" : (hdg == 270 ? "З" : "{hdg / 10}")))
        drawStrAnchored(ctr + float2(lx * hrCos - ly * hrSin, lx * hrSin + ly * hrCos),
                        lblStr, AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    // fixed heading index triangle at top (11)
    let triH = 0.015
    let triW = 0.009
    let triY = ctr.y - r - 0.006
    setFillColor(COLOR_WHITE)
    drawFilledPoly(to_array_move(fixed_array(
      float2(ctr.x, triY),
      float2(ctr.x - triW, triY - triH),
      float2(ctr.x + triW, triY - triH))))
    setFillColor(COLOR_NULL)
    // heading digital box
    let hdgDeg = norm_ang(headingRad) * radToDeg
    let hdg = roundi(hdgDeg) % 360
    let str = fmt(":03d", hdg)
    let boxPos = float2(ctr.x, triY - 0.025)
    let halfSz = getStringSize(str) * 0.5 + float2(0.018, 0.008)
    pushLocalAxes(boxPos, halfSz)
    setFillColor(COLOR_BLACK)
    drawBox(float2(-1.0), float2(1.0))
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    drawBox(float2(-1.0), float2(1.0))
    drawStrAnchored(float2(0.0), str, AnchorHorz.Center, AnchorVert.Center)
    popAxes()
    // cross
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    let bigR = 0.008
    let smallR = bigR * 0.85
    let circOff = 0.025
    drawCircle(ctr, bigR)
    drawCircle(ctr + float2(0.0, -circOff), smallR)
    drawCircle(ctr + float2(0.0,  circOff), smallR)
    drawCircle(ctr + float2(-circOff, 0.0), smallR)
    drawCircle(ctr + float2(circOff, 0.0), smallR)
    // cross lines
    drawLine(ctr + float2(0.0, -r * 0.5), ctr + float2(0.0, r * 0.5))
    drawLine(ctr + float2(-r * 0.5, 0.0), ctr + float2(r * 0.5, 0.0))


  // ── Sideslip indicator (9) ──
  def drawSideslip()
    let cy = COMPASS_CTR.y - COMPASS_R - 0.03 - 0.09  // поднято на 15%
    let hw = 0.05
    setColor(COLOR_WHITE)
    drawLine(float2(-hw, cy), float2(hw, cy))
    // ticks (2° each)
    for i in range(-4, 5)
      let x = float(i) * hw / 4.0
      let tl = (i == 0) ? 0.012 : 0.008
      drawLine(float2(x, cy), float2(x, cy + tl))
    // slip ball (triangle)
    let slipX = clamp(sideSlipDeg / 8.0, -1.0, 1.0) * hw
    let tw = 0.008
    let th = 0.012
    setFillColor(COLOR_WHITE)
    drawFilledPoly(to_array_move(fixed_array(
      float2(slipX, cy),
      float2(slipX - tw, cy - th),
      float2(slipX + tw, cy - th))))
    setFillColor(COLOR_NULL)


  // ── AOA arc (23) — left side, vertical, tight to horizon mask ──
  def drawAoaArc()
    let aoaRange = AOA_LIMITS.y - AOA_LIMITS.x
    let majorTick = 0.020
    let minorTick = 0.012
    let smallFont = int(float(fontSize) * 0.7)
    var sinA, cosA : float

    // draw arc line — red outside safe range, white inside
    let angMin      = calcAoaArcAngle(AOA_LIMITS.x)
    let angMax      = calcAoaArcAngle(AOA_LIMITS.y)
    let angSafeFrom = calcAoaArcAngle(AOA_SAFE_RANGE.x)
    let angSafeTo   = calcAoaArcAngle(AOA_SAFE_RANGE.y)
    setColor(COLOR_RED)
    drawSector(AOA_ARC_CTR, float2(AOA_ARC_R), float2(angMin, angSafeFrom))
    setColor(COLOR_WHITE)
    drawSector(AOA_ARC_CTR, float2(AOA_ARC_R), float2(angSafeFrom, angSafeTo))
    setColor(COLOR_RED)
    drawSector(AOA_ARC_CTR, float2(AOA_ARC_R), float2(angSafeTo, angMax))

    // max AoA label
    setColor(COLOR_WHITE)
    var sMax, cMax : float
    sincos(angMax, sMax, cMax)
    let maxLabelR = AOA_ARC_R + majorTick + 0.015
    setFontSize(smallFont)
    drawStrAnchored(AOA_ARC_CTR + float2(cMax * maxLabelR, sMax * maxLabelR),
                    "{int(AOA_LIMITS.y)}", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)

    // ticks — outward from arc, labels further out
    for i in 0..int(aoaRange) + 1
      let aoaVal = int(AOA_LIMITS.x) + i
      let angle = calcAoaArcAngle(float(aoaVal))
      sincos(angle, sinA, cosA)
      let isMajor = aoaVal % 5 == 0
      setColor(COLOR_WHITE)
      let tl = isMajor ? majorTick : minorTick
      let r1 = AOA_ARC_R + tl
      drawLine(AOA_ARC_CTR + float2(cosA * AOA_ARC_R, sinA * AOA_ARC_R),
               AOA_ARC_CTR + float2(cosA * r1, sinA * r1))
      if aoaVal % 10 == 0 && aoaVal > 0
        setFontSize(smallFont)
        let labelR = AOA_ARC_R + majorTick + 0.015
        drawStrAnchored(AOA_ARC_CTR + float2(cosA * labelR, sinA * labelR),
                        "{aoaVal}", AnchorHorz.Center, AnchorVert.Center)
        setFontSize(fontSize)

    // AOA pointer — white triangle, inside arc, pointing inward
    let pAngle = calcAoaArcAngle(aoaDeg)
    var pSin, pCos : float
    sincos(pAngle, pSin, pCos)
    let ptrTipR = AOA_ARC_R - 0.003
    let ptrBaseR = AOA_ARC_R - 0.025
    let ptrHW = 0.006
    let perpX = -pSin
    let perpY = pCos
    setColor(COLOR_WHITE)
    setFillColor(COLOR_WHITE)
    drawFilledPoly(to_array_move(fixed_array(
      AOA_ARC_CTR + float2(pCos * ptrTipR, pSin * ptrTipR),
      AOA_ARC_CTR + float2(pCos * ptrBaseR + perpX * ptrHW, pSin * ptrBaseR + perpY * ptrHW),
      AOA_ARC_CTR + float2(pCos * ptrBaseR - perpX * ptrHW, pSin * ptrBaseR - perpY * ptrHW))))
    setColor(COLOR_GREEN)
    setFillColor(COLOR_NULL)


  // ── Pitch arc (6 right side) ──
  def drawPitchArc()
    let cy = HOR_CY
    let scaleLen = 90.0
    // reversed arc — center shifted right, arc bulges LEFT toward horizon
    let arcRadius = ARC_R * 0.95  // 30% smaller
    let arcCx = ARC_R + arcRadius - 0.06
    let arcCtr = float2(arcCx, cy)
    let scaleRange = float2(degToRad * (180.0 - scaleLen * 0.5),
      degToRad * (180.0 + scaleLen * 0.5))
    setColor(COLOR_WHITE)
    // single arc line
    drawSector(arcCtr, float2(arcRadius), scaleRange)
    // end caps (ticks at ends)
    var sinBot, cosBot, sinTop, cosTop : float
    sincos(scaleRange.x, sinBot, cosBot)
    sincos(scaleRange.y, sinTop, cosTop)
    let capLen = 0.015
    drawLine(arcCtr + float2(cosBot * arcRadius, sinBot * arcRadius),
             arcCtr + float2(cosBot * (arcRadius - capLen), sinBot * (arcRadius - capLen)))
    drawLine(arcCtr + float2(cosTop * arcRadius, sinTop * arcRadius),
             arcCtr + float2(cosTop * (arcRadius - capLen), sinTop * (arcRadius - capLen)))
    // scale: -15 to 15, labels only at ±10, minor ticks -5..5, empty ticks at ±15
    let pitchMin = -15.0
    let pitchMax = 15.0
    let pitchRange = pitchMax - pitchMin
    let majorTick = 0.020
    let minorTick = 0.010
    var sinA, cosA : float
    let smallFont = int(float(fontSize) * 0.65)
    for i in 0..int(pitchRange) + 1
      let pitchVal = int(pitchMin) + i
      let t = float(i) / pitchRange
      let angle = lerp(scaleRange.x, scaleRange.y, t)
      sincos(angle, sinA, cosA)
      let isMajor = pitchVal % 5 == 0
      let inMinorZone = pitchVal >= -5 && pitchVal <= 5
      setColor(COLOR_WHITE)
      if isMajor || inMinorZone
        let tl = isMajor ? majorTick : minorTick
        let r0 = arcRadius
        let r1 = r0 - tl
        drawLine(arcCtr + float2(cosA * r0, sinA * r0),
                 arcCtr + float2(cosA * r1, sinA * r1))
      if pitchVal % 10 == 0 && abs(pitchVal) <= 10
        let labelR = arcRadius - majorTick - 0.012
        setFontSize(smallFont)
        drawStrAnchored(arcCtr + float2(cosA * labelR, sinA * labelR),
                        "{pitchVal}", AnchorHorz.Left, AnchorVert.Center)
        setFontSize(fontSize)
    // pitch pointer — arrow on concave side pointing left toward arc  ( <
    let clampedPitch = clamp(pitchDeg, pitchMin, pitchMax)
    let pT = (clampedPitch - pitchMin) / pitchRange
    let pAngle = lerp(scaleRange.x, scaleRange.y, pT)
    var pSin, pCos : float
    sincos(pAngle, pSin, pCos)
    let ptrTipR = arcRadius - majorTick - 0.003  // tip just past longest tick
    let ptrBaseR = arcRadius - majorTick - 0.055  // longer arrow
    let ptrHW = 0.0035  // 30% narrower base
    let perpX = -pSin
    let perpY = pCos
    setColor(COLOR_WHITE)
    setFillColor(COLOR_WHITE)
    drawFilledPoly(to_array_move(fixed_array(
      arcCtr + float2(pCos * ptrTipR, pSin * ptrTipR),
      arcCtr + float2(pCos * ptrBaseR + perpX * ptrHW, pSin * ptrBaseR + perpY * ptrHW),
      arcCtr + float2(pCos * ptrBaseR - perpX * ptrHW, pSin * ptrBaseR - perpY * ptrHW))))
    setColor(COLOR_GREEN)
    setFillColor(COLOR_NULL)


  // ── Round dial (generic) ──
  def drawRoundDial(ctr : float2; max_val : float; val : float;
                    scale : float; val2 : float = -1.0; max_val2 : float = -1.0;
                    dispVal : float = -1.0; innerRingScale : float = -1.0)
    let dr      = DIAL_R * scale
    let tick    = 0.020 * scale
    let lblOff  = 0.040 * scale
    let minTick = 0.010 * scale
    let halfW   = 0.045 * scale
    let halfH   = 0.018 * scale
    setColor(COLOR_WHITE)
    setFillColor(COLOR_BLACK)
    drawCircle(ctr, dr)
    setFillColor(COLOR_NULL)
    var sina, cosa : float
    let smallFont = int(float(fontSize) * 0.75)
    setFontSize(smallFont)
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
    // inner ring for altitude
    if innerRingScale > 0.0
      let irR    = dr * innerRingScale
      let irTick = 0.010 * scale
      drawCircle(ctr, irR)
      for i in 0..10
        let angle = float(i) * TWOPI / 10.0 - PI_2
        sincos(angle, sina, cosa)
        drawLine(ctr + float2(cosa * (irR - irTick), sina * (irR - irTick)),
                 ctr + float2(cosa * irR,             sina * irR))
    // main needle
    let needleAngle = clamp(val, 0.0, max_val) / max_val * TWOPI - PI_2
    sincos(needleAngle, sina, cosa)
    let ndlTipR  = dr * 0.72
    let ndlBaseR = -(dr * 0.08)
    let ndlTailR = -(dr * 0.14)
    let ndlHwBase = 0.008 * scale
    let ndlHwTail = 0.004 * scale
    let perpX = -sina
    let perpY =  cosa
    setFillColor(COLOR_WHITE)
    drawFilledPolyOutlined(to_array_move(fixed_array(
      ctr + float2(cosa * ndlTipR,                        sina * ndlTipR),
      ctr + float2(cosa * ndlBaseR - perpX * ndlHwBase,   sina * ndlBaseR - perpY * ndlHwBase),
      ctr + float2(cosa * ndlTailR - perpX * ndlHwTail,   sina * ndlTailR - perpY * ndlHwTail),
      ctr + float2(cosa * ndlTailR + perpX * ndlHwTail,   sina * ndlTailR + perpY * ndlHwTail),
      ctr + float2(cosa * ndlBaseR + perpX * ndlHwBase,   sina * ndlBaseR + perpY * ndlHwBase))))
    setFillColor(COLOR_NULL)
    // second needle (thin, for altitude x10000)
    if max_val2 > 0.0
      let needleAngle2 = clamp(val2, 0.0, max_val2) / max_val2 * TWOPI - PI_2
      var s2, c2 : float
      sincos(needleAngle2, s2, c2)
      let px2 = -s2
      let py2 =  c2
      let tip2R = ndlTipR * 0.55
      setFillColor(COLOR_WHITE)
      drawFilledPolyOutlined(to_array_move(fixed_array(
        ctr + float2(c2 * tip2R,                       s2 * tip2R),
        ctr + float2(c2 * ndlBaseR - px2 * ndlHwBase,  s2 * ndlBaseR - py2 * ndlHwBase),
        ctr + float2(c2 * ndlTailR - px2 * ndlHwTail,  s2 * ndlTailR - py2 * ndlHwTail),
        ctr + float2(c2 * ndlTailR + px2 * ndlHwTail,  s2 * ndlTailR + py2 * ndlHwTail),
        ctr + float2(c2 * ndlBaseR + px2 * ndlHwBase,  s2 * ndlBaseR + py2 * ndlHwBase))))
      setFillColor(COLOR_NULL)
    drawCircle(ctr, 0.005 * scale)
    // digital value box
    let displayValue = int(dispVal >= 0.0 ? dispVal : val)
    let valStr = "{displayValue}"
    let valBoxCtr = ctr + float2(0.0, -0.036 * scale)
    setFillColor(COLOR_BLACK)
    drawBox(valBoxCtr - float2(halfW, halfH), valBoxCtr + float2(halfW, halfH))
    setFillColor(COLOR_NULL)
    drawBox(valBoxCtr - float2(halfW, halfH), valBoxCtr + float2(halfW, halfH))
    drawStrAnchored(valBoxCtr, valStr, AnchorHorz.Center, AnchorVert.Center)


  // ── Speed dial (19-22) ──
  def drawSpdDial()
    let ctr = SPD_CTR
    let scale = DIAL_SCALE * 1.3
    let max_val = 1000.0
    let val = iasMps * MPS_TO_KPH
    let dr      = DIAL_R * scale
    let tick    = 0.020 * scale
    let lblOff  = 0.040 * scale
    let minTick = 0.010 * scale
    let halfW   = 0.045 * scale
    let halfH   = 0.018 * scale
    var sina, cosa : float
    setColor(COLOR_WHITE)
    setFillColor(COLOR_BLACK)
    drawCircle(ctr, dr)
    setFillColor(COLOR_NULL)
    let smallFont = int(float(fontSize) * 0.75)
    setFontSize(smallFont)
    for i in 0..10
      let angle = float(i) * TWOPI / 10.0 - PI_2
      sincos(angle, sina, cosa)
      let r1 = dr - tick
      drawLine(ctr + float2(cosa * r1, sina * r1),
               ctr + float2(cosa * dr, sina * dr))
      let labelR = dr - lblOff
      drawStrAnchored(ctr + float2(cosa * labelR, sina * labelR),
                      "{i}", AnchorHorz.Center, AnchorVert.Center)
      if i < 4
        for j in 1..5
          let minorAngle = angle + float(j) * TWOPI / 50.0
          sincos(minorAngle, sina, cosa)
          let mr1 = dr - minTick
          drawLine(ctr + float2(cosa * mr1, sina * mr1),
                   ctr + float2(cosa * dr,  sina * dr))
    setFontSize(fontSize)
    // main needle
    let needleAngle = clamp(val, 0.0, max_val) / max_val * TWOPI - PI_2
    sincos(needleAngle, sina, cosa)
    let ndlTipR  = dr * 0.72
    let ndlBaseR = -(dr * 0.08)
    let ndlTailR = -(dr * 0.14)
    let ndlHwBase = 0.008 * scale
    let ndlHwTail = 0.004 * scale
    let perpX = -sina
    let perpY =  cosa
    setFillColor(COLOR_WHITE)
    drawFilledPolyOutlined(to_array_move(fixed_array(
      ctr + float2(cosa * ndlTipR,                        sina * ndlTipR),
      ctr + float2(cosa * ndlBaseR - perpX * ndlHwBase,   sina * ndlBaseR - perpY * ndlHwBase),
      ctr + float2(cosa * ndlTailR - perpX * ndlHwTail,   sina * ndlTailR - perpY * ndlHwTail),
      ctr + float2(cosa * ndlTailR + perpX * ndlHwTail,   sina * ndlTailR + perpY * ndlHwTail),
      ctr + float2(cosa * ndlBaseR + perpX * ndlHwBase,   sina * ndlBaseR + perpY * ndlHwBase))))
    setFillColor(COLOR_NULL)
    drawCircle(ctr, 0.005 * scale)
    // digital value box
    let displayValue = int(val)
    let valStr = "{displayValue}"
    let valBoxCtr = ctr + float2(0.0, -0.036 * scale)
    setFillColor(COLOR_BLACK)
    drawBox(valBoxCtr - float2(halfW, halfH), valBoxCtr + float2(halfW, halfH))
    setFillColor(COLOR_NULL)
    drawBox(valBoxCtr - float2(halfW, halfH), valBoxCtr + float2(halfW, halfH))
    drawStrAnchored(valBoxCtr, valStr, AnchorHorz.Center, AnchorVert.Center)
    // Mach digital boxes inside dial (28)
    let machFont = int(float(fontSize) * 0.55)
    setFontSize(machFont)
    let boxY = ctr.y + dr * 0.15
    let boxHW = 0.028
    let boxHH = 0.012
    setFillColor(COLOR_BLACK)
    drawBox(float2(ctr.x - boxHW * 2.0 - 0.002, boxY - boxHH), float2(ctr.x - 0.002, boxY + boxHH))
    setFillColor(COLOR_NULL)
    drawBox(float2(ctr.x - boxHW * 2.0 - 0.002, boxY - boxHH), float2(ctr.x - 0.002, boxY + boxHH))
    drawStrAnchored(float2(ctr.x - boxHW - 0.002, boxY), "{fmt(":.1f", machNum)}", AnchorHorz.Center, AnchorVert.Center)
    setFillColor(COLOR_BLACK)
    drawBox(float2(ctr.x + 0.002, boxY - boxHH), float2(ctr.x + boxHW * 2.0 + 0.002, boxY + boxHH))
    setFillColor(COLOR_NULL)
    drawBox(float2(ctr.x + 0.002, boxY - boxHH), float2(ctr.x + boxHW * 2.0 + 0.002, boxY + boxHH))
    drawStrAnchored(float2(ctr.x + boxHW + 0.002, boxY), "{fmt(":.1f", machNum + 0.1)}", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  // ── Altitude dial (15-18) with inner ring and geom alt arc ──
  def drawAltDial()
    drawRoundDial(ALT_CTR, 1000.0, altM % 1000.0, DIAL_SCALE * 1.30, altM, 10000.0, altM)
    // geometric altitude arc (15б) in yellow
    let dr = DIAL_R * DIAL_SCALE * 1.30
    let geomNorm = clamp(altGeomM / 10000.0, 0.0, 1.0)
    let arcAngle = geomNorm * TWOPI
    if arcAngle > 0.01
      setColor(COLOR_YELLOW)
      let arcStart = -PI_2
      drawSector(ALT_CTR, float2(dr + 0.008), float2(arcStart, arcStart + arcAngle))
      // geom alt pointer triangle
      var gs, gc : float
      sincos(arcStart + arcAngle, gs, gc)
      let ptrR = dr + 0.016
      setFillColor(COLOR_YELLOW)
      drawFilledPoly(to_array_move(fixed_array(
        ALT_CTR + float2(gc * ptrR, gs * ptrR),
        ALT_CTR + float2(gc * (ptrR + 0.012) - gs * 0.006, gs * (ptrR + 0.012) + gc * 0.006),
        ALT_CTR + float2(gc * (ptrR + 0.012) + gs * 0.006, gs * (ptrR + 0.012) - gc * 0.006))))
      setFillColor(COLOR_NULL)
    setColor(COLOR_WHITE)
    // geom alt digital readout in yellow box inside dial (18)
    let smallFont = int(float(fontSize) * 0.55)
    setFontSize(smallFont)
    setColor(COLOR_YELLOW)
    let geomBoxCtr = ALT_CTR + float2(0.0, dr * 0.15)
    let geomBoxHW = 0.035
    let geomBoxHH = 0.012
    setFillColor(COLOR_BLACK)
    drawBox(geomBoxCtr - float2(geomBoxHW, geomBoxHH), geomBoxCtr + float2(geomBoxHW, geomBoxHH))
    setFillColor(COLOR_NULL)
    drawBox(geomBoxCtr - float2(geomBoxHW, geomBoxHH), geomBoxCtr + float2(geomBoxHW, geomBoxHH))
    drawStrAnchored(geomBoxCtr, "{int(altGeomM)}", AnchorHorz.Center, AnchorVert.Center)
    setColor(COLOR_WHITE)
    setFontSize(fontSize)


  // ── Engine RPM bars (31) ──
  def drawRpmBars()
    let smallFont = int(float(fontSize) * 0.65)
    setFontSize(smallFont)
    setColor(COLOR_WHITE)
    let gap = 0.035
    let lx = RPM_X - gap * 0.5
    let rx = RPM_X + gap * 0.5
    let cx = RPM_X
    let tickW = 0.015
    // left vertical line + ticks left
    drawLine(float2(lx, RPM_Y0), float2(lx, RPM_Y1))
    // right vertical line + ticks right
    drawLine(float2(rx, RPM_Y0), float2(rx, RPM_Y1))
    for ti in range(5)
      let pctVal = 60 + ti * 10
      let t = float(pctVal - 60) / 40.0
      let ty = RPM_Y1 - t * (RPM_Y1 - RPM_Y0)
      let tw = (pctVal % 20 == 0) ? tickW : tickW * 0.6
      // left line — ticks go left
      drawLine(float2(lx, ty), float2(lx - tw, ty))
      // right line — ticks go right
      drawLine(float2(rx, ty), float2(rx + tw, ty))
    // fill bars
    let barW = 0.004
    setFillColor(COLOR_WHITE)
    let fillTL = clamp((rpmL - 60.0) / 40.0, 0.0, 1.0)
    let fillYL = RPM_Y1 - fillTL * (RPM_Y1 - RPM_Y0)
    drawBox(float2(lx - barW, fillYL), float2(lx + barW, RPM_Y1))
    let fillTR = clamp((rpmR - 60.0) / 40.0, 0.0, 1.0)
    let fillYR = RPM_Y1 - fillTR * (RPM_Y1 - RPM_Y0)
    drawBox(float2(rx - barW, fillYR), float2(rx + barW, RPM_Y1))
    setFillColor(COLOR_NULL)
    // %
    drawStrAnchored(float2(cx, RPM_Y0 - 0.015), "%", AnchorHorz.Center, AnchorVert.Center)
    // scale labels
    let labelFont = int(float(fontSize) * 0.5)
    setFontSize(labelFont)
    for ti in range(5)
      let pctVal = 60 + ti * 10
      let t = float(pctVal - 60) / 40.0
      let ty = RPM_Y1 - t * (RPM_Y1 - RPM_Y0)
      drawStrAnchored(float2(cx, ty), "{pctVal}", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  // ── G-force indicator (24) — left column, top ──
  def drawGForce()
    let smallFont = int(float(fontSize) * 0.65)
    setFontSize(smallFont)
    setColor(COLOR_WHITE)
    // vertical bar line
    drawLine(float2(GSCALE_BAR_X, calcGScaleY(GSCALE_UPPER_MAX)), float2(GSCALE_BAR_X, calcGScaleY(GSCALE_UPPER_MIN)))
    // upper scale ticks: -2 to +10, every 1g
    for i in range(GSCALE_UPPER_TICKS + 1)
      let gVal = GSCALE_UPPER_MIN + float(i)
      let ty = calcGScaleY(gVal)
      let tw = (int(gVal) % 2 == 0) ? 0.015 : 0.008
      drawLine(float2(GSCALE_BAR_X, ty), float2(GSCALE_BAR_X + tw, ty))
      if int(gVal) % 2 == 0
        drawStrAnchored(float2(GSCALE_BAR_X + 0.018, ty), "{int(gVal)}", AnchorHorz.Left, AnchorVert.Center)

    drawStrAnchored(float2(GSCALE_BAR_X + 0.018, calcGScaleY(GSCALE_LOWER_MIN)), "{int(GSCALE_LOWER_MIN)}", AnchorHorz.Left, AnchorVert.Center)

    // red zone: 6 to 10
    setColor(COLOR_RED)
    drawLine(float2(GSCALE_BAR_X, calcGScaleY(6.0)), float2(GSCALE_BAR_X, calcGScaleY(GSCALE_UPPER_MAX)))
    // lower scale: -2 to -10 (red), marks at -6 and -10
    drawLine(float2(GSCALE_BAR_X, calcGScaleY(GSCALE_UPPER_MIN)), float2(GSCALE_BAR_X, calcGScaleY(GSCALE_LOWER_MIN)))
    let lowerMarks = fixed_array(-6.0, GSCALE_LOWER_MIN)
    for i in range(length(lowerMarks))
      let gVal = lowerMarks[i]
      let ty = calcGScaleY(gVal)
      let tw = (abs(int(gVal)) % 10 == 0) ? 0.015 : 0.008
      drawLine(float2(GSCALE_BAR_X, ty), float2(GSCALE_BAR_X + tw, ty))

    // pointer
    let nyY = calcGScaleY(nyG)
    setFillColor(COLOR_WHITE)
    setColor(COLOR_WHITE)
    drawFilledPoly(to_array_move(fixed_array(
      float2(GSCALE_BAR_X, nyY),
      float2(GSCALE_BAR_X - 0.012, nyY - 0.006),
      float2(GSCALE_BAR_X - 0.012, nyY + 0.006))))
    setFillColor(COLOR_NULL)
    setFontSize(fontSize)


  // ── Vertical speed indicator (25) — right side ──
  def drawVerticalSpeed()
    let smallFont = int(float(fontSize) * 0.65)
    setFontSize(smallFont)
    setColor(COLOR_WHITE)
    let vyStr = "{fmt(":+.0f", vyMps)}"
    drawStrAnchored(float2(0.34, -0.37), vyStr, AnchorHorz.Right, AnchorVert.Top)
    setFontSize(fontSize)



  // ── Side labels (outside border, vertical text) ──
  // ── Bottom bar labels ──
  def drawBottomBar()
    let smallFont = int(float(fontSize) * 0.7)
    setFontSize(smallFont)
    setColor(COLOR_GREEN)
    drawStrAnchored(float2(-0.12, 0.475), "ПИЛ2", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.12, 0.475), "БАСК", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  def draw()
    return if !isValid
    setFullCanvasViewport()

    drawBackground()
    drawBorder()
    drawTopBar()
    drawAviaHorizont()
    drawAoaArc()
    drawPitchArc()
    drawCompassDial()
    drawSideslip()
    drawSpdDial()
    drawAltDial()
    drawRpmBars()
    drawGForce()
    drawVerticalSpeed()
    drawBottomBar()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; var props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId   = getInt(props, "fontId", 0)
  propStorage.fontSize = getInt(props, "fontSize", 20)
  propStorage.horMask  = getPicture(props, "horMask")
