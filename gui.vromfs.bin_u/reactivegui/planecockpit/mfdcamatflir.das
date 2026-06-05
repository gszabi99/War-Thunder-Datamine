require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

require %gameLibs.das.math
require %gameLibs.das.math.base
require %daslib/safe_addr

require app
require DagorMath
require DagorMathUtils
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require hud
require Mission
require Plane
require Unit
require Weapon
require WTCamera


struct Colors
  white = E3DCOLOR(Color4(float4(1.000, 1.000, 1.000, 1.000))) //#FFFFFF
  none  = E3DCOLOR(0x0)


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
  colors : Colors = Colors()
  totalTime : float = 0.0

  defaultFontSize : int = 20
  smallFontSize : int = 16
  defaultLineWidth : float = 2.0
  osbMargin : float = 0.025
  osbStep : float2 = float2(0.14, 0.18)

  targetPos : float3 = float3(0.0)
  isCalculatedRangeValid : bool = false
  isPointTracking : bool = false
  isAreaTracking : bool = false
  isThermalActive : bool = false
  isNaro : bool = false
  lookAnglesDeg : float2 = float2(0.0)
  altFt : float = 0.0
  iasMach : float = 0.0
  iasKts : float = 0.0
  zoomFactor : float = 1.0


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

    isValid = true
    setColor(colors.white)
    setFillColor(colors.none)
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
    isThermalActive = *cockpit |> getPositionDeviceInMfdTex(MfdPageType.MFD_THERMAL, posSize)

    var enabled = false
    *cockpit |> getMfdTargetPos(targetPos, safe_addr(enabled))
    isCalculatedRangeValid = (targetPos == float3(0.0)) ? hud::get_target_point_on_ground(targetPos) : true

    isAreaTracking = fcm.ctrlMap.isAimLockEnabled && fcm.ctrlMap.isAimLockInGimbals
    isPointTracking = get_sensor_index() >= 0
    isNaro = cockpit.mfdZoom > 0.5
    zoomFactor = isNaro ? 6.0 : 0.7
    iasKts = fmw.ias * MPS_TO_KTS
    iasMach = fmw.fm.cache.Mach
    altFt = fm.input.currentAlt * M_TO_FT

    if isCalculatedRangeValid
      let delta = targetPos - hero.unitTm[3]
      let headingRad = atan2_est(hero.unitTm[0].x, hero.unitTm[0].z)
      let bearingRad = atan2_est(delta.x, delta.z)
      let dist2d = length(float2(delta.x, delta.z))
      lookAnglesDeg = float2(
        rad_to_deg(angle_diff(headingRad, bearingRad)),
        rad_to_deg(atan2_est(delta.y, dist2d)))


  def drawTopOsb()
    let y = -0.5 + osbMargin

    setFontSize(smallFontSize)
    drawStrAnchored(float2(-osbStep.x * 2.0, y), isNaro ? "NAR" : "WFOV", AnchorHorz.Center, AnchorVert.Top)
    let zfStr = fmt(":.1f", zoomFactor)
    drawStrAnchored(float2(-osbStep.x, y), "Z{zfStr}", AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(float2(0.0, y), isThermalActive ? "IR" : "TV", AnchorHorz.Center, AnchorVert.Top)
    let azDir = sign(lookAnglesDeg.x) < 0.0 ? "L" : "R"
    let azStr = fmt(":.1f", abs(lookAnglesDeg.x))
    drawStrAnchored(float2(osbStep.x, y), "{azStr} {azDir}", AnchorHorz.Center, AnchorVert.Top)
    setFontSize(defaultFontSize)


  def drawOsbArrow(pos : float2; flip : bool = false)
    let dir = flip ? -1.0 : 1.0
    let arrowBaseH = dir * 0.05
    let arrowHeadH = arrowBaseH - dir * 0.01
    let arrowW = 0.006
    let arrow = to_array_move(fixed_array<float2>(
      float2(-arrowW, -arrowHeadH),
      float2(0.0, -arrowBaseH),
      float2(arrowW, -arrowHeadH)
    ).translate(pos))

    setLineWidth(defaultLineWidth * 0.5)
    drawPolyLine(arrow)
    drawLine(pos, pos + float2(0.0, -arrowBaseH))
    setLineWidth(defaultLineWidth)


  def drawLeftOsb()
    let x = -0.5 + osbMargin

    setFontSize(smallFontSize)
    let lvlBox = drawStrVerticalAnchored(float2(x, -osbStep.y * 1.0), "LVL", 0.005, AnchorHorz.Left, AnchorVert.Center)
    let boxW = toRelX(lvlBox.width.x)
    let boxHw = boxW * 0.5
    let boxHwArrow = float2(boxHw, 0.0)
    drawStrAnchored(float2(x + osbMargin, -osbStep.y), "5", AnchorHorz.Left, AnchorVert.Center)
    let arrowMargin = float2(0.0, 0.02)
    drawOsbArrow(toRelPos(lvlBox.leftTop) + boxHwArrow - arrowMargin)
    drawOsbArrow(toRelPos(lvlBox.rightBottom) - boxHwArrow + arrowMargin, true)

    let elStr = fmt(":.1f", lookAnglesDeg.y)
    drawStrAnchored(float2(x + osbMargin * 3.0, 0.0), "{elStr} ", AnchorHorz.Left, AnchorVert.Bottom)

    let gnBox = drawStrVerticalAnchored(float2(x, osbStep.y), "GN", 0.005, AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(x + osbMargin, osbStep.y), "5", AnchorHorz.Left, AnchorVert.Center)
    drawOsbArrow(toRelPos(gnBox.leftTop) + boxHwArrow - arrowMargin)
    drawOsbArrow(toRelPos(gnBox.rightBottom) - boxHwArrow + arrowMargin, true)

    let zStr = fmt(":.1f", zoomFactor)
    drawStrVerticalAnchored(float2(x, osbStep.y * 2.0), "ZF", 0.005, AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(x + osbMargin, osbStep.y * 2.0), "{zStr}", AnchorHorz.Left, AnchorVert.Center)
    setFontSize(defaultFontSize)


  def drawRightOsb()
    let x = 0.5 - osbMargin
    let boxPadding = 0.003

    setFontSize(smallFontSize)
    let rtclBox = drawStrAnchored(float2(x, -osbStep.y * 2.0), "RTCL", AnchorHorz.Right, AnchorVert.Center)
    drawBBox(rtclBox, boxPadding)
    drawStrVerticalAnchored(float2(x, 0.0), "VVSLV", 0.005, AnchorHorz.Right, AnchorVert.Center)
    let grayBox = drawStrVerticalAnchored(float2(x, osbStep.y), "GRAY", 0.005, AnchorHorz.Right, AnchorVert.Center)
    drawBBox(grayBox, boxPadding)
    setFontSize(defaultFontSize)


  def drawBottomOsb()
    let y = 0.5 - osbMargin

    setFontSize(smallFontSize)
    drawStrAnchored(float2(-osbStep.x * 2.0, y), "WHT", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(-osbStep.x, y), "ALG", AnchorHorz.Center, AnchorVert.Bottom)
    let azStr = fmt(":02d", roundi(abs(lookAnglesDeg.x)))
    drawStrAnchored(float2(0.0, y), "{azStr} 14", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(osbStep.x, y), "LST", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(osbStep.x * 2.0, y), "DCLTR", AnchorHorz.Center, AnchorVert.Bottom)
    setFontSize(defaultFontSize)


  def drawCornerSymbols()
    let margin = float2(0.04)
    // Top left
    setFontSize(smallFontSize)
    drawStrAnchored(float2(-0.5) + margin, "OPR", AnchorHorz.Left, AnchorVert.Top)
    // Bottom left
    let spdStr = "{roundi(iasKts)}"
    let machStr = fmt(":.1f", iasMach)
    let posMach = float2(-0.5 + margin.x, 0.5 - margin.y)
    let boxMach = drawStrAnchored(posMach, "M{machStr}", AnchorHorz.Left, AnchorVert.Bottom)
    drawStrAnchored(posMach - float2(0.0, toRelY(boxMach.width.y) + 0.005), spdStr, AnchorHorz.Left, AnchorVert.Bottom)
    // Bottom right
    let altStr = "{roundi(altFt / 10.0) * 10}"
    drawStrAnchored(float2(0.5) - margin, altStr, AnchorHorz.Right, AnchorVert.Bottom)
    setFontSize(defaultFontSize)


  def drawVelocityVector()
    let vvY = clamp(deg_to_rad(-fmw.tangage) * 0.3, -0.3, 0.3)
    let vvX = 0.0
    let pos = float2(vvX, vvY)

    drawCircle(pos, 0.015)
    drawLine(pos + float2(-0.035, 0.0), pos + float2(-0.015, 0.0))
    drawLine(pos + float2(0.015, 0.0), pos + float2(0.035, 0.0))
    drawLine(pos + float2(0.0, -0.015), pos + float2(0.0, -0.025))
    // Horizon line
    let rollRad = deg_to_rad(fmw.roll)
    var sinR = 0.0
    var cosR = 0.0
    sincos(rollRad, sinR, cosR)
    let hLen = 0.18
    let hDir = float2(cosR, sinR)
    let hCenter = float2(0.0, vvY)
    drawLine(hCenter - hDir * hLen, hCenter - hDir * 0.05)
    drawLine(hCenter + hDir * 0.05, hCenter + hDir * hLen)
    // Perpendicular ticks down at horizon line ends
    let hPerp = float2(-sinR, cosR)
    let hTickLen = 0.03
    let lEnd = hCenter - hDir * hLen
    let rEnd = hCenter + hDir * hLen
    drawLine(lEnd, lEnd + hPerp * hTickLen)
    drawLine(rEnd, rEnd + hPerp * hTickLen)


  def drawReticle()
    if isPointTracking || isAreaTracking
      let s = 0.03
      let lineLen = s * 2.0
      drawBox(float2(-s), float2(s))
      drawLine(float2(0.0, -s), float2(0.0, -s - lineLen))
      drawLine(float2(0.0, s), float2(0.0, s + lineLen))
      drawLine(float2(-s, 0.0), float2(-s - lineLen, 0.0))
      drawLine(float2(s, 0.0), float2(s + lineLen, 0.0))
    else
      let gap = 0.03
      let lineLen = 0.12
      let s = gap + lineLen
      let tick = 0.02
      drawLine(float2(0.0, -gap), float2(0.0, -s))
      drawLine(float2(0.0, gap), float2(0.0, s))
      drawLine(float2(-gap, 0.0), float2(-s, 0.0))
      drawLine(float2(gap, 0.0), float2(s, 0.0))
      let tickPos = gap + lineLen * 1.2
      drawLine(float2(-tick, -tickPos), float2(tick, -tickPos))
      drawLine(float2(-tick, tickPos), float2(tick, tickPos))
      drawLine(float2(-tickPos, -tick), float2(-tickPos, tick))
      drawLine(float2(tickPos, -tick), float2(tickPos, tick))


  def drawTimeToImpact()
    let pos = float2(0.0, 0.32)
    let toi = (*wc).getLastGuidedWeaponHitTime(int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
    return if toi < 0.0
    let timeToShowZeroValue = 1.5
    if toi > totalTime - timeToShowZeroValue
      let timeLeft = clamp(toi - totalTime, 0.0, 99.99)
      let sec = floori(timeLeft)
      let frac = roundi((timeLeft - float(sec)) * 100.0)
      let timeStr = fmt(":02d", sec) + "." + fmt(":02d", frac)
      setFontSize(smallFontSize)
      drawStrAnchored(pos, "TIMPCT: {timeStr}", AnchorHorz.Center, AnchorVert.Center)
      setFontSize(defaultFontSize)


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawTopOsb()
    drawLeftOsb()
    drawRightOsb()
    drawBottomOsb()
    drawCornerSymbols()
    drawVelocityVector()
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
