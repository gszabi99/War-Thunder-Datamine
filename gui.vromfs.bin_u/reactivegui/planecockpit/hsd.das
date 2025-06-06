require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require %rGui.utils.hsd_common

require app
require DagorMath
require DagorStdGuiRender
require DagorTime
require darg
require FlightControl
require FlightModelWrap
require HeroManager
require math
require %dasGameLibs.math.base
require Plane
require Sensors
require strings
require Unit
require Weapon

struct Tracking
  isActive      : bool
  pos           : float3
  distance      : float
  distanceRate  : float
  dirNorm       : float3
  angVel        : float3

struct Spi
  isActive  : bool    = false
  pos       : float3  = float3(0.0)

struct Colors
  nullColor     = E3DCOLOR(0x0)
  maskColor     = E3DCOLOR(0xFF000000)
  defaultColor  = E3DCOLOR(0xFFFFFFFF)

struct Shapes
  diamond = fixed_array(
    float2(0.00, -0.02),
    float2(-0.02,  0.00),
    float2(0.00,  0.02),
    float2(0.02,  0.00),
  )
  triangle = fixed_array(
    float2(0.00, -0.02),
    float2(-0.02,  0.02),
    float2(0.02,  0.02),
  )
  arrow = fixed_array(
    float2(0.00, -0.02),

    float2(-0.02,  0.02),
    float2(-0.01,  0.02),
    float2(-0.01,  0.06),

    float2(0.01,   0.06),
    float2(0.01,   0.02),
    float2(0.02,   0.02),
  )
  centerMarkCross = fixed_array(
    float2(0.000, -0.125),  // Base
    float2(0.000,  0.500),
    float2(-0.250,  0.000), // Horizontal bar
    float2(0.250,  0.000),
    float2(-0.125,  0.500), // Horizontal bar
    float2(0.125,  0.500),
  )
  centerMarkHeliFuse = fixed_array(
    float2(0.098, -0.176),
    float2(0.186, -0.020),
    float2(0.186,  0.127),
    float2(0.098,  0.275),
    float2(0.098,  0.392),
    float2(0.176,  0.431),
    float2(0.176,  0.500),

    float2(-0.176,  0.500),
    float2(-0.176,  0.431),
    float2(-0.098,  0.392),
    float2(-0.098,  0.275),
    float2(-0.186,  0.127),
    float2(-0.186, -0.020),
    float2(-0.098, -0.176),
  )
  centerMarkHeliRotor = fixed_array(
    float2(-0.059, -0.059),
    float2(-0.088, -0.441),
    float2(0.088, -0.441),
    float2(0.059, -0.059),
    float2(0.441, -0.088),
    float2(0.441,  0.088),
    float2(0.059,  0.059),
    float2(0.088,  0.441),
    float2(-0.088,  0.441),
    float2(-0.059,  0.059),
    float2(-0.441,  0.088),
    float2(-0.441, -0.088),
  )
  centerMarkPlane = fixed_array(
    float2(0.000, -0.500),

    float2(-0.011, -0.457),
    float2(-0.037, -0.234),
    float2(-0.059, -0.165),
    float2(-0.218,  0.000),
    float2(-0.218,  0.059),
    float2(-0.064,  0.016),
    float2(-0.064,  0.037),
    float2(-0.149,  0.128),
    float2(-0.122,  0.165),
    float2(-0.043,  0.133),

    float2(0.000,  0.122),

    float2(0.043,  0.133),
    float2(0.122,  0.165),
    float2(0.149,  0.128),
    float2(0.064,  0.037),
    float2(0.064,  0.016),
    float2(0.218,  0.059),
    float2(0.218,  0.000),
    float2(0.059, -0.165),
    float2(0.037, -0.234),
    float2(0.011, -0.457),
  )
  centerMarkTriangle = fixed_array(
    float2(0.000, -0.050),
    float2(-0.250,  0.500),
    float2(0.250,  0.500),
  )
  centerMarkTriangleLine = fixed_array(
    float2(0.000, -0.050),
    float2(0.000, -0.500),
  )

