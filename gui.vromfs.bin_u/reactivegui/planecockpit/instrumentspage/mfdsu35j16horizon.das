require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require app
require DagorDataBlock
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
  fontId : int
  fontSize : int = 16
  chinaLang : bool = false
  altDevImage : Picture?
  spdDevImage : Picture?
  varioDevImage : Picture?
  horMask : Picture?

let
  COLOR_BLACK       = E3DCOLOR(uint4(0, 0, 0, 255))
  COLOR_WHITE       = E3DCOLOR(uint4(255, 255, 255, 255))
  COLOR_YELLOW      = E3DCOLOR(uint4(255, 255, 48, 255))
  COLOR_RED         = E3DCOLOR(uint4(255, 7, 0, 255))
  COLOR_GREEN       = E3DCOLOR(uint4(55, 255, 55, 255))
  COLOR_CYAN        = E3DCOLOR(uint4(0, 200, 200, 255))
  COLOR_NULL        = E3DCOLOR(0x0)
  COLOR_SKY         = E3DCOLOR(uint4(0, 200, 204, 255))
  COLOR_GROUND      = E3DCOLOR(uint4(170, 36, 24, 255))

  MID_Y = 0.55

class Component : Canvas
  isValid      : bool             = false
  hero         : Unit?            = null
  fmw          : FlightModelWrap? = null
  fm           : FlightModel?     = null
  propulsion   : Propulsion?      = null
  app          : AcesApp?         = null

  pitchDeg     : float = 0.0
  rollDeg      : float = 0.0
  headingDeg   : float = 0.0
  iasMps       : float = 0.0
  tasMps       : float = 0.0
  altM         : float = 0.0
  altBaroM     : float = 0.0
  vertSpd      : float = 0.0
  machNum      : float = 0.0
  overloadG    : float = 1.0

  gearPos      : float = 0.0
  flapsPos     : float = 0.0
  airBrakePos  : float = 0.0

  rpm1         : float = 0.0
  rpm2         : float = 0.0
  egt1         : float = 0.0
  egt2         : float = 0.0

  fontSize     : int = 16
  curTime      : float = 0.0
  aspect       : float = 1.0
  xHalf        : float = 0.5
  isChina      : bool = false

  altDevImage   : Picture?
  spdDevImage   : Picture?
  varioDevImage : Picture?
  horMask       : Picture?

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
                rstate : RenderState& const; var props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    if hero == null
      return
    fmw = hero.as_fmw()
    if fmw == null
      return
    fm = fmw.fm
    if fm == null
      return
    app = get_app()
    if app == null
      return
    propulsion = fm.EI
    isValid = true
    fontSize = props.fontSize
    curTime = get_sync_time()

    isChina = props.chinaLang
    altDevImage = props.altDevImage
    spdDevImage = props.spdDevImage
    varioDevImage = props.varioDevImage
    horMask = props.horMask

    // Flight data
    pitchDeg   = fmw.tangage
    rollDeg    = fmw.roll
    let fwd = hero.unitTm[0]
    headingDeg = norm_ang(2.0 * PI + atan2(fwd.x, fwd.z)) * radToDeg
    iasMps     = fmw.ias
    tasMps     = hero.speed
    altM       = hero.unitTm[3].y - app.currentScene.waterLevel
    altBaroM   = fmw.fm.input.currentAlt
    vertSpd    = fmw.fm.vertSpeed
    machNum    = fmw.fm.cache.Mach
    overloadG  = fmw.fm.localAccel.length() / 9.81

    // Mechanization
    gearPos     = fm.appliedCT.gear
    flapsPos    = fm.appliedCT.flaps
    airBrakePos = fm.appliedCT.airBrake

    // Engine data
    if propulsion != null
      if propulsion.numEngines > 0
        propulsion_getEngine(*propulsion, 0) <| $(eng)
          rpm1 = eng.omegaRel
          egt1 = eng.waterTemp + zeroKelvinInCelsium
      if propulsion.numEngines > 1
        propulsion_getEngine(*propulsion, 1) <| $(eng)
          rpm2 = eng.omegaRel
          egt2 = eng.waterTemp + zeroKelvinInCelsium

    aspect = canvasSize.x / canvasSize.y
    xHalf = aspect * 0.5
    setColor(COLOR_WHITE)
    setLineWidth(1.0)
    setFont(props.fontId)
    setFontSize(fontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))


  def draw()
    return if !isValid
    setFullCanvasViewport()

    // Background
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(float2(-xHalf, -0.5), float2(xHalf, 0.5))
    setFillColor(COLOR_NULL)

    // Divider lines
    setColor(COLOR_WHITE)
    setLineWidth(1.5)
    drawLine(float2(0.0, -0.5), float2(0.0, 0.5))
    let midY = MID_Y - 0.5
    drawLine(float2(0.0, midY), float2(xHalf, midY))
    setLineWidth(1.0)

    drawLeftHalf()
    drawEngineBlock()
    drawMechBlock()

    restoreViewport()


  // =====================================================================
  //  LEFT HALF — port of mfdSu30devices.das onto Canvas API
  //  All coordinates inside pushLocalAxes are 0..1 relative
  // =====================================================================
  def drawLeftHalf()
    // Left half in non-square local axes: X spans xHalf, Y spans 1.0
    // ax = aspect ratio inside left half = xHalf / 1.0
    let ax = xHalf
    pushLocalAxes(float2(-xHalf, -0.5), float2(ax, 1.0))

    // For square instruments, use sz.x = sz.y * (1.0 / ax) to compensate
    let sq = 1.0 / ax  // X multiplier to make squares

    // Base sizes from su30Devices, scaled down to fit left half
    let s = 0.80  // overall scale-down factor
    let hs = s * sq  // horizontal size with aspect correction

    drawSu30Compass(float2(0.5, 0.04))
    drawSu30Overload(float2(0.05, 0.10), float2(0.05 * sq, 0.45))
    let horPos = float2(0.50 - 0.25 * hs, 0.14)
    let horSz = float2(0.50 * hs, 0.50 * s)
    let horOriginY = horPos.y + horSz.y * 0.5
    let horRightX = horPos.x + horSz.x
    drawSu30Horizont(horPos, horSz)
    drawSu30Climb(float2(horRightX - 0.27, horOriginY - 0.01), float2(0.30 * hs, 0.30 * s))
    drawSu30Vario(float2(0.78, horOriginY - 0.09), float2(0.18 * sq, 0.18))
    let devSz = float2(0.255 * sq, 0.255)
    drawSu30SpeedDevice(float2(0.07, 0.53), devSz)   // left instrument
    drawSu30AltDevice(float2(0.93 - devSz.x, 0.53), devSz)  // right instrument
    // HSI compass between the two instruments, same size
    let hsiX = 0.50 - devSz.x * 0.5  // centered
    drawHsi(float2(hsiX, 0.73), devSz)
    drawSu30Heights()
    drawSu30Speeds()

    popAxes()


  // --- Compass strip ---
  def drawSu30Compass(ctr : float2)
    setColor(COLOR_GREEN)
    setFontSize(fontSize)
    let stripHW = 0.20
    for i in range(-4, 5)
      let markVal = (int(headingDeg) / 5) * 5 + i * 5
      let markX = ctr.x + (float(markVal) - headingDeg) * 0.008
      if markX < ctr.x - stripHW || markX > ctr.x + stripHW
        continue
      let tickTop = ctr.y + (markVal % 10 == 0 ? 0.003 : 0.009)
      drawLine(float2(markX, tickTop), float2(markX, ctr.y + 0.015))
      if markVal % 10 == 0
        let hdgVal = ((markVal % 360) + 360) % 360
        drawStrAnchored(float2(markX, ctr.y), "{hdgVal / 10}", AnchorHorz.Center, AnchorVert.Bottom)
    drawLine(float2(ctr.x - stripHW, ctr.y + 0.015), float2(ctr.x + stripHW, ctr.y + 0.015))
    setColor(COLOR_WHITE)
    setFillColor(COLOR_WHITE)
    drawFilledPoly([float2(ctr.x - 0.010, ctr.y + 0.030), float2(ctr.x, ctr.y + 0.015), float2(ctr.x + 0.010, ctr.y + 0.030)])
    setFillColor(COLOR_NULL)


  // --- G-overload scale ---
  def drawSu30Overload(pos : float2; sz : float2)
    let scaleX = pos.x + sz.x
    setFontSize(int(float(fontSize) * 0.85))
    setColor(COLOR_GREEN)
    for i in range(12)
      let tickLen = (i % 2 > 0 ? 0.10 : 0.20) * sz.x
      let yPos = pos.y + sz.y * (float(i) * 0.075 + 0.1)
      drawLine(float2(scaleX - tickLen, yPos), float2(scaleX + tickLen, yPos))
      if i % 2 > 0 && i < 10
        drawStrAnchored(float2(scaleX - tickLen - 0.008, yPos), "{10 - i}", AnchorHorz.Right, AnchorVert.Center)

    // Green center / red edges
    setLineWidth(2.0)
    setColor(COLOR_GREEN)
    drawLine(float2(scaleX, pos.y + sz.y * 0.625), float2(scaleX, pos.y + sz.y * 0.8))
    setColor(COLOR_RED)
    drawLine(float2(scaleX, pos.y), float2(scaleX, pos.y + sz.y * 0.625))
    drawLine(float2(scaleX, pos.y + sz.y * 0.8), float2(scaleX, pos.y + sz.y))
    setLineWidth(1.0)

    // Pointer
    let curY = pos.y + sz.y * (0.7 - overloadG * 0.075)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_WHITE)
    drawFilledPoly([float2(scaleX, curY), float2(scaleX - sz.x * 0.3, curY - sz.y * 0.02), float2(scaleX - sz.x * 0.3, curY + sz.y * 0.02)])
    setFillColor(COLOR_NULL)
    setFontSize(fontSize)


  // --- Aviation horizon ---
  def drawSu30Horizont(pos : float2; sz : float2)
    let origin = pos + sz * 0.5
    // Expand fill area to cover up to the mask/arc edges
    let pad = float2(sz.x * 0.01, sz.y * 0.017)
    let fPos = pos - pad
    let fSz = sz + pad * 2.0
    let horLevel = fPos.y + fSz.y * cvt(pitchDeg, -30.0, 30.0, 0.0, 1.0)

    setViewport(fPos, fPos + fSz)

    // Sky / ground
    setColor(COLOR_SKY)
    setFillColor(COLOR_SKY)
    drawBox(fPos, float2(fPos.x + fSz.x, horLevel))
    setColor(COLOR_GROUND)
    setFillColor(COLOR_GROUND)
    drawBox(float2(fPos.x, horLevel), fPos + fSz)

    // Pitch marks
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    setFontSize(int(float(fontSize) * 0.85))
    for i in range(-5, 7)
      let markVal = (int(pitchDeg) / 5) * 5 + i * 5
      let posY = origin.y + (pitchDeg - float(markVal)) * 0.01667 * sz.y
      if markVal == 0
        drawLine(float2(pos.x, posY), float2(pos.x + sz.x, posY))
      elif abs(markVal % 10) > 0
        drawLine(float2(origin.x - sz.x * 0.05, posY), float2(origin.x + sz.x * 0.05, posY))
      else
        drawLine(float2(origin.x - sz.x * 0.15, posY), float2(origin.x - sz.x * 0.05, posY))
        drawLine(float2(origin.x + sz.x * 0.05, posY), float2(origin.x + sz.x * 0.15, posY))
        // Elbows
        let elbowDir = sign(float(markVal)) * sz.y * 0.03
        drawLine(float2(origin.x - sz.x * 0.15, posY), float2(origin.x - sz.x * 0.15, posY + elbowDir))
        drawLine(float2(origin.x + sz.x * 0.15, posY), float2(origin.x + sz.x * 0.15, posY + elbowDir))
        drawStrAnchored(float2(origin.x, posY), "{abs(markVal)}", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)

    // Aircraft symbol (rotates with roll)
    setRotation(origin, rollDeg * degToRad)
    setColor(COLOR_BLACK)
    setLineWidth(2.5)
    // Left wing
    drawPolyLine([origin - float2(sz.x * 0.49, 0.0), origin - float2(sz.x * 0.15, 0.0),
                  origin - float2(sz.x * 0.125, -sz.y * 0.05), origin - float2(sz.x * 0.10, 0.0),
                  origin - float2(sz.x * 0.03, 0.0)])
    // Right wing
    drawPolyLine([origin + float2(sz.x * 0.49, 0.0), origin + float2(sz.x * 0.15, 0.0),
                  origin + float2(sz.x * 0.125, sz.y * 0.05), origin + float2(sz.x * 0.10, 0.0),
                  origin + float2(sz.x * 0.03, 0.0)])
    // Tail
    drawLine(origin - float2(0.0, sz.y * 0.08), origin - float2(0.0, sz.y * 0.16))
    // Center dot
    setFillColor(COLOR_BLACK)
    drawCircle(origin, sz.y * 0.015)
    setFillColor(COLOR_NULL)
    setLineWidth(1.0)
    resetViewTm()

    // Horizon mask texture — covers horizon edges
    let maskPad = float2(sz.x * 0.02, sz.y * 0.02)
    drawPicture(pos - maskPad, sz + maskPad * 2.0, horMask)

    restoreViewport()

    // Bank arcs — match enlarged mask exactly
    let mSz = sz + maskPad * 2.0
    let arcR = mSz * 0.5
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    drawSector(origin, arcR, float2(-PI * 0.847, -PI * 0.153))
    drawSector(origin, arcR, float2(PI * 0.15, PI * 0.846))

    // Side vertical bars — at mask edge
    let mLeft = pos.x - maskPad.x
    setLineWidth(1.5)
    drawLine(float2(mLeft + mSz.x * 0.06, origin.y - mSz.y * 0.23), float2(mLeft + mSz.x * 0.06, origin.y + mSz.y * 0.23))
    drawLine(float2(mLeft + mSz.x * 0.94, origin.y - mSz.y * 0.23), float2(mLeft + mSz.x * 0.94, origin.y + mSz.y * 0.23))
    setLineWidth(1.0)

    // Side arrows
    setFillColor(COLOR_WHITE)
    drawFilledPoly([origin - float2(arcR.x, sz.y * 0.03), origin - float2(arcR.x - mSz.x * 0.05, 0.0), origin - float2(arcR.x, -sz.y * 0.03)])
    drawFilledPoly([origin + float2(arcR.x, sz.y * 0.03), origin + float2(arcR.x - mSz.x * 0.05, 0.0), origin + float2(arcR.x, -sz.y * 0.03)])
    setFillColor(COLOR_NULL)

    // Roll reference marks — along the inner edge of the bank arcs
    setColor(COLOR_WHITE)
    setLineWidth(1.5)
    let tickLong = 0.025
    let tickShort = 0.015
    // Marks at: 10, 20, 30, 45, 60 degrees on each side (bottom half of circle)
    let markAngles = fixed_array(10.0, 20.0, 30.0, 45.0, 60.0)
    for mi in range(5)
      let angleM = markAngles[mi]
      let tickLen = (angleM == 30.0 || angleM == 60.0) ? tickLong : tickShort
      for side in range(2)
        let signF = side == 0 ? 1.0 : -1.0
        // Angle from bottom: 90 + angleM on the circle
        let a = (90.0 + signF * angleM) * degToRad
        var sn, cs : float
        sincos(a, sn, cs)
        // Outer point on the arc, inner point towards center
        let outerPt = origin + float2(cs * arcR.x, sn * arcR.y)
        let innerPt = origin + float2(cs * (arcR.x - tickLen), sn * (arcR.y - tickLen))
        drawLine(outerPt, innerPt)

        if angleM == 30.0 || angleM == 60.0
          let lbl = "{int(90.0 - angleM)}"
          let lblPt = origin + float2(cs * (arcR.x - tickLen - 0.015), sn * (arcR.y - tickLen - 0.015))
          setFontSize(int(float(fontSize) * 0.7))
          drawStrAnchored(lblPt, lbl, AnchorHorz.Center, AnchorVert.Center)
          setFontSize(fontSize)
    setLineWidth(1.0)


  // --- Climb arc ---
  def drawSu30Climb(ctr : float2; sz : float2)
    // Arc on LEFT side: from ~7:30 (bottom-left) up to 12:00 (top)
    // Screen coords: Y down. drawSector angles: 0=right, PI/2=down, PI=left, 3PI/2=up
    // 12 o'clock (top)     = -PI/2  (or 3*PI/2)
    //  9 o'clock (left)    = PI
    //  7:30 (bottom-left)  = PI + PI/4 = PI*1.25
    //
    // Pitch mapping: 0deg at 9 o'clock (PI), +40 toward 12 o'clock, -10 toward 7:30
    let minDeg = -10.0
    let maxDeg = 40.0
    // arcAngle for pitch deg: PI + deg * (PI*0.25 / 10) for negative, PI - deg * (PI*0.5 / 40) for positive
    // Simpler: linearly map minDeg..maxDeg -> arcBottom..arcTop
    let arcTop = PI * 1.52                  // just before 12 o'clock, shifted up
    let arcBot = PI * 0.917                 // ~20:30 (8:30 clock position)
    // 0deg at PI (9 o'clock). -10..0 maps to arcBot..PI, 0..+40 maps to PI..arcTop
    let negSpan = PI - arcBot        // radians for -10..0
    let posSpan = arcTop - PI        // radians for 0..+40

    setColor(COLOR_GREEN)
    drawSector(ctr, sz, float2(arcBot, arcTop))

    // Tick marks: evenly distributed, 0deg at 9 o'clock
    setFontSize(int(float(fontSize) * 0.7))
    for i in range(11)
      let deg = minDeg + float(i) * 5.0
      var angle = 0.0
      if deg <= 0.0
        angle = PI + deg * (negSpan / 10.0)
      else
        angle = PI + deg * (posSpan / 40.0)
      var sn, cs : float
      sincos(angle, sn, cs)
      let isMajor = int(abs(deg)) % 10 == 0
      let tickR = isMajor ? 0.94 : 0.97
      let outP = ctr + float2(cs * sz.x, sn * sz.y)
      let inP = ctr + float2(cs * sz.x * tickR, sn * sz.y * tickR)
      drawLine(outP, inP)

      if isMajor
        let lblPt = ctr + float2(cs * sz.x * 0.88, sn * sz.y * 0.88)
        drawStrAnchored(lblPt, "{int(deg)}", AnchorHorz.Center, AnchorVert.Center)

    setFontSize(fontSize)

    // Red danger zone at top (high AOA, above 35deg)
    setColor(COLOR_RED)
    let redAngle = PI + 35.0 * (posSpan / 40.0)
    drawSector(ctr, sz + float2(0.002), float2(redAngle, arcTop))

    // Pointer
    let clampedT = clamp(pitchDeg, minDeg, maxDeg)
    var ptrAngle = 0.0
    if clampedT <= 0.0
      ptrAngle = PI + clampedT * (negSpan / 10.0)
    else
      ptrAngle = PI + clampedT * (posSpan / 40.0)
    var pSn, pCs : float
    sincos(ptrAngle, pSn, pCs)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_WHITE)
    let pOuter = ctr + float2(pCs * sz.x, pSn * sz.y)
    let pLen = 0.012
    let tX = -pSn
    let tY = pCs
    drawFilledPoly([pOuter,
                    pOuter - float2(pCs * pLen * 2.5 + tX * pLen, pSn * pLen * 2.5 + tY * pLen),
                    pOuter - float2(pCs * pLen * 2.5 - tX * pLen, pSn * pLen * 2.5 - tY * pLen)])
    setFillColor(COLOR_NULL)


  // --- Variometer ---
  def drawSu30Vario(pos : float2; sz : float2)
    drawPicture(pos, sz, varioDevImage)

    setColor(COLOR_WHITE)
    setFontSize(int(float(fontSize) * 0.85))
    drawStrAnchored(pos + sz * float2(0.5, 0.5), "{roundi(vertSpd)}", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(pos + sz * float2(0.25, 0.4), "м/с", AnchorHorz.Left, AnchorVert.Center)

    // Needle
    var rot = 0.0
    let absS = abs(vertSpd)
    if absS <= 10.0
      rot = cvt(vertSpd, -10.0, 10.0, -PI * 0.21, PI * 0.21)
    elif absS <= 20.0
      rot = cvt(absS, 10.0, 20.0, PI * 0.21, PI * 0.38) * sign(vertSpd)
    else
      rot = cvt(absS, 20.0, 30.0, PI * 0.38, PI * 0.5) * sign(vertSpd)
    let ctr = pos + sz * 0.5
    setRotation(ctr, rot)
    drawLine(ctr + float2(-sz.x * 0.45, 0.0), ctr + float2(-sz.x * 0.2, 0.0))
    setFillColor(COLOR_WHITE)
    drawFilledPoly([ctr + float2(-sz.x * 0.45, 0.0), ctr + float2(-sz.x * 0.35, -sz.y * 0.04), ctr + float2(-sz.x * 0.35, sz.y * 0.04)])
    setFillColor(COLOR_NULL)
    resetViewTm()
    setFontSize(fontSize)


  // --- Speed device ---
  def drawSu30SpeedDevice(pos : float2; sz : float2)
    drawPicture(pos, sz, spdDevImage)

    let ctr = pos + sz * 0.5
    var rotSp = 0.0
    let spd = iasMps
    if spd < 55.55
      rotSp = cvt(spd, 0.0, 55.55, PI * 0.5, PI * 0.69)
    elif spd < 111.11
      rotSp = cvt(spd, 55.55, 111.11, PI * 0.69, PI * 1.165)
    elif spd < 166.67
      rotSp = cvt(spd, 111.11, 166.67, PI * 1.165, PI * 1.5)
    elif spd < 277.78
      rotSp = cvt(spd, 166.67, 277.78, PI * 1.5, PI * 2.0)
    else
      rotSp = cvt(spd, 277.78, 416.67, PI * 2.0, PI * 2.5)
    setRotation(ctr, rotSp)
    setColor(COLOR_WHITE)
    setLineWidth(2.0)
    drawLine(ctr + float2(-sz.x * 0.45, 0.0), ctr)
    setFillColor(COLOR_WHITE)
    drawFilledPoly([ctr + float2(-sz.x * 0.45, 0.0), ctr + float2(-sz.x * 0.38, -sz.y * 0.02), ctr + float2(-sz.x * 0.38, sz.y * 0.02)])
    setFillColor(COLOR_NULL)
    setLineWidth(1.0)
    resetViewTm()

    // Speed value box in center
    setFontSize(int(float(fontSize) * 1.3))
    let spdValCtr = ctr + float2(0.0, sz.y * 0.12)
    setColor(COLOR_GREEN)
    drawBox(spdValCtr - float2(sz.x * 0.20, sz.y * 0.09), spdValCtr + float2(sz.x * 0.20, sz.y * 0.09))
    setColor(COLOR_WHITE)
    drawStrAnchored(spdValCtr, "{roundi(iasMps * MPS_TO_KPH)}", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  // --- Altitude device ---
  def drawSu30AltDevice(pos : float2; sz : float2)
    drawPicture(pos, sz, altDevImage)

    let ctr = pos + sz * 0.5

    // 10km needle (short)
    let rotKm = cvt(altM, 0.0, 10000.0, PI * 0.5, PI * 2.5)
    setRotation(ctr, rotKm)
    setColor(COLOR_WHITE)
    setLineWidth(2.5)
    drawLine(ctr + float2(-sz.x * 0.3, 0.0), ctr)
    setFillColor(COLOR_WHITE)
    drawFilledPoly([ctr + float2(-sz.x * 0.30, 0.0), ctr + float2(-sz.x * 0.23, -sz.y * 0.03), ctr + float2(-sz.x * 0.23, sz.y * 0.03)])
    setFillColor(COLOR_NULL)
    setLineWidth(1.0)
    resetViewTm()

    // 1000m needle (long)
    let rotH = cvt(altM % 1000.0, 0.0, 1000.0, PI * 0.5, PI * 2.5)
    setRotation(ctr, rotH)
    setColor(COLOR_WHITE)
    setLineWidth(1.5)
    drawLine(ctr + float2(-sz.x * 0.45, 0.0), ctr)
    setFillColor(COLOR_WHITE)
    drawFilledPoly([ctr + float2(-sz.x * 0.45, 0.0), ctr + float2(-sz.x * 0.38, -sz.y * 0.02), ctr + float2(-sz.x * 0.38, sz.y * 0.02)])
    setFillColor(COLOR_NULL)
    setLineWidth(1.0)
    resetViewTm()

    // Yellow value box
    setFontSize(int(float(fontSize) * 1.3))
    let valBoxCtr = ctr + float2(0.0, sz.y * 0.12)
    setColor(COLOR_YELLOW)
    setFillColor(COLOR_YELLOW)
    drawBox(valBoxCtr - float2(sz.x * 0.20, sz.y * 0.09), valBoxCtr + float2(sz.x * 0.20, sz.y * 0.09))
    setColor(COLOR_BLACK)
    drawStrAnchored(valBoxCtr, "{int(altM % 1000.0)}", AnchorHorz.Center, AnchorVert.Center)

    // Thousands box
    setColor(COLOR_GREEN)
    setFillColor(COLOR_NULL)
    let thBoxCtr = ctr + float2(-sz.x * 0.08, sz.y * 0.0)
    drawBox(thBoxCtr - float2(sz.x * 0.12, sz.y * 0.05), thBoxCtr + float2(0.0, sz.y * 0.0))
    setColor(COLOR_WHITE)
    drawStrAnchored(thBoxCtr - float2(sz.x * 0.02, sz.y * 0.02), "{int(altM / 1000.0)}", AnchorHorz.Right, AnchorVert.Center)
    setFontSize(fontSize)


  // --- Digital heights ---
  def drawSu30Heights()
    setFontSize(int(float(fontSize) * 1.3))
    setColor(COLOR_GREEN)
    drawStrAnchored(float2(0.97, 0.09), "{roundi(altM)}", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(0.97, 0.96), "{roundi(altBaroM)}p", AnchorHorz.Right, AnchorVert.Center)
    setFontSize(fontSize)


  // --- Digital speeds ---
  def drawSu30Speeds()
    setFontSize(int(float(fontSize) * 1.3))
    setColor(COLOR_GREEN)
    drawStrAnchored(float2(0.03, 0.09), "{roundi(iasMps * MPS_TO_KPH)}", AnchorHorz.Left, AnchorVert.Center)
    setFontSize(int(float(fontSize) * 1.0))
    drawStrAnchored(float2(0.03, 0.96), "{roundi(tasMps * MPS_TO_KPH)}и", AnchorHorz.Left, AnchorVert.Center)
    // Mach
    let machStr = fmt(":.2f", machNum)
    drawStrAnchored(float2(0.15, 0.14), "{machStr}M", AnchorHorz.Left, AnchorVert.Center)
    setFontSize(fontSize)


  // --- RPM arc ---


  // --- HSI compass (ported from hsi.das) ---
  def drawHsi(pos : float2; sz : float2)
    // Draw HSI directly in parent local axes using pos/sz
    // Aspect correction: sz.x != sz.y, so use elliptical coords
    let ctr = pos + sz * 0.5
    let rx = sz.x * 0.5   // half-width
    let ry = sz.y * 0.5   // half-height
    let ringS = 0.88       // ring at 88% of half-size
    let roseS = 0.84       // rose ticks outer

    // Outer ring (ellipse)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    let nPts = 48
    var ringPts = array<float2>()
    for i in range(nPts)
      let a = float(i) * 2.0 * PI / float(nPts)
      var sn, cs : float
      sincos(a, sn, cs)
      ringPts |> push(ctr + float2(cs * rx * ringS, sn * ry * ringS))
    ringPts |> push(ringPts[0])
    drawPolyLine(ringPts)

    // Compass rose ticks
    let fwd = hero.unitTm[0]
    let hRad = atan2(fwd.x, fwd.z)
    setFontSize(int(float(fontSize) * 0.65))
    for i in 0..72
      let tickDeg = float(i * 5)
      let angle = tickDeg * degToRad - hRad - PI_2
      var sn, cs : float
      sincos(angle, sn, cs)
      let isCardinal = (i % 18) == 0
      let isLabel = (i % 6) == 0
      let isMajor = (i % 2) == 0
      var innerS = roseS - 0.06
      if isCardinal
        innerS = roseS - 0.18
      elif isMajor
        innerS = roseS - 0.12
      drawLine(ctr + float2(cs * rx * innerS, sn * ry * innerS), ctr + float2(cs * rx * roseS, sn * ry * roseS))

      if isLabel
        let distFromTop = abs(norm_ang(angle + PI_2))
        if distFromTop < 18.0 * degToRad
          continue
        var lbl = ""
        let td = int(tickDeg)
        if td == 0
          lbl = "N"
        elif td == 90
          lbl = "E"
        elif td == 180
          lbl = "S"
        elif td == 270
          lbl = "W"
        else
          lbl = "{td / 10}"
        let textS = innerS - 0.10
        drawStrAnchored(ctr + float2(cs * rx * textS, sn * ry * textS), lbl, AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)

    // Heading box
    let hdg = roundi(norm_ang(hRad) * radToDeg) % 360
    let hdgStr = fmt(":03d", hdg)
    setFontSize(int(float(fontSize) * 1.3))
    let bw = sz.x * 0.15
    let bh = sz.y * 0.09
    let bPos = ctr + float2(0.0, -ry * ringS - bh * 1.5)
    setFillColor(COLOR_WHITE)
    drawBox(bPos - float2(bw, bh), bPos + float2(bw, bh))
    setColor(COLOR_BLACK)
    setFillColor(COLOR_NULL)
    drawStrAnchored(bPos, hdgStr, AnchorHorz.Center, AnchorVert.Center)
    setColor(COLOR_WHITE)
    setFontSize(fontSize)

    // Aircraft symbol
    drawLine(ctr + float2(0.0, -ry * 0.13), ctr + float2(0.0, ry * 0.07))
    drawLine(ctr + float2(-rx * 0.11, 0.0), ctr + float2(rx * 0.11, 0.0))
    drawLine(ctr + float2(-rx * 0.045, ry * 0.07), ctr + float2(rx * 0.045, ry * 0.07))


  // =====================================================================
  //  RIGHT TOP — Engine page per ТЗ reference
  //  Local axes: 0..1 inside right-top panel
  // =====================================================================
  def drawEngineBlock()
    let ox = 0.02
    let oy = -0.48
    let w = xHalf - 0.04
    let h = MID_Y - 0.04
    pushLocalAxes(float2(ox, oy), float2(w, h))

    let smF = int(float(fontSize) * 1.3)
    let mdF = int(float(fontSize) * 1.5)

    // === ZONE 1: top service area (y 0..0.285) ===
    drawEngZone1(smF, mdF)

    // 1.12 Horizontal divider
    setColor(COLOR_GREEN)
    drawLine(float2(0.0, 0.285), float2(1.0, 0.285))

    // === ZONE 2: instruments (y 0.285..1.0) ===
    drawEngZone2(smF, mdF)

    setFontSize(fontSize)
    popAxes()


  def drawEngZone1(smF : int; mdF : int)
    setFontSize(smF)
    // 1.1 КАН
    setColor(COLOR_GREEN)
    drawStrAnchored(float2(0.03, 0.04), isChina ? "告警" : "КАН", AnchorHorz.Left, AnchorVert.Center)
    // 1.2 Number 10
    drawStrAnchored(float2(0.21, 0.04), "10", AnchorHorz.Center, AnchorVert.Center)
    // 1.3 Box КИС
    let kisHW = 0.07
    let kisHH = 0.035
    drawBox(float2(0.34 - kisHW, 0.04 - kisHH), float2(0.34 + kisHW, 0.04 + kisHH))
    drawStrAnchored(float2(0.34, 0.04), isChina ? "综合" : "КИС", AnchorHorz.Center, AnchorVert.Center)
    // 1.4 Box ОПС
    let opsHW = 0.06
    drawBox(float2(0.49 - opsHW, 0.04 - kisHH), float2(0.49 + opsHW, 0.04 + kisHH))
    drawStrAnchored(float2(0.49, 0.04), isChina ? "总览" : "ОПС", AnchorHorz.Center, AnchorVert.Center)

    // 1.5 Scroll symbol (arrows)
    drawLine(float2(0.88, 0.04), float2(0.91, 0.04))
    drawLine(float2(0.88, 0.04), float2(0.89, 0.035))
    drawLine(float2(0.88, 0.04), float2(0.89, 0.045))
    drawLine(float2(0.94, 0.04), float2(0.91, 0.04))
    drawLine(float2(0.94, 0.04), float2(0.93, 0.035))
    drawLine(float2(0.94, 0.04), float2(0.93, 0.045))



    // 1.9 Vertical divider in zone 1
    drawLine(float2(0.755, 0.06), float2(0.755, 0.285))

    // 1.10, 1.11 Bracket symbols (static graphics)
    setColor(COLOR_CYAN)
    // Left bracket: three horizontal lines connected on right
    let sy = 0.235
    drawLine(float2(0.78, sy - 0.03), float2(0.85, sy - 0.03))
    drawLine(float2(0.78, sy), float2(0.85, sy))
    drawLine(float2(0.78, sy + 0.03), float2(0.85, sy + 0.03))
    drawLine(float2(0.85, sy - 0.03), float2(0.85, sy + 0.03))
    // Right bracket: three horizontal lines connected on left
    drawLine(float2(0.86, sy - 0.03), float2(0.93, sy - 0.03))
    drawLine(float2(0.86, sy), float2(0.93, sy))
    drawLine(float2(0.86, sy + 0.03), float2(0.93, sy + 0.03))
    drawLine(float2(0.86, sy - 0.03), float2(0.86, sy + 0.03))


  def drawEngZone2(smF : int; mdF : int)
    let axisX = 0.50  // symmetry axis centered

    // --- Left engine block ---
    drawEngUnit(0.30, axisX, smF, mdF, rpm1, egt1, true)
    // --- Right engine block ---
    drawEngUnit(0.70, axisX, smF, mdF, rpm2, egt2, false)

    // --- Dual RPM scale (curved funnel) ---
    drawDualRpmScale(axisX, smF)

    // --- RPM pointers ---
    drawRpmPointer(axisX, rpm1, true)
    drawRpmPointer(axisX, rpm2, false)



  def drawEngUnit(cx : float; axisX : float; smF : int; mdF : int; rpmVal : float; egtVal : float; isLeft : bool)
    setFontSize(smF)

    // 2.1 Бокс Ф (shifted toward center axis)
    setColor(COLOR_GREEN)
    let fShift = (axisX - cx) * 0.40
    let fBoxCtr = float2(cx + fShift, 0.35)
    let fHW = isChina ? 0.04 : 0.032
    let fHH = 0.032
    drawBox(fBoxCtr - float2(fHW, fHH), fBoxCtr + float2(fHW, fHH))
    drawStrAnchored(fBoxCtr, isChina ? "加" : "Ф", AnchorHorz.Center, AnchorVert.Center)

    // 2.2 N2%
    drawStrAnchored(float2(cx, 0.38), "N2%", AnchorHorz.Center, AnchorVert.Center)

    // 2.3 RPM value box
    setFontSize(smF)
    let rpmStr = fmt(":5.1f", rpmVal * 100.0)
    let valCtr = float2(cx, 0.46)
    let vHW = isChina ? 0.09 : 0.08
    let vHH = 0.025
    setColor(COLOR_GREEN)
    drawBox(valCtr - float2(vHW, vHH), valCtr + float2(vHW, vHH))
    setColor(COLOR_WHITE)
    drawStrAnchored(valCtr, rpmStr, AnchorHorz.Center, AnchorVert.Center)

    // 2.5 T° label — left engine: label left of box, right engine: label right of box
    setFontSize(smF)
    setColor(COLOR_CYAN)
    if isLeft
      drawStrAnchored(float2(cx - 0.07, 0.62), isChina ? "温度" : "T°", AnchorHorz.Right, AnchorVert.Center)
    else
      drawStrAnchored(float2(cx + 0.07, 0.62), isChina ? "温度" : "T°", AnchorHorz.Left, AnchorVert.Center)

    // 2.6 Temperature value box
    let tempStr = "{int(egtVal)}"
    let tCtr = float2(cx, 0.66)
    let tHW = isChina ? 0.07 : 0.06
    let tHH = 0.025
    setColor(COLOR_CYAN)
    drawBox(tCtr - float2(tHW, tHH), tCtr + float2(tHW, tHH))
    drawStrAnchored(tCtr, tempStr, AnchorHorz.Center, AnchorVert.Center)

    // 2.7 охл — shifted away from center
    setColor(COLOR_WHITE)
    let ohlShift = (cx - axisX) * 0.10
    drawStrAnchored(float2(cx + ohlShift, 0.76), isChina ? "冷却" : "охл", AnchorHorz.Center, AnchorVert.Center)



  def drawDualRpmScale(axisX : float; smF : int)
    // Curved funnel: top narrow, bottom wide
    // Scale values: 10 at top (y~0.455), 0 at bottom (y~0.885)
    // Upper section (10..6): shared labels between scales
    // Lower section (6..0): labels split to each side
    setColor(COLOR_GREEN)
    setFillColor(COLOR_NULL)
    setFontSize(smF)

    let yTop = 0.40
    let yBot = 0.88
    let narrowHW = 0.06  // half-width at top (+10%)
    let wideHW = 0.15      // half-width at bottom (+10%)

    // Single curved line per side from 10 to 6 only
    let y10 = 0.455
    let y6 = 0.71
    let nSeg = 16
    var prevL = float2(0.0)
    var prevR = float2(0.0)
    for i in 0..nSeg + 1
      let t = float(i) / float(nSeg)
      let y = lerp(y10, y6, t)
      let yt = (y - yTop) / (yBot - yTop)
      let hw = lerp(narrowHW, wideHW, yt * yt)
      let curL = float2(axisX - hw, y)
      let curR = float2(axisX + hw, y)
      if i > 0
        drawLine(prevL, curL)
        drawLine(prevR, curR)
      prevL = curL
      prevR = curR

    // 3 extra ticks above 10
    let tickInward = 0.025
    for i in range(3)
      let y = y10 - float(i + 1) * 0.025
      let yt = (y - yTop) / (yBot - yTop)
      let hw = lerp(narrowHW, wideHW, max(yt * yt, 0.0))
      // Ticks inward (toward axis)
      drawLine(float2(axisX - hw, y), float2(axisX - hw + tickInward, y))
      drawLine(float2(axisX + hw, y), float2(axisX + hw - tickInward, y))

    // Ticks and labels for 10, 9, 8, 7 — inward (toward axis)
    let upperVals = fixed_array(10.0, 9.0, 8.0, 7.0)
    let upperY = fixed_array(0.455, 0.515, 0.575, 0.635)
    let minorTick = 0.015
    for i in range(4)
      let y = upperY[i]
      let yt = (y - yTop) / (yBot - yTop)
      let hw = lerp(narrowHW, wideHW, yt * yt)
      // Major tick inward
      drawLine(float2(axisX - hw, y), float2(axisX - hw + tickInward, y))
      drawLine(float2(axisX + hw, y), float2(axisX + hw - tickInward, y))
      // Label at center
      setColor(COLOR_GREEN)
      drawStrAnchored(float2(axisX, y), "{int(upperVals[i])}", AnchorHorz.Center, AnchorVert.Center)

      // Minor ticks between this and next major
      let nextY = (i < 3) ? upperY[i + 1] : y6
      let numMinor = (i < 3) ? 4 : 1  // 4 between 10-9, 9-8, 8-7; 1 between 7-6
      for j in range(numMinor)
        let mt = float(j + 1) / float(numMinor + 1)
        let my = lerp(y, nextY, mt)
        let myt = (my - yTop) / (yBot - yTop)
        let mhw = lerp(narrowHW, wideHW, myt * myt)
        drawLine(float2(axisX - mhw, my), float2(axisX - mhw + minorTick, my))
        drawLine(float2(axisX + mhw, my), float2(axisX + mhw - minorTick, my))

    // 6 — tick + split labels (on the line end)
    let hw6t = (y6 - yTop) / (yBot - yTop)
    let hw6 = lerp(narrowHW, wideHW, hw6t * hw6t)
    drawLine(float2(axisX - hw6, y6), float2(axisX - hw6 + tickInward, y6))
    drawLine(float2(axisX + hw6, y6), float2(axisX + hw6 - tickInward, y6))
    drawStrAnchored(float2(axisX - hw6 + 0.035, y6), "6", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(axisX + hw6 - 0.035, y6), "6", AnchorHorz.Center, AnchorVert.Center)

    // 4, 2, 0 — no line, just long ticks inward + labels
    let lowerVals = fixed_array(4.0, 2.0, 0.0)
    let lowerY = fixed_array(0.775, 0.825, 0.885)
    let longTick = 0.04
    for i in range(3)
      let y = lowerY[i]
      let yt = (y - yTop) / (yBot - yTop)
      let hw = lerp(narrowHW, wideHW, yt * yt)
      // Long ticks inward
      drawLine(float2(axisX - hw, y), float2(axisX - hw + longTick, y))
      drawLine(float2(axisX + hw, y), float2(axisX + hw - longTick, y))
      // Labels inside (following arc curve)
      drawStrAnchored(float2(axisX - hw + longTick + 0.01, y), "{int(lowerVals[i])}", AnchorHorz.Left, AnchorVert.Center)
      drawStrAnchored(float2(axisX + hw - longTick - 0.01, y), "{int(lowerVals[i])}", AnchorHorz.Right, AnchorVert.Center)

    // 2.9 Orange flag marks at level ~8
    setColor(E3DCOLOR(uint4(255, 106, 0, 255)))
    let y8 = 0.575
    let hw8t = (y8 - yTop) / (yBot - yTop)
    let hw8 = lerp(narrowHW, wideHW, hw8t * hw8t)
    drawLine(float2(axisX - hw8 - 0.022, y8 - 0.008), float2(axisX - hw8 - 0.010, y8 + 0.008))
    drawLine(float2(axisX + hw8 + 0.022, y8 - 0.008), float2(axisX + hw8 + 0.010, y8 + 0.008))

    // 2.10 Cyan marks at zero level
    setColor(COLOR_CYAN)
    let y0 = 0.885
    let hw0t = (y0 - yTop) / (yBot - yTop)
    let hw0 = lerp(narrowHW, wideHW, hw0t * hw0t)
    drawLine(float2(axisX - hw0 + 0.005, y0 - 0.005), float2(axisX - hw0 + 0.012, y0 + 0.005))
    drawLine(float2(axisX + hw0 - 0.005, y0 - 0.005), float2(axisX + hw0 - 0.012, y0 + 0.005))

    setColor(COLOR_GREEN)
    setFontSize(fontSize)


  def drawRpmPointer(axisX : float; rpmVal : float; isLeft : bool)
    // Outlined arrow outside arcs, pointing toward arc line
    let yTop = 0.40
    let yBot = 0.88
    let narrowHW = 0.06
    let wideHW = 0.15
    let y10 = 0.455
    let y6 = 0.71
    let yMaxUp = y10 - 0.075   // third tick above 10
    let rpmPct = clamp(rpmVal, 0.0, 1.15)  // allow up to ~115% for afterburner
    let scaleVal = rpmPct * 10.0
    var y = 0.0
    if scaleVal > 10.0
      y = lerp(y10, yMaxUp, (scaleVal - 10.0) / 1.5)  // 10..11.5 maps to y10..yMaxUp
    elif scaleVal >= 6.0
      y = lerp(y6, y10, (scaleVal - 6.0) / 4.0)
    else
      y = lerp(yBot, y6, scaleVal / 6.0)
    let hwt = (y - yTop) / (yBot - yTop)
    let hw = lerp(narrowHW, wideHW, max(hwt * hwt, 0.0))
    // Arrow sits inside arc: tip near arc line, tail toward axis
    let dir = isLeft ? -1.0 : 1.0
    let tipX = axisX + dir * (hw + 0.005)  // just outside arc
    let headLen = 0.018
    let bodyLen = 0.025
    let headH = 0.012   // half-height of arrowhead
    let bodyH = 0.006   // half-height of body
    // Outline arrow: body rect + triangle head, pointing toward arc from outside
    setColor(COLOR_WHITE)
    setFillColor(COLOR_NULL)
    let tailX = tipX + dir * (headLen + bodyLen)
    let neckX = tipX + dir * headLen
    drawPolyLine([float2(tailX, y - bodyH),
                  float2(neckX, y - bodyH),
                  float2(neckX, y - headH),
                  float2(tipX, y),
                  float2(neckX, y + headH),
                  float2(neckX, y + bodyH),
                  float2(tailX, y + bodyH),
                  float2(tailX, y - bodyH)])




  // =====================================================================
  //  RIGHT BOTTOM — Gear / Mechanization (per reference mech.png)
  // =====================================================================
  def drawMechBlock()
    let ox = 0.02
    let oy = MID_Y - 0.5 + 0.02
    let w = xHalf - 0.04
    let h = 1.0 - MID_Y - 0.04
    pushLocalAxes(float2(ox, oy), float2(w, h))

    setColor(COLOR_GREEN)
    setFontSize(int(float(fontSize) * 1.3))

    // Aircraft silhouette (Su-35 planform)
    let ctr = float2(0.50, 0.38)
    drawSu35Silhouette(ctr)

    // Gear indicators
    drawGearIndicators(ctr)

    // Flaps — rectangles under wing tips, left and right
    if flapsPos > 0.01
      let flapW = 0.0275   // +10% width
      let flapH = 0.018
      let flapY = ctr.y + 0.06  // below bottom of saucer
      let flapLx = ctr.x - 0.20  // left side under wing
      let flapRx = ctr.x + 0.20  // right side under wing
      setColor(COLOR_GREEN)
      setFillColor(COLOR_GREEN)
      // First rectangle (take off) — always shown when flaps > 0
      drawBox(float2(flapLx - flapW, flapY), float2(flapLx + flapW, flapY + flapH))
      drawBox(float2(flapRx - flapW, flapY), float2(flapRx + flapW, flapY + flapH))
      if flapsPos >= 0.5
        // Second rectangle (landing) — below first
        let gap = 0.010   // +5% more spacing
        drawBox(float2(flapLx - flapW, flapY + flapH + gap), float2(flapLx + flapW, flapY + flapH * 2.0 + gap))
        drawBox(float2(flapRx - flapW, flapY + flapH + gap), float2(flapRx + flapW, flapY + flapH * 2.0 + gap))
      setFillColor(COLOR_NULL)

    // Airbrake — green rectangle above dome when deployed
    if airBrakePos > 0.01
      let domeTop = ctr.y - 0.19  // top of dome
      let abW = 0.03
      let abH = 0.025
      setColor(COLOR_GREEN)
      setFillColor(COLOR_GREEN)
      drawBox(float2(ctr.x - abW, domeTop - abH - 0.01), float2(ctr.x + abW, domeTop - 0.01))
      setFillColor(COLOR_NULL)

    // Bottom button labels
    setColor(COLOR_GREEN)
    drawStrAnchored(float2(0.08, 0.96), isChina ? "发动" : "ДВИГ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.22, 0.96), isChina ? "燃油" : "ТОПЛ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.38, 0.96), isChina ? "前半" : "ППС", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.54, 0.96), isChina ? "GPS" : "ГПС", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.70, 0.96), isChina ? "速度" : "СКО", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.86, 0.96), isChina ? "辐射" : "ИЗЛ", AnchorHorz.Center, AnchorVert.Center)

    // Right side labels — vertical text (one letter per line)
    let lx = 0.97
    let ls = 0.045
    if isChina
      drawStrAnchored(float2(lx, 0.15), "电", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(lx, 0.15 + ls), "源", AnchorHorz.Center, AnchorVert.Center)

      drawStrAnchored(float2(lx, 0.45), "挂", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(lx, 0.45 + ls), "载", AnchorHorz.Center, AnchorVert.Center)

      drawStrAnchored(float2(lx, 0.75), "系", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(lx, 0.75 + ls), "统", AnchorHorz.Center, AnchorVert.Center)
    else
      drawStrAnchored(float2(lx, 0.15), "Е", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(lx, 0.15 + ls), "С", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(lx, 0.15 + ls * 2.0), "Б", AnchorHorz.Center, AnchorVert.Center)

      drawStrAnchored(float2(lx, 0.45), "Н", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(lx, 0.45 + ls), "Е", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(lx, 0.45 + ls * 2.0), "С", AnchorHorz.Center, AnchorVert.Center)

      drawStrAnchored(float2(lx, 0.75), "С", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(lx, 0.75 + ls), "Д", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(lx, 0.75 + ls * 2.0), "С", AnchorHorz.Center, AnchorVert.Center)

    setFontSize(fontSize)
    popAxes()


  def drawSu35Silhouette(ctr : float2)
    setColor(COLOR_GREEN)
    setFillColor(COLOR_NULL)
    setLineWidth(1.5)
    // Front view "UFO saucer" — dome on top, wide wings, flat bottom
    let domeOfs = -0.07  // lift dome up
    // Dome (canopy hump) — arc from left to right, raised
    let domeN = 16
    var dome = array<float2>()
    for i in range(domeN + 1)
      let t = float(i) / float(domeN)
      let a = PI * t
      var sn, cs : float
      sincos(a, sn, cs)
      dome |> push(ctr + float2(cs * 0.08, -sn * 0.12 + domeOfs))
    drawPolyLine(dome)
    // Wings — connect from dome base (raised) to wingtips (original Y)
    // Left wing: dome base left -> wingtip -> wing root bottom
    drawLine(ctr + float2(-0.08, domeOfs), ctr + float2(-0.38, 0.03))
    drawLine(ctr + float2(-0.38, 0.03), ctr + float2(-0.08, 0.04))
    // Right wing
    drawLine(ctr + float2(0.08, domeOfs), ctr + float2(0.38, 0.03))
    drawLine(ctr + float2(0.38, 0.03), ctr + float2(0.08, 0.04))
    // Bottom flat line (connects wing roots)
    drawLine(ctr + float2(-0.08, 0.04), ctr + float2(0.08, 0.04))
    // Two intake/engine boxes under fuselage
    let bw = 0.025
    let bh = 0.03
    drawBox(ctr + float2(-0.04 - bw, 0.04), ctr + float2(-0.04 + bw, 0.04 + bh))
    drawBox(ctr + float2(0.04 - bw, 0.04), ctr + float2(0.04 + bw, 0.04 + bh))
    setLineWidth(1.0)


  def drawGearIndicators(ctr : float2)
    let isTransitioning = gearPos > 0.01 && gearPos < 0.99
    var gearColor = gearPos >= 0.99 ? COLOR_GREEN : COLOR_RED
    if isTransitioning
      gearColor = fract(curTime * 2.0) < 0.5 ? COLOR_GREEN : COLOR_RED
    // Ovals: squeezed sideways (Y > X)
    let ovalRad = float2(0.01, 0.04)
    // Nose gear — centered between nozzles, lowered 7% below bottom of silhouette
    let noseY = ctr.y + 0.04 + 0.14   // +0.07 extra down
    drawGearOval(float2(ctr.x, noseY), ovalRad, gearColor)
    // Main gears — equilateral triangle from nose gear
    let triSpread = 0.08  // 0.16 * 0.93 = closer by 7%
    let triDown = 0.12
    drawGearOval(float2(ctr.x - triSpread, noseY + triDown), ovalRad, gearColor)
    drawGearOval(float2(ctr.x + triSpread, noseY + triDown), ovalRad, gearColor)


  def drawGearOval(pos : float2; rad : float2; clr : E3DCOLOR)
    setColor(clr)
    setFillColor(clr)
    var pts = array<float2>()
    for i in range(16)
      let a = float(i) * 2.0 * PI / 16.0
      var sn, cs : float
      sincos(a, sn, cs)
      pts |> push(pos + float2(cs * rad.x, sn * rad.y))
    drawFilledPolyOutlined(pts)
    setFillColor(COLOR_NULL)
    setColor(COLOR_WHITE)



[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; var props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId        = getInt(props, "fontId", 0)
  propStorage.fontSize      = getInt(props, "fontSize", 16)
  propStorage.altDevImage   = getPicture(props, "altDevImage")
  propStorage.spdDevImage   = getPicture(props, "spdDevImage")
  propStorage.varioDevImage = getPicture(props, "varioDevImage")
  propStorage.horMask       = getPicture(props, "horMask")
  let blk = getBlk(props, "blk")
  if blk != null
    propStorage.chinaLang = datablock_getBool(blk, "chinaLang", false)
