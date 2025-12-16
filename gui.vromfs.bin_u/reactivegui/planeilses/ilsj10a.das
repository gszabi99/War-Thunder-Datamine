require %rGui.utils.avionics_common
require %rGui.utils.canvas_common
require %rGui.utils.helpers_common
require %rGui.utils.constants_common
require %rGui.utils.radar_common

require %dasGameLibs.math.base
require %daslib.match
require %game.utils.utils_common
require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require GamePhys
require GuidanceLock
require HeroManager
require hud
require math
require Plane
require RadarHud
require strings
require Unit
require Weapon
require WTCamera

struct PropStorage
  fontId        : int
  isMetricUnits : bool
  ilsFovDeg     : float2
  langId        : int

let
  COLOR_NULL = E3DCOLOR(0x0)
  COLOR_MASK = E3DCOLOR(0xFF000000)
  BLINKS_PER_S_OUT_OF_BOUNDS = 4.0
  BLINKS_PER_S_MASTER_CAUTION = 2.0

class Component : Canvas
  isValid          : bool
  isMetricUnits    : bool
  hudFov           : float2
  defaultLineWidth : float
  defaultFontSize  : int
  defaultColor     : E3DCOLOR
  langId           : int

  app     : AcesApp?
  hero    : Unit?
  fmw     : FlightModelWrap?
  fcm     : FlightControlMode?
  cockpit : FlightModelCockpit?

  secondaryWeapon : Weapon?
  fpm             : FlightPathMarker
  track           : Track
  totalTime       : float
  spi             : SensorPointOfInterest
  gunBoresight    : GunBoresight
  guidance        : Guidance
  radar           : RadarState

  visual     : Visual
  limits     : LimitsEllipse
  isArmed    : bool
  mode       : WeaponMode
  masterMode : MasterMode

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    app = get_app()
    return if app == null
    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null
    fcm = app.flightControlMode
    return if fcm == null
    cockpit = fmw.cockpit
    return if cockpit == null

    isValid = true

    isMetricUnits = props.isMetricUnits
    hudFov = deg_to_rad(props.ilsFovDeg)
    langId = props.langId

    defaultColor = *fmw.cockpit->getPageColor(MfdPageType.MFD_PLANE_ILS)
    defaultLineWidth = floor(3.0 * fmw.cockpit.ilsLineWidthScale)
    defaultFontSize = 30
    setColor(defaultColor)
    setLineWidth(defaultLineWidth)
    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFontSize(defaultFontSize)

    limits <- LimitsEllipse(center = float2(0.0), radius = float2(0.48))
    get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
      secondaryWeapon := weapon
    totalTime = float(app.usefulTotalTime)
    visual <- avionics_common::get_visual(app.usefulTotalTime, hero)
    fpm <- avionics_common::get_flight_path_marker(visual.vel) <| $(world_pos : float3 const&; var screen_pos : float2&)
      return worldVecToHud(world_pos, screen_pos)
    clampFpm(fpm, limits)
    isArmed = avionics_common::get_armed_status(fmw)
    track <- avionics_common::get_track(hero) <| $(world_pos : float3 const&; var screen_pos : float2&)
      return worldPosToHud(world_pos, screen_pos)
    spi <- avionics_common::get_sensor_point_of_interest(hero) <| $(world_pos : float3 const&; var screen_pos : float2&)
      return worldPosToHud(world_pos, screen_pos)
    gunBoresight <- avionics_common::get_gun_boresight(hero) <| $(world_pos : float3 const&; var screen_pos : float2&)
      return worldPosToHud(world_pos, screen_pos)
    guidance <- get_guidance(secondaryWeapon)
    radar <- get_radar_state()
    mode = getWeaponDeliveryMode()
    masterMode = getMasterMode()

  def clampFpm(var in_fpm : FlightPathMarker&; lim : LimitsEllipse const&)
    avionics_common::clamp_pos(in_fpm.screenPos, in_fpm.screenPos, lim)

  def getWeaponDeliveryMode() : WeaponMode
    let trigger = secondaryWeapon?.trigger_no ?? -1
    if fmw.sightMode == CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET && trigger == WeaponTriggerType.AAM_TRIGGER
      return WeaponMode.AA_MISSILE
    if fmw.sightMode == CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS || fmw.sightMode == CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET
      return track.isActive ? WeaponMode.AA_GUN_RANGED : WeaponMode.AA_GUN_UNRANGED
    if fmw.sightMode == CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS
      return WeaponMode.AG_GUN
    if fmw.sightMode == CockpitSightMode.HUD_SIGHT_MODE_GROUND_ROCKET && trigger == WeaponTriggerType.ROCKETS_TRIGGER
      return WeaponMode.AG_ROCKET
    if trigger == WeaponTriggerType.AGM_TRIGGER
      return WeaponMode.AG_MISSILE
    if trigger == WeaponTriggerType.BOMBS_TRIGGER || trigger == WeaponTriggerType.GUIDED_BOMBS_TRIGGER
      if fmw.sightMode == CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO && spi.isSet
        return WeaponMode.AG_BOMB_CCRP
      if fmw.sightMode == CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS && !spi.isSet
        return WeaponMode.AG_BOMB_CCIP
    return WeaponMode.INVALID

  def getMasterMode() : MasterMode
    if mode > WeaponMode.AA_GUN_MIN && mode < WeaponMode.AA_GUN_MAX
      return MasterMode.DGFT
    if mode > WeaponMode.AA_MIN && mode < WeaponMode.AA_MAX
      return MasterMode.AA
    if mode > WeaponMode.AG_MIN && mode < WeaponMode.AG_MAX
      return MasterMode.AG
    return MasterMode.INVALID

  def drawFpm()
    if !fpm.isScreenPosValid
      return
    assume pos = fpm.screenPos
    let radius = 0.013
    drawCircle(pos, radius)
    let right0 = float2(radius, 0.0)
    let right1 = float2(2.5 * radius, 0.0)
    let up0 = float2(0.0, radius)
    let up1 = float2(0.0, 2.5 * radius)
    drawLine(pos - right0, pos - right1)
    drawLine(pos + right0, pos + right1)
    drawLine(pos - up0, pos - up1)

  def drawPitchLadder()
    setFontSize(roundi(float(defaultFontSize) * 0.9))
    let stepDeg = 5.0
    let stepRel = stepDeg / rad_to_deg(hudFov.y)

    let spaceWidth = 0.07
    let markWidth = 0.05
    let dashWidth = 0.0075
    let serifWidth = 0.015
    let count = roundi(toRelY(length(canvasSize)) / stepRel)
    let tangage5deg = rad_to_deg(visual.euler.y) / 5.0
    let marksVertOffset = fract(tangage5deg) * stepRel
    let markStartX = 0.5 * spaceWidth
    let roll = -visual.euler.z
    var sina = 0.0
    var cosa = 0.0
    sincos(roll, sina, cosa)
    let fpmRotated = rotate(fpm.screenPos, sina, cosa)
    let zeroPos = float2(fpmRotated.x, 0.0)
    setRotation(float2(0.0), -roll)
    setTextAnchorHorz(AnchorHorz.Left)

    for i in -count..count + 1
      let markTangage5deg = floori(tangage5deg) - i
      if abs(markTangage5deg) > 18
        continue
      let markOffset = marksVertOffset + float(i) * stepRel
      let pos = zeroPos + float2(0.0, markOffset)
      var markEndX = 0.5 * spaceWidth + markWidth
      let markEndY = 0.0
      if markTangage5deg > 0
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(markEndX, -markEndY)
        let p2 = float2(markEndX, -markEndY + serifWidth)
        drawLine(pos + p1, pos + p0)
        drawLine(pos + p1, pos + p2)
        drawLine(pos + inv_x(p1), pos + inv_x(p0))
        drawLine(pos + inv_x(p1), pos + inv_x(p2))
      elif markTangage5deg < 0
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(markEndX, -markEndY)
        let p2 = float2(markEndX, -markEndY - serifWidth)
        drawDashedLine(pos + p1, pos + p0, dashWidth, dashWidth)
        drawLine(pos + p1, pos + p2)
        drawDashedLine(pos + inv_x(p1), pos + inv_x(p0), dashWidth, dashWidth)
        drawLine(pos + inv_x(p1), pos + inv_x(p2))
      else
        markEndX *= 1.4
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(markEndX, -markEndY)
        let p2 = float2(markEndX, -markEndY + serifWidth)
        drawLine(pos + p1, pos + p0)
        drawLine(pos + p1, pos + p2)
        drawLine(pos + inv_x(p1), pos + inv_x(p0))
        drawLine(pos + inv_x(p1), pos + inv_x(p2))

      let str = "{abs(markTangage5deg * 5)}"
      let strSize = getStringSize(str)
      let dx = 0.004 + markEndX
      let dy = 0.008 * float(sign(markTangage5deg))
      drawStrAnchored(pos + float2(dx, dy), str, AnchorHorz.Left, AnchorVert.Center)
      drawStrAnchored(pos + float2(-dx, dy), str, AnchorHorz.Right, AnchorVert.Center)
    resetViewTm()
    setFontSize(defaultFontSize)

  def drawIasIndicator()
    let ias = fmw.ias * (isMetricUnits ? MPS_TO_KPH : MPS_TO_KTS)
    let size = float2(0.015, 0.36)
    let pos = float2(-0.365, -0.185)
    let stepSize = 10.0
    let stepCount = 16
    let iasStr = fmt(":4", roundi(ias))
    let isFlipped = false

    drawVerticalLadder(ias, pos, size, stepCount, stepSize, iasStr, isFlipped) <| $(val : int)
      return fmt(":2", val)

  def drawAltIndicator()
    let alt = (hero.unitTm[3].y - app.currentScene.waterLevel) * (isMetricUnits ? 1.0 : M_TO_FT)
    let size = float2(0.015, 0.36)
    let pos = float2(0.365, -0.185)
    let stepSize = 100.0
    let stepCount = 16
    let altStr = fmt(":5", roundi(alt))
    let isFlipped = true

    drawVerticalLadder(alt, pos, size, stepCount, stepSize, altStr, isFlipped) <| $(val : int)
      let isNegative = val < 0
      let whole = val / 10
      let rem = abs(val) % 10
      return isNegative ? "-{fmt(":1", whole)},{rem}" : "{fmt(":2", whole)},{rem}"

  def drawVerticalLadder(val : float;
                         pos : float2;
                         size : float2;
                         step_count : int;
                         step_sz : float;
                         val_str : string;
                         flip_x  : bool;
                         fmt : block<(val : int) : string>)
    let lt = pos - 0.5 * size
    let rb = pos + 0.5 * size
    let stepRel = size.y / float(step_count)
    let stepVal = val / step_sz
    let anchorInt = floor(stepVal + 0.5)
    let anchorText = flip_x ? AnchorHorz.Left : AnchorHorz.Right
    let shiftPixels = (stepVal - float(anchorInt)) * stepRel
    let halfCount = int(step_count / 2) + 1
    let baseX = flip_x ? lt.x : rb.x
    let direction = flip_x ? 1.0 : -1.0
    // Ladder
    for i in -halfCount..halfCount + 1
      let y = pos.y + (float(i) * stepRel) + shiftPixels
      if y > lt.y && y < rb.y
        let p1 = float2(baseX, y)
        var p2 = float2(baseX, y)
        let strVal = int(anchorInt) - i
        if strVal % 5 != 0
          p2.x += size.x * 0.75 * direction
        else
          p2.x += size.x * direction
          let strPos = flip_x ? p2 + float2(0.005, 0.0) : p2 - float2(0.005, 0.0)
          let str = fmt |> invoke(strVal)
          drawStrAnchored(strPos, str, anchorText, AnchorVert.Center)
        drawLine(p1, p2)
    // Boxed value
    let padding = 0.005
    let strPos = float2(baseX + padding * direction, pos.y)
    let box = getStrBbox(strPos, val_str, anchorText, AnchorVert.Center)
    setFillColor(COLOR_MASK)
    drawBBox(box, padding)
    setFillColor(COLOR_NULL)
    drawStrAnchored(strPos, val_str, anchorText, AnchorVert.Center)

  def drawHeadingTape()
    let size = float2(0.66, 0.06)
    let pos = float2(0.0, -0.4)
    let forward = quat_get_forward(visual.quat)
    let heading = atan2(forward.x, forward.z)
    let lt = pos - 0.5 * size
    let rb = pos + 0.5 * size
    let count = 4
    let stepRel = size.x / float(count)
    let heading10deg = (0.5 * float(count + 1) - heading * 36.0 / TWOPI) % 36.0
    let linesOffset = fract(heading10deg) * stepRel
    let dotsOffset = fract(0.5 + heading10deg) * stepRel
    setViewport(lt, rb)

    for i in 0..count + 1
      let x = lt.x + (float(i) - 0.5) * stepRel
      let lineTop = float2(x + linesOffset, rb.y - 0.35 * size.y)
      let lineBottom = float2(x + linesOffset, rb.y)
      let str = fmt(":02", ((36 - floori(heading10deg) + i) % 36))
      let strSize = getStringSize(str, 2)
      let strPos = lineTop
      if strPos.x + strSize.x < rb.x && strPos.x - strSize.x > lt.x
        drawLine(lineTop, lineBottom)
        drawStrAnchored(strPos, str, AnchorHorz.Center, AnchorVert.Bottom)
      let lineCenterTop = float2(x + dotsOffset, rb.y - 0.2 * size.y)
      let lineCenterBottom = float2(x + dotsOffset, rb.y)
      if lineCenterBottom.x + strSize.x < rb.x && lineCenterBottom.x - strSize.x > lt.x
        drawLine(lineCenterTop, lineCenterBottom)

    restoreViewport()
    let centerMarkHt = 0.03
    let centerMarkPos = pos + float2(0.00, 0.5 * size.y - centerMarkHt * 0.25)
    drawLine(centerMarkPos, centerMarkPos + float2(0.0, centerMarkHt))

  def drawLosTarget()
    if !track.isActive
      return
    let lim <- LimitsEllipse(center = float2(0.0), radius = float2(0.4))
    let size = float2(0.022)
    var clampedPos : float2
    let isTargetOnScreen = avionics_common::clamp_pos(track.screenPos, clampedPos, lim)
    let isBlink = fract(BLINKS_PER_S_OUT_OF_BOUNDS * totalTime) < 0.5
    if isTargetOnScreen || isBlink
      if !test_any_flags(radar.flags, RadarStateFlags.MEM)
        drawBox(
          float2(clampedPos - size),
          float2(clampedPos + size))
      else
        let gap = 0.015
        let corner = fixed_array(
          float2(gap, size.y),
          float2(size.x, size.y),
          float2(size.x, gap))
        drawPolyLine(corner.to_array().translate(clampedPos))
        drawPolyLine(corner.to_array().inv_x().translate(clampedPos))
        drawPolyLine(corner.to_array().inv_y().translate(clampedPos))
        drawPolyLine(corner.to_array().inv_y().inv_x().translate(clampedPos))
      if !isTargetOnScreen
        let arrowLength = float2(0.02, 0.1)
        let arrowLineLength = 0.1
        let arrowOffset = -arrowLineLength
        let arrowStart = fast_normalize(clampedPos) * (length(clampedPos) - arrowOffset)
        let arrowEnd = fast_normalize(clampedPos) * (length(clampedPos) - arrowOffset - arrowLineLength)
        drawArrowHead(arrowStart, clampedPos, arrowLength)
        drawLine(arrowStart, arrowEnd)

  def drawRollIndicator()
    let pos = float2(0.0, 0.03)
    let divs = 24
    let interval = TWOPI / float(divs)
    var sina, cosa : float
    let half = divs / 2
    let down = half / 2
    let gap = 0.25
    for i in 2..half - 1
      var length = 0.015
      if i == down
        length *= 2.0
      let angle = float(i) * interval
      sincos(angle, sina, cosa)
      let end = gap - length
      let startPos = float2(gap * cosa, gap * sina) + pos
      let endPos = float2(end * cosa, end * sina) + pos
      drawLine(startPos, endPos)

    var triangle = fixed_array(
      float2(0.00, 0.00),
      float2(-0.01,  0.01),
      float2(0.01,  0.01),
    )
    let limit = 4.0 * interval
    let clampedRoll = clamp(visual.euler.z, -limit, limit)
    sincos(clampedRoll, sina, cosa)
    drawClosedPolyLine(triangle.translate(float2(0.0, gap)).rotate(sina, cosa).translate(pos).to_array())

  def drawBoresightCross()
    let pos = float2(0.0, -0.3)
    let size = float2(0.035)
    if masterMode == MasterMode.DGFT
      drawCrossReticle(gunBoresight.screenPos, size, float2(0.0))
    else
      drawCrossReticle(pos, size, float2(0.0))

  def drawMasterArm()
    let pos = float2(-0.27, 0.1)
    drawStrAnchored(pos, isArmed ? "WPN RDY" : "SAFE", AnchorHorz.Right, AnchorVert.Bottom)

  def drawMach()
    let pos = float2(-0.42, 0.05)
    drawStrAnchored(pos, "M{fmt(":>5.2f", fmw.fm.Mach)}", AnchorHorz.Left, AnchorVert.Bottom)

  def drawVsi()
    let pos = float2(0.35, -0.26)
    let vertSpeed = hero.vel.y * (isMetricUnits ? 1.0 : MPS_TO_FPM * 1e-2)
    drawStrAnchored(pos, "{roundi(vertSpeed)}", AnchorHorz.Right, AnchorVert.Top)

  def drawAoa()
    let pos = float2(-0.42, -0.43)
    drawStrAnchored(pos, "α{fmt(":4d", roundi(fmw.fm.aoa))}", AnchorHorz.Left, AnchorVert.Top)

  def drawLoadFactor()
    let pos = float2(-0.42, -0.47)
    let load = max(float(fmw.fm.localAccel.y) * safeinv(gravity()) + 1.f, -9.9)
    drawStrAnchored(pos, "G{fmt(":4.1f", load)}", AnchorHorz.Left, AnchorVert.Top)

  def drawRadarMode()
    if !radar.isEmitting
      return
    let pos = float2(0.32, 0.1)
    let str = Radar`getModeNameLoc(langId)
    drawStrAnchored(pos, str, AnchorHorz.Left, AnchorVert.Bottom)

  def drawMasterMode()
    let pos = float2(-0.4, 0.15)
    var modeStr = ""
    var subModeStr = ""
    match masterMode
      if MasterMode.DGFT
        modeStr = "DGFT"
      if MasterMode.AA
        modeStr = "INTC"
      if MasterMode.AG
        modeStr = "AG"

    if mode == WeaponMode.AG_BOMB_CCIP || mode == WeaponMode.AG_ROCKET || mode == WeaponMode.AG_GUN
      subModeStr = "CCIP"
    elif mode == WeaponMode.AG_BOMB_CCRP
      subModeStr = "AUTO"
    drawStrAnchored(pos, "{modeStr} {subModeStr}", AnchorHorz.Left, AnchorVert.Bottom)

  def drawAamIrSeekerIndicator()
    if guidance.guidanceType == GuidanceType.TYPE_OPTICAL && int(guidance.lockState) >= int(GuidanceLockState.RESULT_LOCKING)
      let seeker = get_hud_aam_seeker()
      if seeker.isScreenPosValid
        var clampedPos : float2
        let pos = toRelPos(seeker.screenPos)
        let isTargetOnScreen = avionics_common::clamp_pos(pos, clampedPos, limits)
        let isBlink = fract(BLINKS_PER_S_OUT_OF_BOUNDS * totalTime) < 0.5
        if isTargetOnScreen || isBlink
          drawCircle(clampedPos, 0.02)

  def drawFuel()
    let pos = float2(0.47, 0.3)
    let fuel = getFuelMassCurrent(fmw.fm.M) * (isMetricUnits ? 1.0 : KG_TO_LBS)
    let str = "{fmt(":+4d", floori(fuel))} {isMetricUnits ? "KG" : "LBS"}"
    drawStrAnchored(pos, str, AnchorHorz.Right, AnchorVert.Top)

  def drawEegs()
    // Bullet lines
    let absMul = 0.01 * canvasSize
    var bulletImpactLines : array<float2>
    get_bullet_impact_points(0) <| $(var points : array<float2>#)
      for p in points
        if p.x == -1.0 && p.y == -1.0
          continue
        bulletImpactLines.push(toRelPos(p * absMul))
    bulletImpactLines.resize(max(0, bulletImpactLines.length() - 1))
    if bulletImpactLines.empty()
      return
    drawPolyLine(bulletImpactLines)
    // Gyro reticle
    let rangeMax = 4800.0 * FT_TO_M
    let rangeMin = 0.0
    let closureRateMax = 2400.0 * KTS_TO_KPH * KPH_TO_MPS

    let gyro <- avionics_common::get_gun_gyro_pos(fcm, fmw.props, hero.unitTm) <| $(world_pos : float3 const&; var screen_pos : float2&)
      return worldPosToHud(world_pos, screen_pos)
    if !gyro.isScreenPosValid
      return
    let sizeInner = 0.006
    let sizeOuter = 0.05
    let markLength = 0.015
    let rangeClamped = clamp(track.distance, rangeMin, rangeMax)
    let relRange = (rangeClamped - rangeMin) / (rangeMax - rangeMin)
    let angleSectorRange = 1.5 * PI + TWOPI * relRange
    // Range sector
    drawCircle(gyro.screenPos, sizeInner)
    setLineWidth(2.0 * defaultLineWidth)
    drawSector(gyro.screenPos, float2(sizeOuter), float2(1.5 * PI, angleSectorRange))
    setLineWidth(defaultLineWidth)
    // Marks
    let divs = 12
    let interval = TWOPI / float(divs)
    var sina, cosa = 0.0
    for i in 0..divs
      let start = 0.0
      let angle = float(i) * interval
      sincos(angle, sina, cosa)
      let end = sizeOuter + (i % 3 == 0 ? markLength * 1.2 : markLength)
      let startPos = float2((sizeOuter + start) * cosa + gyro.screenPos.x, (sizeOuter + start) * sina + gyro.screenPos.y)
      let endPos = float2(end * cosa + gyro.screenPos.x, end * sina + gyro.screenPos.y)
      drawLine(startPos, endPos)
    // Closure rate arrow
    let closureRate = min(track.distanceRate * -1.0, closureRateMax - FLT_EPSILON)
    if closureRate <= 0.0
      return
    let angleClosureRate = (closureRate / closureRateMax) * TWOPI
    sincos(angleClosureRate, sina, cosa)
    let arrow = fixed_array(float2(-0.01, -markLength), float2(0.0), float2(0.01, -markLength))
    drawClosedPolyLine(arrow.to_array().translate(float2(0.0, -sizeOuter)).rotate(sina, cosa).translate(gyro.screenPos))

  def drawCcip()
    var impactPoint : ScreenPos
    match mode
      if WeaponMode.AG_ROCKET
        if fcm.isRocketImpactValid
          impactPoint.isScreenPosValid = true
          worldPosToHud(fcm.rocketImpactPosition, impactPoint.screenPos)
      if WeaponMode.AG_GUN
        if fcm.isCannonImpactValid
          impactPoint.isScreenPosValid = true
          worldPosToHud(fcm.cannonImpactPosition, impactPoint.screenPos)
      if WeaponMode.AG_BOMB_CCIP || WeaponMode.AG_BOMB_CCRP
        impactPoint.isScreenPosValid = true
        worldPosToHud(fcm.bombImpactPosition, impactPoint.screenPos)
      if _
        return
    if !impactPoint.isScreenPosValid
      return
    var clampedPos : float2
    let isTargetOnScreen = avionics_common::clamp_pos(impactPoint.screenPos, clampedPos, limits)
    let isBlink = fract(BLINKS_PER_S_OUT_OF_BOUNDS * totalTime) < 0.5
    if isTargetOnScreen || isBlink
      drawCircle(clampedPos, 0.022)
      drawDot(clampedPos)

  def drawRadarScanArea()
    if test_any_flags(radar.flags, RadarStateFlags.ACM)
      let lt = float2(get_radar_hud_scan_azimuth_min(), get_radar_hud_scan_elevation_max())
      let rb = float2(get_radar_hud_scan_azimuth_max(), get_radar_hud_scan_elevation_min())
      drawBox(angle_to_hud(lt, hudFov), angle_to_hud(rb, hudFov))

  def worldVecToHud(world_vec : float3 const&; var screen_pos : float2&)
    screen_pos = world_vec_to_hud(world_vec, hero.unitTm, hudFov)
    return true

  def worldPosToHud(world_pos : float3 const&; var screen_pos : float2&)
    screen_pos = world_pos_to_hud(world_pos, hero.unitTm, hudFov)
    return true

  def drawMasterCaution()
    let pos = float2(0.0, 0.1)
    setFontSize(roundi(float(defaultFontSize) * 1.3))
    var str = ""
    if test_any_flags(radar.flags, RadarStateFlags.ACM)
      str = "敌跟踪"
    if !str.empty() && fract(BLINKS_PER_S_MASTER_CAUTION * totalTime) < 0.5
      drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Center)
    setFontSize(defaultFontSize)

  def draw()
    return if !isValid

    setFullCanvasViewport()
    if masterMode != MasterMode.DGFT
      drawFpm()
      drawPitchLadder()
      drawHeadingTape()
      drawRollIndicator()
    if masterMode == MasterMode.AG
      drawCcip()
    drawMasterCaution()
    drawLosTarget()
    drawIasIndicator()
    drawAltIndicator()
    drawBoresightCross()
    drawMasterArm()
    drawMach()
    drawVsi()
    drawAoa()
    drawLoadFactor()
    drawFuel()
    drawMasterMode()
    drawRadarMode()
    drawAamIrSeekerIndicator()
    if masterMode == MasterMode.DGFT
      drawEegs()
      drawRadarScanArea()
    restoreViewport()

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.isMetricUnits = getBool(props, "isMetricUnits", true)
  propStorage.ilsFovDeg.x = getFloat(props, "ilsFovDegX", 20.0)
  propStorage.ilsFovDeg.y = getFloat(props, "ilsFovDegY", 20.0)
  propStorage.langId = getInt(props, "langId", -1)