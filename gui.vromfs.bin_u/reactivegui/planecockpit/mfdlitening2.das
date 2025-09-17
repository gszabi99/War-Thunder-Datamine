require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

require %dasGameLibs.math
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


struct Colors
  white  = E3DCOLOR(Color4(float4(1.000, 1.000, 1.000, 1.000))) //#FFFFFF
  black  = E3DCOLOR(Color4(float4(0.000, 0.000, 0.000, 1.000))) //#000000
  none   = E3DCOLOR(0x0)
  mask   = E3DCOLOR(0xFF000000)
  blue   = E3DCOLOR(Color4(float4(0.000, 0.784, 1.000, 1.000))) //#00C8FF


enum MasterMode
  AA
  AG


struct Spi
  isActive  : bool    = false
  pos       : float3  = float3(0.0)


struct PropStorage
  fontId : int
  fontScale : float
  lineWidthScale : float
  borderless : bool


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
  totalTime : float
  ammo : table<string, int>
  spi : Spi = Spi()
  props : PropStorage

  isArmed : bool = false
  isWeaponSelectorOn : bool = false
  isThermalActive : bool = false
  defaultFontSize : int = 24
  defaultLineWidth : float = 3.0
  targetPos : float3 = float3(0.0)
  isCalculatedRangeValid : bool = false
  isPointTracking : bool = false
  isAreaTracking : bool = false
  isInertialTracking : bool = false
  isLaserDesignatorEnabled : bool = false
  isNaro : bool = false
  masterMode : MasterMode = MasterMode.AG
  borderOffset : float = 0.0


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
    setColor(colors.white)
    defaultLineWidth *= props.lineWidthScale
    setLineWidth(defaultLineWidth)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFont(props.fontId)
    defaultFontSize = roundi(float(defaultFontSize) * props.fontScale)
    setFontSize(defaultFontSize)

    isArmed = !(fmw.isOnGround || fm.currentAlt < fmw.minAltitudeForDropShells)
    isWeaponSelectorOn = app.flightControlMode.isWeaponSelectorOn
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
    if get_point_of_interest(spi.pos)
      spi.isActive = true
    isNaro = cockpit.mfdZoom > 0.5
    masterMode = getMasterMode()


  def getMasterMode()
    if (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET))
      return MasterMode.AA
    elif (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_ROCKET))
      return MasterMode.AG
    return MasterMode.AA


  def drawOsbLabel(pos : float2, text : string, anchorHorz : AnchorHorz, anchorVert : AnchorVert, vert : bool = false)
    var bbox = BBox2()
    if !vert
      bbox = drawStrAnchored(pos, text, anchorHorz, anchorVert)
    else
      bbox = drawStrVerticalAnchored(pos, text, 0.0, anchorHorz, anchorVert)
    if props.borderless
      return
    let size = vert ? toRelXY(bbox.width) * float2(1.0, 0.6) : toRelXY(bbox.width) * float2(0.5, 0.8)
    setColor(colors.black)
    if anchorHorz == AnchorHorz.Left
      drawLine(float2(-0.5 + borderOffset, pos.y + size.y), float2(-0.5 + borderOffset, pos.y - size.y))
    elif anchorHorz == AnchorHorz.Right
      drawLine(float2(0.5 - borderOffset, pos.y + size.y), float2(0.5 - borderOffset, pos.y - size.y))
    elif anchorVert == AnchorVert.Bottom
      drawLine(float2(pos.x + size.x, 0.5 - borderOffset), float2(pos.x - size.x, 0.5 - borderOffset))
    elif anchorVert == AnchorVert.Top
      drawLine(float2(pos.x + size.x, -0.5 + borderOffset), float2(pos.x - size.x, -0.5 + borderOffset))
    setColor(colors.white)


  def drawOsbLabels()
    let osbCount = 5
    let inset = 0.2
    let step = (1.0 - inset - inset) / float(osbCount - 1)
    let margin = !props.borderless ? 0.045 : 0.01
    let p0 = 0.5 - margin
    let p1 = 0.5 - inset
    setFillColor(colors.white)

    let masterModeStr = masterMode == MasterMode.AA ? "A-A" : "A-G"
    // Left
    drawOsbLabel(float2(-p0, -p1), " 0Z", AnchorHorz.Left, AnchorVert.Center)
    drawOsbLabel(float2(-p0, -p1 + step), "GRAY", AnchorHorz.Left, AnchorVert.Center)
    // Bottom
    drawOsbLabel(float2(-p1, p0), "SWAP", AnchorHorz.Center, AnchorVert.Bottom)
    drawOsbLabel(float2(-p1 + step, p0), "FCR", AnchorHorz.Center, AnchorVert.Bottom)
    drawBBox(getStrBbox(float2(-p1 + step * 2.0, p0), "TGP", AnchorHorz.Center, AnchorVert.Bottom), 0.0)
    setColor(colors.black)
    drawStrAnchored(float2(-p1 + step * 2.0, p0), "TGP", AnchorHorz.Center, AnchorVert.Bottom)
    setColor(colors.white)
    drawOsbLabel(float2(-p1 + step * 3.0, p0), "SMS", AnchorHorz.Center, AnchorVert.Bottom)
    drawOsbLabel(float2(-p1 + step * 4.0, p0), "DCLT", AnchorHorz.Center, AnchorVert.Bottom)
    // Right
    if isThermalActive
      drawOsbLabel(float2(p0, -p1), "WHOT", AnchorHorz.Right, AnchorVert.Center)
    drawOsbLabel(float2(p0, -p1 + step), "LSS", AnchorHorz.Right, AnchorVert.Center)
    drawOsbLabel(float2(p0, -p1 + step * 2.0), "SP", AnchorHorz.Right, AnchorVert.Center, true)
    drawOsbLabel(float2(p0, -p1 + step * 3.0), "CZ", AnchorHorz.Right, AnchorVert.Center, true)
    drawOsbLabel(float2(p0, -p1 + step * 4.0), "TGT", AnchorHorz.Right, AnchorVert.Center, true)
    // Top
    drawOsbLabel(float2(p1, -p0), "CNTL", AnchorHorz.Center, AnchorVert.Top)
    drawOsbLabel(float2(p1 - step, -p0), "OVRD", AnchorHorz.Center, AnchorVert.Top)
    drawOsbLabel(float2(p1 - step * 2.0, -p0), isNaro ? "NARO" : "WIDE", AnchorHorz.Center, AnchorVert.Top)
    drawOsbLabel(float2(p1 - step * 3.0, -p0), isThermalActive ? "FLIR" : "TV", AnchorHorz.Center, AnchorVert.Top)
    drawBBox(getStrBbox(float2(p1 - step * 4.0, -p0), "A-A", AnchorHorz.Center, AnchorVert.Top), 0.0)
    setColor(colors.black)
    drawStrAnchored(float2(p1 - step * 4.0, -p0), masterModeStr, AnchorHorz.Center, AnchorVert.Top)
    setColor(colors.white)

    setFillColor(colors.none)


  def drawTimeToImpact()
    let toi = (*wc).getLastGuidedWeaponHitTime(int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
    return if toi < 0.0
    let timeToShowZeroValue = 1.5
    if toi > totalTime - timeToShowZeroValue
      let time = clamp(roundi(toi - totalTime), 0, 99)
      let min = fmt(":03d", time / 60)
      let sec = fmt(":02d", time % 60)
      drawStrAnchored(float2(0.3, 0.38), "{min}:{sec}", AnchorHorz.Center, AnchorVert.Bottom)


  def drawRalt()
    return if abs(fmw.roll) > 45.0 || abs(fmw.tangage) > 45.0

    let ralt = fmw.fm.currentAlt * metrToFeet
    setFontSize(roundi(float(defaultFontSize) * 0.8))
    drawStrAnchored(float2(0.42, -0.4), "{floori(ralt / 10.0) * 10}", AnchorHorz.Right, AnchorVert.Top)
    setFontSize(defaultFontSize)


  def drawLaserStatus()
    let prfCode = 1511
    let blinksPerSecond = 1.5
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    return if isBlink && isLaserDesignatorEnabled
    drawStrAnchored(float2(0.025, 0.36), "L{prfCode}", AnchorHorz.Center, AnchorVert.Bottom)


  def drawCfovRange()
    let pos = float2(-0.3, 0.3)
    let distNm = isCalculatedRangeValid ? min(length(targetPos - hero.unitTm[3]) * metrToNavMile, 99.9) : 99.9
    setFontSize(roundi(float(defaultFontSize) * 0.8))
    if distNm > 1.0
      drawStrAnchored(pos, fmt(":.1f", distNm), AnchorHorz.Right, AnchorVert.Bottom)
    else
      let distFt = roundi(distNm * NmToFt / 100.0) * 100
      drawStrAnchored(pos, "{distFt}", AnchorHorz.Right, AnchorVert.Bottom)
    // Ranging mode
    if isLaserDesignatorEnabled
      drawStrAnchored(pos - float2(0.15, 0.0), "L", AnchorHorz.Left, AnchorVert.Bottom)
    elif isAreaTracking
      drawStrAnchored(pos - float2(0.15, 0.0), "T", AnchorHorz.Left, AnchorVert.Bottom)
    setFontSize(defaultFontSize)


  def drawTrackingStatus()
    setFontSize(roundi(float(defaultFontSize) * 0.8))
    drawStrAnchored(float2(0.08, 0.22), "L", AnchorHorz.Center, AnchorVert.Center)
    if isPointTracking
      drawStrAnchored(float2(-0.05, 0.22), "POINT", AnchorHorz.Center, AnchorVert.Center)
    elif isAreaTracking
      drawStrAnchored(float2(-0.05, 0.22), "AREA", AnchorHorz.Center, AnchorVert.Center)
    elif isInertialTracking
      drawStrAnchored(float2(-0.05, 0.22), "INR", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(defaultFontSize)


  def drawWeaponStatus()
    drawStrAnchored(float2(0.0, 0.41), isArmed ? "RDY" : "SIM", AnchorHorz.Center, AnchorVert.Bottom)


  def drawSituationalAwarenessIndicator()
    let size = float2(0.006)
    let area = float2(0.4)
    let occluder = float2(0.05)
    let targetPosLocal = fast_normalize(inverse(hero.unitTm) * targetPos)
    let screenPos = float2(-targetPosLocal.z * area.x, -targetPosLocal.x * area.y)
    if abs(screenPos.x) < abs(occluder.x) && abs(screenPos.y) < abs(occluder.y)
      return // Occlude near center for declutter
    setFillColor(colors.white)
    drawBox(-size + screenPos, size + screenPos)
    setFillColor(colors.none)


  def drawWaterlineSymbol()
    let pos = float2(-0.4, 0.35)
    let waterline = fixed_array<float2>(
      float2(-0.045, 0.000),
      float2(-0.030, 0.000),
      float2(-0.015, 0.020),
      float2(0.000, 0.000),
      float2(0.015, 0.020),
      float2(0.030, 0.000),
      float2(0.045, 0.000),
    )
    setColor(colors.blue)
    drawPolyLine(to_array(waterline).translate(pos))
    if !spi.isActive
      setColor(colors.white)
      return

    let delta = spi.pos - hero.unitTm[3]
    let angleTo = atan2_est(delta.x, delta.z)
    let heading = atan2_est(hero.unitTm[0].x, hero.unitTm[0].z)
    let diff = angle_diff(heading, angleTo)
    let diffRatio = diff / PI
    let displacement = float2(diffRatio * 0.05, 0.0)
    let line = float2(0.0, 0.05)
    drawLine(pos + line + displacement, pos - line + displacement)
    setColor(colors.white)


  def drawReticle()
    drawCrossReticle(float2(0.0), float2(0.22), float2(0.06))
    if isPointTracking
      drawBox(-float2(0.03), float2(0.03))
    if !isNaro
      let corner = fixed_array<float2>(
        float2(0.00, 0.04),
        float2(0.00, 0.00),
        float2(0.04, 0.00),
      ).translate(float2(-0.14))
      drawPolyLine(corner.to_array())
      drawPolyLine(corner.to_array().inv_y())
      drawPolyLine(corner.to_array().inv_x())
      drawPolyLine(corner.to_array().inv_y().inv_x())


  def drawBorder()
    setColor(colors.black)
    setLineWidth(defaultLineWidth * 7.5)
    borderOffset = toRelY(lineWidthHdpx)
    drawBox(float2(-0.5 +  borderOffset * 0.5), float2(0.5 - borderOffset * 0.5))
    setColor(colors.white)
    setLineWidth(defaultLineWidth * 0.5)
    drawBox(float2(-0.5 + borderOffset), float2(0.5 - borderOffset))
    setLineWidth(defaultLineWidth)


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawSituationalAwarenessIndicator()
    if !props.borderless
      drawBorder()
    drawOsbLabels()
    drawTimeToImpact()
    drawLaserStatus()
    drawTrackingStatus()
    drawWeaponStatus()
    drawRalt()
    drawCfovRange()
    drawWaterlineSymbol()
    drawReticle()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.fontScale = getFloat(props, "fontScale", 1.0)
  propStorage.lineWidthScale = getFloat(props, "lineWidthScale", 1.0)
  propStorage.borderless = getBool(props, "borderless", false)
