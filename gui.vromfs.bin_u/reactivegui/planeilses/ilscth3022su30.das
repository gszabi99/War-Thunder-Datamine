require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightControl
require FlightModelWrap
require GamePhys
require HeroManager
require hud
require math
require Plane
require RadarHud
require Sensors
require strings
require Unit
require Weapon
require WTCamera

require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require %rGui.utils.weaponslots_common

// Adjust this value for each ILS to keep zero line on the horizon when pitching
let hudFovDeg = float2(33)
let hudFovLimits = hudFovDeg * degToRad / 2.0
let hudPadding = float2(0.02)

struct PropStorage
  fontId : int
  fontIdLatin : int

struct Tracking
  isActive : bool
  pos : float3
  distance : float
  distanceRate : float
  dirNorm : float3
  angVel : float3
  ilsPos : float2

struct Radar
  isEmitting : bool
  isVerticalScan : bool
  isAcmMode : bool
  isTrkMode : bool
  isTwsMode : bool
  isHdnMode : bool
  isHmdMode : bool
  isGmtMode : bool
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
  arrow = [[auto
    float2(0.000,  0.000);
    float2(0.015, -0.015);
    float2(0.015, -0.006);
    float2(0.040, -0.006);
    float2(0.040,  0.006);
    float2(0.015,  0.006);
    float2(0.015,  0.015);
  ]]


struct Ccrp
  timeToRelease : float


struct Guidance
  isActive : bool
  guidanceType : GuidanceType
  lockState : GuidanceLockState


struct Visual
  quat : quat
  vel : float3
  pos : float3


def constrain_angle(var a : float)
  a = a % PI2
  if a < 0.0
    a += PI2
  return a


def angle_diff(a : float; b : float)
  var dif = (b - a + PI) % PI2
  if dif < 0.0
    dif += PI2
  return dif - PI


def loc_wpn(str : string) : string
  if str.empty()
    return ""
  return loc("ils/{str.replace("_default", "")}")


