require darg
require math
require strings
require app
require hud
require DagorSystem
require DagorMath
require DagorStdGuiRender
require Plane
require FlightModelWrap
require HeroManager
require Unit
require Sensors
require RadarHud
require Mission
require FlightControl
require Weapon
require WTCamera
require %game.utils.utils_common
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

let airGunDistance = 1000.0
let groundGunDistance = 2000.0
let groundRocketDistance = 10000.0 / metrToFeet
let bombingDistance = 10000.0

struct PropStorage
  fontId : int
  ilsFovDeg : float

struct Tracking
  isActive : bool
  pos : float3
  distance : float
  distanceRate : float
  dirNorm : float3
  angVel : float3
  ilsPosValid : bool
  ilsPos : float2

struct Guidance
  isActive : bool
  guidanceType : GuidanceType
  lockState : GuidanceLockState
  ilsPosValid : bool
  ilsPos : float2

struct Ccip
  ilsPosValid : bool
  ilsPos : float2

struct Ccrp
  isActive : bool
  timeToRelease : float

struct Radar
  isEmitting : bool
  isVerticalScan : bool
  isAcmMode : bool
  isTrkMode : bool
  azimuthMin : float
  azimuthMax : float
  elevationMin : float
  elevationMax : float

struct PointOfInterest
  isSet : bool
  pos : float3
  ilsPosValid : bool
  ilsPos : float2

