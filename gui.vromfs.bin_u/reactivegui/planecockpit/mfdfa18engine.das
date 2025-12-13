require %rGui.utils.canvas_common
require %rGui.utils.helpers_common
require %rGui.utils.weaponslots_common
require %rGui.utils.avionics_common
require %rGui.utils.constants_common
require %rGui.planeCockpit.mfdFA18C_common

require GamePhys
require app
require DagorDataBlock
require DagorMath
require DagorStdGuiRender
require DagorSystem
require darg
require FlightModelWrap
require GuidanceLock
require HeroManager
require hud
require math
require Plane
require strings
require Unit
require Weapon
require RadarHud

struct PropStorage
  fontId    : int
  fontSize    : int


let fuelUnitsMult = kgToPound * 0.01
let bingoPercent = 0.33

class Component : Canvas
  isValid : bool

  fontSize : int

  hero : Unit?
  fmw : FlightModelWrap?
  fm : FlightModel?
  propulsion : Propulsion?

  fuelState : FuelState

  def Component(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&; isIls : bool = false)
    Canvas`Canvas(self, ctx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    fmw = hero.as_fmw()
    return if fmw == null
    fm = fmw.fm
    return if fm == null
    propulsion = fm.EI
    return if propulsion == null

    isValid = true

    setFont(props.fontId)
    setFontSize(props.fontSize)
    fontSize = props.fontSize
    setColor(fa18RadarColor)

  def draw()
    return if !isValid

    drawFuel(float2(-0.5, -0.5), float2(1.0, 0.5))
    drawEngineState(float2(-0.5, 0.0), float2(0.5))
    drawNozzleState(float2(0.0), float2(0.5))

  def drawNozzleState(pos, size : float2)
    pushLocalAxes(pos, size)
    drawBox(float2(0.0), float2(1.0))

    drawStrAnchored(float2(0.5, 0.2), "NOZ", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(0.5, 0.2), "%", AnchorHorz.Center, AnchorVert.Top)

    for i in range(propulsion.numEngines)
      let anchorX = i == 0 ? 0.25 : 0.75

      let y = 0.5
      let r = 0.2

      setFillColor(fa18RadarColor)
      drawCircle(float2(anchorX, y), r)

      setFillColor(E3DCOLOR(0xFF000000))
      let nozzleAngle = get_nozzle_angle(fmw, i)
      drawCircle(float2(anchorX, y), r * nozzleAngle)

      let nozzleAngleText = "{floori(nozzleAngle * 100.0)}"
      drawStrAnchored(float2(anchorX, y + r + 0.05), nozzleAngleText, AnchorHorz.Center, AnchorVert.Top)


    popAxes()

  def drawEngineState(pos, size : float2)
    pushLocalAxes(pos, size)

    drawBox(float2(0.0), float2(1.0))

    let midX = 0.5

    let rpmY = 0.2
    drawStrAnchored(float2(midX, rpmY), "RPM", AnchorHorz.Center, AnchorVert.Bottom)

    let tempY = 0.4
    drawStrAnchored(float2(midX, tempY), "TEMP", AnchorHorz.Center, AnchorVert.Bottom)

    let fuelConsumptionY = 0.6
    drawStrAnchored(float2(midX, fuelConsumptionY), "FF", AnchorHorz.Center, AnchorVert.Bottom)

    let oilY = 0.8
    drawStrAnchored(float2(midX, oilY), "OIL", AnchorHorz.Center, AnchorVert.Bottom)

    var fctx : StdGuiFontContext
    get_font_context(fctx, font.id, 0, 0, font.size)
    let fontAscent = toRelY(float(get_font_ascent(fctx)))

    for i in range(propulsion.numEngines)
      let anchorX = i == 0 ? 0.33 : 0.8
      propulsion_getEngine(*propulsion, i) <| $(eng)
        let rpmText = "{floori(eng.omega)}"
        drawStrAnchored(float2(anchorX, rpmY), rpmText, AnchorHorz.Right, AnchorVert.Bottom)

        let tempText = "{floori(eng.headTemp)}"
        drawStrAnchored(float2(anchorX, tempY), tempText, AnchorHorz.Right, AnchorVert.Bottom)

        let ffText = "{floori(eng.fuelConsumption * fuelUnitsMult * 100.0)}"
        drawStrAnchored(float2(anchorX, fuelConsumptionY), ffText, AnchorHorz.Right, AnchorVert.Bottom)
        setFontSize(floori(float(fontSize) * 0.5))
        drawStrAnchored(float2(anchorX, fuelConsumptionY - fontAscent), "00", AnchorHorz.Left, AnchorVert.Top)
        setFontSize(fontSize)

        let oilText = "{floori(eng.oilPressure * 100.0)}"
        drawStrAnchored(float2(anchorX, oilY), oilText, AnchorHorz.Right, AnchorVert.Bottom)

    popAxes()

  def drawFuel(pos, size : float2)
    pushLocalAxes(pos, size)

    drawBox(float2(0.0), float2(1.0))

    fuelState = get_fuel_state(fm.M) <| $(index : int; curr, max : float)
      drawExternalFuelTank(index, curr, max)

    drawFuelTexts()
    drawTotalTank()

    popAxes()

  def drawExternalFuelTank(index : int; curr, max : float)
    let boxSize = float2(0.1, 0.2)
    let ltAnchor = float2(0.25, 0.6)
    let boxOffset = float2(0.05, 0.0)

    let lt = ltAnchor + float2((boxSize.x + boxOffset.x) * float(index), 0.0)
    let rb = lt + boxSize
    drawBox(lt, rb)

    let t = curr / max
    drawTank(lt, rb, t)

    let textPos = float2(lt.x + boxSize.x * 0.5, rb.y + 0.03)
    let fuelText = fmt(":.1f", fuelUnitsMult * curr)
    drawStrAnchored(textPos, fuelText, AnchorHorz.Center, AnchorVert.Top)

  def drawFuelTexts()
    let totalFuelText = fmt(":.1f", fuelUnitsMult * fuelState.current)
    let totalFuelAnchor = float2(0.1, 0.2)
    drawStrAnchored(totalFuelAnchor, "TOTAL", AnchorHorz.Right, AnchorVert.Bottom)
    drawStrAnchored(totalFuelAnchor + float2(0.0, 0.05), totalFuelText, AnchorHorz.Right, AnchorVert.Top)

    let bingoAmmount = bingoPercent * fuelState.maxAvailable
    let bingoAmmountText = fmt(":.1f", fuelUnitsMult * bingoAmmount)
    drawStrAnchored(float2(0.76, 0.2), "BINGO", AnchorHorz.Left, AnchorVert.Bottom)
    drawStrAnchored(float2(0.95, 0.2), bingoAmmountText, AnchorHorz.Right, AnchorVert.Bottom)

    if fuelState.hasAvailableExternals
      let extText = fmt(":.1f", fuelUnitsMult * fuelState.currentExternal)
      drawStrAnchored(float2(0.05, 0.6), "EXT", AnchorHorz.Left, AnchorVert.Bottom)
      drawStrAnchored(float2(0.22, 0.6), extText, AnchorHorz.Right, AnchorVert.Bottom)

      let intText = fmt(":.1f", fuelUnitsMult * fuelState.currentInternal)
      drawStrAnchored(float2(0.76, 0.3), "INT", AnchorHorz.Left, AnchorVert.Bottom)
      drawStrAnchored(float2(0.95, 0.3), intText, AnchorHorz.Right, AnchorVert.Bottom)

  def drawTotalTank()
    let lt = float2(0.25, 0.1)
    let rb = float2(0.75, 0.45)

    drawBox(lt, rb)

    let t = fuelState.current / fuelState.maxAvailable
    drawTank(lt, rb, t)


    let bingoY = lerp(rb.y, lt.y, bingoPercent)
    let bingoL = float2(lt.x, bingoY)
    drawLine(bingoL, float2(rb.x, bingoY))
    drawArrowHead(bingoL, float2(1.0, 0.0), float2(0.03))

    drawStrAnchored(bingoL - float2(0.02, 0.0), "B", AnchorHorz.Right, AnchorVert.Center)

  def drawTank(lt, rb : float2; t : float)
    let curFuelLt = float2(lt.x, lerp(rb.y, lt.y, t))
    let fuelColor = color_mult4(fa18RadarColor, 0.8)
    setFillColor(fuelColor)
    setColor(fuelColor)
    drawBox(curFuelLt, rb)
    setFillColor(E3DCOLOR(0x00000000))
    setColor(fa18RadarColor)


[export, unused_argument(ctx, rdata, rstate, props)]
def render(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(ctx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.fontSize = getInt(props, "fontSize", 15)
