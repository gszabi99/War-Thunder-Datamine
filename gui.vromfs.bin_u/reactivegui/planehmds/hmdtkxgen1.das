require darg
require DagorStdGuiRender
require DagorMath
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
require Plane
require WTVr


struct PropStorage
  fontId : int


def set_color_alpha(col : E3DCOLOR)
  let col4 = is_hmd_enabled() ? float4(Color4(col)) * 0.8 : float4(Color4(col)) * 0.5
  return E3DCOLOR(Color4(col4))


class Component : Canvas
  isValid : bool = false
  unit : Unit? = null
  fmw : FlightModelWrap? = null
  defaultFontSize : int = 20
  baseLineW : float = 3.0

  heading : float = 0.0
  barometricAltitude : float = 0.0
  ias : float = 0.0
  machNumber : float = 0.0
  overloadG : float = 0.0
  aoa : float = 0.0
  radioAlt : float = 0.0

  hasTrackedTarget : bool = false
  trackedTargetVisible : bool = false
  trackedTargetAbsPos : float2
  trackedTargetDist : float = 0.0

  // locked target uses same source as tracked target
  hasLockedTarget : bool = false

  pitchDeg : float = 0.0
  rollDeg : float = 0.0

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    unit = get_watched_not_delayed_hero()
    fmw = as_fmw(unit)
    return if fmw == null || fmw.cockpit == null

    heading = norm_ang_deg((dir_to_angles(unit.unitTm[0]).x + PI * 0.5) * radToDeg)
    barometricAltitude = unit.unitTm[3].y - get_app().currentScene.waterLevel
    ias = fmw.ias * MPS_TO_KPH
    machNumber = fmw.fm.cache.Mach
    overloadG = float(fmw.fm.localAccel.y) / 9.81 + 1.0
    aoa = fmw.ias > 20.0 ? fmw.fm.aoa : 0.0
    radioAlt = fmw.fm.input.currentAlt
    pitchDeg = fmw.tangage
    rollDeg = fmw.roll

    // single target source: sensor selected target for all symbology
    using() <| $(var target : TargetOfInterest#)
      if unit.sensors.getSelectedTargetOfInterest(unit.detector, target)
        hasTrackedTarget = true
        trackedTargetDist = target.distance
        let pos = target.from + target.dirNorm * target.distance
        var hmdPos : float2
        if world_to_hmd_screen(pos, hmdPos)
          trackedTargetVisible = true
          trackedTargetAbsPos = hmdPos

    let aamLockState = get_aam_guidance_lock_state()
    let guidanceType = get_cur_weapon_guidance_type()
    let lockStateOk = aamLockState == GuidanceLockState.RESULT_TRACKING || aamLockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH
    let guidanceTypeOk = guidanceType == GuidanceType.TYPE_OPTICAL || guidanceType == GuidanceType.TYPE_SARH || guidanceType == GuidanceType.TYPE_ARH
    if lockStateOk && guidanceTypeOk
      hasLockedTarget = trackedTargetVisible

    setColor(set_color_alpha(*fmw.cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS)))
    baseLineW = floor(3.0 * fmw.cockpit.ilsLineWidthScale)
    setLineWidth(baseLineW)
    setFont(props.fontId)
    defaultFontSize = floori(20.0 * float(rdata.size.y) / 1080.0)
    isValid = true


  def drawSpeed()
    setFontSize(defaultFontSize)
    let cx = -0.095
    let r = 0.026
    drawStrAnchored(float2(cx, -0.015), "{roundi(ias)}", AnchorHorz.Center, AnchorVert.Center)
    drawClockDots(float2(cx, -0.015), r)
    let spdAngle = (ias / 100.0) * 360.0 * degToRad
    let aspect = canvasSize.x / canvasSize.y
    let dirX = sin(spdAngle)
    let dirY = -cos(spdAngle) * aspect
    setLineWidth(baseLineW + 1.0)
    drawLine(float2(cx + dirX * r * 0.35, -0.015 + dirY * r * 0.35), float2(cx + dirX * r * 0.92, -0.015 + dirY * r * 0.92))
    setLineWidth(baseLineW)


  def drawAltitude()
    setFontSize(defaultFontSize)
    let cx = 0.095
    let r = 0.026
    drawStrAnchored(float2(cx, -0.015), "{roundi(barometricAltitude)}", AnchorHorz.Center, AnchorVert.Center)
    drawClockDots(float2(cx, -0.015), r)
    let altAngle = (barometricAltitude / 1000.0) * 360.0 * degToRad
    let aspect = canvasSize.x / canvasSize.y
    let dirX = sin(altAngle)
    let dirY = -cos(altAngle) * aspect
    setLineWidth(baseLineW + 1.0)
    drawLine(float2(cx + dirX * r * 0.35, -0.015 + dirY * r * 0.35), float2(cx + dirX * r * 0.92, -0.015 + dirY * r * 0.92))
    setLineWidth(baseLineW)


  def drawClockDots(center : float2; radius : float)
    let aspect = canvasSize.x / canvasSize.y
    setFillColor(color)
    for i in range(0, 12)
      let a = float(i) * 30.0 * degToRad
      let dx = sin(a) * radius
      let dy = -cos(a) * radius * aspect
      drawCircle(center + float2(dx, dy), 0.002)


  def drawAoA()
    setFontSize(defaultFontSize)
    drawStrAnchored(float2(-0.078, -0.111), "A {fmt(":.1f", aoa)}", AnchorHorz.Left, AnchorVert.Center)


  def drawGLoad()
    setFontSize(defaultFontSize)
    drawStrAnchored(float2(-0.078, -0.087), "G {fmt(":.2f", overloadG)}", AnchorHorz.Left, AnchorVert.Center)


  def drawMach()
    setFontSize(defaultFontSize)
    drawStrAnchored(float2(-0.078, 0.12), "M {fmt(":.2f", machNumber)}", AnchorHorz.Left, AnchorVert.Center)


  def drawHeading()
    setFontSize(defaultFontSize)
    setLineWidth(baseLineW + 1.0)
    let hdgVal = roundi(heading) % 360
    let pos = float2(0.0, -0.111)
    setFillColor(E3DCOLOR(0x00000000))
    drawBox(pos - float2(0.014, 0.010), pos + float2(0.014, 0.010))
    drawStrAnchored(pos, "{hdgVal}", AnchorHorz.Center, AnchorVert.Center)
    setLineWidth(baseLineW)


  def drawBoreSight()
    setLineWidth(baseLineW + 1.0)
    let aspect = canvasSize.x / canvasSize.y
    let arm = 0.014
    let armY = arm * aspect
    let gap = 0.005
    let gapY = gap * aspect
    let tick = 0.002
    let tickY = tick * aspect
    let cy = 0.012
    drawLine(float2(-arm, cy), float2(-gap, cy))
    drawLine(float2(gap, cy), float2(arm, cy))
    drawLine(float2(0.0, cy - armY), float2(0.0, cy - gapY))
    drawLine(float2(0.0, cy + gapY), float2(0.0, cy + armY))
    drawLine(float2(-arm, cy - tickY), float2(-arm, cy + tickY))
    drawLine(float2(arm, cy - tickY), float2(arm, cy + tickY))
    drawLine(float2(-tick, cy - armY), float2(tick, cy - armY))
    drawLine(float2(-tick, cy + armY), float2(tick, cy + armY))
    setLineWidth(baseLineW)


  def drawAircraftMarker()
    setLineWidth(baseLineW + 1.0)
    let aspect = canvasSize.x / canvasSize.y
    let arm = 0.014
    let armY = arm * aspect
    let cy = 0.012 - armY * 1.82
    let circleR = 0.00576
    let circleRx = circleR / aspect
    setFillColor(E3DCOLOR(0x00000000))
    setRotation(float2(0.0, cy), -rollDeg * degToRad)
    drawCircle(float2(0.0, cy), circleR)
    drawLine(float2(-arm, cy), float2(-circleRx, cy))
    drawLine(float2(circleRx, cy), float2(arm, cy))
    drawLine(float2(0.0, cy - circleR), float2(0.0, cy - circleR - armY * 0.4))
    resetViewTm()
    setLineWidth(baseLineW)


  // pitch-only horizon, matches real horizon line
  def drawHorizon()
    setLineWidth(baseLineW + 1.0)
    let totalHalf = 0.055
    let gap = 0.008
    let pitchScale = 0.0024
    let yOff = pitchScale * pitchDeg
    let cy = clamp(0.012 + yOff, -0.07, 0.09)
    drawLine(float2(-totalHalf, cy), float2(-gap, cy))
    drawLine(float2(gap, cy), float2(totalHalf, cy))
    setLineWidth(baseLineW)


  def drawRadioAlt()
    setFontSize(defaultFontSize)
    drawStrAnchored(float2(0.048, 0.108), "RA{roundi(radioAlt)}", AnchorHorz.Left, AnchorVert.Center)


  def drawTargetInfo()
    return if !hasTrackedTarget
    setFontSize(defaultFontSize)
    let distKm = roundi(trackedTargetDist * 0.001)
    drawStrAnchored(float2(0.048, 0.126), "{fmt(":02d", distKm)}KM", AnchorHorz.Left, AnchorVert.Center)


  // circle-in-square marker at tracked target position
  def drawTrackedTarget()
    return if !trackedTargetVisible
    let sz = toAbsX(0.012)
    pushAxes(trackedTargetAbsPos, float2(1.0))
    drawBox(float2(-sz), float2(sz))
    drawCircle(float2(0.0), sz * 0.65)
    if hasTrackedTarget
      setFontSize(defaultFontSize)
      drawStrAnchored(float2(0.0, sz * 1.8), "{roundi(trackedTargetDist * 0.001)}", AnchorHorz.Center, AnchorVert.Top)
    popAxes()


  // square on locked target, uses same position as tracked target
  def drawLockedTarget()
    return if !hasLockedTarget || !trackedTargetVisible
    let sz = toAbsX(0.009)
    setFillColor(E3DCOLOR(0x00000000))
    pushAxes(trackedTargetAbsPos, float2(1.0))
    drawBox(float2(-sz), float2(sz))
    popAxes()


  def drawAimLine()
    return if !trackedTargetVisible
    let aspect = canvasSize.x / canvasSize.y
    let armY = 0.014 * aspect
    let markerCy = 0.012 - armY * 1.82
    let center = toAbsPos(float2(0.0, markerCy))
    let delta = trackedTargetAbsPos - center
    let lenSq = dot(delta, delta)
    if lenSq < 1.0
      return
    let dist = sqrt(lenSq)
    let dir = delta * (1.0 / dist)
    let maxRadius = toAbsX(0.1)
    let lineStart = center + dir * toAbsX(0.005)
    let lineEnd = center + dir * min(dist, maxRadius)
    pushAxes(float2(0.0), float2(1.0))
    drawLine(lineStart, lineEnd)
    popAxes()


  def draw()
    return if !isValid
    setFullCanvasViewport()
    drawSpeed()
    drawAltitude()
    drawAoA()
    drawGLoad()
    drawMach()
    drawHeading()
    drawBoreSight()
    drawAircraftMarker()
    drawHorizon()
    drawRadioAlt()
    drawTargetInfo()
    drawTrackedTarget()
    drawLockedTarget()
    drawAimLine()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
