require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

require %gameLibs.das.math
require %daslib/safe_addr

require app
require DagorMath
require DagorMathUtils
require DagorStdGuiRender
require darg
require FlightControl
require FlightModelWrap
require HeroManager
require hud
require Mission
require Plane
require strings
require Unit
require Weapon
require WTCamera


struct PropStorage
  fontId : int = 0
  fontScale : float = 1.0
  lineWidthScale : float = 1.0

class Component : Canvas
  isValid : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  wc : WeaponController? = null
  app : AcesApp? = null
  fcm : FlightControlMode? = null
  cockpit : FlightModelCockpit? = null
  totalTime : float = 0.0
  props : PropStorage = PropStorage()

  defaultFontSize : int = 20
  smallFontSize : int = 16
  defaultLineWidth : float = 2.0

  targetPos : float3 = float3(0.0)
  isCalculatedRangeValid : bool = false
  isPointTracking : bool = false
  isAreaTracking : bool = false
  isInertialTracking : bool = false
  isLaserDesignatorEnabled : bool = false
  isThermalActive : bool = false
  isNaro : bool = false
  isAG : bool = true
  headingDeg : float = 0.0
  azText : string = "000R"
  elText : string = "003D"
  slrNm : float = 0.0
  tgtAltM : float = 0.0


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null
    wc = hero.weap
    return if wc == null
    fm = fmw.fm
    return if fm == null
    app = get_app()
    return if app == null
    fcm = app.flightControlMode
    return if fcm == null
    cockpit = fmw.cockpit
    return if cockpit == null
    self.props := props

    isValid = true
    setColor(WHITE)
    setFillColor(TRANSPARENT)
    defaultLineWidth *= props.lineWidthScale
    setLineWidth(defaultLineWidth)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFont(props.fontId)
    defaultFontSize = roundi(float(defaultFontSize) * props.fontScale)
    smallFontSize = roundi(float(smallFontSize) * props.fontScale)
    setFontSize(defaultFontSize)

    totalTime = float(get_total_time())

    var posSize = float4(0.0)
    if *cockpit |> getPositionDeviceInMfdTex(MfdPageType.MFD_THERMAL, posSize)
      isThermalActive = true

    var enabled = false
    *cockpit |> getMfdTargetPos(targetPos, safe_addr(enabled))
    if targetPos == float3(0.0)
      isCalculatedRangeValid = hud::get_target_point_on_ground(targetPos)
    else
      isCalculatedRangeValid = true

    isInertialTracking = !fcm.ctrlMap.isAimLockInGimbals
    isAreaTracking = fcm.ctrlMap.isAimLockEnabled && !isInertialTracking
    isPointTracking = get_sensor_index() >= 0
    isLaserDesignatorEnabled = fcm.ctrlMap.isLaserDesignatorEnabled
    isNaro = cockpit.mfdZoom > 0.5

    // Master mode
    if (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET))
      isAG = false

    // Heading
    headingDeg = atan2_est(hero.unitTm[0].x, hero.unitTm[0].z) * radToDeg
    if headingDeg < 0.0
      headingDeg += 360.0

    // Target-relative data
    tgtAltM = hero.unitTm[3].y
    if isCalculatedRangeValid
      let delta = targetPos - hero.unitTm[3]
      let headingRad = atan2_est(hero.unitTm[0].x, hero.unitTm[0].z)
      let bearingRad = atan2_est(delta.x, delta.z)
      let azAngle = angle_diff(headingRad, bearingRad) * radToDeg
      var azDirStr = "R"
      if azAngle < 0.0
        azDirStr = "L"
      let azNum = fmt(":03d", roundi(abs(azAngle)))
      azText = "{azNum}{azDirStr}"

      let dist2d = length(float2(delta.x, delta.z))
      let elAngle = atan2_est(delta.y, dist2d) * radToDeg
      var elDirStr = "U"
      if elAngle < 0.0
        elDirStr = "D"
      let elNum = fmt(":03d", roundi(abs(elAngle)))
      elText = "{elNum}{elDirStr}"

      slrNm = length(delta) * metrToNavMile
      tgtAltM = targetPos.y


  def drawBorder()
    setLineWidth(defaultLineWidth * 1.5)
    drawRoundedBox(float2(-0.48), float2(0.48), float4(0.03))
    setLineWidth(defaultLineWidth)


  def drawHeader()
    let y0 = -0.46
    let dy = 0.035
    setFontSize(smallFontSize)

    // Left column: AZ, EL, SLR
    drawStrAnchored(float2(-0.46, y0), "AZ {azText}", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(-0.46, y0 + dy), "EL {elText}", AnchorHorz.Left, AnchorVert.Top)
    let slrStr = fmt(":.1f", slrNm)
    drawStrAnchored(float2(-0.46, y0 + dy * 2.0), "SLR {slrStr}", AnchorHorz.Left, AnchorVert.Top)

    // Center-left: ARM + laser code
    drawStrAnchored(float2(-0.12, y0), "ARM", AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(float2(-0.12, y0 + dy), "1688", AnchorHorz.Center, AnchorVert.Top)

    // Center: ALAS + tracking indicator
    let showLaser = !isLaserDesignatorEnabled || fract(1.5 * totalTime) < 0.5
    if showLaser
      drawStrAnchored(float2(0.08, y0), "ALAS", AnchorHorz.Center, AnchorVert.Top)
    if isPointTracking || isAreaTracking
      drawStrAnchored(float2(0.08, y0 + dy), "[+]", AnchorHorz.Center, AnchorVert.Top)
    else
      drawStrAnchored(float2(0.08, y0 + dy), "[ ]", AnchorHorz.Center, AnchorVert.Top)

    // Center-right: STAB
    drawStrAnchored(float2(0.25, y0), "STAB", AnchorHorz.Center, AnchorVert.Top)

    // Right column: DCL + coordinates + elevation
    drawStrAnchored(float2(0.46, y0), "DCL", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(0.46, y0 + dy), "N  23 43.34", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(0.46, y0 + dy * 2.0), "E 104 34.32", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(0.46, y0 + dy * 3.0), "ELV   {roundi(tgtAltM)}", AnchorHorz.Right, AnchorVert.Top)

    setFontSize(defaultFontSize)


  def drawLeftLabels()
    setFontSize(smallFontSize)

    // CDES - boxed label (outlined)
    let cdesPos = float2(-0.46, -0.22)
    drawStrAnchored(cdesPos, "CDES", AnchorHorz.Left, AnchorVert.Center)
    drawBBox(getStrBbox(cdesPos, "CDES", AnchorHorz.Left, AnchorVert.Center), 0.005)

    // ALG - vertical
    drawStrVerticalAnchored(float2(-0.47, 0.15), "ALG", 0.0, AnchorHorz.Left, AnchorVert.Center)

    // WHT - vertical (thermal mode indicator)
    if isThermalActive
      drawStrVerticalAnchored(float2(-0.47, 0.35), "WHT", 0.0, AnchorHorz.Left, AnchorVert.Center)

    setFontSize(defaultFontSize)


  def drawRightLabels()
    setFontSize(smallFontSize)

    // EXP - expand/zoom
    drawStrVerticalAnchored(float2(0.47, -0.05), "EXP", 0.0, AnchorHorz.Right, AnchorVert.Center)

    // T1 - target 1
    drawStrVerticalAnchored(float2(0.47, 0.10), "T1", 0.0, AnchorHorz.Right, AnchorVert.Center)

    // RCD - record
    drawStrVerticalAnchored(float2(0.47, 0.25), "RCD", 0.0, AnchorHorz.Right, AnchorVert.Center)

    // M - mode
    drawStrAnchored(float2(0.47, 0.40), "M", AnchorHorz.Right, AnchorVert.Center)

    setFontSize(defaultFontSize)


  def drawBottomLabels()
    let by = 0.46
    let bx0 = -0.35
    let bstep = 0.14
    setFontSize(smallFontSize)

    // Master mode
    let modeStr = isAG ? "A/G" : "A/A"
    drawStrAnchored(float2(bx0, by), modeStr, AnchorHorz.Center, AnchorVert.Bottom)

    // TGT
    drawStrAnchored(float2(bx0 + bstep, by), "TGT", AnchorHorz.Center, AnchorVert.Bottom)

    // WPT
    drawStrAnchored(float2(bx0 + bstep * 2.0, by), "WPT", AnchorHorz.Center, AnchorVert.Bottom)

    // PTRK (rightmost)
    drawStrAnchored(float2(bx0 + bstep * 5.0, by), "PTRK", AnchorHorz.Center, AnchorVert.Bottom)

    // Separator lines between labels
    let sepY0 = 0.43
    let sepY1 = 0.48
    for i in range(0, 5)
      let sx = bx0 + bstep * (float(i) + 0.5)
      drawLine(float2(sx, sepY0), float2(sx, sepY1))

    // Heading / bearing info bottom-right
    let hdg = fmt(":03d", roundi(headingDeg))
    drawStrAnchored(float2(0.38, 0.42), "{hdg}-102", AnchorHorz.Right, AnchorVert.Bottom)

    setFontSize(defaultFontSize)


  def drawHeadingIndicator()
    setFontSize(smallFontSize)
    let center = float2(-0.30, 0.20)
    let radius = 0.04
    let angle = -PI_2 - headingDeg * degToRad
    var sinVal = 0.0
    var cosVal = 0.0
    sincos(angle, sinVal, cosVal)
    let dir = float2(cosVal, sinVal)
    let perp = float2(-sinVal, cosVal)
    let tip = center + dir * radius
    // Arrow line
    drawLine(center - dir * 0.02, tip)
    // Arrowhead
    drawLine(tip, tip - dir * 0.015 + perp * 0.01)
    drawLine(tip, tip - dir * 0.015 - perp * 0.01)
    // N label
    drawStrAnchored(tip + dir * 0.025, "N", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(defaultFontSize)


  def drawReticle()
    if isPointTracking || isAreaTracking
      // Locked target: square with 4 lines from center of each side
      let s = 0.03
      let lineLen = s * 2.0
      drawBox(float2(-s), float2(s))
      drawLine(float2(0.0, -s), float2(0.0, -s - lineLen))
      drawLine(float2(0.0, s), float2(0.0, s + lineLen))
      drawLine(float2(-s, 0.0), float2(-s - lineLen, 0.0))
      drawLine(float2(s, 0.0), float2(s + lineLen, 0.0))
    else
      // No lock: crosshair with corner brackets
      drawCrossReticle(float2(0.0), float2(0.22), float2(0.04))
      let cd = 0.12
      let cs = 0.05
      drawLine(float2(-cd, -cd), float2(-cd + cs, -cd))
      drawLine(float2(-cd, -cd), float2(-cd, -cd + cs))
      drawLine(float2(cd, -cd), float2(cd - cs, -cd))
      drawLine(float2(cd, -cd), float2(cd, -cd + cs))
      drawLine(float2(-cd, cd), float2(-cd + cs, cd))
      drawLine(float2(-cd, cd), float2(-cd, cd - cs))
      drawLine(float2(cd, cd), float2(cd - cs, cd))
      drawLine(float2(cd, cd), float2(cd, cd - cs))


  def drawTimeToImpact()
    let toi = (*wc).getLastGuidedWeaponHitTime(int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
    return if toi < 0.0
    let timeToShowZeroValue = 1.5
    if toi > totalTime - timeToShowZeroValue
      let timeLeft = clamp(toi - totalTime, 0.0, 99.99)
      let timeStr = fmt(":05.2f", timeLeft)
      setFontSize(smallFontSize)
      drawStrAnchored(float2(0.2, -0.2), "TIMPCT: {timeStr}", AnchorHorz.Center, AnchorVert.Center)
      setFontSize(defaultFontSize)


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawBorder()
    drawHeader()
    drawLeftLabels()
    drawRightLabels()
    drawBottomLabels()
    drawHeadingIndicator()
    drawReticle()
    drawTimeToImpact()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.fontScale = getFloat(props, "fontScale", 1.0)
  propStorage.lineWidthScale = getFloat(props, "lineWidthScale", 1.0)
