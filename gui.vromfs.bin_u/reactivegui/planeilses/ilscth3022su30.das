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
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require GamePhys
require WTCamera

let airGunDistance = 1000.0
let groundGunDistance = 2000.0
let bombingDistance = 10000.0

// Adjust this value for each ILS to keep zero line on the horizon when pitching
let hudFovDeg = float2(33)
let hudFovLimits = hudFovDeg * degToRad / 2.0
let hudPadding = float2(0.02)

struct PropStorage
  fontId : int

struct Tracking
  isActive : bool
  pos : float3
  distance : float
  distanceRate : float
  dirNorm : float3
  angVel : float3
  ilsPosValid : bool
  ilsPos : float2

struct Radar
  isEmitting : bool
  isVerticalScan : bool
  isAcmMode : bool
  isTrkMode : bool
  isTwsMode : bool
  isHdnMode : bool
  isHmdMode : bool
  azimuthMin : float
  azimuthMax : float
  elevationMin : float
  elevationMax : float
  displayRangeMax : float
  displayRangeMin : float
  isIrst : bool


struct SensorPoi
  isSet : bool
  pos : float3
  distance : float
  ilsPos : float2


struct Shapes
  diamond = [[auto
    float2(0.01,  0.00);
    float2(0.00,  0.02);
    float2(-0.01,  0.00);
    float2(0.00, -0.02);
  ]]


struct Ccip
  ilsPosValid : bool
  ilsPos : float2


