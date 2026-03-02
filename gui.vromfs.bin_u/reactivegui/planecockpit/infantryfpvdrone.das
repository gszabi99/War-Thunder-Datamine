require %rGui.utils.canvas_common
require %rGui.utils.helpers_common
require %rGui.utils.avionics_common
require %rGui.utils.constants_common

require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require math
require %dasGameLibs.math.base
require Plane
require strings
require Unit
require hud

struct Colors
  white  = E3DCOLOR(0xFF_DDDDDD)
  black  = E3DCOLOR(0xFF_000000)

struct PropStorage
  fontId : int

struct Shapes
  square <- fixed_array(
    float2(-1.0, -1.0),
    float2(-1.0, 1.0),
    float2(1.0, 1.0),
    float2(1.0, -1.0),
  )

  squareCorner <- fixed_array(
    float2(0.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0),
    float2(1.0, 0.0),
  )

class Component : Canvas
  isValid : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  app : AcesApp? = null
  colors : Colors = Colors()
  shapes : Shapes = Shapes()
  fuelState : FuelState



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

    isValid = true
    setLineWidth(2.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(25)
    setFillColor(colors.white)
    setColor(colors.white)

  def drawRect(pos : float2; size : float2)
    drawFilledPoly(shapes.square.to_array().scale(size).translate(pos))

  def drawHorizonLine()
    let roll = fmw.roll
    let pitch = fmw.tangage

    let pointNum = 11
    let dotSize = float2(0.004, 0.0)
    let pos = float2(0.0, 0.05)
    let size = float(0.4)

    let ydelta = pitch / 90.0
    var sina, cosa = 0.0
    sincos(deg_to_rad(-roll), sina, cosa)
    let center = pos + float2(0.0, ydelta)
    let start = center + float2(size * cosa, size * sina)
    let finish = center + float2(-size * cosa, -size * sina)

    let step = (finish - start) / float(pointNum - 1)

    setLineWidth(3.0)

    for i in range(0, pointNum)
      let curPointPos = start + step * float(i)
      drawLine(curPointPos - 0.5 * dotSize, curPointPos + 0.5 * dotSize)

    setLineWidth(2.0)

  def drawCenter()

    let pos = float2(0.0, 0.0)
    let size = float2(0.01, 0.01)

    setLineWidth(3.0)

    drawClosedPolyLine(shapes.square.to_array().scale(0.6 * size).rotate(0.707106, 0.707106).translate(pos))

    drawLine(pos + float2(-0.2 * size.x, 2.0 * size.y), pos + float2(0.2 * size.x, 2.0 * size.y))
    drawLine(pos + float2(-0.2 * size.x, -2.0 * size.y), pos + float2(0.2 * size.x, -2.0 * size.y))

    drawLine(pos + float2(2.0 * size.x, -0.2 * size.y), pos + float2(2.0 * size.x, 0.2 * size.y))
    drawLine(pos + float2(-2.0 * size.x, -0.2 * size.y), pos + float2(-2.0 * size.x, 0.2 * size.y))

    drawLine(pos + float2(3.0 * size.x, -0.2 * size.y), pos + float2(3.0 * size.x, 0.2 * size.y))
    drawLine(pos + float2(-3.0 * size.x, -0.2 * size.y), pos + float2(-3.0 * size.x, 0.2 * size.y))

    setLineWidth(2.0)

  def drawPitch()
    let pitchRatio = min(1.0, max(-1.0, fmw.tangage / 90.0))

    let pos = float2(0.0, 0.0)
    let size = float2(0.4, 0.5)
    let numberOfDots = 15

    let first = pos - 0.5 * size
    let step = size.y / float(numberOfDots - 1)

    setLineWidth(4.0)

    for i in range(0, numberOfDots)
      let left = first + float(i) * float2(0.0, step)
      let right = left + float2(size.x, 0.0)

      if i % 2 == 0
        drawLine(left - float2(0.0015, 0.0), left + float2(0.0015, 0.0))
        drawLine(right - float2(0.0015, 0.0), right + float2(0.0015, 0.0))
      else
        drawLine(left - float2(0.005, 0.0), left + float2(0.005, 0.0))
        drawLine(right - float2(0.005, 0.0), right + float2(0.005, 0.0))

    setLineWidth(2.0)

    let carretPosLeft = float2(-0.4 * size.x, -0.5 * pitchRatio * size.y)
    let carretPosRight = float2(0.4 * size.x, -0.5 * pitchRatio * size.y)

    drawLine(carretPosLeft, carretPosLeft + 0.025 * float2(size.x, size.x))
    drawLine(carretPosLeft, carretPosLeft + 0.025 * float2(size.x, -size.x))

    drawLine(carretPosRight, carretPosRight - 0.025 * float2(size.x, size.x))
    drawLine(carretPosRight, carretPosRight - 0.025 * float2(size.x, -size.x))

  def drawFuelTime()
    let fuelRemainingTimeS = floori(get_remaining_fuel_time())

    let pos = float2(-0.362, 0.15)
    drawStrAnchored(pos, "{format("%02d", fuelRemainingTimeS / 60)} : {format("%02d", fuelRemainingTimeS % 60)}",  AnchorHorz.Center, AnchorVert.Center)


  def drawFuelVoltage()
    let fuelRemaining = fuelState.current / fuelState.maxAvailable

    let pos = float2(-0.4, 0.19)

    let maxVoltage = 22.0
    let minVoltage = 18.0
    let curVoltage = lerp(minVoltage, maxVoltage, fuelRemaining)

    drawStrAnchored(pos, "{format("%.2f", curVoltage)} V",  AnchorHorz.Left, AnchorVert.Bottom)


  def drawFuelBattery()
    let fuelRemaining = fuelState.current / fuelState.maxAvailable

    let pos = float2(-0.41, 0.19)
    let size = float2(0.025, 0.05)
    let smallSize = float2(0.005, 0.001)

    drawFilledPoly(shapes.squareCorner.to_array().scale(-size).translate(pos))

    let smallPos = pos + float2(-0.5 * (size.x - smallSize.x), -size.y)
    drawFilledPoly(shapes.squareCorner.to_array().scale(-smallSize).translate(smallPos))

    if 1.0 - fuelRemaining < 1e-4
      return

    setColor(colors.black)

    let margin = 0.001
    let fullSize = float2(size.x - 2.0 * margin, size.y - 2.0 * margin)
    let curSize = float2(fullSize.x, (1.0 - fuelRemaining) * fullSize.y)

    let startPos = pos - size + float2(margin)
    drawFilledPoly(shapes.squareCorner.to_array().scale(curSize).translate(startPos))
    setColor(colors.white)

  def drawAlt()
    let alt = float(fm.input.currentAlt)

    let pos = float2(0.39, 0.15)

    drawStrAnchored(pos, "ALT  {format("%3d", floori(alt))}",  AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.1, 0.00), "M",  AnchorHorz.Left, AnchorVert.Center)

  def drawVelocity()
    let vel = fm.speed * mpsToKmh

    let pos = float2(0.39, 0.18)

    drawStrAnchored(pos, "VEL  {format("%3d", floori(vel))}",  AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.1, 0.00), "km/h",  AnchorHorz.Left, AnchorVert.Center)

  def drawEngineThrottle()
    let thrust = float(fm.appliedCT.getPower(0))

    let pos = float2(0.39, 0.21)

    drawStrAnchored(pos, "THR {format("%3d", floori(thrust * 100.0))}",  AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.1, 0.00), "%",  AnchorHorz.Left, AnchorVert.Center)

  def drawSignalQuality()
    let signalQualityRatio = float(get_drone_connection_quality()) / 3.0

    let pos = float2(0.39, -0.2)
    let width = 0.01
    let startHeight = 0.007
    let heightInc = 0.007
    let margin = 0.002
    let maxLinesNumber = 6
    let linesNumber = int(signalQualityRatio * float(maxLinesNumber))

    drawStrAnchored(pos + float2(0.04, -0.06), "LQ",  AnchorHorz.Center, AnchorVert.Center)

    for i in range(0, linesNumber)
      let curPos = pos + float(i) * float2(width + margin, 0.0)
      let curSize = float2(width, startHeight + float(i) * heightInc)
      drawFilledPoly(shapes.squareCorner.to_array().scale(-curSize).translate(curPos))

  def draw()
    if !isValid
      return

    setColor(colors.white)
    drawCenter()
    drawPitch()
    drawHorizonLine()
    drawSignalQuality()
    drawAlt()
    drawVelocity()
    drawEngineThrottle()

    fuelState = get_fuel_state(fm.M) <| $[unused_argument(index, curr, max)] (index : int; curr, max : float)
      return
    drawFuelVoltage()
    drawFuelBattery()
    drawFuelTime()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