class Component : Canvas
  isValid         : bool                = false
  hero            : Unit?               = null
  fmw             : FlightModelWrap?    = null
  fm              : FlightModel?        = null
  wc              : WeaponController?   = null
  app             : AcesApp?            = null
  props           : HsdProps const?     = null
  toi             : Tracking            = Tracking()
  spi             : Spi                 = Spi()
  colors          : Colors              = Colors()
  shapes          : Shapes              = Shapes()

  forward         : float2              = float2(0.0)
  forwardAngle    : float               = 0.0
  windDirections  : table<int; string> = {0 => "N", 9 => "E", 18 => "S", 27 => "W"}
  mToCanvas       : float               = 1.0

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : HsdProps&)
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
    self.props = unsafe(addr(props))

    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        toi.isActive = true
        toi.pos = target.from + target.dirNorm * target.distance
        toi.distance = target.distance
        toi.distanceRate = target.distanceRate
        toi.dirNorm = target.dirNorm
        toi.angVel = target.angVel

    isValid = true
    setColor(props.lineColor)
    setLineWidth(props.lineWidth)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(props.fontSize)
    setLineSpacing(0.85)

    forward = fast_normalize(hero.unitTm[0].xz)
    forwardAngle = atan2_est(forward.x, forward.y)
    mToCanvas = 1.0 / props.extent

    if get_point_of_interest(spi.pos)
      spi.isActive = true

  def worldToScreen(worldPos : float3& const) : float2
    return hsd_world_to_screen(worldPos, props, hero)

  def drawAzScale()
    setColor(props.azScaleColor)
    if props.azScaleType == int(AzimuthScaleType.GATES)
      drawAzScaleGates()
    if props.azScaleType == int(AzimuthScaleType.LINES)
      drawCircle(float2(0.0), props.azScaleSize * mToCanvas)
      drawAzScaleLine()
    elif props.azScaleType == int(AzimuthScaleType.DOTS)
      drawAzScaleDots()
    setColor(props.lineColor)

  def drawAzScaleGates()
    let divs = 36
    let interval = PI2 / float(divs)
    let size = props.azScaleSize * mToCanvas
    let length = toRelY(float(props.fontSize)) * 0.5

    var sina, cosa = 0.0
    for i in 0..divs
      var angle = float(i) * interval - PI_2
      if props.orient == int(Orient.HDG_UP)
        angle -= forwardAngle
      sincos(angle, sina, cosa)
      if i % 3 == 0
        let pos = float2(size * cosa, size * sina)
        if i % 9 != 0
          drawStrAnchored(pos, "{i}", AnchorHorz.Center, AnchorVert.Center)
        else
          drawStrAnchored(pos, "{windDirections.get_value(i)}", AnchorHorz.Center, AnchorVert.Center)
        continue
      let end = size + length
      let start = size - length
      let startPos = float2(start * cosa, start * sina)
      let endPos = float2(end * cosa, end * sina)
      drawLine(startPos, endPos)

  def drawAzScaleLine()
    let divs = 36
    let interval = PI2 / float(divs)
    let size = props.azScaleSize * mToCanvas
    let length = toRelY(float(props.fontSize)) * 0.5
    let numPosMult = 3.0

    var sina, cosa = 0.0
    for i in 0..divs
      var angle = float(i) * interval - PI_2
      if props.orient == int(Orient.HDG_UP)
        angle -= forwardAngle

      sincos(angle, sina, cosa)
      var end = 0.0
      if i % 3 == 0
        end = size + length
        let pos = float2((size + length * numPosMult) * cosa, (size + length * numPosMult) * sina)
        if i != 0
          drawStrAnchored(pos, "{i}", AnchorHorz.Center, AnchorVert.Center)
        else
          drawStrAnchored(pos, "{windDirections.get_value(i)}", AnchorHorz.Center, AnchorVert.Center)
      else
        end = size + length * 0.5
      let startPos = float2(size * cosa, size * sina)
      let endPos = float2(end * cosa, end * sina)
      drawLine(startPos, endPos)
    drawHeading()

  def drawAzScaleDots()
    let divs = 36
    let interval = PI2 / float(divs)
    let size = props.azScaleSize * mToCanvas

    var sina, cosa = 0.0
    for i in 0..divs
      var angle = float(i) * interval - PI_2
      if props.orient == int(Orient.HDG_UP)
        angle -= forwardAngle
      sincos(angle, sina, cosa)
      if i % 3 == 0
        let pos = float2(size * cosa, size * sina)
        if i % 9 != 0
          drawStrAnchored(pos, "{i}", AnchorHorz.Center, AnchorVert.Center)
        else
          drawStrAnchored(pos, "{windDirections.get_value(i)}", AnchorHorz.Center, AnchorVert.Center)
        continue
      let pos = float2(size * cosa, size * sina)

      let radius = toRelY(float(props.fontSize)) * 0.15
      setFillColor(props.azScaleColor)
      drawCircle(pos, radius)
      setFillColor(colors.nullColor)

  def drawDistScale()
    return if !props.distScale

    setColor(props.distScaleColor)

    var sina, cosa = 0.0
    if props.distScaleNumbers
      sincos(props.distScaleNumbersAngle * degToRad - PI_2, sina, cosa)
    let n = props.distScaleBeyondAzScale ? roundi(props.extent / props.distScaleStepSize) : roundi(props.extent * 0.5 / props.distScaleStepSize)
    for i in 1 .. n
      let radius = props.distScaleStepSize * float(i)
      continue if is_equal_float(radius, props.azScaleSize)
      drawCircle(float2(0.0), props.distScaleStepSize * float(i) * mToCanvas)
      continue if !props.distScaleNumbers
      // Number drawing
      let pos = float2(
        float(i) * props.distScaleStepSize * mToCanvas * cosa,
        float(i) * props.distScaleStepSize * mToCanvas * sina)
      let str = string(roundi(float(i) * props.distScaleStepSize * 1e-3))
      let size = getStringSize(str) * 0.5

      setColor(props.distScaleNumbersFillColor)
      setFillColor(props.distScaleNumbersFillColor)
      drawBox(
        float2(pos - size),
        float2(pos + size))
      setColor(props.distScaleColor)
      setFillColor(colors.nullColor)
      drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Center)

    setColor(props.lineColor)

  def drawHeading()
    let heading = norm_ang(forwardAngle) * radToDeg
    let pos = float2(0.0, -props.azScaleSize * mToCanvas - toRelY(float(props.fontSize)) * 1.5)
    let str = fmt(":03d", floori(heading))
    let size = getStringSize(str) * 0.5
    let margin = float2(0.01)

    setFillColor(props.headingIndFillColor)
    drawBox(
      float2(pos - size - margin),
      float2(pos + size + margin))
    setFillColor(colors.nullColor)
    drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Center)

  def drawCenterMark()
    setFillColor(props.centerMarkFillColor)
    setColor(props.centerMarkLineColor)

    if props.orient == int(Orient.NORTH_UP)
      setRotation(float2(0.0), forwardAngle)

    if props.centerMarkType == int(CenterMarkType.CROSS)
      var n = 2
      while n <= shapes.centerMarkCross.length()
        drawPolyLine(shapes.centerMarkCross[n - 2 .. n].scale(float2(props.centerMarkScale)))
        n += 2
    elif props.centerMarkType == int(CenterMarkType.CIRCLE)
      drawCircle(float2(0.0), props.centerMarkScale * 0.5)
    elif props.centerMarkType == int(CenterMarkType.HELI)
      var sina, cosa = 0.0
      sincos(PI_4, sina, cosa)
      drawFilledPolyOutlined(shapes.centerMarkHeliFuse.to_array().scale(float2(props.centerMarkScale)))
      drawFilledPolyOutlined(shapes.centerMarkHeliRotor.to_array().scale(float2(props.centerMarkScale)).rotate(sina, cosa))
    elif props.centerMarkType == int(CenterMarkType.PLANE)
      drawFilledPolyOutlined(shapes.centerMarkPlane.to_array().scale(float2(props.centerMarkScale)))
    elif props.centerMarkType == int(CenterMarkType.TRIANGLE)
      drawFilledPolyOutlined(shapes.centerMarkTriangle.to_array().scale(float2(props.centerMarkScale)))
      drawPolyLine(shapes.centerMarkTriangleLine.to_array().scale(float2(props.centerMarkScale)))

    setColor(props.lineColor)
    setFillColor(colors.nullColor)
    resetViewTm()

  def drawSpi()
    return if !props.spi
    return if !spi.isActive

    let pos = worldToScreen(spi.pos)
    let len = pos.length()
    let margin = 0.02
    setColor(props.spiColor)
    if len <= props.azScaleSize * mToCanvas - margin
      drawClosedPolyLine(shapes.diamond.to_array().translate(pos))
      drawDot(pos)
    else
      let posClamped = pos * ((props.azScaleSize * mToCanvas - margin) / len)
      let angle = atan2_est(pos.x, -pos.y)
      var sina, cosa = 0.0
      sincos(angle, sina, cosa)
      if (props.azScaleType == int(AzimuthScaleType.GATES)
        || props.azScaleType == int(AzimuthScaleType.DOTS))
        drawClosedPolyLine(shapes.triangle.to_array().rotate(sina, cosa).translate(posClamped))
        drawDot(posClamped)
      elif props.azScaleType == int(AzimuthScaleType.LINES)
        drawClosedPolyLine(shapes.arrow.to_array().rotate(sina, cosa).translate(posClamped))
    setColor(props.lineColor)

  def drawSpiInfo()
    return if !props.spiInfo
    return if !spi.isActive

    let dir = spi.pos.xz - hero.pos.xz
    let dist = dir.length()
    // Distance and heading
    let angle = -atan2_est(dir.x * forward.y - dir.y * forward.x, dot(dir, forward))
    let angleStr = "{fmt(":+04d", floori(angle * radToDeg))} {loc("measureUnits/deg")}"
    let distStr = fmt(":.1f", props.metricUnits ? dist * 1e-3 : dist * metrToNavMile)
    drawStrAnchored(float2(0.45 - props.spiInfoOffset, -0.45 + props.spiInfoOffset), "{angleStr} / {distStr}", AnchorHorz.Right, AnchorVert.Top)
    // Time to target
    let velAlongDir = dot(float3(fm.vel).xz, fast_normalize(dir))
    return if velAlongDir < 0.0

    let timeToTarget = ceili(safediv(dist, velAlongDir))
    return if timeToTarget > 60 * 60

    let timeStr = "{timeToTarget / 60}:{fmt(":02d", timeToTarget % 60)}"
    drawStrAnchored(float2(0.45 - props.spiInfoOffset, -0.4 + props.spiInfoOffset), timeStr, AnchorHorz.Right, AnchorVert.Top)

  def drawCenterCross()
    return if !props.centerCross

    drawLine(float2(0.5, 0.0), float2(-0.5, 0.0))
    drawLine(float2(0.0, 0.5), float2(0.0, -0.5))

  def drawClock()
    return if !props.time

    let now = get_local_time()
    let str = "{fmt(":02d", now.x)}:{fmt(":02d", now.y)}:{fmt(":02d", now.z)}"
    drawStrAnchored(float2(-0.4, 0.4), str, AnchorHorz.Center, AnchorVert.Center)

  def drawSpeed()
    return if !props.centerMarkSpeed

    let ias = props.metricUnits ? fmw.ias * mpsToKmh : fmw.ias * mpsToKnots
    let tas = props.metricUnits ? fm.speed * mpsToKmh : fm.speed * mpsToKnots
    let pos = props.centerMarkScale * 0.5
    drawStrAnchored(float2(-pos, pos), string(roundi(ias)), AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(pos), string(roundi(tas)), AnchorHorz.Left, AnchorVert.Top)

  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawCenterCross()
    drawAzScale()
    drawDistScale()
    drawSpi()
    drawSpiInfo()
    drawCenterMark()
    drawClock()
    drawSpeed()
    restoreViewport()

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : HsdProps&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var hsd_props : HsdProps&)
  hsd_load_props(props, hsd_props)
