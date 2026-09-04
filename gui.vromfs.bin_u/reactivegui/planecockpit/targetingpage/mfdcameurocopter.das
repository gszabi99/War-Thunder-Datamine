require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %daslib/safe_addr
require %gameLibs.das.math
require DagorMath
require DagorMathUtils
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require hud
require Mission
require strings
require Unit
require WTCamera


struct PropStorage
  fontId : int
  fontScale : float
  lineWidthScale : float


class Component : Canvas
  isValid : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  cockpit : FlightModelCockpit? = null
  fcm : FlightControlMode? = null
  defaultLineWidth : float = 3.0
  defaultFontSize : int = 24
  targetPos : float3 = float3(0.0)
  isTargetValid : bool = false
  isTargetLocked : bool = false
  turretYawNorm : float = 0.5
  turretPitchNorm : float = 0.5
  azimuthDeg : int = 0
  speedKts : int = 0
  distM : int = 0
  isInhibit : bool = false


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    fcm = get_flight_control_mode()
    return if fcm == null
    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null
    cockpit = fmw.cockpit
    return if cockpit == null

    var enabled = false
    *cockpit |> getMfdTargetPos(targetPos, safe_addr(enabled))
    isTargetLocked = enabled && targetPos != float3(0.0)
    if targetPos == float3(0.0)
      isTargetValid = hud::get_target_point_on_ground(targetPos)
    else
      isTargetValid = enabled

    speedKts = int(length(hero.vel.xz) * mpsToKnots)

    if isTargetValid
      let delta = targetPos - hero.unitTm[3]
      let azRad = atan2_est(delta.x, delta.z)
      azimuthDeg = int(azRad * radToDeg + 360.0) % 360
      let heading = atan2_est(hero.unitTm[0].x, hero.unitTm[0].z)
      let relYaw = angle_diff(heading, azRad)
      turretYawNorm = clamp(cvt(relYaw, -PI * 0.75f, PI * 0.75f, 0.0f, 1.0f), 0.0f, 1.0f)
      let dist2d = length(float2(delta.x, delta.z))
      let pitchRad = atan2_est(delta.y, dist2d)
      turretPitchNorm = clamp(cvt(pitchRad, -PI / 3.0f, PI / 9.0f, 0.0f, 1.0f), 0.0f, 1.0f)
      distM = int(length(delta))
      if get_agm_launch_zone_visible()
        let dmin = get_agm_launch_zone_dist_min()
        let dmax = get_agm_launch_zone_dist_max()
        isInhibit = float(distM) < dmin || float(distM) > dmax

    isValid = true
    setColor(constants_common::WHITE)
    defaultLineWidth *= props.lineWidthScale
    setLineWidth(defaultLineWidth)
    setOrigin(canvasPos + 0.5f * canvasSize)
    setScale(canvasSize)
    setFont(props.fontId)
    defaultFontSize = roundi(float(defaultFontSize) * props.fontScale)
    setFontSize(defaultFontSize)


  // INT azimuth scale, ticks go UP from baseline, triangles below
  def drawIntScale()
    let baseline_y = -0.4478f
    let cx = 0.03f  // horizontal center offset (between pitch scale and right edge)
    let hw = 0.36f  // half-width of scale
    let leftBoundary  = cx - hw
    let rightBoundary = cx + hw
    let numberOfTicks = 17
    let longTickH  = 0.0333f
    let medTickH   = 0.0243f
    let shortTickH = 0.0162f
    let tinyTickH  = 0.009f
    // baseline
    drawLine(float2(leftBoundary, baseline_y), float2(rightBoundary, baseline_y))
    for i in range(numberOfTicks)
      let tx = lerp(leftBoundary, rightBoundary, float(i) / float(numberOfTicks - 1))
      var tick_h = tinyTickH
      if i % 8 == 0
        tick_h = longTickH
      elif i % 8 == 4
        tick_h = medTickH
      elif i % 4 == 2
        tick_h = shortTickH
      drawLine(float2(tx, baseline_y), float2(tx, baseline_y - tick_h))
    // boresight triangle BELOW baseline, tip pointing UP △
    let tri_tip = baseline_y
    let tri_base = baseline_y + 0.045f
    drawLine(float2(cx - 0.02f, tri_base), float2(cx, tri_tip))
    drawLine(float2(cx + 0.02f, tri_base), float2(cx, tri_tip))
    drawLine(float2(cx - 0.02f, tri_base), float2(cx + 0.02f, tri_base))
    // LOS marker triangle BELOW baseline, tip pointing UP ∧
    let mx = lerp(leftBoundary, rightBoundary, turretYawNorm)
    setLineWidth(defaultLineWidth + 0.5f * (defaultLineWidth / 3.0f))
    drawLine(float2(mx - 0.02f, tri_base), float2(mx, tri_tip))
    drawLine(float2(mx + 0.02f, tri_base), float2(mx, tri_tip))
    setLineWidth(defaultLineWidth)
    // azimuth degree label connected below LOS marker triangle
    drawStrAnchored(float2(mx, tri_base), "{azimuthDeg}", AnchorHorz.Center, AnchorVert.Top)
    // INT / LOK label
    let scaleLabel = isTargetLocked ? "LOK" : "INT"
    drawStrAnchored(float2(-0.465f, -0.4478f), scaleLabel, AnchorHorz.Left, AnchorVert.Top)


  // Vertical pitch scale on left side
  def drawPitchScale()
    let barX       = -0.42f
    let longTickX  = -0.47f
    let shortTickX = -0.45f
    let barHalfH   = 0.35f
    let numberOfTicks = 9
    // main bar
    drawLine(float2(barX, -barHalfH), float2(barX, barHalfH))
    // ticks (long at i%4==0: ends and center; short otherwise)
    for i in range(numberOfTicks)
      let ty = lerp(-barHalfH, barHalfH, float(i) / float(numberOfTicks - 1))
      let tx = (i % 4 == 0) ? longTickX : shortTickX
      drawLine(float2(tx, ty), float2(barX, ty))
    let markerX    = barX + 0.05f   // right edge of marker arrows
    let markerHalfH = 0.025f
    // pitch reference marker ◁ (static, center, right of bar, pointing left toward bar)
    drawLine(float2(markerX, -markerHalfH), float2(barX, 0.0f))
    drawLine(float2(markerX, markerHalfH),  float2(barX, 0.0f))
    drawLine(float2(markerX, -markerHalfH), float2(markerX, markerHalfH))
    // pitch LOS marker ◁ (moves with turretPitchNorm, right of bar, pointing left toward bar)
    let pcy = lerp(barHalfH, -barHalfH, turretPitchNorm)
    setLineWidth(defaultLineWidth + 0.5f * (defaultLineWidth / 3.0f))
    drawLine(float2(markerX, pcy - markerHalfH), float2(barX, pcy))
    drawLine(float2(markerX, pcy + markerHalfH), float2(barX, pcy))
    drawLine(float2(markerX, pcy - markerHalfH), float2(markerX, pcy + markerHalfH))
    setLineWidth(defaultLineWidth)

  // Inner range frame with T-corners and distance labels
  def drawInnerFrame()
    let ox         = 0.03f    // horizontal offset (center between pitch scale and right edge)
    let frameHalfW = 0.23f
    let frameHalfH = 0.14625f
    let legLen     = 0.055f   // L-bracket leg length (same for horizontal and vertical)
    // top-left
    drawLine(float2(ox - frameHalfW, -frameHalfH), float2(ox - frameHalfW + legLen, -frameHalfH))
    drawLine(float2(ox - frameHalfW, -frameHalfH), float2(ox - frameHalfW,          -frameHalfH + legLen))
    // top-right
    drawLine(float2(ox + frameHalfW, -frameHalfH), float2(ox + frameHalfW - legLen, -frameHalfH))
    drawLine(float2(ox + frameHalfW, -frameHalfH), float2(ox + frameHalfW,          -frameHalfH + legLen))
    // bottom-left
    drawLine(float2(ox - frameHalfW, frameHalfH), float2(ox - frameHalfW + legLen, frameHalfH))
    drawLine(float2(ox - frameHalfW, frameHalfH), float2(ox - frameHalfW,          frameHalfH - legLen))
    // bottom-right
    drawLine(float2(ox + frameHalfW, frameHalfH), float2(ox + frameHalfW - legLen, frameHalfH))
    drawLine(float2(ox + frameHalfW, frameHalfH), float2(ox + frameHalfW,          frameHalfH - legLen))
    // range labels (at top corners of inner frame)
    if isTargetValid
      drawStrAnchored(float2(ox - 0.17f, -0.195f), "{distM}", AnchorHorz.Left, AnchorVert.Top)
      drawStrAnchored(float2(ox + 0.17f, -0.195f), "{distM + 50}", AnchorHorz.Right, AnchorVert.Top)


  // Small acquisition reticle (4 L-corner brackets at center, landscape rectangle)
  def drawAcqReticle()
    let ox = 0.03f  // horizontal offset matching inner frame
    let s = isTargetLocked ? 0.5f : 1.0f
    let hw = 0.08f * s   // half-width
    let hh = 0.055f * s  // half-height
    let lw = 0.04f * s   // L-bracket leg length horizontal
    let lh = 0.035f * s  // L-bracket leg length vertical
    // top-left
    drawLine(float2(ox - hw, -hh), float2(ox - hw + lw, -hh))
    drawLine(float2(ox - hw, -hh), float2(ox - hw, -hh + lh))
    // top-right
    drawLine(float2(ox + hw, -hh), float2(ox + hw - lw, -hh))
    drawLine(float2(ox + hw, -hh), float2(ox + hw, -hh + lh))
    // bottom-left
    drawLine(float2(ox - hw, hh), float2(ox - hw + lw, hh))
    drawLine(float2(ox - hw, hh), float2(ox - hw, hh - lh))
    // bottom-right
    drawLine(float2(ox + hw, hh), float2(ox + hw - lw, hh))
    drawLine(float2(ox + hw, hh), float2(ox + hw, hh - lh))


  // LOS stabilization circle (removed)
  def drawLosCircle()
    pass

  // Static status labels at bottom
  def drawStatusLabels()
    drawStrAnchored(float2(-0.47f, 0.41f), "OP", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(-0.33f, 0.41f), "TV1 N", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(0.22f, 0.41f), "TI TV", AnchorHorz.Left, AnchorVert.Top)


  // Speed readout (bottom-left)
  def drawSpeed()
    drawStrAnchored(float2(-0.47f, 0.36f), "{speedKts}", AnchorHorz.Left, AnchorVert.Top)


  // Launch inhibit warning
  def drawInhibit()
    if isInhibit
      drawStrAnchored(float2(-0.15f, 0.26f), "INHIB", AnchorHorz.Center, AnchorVert.Top)


  def draw()
    return if !isValid
    setFullCanvasViewport()
    drawIntScale()
    drawPitchScale()
    drawInnerFrame()
    drawAcqReticle()
    drawLosCircle()
    drawStatusLabels()
    drawSpeed()
    drawInhibit()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.fontScale = getFloat(props, "fontScale", 1.0)
  propStorage.lineWidthScale = getFloat(props, "lineWidthScale", 1.0)
