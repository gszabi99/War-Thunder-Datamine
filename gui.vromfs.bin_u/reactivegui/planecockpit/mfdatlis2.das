require %dasGameLibs.math
require %dasGameLibs.math.base
require %daslib/safe_addr
require %rGui.utils.avionics_common
require %rGui.utils.canvas_common
require DagorMath
require DagorStdGuiRender
require darg
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
  fontId : int
  isMetricUnits : bool

let
  COLOR_BLACK = E3DCOLOR(uint4(0, 0, 0, 255))
  COLOR_WHITE = E3DCOLOR(uint4(255, 255, 255, 255))
  COLOR_NULL = E3DCOLOR(0x0)

class Component : Canvas
  isValid : bool = false
  isMetricUnits : bool = true
  hero : Unit? = null
  fcm : FlightControlMode? = null
  hud : Hud? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  cockpit : FlightModelCockpit? = null
  wc : WeaponController? = null

  defaultLineWidth : float = 3.0
  defaultFontSize : int = 70
  totalTime : float = 0.0

  targetPos : float3 = float3(0.0)
  isCalculatedRangeValid : bool = false

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    fcm = get_flight_control_mode()
    return if fcm == null
    hud = hud::get_cur_hud()
    return if hud == null
    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null
    fm = fmw.fm
    return if fm == null
    cockpit = fmw.cockpit
    return if cockpit == null
    wc = hero.weap
    return if wc == null

    totalTime = float(get_total_time())
    var enabled = false
    *cockpit |> getMfdTargetPos(targetPos, safe_addr(enabled))
    if targetPos == float3(0.0)
      isCalculatedRangeValid = hud::get_target_point_on_ground(targetPos)
    else
      isCalculatedRangeValid = true

    isValid = true
    isMetricUnits = props.isMetricUnits
    setColor(COLOR_BLACK)
    setLineWidth(defaultLineWidth)
    setFont(props.fontId)
    setFontSize(defaultFontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))

  def drawReticle()
    let rectSize = float2(0.6, 0.4)
    let rectHalfSize = 0.25 * rectSize
    drawBox(-rectHalfSize, rectHalfSize)

    let outerCrossGapSize = 0.1 * rectSize
    drawLine(float2(0.0, 0.3), float2(0.0, outerCrossGapSize.y))
    drawLine(float2(0.0, -0.5), float2(0.0, -outerCrossGapSize.y))
    drawLine(float2(0.5, 0.0), float2(outerCrossGapSize.x, 0.0))
    drawLine(float2(-0.5, 0.0), float2(-outerCrossGapSize.x, 0.0))

    setColor(COLOR_WHITE)
    let innerCrossGapSize = 0.05 * rectSize
    drawCrossReticle(float2(0.0), innerCrossGapSize * 2.0, outerCrossGapSize * 2.0)
    setColor(COLOR_BLACK)

    if fcm.ctrlMap.isLaserDesignatorEnabled
      setLineWidth(defaultLineWidth * 1.5)
      let serifHalfSize = 0.03
      let dx = 0.5 * rectSize.x
      let dy = 0.5 * rectSize.y
      drawLine(float2(dx, -serifHalfSize), float2(dx, serifHalfSize))
      drawLine(float2(-dx, -serifHalfSize), float2(-dx, serifHalfSize))
      drawLine(float2(-serifHalfSize, dy), float2(serifHalfSize, dy))
      drawLine(float2(-serifHalfSize, -dy), float2(serifHalfSize, -dy))
      setLineWidth(defaultLineWidth)

  def drawTrackingArea()
    if fcm.ctrlMap.isAimLockEnabled && get_sensor_index() >= 0
      let targetRadiusHalfWidth = toRelXY(float2(hud.targetTracker.screenRadius))
      drawBox(-targetRadiusHalfWidth, targetRadiusHalfWidth)

  def drawTrackingIndicator()
    let pos = float2(-0.48, 0.48)
    var str : string = ""
    var drawBg = true

    if get_sensor_index() >= 0
      str = "TAZ"
    elif fcm.ctrlMap.isAimLockEnabled && fcm.ctrlMap.isAimLockInGimbals
      str = "TAC"
    elif fcm.ctrlMap.isAimLockEnabled
      str = "R"
      drawBg = false
      setFontSize(roundi(float(defaultFontSize) * 2.0))

    if str.empty()
      return

    if drawBg
      setFillColor(COLOR_BLACK)
      setColor(COLOR_BLACK)
      drawBBox(getStrBbox(pos, str, AnchorHorz.Left, AnchorVert.Bottom))
      setColor(COLOR_WHITE)
    else
      setColor(COLOR_BLACK)
    drawStrAnchored(pos, str, AnchorHorz.Left, AnchorVert.Bottom)
    setFontSize(defaultFontSize)

  def drawZoomLevel()
    let padding = 0.01
    var pos = float2(0.4 - padding, -0.18)
    let isZoomed = cockpit.mfdZoom > 0.5
    for i in 1..5
      let str = string(i)
      pos.y -= getFontAscent() + padding * 2.0
      let isSelected = (i == 1 && !isZoomed) || (i == 4 && isZoomed)
      if !isSelected
        setFillColor(COLOR_WHITE)
        setColor(COLOR_WHITE)
      else
        setFillColor(COLOR_BLACK)
        setColor(COLOR_BLACK)
      drawBBox(getStrBbox(pos, str, AnchorHorz.Right, AnchorVert.Top), padding)
      if !isSelected
        setColor(COLOR_BLACK)
      else
        setColor(COLOR_WHITE)
      drawStrAnchored(pos, str, AnchorHorz.Right, AnchorVert.Top)

  def drawOpticalMode()
    let pos = float2(-0.4)
    var posSize : float4
    let isIrActive = *cockpit |> getPositionDeviceInMfdTex(MfdPageType.MFD_NIGHT_VISION, posSize)
    let str = isIrActive ? "IR" : "VI"
    setFillColor(COLOR_BLACK)
    setColor(COLOR_BLACK)
    drawBBox(getStrBbox(pos, str, AnchorHorz.Left, AnchorVert.Top))
    setColor(COLOR_WHITE)
    drawStrAnchored(pos, str, AnchorHorz.Left, AnchorVert.Top)

  def drawHorizontalStabilizationIndicator()
    let width = 0.1
    let pos = float2(0.0, 0.5 - width)
    let gapSize = 0.04
    let centerSize = float2(0.005)
    let roll = -fmw.roll

    setFillColor(COLOR_WHITE)
    setColor(COLOR_WHITE)
    drawBox(pos - centerSize, pos + centerSize)

    setRotation(pos, deg_to_rad(roll))
    drawLine(float2(pos.x - width, pos.y), float2(pos.x - gapSize, pos.y))
    drawLine(float2(pos.x + width, pos.y), float2(pos.x + gapSize, pos.y))
    let dotOffset = toRelY(lineWidthHdpx * 2.0)
    drawDot(float2(pos.x - width, pos.y + dotOffset))
    drawDot(float2(pos.x + width, pos.y + dotOffset))
    resetViewTm()

  def drawVerticalStabilizationIndicator()
    var pos = float2(0.0, 0.4)
    let size = float2(0.04, 0.02)
    let rng = 0.1

    let localTarget = targetPos - hero.pos
    let tmInv = float3x3(inverse(hero.unitTm))
    let localVec = tmInv * localTarget
    let elevRad = atan2(localVec.y, localVec.x)
    let angle = rad_to_deg(norm_s_ang(elevRad))
    pos.y -= cvt(angle, -159.0, 14.0, -rng, rng)
    drawLine(float2(-size.x, pos.y), float2(size.x, pos.y))
    drawLine(float2(pos.x, pos.y), float2(pos.x, pos.y + size.y))

  def drawTimeToImpactOrRange()
    let pos = float2(0.0, -0.38)
    var str = ""

    str = getTimeToImpact()
    if str.empty() && isCalculatedRangeValid && fcm.ctrlMap.isAimLockEnabled && fcm.ctrlMap.isAimLockInGimbals
      str = fmt(":2.1f", length(targetPos - hero.pos) * 1e-3)
    setFontSize(roundi(float(defaultFontSize) * 0.8))
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBBox(getStrBbox(pos, str, AnchorHorz.Center, AnchorVert.Top))
    setColor(COLOR_WHITE)
    drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Top)
    setFontSize(defaultFontSize)

  def getTimeToImpact()
    let toi1 = *wc |> getLastGuidedWeaponHitTime(int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
    let toi2 = *wc |> getLastGuidedWeaponHitTime(int(WeaponTriggerType.AGM_TRIGGER))
    let timeToShowZeroValue = 2.0
    let valid1 = toi1 > totalTime - timeToShowZeroValue
    let valid2 = toi2 > totalTime - timeToShowZeroValue
    if !valid1 && !valid2
      return ""
    let toi = valid1 ? (valid2 ? min(toi1, toi2) : toi1) : toi2
    let time = clamp(toi - totalTime, 0.0, 99.999)
    return fmt(":04.1f", time)

  def drawTrigger()
    if !avionics_common::is_trigger_pulled(fm, wc)
      return
    let str = "TIR"
    let pos = float2(0.0, 0.1)
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBBox(getStrBbox(pos, str, AnchorHorz.Center, AnchorVert.Top))
    setColor(COLOR_WHITE)
    drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Top)

  def drawDynamicLaunchZone()
    let pos = float2(0.42, 0.45)
    let size = float2(0.04, 0.9)
    let gap = 0.02
    if !get_agm_launch_zone_visible()
      return

    let distMax = get_agm_launch_zone_dist_max()
    let distMin = get_agm_launch_zone_dist_min()
    let fullRangeMultInv = 0.8
    let distanceRangeInv = fullRangeMultInv / max(distMax, 1.0)
    let distMinRel = distMin * distanceRangeInv
    let distMaxRel = fullRangeMultInv
    let distTgtRel = min(length(targetPos - hero.pos) * distanceRangeInv, 1.0)
    setColor(COLOR_WHITE)
    setLineWidth(defaultLineWidth * 2.0)
    drawLine(float2(pos.x, pos.y - size.y), float2(pos.x, pos.y - size.y * distMaxRel - gap))
    drawLine(float2(pos.x, pos.y - size.y * distMaxRel + gap), float2(pos.x, pos.y - size.y * distMinRel - gap))
    drawLine(float2(pos.x, pos.y - size.y * distMinRel + gap), float2(pos.x, pos.y))
    drawLine(float2(pos.x - gap, pos.y - size.y * distTgtRel), float2(pos.x - gap - size.x, pos.y - size.y * distTgtRel))
    setLineWidth(defaultLineWidth)

  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawReticle()
    drawTrackingArea()
    drawTrackingIndicator()
    drawOpticalMode()
    drawTrigger()
    drawTimeToImpactOrRange()
    drawHorizontalStabilizationIndicator()
    drawVerticalStabilizationIndicator()
    drawZoomLevel()
    drawDynamicLaunchZone()
    restoreViewport()

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.isMetricUnits = getBool(props, "isMetricUnits", true)