class Component : Canvas
  isValid : bool

  app : AcesApp?
  hero : Unit?
  fmw : FlightModelWrap?
  wc : WeaponController?
  fcm : FlightControlMode?
  secondaryWeapon : Weapon?
  totalTime : float
  visual : Visual
  ws : WeaponSlots?

  fontId : int
  fontIdLatin : int

  radar : Radar
  toi : Tracking
  spi : SensorPoi
  radarScopeSize : float2
  ccrp : Ccrp
  guidance : Guidance

  isDogFight : bool
  isAirGunMode : bool
  isAirGunUnrangedMode : bool
  isAirGunRangedMode : bool
  isGroundGunMode : bool
  isGroundRocketMode : bool
  isAtgmMode : bool
  isAamMode : bool
  isBombingCcrpMode : bool
  isBombingCcipMode : bool
  isBombingGuidedMode : bool
  hasReleasePerm : bool
  isOutsideRminRmax : bool
  fpmPos : float2
  nctr : string

  defaultLineWidth : float
  defaultFontSize : int
  defaultColor : E3DCOLOR
  nullColor : E3DCOLOR
  maskColor : E3DCOLOR
  shapes : Shapes = Shapes()

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    app = get_app()
    return if app == null
    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null
    wc = hero.weap
    return if wc == null
    fcm = app.flightControlMode
    return if fcm == null
    hero.calcPosVelQuatAtTime(app.usefulTotalTime, visual.pos, visual.vel, visual.quat)
    totalTime = float(app.usefulTotalTime)
    ws = new WeaponSlots(hero, app, fmw, wc)

    fontId = props.fontId
    fontIdLatin = props.fontIdLatin

    isValid = true
    defaultColor = *fmw.cockpit->getPageColor(MfdPageType.MFD_PLANE_ILS)
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

    hasReleasePerm = false
    isOutsideRminRmax = false

    radarScopeSize = float2(0.5, 0.5)

    if get_point_of_interest(spi.pos)
      spi.isSet = true
      spi.distance = length(spi.pos - hero.unitTm[3])
      spi.ilsPos = worldPosToHud(spi.pos)

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
    radar.isGmtMode = find(radarModeName, "GTM") >= 0
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
        toi.ilsPos = worldPosToHud(toi.pos)

    isAirGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS)
    isAirGunUnrangedMode = isAirGunMode && !toi.isActive
    isAirGunRangedMode = isAirGunMode && toi.isActive

    isGroundGunMode = fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS)

    isAamMode = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (secondaryWeapon == null || secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)))

    isBombingCcrpMode = spi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) &&
      (secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)
        || secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))))

    isBombingCcipMode = !spi.isSet && (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS) &&
       (secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)
       || secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))))

    isGroundRocketMode = (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.ROCKETS_TRIGGER))
    isAtgmMode = (secondaryWeapon != null && secondaryWeapon.trigger_no == int(WeaponTriggerType.AGM_TRIGGER))

    ccrp.timeToRelease = get_time_before_bomb_release()

    var lockState = GuidanceLockState.RESULT_INVALID
    var guidanceType = GuidanceType.TYPE_INVALID
    if secondaryWeapon != null
      guidanceType = get_weapon_guidance_type(secondaryWeapon)
      if secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)
        lockState = get_aam_guidance_lock_state()
      elif secondaryWeapon.trigger_no == int(WeaponTriggerType.AGM_TRIGGER)
        lockState = get_agm_guidance_lock_state()
      elif secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)
        lockState = get_bomb_guidance_lock_state()
    if lockState != GuidanceLockState.RESULT_INVALID && guidanceType != GuidanceType.TYPE_INVALID
      guidance.isActive = true
      guidance.lockState = lockState
      guidance.guidanceType = guidanceType


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
    let pos = visual.vel.length_sq() > factor ? worldVecToHud(visual.vel) : visual.vel.length_sq() / factor *  worldVecToHud(visual.vel)
    fpmPos = pos
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


  def quantizeAlt(alt : float) : int // Based on Su-35
    if alt < 100.0
      return floori(alt / 2.0) * 2;
    if alt < 500.0
      return floori(alt / 5.0) * 5;
    return floori(alt / 10.0) * 10;


  def quantizeSpeed(speed : float) : int // Based on Su-35
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
    let pos = float2(0.37, -0.365)
    let alt = hero.unitTm[3].y - app.currentScene.waterLevel
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
    drawStrAnchored(pos, fmt(abs(load) <= 10.0 ? ":.1f" : ":.0f", abs(load)), AnchorHorz.Center, AnchorVert.Center)

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
      continue if offset > mask || offset < -mask

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


  def drawHeadingTape()
    let posY = -0.4
    let interval = 5
    let count = 360 / interval
    let width = 0.22   // width of whole indicator
    let scale =  0.011 // degrees per canvas unit
    let mask = 0.24      // width of the heading tape mask
    let height = 0.02  // height of large marker
    setFontSize(roundi(0.8 * float(defaultFontSize)))

    let heading = constrain_angle(atan2(hero.unitTm[0].x, hero.unitTm[0].z))
    let vel = fast_normalize(hero.vel)
    let headingVel = constrain_angle(atan2(vel.x, vel.z))
    let headingVelDiff = angle_diff(heading, headingVel) * radToDeg

    drawLine(float2(width, posY), float2(-width, posY))

    let n = [[auto
      float2(-0.008,  0.014);
      float2(-0.008, -0.014);
      float2(0.008,  0.014);
      float2(0.008, -0.014);
    ]]
    drawLine(float2(0.0, posY), float2(0.0, posY + 0.03))

    for i in -count..count * 2 + 1
      let offset = (float(i * interval) - heading * radToDeg) * scale
      continue if offset > mask || offset < -mask

      if i % 2 == 0 // normal line
        drawLine(float2(offset, posY), float2(offset, posY - height))
        let deg = i * interval > 0 ? i * interval % 360 : 360 - abs(i * interval)
        if deg != 360 && deg != 0
          drawStrAnchored(float2(offset, posY - height - 0.02), "{fmt(":02d", deg / 10)}", AnchorHorz.Center, AnchorVert.Center)
        else
          drawPolyLine(n.to_array().translate(float2(offset, posY - height - 0.02)))
      else
        drawLine(float2(offset, posY), float2(offset, posY - height * 0.7))

    let caret = [[auto
      float2(-0.015,  0.034);
      float2(-0.0,  0.0);
      float2(0.015,  0.034);
    ]]
    drawPolyLine(caret.to_array().translate(float2(clamp(headingVelDiff * scale, -width, width), posY)))
    // masking
    setFillColor(maskColor)
    setColor(maskColor)
    let maskWidth = float(interval) * scale
    let maskHeight = 0.06
    drawBox(float2(-width - maskWidth, posY - maskHeight), float2(-width, posY))
    drawBox(float2(width, posY - maskHeight), float2(width + maskWidth, posY))
    // resets
    setFontSize(defaultFontSize)
    setFillColor(nullColor)
    setColor(defaultColor)


  def drawAoaConv(hand : float2[5])
    let pos = float2(-0.16, 0.35)
    let divs = 36
    let interval = PI2 / float(divs)
    let size = 0.155
    let scale =  0.0055 // degrees per canvas unit

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
    let isTvc = fmw.fm.appliedCT.maneuverabilityMode > fmw.fullAutopilotManeuverabilityModeTransition.x
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


  def drawRadarRangeScale(drawDlz : bool = true)
    let length = radarScopeSize.y
    let padding = 0.035
    let pos = float2(-radarScopeSize.x * 0.5 - padding, length * 0.5)
    let divs = 5
    let stepWidth = 0.015

    let step = length / float(divs)
    let displRng = ceili(radar.displayRangeMax - radar.displayRangeMin)
    let displStep = float(displRng) / float(divs)

    return if displRng == 0

    drawLine(pos, float2(pos.x, pos.y - length))
    setFontSize(roundi(0.6 * float(defaultFontSize)))
    for i in 0 .. divs + 1
      let posY = -float(i) * step + pos.y
      drawLine(float2(pos.x, posY), float2(pos.x - stepWidth, posY))
      drawStrAnchored(float2(pos.x - stepWidth, posY), "{roundi(float(i) * displStep)}", AnchorHorz.Right, AnchorVert.Center)

    // DLZ
    if drawDlz
      if get_radar_hud_aam_launch_zone_visible()
        setLineWidth(2.0 * defaultLineWidth)

        let dlzMax = get_radar_hud_aam_launch_zone_dist_max()
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

        isOutsideRminRmax = toi.distance / float(radar.displayRangeMax * 1000.0) > dlzMax
        setLineWidth(defaultLineWidth)

    // Target range
    if toi.isActive
      let tgt = toi.distance / float(radar.displayRangeMax * 1000.0)
      drawClosedPolyLine(shapes.arrow.to_array().translate(float2(pos.x, pos.y - tgt * length)))

    setFontSize(defaultFontSize)


  def drawGroundRangeScale(minRange : float = 0.0; maxRange : float = 0.0; targetRange : float = 0.0)
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
    if maxRange != 0.0
      let dlzMax = maxRange / float(radar.displayRangeMax * 1000.0)
      let dlzMaxY = pos.y - dlzMax * length
      if dlzMax < 1.0
        setLineWidth(2.0 * defaultLineWidth)
        drawLine(float2(pos.x - stepWidth, dlzMaxY), float2(pos.x + 0.02, dlzMaxY))
        setLineWidth(defaultLineWidth)
    if minRange != 0.0
      let dlzMin = minRange / float(radar.displayRangeMax * 1000.0)
      let dlzMinY = pos.y - dlzMin * length
      if dlzMin < 1.0
        let bracket = [[auto
          float2(-stepWidth, 0.01);
          float2(-stepWidth, 0.0);
          float2(stepWidth, 0.0);
          float2(stepWidth, 0.01);
        ]]
        drawPolyLine(bracket.to_array().translate(float2(pos.x, dlzMinY)))

    // Target range
    if targetRange != 0.0
      let tgt = clamp(targetRange / float(radar.displayRangeMax * 1000.0), 0.0, 1.04)
      drawClosedPolyLine(shapes.arrow.to_array().translate(float2(pos.x, pos.y - tgt * length)))

    setFontSize(defaultFontSize)


  def drawSelectionCue()
    return if !get_radar_hud_cue_visible() || toi.isActive

    let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
    let cueAzimuthHwr = get_radar_hud_cue_azimuth_half_width_rel()
    let cueDistWidthRel = get_radar_hud_cue_dist_width_rel()
    let cuePos = float2((get_radar_hud_cue_azimuth() * (get_radar_hud_target_azimuth_width() / azimuthRange - cueAzimuthHwr)) * radarScopeSize.x,
            (1. - (0.5 * cueDistWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - cueDistWidthRel)) - 0.5) * radarScopeSize.y)
    if !radar.isIrst
      let lt = float2(cuePos.x - cueAzimuthHwr * radarScopeSize.x, cuePos.y - cueDistWidthRel * radarScopeSize.y * 0.5)
      let rb = float2(cuePos.x + cueAzimuthHwr * radarScopeSize.x, cuePos.y + cueDistWidthRel * radarScopeSize.y * 0.5)
      drawBox(lt, rb)
    else
      let xl = cuePos.x - cueAzimuthHwr * radarScopeSize.x
      let xr = cuePos.x + cueAzimuthHwr * radarScopeSize.x
      drawLine(float2(xl, -0.5 * radarScopeSize.y), float2(xl, 0.5 * radarScopeSize.y))
      drawLine(float2(xr, -0.5 * radarScopeSize.y), float2(xr, 0.5 * radarScopeSize.y))


  def drawBScopeTargets()
    setFontSize(roundi(0.5 * float(defaultFontSize)))
    get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
      for t in targets
        continue if !t.isEnemy
        continue if t.targetType == int(RadarTargetType.TYPE_OWN_WEAPON)
        continue if t.targetType == int(RadarTargetType.TYPE_OWN_WEAPON_TARGET)

        let isClamped = t.azimuthRel < 0.0 || t.azimuthRel > 1.0 || t.distanceRel < 0.0 || t.distanceRel > 1.0
        continue if isClamped && fract(totalTime * 2.0) < 0.5

        let pos = float2(
          (clamp(t.azimuthRel, 0.0, 1.0) - 0.5) * radarScopeSize.x,
          (-clamp(t.distanceRel, 0.0, 1.0) + 0.5) * radarScopeSize.y)

        if t.isAttacked || t.isTracked || t.isDetected
          drawClosedPolyLine(shapes.diamond.to_array().translate(pos))
        else
          drawCross(pos, float2(0.02))

        if t.isTracked || t.isDetected
          if isAamMode && !isOutsideRminRmax && (guidance.lockState == GuidanceLockState.RESULT_TRACKING || guidance.lockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH)
            drawLine(float2(pos.x, pos.y + 0.02), float2(pos.x, pos.y - 0.02))
            drawLine(float2(pos.x + 0.01, pos.y), float2(pos.x - 0.01, pos.y))
        if t.isAttacked
          drawCross(pos, float2(0.02))

        drawStrAnchored(pos - float2(0.015, 0.0), "{int(t.id)}", AnchorHorz.Right, AnchorVert.Center)
    setFontSize(defaultFontSize)


  def drawCScopeTargets()
    setFontSize(roundi(0.5 * float(defaultFontSize)))
    get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
      for t in targets
        continue if !t.isEnemy
        continue if t.targetType == int(RadarTargetType.TYPE_OWN_WEAPON)
        continue if t.targetType == int(RadarTargetType.TYPE_OWN_WEAPON_TARGET)
        // Scale elevation up to full radar display
        var elevationRel = t.elevationRel
        if !t.isTracked
          let elevationAbs = t.elevationRel * (get_radar_hud_elevation_max() - get_radar_hud_elevation_min()) + get_radar_hud_elevation_min()
          elevationRel = (elevationAbs - get_radar_hud_scan_elevation_min()) / (get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min())

        let isClamped = t.azimuthRel < 0.0 || t.azimuthRel > 1.0 || elevationRel < 0.0 || elevationRel > 1.0
        continue if isClamped && fract(totalTime * 2.0) < 0.5

        let pos = float2(
          (clamp(t.azimuthRel, 0.0, 1.0) - 0.5) * radarScopeSize.x,
          (-clamp(elevationRel, 0.0, 1.0) + 0.5) * radarScopeSize.y)

        if t.isAttacked || t.isTracked || t.isDetected
          drawClosedPolyLine(shapes.diamond.to_array().translate(pos))
        else
          drawCross(pos, float2(0.02))

        if t.isTracked || t.isDetected
          if !isOutsideRminRmax && (guidance.lockState == GuidanceLockState.RESULT_TRACKING || guidance.lockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH)
            drawLine(float2(pos.x, pos.y + 0.02), float2(pos.x, pos.y - 0.02))
            drawLine(float2(pos.x + 0.01, pos.y), float2(pos.x - 0.01, pos.y))
        if t.isAttacked
          drawCross(pos, float2(0.02))

        drawStrAnchored(pos - float2(0.015, 0.0), "{int(t.id)}", AnchorHorz.Right, AnchorVert.Center)
    setFontSize(defaultFontSize)


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
      let el = -(get_radar_hud_elevation() - 0.5) * 0.5
      let y1 = clamp(el - trackSize * elScale, -radarScopeSize.y * 0.5, 1.0)
      let y2 = clamp(el + trackSize * elScale, -1.0, radarScopeSize.y * 0.5)
      drawLine(
        float2(radarScopeSize.x * 0.5 + padding + zeroMark, y1),
        float2(radarScopeSize.x * 0.5 + padding + zeroMark, y2))


  def drawScanArea()
    let lt = float2(get_radar_hud_scan_azimuth_min(), get_radar_hud_scan_elevation_max())
    let rb = float2(get_radar_hud_scan_azimuth_max(), get_radar_hud_scan_elevation_min())
    drawBox(angleToHud(lt), angleToHud(rb))


  def drawLosTarget()
    return if !toi.isActive

    let radius = 0.03
    if isOutOfCanvas(toi.ilsPos, 1.8 * hudPadding)
      return if fract(totalTime * 2.0) < 0.5

      let dir = fast_normalize(toi.ilsPos)
      let rt = traceRayToCanvasEdges(float2(0.0), dir, 1.8 * hudPadding)
      let pos = rt * dir
      drawCircle(pos, radius)
    else
      drawCircle(toi.ilsPos, radius)


  def drawTargetSpeedAlt()
    return if !toi.isActive

    let posAlt = float2(0.31, -0.42)
    let posSpd = float2(-0.33, -0.42)
    let box = float2(0.1, 0.034)

    let tangVel = toi.angVel * toi.distance
    let relVel = tangVel + toi.distanceRate * toi.dirNorm;
    let targetVel = hero.vel + relVel
    let targetSpd = length(targetVel) * mpsToKmh
    let targetBaroAlt = toi.pos.y - app.currentScene.waterLevel

    setFontSize(roundi(0.7 * float(defaultFontSize)))
    drawStrAnchored(posAlt, "{floori(targetBaroAlt / 10.0) * 10}", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(posSpd, "{floori(targetSpd / 10.0) * 10}", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(defaultFontSize)

    drawBox(posAlt - box * 0.5, posAlt + box * 0.5)
    drawBox(posSpd - box * 0.5, posSpd + box * 0.5)


  def drawAspectMode()
    let pos = float2(-0.46, -0.1)
    drawStrAnchored(pos, radar.isHdnMode ? "ППС" : "ЗПС", AnchorHorz.Center, AnchorVert.Center)


  def drawRadarMode()
    var mode = "ДБВ"
    if radar.isHmdMode || radar.isAcmMode
      mode = "ББВ"
    elif radar.isGmtMode
      mode = "ДБП"
    drawStrAnchored(float2(0.44, 0.24), mode, AnchorHorz.Center, AnchorVert.Center)


  def drawSensorOperatingMode()
    drawStrAnchored(float2(-0.46, -0.16), radar.isIrst ? "ТП" : "РЛ", AnchorHorz.Center, AnchorVert.Center)


  def drawIlsOperatingMode()
    drawStrAnchored(float2(-0.46, -0.22), "ИЛС", AnchorHorz.Center, AnchorVert.Center)


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


  def drawTargetTrackingStatus()
    return if !radar.isTrkMode

    drawStrAnchored(float2(0.43, 0.195), "СЦ", AnchorHorz.Center, AnchorVert.Center)


  def drawRadar()
    return if !radar.isEmitting && !radar.isHmdMode
    // Labels
    drawAspectMode()
    drawRadarMode()
    drawSensorOperatingMode()
    drawTargetTrackingStatus()
    // Radar symbology occluded
    return if (radar.isHmdMode
      || isGroundGunMode
      || isGroundRocketMode
      || isBombingCcipMode
      || isBombingCcrpMode
      || isAtgmMode)
    // Main radar modes
    if isAirGunRangedMode
      drawRadarRangeScale(false)
      drawLosTarget()
    elif isAirGunUnrangedMode
      if radar.isVerticalScan
        drawScanArea()
    elif radar.isAcmMode
      drawScanArea()
    elif radar.isIrst
      drawRadarRangeScale()
      drawCScopeTargets()
      drawRadarAzimuthElevation()
      drawLosTarget()
      drawSelectionCue()
      drawMissileLeadMarker()
      drawNctr()
    else
      drawRadarRangeScale()
      drawBScopeTargets()
      drawRadarAzimuthElevation()
      drawLosTarget()
      drawSelectionCue()
      drawMissileLeadMarker()
      drawNctr()

    drawTargetSpeedAlt()


  def drawReleasePerm()
    let pos = float2(0.0, 0.3)
    if secondaryWeapon != null
      if isGroundRocketMode
        hasReleasePerm = !isOutsideRminRmax && fcm.isRocketImpactValid
      elif isBombingCcrpMode
        if ccrp.timeToRelease < 5.0 && ccrp.timeToRelease > 0.0
          if secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER) && guidance.guidanceType == GuidanceType.TYPE_OPTICAL
            hasReleasePerm = guidance.lockState == GuidanceLockState.RESULT_TRACKING
          else
            hasReleasePerm = true
          hasReleasePerm = hasReleasePerm && *wc->getBombingLimits(false).isDropAllowed(hero.pos.y - app.currentScene.waterLevel, fmw.tangage, fmw.roll, false)
      elif isBombingCcipMode
        if !isOutsideRminRmax
          if secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER) && guidance.guidanceType == GuidanceType.TYPE_OPTICAL
            hasReleasePerm = guidance.lockState == GuidanceLockState.RESULT_TRACKING
          else
            hasReleasePerm = true
          hasReleasePerm = hasReleasePerm && *wc->getBombingLimits(false).isDropAllowed(hero.pos.y - app.currentScene.waterLevel, fmw.tangage, fmw.roll, false)
      elif isAtgmMode
        if guidance.guidanceType == GuidanceType.TYPE_OPTICAL
          hasReleasePerm = guidance.lockState == GuidanceLockState.RESULT_TRACKING
        elif guidance.guidanceType == GuidanceType.TYPE_LASER_ILLUMINATION
          hasReleasePerm = true
      elif isAamMode
        hasReleasePerm = !isOutsideRminRmax && (guidance.lockState == GuidanceLockState.RESULT_TRACKING || guidance.lockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH)

      var machLimit, verAccelLimit = VERY_BIG_NUMBER
      var gearLim = float2(0.0)
      var isBlocked = false
      *wc->getNextGunLimits(secondaryWeapon.trigger_no, isBlocked, machLimit, verAccelLimit, gearLim)
      if isBlocked || fmw.fm.Mach > machLimit || float(fmw.fm.localAccel.y) > verAccelLimit
        hasReleasePerm = false

    if isGroundGunMode
      hasReleasePerm = !isOutsideRminRmax && fcm.isCannonImpactValid
    elif isAirGunUnrangedMode
      hasReleasePerm = true
    elif isAirGunRangedMode
      hasReleasePerm = !isOutsideRminRmax

    hasReleasePerm = hasReleasePerm && !(fmw.isOnGround || fmw.fm.currentAlt < fmw.minAltitudeForDropShells) // Armed check
    hasReleasePerm = hasReleasePerm && !hero.cannotShoot

    if hasReleasePerm
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


  def drawSpi()
    return if !spi.isSet

    let radius = 0.02

    let alt = spi.pos.y - app.currentScene.waterLevel
    setFontSize(roundi(0.7 * float(defaultFontSize)))
    drawStrAnchored(float2(0.32, -0.408), "{floori(alt / 10.0) * 10}", AnchorHorz.Right, AnchorVert.Bottom)
    setFontSize(defaultFontSize)
    if isOutOfCanvas(spi.ilsPos, 1.8 * hudPadding)
      return if fract(totalTime * 2.0) < 0.5

      let dir = fast_normalize(spi.ilsPos)
      let rt = traceRayToCanvasEdges(float2(0.0), dir, 1.8 * hudPadding)
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

    isOutsideRminRmax = ccipRange > maxRange || ccipRange < minRange


  def drawRocketMode()
    return if !isGroundRocketMode && !isAtgmMode

    drawSpi()
    drawIlsOperatingMode()
    drawStrAnchored(float2(0.4, 0.28), "ПЗ", AnchorHorz.Left, AnchorVert.Center)
    drawTargetingMode(spi.isSet ? "ПрЗ" : "НС")

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

    isOutsideRminRmax = ccipRange > maxRange || ccipRange < minRange


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

    if toi.distance > rangeMax
      isOutsideRminRmax = true
      return

    drawStrAnchored(float2(0.43, 0.3), "НС", AnchorHorz.Center, AnchorVert.Center)

    var pos = float2(0.0)
    if fcm.isCannonFireDirectionValid
      pos = worldPosToHud((hero.unitTm * fcm.averageCannonPosition) + fcm.cannonAimDirection);
    elif fcm.isCannonAimValid
      var offsetPitchRotTm : float3x4
      rotzTM(fmw.props.staticAimPitch, offsetPitchRotTm)
      var gyroOffset = inverse(hero.unitTm) * fcm.cannonAimPosition
      gyroOffset = offsetPitchRotTm * gyroOffset
      pos = worldPosToHud(hero.unitTm * gyroOffset)
    else
      return

    drawReticle(pos)
    drawDot(pos)

    let rangeClamped = clamp(toi.distance, rangeMin, rangeMax)

    let relRange = (rangeClamped - rangeMin) / (rangeMax - rangeMin)
    let angle = PI3_2 + PI2 * relRange
    setLineWidth(2.0 * defaultLineWidth)
    drawSector(pos, float2(0.025), float2(PI3_2, angle))
    setLineWidth(defaultLineWidth)

    isOutsideRminRmax = toi.distance > rangeMax && toi.distance < rangeMin


  def drawGunMode()
    return if !isAirGunMode && !isGroundGunMode

    if isAirGunUnrangedMode
      drawAirGunUnranged()
    elif isAirGunRangedMode
      drawAirGunRanged()
    elif isGroundGunMode
      drawGroundGun()


  def drawWeaponCodeOrGunAmmo()
    let pos = float2(0.32, 0.46)

    if isAirGunMode || isGroundGunMode
      let ammoCount = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
        wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))

      setFontSize(roundi(0.8 * float(defaultFontSize)))
      drawStrAnchored(pos, "{ammoCount}", AnchorHorz.Right, AnchorVert.Bottom)

      let padding = float2(0.01)
      let size = float2(0.06, 0.025)
      drawBox(pos - size - padding, pos + padding)

      setFontSize(defaultFontSize)
    elif secondaryWeapon != null
      let name = get_weapon_name(*secondaryWeapon.prop.shellProps)
      drawStrAnchored(pos, "{loc_wpn(name)}", AnchorHorz.Center, AnchorVert.Bottom)


  def drawTargetingMode(mode : string)
    drawStrAnchored(float2(0.4, 0.32), mode, AnchorHorz.Left, AnchorVert.Center)


  def drawBombCcip()
    var pos = worldPosToHud(fcm.bombImpactPosition)
    let m = (pos.y - fpmPos.y) / (pos.x - fpmPos.x)
    var zeroPos = float2((pos.x - pos.y / m), 0.0)
    let zeroPosUnclamped = zeroPos

    if isOutOfCanvas(zeroPos, 1.6 * hudPadding)
      let dir = fast_normalize(zeroPos)
      let rt = traceRayToCanvasEdges(float2(0.0), dir, 1.8 * hudPadding)
      zeroPos = rt * dir
      if fract(totalTime * 2.0) < 0.5
        drawCircle(zeroPos, 0.03)
    else
      drawCircle(zeroPos, 0.03)

    if isOutOfCanvas(pos, 1.8 * hudPadding)
      let dir = fast_normalize(pos)
      let rt = traceRayToCanvasEdges(float2(0.0), dir, 1.8 * hudPadding)
      pos = rt * dir
      drawLine(lerp(pos, zeroPos, 0.02), lerp(pos, zeroPosUnclamped, 0.5))

    drawReticle(pos)


  def drawBombCcrp()
    let pos = float2(-0.12, 0.3)

    if !(ccrp.timeToRelease > 0.0)
      return
    if ccrp.timeToRelease < 60.0
      setFontSize(roundi(0.7 * float(defaultFontSize)))
      drawStrAnchored(pos, fmt(":02d", roundi(ccrp.timeToRelease)), AnchorHorz.Center, AnchorVert.Center)
      setFontSize(defaultFontSize)
    if ccrp.timeToRelease < 20.0
      let radius = 0.03

      let angle = PI3_2 + PI2 * (ccrp.timeToRelease / 20.0)
      drawSector(pos, float2(radius), float2(PI3_2, angle))

    drawStrAnchored(float2(-0.46, 0.2), "АТК", AnchorHorz.Center, AnchorVert.Center)


  def drawBombMode()
    return if !isBombingCcipMode && !isBombingCcrpMode

    let avoidRange = get_weapon_shatter_radius(secondaryWeapon)
    let ccipRange = length(fcm.bombImpactPosition - hero.pos)

    drawIlsOperatingMode()
    drawStrAnchored(float2(0.4, 0.28), "ПЗ", AnchorHorz.Left, AnchorVert.Center)
    drawTargetingMode(spi.isSet ? "НВГБ" : "НС")

    if isBombingCcipMode
      drawBombCcip()
      drawGroundRangeScale(avoidRange * 3.0, ccipRange, 0.0)
    elif isBombingCcrpMode
      drawSpi()
      drawBombCcip()
      drawBombCcrp()
      drawGroundRangeScale(avoidRange * 3.0, ccipRange, spi.distance)

    if ccipRange < avoidRange || fmw.fm.currentAlt < avoidRange
      isOutsideRminRmax = true


  def drawLaserDesignatorStatus()
    return if !fcm.ctrlMap.isLaserDesignatorEnabled

    let pos = float2(-0.46, 0.0)
    drawStrAnchored(pos, "ЛД", AnchorHorz.Center, AnchorVert.Center)


  def worldPosToHud(pos : float3)
    return worldVecToHud(pos - hero.pos)


  def worldVecToHud(dirVec : float3)
    var localVec = quat_mul_vec(math::quat(inverse(hero.unitTm)), dirVec)
    let isBehind = localVec.x < 0.0 // Point in rear hemisphere
    if isBehind
      localVec.x = -localVec.x
    localVec = fast_normalize(localVec)
    let screenX = (atan2(localVec.x, localVec.z) - PI_2)
    let screenY = asin(localVec.y)
    var result = float2(screenX / hudFovLimits.x, -screenY / hudFovLimits.y)
    return !isBehind ? result : result * 100.0


  def angleToHud(angle : float2)
    return float2(angle.x / hudFovLimits.x, -angle.y / hudFovLimits.y)


  def drawWeaponSlots()
    return if isAirGunMode || isGroundGunMode

    let pos = float2(0.0, 0.44)
    let numbers <- [[auto 11; 9; 7; 5; 3; 1; 2; 4; 6; 8; 10; 12]]
    let count = numbers.length()
    let size = float2(0.22, 0.0)
    let boxSize = 0.014
    let engSize = 0.012
    let eng1Slot = 4
    let eng2Slot = 7

    let stations <- [{
      for i in 0 .. count;
      float2(lerp(-size.x, size.x, float(i) / float(count - 1)), pos.y)
    }]
    // Draw aircraft outline
    setLineWidth(1.6 * defaultLineWidth)
    drawLine(pos + size, pos - size)
    let relLineWidth = toRelY(lineWidthHdpx)
    for i, idx in stations, 0 .. count
      if idx == eng1Slot || idx == eng2Slot
        drawDot(i + float2(0.0, relLineWidth + engSize * 2.0))
      else
        drawDot(i + float2(0.0, relLineWidth))
    setLineWidth(defaultLineWidth)
    // Engines
    let eng1Pos = stations[eng1Slot]
    let eng2Pos = stations[eng2Slot]
    drawBox(float2(eng1Pos.x - engSize, eng1Pos.y), float2(eng1Pos.x + engSize, eng1Pos.y + engSize * 2.0))
    drawBox(float2(eng2Pos.x - engSize, eng1Pos.y), float2(eng2Pos.x + engSize, eng1Pos.y + engSize * 2.0))

    let arrowHead = [[auto
      float2(-0.01, 0.01);
      float2(-0.0, -0.0);
      float2(0.01, 0.01);
    ]]

    setFontSize(roundi(0.5 * float(defaultFontSize)))
    for i in 0 .. ws.length()
      continue if (hero.slotIdByWeaponId[i] <= 0)
      var slot = ws.getWeaponSlot(i)
      slot.slot -= 1

      continue if slot.slot > stations.length() - 1
      continue if slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)
      continue if slot.maxAmmo < 1
      let slotPos = stations[slot.slot]
      // Draw arrows of empty stations
      let arrowPos = (slot.slot == eng1Slot || slot.slot == eng2Slot) ? float2(slotPos.x, slotPos.y + engSize * 2.0 + relLineWidth) : float2(slotPos.x, slotPos.y + relLineWidth)

      drawPolyLine(arrowHead.to_array().translate(arrowPos))
      drawLine(arrowPos, arrowPos + float2(0.0, 0.025))

      // Draw stations
      continue if slot.curAmmo < 1
      drawStrAnchored(float2(slotPos.x, slotPos.y - boxSize), "{numbers[slot.slot]}", AnchorHorz.Center, AnchorVert.Center)

      continue if !slot.selected
      drawBox(float2(slotPos.x - boxSize, slotPos.y - boxSize * 2.0), float2(slotPos.x + boxSize, slotPos.y))

    setFontSize(defaultFontSize)


  def drawPermanentLabels()
    setFontSize(roundi(0.7   * float(defaultFontSize)))
    drawStrAnchored(float2(0.42, 0.39), "УВОД ОТКЛ", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(defaultFontSize)


  def drawMissileLeadMarker()
    return if !isAamMode

    let radius = 0.012
    get_radar_hud_screen_targets() <| $(targets : array<RadarScreenTarget> const#)
      for t in targets
        continue if !t.isDetected && !t.isTracked && !t.hasAimPos && !t.isEnemy

        nctr := t.id
        var pos = worldPosToHud(t.aimPos)
        if isOutOfCanvas(pos, hudPadding)
          return if fract(totalTime * 2.0) < 0.5

          let dir = fast_normalize(pos)
          let rt = traceRayToCanvasEdges(float2(0.0), dir, 1.8 * hudPadding)
          pos = rt * dir
        drawCircle(pos, radius)


  def drawNctr()
    return if nctr.empty()

    setFont(fontIdLatin)
    setFontSize(defaultFontSize)
    drawStrAnchored(float2(0.43, 0.15), loc(nctr), AnchorHorz.Center, AnchorVert.Center)
    setFont(fontId)
    setFontSize(defaultFontSize)


  def drawThrottle()
    return if !fmw.isLocalControl

    let relEngPower = fmw.fm.appliedCT.getPower(0)
    var throttle = "МГ"
    if relEngPower >= 1.009 && *fmw.fm.EI->propulsion_isAfterburnerEffective(fmw.fm)
      throttle = "Ф"
    elif relEngPower >= 0.635
      throttle = "МАКС"
    drawStrAnchored(float2(-0.45, 0.3), throttle, AnchorHorz.Center, AnchorVert.Center)


  def drawArtificialHorizon()
    let euler = euler_from_quat(math::quat(hero.unitTm))
    var pos = -angleToHud(float2(0.0, euler.y))
    var isClamped = false;

    if isOutOfCanvas(pos, 2.0 * hudPadding)
      let dir = fast_normalize(pos)
      let rt = traceRayToCanvasEdges(float2(0.0), dir, 2.0 * hudPadding)
      pos = rt * dir
      isClamped = true
    var sina, cosa : float = 0.0
    sincos(euler.z, sina, cosa)
    let line = [[auto
      float2(pos.x + 1.0, pos.y);
      float2(pos.x - 1.0, pos.y)
    ]]
    setLineWidth(0.7 * defaultLineWidth)
    if isClamped
      drawDashedPolyLine(line.to_array().rotate(sina, cosa), 0.008, 0.012)
    else
      drawPolyLine(line.to_array().rotate(sina, cosa))
    setLineWidth(defaultLineWidth)


  def drawFlightSymbology()
    if !isAirGunUnrangedMode
      drawPitchLadder()
      drawRollScale()
      drawRollIndicator()
      drawHeadingTape()
      drawArtificialHorizon()
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
    drawLaserDesignatorStatus()
    drawRadar()
    drawHmd()
    drawGunMode()
    drawRocketMode()
    drawBombMode()
    drawWeaponCodeOrGunAmmo()
    drawWeaponSlots()
    drawPermanentLabels()
    drawReleasePerm()
    drawThrottle()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.fontIdLatin = getInt(props, "fontIdLatin", 0)
