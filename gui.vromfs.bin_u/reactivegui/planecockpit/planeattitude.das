require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require DagorMath
require math
require DagorMathUtils
require Unit
require FlightModelWrap
require Plane
require HeroManager
require DagorStdGuiRender
require darg
require DagorSystem
require DagorDataBlock
require strings
require app

enum AttitudeType
  SQUARE
  CIRCLE
  SLICED_CIRCLE
  NUM
let attitude_type_names = fixed_array<string>(
  "square",
  "circle",
  "slicedCircle"
)

enum MiniatureType
  WINGS
  TRIANGLE
  NUM
let miniature_type_names = fixed_array<string>(
  "wings",
  "triangle"
)

struct TapeProps
  isActive : bool = false

  pos : float2 = float2(0.0)
  size : float2 = float2(0.0)

  span : float = 0.0

  markedDelta : float = 1.0
  markedLineLen : float = 1.0
  markFontSize : int = 10

  minorDeltaNum : int = 1
  minorLineLen : float = 0.5

  def update(blk : DataBlock)
    isActive = blk |> datablock_getBool("isActive", isActive)
    pos = blk |> datablock_getPoint2("pos", pos)
    size = blk |> datablock_getPoint2("size", size)
    span = blk |> datablock_getReal("span", span)
    markedDelta = blk |> datablock_getReal("markedDelta", markedDelta)
    markedLineLen = blk |> datablock_getReal("markedLineLen", markedLineLen)
    markFontSize = blk |> datablock_getInt("markFontSize", markFontSize)
    minorDeltaNum = blk |> datablock_getInt("minorDeltaNum", minorDeltaNum)
    minorLineLen = blk |> datablock_getReal("minorLineLen", minorLineLen)

struct AttitudeProps
  attitudeType : uint8 = uint8(AttitudeType.CIRCLE)
  size : float2 = float2(0.3, 0.4)

  miniatureType : uint8 = uint8(MiniatureType TRIANGLE)
  miniatureColor : E3DCOLOR = E3DCOLOR(0xFF000000)
  miniatureLineWidth : float = 3.0

  groundColor : E3DCOLOR = E3DCOLOR(0xFF4A2B22)
  skyColor : E3DCOLOR = E3DCOLOR(0xFF0000FF)

  pitchTape : TapeProps = TapeProps(
    isActive = true,

    pos = float2(0.0),
    size = float2(1.0, 0.8),

    span = 60.0,

    markedDelta = 10.0,
    markedLineLen = 0.09,
    markFontSize = 10,

    minorDeltaNum = 1,
    minorLineLen = 0.03
  )

  bankScaleHalfSpan : float = 40.0
  bankDelta : float = 10.0
  bankScaleRadius : float = 0.2
  bankDashLength : float = -0.01

  def update(blk : DataBlock)
    let attitudeTypeIndex = find_index(attitude_type_names, datablock_getStr(blk, "attitudeType", ""))
    if attitudeTypeIndex >= 0
      attitudeType = uint8(attitudeTypeIndex)

    size = blk |> datablock_getPoint2("size", size)


    let miniatureTypeIndex = find_index(miniature_type_names, datablock_getStr(blk, "miniatureType", ""))
    if miniatureTypeIndex >= 0
      miniatureType = uint8(miniatureTypeIndex)
    miniatureColor = blk |> datablock_getE3dcolor("miniatureColor", miniatureColor)
    miniatureLineWidth = blk |> datablock_getReal("miniatureLineWidth", miniatureLineWidth)

    groundColor = blk |> datablock_getE3dcolor("groundColor", groundColor)
    skyColor = blk |> datablock_getE3dcolor("skyColor", skyColor)

    pitchTape.update(*datablock_get_block_by_name_ex(blk, "pitchTape"))

    bankScaleHalfSpan = blk |> datablock_getReal("bankScaleHalfSpan", bankScaleHalfSpan)
    bankDelta = blk |> datablock_getReal("bankDelta", bankDelta)
    bankScaleRadius = blk |> datablock_getReal("bankScaleRadius", bankScaleRadius)
    bankDashLength = blk |> datablock_getReal("bankDashLength", bankDashLength)

