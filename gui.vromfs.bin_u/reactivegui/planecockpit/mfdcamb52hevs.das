require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

require %gameLibs.das.math
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
require strings
require Unit
require Weapon



struct PropStorage
  fontId : int
  fontScale : float
  lineWidthScale : float


class Component : Canvas
  isValid : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  wc : WeaponController? = null
  app : AcesApp? = null
  cockpit : FlightModelCockpit? = null
  props : PropStorage
  defaultFontSize : int = 20
  defaultLineWidth : float = 2.0
  totalTime : float = 0.0

  ias : float = 0.0
  heading : float = 0.0
  pitch : float = 0.0
  roll : float = 0.0
  radarAlt : float = 0.0
  cameraElev : float = 0.0
  cameraAzim : float = 0.0
  isTargetLocked : bool = false


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
    cockpit = fmw.cockpit
    return if cockpit == null
    self.props := props

    isValid = true
    setColor(WHITE)
    defaultLineWidth *= props.lineWidthScale
    setLineWidth(defaultLineWidth)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFont(props.fontId)
    defaultFontSize = roundi(float(defaultFontSize) * props.fontScale)
    setFontSize(defaultFontSize)
    totalTime = float(get_total_time())

    ias = fmw.ias * MPS_TO_KTS
    pitch = fmw.tangage
    roll = fmw.roll
    let hdg = atan2_est(hero.unitTm[0].x, hero.unitTm[0].z)
    heading = hdg * radToDeg
    if heading < 0.0
      heading += 360.0
    radarAlt = fm.input.currentAlt * metrToFeet

    // Camera aim point — try getMfdTargetPos, then get_target_point_on_ground
    var targetPos = float3(0.0)
    var enabled = false
    *cockpit |> getMfdTargetPos(targetPos, safe_addr(enabled))
    if targetPos != float3(0.0) && enabled
      isTargetLocked = true
    else
      isTargetLocked = hud::get_target_point_on_ground(targetPos)
    if isTargetLocked
      let delta = targetPos - hero.unitTm[3]
      let horizDist = length(float2(delta.x, delta.z))
      cameraElev = -atan2_est(delta.y, horizDist) * radToDeg
      let hdgToTarget = atan2_est(delta.x, delta.z)
      cameraAzim = angle_diff(hdg, hdgToTarget) * radToDeg


  // Indicated Airspeed (boxed, upper-left)
  def drawAirspeedBox()
    let pos = float2(-0.30, -0.38)
    let iasVal = clamp(roundi(ias), 0, 999)
    let text = fmt(":03d", iasVal)
    setFillColor(BLACK)
    let bbox = getStrBbox(pos, text, AnchorHorz.Center, AnchorVert.Center)
    drawBBox(bbox, 0.008)
    setFillColor(TRANSPARENT)
    drawStrAnchored(pos, text, AnchorHorz.Center, AnchorVert.Center)


  // Time-To-Go (boxed, upper-right area)
  def drawTimeToGoBox()
    let toi = (*wc).getLastGuidedWeaponHitTime(int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
    return if toi < 0.0
    return if toi <= totalTime - 1.5
    let time = clamp(roundi(toi - totalTime), 0, 999)
    let pos = float2(0.20, -0.38)
    let text = fmt(":03d", time)
    setFillColor(BLACK)
    let bbox = getStrBbox(pos, text, AnchorHorz.Center, AnchorVert.Center)
    drawBBox(bbox, 0.008)
    setFillColor(TRANSPARENT)
    drawStrAnchored(pos, text, AnchorHorz.Center, AnchorVert.Center)


  // Heading Reference Marker (inverted triangle at top center)
  def drawHeadingRefMarker()
    let cx = 0.0
    let y0 = -0.47
    let h = 0.018
    let w = 0.012
    let verts = fixed_array<float2>(
      float2(cx, y0),
      float2(cx - w, y0 - h),
      float2(cx + w, y0 - h),
    )
    setFillColor(WHITE)
    drawFilledPolyOutlined(verts.to_array())
    setFillColor(TRANSPARENT)


  // Bank / Steering Marker (vertical tick at top, displaced by roll)
  def drawBankSteeringMarker()
    let bankOffset = clamp(roll * 0.003, -0.3, 0.3)
    let y0 = -0.44
    let len = 0.03
    drawLine(float2(bankOffset, y0), float2(bankOffset, y0 + len))


  // Elevation Scales (left side — camera elevation limits)
  def drawElevationScales()
    let longX = -0.38
    let tickLong = 0.025
    let tickMinor = 0.012
    let degSpacing = 0.09

    setFontSize(roundi(float(defaultFontSize) * 0.65))

    let markCount = 5
    let markStep = 15.0
    let markStart = -15.0
    let rightX = longX - tickLong

    let minorStep = degSpacing / 3.0
    for idx in range(0, markCount)
      let mark = markStart + float(idx) * markStep
      let y = float(idx) * degSpacing - degSpacing
      drawLine(float2(rightX, y), float2(longX, y))
      drawStrAnchored(float2(longX + 0.01, y), "{roundi(mark)}", AnchorHorz.Left, AnchorVert.Center)
      if idx < markCount - 1
        for j in range(1, 3)
          drawLine(float2(rightX, y + float(j) * minorStep), float2(rightX + tickMinor, y + float(j) * minorStep))

    setFontSize(defaultFontSize)

    // Camera elevation indicator ├── (rotated T) on elevation scale, right of ticks
    var elev = pitch
    if isTargetLocked
      elev = cameraElev
    let elevClamped = clamp(elev, markStart, markStart + float(markCount - 1) * markStep)
    let elevY = elevClamped / markStep * degSpacing

    let lineLen = 0.02
    let tickH = 0.015
    setLineWidth(defaultLineWidth * 1.5)
    drawLine(float2(longX - lineLen, elevY), float2(longX, elevY))
    drawLine(float2(longX, elevY - tickH), float2(longX, elevY + tickH))
    setLineWidth(defaultLineWidth)


  // Pitch and Roll Bar (single line with center gap)
  def drawPitchRollBar()
    let barLen = 0.25
    let gapHalf = 0.03
    let pitchShift = clamp(pitch * 0.004, -0.2, 0.2)

    var sina, cosa : float
    sincos(-roll * degToRad, sina, cosa)

    let dir = float2(cosa, sina)
    let center = float2(0.0, pitchShift)

    drawLine(center - dir * barLen, center - dir * gapHalf)
    drawLine(center + dir * gapHalf, center + dir * barLen)


  // Radar Altitude Scale (right side — rectangle with filled bar, 0-30 × 1000 ft)
  def drawRadarAltScale()
    let barLeft = 0.3674
    let barRight = 0.4226
    let scaleTop = -0.336
    let scaleBot = 0.336
    let maxAlt = 30000.0

    let altMarks = fixed_array(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 20.0, 30.0)
    let markCount = length(altMarks)
    let markPadding = 0.025
    let markTop = scaleTop + markPadding
    let markBot = scaleBot - markPadding
    let markH = markBot - markTop
    let step = markH / float(markCount - 1)

    // Map altitude to even-spaced position
    let altClamped = clamp(radarAlt, 0.0, maxAlt)
    let altKft = altClamped / 1000.0
    var barIdx = float(markCount - 1)
    for i in range(0, markCount - 1)
      if altKft <= altMarks[i + 1]
        barIdx = float(i) + (altKft - altMarks[i]) / (altMarks[i + 1] - altMarks[i])
        break

    // Filled altitude bar (from 0 up to current altitude)
    let barTopY = markBot - barIdx * step
    if altClamped > 0.0
      setFillColor(WHITE)
      let barCenterX = (barLeft + barRight) * 0.5 + (barRight - barLeft) * 0.2
      let halfBarW = (barRight - barLeft) * 0.1125
      drawBox(float2(barCenterX - halfBarW, barTopY), float2(barCenterX + halfBarW, markBot))
      setFillColor(TRANSPARENT)

    // Border rectangle
    drawBox(float2(barLeft, scaleTop), float2(barRight, scaleBot))

    // Numbers inside rectangle in herringbone pattern, ticks to right edge
    let tickInset = 0.008
    let barW = barRight - barLeft
    setFontSize(roundi(float(defaultFontSize) * 0.65))
    for mark, idx in altMarks, range(0, markCount)
      let y = markBot - float(idx) * step
      let indent = float(markCount - 1 - idx) / float(markCount - 1) * barW * 0.3
      let numX = barLeft + 0.002 + indent
      let text = "{roundi(mark)}"
      drawStrAnchored(float2(numX, y), text, AnchorHorz.Left, AnchorVert.Center)
      let textW = getStringSize(text).x
      drawLine(float2(numX + textW + 0.002, y), float2(barRight - tickInset, y))

    setFontSize(defaultFontSize)


  // Azimuth Scale (bottom — camera angular limits display)
  def drawAzimuthScales()
    let longY = 0.38
    let tickLong = 0.025
    let tickMinor = 0.012
    let degSpacing = 0.07

    setFontSize(roundi(float(defaultFontSize) * 0.65))

    let sideMarkCount = 3
    let markStep = 15.0
    let botY = longY + tickLong
    let minorStep = degSpacing / 3.0

    // Center tick
    drawLine(float2(0.0, longY), float2(0.0, longY + tickLong))

    for idx in range(1, sideMarkCount + 1)
      let x = float(idx) * degSpacing
      let text = "{roundi(float(idx) * markStep)}"
      drawLine(float2(x, longY), float2(x, longY + tickLong))
      drawLine(float2(-x, longY), float2(-x, longY + tickLong))
      drawStrAnchored(float2(x, longY - 0.01), text, AnchorHorz.Center, AnchorVert.Bottom)
      drawStrAnchored(float2(-x, longY - 0.01), text, AnchorHorz.Center, AnchorVert.Bottom)
      for j in range(1, 3)
        let mx = float(idx - 1) * degSpacing + float(j) * minorStep
        drawLine(float2(mx, botY - tickMinor), float2(mx, botY))
        drawLine(float2(-mx, botY - tickMinor), float2(-mx, botY))

    setFontSize(defaultFontSize)

    // Camera azimuth indicator (T shape) on azimuth scale
    let azimMax = float(sideMarkCount) * markStep
    let azimClamped = clamp(cameraAzim, -azimMax, azimMax)
    let azimX = azimClamped / markStep * degSpacing

    let tickW = 0.015
    let lineLen = 0.02
    setLineWidth(defaultLineWidth * 1.5)
    drawLine(float2(azimX - tickW, longY), float2(azimX + tickW, longY))
    drawLine(float2(azimX, longY), float2(azimX, longY + lineLen))
    setLineWidth(defaultLineWidth)


  // LOS Markers (corner brackets — STV and FLIR)
  def drawLosMarkers()
    let sz = 0.025

    // STV LOS — top-left
    let stv1 = float2(-0.43, -0.30)
    drawLine(stv1, stv1 + float2(sz, 0.0))
    drawLine(stv1, stv1 + float2(0.0, sz))

    // STV LOS — bottom-left
    let stv2 = float2(-0.43, 0.30)
    drawLine(stv2, stv2 + float2(sz, 0.0))
    drawLine(stv2, stv2 - float2(0.0, sz))

    // FLIR LOS — bottom-left (offset from STV)
    let flir1 = float2(-0.30, 0.43)
    drawLine(flir1, flir1 + float2(sz, 0.0))
    drawLine(flir1, flir1 - float2(0.0, sz))

    // FLIR LOS — bottom-right
    let flir2 = float2(0.30, 0.43)
    drawLine(flir2, flir2 - float2(sz, 0.0))
    drawLine(flir2, flir2 - float2(0.0, sz))


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawAirspeedBox()
    drawTimeToGoBox()
    drawHeadingRefMarker()
    //drawBankSteeringMarker()
    drawElevationScales()
    drawPitchRollBar()
    drawRadarAltScale()
    drawAzimuthScales()
    //drawLosMarkers()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.fontScale = getFloat(props, "fontScale", 1.0)
  propStorage.lineWidthScale = getFloat(props, "lineWidthScale", 1.0)
