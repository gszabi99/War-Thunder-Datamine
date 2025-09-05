require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require %rGui.utils.hsd_common
require %rGui.utils.weaponslots_common

require app
require DagorMath
require DagorStdGuiRender
require DagorSystem
require DagorTime
require darg
require FlightControl
require FlightModelWrap
require HeroManager
require math
require %dasGameLibs.math.base
require RadarHud
require Plane
require Sensors
require strings
require Unit
require Weapon
require hud
require WTCamera

enum ArrowType
  large
  small

struct Colors
  green  = E3DCOLOR(0xFF_00FF00)
  lightGreen  = E3DCOLOR(0xFF_AAFFAA)
  empty  = E3DCOLOR(0x00_000000)
  black  = E3DCOLOR(0xFF_000000)
  white  = E3DCOLOR(0xFF_FFFFFF)
  pink  = E3DCOLOR(0xFF_FF9ACC)
  grey  = E3DCOLOR(0xFF_404040)
  lightBlue = E3DCOLOR(0xFF_CCFFFF)
  cyan = E3DCOLOR(0xFF_33CCCC)
  blue = E3DCOLOR(0xFF_0000FF)
  orange = E3DCOLOR(0xFF_F28326)
  shade = E3DCOLOR(0x70_000000)
  yellow = E3DCOLOR(0xFF_FFFF00)


def rad_to_deg(rad : float)
  return rad * 180.0 / PI

def circle_value(var value : int) : string
  return "{value / 10}"

def get_feet_speed_angle(value : float) : float
  if value < 25.0
    return 0.0
  if value < 50.0
    return 5.0 + 60.0 * (value - 25.0) / 25.0
  if value < 150.0
    return 65.0 + 100.0 * (value - 50.0) / 50.0
  if value < 200.0
    return 265.0 + 35.0 * (value - 150.0) / 50.0
  if value < 280.0
    return 300.0 + 50.0 * (value - 200.0) / 80.0

  return 350.0


struct PropStorage
  fontId : int
  horMask : Picture? = null
  english : bool

struct Shapes
  smallArrowPoints <- fixed_array(
    float2(0.05, 0.0),
    float2(0.1, 0.8),
    float2(0.0, 1.0),
    float2(-0.1, 0.8),
    float2(-0.05, 0.0),
  )
  largeArrowPoints <- fixed_array(
    float2(0.05, 0.0),
    float2(0.05, 0.8),
    float2(0.0, 1.0),
    float2(-0.05, 0.8),
    float2(-0.05, 0.0),
  )
  rectanglePoints <- fixed_array(float2(-0.5, -0.5), float2(-0.5, 0.5), float2(0.5, 0.5), float2(0.5, -0.5))
  trianglePoints <- fixed_array(float2(-0.5, 0.0), float2(0.0, 0.4), float2(0.5, 0.0),  float2(0.5, -0.25),  float2(-0.5, -0.25))
  rollIndicatorPoints <- fixed_array(
    float2(-1.8, 0.0),
    float2(-1.3, 0.0),
    float2(-1.4, 0.0),
    float2(-1.4, -0.2),
    float2(1.8, 0.0),
    float2(1.3, 0.0),
    float2(1.4, -0.0),
    float2(1.4, -0.2),
  )

  planeWingsPoints <- fixed_array(
    float2(-1.0, 0.0),
    float2(-0.3, 0.0),
    float2(0.0, 0.15),
    float2(0.3, 0.0),
    float2(1.0, 0.0),

    float2(1.0, 0.02),
    float2(0.3, 0.02),
    float2(0.3, 0.03),
    float2(0.29, 0.03),
    float2(0.29, 0.02),
    float2(0.0, 0.20),
    float2(-0.29, 0.02),
    float2(-0.29, 0.03),
    float2(-0.3, 0.03),
    float2(-0.3, 0.02),
    float2(-1.0, 0.02),
  )
  planeTailPoints <- fixed_array(
    float2(0.0, -0.4),
    float2(0.05, -0.15),
    float2(-0.05, -0.15),
  )

  horizonIndicatorShade <- fixed_array(
    float2(-0.1, 0.0),
    float2(-0.15, 1.0),
    float2(0.15, 1.0),
    float2(0.1, 0.0),
    float2(0.15, -1.0),
    float2(-0.15, -1.0),
  )

  square <- fixed_array(
    float2(-1.0, -1.0),
    float2(-1.0, 1.0),
    float2(1.0, 1.0),
    float2(1.0, -1.0),
  )

  triangle <- fixed_array(
    float2(-0.5, -0.8660),
    float2(0.5, -0.8660),
    float2(0.0, 0.0),
  )

  slidingArrowPoints <- fixed_array(
    float2(0.0, 0.25),
    float2(0.5, 0.25),
    float2(0.5, 0.5),
    float2(1.0, 0.0),
    float2(0.5, -0.5),
    float2(0.5, -0.25),
    float2(0.0, -0.25),
  )

