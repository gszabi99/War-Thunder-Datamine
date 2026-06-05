require %daslib.match
require %gameLibs.das.math.base
require %rGui.planeCockpit.mfdZ19_common
require %rGui.utils.avionics_common
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

require app
require DagorMath
require DagorMathUtils
require DagorStdGuiRender
require DagorTime
require darg
require FlightModelWrap
require GamePhys
require HeroManager
require math
require Plane
require Unit
require Weapon
require WTCamera


struct PropStorage
  fontId : int
  horMask : Picture?


struct SubDisplay
  lt           : float2
  rb           : float2
  uniformScale : bool = false


let
  SD_HSI = SubDisplay(lt = float2(-0.48, -0.32), rb = float2(0.0, 0.32), uniformScale = true)
  SD_HOR = SubDisplay(lt = float2(0.04, -0.22), rb = float2(0.34, 0.22))


def get_heading_label(deg : int) : string
  match deg
    if 0
      return "N"
    if 90
      return "E"
    if 180
      return "S"
    if 270
      return "W"
    if _
      return fmt(":02d", deg / 10)


class Component : Canvas
  isValid    : bool  = false
  heading    : float = 0.0
  track      : float = 0.0
  visual     : avionics_common::Visual
  spi        : avionics_common::SensorPointOfInterest
  horMask    : Picture? = null
  hero       : Unit? = null
  fmw        : FlightModelWrap? = null
  fcm        : FlightControlMode? = null
  app        : AcesApp? = null
  propulsion : Propulsion? = null

  @safe_when_uninitialized engines : EngineData[2]
  @safe_when_uninitialized rotor   : RotorData



  def Component(var gui_ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; var props : PropStorage&)
    Canvas`Canvas(self, gui_ctx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null
    app = get_app()
    return if app == null
    fcm = app.flightControlMode
    return if fcm == null
    horMask = props.horMask
    propulsion = fmw.fm.EI
    return if propulsion == null || propulsion.numEngines < 1 || propulsion.numEngines > 2

    isValid = true
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFont(props.fontId)
    setFontSize(14)

    heading = norm_ang(atan2_est(hero.unitTm[0].x, hero.unitTm[0].z))
    let rawTrack  = norm_ang(atan2_est(hero.vel.x, hero.vel.z))
    let trackBlend = clamp(cvt(length(hero.vel.xz), 1.0, 30.0, 0.0, 1.0), 0.0, 1.0)
    track = norm_ang(heading + angle_diff(heading, rawTrack) * trackBlend)
    visual <- avionics_common::get_visual(app.usefulTotalTime, hero)
    spi <- avionics_common::get_sensor_point_of_interest(hero)
    engines[0] <- get_engine_data(propulsion, 0)
    if propulsion.numEngines == 2
      engines[1] <- get_engine_data(propulsion, 1)
    else
      engines[1] := engines[0]
    rotor <- get_rotor_data(propulsion, 0)


  def beginSubDisplay(sd : SubDisplay)
    setViewport(sd.lt, sd.rb)
    let center = (sd.lt + sd.rb) * 0.5
    let size   = sd.rb - sd.lt
    if sd.uniformScale
      let minPix = min(size.x * canvasSize.x, size.y * canvasSize.y)
      pushLocalAxes(center, float2(minPix / canvasSize.x, minPix / canvasSize.y))
    else
      pushLocalAxes(center, size)


  def endSubDisplay()
    popAxes()
    restoreViewport()


  def drawHsi()
    beginSubDisplay(SD_HSI)
    let tickCount  = 72            // one tick every 5°
    let circleR    = 0.3           // compass rose radius
    let tickLen    = 0.02          // minor tick length; medium = ×1.6, major = ×2.5
    let planeScale = float2(0.02)  // half-size of the fixed center aircraft symbol
    let lblOffset  = 0.04          // label push beyond the outer tick tip
    let boxGap     = 0.04          // gap between outer tick tip and heading box

    let radPerTick    = TWOPI / float(tickCount)
    let ticksPerMajor = tickCount / 12   // major tick every 30°
    let ticksPerMed   = tickCount / 36   // medium tick every 10°

    setFillColor(COLOR_NULL)
    setFontSize(12)

    var sina, cosa : float
    for i in 0 .. tickCount
      let bearingRad = float(i) * radPerTick
      let isMajor    = (i % ticksPerMajor) == 0
      let isMedium   = !isMajor && (i % ticksPerMed) == 0

      let screenAngle = bearingRad - track - HALF_PI
      sincos(screenAngle, sina, cosa)

      let len    = tickLen * (isMajor ? 2.5 : (isMedium ? 1.6 : 1.0))
      let outerR = circleR + len

      setColor(COLOR_WHITE)
      drawLine(float2(circleR * cosa, circleR * sina),
               float2(outerR  * cosa, outerR  * sina))

      if isMajor
        let lbl   = get_heading_label(roundi(bearingRad * RAD_TO_DEG))
        let textR = outerR + lblOffset
        setColor(COLOR_GREEN)
        drawStrAnchored(float2(textR * cosa, textR * sina),
                        lbl, AnchorHorz.Center, AnchorVert.Center)

    let hdg = roundi(track * RAD_TO_DEG) % 360
    let hdgStr = fmt(":03d", hdg)
    setFillColor(COLOR_NULL)
    setColor(COLOR_GREEN)
    let hdgBbox = drawStrAnchored(float2(0.0, -(circleR + tickLen * 2.5 + lblOffset + boxGap)), hdgStr, AnchorHorz.Center, AnchorVert.Bottom)
    drawBBox(hdgBbox, 0.012)

    let planeLines = fixed_array(
      (float2(0.0, -0.5), float2(0.0, 1.0)),
      (float2(-1.0, 0.0), float2(1.0, 0.0)),
      (float2(-0.4, 1.0), float2(0.4, 1.0)))

    setColor(COLOR_GREEN)
    setLineWidth(2.0)
    for ln in planeLines
      drawLine(ln._0 * planeScale, ln._1 * planeScale)
    setLineWidth(1.0)
    endSubDisplay()


  def drawPitchLadder()
    let stepRel     = 0.2
    let stepSizeDeg = 10.0
    let markGap     = 0.1
    let markWidth   = 0.35

    let count           = roundi(toRelY(length(canvasSize)) / stepRel)
    let tangageStepDeg  = rad_to_deg(visual.euler.y) / stepSizeDeg
    let marksVertOffset = fract(tangageStepDeg) * stepRel
    setRotation(float2(0.0), visual.euler.z)
    // Background
    let bgHw   = length(float2(0.5))
    let bgPosY = clamp(tangageStepDeg * stepRel, -bgHw, bgHw)
    setColor(COLOR_SKY)
    setFillColor(COLOR_SKY)
    drawBox(float2(-bgHw, bgPosY - bgHw * 2.0), float2(bgHw, bgPosY))
    setColor(COLOR_GROUND)
    setFillColor(COLOR_GROUND)
    drawBox(float2(-bgHw, bgPosY), float2(bgHw, bgPosY + bgHw * 2.0))
    setColor(COLOR_WHITE)
    drawLine(float2(-bgHw, bgPosY), float2(bgHw, bgPosY))
    // Marks
    setColor(COLOR_WHITE)
    for i in -count..count + 1
      let markTangageStepDeg = floori(tangageStepDeg) - i
      if abs(markTangageStepDeg) > roundi(90.0 / stepSizeDeg)
        continue
      if markTangageStepDeg == 0
        continue
      let pos       = float2(0.0, marksVertOffset + float(i) * stepRel)
      let isBig     = (markTangageStepDeg % 2) == 0
      let markWidthRes = isBig ? markWidth : markWidth * 0.8
      setLineWidth(isBig ? 2.0 : 1.0)
      drawLine(pos + float2(-markWidthRes, 0.0), pos + float2(-markGap, 0.0))
      drawLine(pos + float2(markGap, 0.0),   pos + float2(markWidthRes, 0.0))
      setLineWidth(1.0)
      let degs = abs(markTangageStepDeg) * int(stepSizeDeg)
      drawStrAnchored(pos, "{degs}", AnchorHorz.Center, AnchorVert.Center)
    resetViewTm()


  def drawAircraftSymbol
    setColor(COLOR_GREEN)
    setLineWidth(2.0)
    drawDot(float2(0.0))
    var wing = array<float2>(
      float2(-0.05, 0.02),
      float2(-0.05, 0.0),
      float2(-0.28, 0.0),
    )
    drawPolyLine(wing)
    drawPolyLine(wing.inv_x())
    setLineWidth(1.0)


  def drawAirSpeedIndicator(pos : float2; size : float2)
    let ias    = fmw.ias * MPS_TO_KPH
    let redSpd = 300.0
    let boxOffsetX = 0.01

    let maxSpd      = 400.0
    let unitsPerKph = size.y / maxSpd
    let tapeCx      = pos.x + size.x * 0.5
    let hwBig       = size.x * 0.5 * 0.55
    let hwMed       = size.x * 0.5 * 0.35
    let hwSmall     = size.x * 0.5 * 0.18

    setFontSize(12)
    for j in 0 .. int(maxSpd / 10.0) + 1
      let spd   = j * 10
      let y     = pos.y + size.y - float(spd) * unitsPerKph
      let isBig = spd % 100 == 0
      let isMed = !isBig && spd % 50 == 0
      let hw    = isBig ? hwBig : (isMed ? hwMed : hwSmall)
      let col   = float(spd) >= redSpd ? COLOR_RED : COLOR_GREEN
      setColor(col)
      drawLine(float2(tapeCx - hw, y), float2(tapeCx + hw, y))
      if isBig
        drawStrAnchored(float2(tapeCx - hwBig - 0.005, y), "{spd / 10}", AnchorHorz.Right, AnchorVert.Center)

    let redY = pos.y + size.y - redSpd * unitsPerKph
    setColor(COLOR_GREEN)
    drawLine(float2(tapeCx, redY), float2(tapeCx, pos.y + size.y))
    setColor(COLOR_RED)
    drawLine(float2(tapeCx, pos.y), float2(tapeCx, redY))

    setFontSize(14)
    let boxY   = clamp(pos.y + size.y - ias * unitsPerKph, pos.y, pos.y + size.y)
    let boxPos = float2(tapeCx + boxOffsetX, boxY)
    let iasStr = fmt(":3d", roundi(ias))
    let iasBbox = getStrBbox(boxPos, iasStr, AnchorHorz.Center, AnchorVert.Center)
    setFillColor(COLOR_BLACK)
    setColor(COLOR_WHITE)
    drawBBox(iasBbox, 0.006)
    setColor(ias >= redSpd ? COLOR_RED : COLOR_GREEN)
    drawStrAnchored(boxPos, iasStr, AnchorHorz.Center, AnchorVert.Center)
    setFillColor(COLOR_NULL)


  def drawGroundSpeedIndicator(pos : float2)
    let gs = fmw.fm.speed * MPS_TO_KPH
    setCaretPosition(pos)
    setColor(COLOR_GREEN)
    printStr("GS ")
    setColor(COLOR_WHITE)
    printStr("{roundi(gs)}")


  def drawArtificialHorizon()
    beginSubDisplay(SD_HOR)
    drawPitchLadder()
    drawLine(float2(0.0, -0.5), float2(0.0, 0.5))
    drawAircraftSymbol()
    drawPicture(float2(-0.51), float2(1.02), horMask)
    endSubDisplay()


  def drawSideSlipIndicator(pos : float2, size : float2)
    let lim = float2(-20.0, 20.0)

    let hSize = size * 0.5
    assume dotRadius = hSize.y
    let slip = clamp(fmw.fm.aos, lim.x, lim.y)
    let rangeOfMotion = hSize.x - dotRadius
    let speedAlpha = cvt(fmw.ias, 0.0, 5.0, 0.0, 1.0)
    let translate = cvt(slip, lim.x, lim.y, -rangeOfMotion, rangeOfMotion) * speedAlpha

    setColor(COLOR_GREEN)
    setFillColor(COLOR_GREEN)
    drawCircle(float2(pos.x - translate, pos.y), dotRadius)
    drawLine(float2(pos - hSize), float2(pos.x - hSize.x, pos.y + hSize.y))
    drawLine(float2(pos + hSize), float2(pos.x + hSize.x, pos.y - hSize.y))
    setFillColor(COLOR_NULL)


  def drawHeadingTape(sd : SubDisplay; isBottom : bool)
    let ftHt = getLineSpacing()
    let padding = float2(0.01)
    let cx   = (sd.lt.x + sd.rb.x) * 0.5
    let size = sd.rb - sd.lt
    let count = 20
    let minorTickRatio = 0.35
    let textGap = 0.005

    setColor(COLOR_GREEN)
    if !isBottom
      let triSize = float2(0.01, 0.015)
      drawPolyLine(array(
        float2(cx - triSize.x, sd.rb.y + triSize.y),
        float2(cx, sd.rb.y),
        float2(cx + triSize.x, sd.rb.y + triSize.y),
      ))

    setViewport(sd.lt, sd.rb)

    let stepRel = size.x / float(count)
    let totalTicks = 36.0
    let lineHeight = size.y - ftHt - padding.y

    let effectiveHeading = isBottom ? (heading + PI) % TWOPI : heading
    let headingTicks = isBottom ? 0.5 * float(count + 1) + effectiveHeading * totalTicks / TWOPI : 0.5 * float(count + 1) - effectiveHeading * totalTicks / TWOPI
    let offset = fract(headingTicks) * stepRel

    setFontSize(12)
    for i in 0..count + 1
      let x = sd.lt.x + (float(i) - 0.5) * stepRel + offset
      if x > sd.lt.x && x < sd.rb.x
        let tickIdx = isBottom ? (3600 + floori(headingTicks) - i) % 36 : (3600 - floori(headingTicks) + i) % 36
        let tickValue = tickIdx * 10
        let hasText = tickValue % 30 == 0

        let tickLineHeight = hasText ? lineHeight : lineHeight * minorTickRatio
        let p1 = isBottom ? float2(x, sd.lt.y) : float2(x, sd.rb.y)
        let p2 = p1 + float2(0.0, isBottom ? tickLineHeight : -tickLineHeight)
        drawLine(p1, p2)

        if hasText
          let str = get_heading_label(tickValue)
          let anchor = isBottom ? AnchorVert.Top : AnchorVert.Bottom
          let textPos = p2 + float2(0.0, isBottom ? textGap : -textGap)
          drawStrAnchored(textPos, str, AnchorHorz.Center, anchor)

    restoreViewport()


  def drawHeadingTapes()
    let tapeHeight = 0.05
    let tapeGap    = 0.06
    let SD_HDG_TOP = SubDisplay(lt = float2(SD_HOR.lt.x, SD_HOR.lt.y - tapeGap - tapeHeight),
                                rb = float2(SD_HOR.rb.x, SD_HOR.lt.y - tapeGap))
    drawHeadingTape(SD_HDG_TOP, false)
    let SD_HDG_BOT = SubDisplay(lt = float2(SD_HOR.lt.x, SD_HOR.rb.y + tapeGap),
                                rb = float2(SD_HOR.rb.x, SD_HOR.rb.y + tapeGap + tapeHeight))
    drawHeadingTape(SD_HDG_BOT, true)


  def drawRalt(pos : float2; size : float2)
    let ralt = fmw.fm.input.currentAlt
    let vsRaw = fmw.fm.vertSpeed
    let vs    = abs(vsRaw) < 0.05 ? 0.0 : vsRaw

    let scaleX   = pos.x + size.x
    let scaleTop = pos.y
    let scaleBtm = pos.y + size.y
    let scaleH   = size.y
    let tickLen  = size.x
    let labelGap = 0.004
    let arrowSize = float2(0.015)

    let breakVals = fixed_array(0.0, 10.0, 50.0, 100.0, 150.0, 200.0, 300.0)
    let numSegs   = 6

    var normPos = 1.0
    let raltClamped = clamp(ralt, 0.0, 300.0)
    for i in 0 .. numSegs
      if raltClamped <= breakVals[i + 1]
        normPos = (float(i) + cvt(raltClamped, breakVals[i], breakVals[i + 1], 0.0, 1.0)) / float(numSegs)
        break

    let arrowY = scaleTop + scaleH * (1.0 - normPos)

    setColor(COLOR_GREEN)
    setFontSize(12)

    let segTickLeft  = fixed_array(false, false, true, true, true, false)
    let smallTickLen = tickLen * 0.2
    let subDivs      = 5
    for i in 0 .. numSegs
      let ty = scaleTop + scaleH * (1.0 - float(i) / float(numSegs))
      drawLine(float2(scaleX - tickLen, ty), float2(scaleX, ty))
      drawStrAnchored(float2(scaleX + labelGap, ty), "{roundi(breakVals[i])}", AnchorHorz.Left, AnchorVert.Center)
      for j in 1 .. subDivs
        let subT = scaleTop + scaleH * (1.0 - (float(i) + float(j) / float(subDivs)) / float(numSegs))
        if segTickLeft[i]
          drawLine(float2(scaleX - tickLen, subT), float2(scaleX - tickLen + smallTickLen, subT))
        else
          drawLine(float2(scaleX - smallTickLen, subT), float2(scaleX, subT))
    drawLine(float2(scaleX - tickLen, scaleTop), float2(scaleX, scaleTop))
    drawStrAnchored(float2(scaleX + labelGap, scaleTop), "{roundi(breakVals[numSegs])}", AnchorHorz.Left, AnchorVert.Center)

    let tipX  = scaleX - tickLen
    let baseX = tipX - arrowSize.x
    setFillColor(COLOR_WHITE)
    setColor(COLOR_WHITE)
    drawFilledPoly(array(
      float2(tipX,  arrowY),
      float2(baseX, arrowY - arrowSize.y),
      float2(baseX, arrowY + arrowSize.y)))
    setFillColor(COLOR_NULL)

    let vsStr = fmt(":.1f", vs)
    setColor(COLOR_WHITE)
    setFontSize(14)
    drawStrAnchored(float2(baseX - 0.004, arrowY), vsStr, AnchorHorz.Right, AnchorVert.Center)

    let raltStr = fmt(":.1f", ralt)
    setFontSize(12)
    drawStrAnchored(float2(scaleX, scaleBtm + 0.025), raltStr, AnchorHorz.Center, AnchorVert.Top)


  def drawOsbArrow(p1 : float2; p2 : float2)
    let headSizeH = float2(0.0075, 0.006)
    let normDir   = fast_normalize(p1 - p2)
    let right     = float2(-normDir.y, normDir.x)
    let tip       = p1 + normDir * headSizeH.y
    drawLine(p1, p2)
    drawFilledPoly(array(
      tip,
      p1 - normDir * headSizeH.y + right * headSizeH.x,
      p1 - normDir * headSizeH.y - right * headSizeH.x))


  def drawNavData(pos : float2)
    let colSpacing = 0.01
    let closingSpeed = spi.isSet ? dot(hero.vel, normalize(spi.worldPos - hero.pos)) : 0.0
    var etaStr = "——:——:——"
    if spi.isSet && closingSpeed > 0.5
      let totalSec = int(spi.distance / closingSpeed)
      let now = get_local_time()
      let nowSec = now.x * 3600 + now.y * 60 + now.z
      let arrivalSec = (nowSec + totalSec) % 86400
      etaStr = fmt(":02d", arrivalSec / 3600) + ":" + fmt(":02d", (arrivalSec % 3600) / 60) + ":" + fmt(":02d", arrivalSec % 60)

    setColor(COLOR_GREEN)
    setFontSize(14)
    setCaretPosition(pos)
    let colWidthStr = "当前航点"
    let colWidth = getStringSize(colWidthStr)
    printStrLn(colWidthStr)
    printStrLn("偏航距离")
    printStrLn("待飞距离")
    printStrLn("预计时间")

    setColor(COLOR_WHITE)
    setCaretPosition(pos + float2(colWidth.x + colSpacing, 0.0))
    printStrLn(spi.isSet ? fmt(":1d", 0) : "——")
    printStrLn(spi.isSet ? fmt(":.1f", 0.0) : "————")
    printStrLn(spi.isSet ? fmt(":.1f", spi.distance) : "————")
    printStrLn(etaStr)


  def drawOsbTimer(pos : float2)
    setCaretPosition(pos)
    setColor(COLOR_GREEN)
    printStrLn("秒表")
    let totalSec = int(app.usefulTotalTime)
    let mm = totalSec / 60 % 1000
    let ss = totalSec % 60
    setColor(COLOR_WHITE)
    printStrLn("{fmt(":03d", mm)}:{fmt(":02d", ss)}")
    setColor(COLOR_GREEN)


  def drawOsbDateLocalTime(pos : float2)
    let colSpacing = 0.01 * 0.5

    let now = get_local_time()
    setColor(COLOR_GREEN)
    drawStrAnchored(float2(pos.x - colSpacing, pos.y), "北京时间", AnchorHorz.Right, AnchorVert.Top)
    setColor(COLOR_WHITE)
    drawStrAnchored(float2(pos.x + colSpacing, pos.y), "{fmt(":02d", now.x)}:{fmt(":02d", now.y)}:{fmt(":02d", now.z)}", AnchorHorz.Left, AnchorVert.Top)
    setColor(COLOR_GREEN)


  def drawLrfdData(pos : float2)
    let txtOffset = float2(0.05, 0.0)

    setColor(COLOR_GREEN)
    setFontSize(12)
    drawStrAnchored(pos - txtOffset, "激光 测", AnchorHorz.Right, AnchorVert.Center)
    let bBox = getStrBbox(pos, "0000", AnchorHorz.Center, AnchorVert.Center)
    drawBBox(bBox, 0.006)
    if fcm.ctrlMap.isLaserDesignatorEnabled && fcm.ctrlMap.isAimLockEnabled && fcm.ctrlMap.isAimLockInGimbals
      let laserRange = clamp(roundi(spi.distance), 0, 9999)
      drawStrAnchored(pos, string(laserRange), AnchorHorz.Center, AnchorVert.Center)


  def drawBaroAlt(pos : float2)
    let baroAlt = fmt(": 4d", roundi(hero.unitTm[3].y - get_app().currentScene.waterLevel))
    setFontSize(14)
    setCaretPosition(pos)
    setColor(COLOR_GREEN)
    printStr("Hc")
    setColor(COLOR_WHITE)
    printStr(baroAlt)
    setColor(COLOR_GREEN)


  def drawGunData(pos : float2)
    let colSpacing = 0.01

    var turretYawDeg, turretPitchDeg = "——"
    for turret in hero.weap.turret
      if int(turret.triggerNo) < int(WeaponTriggerConsts.FIRST_GUNNER_TRIGGER)
        continue
      let weapon = get_weapon(hero.weap.Weapons, int(turret.triggerNo), int(turret.weaponIndex))
      if weapon != null && !weapon.isDummyGun
        turretYawDeg = fmt(":.1f", turret.yawVisual)
        turretPitchDeg = fmt(":.1f", turret.pitchVisual)
        break

    setColor(COLOR_GREEN)
    setFontSize(14)
    setCaretPosition(pos)
    let colWidthStr = "航炮方位"
    let colWidth = getStringSize(colWidthStr)
    printStrLn(colWidthStr)
    printStrLn("航炮俯仰")

    setColor(COLOR_WHITE)
    setCaretPosition(pos + float2(colWidth.x + colSpacing, 0.0))
    printStrLn(turretYawDeg)
    printStrLn(turretPitchDeg)
    setColor(COLOR_GREEN)


  def drawEngineData(pos : float2)
    let colSpacing = 0.005

    setCaretPosition(pos)
    setFontSize(14)
    setColor(COLOR_GREEN)
    let colWidthStr = " Q"
    let colWidth = getStringSize(colWidthStr)
    printStrLn(colWidthStr)
    printStrLn("Ng")
    printStrLn("")
    printStrLn("Nr")

    setColor(COLOR_WHITE)
    setCaretPosition(pos + float2(colWidth.x + colSpacing, 0.0))
    var torqueTotal = 0.0
    for e in engines
      torqueTotal += e.torqueRel
    let torqueAvg = torqueTotal / float(length(engines))
    printStrLn("{fmt(":5.1f", torqueAvg)}%")
    printStrLn("{fmt(":5.1f", engines[0].turbineRpmRel)}%")
    printStrLn("{fmt(":5.1f", engines[1].turbineRpmRel)}%")
    printStrLn(fmt(":4d", roundi(rotor.nr)))
    setColor(COLOR_GREEN)


  def drawLoadFactor(pos : float2)
    let load = float(fmw.fm.localAccel.y) * safeinv(gravity()) + 1.f
    setColor(COLOR_GREEN)
    drawStrAnchored(pos, "{fmt(":.1f", load)} G", AnchorHorz.Center, AnchorVert.Center)


  def drawHeading(pos : float2)
    let colSpacing = 0.005

    setCaretPosition(pos)
    setFontSize(14)
    setColor(COLOR_GREEN)
    let colWidthStr = "偏流"
    let colWidth = getStringSize(colWidthStr)
    printStrLn(colWidthStr)
    printStrLn("航向")

    let drift = angle_diff(heading, track)
    setColor(COLOR_WHITE)
    setCaretPosition(pos + float2(colWidth.x + colSpacing, 0.0))
    printStrLn(fmt(":+.1f", drift * RAD_TO_DEG))
    printStrLn(fmt(":3d", roundi(heading * RAD_TO_DEG)))
    setColor(COLOR_GREEN)


  def drawWindData(pos : float2)
    let colSpacing = 0.005

    setCaretPosition(pos)
    setFontSize(14)
    setColor(COLOR_GREEN)
    let colWidthStr = "风速"
    let colWidth = getStringSize(colWidthStr)
    printStrLn(colWidthStr)
    printStrLn("风向")

    let windVel = get_wind()
    let windSpeed = length(windVel)
    let windDir = norm_ang(atan2_est(windVel.x, windVel.z))

    setColor(COLOR_WHITE)
    setCaretPosition(pos + float2(colWidth.x + colSpacing, 0.0))
    printStrLn(fmt(":3d", roundi(windSpeed * MPS_TO_KPH)))
    printStrLn(fmt(":4d", roundi(windDir * RAD_TO_DEG)))
    setColor(COLOR_GREEN)


  def drawOsbBot()
    let margin = float2(0.06, 0.03)
    let count = 7
    let pos = float2(-0.5 + margin.x, 0.5 - margin.y)
    let step = (1.0 - margin.x * 2.0) / float(count - 1)
    drawStrAnchored(float2(pos.x, pos.y), "地图", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(pos.x + step * 2.0, pos.y), "雷达", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(pos.x + step * 3.0, pos.y), "主菜单", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(pos.x + step * 4.0, pos.y), "返回", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(pos.x + step * 6.0, pos.y), "电视", AnchorHorz.Center, AnchorVert.Center)


  def drawOsbTop()
    let margin = float2(0.06, 0.03)
    let count = 7
    let pos = float2(-0.5 + margin.x, -0.5 + margin.y)
    let step = (1.0 - margin.x * 2.0) / float(count - 1)
    drawStrAnchored(float2(pos.x, pos.y + getLineSpacing()), "图像", AnchorHorz.Center, AnchorVert.Center)
    drawOsbDateLocalTime(float2(pos.x + step * 2.0, pos.y + getLineSpacing()))
    let arrowLPos = float2(pos.x + step * 4.0, pos.y)
    let arrowSize = float2(0.03, 0.0)
    drawOsbArrow(arrowLPos - arrowSize, arrowLPos + arrowSize)
    let arrowRPos = float2(pos.x + step * 5.0, pos.y)
    drawOsbArrow(arrowRPos + arrowSize, arrowRPos - arrowSize)
    drawStrAnchored(float2(pos.x + step * 6.0, pos.y), "视场切换", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(pos.x + step * 6.0, pos.y + getLineSpacing()), "红外", AnchorHorz.Center, AnchorVert.Center)


  def drawOsbLeft()
    let margin = float2(0.01, 0.12)
    let count = 5
    let pos = float2(-0.5) + margin
    let step = (1.0 - margin.y * 2.0) / float(count - 1)
    drawOsbTimer(float2(pos.x, pos.y + step * 3.0))


  def drawOsbRight()
    let margin = float2(0.01, 0.12)
    let count = 5
    let pos = float2(0.5 - margin.x, -0.5 + margin.y)
    let step = (1.0 - margin.y * 2.0) / float(count - 1)
    let arrowLPos = float2(pos.x, pos.y + step * 2.0)
    let arrowSize = float2(0.0, 0.03)
    drawOsbArrow(arrowLPos - arrowSize, arrowLPos + arrowSize)
    let arrowRPos = float2(pos.x, pos.y + step * 3.0)
    drawOsbArrow(arrowRPos + arrowSize, arrowRPos - arrowSize)


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawHsi()
    drawArtificialHorizon()
    drawAirSpeedIndicator(float2(-0.025, -0.1), float2(0.08, 0.32))
    drawGroundSpeedIndicator(float2(-0.02, 0.26))
    drawSideSlipIndicator(float2((SD_HOR.lt.x + SD_HOR.rb.x) * 0.5, SD_HSI.rb.y - 0.08), float2(0.08, 0.018))
    drawHeadingTapes()
    drawRalt(float2(0.40, -0.2), float2(0.018, 0.35))
    drawNavData(float2(-0.07, 0.34))
    drawBaroAlt(float2(0.4, -0.34))
    drawGunData(float2(0.34, 0.36))
    drawEngineData(float2(-0.05, -0.2))
    drawLoadFactor(float2(-0.02, -0.25))
    drawHeading(float2(-0.4, -0.36))
    drawWindData(float2(-0.1, -0.36))
    drawLrfdData(float2((SD_HOR.lt.x + SD_HOR.rb.x) * 0.5, SD_HSI.lt.y - 0.02))
    drawOsbBot()
    drawOsbTop()
    drawOsbLeft()
    drawOsbRight()
    restoreViewport()


[export]
def render(var gui_ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; var props : PropStorage&)
  new Component(gui_ctx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.horMask = getPicture(props, "horMask")