struct AzimuthTapeProps
  isLinearTape : bool = false

  tape : TapeProps = TapeProps(
    pos = float2(0.0, 0.45),
    size = float2(0.6, 0.05),

    span = 90.0,

    markedDelta = 30.0,
    markedLineLen = 0.015,
    markFontSize = 15,

    minorDeltaNum = 0
  )

  backColor : E3DCOLOR = E3DCOLOR(0xFF404040)
  centralMarkColor : E3DCOLOR = E3DCOLOR(0xFFFFFF00)

  textMarkOffset : float = 0.005

  def update(blk : DataBlock)
    tape.update(blk)

    isLinearTape = blk |> datablock_getBool("isLinearTape", isLinearTape)

    backColor = blk |> datablock_getE3dcolor("backColor", backColor)
    centralMarkColor = blk |> datablock_getE3dcolor("centralMarkColor", centralMarkColor)

struct SlipAngleProps
  isActive : bool = false

  pos : float2 = float2(0.0, 0.37)
  size : float2 = float2(0.4, 0.04)

  backColor : E3DCOLOR = E3DCOLOR(0xFF404040)
  lineColor : E3DCOLOR = E3DCOLOR(0xFF000000)

  indicatorSize : float = 0.015

  span : float = 10.0
  deltaDeg : float = 2.0

  def update(blk : DataBlock)
    isActive = blk |> datablock_getBool("isActive", isActive)

    pos = blk |> datablock_getPoint2("pos", pos)
    size = blk |> datablock_getPoint2("size", size)

    backColor = blk |> datablock_getE3dcolor("backColor", backColor)
    lineColor = blk |> datablock_getE3dcolor("lineColor", lineColor)

    indicatorSize = blk |> datablock_getReal("indicatorSize", indicatorSize)

    span = blk |> datablock_getReal("span", span)
    deltaDeg = blk |> datablock_getReal("deltaDeg", deltaDeg)

struct DigitalValueProps
  isActive : bool = false
  pos : float2 = float2(0.0)
  fontSize : int = 20
  anchorHorz : AnchorHorz = AnchorHorz.Center

  def update(blk : DataBlock)
    isActive = blk |> datablock_getBool("isActive", isActive)
    pos = blk |> datablock_getPoint2("pos", pos)
    fontSize = blk |> datablock_getInt("fontSize", fontSize)


struct PropStorage
  fontId : int
  lineColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  lineWidth : float = 2.0

  attitude : AttitudeProps = AttitudeProps()

  frameColor : E3DCOLOR = E3DCOLOR(0xFF000000)

  azimuthTape : AzimuthTapeProps = AzimuthTapeProps()
  slip : SlipAngleProps = SlipAngleProps()

  isMetric : bool = true


  angleOfAttackTape : TapeProps = TapeProps(
    isActive = false,

    pos = float2(-0.42, 0.0),
    size = float2(0.1, 0.3),

    span = 5.0,

    markedDelta = 1.0,
    markedLineLen = 0.2,
    markFontSize = 14,

    minorDeltaNum = 0
  )

  iasTape : TapeProps = TapeProps(
    isActive = false,

    pos = float2(-0.33, 0.0),
    size = float2(0.1, 0.6),

    span = 1500.0,

    markedDelta = 250.0,
    markedLineLen = 0.2,
    markFontSize = 14,

    minorDeltaNum = 1,
    minorLineLen = 0.1
  )

  altitudeTape : TapeProps = TapeProps(
    isActive = false,

    pos = float2(0.33, 0.0),
    size = float2(0.1, 0.6),

    span = 1500.0,

    markedDelta = 500.0,
    markedLineLen = 0.2,
    markFontSize = 14,

    minorDeltaNum = 4,
    minorLineLen = 0.1
  )

  verticalSpeedTape : TapeProps = TapeProps(
    isActive = false,

    pos = float2(0.42, 0.0),
    size = float2(0.1, 0.3),

    span = 200.0,

    markedDelta = 100.0,
    markedLineLen = 0.2,
    markFontSize = 14,

    minorDeltaNum = 4,
    minorLineLen = 0.1
  )

  digitalIasProps : DigitalValueProps = DigitalValueProps(
    pos = float2(-0.35, -0.4)
  )

  digitalAngleOfAttackProps : DigitalValueProps = DigitalValueProps(
    pos = float2(-0.35, -0.35)
  )

  digitalAltitudeProps : DigitalValueProps = DigitalValueProps(
    pos = float2(0.35, -0.4)
  )

  digitalVerticalSpeedProps : DigitalValueProps = DigitalValueProps(
    pos = float2(0.35, -0.35)
  )

  def update(blk : DataBlock)
    lineColor = blk |> datablock_getE3dcolor("lineColor", lineColor)
    lineWidth = blk |> datablock_getReal("lineWidth", lineWidth)

    attitude.update(*datablock_get_block_by_name_ex(blk, "attitude"))

    frameColor = blk |> datablock_getE3dcolor("frameColor", frameColor)

    azimuthTape.update(*datablock_get_block_by_name_ex(blk, "azimuthTape"))
    slip.update(*datablock_get_block_by_name_ex(blk, "slip"))

    isMetric = blk |> datablock_getBool("isMetric", isMetric)

    angleOfAttackTape.update(*datablock_get_block_by_name_ex(blk, "angleOfAttackTape"))
    iasTape.update(*datablock_get_block_by_name_ex(blk, "iasTape"))
    altitudeTape.update(*datablock_get_block_by_name_ex(blk, "altitudeTape"))
    verticalSpeedTape.update(*datablock_get_block_by_name_ex(blk, "verticalSpeedTape"))

    digitalIasProps.update(*datablock_get_block_by_name_ex(blk, "digitalIas"))
    digitalAngleOfAttackProps.update(*datablock_get_block_by_name_ex(blk, "digitalAngleOfAttack"))
    digitalAltitudeProps.update(*datablock_get_block_by_name_ex(blk, "digitalAltitude"))
    digitalVerticalSpeedProps.update(*datablock_get_block_by_name_ex(blk, "digitalVerticalSpeed"))