class Component : Canvas
  isValid : bool = false
  isMetric : bool = true
  isEnglish : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  app : AcesApp? = null
  colors : Colors = Colors()
  shapes : Shapes = Shapes()

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    if hero == null
      return

    fmw = hero.as_fmw()
    if fmw == null
      return

    fm = fmw.fm
    if fm == null
      return

    app = get_app()
    if app == null
      return
    isEnglish = props.english
    isMetric = !isEnglish

    isValid = true
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(18)

  // Utils

  def getSkidBallValue()
    let vel = float3(fm.currentState.velocity.x, fm.currentState.velocity.y, fm.currentState.velocity.z)
    let acc = float3(fm.currentState.acceleration.x, fm.currentState.acceleration.y, fm.currentState.acceleration.z)
    let accVal = dot(fast_normalize(vel), acc);
    var unitRotation = hero.unitTm
    unitRotation[3] = float3(0.0)
    let horAccel = normalize(inverse(unitRotation) * acc)
    let res = cvt(horAccel.z * abs(accVal), -1.5, 1.5, -1.0, 1.0)
    return res

  def resetColor()
    setColor(colors.green)

  def resetFillColor()
    setFillColor(colors.empty)

  def resetColorAll()
    resetColor()
    resetFillColor()

  def drawArrow(pos : float2; r : float; angle : float, arrow : ArrowType)
    setColor(colors.cyan)
    setFillColor(colors.white)
    var sina, cosa = 0.0
    sincos(deg_to_rad(angle), sina, cosa)
    var arrowPoints : array<float2>
    if arrow == ArrowType.small
      arrowPoints = shapes.smallArrowPoints.to_array()
    else
      arrowPoints = shapes.largeArrowPoints.to_array()
    drawFilledPolyOutlined(arrowPoints.scale(float2(r)).rotate(-sina, -cosa).translate(pos))
    resetColorAll()

  def drawTick(pos : float2; r : float; angle : float; len : float)
    var sina, cosa = 0.0
    sincos(deg_to_rad(angle), sina, cosa)
    let rv = float2(sina, -cosa)
    let start : float2 = pos + (r - len) * rv
    let finish : float2 = pos + r * rv
    drawLine(start, finish)

  def drawCircleTicks(pos : float2; angleStart : float; step : float; r : float; len : float; number : int)
    var angle = angleStart

    for _ in range(0, number)
      drawTick(pos, r, angle, len)
      angle += step
    return

  def drawCircleIndicatorValues(pos : float2; angleStart : float; step : float; r : float; values : array<string>)
    var angle = angleStart
    var sina, cosa = 0.0
    for i in range(0, values.length())
      sincos(deg_to_rad(angle), sina, cosa)
      let curPoint : float2 = pos + r * float2(sina, -cosa)
      drawStrAnchored(curPoint, values[i], AnchorHorz.Center, AnchorVert.Center)
      angle += step
    return

  def drawCircleSegment(pos : float2; angleStart : float; angleStop : float; r : float)
    drawSector(pos, float2(r), float2(deg_to_rad(angleStart - 90.0), deg_to_rad(angleStop - 90.0)))
    return

  def drawCircleSegmentFilled(pos : float2; angleStart : float; angleStop : float; r : float; color : E3DCOLOR; fill_color : E3DCOLOR)
    setColor(color)
    setFillColor(fill_color)
    drawCircleSegment(pos, angleStart, angleStop, r)
    resetColorAll()

  def drawCircleFilled(pos : float2; r : float; color : E3DCOLOR; fill_color : E3DCOLOR)
    setColor(color)
    setFillColor(fill_color)
    drawCircle(pos, r)
    resetColorAll()

  def drawSpeed(value : float)
    let pos = float2(-0.45, -0.3)
    let size = 0.18
    var angle = 0.0
    drawCircleFilled(pos, size, colors.green, colors.black)
    drawCircleFilled(pos, 0.01, colors.white, colors.white)
    if isMetric
      drawCircleIndicatorValues(pos, 0.0, 36.0, size - 0.045, ["", "5", "10", "15", "20", "25", "30", "35", "40", "45"])
      drawCircleTicks(pos, 0.0, 36.0, size, 0.02, 9)
      drawCircleTicks(pos, 0.0, 7.2, size, 0.01, 45)
      angle = 180.0 * value / 250.0
    else
      drawCircleTicks(pos, 5.0, 20.0, size, 0.01, 3)
      drawCircleTicks(pos, 65.0, 100.0, size, 0.02, 3)
      drawCircleTicks(pos, 65.0, 20.0, size, 0.01, 10)
      drawTick(pos, size, 300.0, 0.02)
      drawTick(pos, size, 350.0, 0.02)
      drawCircleTicks(pos, 265.0, 7.0, size, 0.01, 5)
      drawCircleTicks(pos, 300.0, 10.0, size, 0.01, 5)
      drawCircleIndicatorValues(pos, 5.0, 0.0, size - 0.045, ["25"])
      drawCircleIndicatorValues(pos, 65.0, 100.0, size - 0.045, ["50", "100", "150"])
      drawCircleIndicatorValues(pos, 300.0, 0.0, size - 0.045, ["200"])
      angle = get_feet_speed_angle(value)

    setColor(colors.cyan)
    drawStrAnchored(pos + float2(0.0, 0.06), isEnglish ? "SPEED" : "СКОРОСТЬ", AnchorHorz.Center, AnchorVert.Center)
    drawArrow(pos, size * 0.8, angle, ArrowType.large)
    resetColorAll()

  def drawRadioAltitude(value : float)
    let pos = float2(-0.45, 0.1)
    let size = 0.18
    var angle = 0.0
    drawCircleFilled(pos, size, colors.green, colors.black)
    if isMetric
      drawCircleTicks(pos, 0.0, 25.0, size, 0.02, 13)
      drawCircleTicks(pos, 00.0, 5.0, size, 0.01, 10)
      drawCircleTicks(pos, 50.0, 12.5, size, 0.01, 23)
      drawCircleIndicatorValues(pos, 0.0, 25.0, size - 0.045, ["", "", "20", "40", "60", "80", "100", "", "300", "", "500", "", "700"])
      angle = value < 20.0 ? 50.0 * (value / 20.0) : value < 100.0 ? 50.0 + 25.0 * (value - 20.0) / 20.0 : 150.0 + 25.0 * (value - 100.0) / 100.0
    else
      drawCircleTicks(pos, 0.0, 15.0, size, 0.02, 11)
      drawCircleTicks(pos, 0.0, 3.0, size, 0.01, 50)
      drawCircleIndicatorValues(pos, 0.0, 30.0, size - 0.045, ["0", "1", "2", "3", "4", "5"])

      drawCircleTicks(pos, 190.0, 40.0, size, 0.02, 4)
      drawCircleTicks(pos, 150.0, 8.0, size, 0.01, 20)
      drawCircleIndicatorValues(pos, 190.0, 40.0, size - 0.045, ["10", "15", "20", "25"])
      angle = value < 500.0 ? value / 100.0 * 30.0 : 150.0 + (value - 500.0) / 500.0 * 40.0

    setColor(colors.cyan)
    let textUnits = isMetric ? (isEnglish ? "METERS" : "МЕТРЫ") : (isEnglish ? "x 100 FT" : "x 100 ФТ")
    let text = isEnglish ? "RADIO ALT" : "РАДИО ВСТ"
    drawStrAnchored(pos + float2(0.0, 0.06), textUnits, AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.0, -0.03), text, AnchorHorz.Center, AnchorVert.Center)

    drawArrow(pos, size * 0.8, angle, ArrowType.large)

    resetColorAll()

  def drawBarometricAltitude(value : float)
    let pos = float2(0.45, -0.3)
    let size = 0.18
    let angleHour = 180.0 * value / 5.0 / 1000.0
    let angleMinute = 180.0 * value / 500.0
    drawCircleFilled(pos, size + 0.01, colors.empty, colors.black)
    drawCircleFilled(pos, 0.01, colors.cyan, colors.cyan)
    drawCircleIndicatorValues(pos, 0.0, 36.0, size - 0.045, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
    drawCircleTicks(pos, 0.0, 36.0, size, 0.02, 10)
    drawCircleTicks(pos, 0.0, 7.2, size, 0.01, 50)
    drawArrow(pos, size, angleMinute, ArrowType.large)
    drawArrow(pos, 0.7 * size, angleHour, ArrowType.small)
    setColor(colors.cyan)
    drawStrAnchored(pos + float2(0.0, 0.06), isEnglish ? "ALTITUDE" : "ВЫСОТА", AnchorHorz.Center, AnchorVert.Center)
    resetColorAll()

  def drawClimb(value : float)
    let maxValue = isMetric ? 15.0 : 40.0
    let minValue = isMetric ? -15.0 : -40.0
    let pos = float2(0.45, 0.1)
    let size = 0.18
    let start_a = 135.0
    let stop_a = 135.0 + 270.0
    let angle = -90.0 + cvt(value, minValue, maxValue, -135.0, 135.0)
    let sin45 = 0.70710
    drawCircleSegmentFilled(pos, start_a, stop_a, size, colors.green, colors.black)
    drawCircleFilled(pos, 0.01, colors.cyan, colors.cyan)
    setColor(colors.black);
    drawFilledPoly(
      [
        pos, pos + size * float2(sin45, sin45), pos + size * float2(sin45, -sin45)
      ]
    )
    setColor(colors.green);
    if isMetric
      drawCircleIndicatorValues(pos, start_a, 45.0, size - 0.045, ["20", "10", "5", "0", "5", "10", "20"])
      drawCircleTicks(pos, start_a, 9.0, size, 0.01, 30)
      drawCircleTicks(pos, start_a, 45.0, size, 0.02, 7)
    else
      drawCircleIndicatorValues(pos, start_a, 33.75, size - 0.045, ["4", "", "2", "1", "0", "1", "2", "", "4"])
      drawCircleTicks(pos, start_a, 33.75, size, 0.02, 9)
      drawCircleTicks(pos, start_a, 6.75, size, 0.01, 40)

    drawArrow(pos, size * 0.8, angle, ArrowType.large)
    setColor(colors.cyan)
    drawStrAnchored(pos - float2(0.0, 0.06), isEnglish ? "UP" : "ПОДЪЕМ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.0, 0.06), isEnglish ? "DOWN" : "СПУСК", AnchorHorz.Center, AnchorVert.Center)
    resetColorAll()

  def drawSlidingClimb(value : float)
    let pos = float2(0.645, 0.09)
    let sizeUp = 0.15
    let sizeDown = 0.25
    let size = sizeDown + sizeUp
    let arrowVerPos = -clamp(value, -25.0, 15.0) / 100.0
    let arrowPos = float2(pos.x - 0.06, pos.y + arrowVerPos)
    let tickNum = 40
    setColor(colors.pink)

    drawLine(pos - float2(0.0, sizeUp), pos + float2(0.0, sizeDown))
    setLineWidth(2.0)
    drawLine(pos, pos - float2(0.03, 0.0))
    setLineWidth(1.0)
    let step = size / float(tickNum)
    for y in range(0, tickNum + 1)
      let posStart = float2(pos.x, pos.y - sizeUp + step * float(y))
      var posFin : float2
      if y % 5 == 0
        posFin = float2(pos.x - 0.02, posStart.y)
      else
        posFin = float2(pos.x - 0.01, posStart.y)
      drawLine(posStart, posFin)
    drawClosedPolyLine(shapes.slidingArrowPoints.to_array().scale(float2(0.03, 0.03)).translate(arrowPos))

    setColor(colors.green)

  def drawVelocityDirection()
    let pos = float2(0.0, 1.0)
    let size = 0.7

    var unitRotation = hero.unitTm
    unitRotation[3] = float3(0.0)
    let normVel = fast_normalize((inverse(unitRotation) * float3(fm.vel.x, fm.vel.y, fm.vel.z)).zx)

    setColor(colors.yellow)
    let start = pos - float2(1.0, 1.0) * size * normVel
    let points = shapes.triangle.to_array().rotate(-normVel.x, normVel.y).scale(float2(0.05)).translate(start)
    drawLine(points[2], points[1])
    drawLine(points[2], points[0])
    resetColorAll()


  def drawCompass(value : float)
    let pos = float2(0.0, 1.0)
    let size = 0.7
    let angleSmallTickStart = 2.0 * floor(value / 2.0) - value - 44.0
    let angleBigTickStart = 30.0 * floor(value / 30.0) - value - 60.0

    let startValue = 30 * floori(value / 30.0) - 60
    var values = to_array_move(fixed_array<string>(
      "{circle_value(startValue)}",
      "{circle_value(startValue + 30)}",
      "{circle_value(startValue + 60)}",
      "{circle_value(startValue + 90)}",
      "{circle_value(startValue + 120)}",
    ))

    drawCircleSegmentFilled(pos, -45.0, 45.0, size, colors.green, colors.black)
    setFontSize(24)
    drawCircleIndicatorValues(pos, angleBigTickStart, 30.0, size - 0.07, values)
    drawCircleTicks(pos, angleSmallTickStart, 2.0, size, 0.02, 44)
    drawCircleTicks(pos, angleBigTickStart, 30.0, size, 0.05, 5)
    setColor(colors.cyan)
    setFillColor(colors.cyan)
    drawFilledPolyOutlined(shapes.trianglePoints.to_array().scale(float2(0.1)).translate(float2(0.0, 0.23)))
    setColor(colors.black)
    setFontSize(14)
    drawStrAnchored(float2(0.0, 0.22), "{floori(value)}",  AnchorHorz.Center, AnchorVert.Center)
    setFontSize(18)
    resetColorAll()

  def drawSkidIndicator()
    let pos = float2(0.0, 0.48)
    let size = 0.015
    let value = 2.0 * getSkidBallValue() * size

    setColor(colors.green)
    setFillColor(colors.lightGreen)
    drawFilledPolyOutlined(
      shapes.square.to_array().scale(float2(5.0 * size, size)).translate(pos)
    )
    setFillColor(colors.black)
    drawCircle(pos + float2(value, 0.0), 0.8 * size)
    drawClosedPolyLine(
      shapes.square.to_array().scale(float2(size, size)).translate(pos)
    )
    resetColorAll()

  def drawPlaneSymbol(pos : float2; size : float; rotation : float)
    var sina, cosa = 0.0
    let circleSize = 0.15 * size;
    sincos(deg_to_rad(rotation), sina, cosa)
    setFillColor(colors.white)
    setColor(colors.blue)
    drawFilledPolyOutlined(shapes.planeWingsPoints.to_array().scale(float2(size)).rotate(sina, cosa).translate(pos))
    drawFilledPolyOutlined(shapes.planeTailPoints.to_array().scale(float2(size)).rotate(sina, cosa).translate(pos))

    setFillColor(colors.empty)
    setColor(colors.white)
    drawCircle(pos, circleSize)
    resetColorAll()

  def drawHorizonIndicator(angle : float; roll : float)
    let pos = float2(0.0, -0.125)
    let size = 0.225
    let rotate = isEnglish;
    let value = clamp(angle / 30.0, -2.0, 2.0);
    let center = pos + float2(0.0, size) * value
    setColor(colors.orange)

    var sina = 0.0
    var cosa = 1.0
    if rotate
      sincos(deg_to_rad(-roll), sina, cosa)

    drawFilledPoly(
      [
        float2(-2.0 * size, center.y), float2(2.0 * size, center.y), float2(2.0 * size, 2.0 * size), float2(-2.0 * size, 2.0 * size)
      ].rotate(sina, cosa)
    )

    setColor(colors.cyan)
    drawFilledPoly(
      [
        float2(-2.0 * size, center.y), float2(2.0 * size, center.y), float2(2.0 * size, -2.0 * size), float2(-2.0 * size, -2.0 * size)
      ].rotate(sina, cosa)
    )

    setColor(colors.shade)
    drawFilledPoly(shapes.horizonIndicatorShade.to_array().scale(float2(size)).translate(pos).rotate(sina, cosa))

    drawPlaneSymbol(pos, 0.9 * size, rotate ? 0.0 : roll);

    var linesUp = array<float2>()
    var linesDown = array<float2>()
    var textUpPos = array<float2>()
    var textDownPos = array<float2>()

    let linesDownNum = floori(6.0 * (1.0 - value))
    let linesUpNum = floori(6.0 * (1.0 + value))

    for i in range(0, linesDownNum)
      if i % 2 == 0
        linesDown.push(float2(-0.015, float(i + 1) * size / 6.0))
        linesDown.push(float2(0.015, float(i + 1) * size / 6.0))
      else
        linesDown.push(float2(-0.04, float(i + 1) * size / 6.0))
        linesDown.push(float2(-0.03, float(i + 1) * size / 6.0))
        linesDown.push(float2(0.04, float(i + 1) * size / 6.0))
        linesDown.push(float2(0.03, float(i + 1) * size / 6.0))
        textDownPos.push(float2(0.00, float(i + 1) * size / 6.0))

    for i in range(0, linesUpNum)
      if i % 2 == 0
        linesUp.push(float2(-0.015, -float(i + 1) * size / 6.0))
        linesUp.push(float2(0.015, -float(i + 1) * size / 6.0))
      else
        linesUp.push(float2(-0.04, -float(i + 1) * size / 6.0))
        linesUp.push(float2(-0.03, -float(i + 1) * size / 6.0))
        linesUp.push(float2(0.04, -float(i + 1) * size / 6.0))
        linesUp.push(float2(0.03, -float(i + 1) * size / 6.0))
        textUpPos.push(float2(0.00, -float(i + 1) * size / 6.0))

    linesDown = linesDown.translate(center).rotate(sina, cosa);
    linesUp = linesUp.translate(center).rotate(sina, cosa);
    textDownPos = textDownPos.translate(center).rotate(sina, cosa);
    textUpPos = textUpPos.translate(center).rotate(sina, cosa);

    setColor(colors.blue)

    for i in range(0, linesUp.length() / 2)
      drawLine(linesUp[2 * i], linesUp[2 * i + 1])

    for i in range(0, textUpPos.length())
      drawStrAnchored(textUpPos[i], "{10 + i * 10}", AnchorHorz.Center, AnchorVert.Center)

    setColor(colors.white)

    for i in range(0, linesDown.length() / 2)
      drawLine(linesDown[2 * i], linesDown[2 * i + 1])

    for i in range(0, textDownPos.length())
      drawStrAnchored(textDownPos[i], "{10 + i * 10}", AnchorHorz.Center, AnchorVert.Center)

    resetColorAll()

  def drawHorizonIndication()
    let pos = float2(0.0, -0.125)
    let size = 0.225

    setColor(colors.black)
    setLineWidth(10.0)
    drawCircle(pos, size)
    setLineWidth(1.0)

    setColor(colors.white)
    drawCircleTicks(pos, 90.0, 5.0, size + 0.01, 0.015, 9)
    drawCircleTicks(pos, 225.0, 5.0, size + 0.01, 0.015, 9)

    drawCircleIndicatorValues(pos, 105.0, 15.0, size + 0.035, ["15", "30", "45"])
    drawCircleIndicatorValues(pos, 225.0, 15.0, size + 0.035, ["45", "30", "15"])

    setLineWidth(3.0)
    drawCircleTicks(pos, 90.0, 15.0, size + 0.01, 0.015, 5)
    drawCircleTicks(pos, 210.0, 15.0, size + 0.01, 0.015, 5)
    setLineWidth(1.0)

    resetColorAll()

  def drawGeneral()

    drawBarometricAltitude(isMetric ? float(fm.pos.y) : float(fm.pos.y) * metrToFeet)

    drawRadioAltitude(isMetric ? float(fm.currentAlt) : float(fm.currentAlt) * metrToFeet)

    drawSpeed(isMetric ? float(fm.speed) * mpsToKmh : float(fm.speed) * mpsToMh)

    drawClimb(isMetric ? float(fm.vel.y) : float(fm.vel.y) * metrToFeet)

    drawSlidingClimb(isMetric ? float(fm.vel.y) : float(fm.vel.y) * metrToFeet)

    drawCompass((norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * 180. / PI)

    drawVelocityDirection()

    drawSkidIndicator()

  def drawBackgroundWithMask(props : PropStorage&)
    let pos = float2(-0.225, -0.35)
    let size = float2(0.45)
    setFillColor(colors.grey)
    setColor(colors.grey)
    if props.horMask != null
      drawPicture(pos, size, props.horMask)

    drawFilledPolyOutlined(
      [
        float2(-0.65, -0.5), float2(0.65, -0.5), float2(0.65, -0.35), float2(-0.65, -0.35)
      ]
    )
    drawFilledPolyOutlined(
      [
        float2(-0.65, 0.5), float2(0.65, 0.5), float2(0.65, 0.1), float2(-0.65, 0.1)
      ]
    )

    drawFilledPolyOutlined(
      [
        float2(-0.65, 0.5), float2(-0.225, 0.5), float2(-0.225, -0.5), float2(-0.65, -0.5)
      ]
    )

    drawFilledPolyOutlined(
      [
        float2(0.65, 0.5), float2(0.225, 0.5), float2(0.225, -0.5), float2(0.65, -0.5)
      ]
    )
    resetColorAll()

  def draw(props : PropStorage&)
    return if !isValid && props.horMask == null
    drawHorizonIndicator(fmw.tangage, fmw.roll)
    drawBackgroundWithMask(props)
    drawHorizonIndication()
    drawGeneral()
    return


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw(props)


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId =  props |> getInt("fontId", 0)
  propStorage.horMask =  props |> getPicture("horMask")
  propStorage.english =  props |> getBool("english", false)
