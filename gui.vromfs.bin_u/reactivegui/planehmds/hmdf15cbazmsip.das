require darg
require DagorStdGuiRender
require DagorMath
require DagorSystem
require math
require FlightModelWrap
require HeroManager
require Unit
require Sensors
require FlightControl
require Weapon
require app
require hud
require RadarHud
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require DagorMathUtils
require strings
require GuidanceLock

let airGunDistance = 1000.0

struct PropStorage
  fontId : int

class Component : Canvas
  isValid : bool = false
  unit : Unit? = null
  fmw : FlightModelWrap? = null

  heading : float = 0.0
  barometricAltitude : float = 0.0
  ias : float = 0.0

  hasTrackedTarget : bool = false
  trackedTargetVisible : bool = false
  trackedTargetAbsPos : float2

  hasLockedTarget : bool = false
  lockedTargetAbsPos : float2

  showAAMLaunchZone : bool = false
  currentLaunchDist : float = 0.0
  launchDistLim : float2

  isArmed : bool = false
  isDogFight : bool = false

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    unit = get_watched_not_delayed_hero()
    fmw = as_fmw(unit)
    return if fmw == null

    heading = norm_ang_deg((dir_to_angles(unit.unitTm[0]).x + PI * 0.5) * radToDeg)
    barometricAltitude = (unit.unitTm[3].y - get_app().currentScene.waterLevel) * metrToFeet
    ias = fmw.ias * mpsToKnots

    var trackingDist = 0.0f
    using() <| $(var target : TargetOfInterest#)
      if unit.sensors.getSelectedTargetOfInterest(unit.detector, target)
        hasTrackedTarget = true
        let pos = target.from + target.dirNorm * target.distance
        trackingDist = target.distance
        var hmdPos : float2
        if world_to_hmd_screen(pos, hmdPos)
          trackedTargetVisible = true
          trackedTargetAbsPos = hmdPos

    let aamLockState = get_aam_guidance_lock_state()
    let guidanceType = get_cur_weapon_guidance_type()

    let lockStateOk = aamLockState == GuidanceLockState.RESULT_TRACKING || aamLockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH
    let guidanceTypeOk = guidanceType == GuidanceType.TYPE_OPTICAL || guidanceType == GuidanceType.TYPE_SARH || guidanceType == GuidanceType.TYPE_ARH
    if lockStateOk && guidanceTypeOk
      hasLockedTarget = get_aam_tracker_visible()
      lockedTargetAbsPos = hasLockedTarget ? get_screen_aam_tracker_pos() : trackedTargetAbsPos

    var secondaryWeapon : Weapon? = null
    get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
      secondaryWeapon := weapon

    let isBombing = ((fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) || fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS)) &&
      secondaryWeapon != null && (secondaryWeapon.trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER) || secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)))
    showAAMLaunchZone = !isBombing && hasTrackedTarget
    if showAAMLaunchZone
      currentLaunchDist = get_radar_hud_aam_launch_zone_dist()
      launchDistLim = float2(get_radar_hud_aam_launch_zone_dist_min(), get_radar_hud_aam_launch_zone_dist_max())

    isArmed = !(fmw.isOnGround || fmw.fm.currentAlt < fmw.minAltitudeForDropShells)

    let isAcmMode = find(get_radar_hud_mode_name(), "ACM") >= 0
    let isTrkMode = find(get_radar_hud_mode_name(), "track") >= 0
    isDogFight = (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET) &&
      (isAcmMode || (isTrkMode && hasTrackedTarget && trackingDist < 2.0 * airGunDistance))))

    setColor(*fmw.cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS))
    setLineWidth(floor(6.0 * fmw.cockpit.ilsLineWidthScale))
    setFont(props.fontId)
    isValid = true

  def drawLaunchZone()
    return if !showAAMLaunchZone
    let maxT = 1.1
    let height = 0.25
    let pos = toAbsPos(float2(0.15, 0.0))
    let size = toAbsXY(float2(0.005, -height))
    pushAxes(pos, size) // [0, 1], +y - up

    drawLine(float2(0.0), float2(0.0, 1.0))
    drawLine(float2(0.0), float2(0.5, 0.0))
    drawLine(float2(0.0, 1.0), float2(0.5, 1.0))

    if (launchDistLim.x > 0.0 && launchDistLim.y > 0.0 && launchDistLim.y - launchDistLim.x > 0.0)
      let t = clamp((currentLaunchDist -  launchDistLim.x) / (launchDistLim.y - launchDistLim.x), 0.0, maxT)
      drawBox(float2(-0.5, t), float2(0))

    popAxes()

  def drawBarometricAltitude()
    let height = 0.4
    let size = toAbsXY(float2(0.03, -height))
    let pos = toAbsPos(float2(0.2, 0.5 * height))
    pushAxes(pos, size) // [0, 1], +y - up

    let altSpan = 1200.0
    let altMarkDelta = 100.0

    let bot = barometricAltitude - altSpan * 0.5

    setViewport(float2(-1.0, 0.0), float2(1.0, 1.0))
    let count = int(altSpan * 0.5 / altMarkDelta)
    let altI = roundi(barometricAltitude / float(altMarkDelta))
    for i in range(max(altI - count, 0), altI + count + 1)
      let v = float(i) * altMarkDelta
      let t = (v - bot) / altSpan

      if i % 10 == 0
        let displayVal = floori(v / 1000.0)
        drawStrAnchored(float2(0.6, t), "{displayVal}", AnchorHorz.Left, AnchorVert.Center)
        drawLine(float2(-0.5, t), float2(0.5, t))
      elif i % 5 == 0
        drawLine(float2(-0.4, t), float2(0.4, t))
      else
        drawLine(float2(-0.2, t), float2(0.2, t))

    restoreViewport()
    drawArrow(float2(-1, 0.5), float2(-0.6, 0.5))

    popAxes()

  def drawIAS()
    let height = 0.4
    let size = toAbsXY(float2(0.03, -height))
    let pos = toAbsPos(float2(-0.2, 0.5 * height))
    pushAxes(pos, size) // [0, 1], +y - up

    let iasSpan = 150.0
    let markDelta = 10.0

    let bot = ias - iasSpan * 0.5

    setViewport(float2(-1.0, 0.0), float2(1.0, 1.0))
    let count = int(iasSpan * 0.5 / markDelta)
    let altI = roundi(ias / float(markDelta))
    for i in range(max(altI - count, 0), altI + count + 1)
      let v = float(i) * markDelta
      let t = (v - bot) / iasSpan

      if i % 5 == 0
        let displayVal = floori(v / 10.0)
        drawStrAnchored(float2(-0.6, t), "{displayVal}", AnchorHorz.Right, AnchorVert.Center)
        drawLine(float2(-0.5, t), float2(0.5, t))
      else
        drawLine(float2(-0.3, t), float2(0.3, t))

    restoreViewport()
    drawArrow(float2(1, 0.5), float2(0.6, 0.5))

    popAxes()

  def drawBoreSight()
    let size = float2(toAbsX(0.1))
    let pos = toAbsPos(float2(0.0, 0.0))
    pushAxes(pos, size) // [-0.5. 0.5]

    drawCrossReticle(float2(0.0), float2(1.0), float2(0.5))
    drawDot(float2(0.0))

    popAxes()

  targetMarkSize : float = 0.01
  def drawTrackedTarget()
    return if !trackedTargetVisible
    pushAxes(trackedTargetAbsPos, float2(1.0))
    let size = canvasSize.x * targetMarkSize
    drawBox(float2(size), float2(-size))
    popAxes()

  def drawAamTrackingMark()
    return if !hasLockedTarget
    let size = canvasSize.x * targetMarkSize * 2.5
    pushAxes(lockedTargetAbsPos, float2(1.0))
    drawLine(float2(size, 0), float2(0, size))
    drawLine(float2(-size, 0), float2(0, size))
    drawLine(float2(size, 0), float2(0, -size))
    drawLine(float2(-size, 0), float2(0, -size))
    popAxes()

  def drawHeading()
    let pos = toAbsPos(float2(0.0, -0.4))
    let size = toAbsXY(float2(0.25, 0.03))
    pushAxes(pos, size) // [-0.5, 0.5]

    drawHeadingTape()
    drawHeadingArrow()

    popAxes()

  def drawHeadingTape()
    setViewport(float2(-0.5, -1.), float2(0.5, 1.))

    let degreesHalfWidth = 40
    let dashIntervalDegrees = 10

    let headingI = roundi(heading / float(dashIntervalDegrees))

    let count = degreesHalfWidth / dashIntervalDegrees
    for i in range(-count, count + 1)
      let angleI = headingI + i
      let angle = float((angleI) * dashIntervalDegrees)
      let t = -(heading - angle) / float(degreesHalfWidth * 2)

      if angleI % 3 == 0
        drawLine(float2(t, -0.5), float2(t, 0.5))
        drawStrAnchored(float2(t, -0.6), "{norm_ang_deg(angle)}", AnchorHorz.Center, AnchorVert.Bottom)
      else
        drawLine(float2(t, -0.35), float2(t, 0.35))

    restoreViewport()

  def drawHeadingArrow()
    let arrowLength = 0.8
    let arrowPadding = 0.2
    let arrowPos = float2(0, 0.5 + arrowPadding)
    let arrowStart = arrowPos + float2(0, arrowLength)
    drawArrow(arrowStart, arrowPos)

  def drawWeaponStatus()
    let pos = float2(-0.2, 0.3)
    setFontSize(40)
    setCaretPosition(pos)
    if isArmed
      printStrLn("ARM")
    if isDogFight
      printStrLn("DOG")

  def drawArrow(var from : float2; var to : float2)
    let headLengthFraction = 0.33
    let widthToLengthFraction = 0.1
    let arrowLength = 0.01

    from = toAbsPos(from)
    to = toAbsPos(to)
    pushAxes(float2(0.0), float2(1, 1))

    var y = to - from
    from = to - fast_normalize(y) * canvasSize.x * arrowLength

    y = to - from
    let x = float2(y.y, -y.x)

    let lCorner = to - y * headLengthFraction - x * widthToLengthFraction
    let rCorner = to - y * headLengthFraction + x * widthToLengthFraction

    drawLine(from, to)
    drawLine(lCorner, to)
    drawLine(rCorner, to)
    popAxes()

  def draw()
    return if !isValid
    drawHeading()
    drawBarometricAltitude()
    drawIAS()
    drawBoreSight()
    drawTrackedTarget()
    drawAamTrackingMark()
    drawLaunchZone()
    drawWeaponStatus()

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