struct PlaneState
  pitchDeg : float = 0.0
  bankAngleDeg : float = 0.0
  headingDeg : float = 0.0
  slipAngleDeg : float = 0.0
  angleOfAttack : float = 0.0
  ias : float = 0.0
  altitude : float = 0.0
  verticalSpeed : float = 0.0

class Component : Canvas
  props : PropStorage = PropStorage()
  state : PlaneState = PlaneState()

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; _props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    props = _props
    initState()
    setFont(props.fontId)
    setColor(props.lineColor)
    setLineWidth(props.lineWidth)

  def initState()
    let unit = get_watched_not_delayed_hero()
    let fmw = as_fmw(unit)
    return if fmw == null

    state.pitchDeg = fmw.tangage
    state.bankAngleDeg = fmw.roll
    state.headingDeg = norm_ang_deg((dir_to_angles(unit.unitTm[0]).x + PI * 0.5) * radToDeg)

    let zVel = dot(unit.vel, unit.unitTm[1])
    let projectedVel = unit.vel - unit.unitTm[1] * zVel
    let crossProduct = cross(fast_normalize(projectedVel), fast_normalize(unit.unitTm[0]))
    let signMult = -sign(dot(crossProduct, unit.unitTm[1]))
    let ang = asin(length(crossProduct)) * radToDeg * signMult
    state.slipAngleDeg = ang


    state.angleOfAttack = fmw.fm.aoa
    state.ias = fmw.ias * (props.isMetric ? mpsToKmh : mpsToKnots)
    state.altitude = (unit.unitTm[3].y - get_app().currentScene.waterLevel) * (props.isMetric ? 1.0 : metrToFeet)
    state.verticalSpeed = unit.vel.y * (props.isMetric ? mpsToKmh : mpsToKnots)

  def drawMiniature()
    setColor(props.attitude.miniatureColor)
    setLineWidth(props.attitude.miniatureLineWidth)
    if props.attitude.miniatureType == uint8(MiniatureType WINGS)
      let offset = 0.03
      let len = 0.08
      let height = 0.02
      drawLine(float2(offset, 0.0), float2(offset + len, 0.0))
      drawLine(float2(offset, 0.0), float2(offset, height))
      drawDot(float2(0.0, 0.0))
      drawLine(float2(-offset, 0.0), float2(-offset - len, 0.0))
      drawLine(float2(-offset, 0.0), float2(-offset, height))
    elif props.attitude.miniatureType == uint8(MiniatureType TRIANGLE)
      drawLine(float2(0.0, 0.0), float2(-0.05, 0.05))
      drawLine(float2(-0.05, 0.05), float2(-0.1, 0.0))
      drawLine(float2(-0.1, 0.0), float2(-0.2, 0.0))

      drawLine(float2(0.0, 0.0), float2(0.05, 0.05))
      drawLine(float2(0.05, 0.05), float2(0.1, 0.0))
      drawLine(float2(0.1, 0.0), float2(0.2, 0.0))
    setLineWidth(props.lineWidth)

  def drawHorizonLine(t : float)
    let l = float2(0.0, axesOrigin.y + toAbsY(t))

    setColor(props.attitude.groundColor)
    setFillColor(props.attitude.groundColor)
    let groundBBox = BBox2(l, canvasSize)
    drawBBox(groundBBox)

    setColor(props.attitude.skyColor)
    setFillColor(props.attitude.skyColor)
    let skyBBox = BBox2(l, float2(canvasSize.x, 0.0))
    drawBBox(skyBBox)

    setColor(props.lineColor)

    let ll = toRelPos(float2(0.0, 0.0))
    drawLine(float2(ll.x, t), float2(-ll.x, t))


  def drawPitchLadder()
    let tape = props.attitude.pitchTape
    return if !tape.isActive

    let size = toAbsXY(float2(tape.size.x, -tape.size.y))
    let pos = toAbsPos(tape.pos + float2(0.0, 0.5 * tape.size.y))
    pushAxes(pos, size) // [0, 1], +y - up

    let bot = state.pitchDeg - tape.span * 0.5

    drawHorizonLine(-bot / tape.span)

    setFontSize(tape.markFontSize)
    setColor(props.lineColor)
    let delta = tape.markedDelta / float(tape.minorDeltaNum + 1)
    let count = int(tape.span * 0.5 / delta)
    let currentI = roundi(state.pitchDeg / delta)
    for i in range(currentI - count, currentI + count + 1)
      if i == 0
        continue
      let v = float(i) * delta
      let t = (v - bot) / tape.span
      if i % (tape.minorDeltaNum + 1) == 0
        drawLine(float2(-tape.markedLineLen, t), float2(tape.markedLineLen, t))
        drawStrAnchored(float2(tape.markedLineLen + 0.02, t), "{v}", AnchorHorz.Left, AnchorVert.Center)
        drawStrAnchored(float2(-tape.markedLineLen - 0.04, t), "{v}", AnchorHorz.Right, AnchorVert.Center)
      else
        drawLine(float2(-tape.minorLineLen, t), float2(tape.minorLineLen, t))

    popAxes()

  def drawBankAngleScale()
    setColor(props.lineColor)
    let count = roundi((props.attitude.bankScaleHalfSpan) / props.attitude.bankDelta)
    for i in range(-count, count + 1)
      let angle = float(i) * props.attitude.bankDelta
      var sina : float
      var cosa : float
      sincos(angle * degToRad, sina, cosa)

      let r = props.attitude.attitudeType == uint8(AttitudeType.SQUARE) ? props.attitude.bankScaleRadius : props.attitude.size.y * 0.5
      drawLine(r * float2(sina, -cosa), (r + props.attitude.bankDashLength) * float2(sina, -cosa))

  def drawBankAngle()
    setRotation(float2(0.0, 0.0), -state.bankAngleDeg * degToRad)
    setColor(props.lineColor)
    let r = props.attitude.attitudeType == uint8(AttitudeType.SQUARE) ? props.attitude.bankScaleRadius : props.attitude.size.y * 0.5
    drawArrowHead(float2(0.0, -r + 0.01), float2(0.0, -1.0), float2(0.05, 0.05))
    resetViewTm()

  def drawFrame()
    setColor(props.frameColor)
    if props.attitude.attitudeType == uint8(AttitudeType.SQUARE)
      let l = props.attitude.size.y * 0.5
      let rad = l * props.attitude.size.x
      let d = l - rad

      var q1 = array<float2>(
        float2(-d, -l),
        float2(0.0, -l),
        float2(0.0, -0.5),
        float2(-0.5, -0.5),
        float2(-0.5, 0.0),
        float2(-l, 0.0),
        float2(-l, -d)
      )
      var q2 = array<float2>(
        float2(d, -l),
        float2(0.0, -l),
        float2(0.0, -0.5),
        float2(0.5, -0.5),
        float2(0.5, 0.0),
        float2(l, 0.0),
        float2(l, -d)
      )
      var q3 = array<float2>(
        float2(d, l),
        float2(0.0, l),
        float2(0.0, 0.5),
        float2(0.5, 0.5),
        float2(0.5, 0.0),
        float2(l, 0.0),
        float2(l, d)
      )
      var q4 = array<float2>(
        float2(-d, l),
        float2(0.0, l),
        float2(0.0, 0.5),
        float2(-0.5, 0.5),
        float2(-0.5, 0.0),
        float2(-l, 0.0),
        float2(-l, d)
      )

      let n = 20
      for i in range(n + 1)
        var sina : float
        var cosa : float
        let angle = PI_2 * float(i) / float(n)
        sincos(angle, sina, cosa)

        let lt = float2(-d, -d)
        let ltp = lt + rad * float2(-cosa, -sina)
        q1 |> push(ltp)

        let rt = float2(d, -d)
        let rtp = rt + rad * float2(cosa, -sina)
        q2 |> push(rtp)

        let rb = float2(d, d)
        let rbt = rb + rad * float2(cosa, sina)
        q3 |> push(rbt)

        let lb = float2(-d, d)
        let lbt = lb + rad * float2(-cosa, sina)
        q4 |> push(lbt)
      drawFilledPoly(q1)
      drawFilledPoly(q2)
      drawFilledPoly(q3)
      drawFilledPoly(q4)
    elif props.attitude.attitudeType == uint8(AttitudeType.CIRCLE)
      var topHalf = array<float2>(
        float2(-props.attitude.size.y * 0.5, 0.0),
        float2(-0.5, 0.0),
        float2(-0.5, 0.5),
        float2(0.5, 0.5),
        float2(0.5, 0.0)
      )
      var bottomHalf = array<float2>(
        float2(-props.attitude.size.y * 0.5, 0.0),
        float2(-0.5, 0.0),
        float2(-0.5, -0.5),
        float2(0.5, -0.5),
        float2(0.5, 0.0)
      )

      let n = 20
      for i in range(n + 1)
        var sina : float
        var cosa : float
        let angle = PI * float(i) / float(n)
        sincos(angle, sina, cosa)

        let tp = props.attitude.size.y * 0.5 * float2(cosa, sina)
        let bp = props.attitude.size.y * 0.5 * float2(cosa, -sina)
        topHalf |> push(tp)
        bottomHalf |> push(bp)
      drawFilledPoly(topHalf)
      drawFilledPoly(bottomHalf)
    elif props.attitude.attitudeType == uint8(AttitudeType.SLICED_CIRCLE)
      var topHalf = array<float2>(
        float2(-props.attitude.size.x * 0.5, props.attitude.size.y * 0.5),
        float2(-props.attitude.size.x * 0.5, 0.0),
        float2(-0.5, 0.0),
        float2(-0.5, 0.5),
        float2(0.5, 0.5),
        float2(0.5, 0.0),
        float2(props.attitude.size.x * 0.5, 0.0),
        float2(props.attitude.size.x * 0.5, props.attitude.size.y * 0.5)
      )
      var bottomHalf = array<float2>(
        float2(-props.attitude.size.x * 0.5, -props.attitude.size.y * 0.5),
        float2(-props.attitude.size.x * 0.5, 0.0),
        float2(-0.5, 0.0),
        float2(-0.5, -0.5),
        float2(0.5, -0.5),
        float2(0.5, 0.0),
        float2(props.attitude.size.x * 0.5, 0.0),
        float2(props.attitude.size.x * 0.5, -props.attitude.size.y * 0.5)
      )

      let n = 20
      for i in range(n + 1)
        let x = lerp(props.attitude.size.x * 0.5, -props.attitude.size.x * 0.5, float(i) / float(n))
        let y = sqrt(props.attitude.size.y * 0.5 * props.attitude.size.y * 0.5 - x * x)

        let tp = float2(x, y)
        let bp = float2(x, -y)
        topHalf |> push(tp)
        bottomHalf |> push(bp)
      drawFilledPoly(topHalf)
      drawFilledPoly(bottomHalf)

  def drawCenter()
    let size = toAbsXY(props.attitude.size)
    let pos = toAbsPos(float2(0.0, 0.0))
    pushAxes(pos, size)

    setRotation(float2(0.0, 0.0), -state.bankAngleDeg * degToRad)
    drawPitchLadder()
    resetViewTm()

    drawMiniature()

    popAxes()

  def drawLinearAzimuthTape()
    let tape = props.azimuthTape.tape
    return if !tape.isActive

    let size = toAbsXY(tape.size)
    let pos = toAbsPos(tape.pos)
    pushAxes(pos, size)
    setViewport(float2(-0.5), float2(0.5))

    setFillColor(props.azimuthTape.backColor)
    setColor(props.azimuthTape.backColor)
    drawBox(float2(-0.5), float2(0.5))

    let bot = state.headingDeg - tape.span * 0.5

    setFontSize(tape.markFontSize)
    setColor(props.lineColor)

    let markSize = toRelY(canvasSize.y * tape.markedLineLen)
    let offset = toRelY(canvasSize.y * props.azimuthTape.textMarkOffset)

    let count = int(tape.span * 0.5 / tape.markedDelta)
    let currentI = roundi(state.headingDeg / float(tape.markedDelta))
    for i in range(currentI - count - 1, currentI + count + 1)
      let v = float(i) * tape.markedDelta
      let t = (v - bot) / tape.span - 0.5

      drawLine(float2(t, -0.5 + markSize), float2(t, -0.5))

      let angle = norm_ang_deg(v)
      let str = fmt(":02d", roundi(angle / 10.0))
      drawStrAnchored(float2(t, -0.5 + markSize + offset), "{str}", AnchorHorz.Center, AnchorVert.Top)

    drawLine(float2(-0.5, -0.5), float2(0.5, -0.5))

    setColor(props.azimuthTape.centralMarkColor)
    drawLine(float2(0.0, -0.5), float2(0.0, 0.5))

    restoreViewport()
    popAxes()

  def drawCircularAzimuthTape()
    let tape = props.azimuthTape.tape
    return if !tape.isActive

    let span = 360.0

    setFontSize(tape.markFontSize)
    setColor(props.lineColor)

    var markY : float = 0.0
    let count = floori(span / tape.markedDelta)
    for i in range(count)
      let angle = float(i) * tape.markedDelta
      let shiftedAngle = angle - state.headingDeg

      setRotation(float2(0.0), shiftedAngle * degToRad)

      let textY = -props.attitude.size.y * 0.5 - props.azimuthTape.textMarkOffset
      let str = fmt(":02d", roundi(angle / 10.0))
      let textBox = drawStrAnchored(float2(0.0, textY), str, AnchorHorz.Center, AnchorVert.Bottom)

      let offset = toRelY(textBox.width.y) + props.azimuthTape.textMarkOffset
      markY = textY - offset
      drawDot(float2(0.0, markY))

      resetViewTm()

    drawArrowHead(float2(0.0, markY), float2(0.0, 1.0), float2(0.05))


  def drawAzimuthTape()
    if props.azimuthTape.isLinearTape
      drawLinearAzimuthTape()
    else
      drawCircularAzimuthTape()

  def drawSlipAngle()
    return if !props.slip.isActive

    let size = toAbsXY(props.slip.size)
    let pos = toAbsPos(props.slip.pos)
    pushAxes(pos, size)

    setFillColor(props.slip.backColor)
    setColor(props.slip.lineColor)
    drawEllipse(float2(0.0), float2(0.5))

    let count = roundi(props.slip.span / props.slip.deltaDeg)
    for i in range(count + 1)
      let angle = float(i) * props.slip.deltaDeg - props.slip.span * 0.5
      let x = angle / props.slip.span
      drawLine(float2(x, 0.5), float2(x, 0.0))

    let indicatorSize = toRelXY(float2(props.slip.indicatorSize * canvasSize.y))
    setFillColor(props.slip.lineColor)
    let slipX = clamp(state.slipAngleDeg / props.slip.span, -0.48, 0.48)
    drawEllipse(float2(slipX, 0.0), indicatorSize)
    setLineWidth(props.lineWidth)

    popAxes()

  def drawAngleOfAttackTape()
    let tape = props.angleOfAttackTape
    return if !tape.isActive

    let val = state.angleOfAttack

    let size = toAbsXY(float2(tape.size.x, -tape.size.y))
    let pos = toAbsPos(tape.pos + float2(0.0, 0.5 * tape.size.y))
    pushAxes(pos, size) // [0, 1], +y - up
    setViewport(float2(-0.5, 0.0), float2(0.5, 1.0))

    let bot = val - tape.span * 0.5

    setFontSize(tape.markFontSize)
    setColor(props.lineColor)

    let delta = tape.markedDelta / float(tape.minorDeltaNum + 1)
    let count = int(tape.span * 0.5 / delta)
    let currentI = roundi(val / delta)
    for i in range(currentI - count, currentI + count + 1)
      let v = float(i) * delta
      let t = (v - bot) / tape.span

      if i % (tape.minorDeltaNum + 1) == 0
        drawLine(float2(-0.5 + tape.markedLineLen, t), float2(-0.5, t))
        drawStrAnchored(float2(-0.5 + tape.markedLineLen + 0.1, t), "{v}", AnchorHorz.Left, AnchorVert.Center)
      else
        drawLine(float2(-0.5 + tape.minorLineLen, t), float2(-0.5, t))

    restoreViewport()

    drawLine(float2(-0.5, 0.0), float2(-0.5, 1.0))
    drawArrowHead(float2(-0.5, 0.5), float2(1.0, 0.0), float2(0.05, 0.5))

    popAxes()

  def drawIASTape()
    let tape = props.iasTape
    return if !tape.isActive

    let val = state.ias

    let size = toAbsXY(float2(tape.size.x, -tape.size.y))
    let pos = toAbsPos(tape.pos + float2(0.0, 0.5 * tape.size.y))
    pushAxes(pos, size) // [0, 1], +y - up
    setViewport(float2(-0.5, 0.0), float2(0.5, 1.0))

    let bot = val - tape.span * 0.5

    setFontSize(tape.markFontSize)
    setColor(props.lineColor)

    let delta = tape.markedDelta / float(tape.minorDeltaNum + 1)
    let count = int(tape.span * 0.5 / delta)
    let currentI = roundi(val / delta)
    for i in range(max(currentI - count, 0), currentI + count + 1)
      let v = float(i) * delta
      let t = (v - bot) / tape.span

      if i % (tape.minorDeltaNum + 1) == 0
        drawLine(float2(0.5 - tape.markedLineLen, t), float2(0.5, t))
        drawStrAnchored(float2(0.5 - tape.markedLineLen - 0.1, t), "{v}", AnchorHorz.Right, AnchorVert.Center)
      else
        drawLine(float2(0.5 - tape.minorLineLen, t), float2(0.5, t))

    restoreViewport()

    drawLine(float2(0.5, 0.0), float2(0.5, 1.0))
    drawArrowHead(float2(0.5, 0.5), float2(-1.0, 0.0), float2(0.05, 0.5))

    popAxes()

  def drawAltitudeTape()
    let tape = props.altitudeTape
    return if !tape.isActive

    let val = state.altitude

    let size = toAbsXY(float2(tape.size.x, -tape.size.y))
    let pos = toAbsPos(tape.pos + float2(0.0, 0.5 * tape.size.y))
    pushAxes(pos, size) // [0, 1], +y - up
    setViewport(float2(-0.5, 0.0), float2(0.5, 1.0))

    let bot = val - tape.span * 0.5

    setFontSize(tape.markFontSize)
    setColor(props.lineColor)

    let delta = tape.markedDelta / float(tape.minorDeltaNum + 1)
    let count = int(tape.span * 0.5 / delta)
    let currentI = roundi(val / delta)
    for i in range(max(currentI - count, 0), currentI + count + 1)
      let v = float(i) * delta
      let t = (v - bot) / tape.span

      if i % (tape.minorDeltaNum + 1) == 0
        drawLine(float2(-0.5 + tape.markedLineLen, t), float2(-0.5, t))
        drawStrAnchored(float2(-0.5 + tape.markedLineLen + 0.1, t), "{v}", AnchorHorz.Left, AnchorVert.Center)
      else
        drawLine(float2(-0.5 + tape.minorLineLen, t), float2(-0.5, t))

    restoreViewport()

    drawLine(float2(-0.5, 0.0), float2(-0.5, 1.0))
    drawArrowHead(float2(-0.5, 0.5), float2(1.0, 0.0), float2(0.05, 0.5))

    popAxes()

  def drawVerticalSpeedTape()
    let tape = props.verticalSpeedTape
    return if !tape.isActive

    let val = state.verticalSpeed

    let size = toAbsXY(float2(tape.size.x, -tape.size.y))
    let pos = toAbsPos(tape.pos + float2(0.0, 0.5 * tape.size.y))
    pushAxes(pos, size) // [0, 1], +y - up
    setViewport(float2(-0.5, 0.0), float2(0.5, 1.0))

    let bot = val - tape.span * 0.5

    setFontSize(tape.markFontSize)
    setColor(props.lineColor)

    let delta = tape.markedDelta / float(tape.minorDeltaNum + 1)
    let count = int(tape.span * 0.5 / delta)
    let currentI = roundi(val / delta)
    for i in range(currentI - count, currentI + count + 1)
      let v = float(i) * delta
      let t = (v - bot) / tape.span

      if i % (tape.minorDeltaNum + 1) == 0
        drawLine(float2(0.5 - tape.markedLineLen, t), float2(0.5, t))
        drawStrAnchored(float2(0.5 - tape.markedLineLen - 0.1, t), "{v}", AnchorHorz.Right, AnchorVert.Center)
      else
        drawLine(float2(0.5 - tape.minorLineLen, t), float2(0.5, t))

    restoreViewport()

    drawLine(float2(0.5, 0.0), float2(0.5, 1.0))
    drawArrowHead(float2(0.5, 0.5), float2(-1.0, 0.0), float2(0.05, 0.5))

    popAxes()

  def drawDigitalValue(prop : DigitalValueProps&; value : float)
    return if !prop.isActive

    setColor(props.lineColor)
    setFontSize(prop.fontSize)
    drawStrAnchored(prop.pos, "{roundi(value)}", prop.anchorHorz, AnchorVert.Center)

  def drawDigitalValues()
    drawDigitalValue(props.digitalIasProps, state.ias)
    drawDigitalValue(props.digitalAngleOfAttackProps, state.angleOfAttack)
    drawDigitalValue(props.digitalAltitudeProps, state.altitude)
    drawDigitalValue(props.digitalVerticalSpeedProps, state.verticalSpeed)

  def draw()
    setViewport(float2(-0.5, -0.5), float2(0.5, 0.5))

    drawCenter()
    drawBankAngle()
    drawFrame()
    drawBankAngleScale()

    drawAzimuthTape()
    drawSlipAngle()

    drawAngleOfAttackTape()
    drawIASTape()
    drawAltitudeTape()
    drawVerticalSpeedTape()

    drawDigitalValues()

    restoreViewport()