class Component : Canvas
  isValid : bool
  isMetricUnits : bool

  app : AcesApp?
  hero : Unit?
  fmw : FlightModelWrap?
  wc : WeaponController?
  fcm : FlightControlMode?
  secondaryWeapon : Weapon?
  totalTime : float
  heading : float

  radar : Radar
  toi : Tracking
  spi : SensorPoi
  radarScopeSize : float2
  ccip : Ccip

  isDogFight : bool
  isAirGunMode : bool
  isAirGunUnrangedMode : bool
  isAirGunRangedMode : bool
  isGroundGunMode : bool
  isGroundRocketMode : bool
  isAamMode : bool
  isBombingCcrpMode : bool
  isBombingCcipMode : bool
  isBombingGuidedMode : bool
  hasLaunchPerm : bool

  defaultLineWidth : float
  defaultFontSize : int
  defaultColor : E3DCOLOR
  nullColor : E3DCOLOR
  maskColor : E3DCOLOR
  shapes : Shapes = Shapes()

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    app = get_app()
    hero = get_watched_not_delayed_hero()
    fmw = hero.as_fmw()
    wc = hero.weap
    fcm = app.flightControlMode
    return if (app == null
      || hero == null
      || fmw == null
      || wc == null
      || fcm == null)

    isValid = true
    defaultColor = *fmw.cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS)
    defaultLineWidth = floor(5.0 * fmw.cockpit.ilsLineWidthScale)
    defaultFontSize = 45
    nullColor = E3DCOLOR(0x0)
    maskColor = E3DCOLOR(0xFF000000)
    setColor(defaultColor)
    setLineWidth(defaultLineWidth)
    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFontSize(defaultFontSize)

    totalTime = float(get_total_time())

    let forward = hero.unitTm[0]
    heading = atan2(forward.x, forward.z)

    hasLaunchPerm = false
    radarScopeSize = float2(0.5, 0.5)

    if get_point_of_interest(spi.pos)
      spi.isSet = true
      spi.distance = 0.001 * length(spi.pos - hero.unitTm[3])
      spi.ilsPos = worldPosToHud(spi.pos)

    if get_ils_target_pos_valid()
      ccip.ilsPosValid = true
      ccip.ilsPos = toRelPos(get_ils_target_pos())

    get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
      secondaryWeapon := weapon

    radar.isEmitting = get_radar_hud_is_emitting() || get_radar_hud_is_emitting2()
    radar.azimuthMin = get_radar_hud_scan_azimuth_min()
    radar.azimuthMax = get_radar_hud_scan_azimuth_max()
    radar.elevationMin = get_radar_hud_scan_elevation_min()
    radar.elevationMax = get_radar_hud_scan_elevation_max()
    radar.displayRangeMax = get_radar_hud_distance_max()
    radar.displayRangeMin = get_radar_hud_distance_min()
    let radarModeName = get_radar_hud_mode_name()
    radar.isAcmMode = find(radarModeName, "ACM") >= 0
    radar.isTrkMode = find(radarModeName, "track") >= 0
    radar.isTwsMode = find(radarModeName, "TWS") >= 0
    radar.isHdnMode = find(radarModeName, "HDN") >= 0
    radar.isHmdMode = find(radarModeName, "HMD") >= 0
    radar.isIrst = get_radar_hud_is_irst() && find(radarModeName, "IRST") >= 0
    radar.isVerticalScan = radar.elevationMax - radar.elevationMin > 2.0 * (radar.azimuthMax - radar.azimuthMin)

    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        toi.isActive = true
        toi.pos = target.from + target.dirNorm * target.distance
        toi.distance = target.distance
        toi.distanceRate = target.distanceRate
        toi.dirNorm = target.dirNorm
        toi.angVel = target.angVel
        var ilsPos : float2
        if world_to_ils_screen(fmw, toi.pos, ilsPos)
          toi.ilsPosValid = true
          toi.ilsPos = toRelPos(ilsPos)

    isAirGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS)
    isAirGunUnrangedMode = isAirGunMode && !toi.isActive
    isAirGunRangedMode = isAirGunMode && toi.isActive

    isGroundGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS)

    isAamMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (secondaryWeapon == null || secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)))

    isDogFight = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (radar.isAcmMode || (radar.isTrkMode && toi.isActive && toi.distance < 2.0 * airGunDistance))))

    isBombingCcrpMode = spi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) &&
      (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)))

    isBombingCcipMode = !spi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS) &&
       (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)))

    isBombingGuidedMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) &&
      (secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))))

    isGroundRocketMode = (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.ROCKETS_TRIGGER))


  def drawRollScale()
    let pos = float2(0.0)
    let divs = 12
    let interval = PI2 / float(divs)

    var sina, cosa = 0.0
    for i in 0..divs / 2 + 1
      let gap = 0.12
      var length = 0.015
      setLineWidth(defaultLineWidth)

      if i % 3 == 0
        setLineWidth(2.0 * defaultLineWidth)
        length += 0.005

      let angle = float(i) * interval
      sincos(angle, sina, cosa)
      let end = gap + length
      let startPos = float2(gap * cosa + pos.x, gap * sina + pos.y)
      let endPos = float2(end * cosa + pos.x, end * sina + pos.y)
      drawLine(startPos, endPos)
      setLineWidth(defaultLineWidth)


  def drawRollIndicator()
    let gap = 0.022

    setFillColor(defaultColor)
    drawCircle(float2(0.0), 0.004)
    setFillColor(nullColor)

    var wing = [[auto
      float2(-gap, 0.0);
      float2(-0.04, 0.0);
      float2(-0.045, 0.015);
      float2(-0.05, 0.0);
      float2(-0.11, 0.0);
    ]]

    var stab = [[auto
      float2(0.0, -gap);
      float2(0.0, -0.085);
    ]]

    var sina, cosa = 0.0
    sincos(fmw.roll / 180.0 * PI, sina, cosa)

    setLineWidth(2.0 * defaultLineWidth)
    drawPolyLine(wing.to_array().rotate(sina, cosa))
    drawPolyLine(wing.to_array().inv_x().rotate(sina, cosa))
    drawPolyLine(stab.to_array().rotate(sina, cosa))
    setLineWidth(defaultLineWidth)


  def drawFpm()
    let factor = 5.0
    let pos = hero.vel.length_sq() > factor ? worldVecToHud(hero.vel) : hero.vel.length_sq() / factor *  worldVecToHud(hero.vel)
    let gap = 0.011
    drawDot(pos)
    drawCircle(pos, gap)
    drawLine(float2(gap, 0.0) + pos, float2(gap + 0.035, 0.0) + pos)
    drawLine(float2(-gap, 0.0) + pos, float2(-gap - 0.035, 0.0) + pos)
    drawLine(float2(0.0, -gap) + pos, float2(0.0, -gap - 0.015) + pos)


  def drawVsi()
    let pos = float2(0.5, 0.0)
    let divs = 16
    let interval = PI2 / float(divs)
    let quarter = divs / 4
    let size = 0.09
    let handSize = 0.08
    let max = 16.0
    // Scale
    var sina, cosa = 0.0
    for i in quarter + 1..quarter * 3
      let angle = float(i) * interval
      sincos(angle, sina, cosa)
      if i % 8 == 0
        let end = size - 0.015
        let startPos = float2(size * cosa + pos.x, size * sina + pos.y)
        let endPos = float2(end * cosa + pos.x, end * sina + pos.y)
        drawLine(startPos, endPos)
      else
        drawDot(float2(size * cosa + pos.x, size * sina + pos.y))
    // Hand
    let line = [[auto
      float2(0.0, 0.0);
      float2(-handSize, 0.0);
    ]]

    let arrow = [[auto
      float2(-handSize + 0.01, -0.005);
      float2(-handSize, 0.0);
      float2(-handSize + 0.01, 0.005);
    ]]

    let factor = 80.0 / max
    sincos(clamp(hero.vel.y, -max, max) * factor / 180.0 * PI, sina, cosa)

    drawPolyLine(line.to_array().rotate(sina, cosa).translate(pos))
    drawPolyLine(arrow.to_array().rotate(sina, cosa).translate(pos))
    // Draw numbers if exceed max ascend/descend rate
    setFontSize(roundi(0.6 * float(defaultFontSize)))
    if hero.vel.y > max
      drawStrAnchored(float2(pos.x - 0.035, pos.y - size - 0.01), "{floori(hero.vel.y)}", AnchorHorz.Center, AnchorVert.Bottom)
    elif hero.vel.y < -max
      drawStrAnchored(float2(pos.x -  0.035, pos.y + size + 0.01), "{floori(abs(hero.vel.y))}", AnchorHorz.Center, AnchorVert.Top)
    setFontSize(defaultFontSize)


  def quantizeAlt(alt : float) : int // based on Su-35
    if alt < 100.0
      return floori(alt / 2.0) * 2;
    if alt < 500.0
      return floori(alt / 5.0) * 5;
    return floori(alt / 10.0) * 10;


  def quantizeSpeed(speed : float) : int // based on Su-35
    if speed < 300.0
      return floori(speed / 2.0) * 2;
    if speed < 400.0
      return floori(speed / 5.0) * 5;
    return floori(speed / 10.0) * 10;


  def drawRalt()
    return if abs(fmw.roll) > 45.0 || abs(fmw.tangage) > 45.0

    let pos = float2(0.37, -0.355)
    let ralt = fmw.fm.currentAlt
    drawStrAnchored(pos, "{quantizeAlt(ralt)}Р", AnchorHorz.Right, AnchorVert.Top)


  def drawAlt()
    let pos = float2(0.37, -0.36)
    let alt = hero.unitTm[3].y - get_app().currentScene.waterLevel
    drawStrAnchored(pos, "{quantizeAlt(alt)} ", AnchorHorz.Right, AnchorVert.Bottom)


  def drawLoadFactor()
    let pos = float2(-0.365, -0.285)
    let max = 9.0
    let min = -3.0
    let inner = 0.03  // inner circle size
    let outer = 0.038 // outer circle size

    setFontSize(roundi(0.8 * float(defaultFontSize)))

    drawCircle(pos, inner)

    let gInv = 1.0 / gravity()
    let load = float(fmw.fm.localAccel.y) * gInv + 1.f
    let loadClamped = clamp(load, min, max)
    drawStrAnchored(pos, fmt(load < 10.0 && load > -10.0 ? ":.1f" : ":.0f", abs(load)), AnchorHorz.Center, AnchorVert.Center)

    var angle : float
    if load > 0.0
      let relLoad = loadClamped / (max + 0.01)
      angle = PI3_2 + PI2 * relLoad
      drawSector(pos, float2(outer), float2(PI3_2, angle))
    else
      let relLoad = loadClamped / (min - 0.01)
      angle = PI3_2 - PI2 * relLoad
      drawSector(pos, float2(outer), float2(angle, PI3_2))

    let start = inner - 0.005
    let end = outer + 0.003
    var sina, cosa = 0.0
    sincos(angle, sina, cosa)
    drawLine(
      float2(pos.x + start * cosa, pos.y + start * sina),
      float2(pos.x + end  * cosa, pos.y + end * sina)
    )

    setFontSize(defaultFontSize)


  def drawPitchLadder()
    let interval = 5
    let count = 90 / interval
    let width = 0.195   // width of whole indicator
    let start = 0.145   // start of scale mark
    let scale =  0.0055 // degrees per canvas unit
    let mask = 0.2      // height of pitch ladder mask

    setFontSize(roundi(0.5 * float(defaultFontSize)))

    let pitch = fmw.tangage

    for i in -count..count + 1
      let offset = (float(i * interval) + pitch) * scale
      if offset > mask || offset < -mask
        continue
      if i == 0 // level flight line
        drawLine(float2(-width + (width - start), offset), float2(width, offset))
        drawStrAnchored(float2(width + 0.01, offset), "{abs(i * interval)}", AnchorHorz.Left, AnchorVert.Center)
      elif i % 2 == 0 // normal line
        if i > 0
          drawLine(float2(start, offset), float2(width, offset))
        else
          drawDashedLine(float2(start, offset), float2(width, offset), 0.01, 0.008)
        drawStrAnchored(float2(width + 0.01, offset), "{abs(i * interval)}", AnchorHorz.Left, AnchorVert.Center)
      else // small line
        if i > 0
          drawLine(float2(start, offset), float2(width - 0.02, offset))
        else
          drawDashedLine(float2(start, offset), float2(width - 0.02, offset), 0.01, 0.008)
    // masking
    setFillColor(maskColor)
    setColor(maskColor)
    let maskHeight = float(interval) * scale
    drawBox(float2(-width, -mask + maskHeight), float2(width + 0.04, -mask - maskHeight))
    drawBox(float2(-width, mask + maskHeight), float2(width + 0.04, mask - maskHeight))
    // resets
    setFontSize(defaultFontSize)
    setFillColor(nullColor)
    setColor(defaultColor)


  def drawAoaConv(hand : float2[5])
    let pos = float2(-0.16, 0.35)
    let divs = 36
    let interval = PI2 / float(divs)
    let size = 0.155

    let startAngle = 3.0 * interval

    drawSector(pos, float2(size), float2(-1.0 * interval + PI, 3.0 * interval + PI))

    var sina, cosa = 0.0

    for i in divs / 2 - 1.. divs / 2 + 4
      let length = 0.01
      var start = 0.0
      if i == divs / 2
        start += 0.01
      let angle = float(i) * interval
      let end = size - length
      sincos(angle, sina, cosa)
      let startPos = float2((size + start) * cosa + pos.x, (size + start) * sina + pos.y)
      let endPos = float2(end * cosa + pos.x, end * sina + pos.y)
      drawLine(startPos, endPos)

    sincos(clamp(fmw.fm.aoa, -10.0, 30.0) / 180.0 * PI, sina, cosa)
    drawPolyLine(hand.to_array().translate(float2(-size - hand[0].x, 0.0)).rotate(sina, cosa).translate(pos))


  def drawAoaTvc(hand : float2[5])
    let pos = float2(-0.325, 0.37)
    let divs = 12
    let interval = PI2 / float(divs)
    let size = 0.065

    var aoa : float
    if hero.vel.length_sq() < 1.0
      aoa = hero.vel.length_sq() * fmw.fm.aoa
    else
      aoa = fmw.fm.aoa

    drawCircle(pos, size)
    setFontSize(roundi(0.6 * float(defaultFontSize)))

    if aoa < 90.0 && aoa > -90.0
      drawStrAnchored(pos + float2(0.045, 0.0), "{roundi(aoa)}", AnchorHorz.Right, AnchorVert.Center)
    else
      drawStrAnchored(pos, "{roundi(aoa)}", AnchorHorz.Right, AnchorVert.Center)

    var sina, cosa = 0.0
    for i in 0..divs
      let length = 0.015
      var start = 0.0
      if i == 6
        start += 0.01
      let angle = float(i) * interval
      sincos(angle, sina, cosa)
      let end = size - length
      let startPos = float2((size + start) * cosa + pos.x, (size + start) * sina + pos.y)
      let endPos = float2(end * cosa + pos.x, end * sina + pos.y)
      drawLine(startPos, endPos)

    sincos(aoa / 180.0 * PI, sina, cosa)
    drawPolyLine(hand.to_array().rotate(sina, cosa).translate(pos))

    setFontSize(defaultFontSize)


  def drawAoa()
    let isTvc = fmw.fm.appliedCT.maneuverabilityMode < fmw.fullAutopilotManeuverabilityModeTransition.x
    let hand = [[auto
      float2(-0.065, 0.0);
      float2(0.0, 0.0);
      float2(0.0, -0.02);
      float2(-0.015, -0.01);
      float2(-0.06, 0.0);
    ]]
    if isTvc
      drawAoaTvc(hand)
    else
      drawAoaConv(hand)


  def drawMach()
    let pos = float2(-0.38, -0.33)

    setCaretPosition(pos)
    setFontSize(roundi(0.8 * float(defaultFontSize)))
    printStr("{floori(fmw.fm.Mach)}.")

    setFontSize(roundi(0.6 * float(defaultFontSize)))
    printStr(fmt(":02d", floori(fract(fmw.fm.Mach) * 100.0)))

    setFontSize(roundi(0.8 * float(defaultFontSize)))
    printStr("М")

    setFontSize(defaultFontSize)


  def drawIas()
    let pos = float2(-0.3, -0.365)
    drawStrAnchored(pos, "{quantizeSpeed(fmw.ias * mpsToKmh)}", AnchorHorz.Right, AnchorVert.Bottom)


  def drawRangeScale(drawDlz : bool = true)
    let length = radarScopeSize.y
    let padding = 0.035
    let pos = float2(-radarScopeSize.x * 0.5 - padding, length * 0.5)
    let divs = 5
    let stepWidth = 0.015

    let step = length / float(divs)
    let displRng = ceili(radar.displayRangeMax - radar.displayRangeMin)
    let displStep = float(displRng) / float(divs)

    drawLine(pos, float2(pos.x, pos.y - length))
    setFontSize(roundi(0.6 * float(defaultFontSize)))
    for i in 0 .. divs + 1
      let posY = -float(i) * step + pos.y
      drawLine(float2(pos.x, posY), float2(pos.x - stepWidth, posY))
      drawStrAnchored(float2(pos.x - stepWidth, posY), "{roundi(float(i) * displStep)}", AnchorHorz.Right, AnchorVert.Center)

    // DLZ
    var dlzMax = 0.0
    if drawDlz
      if get_radar_hud_aam_launch_zone_visible()
        setLineWidth(2.0 * defaultLineWidth)

        dlzMax = get_radar_hud_aam_launch_zone_dist_max()
        if dlzMax < 1.0
          let dlzMaxY = pos.y - dlzMax * length
          drawLine(float2(pos.x, dlzMaxY), float2(pos.x + stepWidth, dlzMaxY))

        let dlzMin = get_radar_hud_aam_launch_zone_dist_dgft_min()
        if dlzMin < 1.0
          let dlzMinY = pos.y - dlzMin * length
          drawLine(float2(pos.x, dlzMinY), float2(pos.x + stepWidth, dlzMinY))

        let dlzNezMax = get_radar_hud_aam_launch_zone_dist_dgft_max()
        if dlzNezMax < 1.0
          let dlzNezMaxY = pos.y - dlzNezMax * length
          drawLine(float2(pos.x, dlzNezMaxY), float2(pos.x + stepWidth, dlzNezMaxY))

        setLineWidth(defaultLineWidth)

    // Target range
    if toi.isActive
      let tgt = toi.distance / float(radar.displayRangeMax * 1000.0)
      if dlzMax > tgt
        hasLaunchPerm = true
      let arrow = [[auto
        float2(0.000,  0.000);
        float2(0.015, -0.015);
        float2(0.015, -0.006);
        float2(0.040, -0.006);
        float2(0.040,  0.006);
        float2(0.015,  0.006);
        float2(0.015,  0.015);
      ]]
      drawClosedPolyLine(arrow.to_array().translate(float2(pos.x, pos.y - tgt * length)))

    setFontSize(defaultFontSize)


  def drawBScopeTargets()
    get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
      for t in targets
        continue if !t.isEnemy
        continue if t.targetType == int(RadarTargetType.TYPE_OWN_WEAPON)
        continue if t.targetType == int(RadarTargetType.TYPE_OWN_WEAPON_TARGET)

        let isClamped = t.azimuthRel < 0.0 || t.azimuthRel > 1.0 || t.distanceRel < 0.0 || t.distanceRel > 1.0
        continue if isClamped && fract(totalTime * 2.0) < 0.5

        let pos = float2(
          (clamp(t.azimuthRel, 0.0, 1.0) - 0.5) * (radarScopeSize.x / 1.0),
          (-clamp(t.distanceRel, 0.0, 1.0) + 0.5) * (radarScopeSize.y / 1.0))

        if t.isAttacked
          drawLine(float2(pos.x, pos.y + 0.02), float2(pos.x, pos.y - 0.02))
          drawLine(float2(pos.x + 0.01, pos.y), float2(pos.x - 0.01, pos.y))

        if t.isDetected || t.isTracked
          drawClosedPolyLine(shapes.diamond.to_array().translate(pos))
        elif !t.isAttacked
          drawCircle(pos, 0.012)


  def drawCScopeTargets()
    get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
      for t in targets
        continue if !t.isEnemy
        continue if t.targetType == int(RadarTargetType.TYPE_OWN_WEAPON)
        continue if t.targetType == int(RadarTargetType.TYPE_OWN_WEAPON_TARGET)

        let isClamped = t.azimuthRel < 0.0 || t.azimuthRel > 1.0 || t.elevationRel < 0.0 || t.elevationRel > 1.0
        continue if isClamped && fract(totalTime * 2.0) < 0.5

        let pos = float2(
          (clamp(t.azimuthRel, 0.0, 1.0) - 0.5) * (radarScopeSize.x / 1.0),
          (-clamp(t.elevationRel, 0.0, 1.0) + 0.5) * (radarScopeSize.y / 1.0))

        if t.isDetected || t.isTracked
          drawClosedPolyLine(shapes.diamond.to_array().translate(pos))
        else
          drawCircle(pos, 0.012)


  def drawRadarAzimuthElevation()
    let padding = 0.01
    let zeroMark = 0.01
    let trackSize = 0.04

    // X
    drawLine(
      float2(radarScopeSize.x * 0.5, radarScopeSize.y * 0.5 + padding),
      float2(-radarScopeSize.x * 0.5, radarScopeSize.y * 0.5 + padding))
    drawLine(
      float2(0.0, radarScopeSize.y * 0.5 + padding),
      float2(0.0, radarScopeSize.y * 0.5 + padding + zeroMark))

    // Y
    drawLine(
      float2(radarScopeSize.x * 0.5 + padding, radarScopeSize.y * 0.5),
      float2(radarScopeSize.x * 0.5 + padding, -radarScopeSize.y * 0.5))
    drawLine(
      float2(radarScopeSize.x * 0.5 + padding, 0.0),
      float2(radarScopeSize.x * 0.5 + padding + zeroMark, 0.0))

    // AZ scan indicator
    let azScale = radarScopeSize.x / 1.0
    if !radar.isTrkMode
      let azMax = (get_radar_hud_scan_azimuth_max() - get_radar_hud_azimuth_min()) / (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) - 0.5
      let azMin = (get_radar_hud_scan_azimuth_min() - get_radar_hud_azimuth_min()) / (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) - 0.5
      if azMax - azMin < 1.0
        drawLine(
          float2(azMax * azScale, radarScopeSize.y * 0.5 + padding + zeroMark),
          float2(azMin * azScale, radarScopeSize.y * 0.5 + padding + zeroMark))
    else
      let az = (get_radar_hud_azimuth() - 0.5) * 0.5
      let x1 = clamp(az - trackSize * azScale, -radarScopeSize.x * 0.5, 1.0)
      let x2 = clamp(az + trackSize * azScale, -1.0, radarScopeSize.x * 0.5)
      drawLine(
        float2(x1, radarScopeSize.y * 0.5 + padding + zeroMark),
        float2(x2, radarScopeSize.y * 0.5 + padding + zeroMark))

    // EL scan indicator
    let elScale = radarScopeSize.y / 1.0
    if !radar.isTrkMode
      let elMax = -(get_radar_hud_scan_elevation_max() - get_radar_hud_elevation_min()) / (get_radar_hud_elevation_max() - get_radar_hud_elevation_min()) + 0.5
      let elMin = -(get_radar_hud_scan_elevation_min() - get_radar_hud_elevation_min()) / (get_radar_hud_elevation_max() - get_radar_hud_elevation_min()) + 0.5
      drawLine(
        float2(radarScopeSize.x * 0.5 + padding + zeroMark, elMax * elScale),
        float2(radarScopeSize.x * 0.5 + padding + zeroMark, elMin * elScale))
    else
      let el = -(clamp(get_radar_hud_elevation(), 0.0, 1.0) - 0.5) * 0.5 // FIXME clamp is temporary fix for non-working radar elevation limits
      let y1 = clamp(el - trackSize * elScale, -radarScopeSize.y * 0.5, 1.0)
      let y2 = clamp(el + trackSize * elScale, -1.0, radarScopeSize.y * 0.5)
      drawLine(
        float2(radarScopeSize.x * 0.5 + padding + zeroMark, y1),
        float2(radarScopeSize.x * 0.5 + padding + zeroMark, y2))


  def drawScanArea()
    let lt = float2(get_radar_hud_scan_azimuth_min(), get_radar_hud_scan_elevation_max())
    let rb = float2(get_radar_hud_scan_azimuth_max(), get_radar_hud_scan_elevation_min())
    drawBox(angleToHud(lt), angleToHud(rb))


  def drawLosTargets()
    get_radar_hud_screen_targets() <| $(targets : array<RadarScreenTarget> const#)
      for t in targets
        continue if !t.isEnemy

        let pos = worldPosToHud(t.worldPos)
        continue if isOutOfCanvas(pos, hudPadding) && fract(totalTime * 2.0) < 0.5

        let dir = fast_normalize(spi.ilsPos)
        let rt = traceRayToCanvasEdges(float2(0.0), dir, hudPadding)
        let posClamped = rt * dir

        if t.isAttacked
          drawLine(float2(pos.x, pos.y + 0.02), float2(pos.x, pos.y - 0.02))
          drawLine(float2(pos.x + 0.01, pos.y), float2(pos.x - 0.01, pos.y))

        if t.isDetected || t.isTracked
          drawClosedPolyLine(shapes.diamond.to_array().translate(posClamped))
        elif !t.isAttacked
          drawCircle(posClamped, 0.012)


  def drawLosTarget()
    return if !toi.ilsPosValid

    return if isOutOfCanvas(toi.ilsPos, hudPadding) && fract(totalTime * 2.0) < 0.5

    let dir = fast_normalize(spi.ilsPos)
    let rt = traceRayToCanvasEdges(float2(0.0), dir, hudPadding)
    let posClamped = rt * dir

    drawCircle(posClamped, 0.03)


  def drawAspectMode()
    let pos = float2(-0.46, -0.1)
    drawStrAnchored(pos, radar.isHdnMode ? "ППС" : "ЗПС", AnchorHorz.Center, AnchorVert.Center)


  def drawRangeMode(isShortRange : bool)
    let pos = float2(0.44, 0.24)
    drawStrAnchored(pos, isShortRange ? "ББВ" : "ДБВ1", AnchorHorz.Center, AnchorVert.Center)


  def drawSensorOperatingMode()
    let pos = float2(-0.46, -0.16)
    drawStrAnchored(pos, radar.isIrst ? "ТП" : "РЛ", AnchorHorz.Center, AnchorVert.Center)


  def drawIlsOperatingMode()
    let pos = float2(-0.46, -0.22)
    drawStrAnchored(pos, "ИЛС", AnchorHorz.Center, AnchorVert.Center)


  def drawHmd()
    let isIrAam = secondaryWeapon?.trigger_no ?? -1 == int(WeaponTriggerType.AAM_TRIGGER) && get_cur_weapon_guidance_type() == GuidanceType.TYPE_OPTICAL
    return if !isIrAam && !radar.isHmdMode

    let camera = app.flightControlMode.cameraControl.cur
    return if camera == null

    let dirVec = normalize(camera.viewData.lookAt - camera.viewData.lookFrom)
    let pos = worldVecToHud(dirVec)
    drawReticle(pos, float2(0.14), float2(0.02))


  def drawReticle(pos : float2; outerSize : float2 = float2(0.075); innerSize : float2 = float2(0.025))
    drawCrossReticle(pos, outerSize, innerSize)
    drawDot(pos)


  def drawRadar()
    return if !radar.isEmitting && !radar.isHmdMode
    // Labels
    let isLosMode = (
      (toi.distance < 3000.0 && !radar.isHdnMode && toi.isActive)
      || (toi.distance < 10000.0 && radar.isHdnMode && toi.isActive))

    drawAspectMode()
    drawRangeMode(isLosMode || radar.isAcmMode || radar.isHmdMode)
    drawSensorOperatingMode()

    return if radar.isHmdMode || isGroundGunMode || isGroundRocketMode
    // Main radar modes
    if isAirGunRangedMode
      drawRangeScale(false)
      drawLosTarget()
    elif isAirGunUnrangedMode
      if radar.isVerticalScan
        drawScanArea()
    elif isLosMode
      drawRangeScale()
      drawLosTargets()
    elif radar.isAcmMode
      drawScanArea()
    elif radar.isIrst
      drawCScopeTargets()
      drawRadarAzimuthElevation()
    else
      drawBScopeTargets()
      drawRadarAzimuthElevation()
      drawRangeScale()


  def drawLaunchPerm()
    return if !hasLaunchPerm

    let pos = float2(0.0, 0.3)
    drawStrAnchored(pos, "ПР", AnchorHorz.Center, AnchorVert.Center)


  def drawAirGunUnranged() // Gun funnel
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

    hasLaunchPerm = true


  def drawSpi()
    let radius = 0.015

    if spi.isSet
      if isOutOfCanvas(spi.ilsPos, hudPadding)
        return if fract(totalTime * 2.0) < 0.5

        let dir = fast_normalize(spi.ilsPos)
        let rt = traceRayToCanvasEdges(float2(0.0), dir, hudPadding)
        let pos = rt * dir
        drawCircle(pos, radius)
        drawDot(pos)
      else
        drawCircle(spi.ilsPos, radius)
        drawDot(spi.ilsPos)


  def drawGroundGun()
    drawSpi()
    drawIlsOperatingMode()
    drawStrAnchored(float2(0.4, 0.28), "ПЗ", AnchorHorz.Left, AnchorVert.Center)
    drawTargetingMode(spi.isSet ? "НС" : "ПрЗ")
    drawStrAnchored(float2(0.4, 0.20), "ВСЕ", AnchorHorz.Left, AnchorVert.Center)

    return if !fcm.isCannonImpactValid

    let radius = 0.03

    let maxRangeLoSpeed = 1800.0
    let maxRangeHiSPeed = 2200.0
    let minRange = 200.0
    let goodRange = 800.0
    let speedForMaxRange = 900.0
    let speedForMinRange = 500.0

    let coeff = clamp((fmw.ias * mpsToKmh - speedForMinRange) / (speedForMaxRange - speedForMinRange), 0.0, 1.0)
    let maxRange = lerp(maxRangeLoSpeed, maxRangeHiSPeed, coeff)
    let ccipRange = length(fcm.cannonImpactPosition - hero.pos)
    let pos = worldPosToHud(fcm.cannonImpactPosition)

    drawReticle(pos)
    let relRange = clamp(ccipRange / maxRange, 0.0, 1.0 - 0.001)

    setFontSize(roundi(0.6 * float(defaultFontSize)))
    drawStrAnchored(pos + float2(0.0, -0.05), fmt(":.1f", ccipRange / 1000.0), AnchorHorz.Center, AnchorVert.Center)
    setFontSize(defaultFontSize)

    drawCircularRangeScale(pos, relRange, goodRange / maxRange, minRange / maxRange)

    hasLaunchPerm = ccipRange < maxRange && ccipRange > minRange


  def drawRocketMode()
    return if !isGroundRocketMode

    drawSpi()
    drawIlsOperatingMode()
    drawStrAnchored(float2(0.4, 0.28), "ПЗ", AnchorHorz.Left, AnchorVert.Center)
    drawTargetingMode(spi.isSet ? "НС" : "ПрЗ")

    return if !fcm.isRocketImpactValid

    let radius = 0.03

    let maxRange = 4000.0
    let minRange = 500.0
    let goodRange = 1800.0

    let ccipRange = length(fcm.rocketImpactPosition - hero.pos)
    let pos = worldPosToHud(fcm.rocketImpactPosition)

    drawReticle(pos)
    let relRange = clamp(ccipRange / maxRange, 0.0, 1.0 - 0.001)

    setFontSize(roundi(0.6 * float(defaultFontSize)))
    drawStrAnchored(pos + float2(0.0, -0.05), fmt(":.1f", ccipRange / 1000.0), AnchorHorz.Center, AnchorVert.Center)
    setFontSize(defaultFontSize)

    drawCircularRangeScale(pos, relRange, goodRange / maxRange, minRange / maxRange)

    hasLaunchPerm = ccipRange < maxRange && ccipRange > minRange


  def drawCircularRangeScale(pos : float2; relRange : float; centerRange : float; minRange : float)
    let radius = 0.03
    let start = radius
    let end = radius + 0.008

    let angleRange = PI3_2 + PI2 * relRange
    setLineWidth(1.5 * defaultLineWidth)
    drawSector(pos, float2(radius), float2(PI3_2, angleRange))

    var sina, cosa = 0.0
    sincos(relRange * PI2 + PI3_2, sina, cosa)
    drawLine(
      float2(pos.x + start * cosa, pos.y + start * sina),
      float2(pos.x + end  * cosa, pos.y + end * sina)
    )

    if minRange < relRange
      sincos(minRange * PI2 + PI3_2, sina, cosa)
      drawLine(
        float2(pos.x + start * cosa, pos.y + start * sina),
        float2(pos.x + end  * cosa, pos.y + end * sina)
      )
    if centerRange < relRange
      sincos(centerRange * PI2 + PI3_2, sina, cosa)
      drawLine(
        float2(pos.x + start * cosa, pos.y + start * sina),
        float2(pos.x + end  * cosa, pos.y + end * sina)
      )

    setLineWidth(defaultLineWidth)


  def drawAirGunRanged()
    let rangeMax = 1500.0
    let rangeMin = 300.0

    return if toi.distance > rangeMax

    drawStrAnchored(float2(0.43, 0.3), "НС", AnchorHorz.Center, AnchorVert.Center)

    return if !ccip.ilsPosValid

    let pos = ccip.ilsPos
    drawReticle(pos)
    drawDot(pos)

    let rangeClamped = clamp(toi.distance, rangeMin, rangeMax)

    let relRange = (rangeClamped - rangeMin) / (rangeMax - rangeMin)
    let angle = PI3_2 + PI2 * relRange
    setLineWidth(2.0 * defaultLineWidth)
    drawSector(pos, float2(0.025), float2(PI3_2, angle))
    setLineWidth(defaultLineWidth)

    hasLaunchPerm = toi.distance < rangeMax && toi.distance > rangeMin


  def drawGunModes()
    return if !isAirGunMode && !isGroundGunMode

    let ammoPos = float2(0.3, 0.4)
    if isAirGunUnrangedMode
      drawAirGunUnranged()
    elif isAirGunRangedMode
      drawAirGunRanged()
    elif isGroundGunMode
      drawGroundGun()

    let ammoCount = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))

    setFontSize(roundi(0.8 * float(defaultFontSize)))
    drawStrAnchored(ammoPos, "{ammoCount}", AnchorHorz.Right, AnchorVert.Bottom)

    let padding = float2(0.01)
    let size = float2(0.06, 0.025)
    drawBox(ammoPos - size - padding, ammoPos + padding)

    setFontSize(defaultFontSize)

  def drawTargetingMode(mode : string)
    let pos = float2(0.4, 0.32)

    drawStrAnchored(pos, mode, AnchorHorz.Left, AnchorVert.Center)


  def worldVecToHud(dirVec : float3)
    var localVec = float3x3(inverse(hero.unitTm)) * dirVec
    let isBehind = localVec.x < 0.0 // Point in rear hemisphere
    if isBehind
      localVec.x = -localVec.x
    localVec = fast_normalize(localVec)
    let yaw = (atan2(localVec.x, localVec.z) - PI_2)
    let pitch = asin(localVec.y)
    var result = float2(yaw / hudFovLimits.x, -pitch / hudFovLimits.y)
    return !isBehind ? result : result * 100.0


  def worldPosToHud(pos : float3)
    return worldVecToHud(pos - hero.pos)


  def angleToHud(angle : float2)
    return float2(angle.x / hudFovLimits.x, -angle.y / hudFovLimits.y)


  def drawFlightSymbology()
    if !isAirGunUnrangedMode
      drawPitchLadder()
      drawRollScale()
      drawRollIndicator()
    drawFpm()
    drawVsi()
    drawAlt()
    drawRalt()
    drawLoadFactor()
    drawAoa()
    drawMach()
    drawIas()


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawFlightSymbology()
    drawRadar()
    drawHmd()
    drawGunModes()
    drawRocketMode()
    drawLaunchPerm()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