class Component : Canvas
  isValid : bool
  ilsFovDeg : float
  defaultLineWidth : float
  defaultLineWidthHdpxRel : float

  hero : Unit?
  fmw : FlightModelWrap?
  wc : WeaponController?
  fcm : FlightControlMode?
  secondaryWeapon : Weapon?
  totalTime : float
  tvvPos : float2
  heading : float
  gearProgress : float
  gunBoresightPos : float2

  radar : Radar
  tracking : Tracking
  aamGuidance : Guidance
  agmGuidance : Guidance
  ccip : Ccip
  ccrp : Ccrp
  poi : PointOfInterest

  isDogFight : bool
  isAirGunMode : bool
  isGroundGunMode : bool
  isGroundRocketMode : bool
  isAamMode : bool
  isAgmMode : bool
  isBombingCcrpMode : bool
  isBombingCcipMode : bool
  isBombingGuidedMode : bool

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    fmw = hero.as_fmw()
    wc = hero.weap
    fcm = get_app().flightControlMode
    return if fmw == null || wc == null || fcm == null

    isValid = true
    ilsFovDeg = props.ilsFovDeg
    setColor(*fmw.cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS))
    defaultLineWidth = floor(4.0 * fmw.cockpit.ilsLineWidthScale)
    setLineWidth(defaultLineWidth)
    defaultLineWidthHdpxRel = toRelY(lineWidthHdpx)

    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)

    totalTime = float(get_total_time())
    let dirProjectionToIlsPos = 2.5
    tvvPos = -(float3x3(inverse(hero.unitTm)) * fast_normalize(hero.vel)).zy * dirProjectionToIlsPos;
    tvvPos = clamp(tvvPos, float2(-0.5), float2(0.5))

    let forward = hero.unitTm[0]
    heading = atan2(forward.x, forward.z)

    if get_point_of_interest(poi.pos)
      poi.isSet = true
      var ilsPos : float2
      if world_to_ils_screen(fmw, poi.pos, ilsPos)
        poi.ilsPosValid = true
        poi.ilsPos = toRelPos(ilsPos)

    gearProgress = fmw.fm.appliedCT.gear

    get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
      secondaryWeapon := weapon

    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        tracking.isActive = true
        tracking.pos = target.from + target.dirNorm * target.distance
        tracking.distance = target.distance
        tracking.distanceRate = target.distanceRate
        tracking.dirNorm = target.dirNorm
        tracking.angVel = target.angVel
        var ilsPos : float2
        if world_to_ils_screen(fmw, tracking.pos, ilsPos)
          tracking.ilsPosValid = true
          tracking.ilsPos = toRelPos(ilsPos)

    let aamLockState = get_aam_guidance_lock_state()
    let aamGuidanceType = get_cur_weapon_guidance_type()
    if aamLockState != GuidanceLockState.RESULT_INVALID && aamGuidanceType != GuidanceType.TYPE_INVALID
      aamGuidance.isActive = true
      aamGuidance.lockState = aamLockState
      aamGuidance.guidanceType = aamGuidanceType
      if get_ils_aam_tracker_visible()
        aamGuidance.ilsPosValid = true
        aamGuidance.ilsPos = toRelPos(get_ils_aam_tracker_pos())

    let agmLockState = get_agm_guidance_lock_state()
    let agmGuidanceType = get_cur_weapon_guidance_type()
    if agmLockState != GuidanceLockState.RESULT_INVALID && agmGuidanceType != GuidanceType.TYPE_INVALID
      agmGuidance.isActive = true
      agmGuidance.lockState = agmLockState
      agmGuidance.guidanceType = agmGuidanceType
      if get_agm_tracker_visible()
        var ilsPosAbs : float2
        agmGuidance.ilsPosValid = get_ils_agm_tracker_pos(fmw, ilsPosAbs)
        agmGuidance.ilsPos = toRelPos(ilsPosAbs)

    radar.isEmitting = get_radar_hud_is_emitting() || get_radar_hud_is_emitting2()
    radar.azimuthMin = get_radar_hud_scan_azimuth_min()
    radar.azimuthMax = get_radar_hud_scan_azimuth_max()
    radar.elevationMin = get_radar_hud_scan_elevation_min()
    radar.elevationMax = get_radar_hud_scan_elevation_max()
    radar.isAcmMode = find(get_radar_hud_mode_name(), "ACM") >= 0
    radar.isTrkMode = find(get_radar_hud_mode_name(), "track") >= 0
    radar.isVerticalScan = radar.elevationMax - radar.elevationMin > 2.0 * (radar.azimuthMax - radar.azimuthMin)

    let infVector = float3(10000.0, 0.0, 0.0)
    var ilsPos = float2(0.0)
    get_weapons_by_trigger_group(wc.Weapons, WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY) <| $(weapons : array<Weapon const? const> const#)
      for w in weapons
        let isGun = (w.trigger_no == int(WeaponTriggerType.MACHINE_GUNS_TRIGGER) ||
          w.trigger_no == int(WeaponTriggerType.CANNONS_TRIGGER) ||
          w.trigger_no == int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER))
        if !isGun
          continue
        var weaponTm : float3x4
        weapon_calcShootTm(w, hero.unitTm, weaponTm)
        if world_to_ils_screen(fmw, weaponTm * infVector, ilsPos)
          gunBoresightPos = toRelPos(ilsPos)
          break

    isAirGunMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) && secondaryWeapon == null))

    isGroundGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS)

    isGroundRocketMode = (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.ROCKETS_TRIGGER))

    isAamMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) && secondaryWeapon != null &&
      secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER))

    isAgmMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_ROCKET) && secondaryWeapon != null &&
      secondaryWeapon.trigger_no == int(WeaponTriggerType.AGM_TRIGGER))

    isDogFight = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (radar.isAcmMode || (radar.isTrkMode && tracking.isActive && tracking.distance < 2.0 * airGunDistance))))

    let isBombTrigger = (secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER) ||
      secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)))

    isBombingCcrpMode = poi.isSet && isBombTrigger && fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO)

    isBombingCcipMode = !poi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS) &&
       (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)))

    isBombingGuidedMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) &&
      (secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))))

    if get_ils_target_pos_valid()
      ccip.ilsPosValid = true
      ccip.ilsPos = toRelPos(get_ils_target_pos())

    if isBombingCcrpMode
      ccrp.isActive = true
      ccrp.timeToRelease = get_time_before_bomb_release()


  def drawTvvMark()
    let pos = tvvPos
    let radius = 0.015
    drawCircle(pos, radius)
    let right0 = float2(radius, 0.0)
    let right1 = float2(4.0 * radius, 0.0)
    let up0 = float2(0.0, radius)
    let up1 = float2(0.0, 3.0 * radius)
    drawLine(pos - right0, pos - right1)
    drawLine(pos + right0, pos + right1)
    drawLine(pos - up0, pos - up1)

  def drawFlightParams()
    let pos = float2(-0.42, -0.03)
    setTextAnchorHorz(AnchorHorz.Right)
    setCaretPosition(pos)
    setLineSpacing(1.4)
    setFontSize(35)

    let verts = [[float2
      float2(1.0, 0.0);
      float2(0.9, 0.0);
      float2(0.3, 1.0);
      float2(0.1, 1.0);
      float2(0.0, 0.75);
      float2(0.0, 0.25);
      float2(0.1, 0.0);
      float2(0.3, 0.0);
      float2(0.9, 1.0);
      float2(1.0, 1.0);
    ]]

    let offset = float2(-0.015, -0.022)
    let scale = float2(0.03, 0.02)
    let alphaVerts = verts.to_array().scale(scale).translate(pos + offset);
    drawPolyLine(alphaVerts)
    let aoaStr = fmt(":>5.1f", fmw.fm.aoa)
    printStrLn(" {aoaStr}")

    if fmw.fm.appliedCT.gear == 0.0
      let machStr = fmt(":>6.2f", fmw.fm.Mach)
      let overloadStr = fmt(":>5.1f", fmw.fm.localAccel.length() / 9.81 + 1.0)
      let maxOverloadStr = fmt(":>6.1f", fmw.cockpit.maxG)
      printStrLn("M{machStr}")
      printStrLn("G{overloadStr}")
      printStrLn(maxOverloadStr)


  def drawAltitude()
    // TODO: Make numbers blinking on low altitudes
    let pos = float2(0.4, -0.25)
    var altitude = roundi(fmw.fm.currentAlt * metrToFeet)

    if abs(fmw.fm.vertSpeed * metrToFeet) < 40.0
      altitude = altitude / 10 * 10
    else
      altitude = altitude / 100 * 100

    setFontSize(35)
    setTextAnchorHorz(AnchorHorz.Right)
    drawIntWithBiggerThousands(pos, altitude, 1.25, true, 2)


  def drawVerticalSpeed()
    let pos = float2(0.4, -0.30)
    let vspeed = 10 * roundi(6.0 * fmw.fm.vertSpeed * metrToFeet)
    setFontSize(35)
    setTextAnchorHorz(AnchorHorz.Right)
    drawStr(pos, string(vspeed))


  def drawIntegratedAirSpeed()
    let pos = float2(-0.3, -0.25)
    let ias = roundi(fmw.ias * mpsToKnots)
    setFontSize(40)
    setTextAnchorHorz(AnchorHorz.Right)
    drawIntWithBiggerThousands(pos, ias, 1.15, true, 1)


  def drawBankingAngle()
    let pos = float2(0.0, -0.25)
    let radius = 0.65
    let length = 0.02
    let angles = [[float -45.0; -30.0; -15.0; -5.0; 0.0; 5.0; 15.0; 30.0; 45.0;]]
    var sina = 0.0
    var cosa = 0.0
    let down = float2(0.0, 1.0)

    for angle in angles
      sincos(angle * degToRad, sina, cosa)
      let dir = rotate(down, sina, cosa)
      let p0 = pos + dir * radius
      let lengthMul = abs(angle) == 5.0 ? 0.5 : 1.0
      let p1 = pos + dir * (radius + length * lengthMul)
      drawLine(p0, p1)

    let roll = fmw.roll * degToRad
    sincos(-roll, sina, cosa)
    let dir = rotate(down, sina, cosa)
    let triangle = [[float2
      float2(0.0, 0.0);
      float2(0.7, -1.0);
      float2(-0.7, -1.0);
    ]]

    let size = float2(0.015)
    let arrPos = pos + dir * (radius - defaultLineWidthHdpxRel)
    var verts = triangle.to_array().rotate(sina, cosa).scale(size).translate(arrPos)
    drawClosedPolyLine(verts)


  def drawHeadingTape()
    let pos = float2(0.0, -0.4)
    let size = float2(0.6, 0.06)
    let lt = pos - 0.5 * size
    let rb = pos + 0.5 * size
    let count = 3
    let stepRel = size.x / float(count)
    let heading10deg = (0.5 * float(count + 1) - heading * 36.0 / PI2) % 36.0;
    let linesOffset = fract(heading10deg) * stepRel
    let dotsOffset = fract(0.5 + heading10deg) * stepRel
    setFontSize(35)
    setViewport(lt, rb)

    for i in range(0, count + 1)
      let x = lt.x + (float(i) - 0.5) * stepRel
      let lineTop = float2(x + linesOffset, rb.y - 0.35 * size.y)
      let lineBottom = float2(x + linesOffset, rb.y - defaultLineWidthHdpxRel)
      let dotPos = float2(x + dotsOffset, rb.y - defaultLineWidthHdpxRel)
      let str = fmt(":03", (36 - floori(heading10deg) + i) % 36)
      let strSize = getStringSize(str, 2)
      drawLine(lineTop, lineBottom)
      drawDot(dotPos)
      let fontDescend = getFontDescent()
      let strPos = lineTop + float2(0.0, -fontDescend)
      drawStrAnchored(strPos, str, AnchorHorz.Center, AnchorVert.Bottom)

    restoreViewport()
    let arrPos = pos + float2(0.00, 0.5 * size.y)
    let arrHeight = 0.02
    let arrHalfWidth = 0.012
    drawLine(arrPos, arrPos + float2(arrHalfWidth, arrHeight))
    drawLine(arrPos, arrPos + float2(-arrHalfWidth, arrHeight))


  def drawPitchLadder()
    let stepDeg = 5.0
    let stepRel = stepDeg / ilsFovDeg

    let spaceWidth = 0.13
    let markWidth = 0.09
    let dashWidth = 0.01
    let serifWidth = 0.02
    let count = roundi(toRelY(length(canvasSize)) / stepRel)
    let tangage5deg = fmw.tangage / 5.0
    let marksVertOffset = fract(tangage5deg) * stepRel
    let markStartX = 0.5 * spaceWidth
    let markEndX = 0.5 * spaceWidth + markWidth
    let roll = fmw.roll * degToRad
    var sina = 0.0
    var cosa = 0.0
    sincos(roll, sina, cosa)
    let tvvRotated = rotate(tvvPos, sina, cosa)
    let zeroPos = float2(tvvRotated.x, 0.0)
    setRotation(float2(0.0), -roll)
    setTextAnchorHorz(AnchorHorz.Left)

    for i in range(-count, count + 1)
      let markTangage5deg = floori(tangage5deg) - i
      if abs(markTangage5deg) > 18
        continue
      let markOffset = marksVertOffset + float(i) * stepRel
      let pos = zeroPos + float2(0.0, markOffset)
      let markEndY = float(markTangage5deg) / 22.0 * markWidth
      if markTangage5deg > 0
        let p0 = float2(markStartX, 0.0);
        let p1 = float2(markEndX, -markEndY);
        let p2 = float2(markEndX, -markEndY + serifWidth);
        drawLine(pos + p1, pos + p0)
        drawLine(pos + p1, pos + p2)
        drawLine(pos + inv_x(p1), pos + inv_x(p0))
        drawLine(pos + inv_x(p1), pos + inv_x(p2))
      elif markTangage5deg < 0
        let p0 = float2(markStartX, 0.0);
        let p1 = float2(markEndX, -markEndY);
        let p2 = float2(markEndX, -markEndY - serifWidth);
        let adjDashWidth = length(p2 - p1) / 7.0
        drawDashedLine(pos + p1, pos + p0, dashWidth, dashWidth)
        drawLine(pos + p1, pos + p2)
        drawDashedLine(pos + inv_x(p1), pos + inv_x(p0), dashWidth, dashWidth)
        drawLine(pos + inv_x(p1), pos + inv_x(p2))
      else
        let p0 = float2(markStartX, 0.0);
        let p1 = float2(1.5 * markEndX, -markEndY);
        let p2 = float2(1.5 * markEndX, -markEndY + 2.0 * serifWidth);
        drawLine(pos + p1, pos + p0)
        drawLine(pos + p1, pos + p2)
        drawLine(pos + inv_x(p1), pos + inv_x(p0))
        drawLine(pos + inv_x(p1), pos + inv_x(p2))

      if markTangage5deg != 0
        let str = "{abs(markTangage5deg * 5)}"
        let strSize = getStringSize(str)
        let dx = 0.01 + markEndX
        let dy = 0.005 * sign(markEndY) - markEndY
        drawStrAnchored(pos + float2(dx, dy), str, AnchorHorz.Left, AnchorVert.Center)
        drawStrAnchored(pos + float2(-dx, dy), str, AnchorHorz.Right, AnchorVert.Center)

    resetViewTm()


  def drawForwardPoint()
    return if gearProgress == 0.0

    let forward = hero.unitTm[0]
    let forwardPoint = hero.pos + forward * 10000.0
    var forwardPointOnIls = float2(0.0)
    if world_to_ils_screen(fmw, forwardPoint, forwardPointOnIls)
      let points = [[float2
        float2(-0.5, 0.0);
        float2(-0.25, 0.0);
        float2(-0.125, 0.175);
        float2(0.0, 0.0);
        float2(0.125, 0.175);
        float2(0.25, 0.0);
        float2(0.5, 0.0);
      ]]
      let scale = float2(0.1)
      let pos = toRelPos(forwardPointOnIls)
      let verts = points.to_array().scale(scale).translate(pos)
      drawPolyLine(verts)


  def drawSelectedAirWeapon()
    var pos = float2(0.0, 0.23)
    setFontSize(40)
    setTextAnchorHorz(AnchorHorz.Center)

    if isAirGunMode
      let bulletsCountPos = float2(-0.01, 0.4)
      let bulletsCount = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
      drawStr(pos, "GUN", 3)
      pos.y += 0.032
      drawStr(pos, "{bulletsCount}")
    elif isAamMode
      let rawName = get_hud_cur_weapon_name()
      return if rawName.empty()
      let shellCount = get_hud_cur_weapon_shell_count()
      let name1 = loc("{rawName}/f_15e/1")
      let name2 = loc("{rawName}/f_15e/2")
      drawStr(pos, "{name1}{name2} {shellCount}")


  def drawSelectedGroundWeapon()
    let pos = float2(0.33, -0.05)
    setFontSize(35)
    setCaretPosition(pos)
    setLineSpacing(1.0)

    if isGroundGunMode
      let bulletsCount = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
      let bulletsStr = bulletsCount > 0 ? fmt(":>4d", bulletsCount) : " XXX"
      printStrLn("CCIP")
      printStr("GUN{bulletsStr}")
    elif isGroundRocketMode
      let rocketsCount = wc.Weapons.countBullets(int(WeaponTriggerType.ROCKETS_TRIGGER))
      let rocketsStr = rocketsCount > 0 ? fmt(":>4d", rocketsCount) : " XXX"
      printStrLn("CCIP")
      printStr("RKT{rocketsStr}")
    elif isAgmMode
      let text = "MAVF"
      let size = getStringSize(text)
      printStr(text)
      if agmGuidance.isActive && agmGuidance.lockState != GuidanceLockState.RESULT_TRACKING
        drawLine(pos + float2(0.0, -size.y), pos + float2(size.x, 0.0))
        drawLine(pos + float2(0.0, 0.0), pos + float2(size.x, -size.y))
    elif isBombingCcipMode
      printStrLn("CCIP")
    elif isBombingCcrpMode || isBombingGuidedMode
      printStrLn("AUTO")
      var tth = (*wc).getLastGuidedWeaponHitTime(int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
      let timeToShowZeroValue = 2.0

      if tth > totalTime - timeToShowZeroValue
        let time = clamp(roundi(tth - totalTime), 0, 99)
        let timeStr = fmt(":>2d", time)
        printStr("{timeStr} TTI")
      elif ccrp.timeToRelease > 0.0 && ccrp.timeToRelease < 100.0
        let timeStr = fmt(":>2d", ceili(ccrp.timeToRelease))
        printStrLn("{timeStr} REL")

      let distanceStr = fmt(":>4.1f", length(poi.pos - hero.pos) * metrToMile)
      setTextAnchorHorz(AnchorHorz.Left)
      let distanceOffset = float2(-0.037, 0.09)
      drawStr(pos + distanceOffset, "{distanceStr} TGT")

      if fcm.ctrlMap.isLaserDesignatorEnabled
        setTextAnchorHorz(AnchorHorz.Center)
        drawStr(float2(0.0, -0.30), "LTD/R")


  def drawGunBoresight()
    return if !isAirGunMode

    let pos = gunBoresightPos
    let halfSize = 0.02
    drawLine(pos - float2(halfSize, 0.0), pos + float2(halfSize, 0.0))
    drawLine(pos - float2(0.0, halfSize), pos + float2(0.0, halfSize))


  def drawBulletImpactLines()
    return if !isAirGunMode || !get_bullet_impact_line_enabled() || tracking.isActive

    let absMul = 0.01 * canvasSize
    var bulletImpactLines1 : array<float2>
    var bulletImpactLines2 : array<float2>

    get_bullet_impact_points(1) <| $(var points : array<float2>#)
      for p in points
        if p.x == -1.0 && p.y == -1.0
          continue
        bulletImpactLines1.push(toRelPos(p * absMul))

    get_bullet_impact_points(2) <| $(var points : array<float2>#)
      for p in points
        if p.x == -1.0 && p.y == -1.0
          continue
        bulletImpactLines2.push(toRelPos(p * absMul))

    bulletImpactLines1.resize(max(0, bulletImpactLines1.length() - 1))
    bulletImpactLines2.resize(max(0, bulletImpactLines2.length() - 1))
    return if bulletImpactLines1.empty() || bulletImpactLines2.empty()

    drawPolyLine(bulletImpactLines1)
    drawPolyLine(bulletImpactLines2)
    let len1 = bulletImpactLines1.length()
    let len2 = bulletImpactLines2.length()
    let offs1 = 3
    let offs2 = 6
    if len1 - offs1 >= 0 && len2 - offs1 >= 0
      drawDot(lerp(bulletImpactLines1[len1 - offs1], bulletImpactLines2[len2 - offs1], 0.5))
    if len1 - offs2 >= 0 && len2 - offs2 >= 0
      drawDot(lerp(bulletImpactLines1[len1 - offs2], bulletImpactLines2[len2 - offs2], 0.5))


  def drawAirGunCcipReticle()
    return if !isAirGunMode || !ccip.ilsPosValid || !tracking.isActive || tracking.distance > 2.0 * airGunDistance

    let pos = ccip.ilsPos
    let radius = 0.1
    let effectiveDistanceCoeff = 0.7
    let effectiveDistance = effectiveDistanceCoeff * airGunDistance
    drawCircle(pos, radius)
    drawCircle(pos, 0.5 * defaultLineWidthHdpxRel)
    let currentDistanceAngle = PI - clamp(tracking.distance / airGunDistance * PI, 0.0, PI2)
    let effectiveDistanceAngle = PI - clamp(effectiveDistance / airGunDistance * PI, 0.0, PI2)

    var dir = float2(0.0)
    let markLength = 0.03
    sincos(currentDistanceAngle, dir.x, dir.y)
    drawLine(pos + dir * radius, pos + dir * (radius - markLength))
    sincos(effectiveDistanceAngle, dir.x, dir.y)
    drawLine(pos + dir * radius, pos + dir * (radius + markLength))

    setLineWidth(2.0 * defaultLineWidth)
    drawSector(pos, float2(radius), float2(-PI_2, PI_2 - currentDistanceAngle))
    setLineWidth(defaultLineWidth)

    let isPredictionValid = fcm.isCannonFireDirectionValid
    if tracking.distance < effectiveDistance && isPredictionValid
      setFontSize(45)
      let offset = getFontDescent() + defaultLineWidthHdpxRel
      drawStrAnchored(pos + float2(0.0, -radius - offset), "SHOOT", AnchorHorz.Center, AnchorVert.Bottom)

    let velRel = tracking.dirNorm * tracking.distanceRate + tracking.angVel * tracking.distance
    let velAbs = hero.vel + velRel
    let tmInv : float3x3 = float3x3(inverse(hero.unitTm))
    let velProjected = (tmInv * velAbs).zx
    let velDir = fast_normalize(velProjected)
    let wingDir = float2(-velDir.y, velDir.x)
    let wingLength = 0.06
    let wingGap = 0.02
    drawLine(pos + wingDir * wingGap, pos + wingDir * (wingGap + wingLength))
    drawLine(pos - wingDir * wingGap, pos - wingDir * (wingGap + wingLength))
    let velGap = 0.06
    let velLength = 0.01
    drawLine(pos - velDir * velGap, pos - velDir * (velGap + velLength))


  def drawProximityCross()
    let halfSize = 0.15
    drawLine(float2(-halfSize, -halfSize), float2(halfSize, halfSize))
    drawLine(float2(-halfSize, halfSize), float2(halfSize, -halfSize))


  def drawGroundGunAndRocketCcipReticle()
    let isGunCcipReady = isGroundGunMode && fcm.isCannonImpactValid
    let isRocketCcipReady = isGroundRocketMode && fcm.isRocketsConstantlyComputingSightActive && fcm.isRocketImpactValid

    var impactPos = float3(0.0)
    var inRangeDistance = 0.0
    var avoidRangeDistance = 0.0
    var ilsImpactPosAbs = float2(0.0)
    if isGunCcipReady && world_to_ils_screen(fmw, fcm.cannonImpactPosition, ilsImpactPosAbs)
      impactPos = fcm.cannonImpactPosition
      inRangeDistance = 2000.0
      avoidRangeDistance = 500.0
    elif isRocketCcipReady && world_to_ils_screen(fmw, fcm.rocketImpactPosition, ilsImpactPosAbs)
      impactPos = fcm.rocketImpactPosition
      inRangeDistance = 10000.0 / metrToFeet
      avoidRangeDistance = 500.0
    else
      return

    let pos = toRelPos(ilsImpactPosAbs)
    let radius = 0.08
    let markLength = 0.02
    let distMarkLength = 0.025

    var sina = 0.0
    var cosa = 0.0
    let distance = length(impactPos - hero.pos)
    let distMarkAngle = PI2 * max(distance * metrToFeet / 12000.0, 0.0)
    sincos(distMarkAngle, sina, cosa)

    if distMarkAngle > PI2
      drawCircle(pos, radius)
    else
      drawSector(pos, float2(radius), float2(-PI_2, -PI_2 + distMarkAngle))

    drawLine(pos + float2(sina, -cosa) * radius, pos + float2(sina, -cosa) * (radius - distMarkLength))
    drawCircle(pos, 0.5 * defaultLineWidthHdpxRel)

    for i in range(0, 12)
      let markAngle = PI2 * float(i) / 12.0
      sincos(markAngle, sina, cosa)
      let markDir = float2(sina, cosa)
      drawLine(pos + markDir * radius, pos + markDir * (radius + markLength))

    if distance < inRangeDistance
      setFontSize(45)
      let offset = float2(0.0, -radius - getFontDescent())
      drawStrAnchored(pos + offset, "IN RNG", AnchorHorz.Center, AnchorVert.Bottom)

    if distance < avoidRangeDistance
      drawProximityCross()


  def drawPullUpCue(impactPos : float3)
    return if !isBombingCcipMode && !isBombingCcrpMode

    let distance = length(impactPos - hero.pos)
    let pullUpOffsetY = min(distance / 20000.0, 0.4)
    let pullUpPos = tvvPos + float2(0.0, pullUpOffsetY)
    let pullUpScale = float2(0.08)
    let pullUpCuePoints = [[float2
      float2(0.3, 0.0);
      float2(0.9, 0.0);
      float2(1.0, -0.15);
    ]]
    drawPolyLine(pullUpCuePoints.to_array().scale(pullUpScale).translate(pullUpPos))
    drawPolyLine(pullUpCuePoints.to_array().scale(inv_x(pullUpScale)).translate(pullUpPos))


  def drawBombCcipReticle()
    return if !isBombingCcipMode || fmw.tangage > 15.0

    var impactPos = fcm.bombImpactPosition
    var ilsImpactPosAbs = float2(0.0)
    if !world_to_ils_screen(fmw, impactPos, ilsImpactPosAbs)
      return

    let pos = toRelPos(ilsImpactPosAbs)
    let crossSize = 0.05
    let from = tvvPos + float2(0.0, 0.015)
    let to = pos
    let dir = fast_normalize(to - from)
    let left = float2(-dir.y, dir.x)
    drawLine(from, to + dir * crossSize * 0.8)
    drawLine(pos + left * crossSize, pos - left * crossSize)
    drawPullUpCue(impactPos)

    let avoidRangeDistance = 500.0
    if length_sq(impactPos - hero.pos) < avoidRangeDistance * avoidRangeDistance
      drawProximityCross()


  def drawBombCcrpReticle()
    return if (!isBombingCcrpMode && !isBombingGuidedMode) || !poi.ilsPosValid

    let poiPosLocal = inverse(hero.unitTm) * poi.pos
    let isBehind = poiPosLocal.x < 0.0
    return if isBehind

    var sina = 0.0
    var cosa = 0.0
    sincos(-fmw.roll * degToRad, sina, cosa)
    let up = float2(sina, -cosa)
    let targetPos = poi.ilsPos
    let rayLength = length(targetPos) + 1.0
    drawLine(targetPos, targetPos + rayLength * up)
    drawLine(targetPos, targetPos - rayLength * up)

    let zeroOffset = dot(up, tvvPos - targetPos)
    let zeroPos = targetPos + up * zeroOffset
    drawPullUpCue(poi.pos)

    if ccrp.timeToRelease > 0.0
      let timeMarkWidth = 0.1
      let timeOffset = 0.03 * ccrp.timeToRelease + zeroOffset
      let timePos = targetPos + up * timeOffset
      let right = float2(cosa, sina)
      let upLeft = timePos - right * timeMarkWidth
      let upRight = timePos + right * timeMarkWidth
      drawLine(upLeft, upRight)

    let avoidRangeDistance = 500.0
    if length_sq(poi.pos - hero.pos) < avoidRangeDistance * avoidRangeDistance
      drawProximityCross()


  def drawPointOfInterest()
    return if !poi.ilsPosValid

    let pos = poi.ilsPos
    let size = 0.05
    let sideLen = 0.5 * size / SINCOS45
    let verts = [[float2
      float2(-0.5, 0.0);
      float2(0.0, -0.5);
      float2(0.5, 0.0);
      float2(0.0, 0.5);
    ]]
    let dash = sideLen * 0.3
    let space = sideLen * 0.4
    drawDashedClosedPolyLine(verts.to_array().scale(float2(size)).translate(pos), dash, space)
    drawCircle(pos, 0.25 * defaultLineWidthHdpxRel)


  def drawRadarScanArea()
    return if !radar.isEmitting || radar.isTrkMode

    let angleToRelPos = 4.0 * ilsFovDeg * degToRad
    if radar.isVerticalScan
      let top = float2(0.0, -0.49)
      let bottom = float2(0.0, 0.25)
      let horz = float2(radar.azimuthMin, radar.azimuthMax) * angleToRelPos
      let vert = float2(-radar.elevationMax, -radar.elevationMin) * angleToRelPos
      let dash = 0.015
      let space = 0.01
      drawDashedLine(float2(horz.x, vert.x), float2(horz.x, vert.y), dash, space)
      drawDashedLine(float2(horz.y, vert.x), float2(horz.y, vert.y), dash, space)
    elif radar.isAcmMode
      let size = float2(radar.azimuthMax - radar.azimuthMin, radar.elevationMax - radar.elevationMin) * angleToRelPos
      let clampedSize = clamp(size, float2(0.0), float2(0.5))
      let offset = float2(radar.azimuthMin, radar.elevationMin) * angleToRelPos + size * 0.5
      drawDashedEllipse(offset, clamp(size, float2(0.0), float2(0.48)), PI2 / 64.0, PI2 / 64.0, PI / 64.0)


  def drawRadarAirTracking()
    let isAirCombatMode = isAamMode || isAirGunMode
    return if !isAirCombatMode || !radar.isTrkMode || !tracking.isActive || !tracking.ilsPosValid

    let boresightToTarget = tracking.ilsPos - gunBoresightPos
    let length = length(boresightToTarget)
    let dir = boresightToTarget / length

    var pos = tracking.ilsPos
    let size = 0.1
    let indent = float2(0.25 * size)
    let outOfCanvas = isOutOfCanvas(pos, indent)

    if outOfCanvas
      let t = traceRayToCanvasEdges(gunBoresightPos, dir, indent)
      pos = gunBoresightPos + t * dir

    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    if !outOfCanvas || isBlink
      let points = [[float2
        float2(-0.5, 0.0);
        float2(0.0, -0.5);
        float2(0.5, 0.0);
        float2(0.0, 0.5);
      ]]

      let verts = points.to_array().scale(float2(size)).translate(pos)
      drawClosedPolyLine(verts)

    let arrowLength = 0.15
    if length > arrowLength + 0.065
      let to = gunBoresightPos + arrowLength * dir
      let headSize = float2(0.01, 0.05)
      drawLine(gunBoresightPos, to)
      drawArrowHead(to, dir, headSize)


  def drawRadarAirTrackingInfo()
    let isAirCombatMode = isAamMode || isAirGunMode
    return if !isAirCombatMode || !tracking.isActive

    let pos = float2(0.18, -0.07)
    setFontSize(35)
    setLineSpacing(1.0)
    setCaretPosition(pos)
    let distanceRateStr = fmt(":>6d", roundi(-tracking.distanceRate * mpsToKnots))
    printStrLn("{distanceRateStr}Vc")

    if isAirGunMode
      let distanceStr = fmt(":>4d", roundi(tracking.distance * metrToFeet))
      printStrLn("{distanceStr} FT")
    elif isAamMode
      let distanceStr = fmt(":>4.1f", tracking.distance * metrToNavMile)
      printStrLn("{distanceStr}RNG")


  def drawAamGuidance()
    return if !isAamMode || !aamGuidance.isActive

    var pos : float2
    let isTracking = int(aamGuidance.lockState) >= int(GuidanceLockState.RESULT_TRACKING)
    if isTracking && aamGuidance.ilsPosValid
      pos = aamGuidance.ilsPos
    else
      pos = gunBoresightPos

    let radius = 0.04
    let indent = float2(0.75 * radius)
    let outOfCanvas = isOutOfCanvas(pos, indent)

    if outOfCanvas
      let dir = fast_normalize(pos - gunBoresightPos)
      let t = traceRayToCanvasEdges(gunBoresightPos, dir, indent)
      pos = gunBoresightPos + t * dir

    let blinksPerSecond = 4.0
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    if !outOfCanvas || isBlink
      drawCircle(pos, radius)


  def drawAgmGuidance()
    return if !agmGuidance.isActive || int(agmGuidance.lockState) <= int(GuidanceLockState.RESULT_STANDBY)

    let isPreparing = int(agmGuidance.lockState) <= int(GuidanceLockState.RESULT_WARMING_UP)

    var pos = isPreparing ? gunBoresightPos : agmGuidance.ilsPos
    let radius = 0.04

    let indent = float2(0.75 * radius)
    let outOfCanvas = !isPreparing && isOutOfCanvas(pos, indent)
    if outOfCanvas
      let dir = fast_normalize(pos - gunBoresightPos)
      let t = traceRayToCanvasEdges(gunBoresightPos, dir, indent)
      pos = gunBoresightPos + t * dir

    let blinksPerSecond = 4.0
    let isBlinking = outOfCanvas || isPreparing
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5

    if !isBlinking || isBlink
      let points = [[float2
        float2(-1.0, -1.0);
        float2(1.0, -1.0);
        float2(0.0, 0.0);
      ]]
      drawClosedPolyLine(points.to_array().scale(float2(radius)).translate(pos))


  def drawAamReticle()
    return if !isAamMode || !tracking.isActive

    var pos = gunBoresightPos
    let radius = 0.2
    drawCircle(pos, radius)

    let velRel = tracking.dirNorm * tracking.distanceRate + tracking.angVel * tracking.distance
    let velAbs = hero.vel + velRel
    let tmInv : float3x3 = float3x3(inverse(hero.unitTm))
    let velDir = fast_normalize(-(tmInv * velAbs).zx)
    let arrowLength = 0.05
    let arrowSize = float2(0.005, 0.025)
    drawLine(pos + velDir * radius, pos + velDir * (radius + arrowLength))
    drawArrowHead(pos + velDir * (radius + arrowLength), velDir, arrowSize)

    let hasDgftDist = get_radar_hud_aam_launch_zone_dist_dgft_max() > 0.0
    let maxDist = hasDgftDist ? get_radar_hud_aam_launch_zone_dist_dgft_max() : get_radar_hud_aam_launch_zone_dist_max()
    let minDist = hasDgftDist ? get_radar_hud_aam_launch_zone_dist_dgft_min() : get_radar_hud_aam_launch_zone_dist_min()
    var curDist = get_radar_hud_aam_launch_zone_dist()
    let curDistAngle = PI - clamp(curDist, 0.0, 1.0) * PI2
    let minDistAngle = PI - clamp(minDist, 0.0, 1.0) * PI2
    let maxDistAngle = PI - clamp(maxDist, 0.0, 1.0) * PI2

    let halfLineWidthRel = 0.5 * defaultLineWidthHdpxRel
    setLineWidth(1.5 * defaultLineWidth)
    drawSector(pos, float2(radius - halfLineWidthRel), float2(-PI_2, PI_2 - curDistAngle))
    setLineWidth(defaultLineWidth)
    var dir = float2(0.0, -1.0)
    let serifLength = 0.015
    drawLine(pos + dir * radius, pos + dir * (radius - serifLength))
    sincos(curDistAngle, dir.x, dir.y)
    drawLine(pos + dir * radius, pos + dir * (radius - serifLength))

    let triangle = [[float2
      float2(0.0, 0.0);
      float2(0.6, 1.0);
      float2(-0.6, 1.0);
    ]]

    let triangleSize = float2(0.02)
    sincos(maxDistAngle, dir.x, dir.y)
    let curDistTriangleVerts = triangle.to_array().scale(triangleSize).rotate(-dir.x, dir.y).translate(pos + dir * (radius + halfLineWidthRel))
    drawClosedPolyLine(curDistTriangleVerts)
    sincos(minDistAngle, dir.x, dir.y)
    let minDistTriangleVerts = triangle.to_array().scale(triangleSize).rotate(-dir.x, dir.y).translate(pos + dir * (radius + halfLineWidthRel))
    drawClosedPolyLine(minDistTriangleVerts)

    let blinksPerSecond = 2.5
    let isBlink = fract(blinksPerSecond * totalTime) < 0.5
    let isGuidanceReady = aamGuidance.lockState == GuidanceLockState.RESULT_TRACKING || aamGuidance.lockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH
    let isInRange = curDist > minDist && curDist < maxDist
    if isGuidanceReady && isInRange && isBlink
      setFontSize(35)
      let offset = -0.055 - getFontDescent()
      drawStrAnchored(tracking.ilsPos + float2(0.0, offset), "SHOOT", AnchorHorz.Center, AnchorVert.Bottom)

    let steeringDir = -toRelXY((tmInv * velRel).zy)
    let steeringDotPos = tracking.ilsPos + steeringDir
    let lastFillColor = fillColor
    setFillColor(color)
    drawCircle(steeringDotPos, 0.007)
    setFillColor(lastFillColor)


  def drawAamTimeToHit()
    return if !tracking.isActive

    let pos = float2(0.3, 0.1)
    setTextAnchorHorz(AnchorHorz.Right)
    setFontSize(35)

    var tthAfterLaunch = (*wc).getLastGuidedWeaponHitTime(int(WeaponTriggerType.AAM_TRIGGER))
    let timeToShowZeroValue = 2.0
    if tthAfterLaunch > totalTime - timeToShowZeroValue
      let time = clamp(roundi(tthAfterLaunch - totalTime), 0, 99)
      let timeStr = fmt(":>2d", time)
      drawStr(pos, "SW {timeStr} TTG")
      return

    return if !isAamMode

    let tthBeforeLaunch = get_radar_hud_aam_time_to_hit()
    if tthBeforeLaunch > 0.0
      let time = min(99, roundi(tthBeforeLaunch))
      drawStr(pos, "{time} TTG")


  def draw()
    return if !isValid

    setFullCanvasViewport()

    drawTvvMark()
    drawVerticalSpeed()
    drawIntegratedAirSpeed()
    drawAltitude()
    drawFlightParams()
    drawHeadingTape()
    drawPitchLadder()
    drawForwardPoint()

    let isCombatMode = gearProgress == 0.0
    if isCombatMode
      drawSelectedAirWeapon()
      drawSelectedGroundWeapon()
      drawGunBoresight()
      drawBulletImpactLines()
      drawAirGunCcipReticle()
      drawGroundGunAndRocketCcipReticle()
      drawBombCcipReticle()
      drawBombCcrpReticle()
      drawPointOfInterest()
      drawRadarScanArea()
      drawRadarAirTracking()
      drawRadarAirTrackingInfo()
      drawAamGuidance()
      drawAgmGuidance()
      drawAamReticle()
      drawAamTimeToHit()
    else
      drawBankingAngle()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.ilsFovDeg = getFloat(props, "ilsFovDeg", 20.0)