[export]
def draw(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  // TODO put it into global scope somehow
  static_assert(length(attitude_type_names) == int(AttitudeType NUM), "AttitudeType and lup table (attitude_type_names) should have equal length")
  static_assert(length(miniature_type_names) == int(MiniatureType NUM), "MiniatureType and lup table (miniature_type_names) should have equal length")

  propStorage = PropStorage()
  propStorage.fontId = getInt(props, "fontId", 0)

  let blk = getBlk(props, "blk")
  return if blk == null

  propStorage.update(*blk)

  let azimuthTapeType = blk |> datablock_getStr("azimuthType", "")
  if azimuthTapeType == "AzimuthUp"
    propStorage.azimuthTape.tape.pos = float2(0.0, -0.45)
    propStorage.azimuthTape.isLinearTape = true
    propStorage.azimuthTape.tape.isActive = true
  elif azimuthTapeType == "AzimuthDown"
    propStorage.azimuthTape.tape.pos = float2(0.0, 0.45)
    propStorage.azimuthTape.isLinearTape = true
    propStorage.azimuthTape.tape.isActive = true
  elif azimuthTapeType == "AzimuthCircle"
    propStorage.azimuthTape.isLinearTape = false
    propStorage.azimuthTape.tape.isActive = true

  let slipAngleType = blk |> datablock_getStr("turnType", "")
  if slipAngleType == "TurnUp"
    propStorage.slip.pos = float2(0.0, -0.37)
    propStorage.slip.isActive = true
  elif slipAngleType == "TurnDown"
    propStorage.slip.pos = float2(0.0, 0.37)
    propStorage.slip.isActive = true

  if blk |> datablock_getBool("fitBankScale", true)
    if propStorage.attitude.attitudeType != uint8(AttitudeType.SQUARE)
      let y = sqrt(propStorage.attitude.size.y * propStorage.attitude.size.y - propStorage.attitude.size.x * propStorage.attitude.size.x) * 0.5
      let angle = atan2(propStorage.attitude.size.x * 0.5, y) * radToDeg
      propStorage.attitude.bankScaleHalfSpan = angle