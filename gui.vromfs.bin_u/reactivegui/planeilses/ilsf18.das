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
require GuidanceLock
require %game.utils.utils_common
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require %rGui.planeIlses.F18cockpit_common

struct Ccip
  ilsPosValid : bool
  ilsPos : float2

struct PointOfInterest
  isSet : bool
  pos : float3
  ilsPosValid : bool
  ilsPos : float2

class Component : FA18CockpitElementBase
  tvvPos : float2
  gunBoresightPos : float2

  ccip : Ccip

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    FA18CockpitElementBase`FA18CockpitElementBase(self, guiCtx, rdata, rstate, props, true)

    let dirProjectionToIlsPos = 2.5
    let forward = hero.unitTm[0]
    let minSpeedSq = 1.0
    let velocityDir = length_sq(hero.vel) > minSpeedSq ? fast_normalize(hero.vel) : forward
    tvvPos = -(float3x3(inverse(hero.unitTm)) * velocityDir).zy * dirProjectionToIlsPos
    tvvPos = clamp(tvvPos, float2(-0.5), float2(0.5))

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

    if get_ils_target_pos_valid()
      ccip.ilsPosValid = true
      ccip.ilsPos = toRelPos(get_ils_target_pos())


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


  def drawVerticalSpeed()
    let pos = float2(0.4, -0.30)
    let vspeed = 10 * roundi(6.0 * fm.vertSpeed * metrToFeet)
    setFontSize(35)
    setTextAnchorHorz(AnchorHorz.Right)
    drawStr(pos, string(vspeed))


  def drawBankingAngle()
    let pos = float2(0.0, -0.25)
    let radius = 0.65
    let length = 0.02
    let angles = fixed_array<float>(-45.0, -30.0, -15.0, -5.0, 0.0, 5.0, 15.0, 30.0, 45.0)
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
    let triangle = fixed_array<float2>(
      float2(0.0, 0.0),
      float2(0.7, -1.0),
      float2(-0.7, -1.0))

    let size = float2(0.015)
    let arrPos = pos + dir * (radius - defaultLineWidthHdpxRel)
    var verts = triangle.to_array().rotate(sina, cosa).scale(size).translate(arrPos)
    drawClosedPolyLine(verts)


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
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(1.5 * markEndX, -markEndY)
        let p2 = float2(1.5 * markEndX, -markEndY + 2.0 * serifWidth)
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
      let points = fixed_array<float2>(
        float2(-0.5, 0.0),
        float2(-0.25, 0.0),
        float2(-0.125, 0.175),
        float2(0.0, 0.0),
        float2(0.125, 0.175),
        float2(0.25, 0.0),
        float2(0.5, 0.0))
      let scale = float2(0.1)
      let pos = toRelPos(forwardPointOnIls)
      let verts = points.to_array().scale(scale).translate(pos)
      drawPolyLine(verts)


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
    let pullUpCuePoints = fixed_array<float2>(
      float2(0.3, 0.0),
      float2(0.9, 0.0),
      float2(1.0, -0.15))
    drawPolyLine(pullUpCuePoints.to_array().scale(pullUpScale).translate(pullUpPos))
    drawPolyLine(pullUpCuePoints.to_array().scale(inv_x(pullUpScale)).translate(pullUpPos))


  def drawBombCcipReticle()
    return if !isBombingCcipMode || fmw.tangage > 15.0

    let impactPos = fcm.bombImpactPosition
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


  def drawRadarScanArea()
    return if !radar.isEmitting || radar.isTrkMode

    let angleToRelPos = 4.0 * ilsFovDeg * degToRad
    if radar.isVerticalScan
      let horz = float2(radar.azimuthMin, radar.azimuthMax) * angleToRelPos
      let vert = float2(-radar.elevationMax, -radar.elevationMin) * angleToRelPos
      let dash = 0.015
      let space = 0.01
      drawDashedLine(float2(horz.x, vert.x), float2(horz.x, vert.y), dash, space)
      drawDashedLine(float2(horz.y, vert.x), float2(horz.y, vert.y), dash, space)
    elif radar.isAcmMode
      let size = float2(radar.azimuthMax - radar.azimuthMin, radar.elevationMax - radar.elevationMin) * angleToRelPos
      let offset = float2(radar.azimuthMin, radar.elevationMin) * angleToRelPos + size * 0.5
      drawDashedEllipse(offset, clamp(size, float2(0.0), float2(0.48)), PI2 / 64.0, PI2 / 64.0, PI / 64.0)


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
      let points = fixed_array<float2>(
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(0.0, 0.0))
      drawClosedPolyLine(points.to_array().scale(float2(radius)).translate(pos))


  def drawAamTimeToHit()
    return if !tracking.isActive

    let pos = float2(0.3, 0.1)
    setTextAnchorHorz(AnchorHorz.Left)
    setFontSize(35)

    let tthAfterLaunch = (*wc).getLastGuidedWeaponHitTime(int(WeaponTriggerType.AAM_TRIGGER))
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
    drawHeadingTape(heading, float2(0.0, -0.4), float2(0.6, 0.06))
    drawPitchLadder()
    drawForwardPoint()
    drawBankingAngle()

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
      drawPointOfInterest(true)
      drawRadarScanArea()
      if tracking.ilsPosValid
        drawRadarAirTracking(tracking.ilsPos, gunBoresightPos)
        drawAamReticle(tracking.ilsPos, gunBoresightPos)
      drawRadarAirTrackingInfo()
      if aamGuidance.ilsPosValid
        drawAamGuidance(aamGuidance.ilsPos, gunBoresightPos)
      drawAgmGuidance()
      drawAamTimeToHit()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.ilsFovDeg = getFloat(props, "ilsFovDeg", 20.0)
