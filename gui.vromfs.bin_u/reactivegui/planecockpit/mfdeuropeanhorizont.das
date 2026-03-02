require %dasGameLibs.math
require %dasGameLibs.math.base
require %rGui.utils.avionics_common
require %rGui.utils.canvas_common
require %rGui.utils.helpers_common
require %rGui.utils.constants_common
require app
require DagorMath
require DagorStdGuiRender
require darg
require DagorDataBlock
require FlightModelWrap
require GamePhys
require HeroManager
require hud
require Plane
require strings
require Unit
require Weapon
require WTCamera

struct PropStorage
  fontId : int
  isMetricUnits : bool
  fontSize : int

let
  COLOR_BLACK = E3DCOLOR(uint4(0, 0, 0, 255))
  COLOR_WHITE = E3DCOLOR(uint4(255, 255, 255, 255))
  COLOR_GREY = E3DCOLOR(uint4(50, 50, 50, 255))
  COLOR_SKY = E3DCOLOR(uint4(10, 105, 180, 255))
  COLOR_GROUND = E3DCOLOR(uint4(110, 60, 40, 255))
  COLOR_NULL = E3DCOLOR(0x0)

class Component : Canvas
  isValid : bool = false
  isMetricUnits : bool = true
  hero : Unit? = null
  fcm : FlightControlMode? = null
  hud : Hud? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  cockpit : FlightModelCockpit? = null
  wc : WeaponController? = null
  app : AcesApp? = null

  defaultLineWidth : float = 5.0
  defaultFontSize : int = 35

  visual : Visual


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    fcm = get_flight_control_mode()
    return if fcm == null
    hud = hud::get_cur_hud()
    return if hud == null
    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null
    fm = fmw.fm
    return if fm == null
    cockpit = fmw.cockpit
    return if cockpit == null
    wc = hero.weap
    return if wc == null
    app = get_app()
    return if app == null

    isValid = true
    isMetricUnits = props.isMetricUnits
    defaultFontSize = props.fontSize
    visual <- avionics_common::get_visual(app.usefulTotalTime, hero)
    setColor(COLOR_WHITE)
    setLineWidth(defaultLineWidth)
    setFont(props.fontId)
    setFontSize(defaultFontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)


  def drawPitchLadder()
    let stepRel = 0.04
    let stepSizeDeg = 2.5

    let count = roundi(toRelY(length(canvasSize)) / stepRel)
    let tangageStepDeg = rad_to_deg(visual.euler.y) / stepSizeDeg
    let marksVertOffset = fract(tangageStepDeg) * stepRel
    let zeroPos = float2(0.0)
    setRotation(float2(0.0), visual.euler.z)
    setTextAnchorHorz(AnchorHorz.Left)
    // Background
    let bgHw = length(float2(0.5))
    let bgPosY = clamp(tangageStepDeg * stepRel, -bgHw, bgHw)
    setColor(COLOR_SKY)
    setFillColor(COLOR_SKY)
    drawBox(float2(-bgHw, bgPosY - bgHw * 2.0), float2(bgHw, bgPosY))
    setColor(COLOR_GROUND)
    setFillColor(COLOR_GROUND)
    drawBox(float2(-bgHw, bgPosY), float2(bgHw, bgPosY + bgHw * 2.0))
    setColor(COLOR_WHITE)
    drawLine(float2(-bgHw, bgPosY), float2(bgHw, bgPosY))
    // Marks
    for i in -count..count + 1
      var markWidth = 0.15
      let markTangageStepDeg = floori(tangageStepDeg) - i
      if abs(markTangageStepDeg) > roundi(90.0 / stepSizeDeg)
        continue
      let markOffset = marksVertOffset + float(i) * stepRel
      let pos = zeroPos + float2(0.0, markOffset)
      if abs(markTangageStepDeg) % 4 == 2
        markWidth *= 0.5
      elif abs(markTangageStepDeg) % 2 == 1
        markWidth *= 0.3
      if markTangageStepDeg != 0
        let p0 = float2(-markWidth, 0.0)
        let p1 = float2(markWidth, 0.0)
        drawLine(pos + p1, pos + p0)

      if markTangageStepDeg == 0 || markTangageStepDeg % 4 != 0
        continue

      let str = "{abs(float(markTangageStepDeg) * 2.5)}"
      let strSize = getStringSize(str)
      let dx = 0.004 + markWidth
      drawStrAnchored(pos + float2(dx, 0.0), str, AnchorHorz.Left, AnchorVert.Center)
      drawStrAnchored(pos + float2(-dx, 0.0), str, AnchorHorz.Right, AnchorVert.Center)
    resetViewTm()


  def drawVerticalLadder(val : float;
                         pos : float2;
                         size : float2;
                         step_count : int;
                         step_sz : float;
                         flip_x  : bool;
                         fmt : block<(val : int) : string>)
    let lt = pos - 0.5 * size
    let rb = pos + 0.5 * size
    let stepRel = size.y / float(step_count)
    let stepVal = val / step_sz
    let anchorInt = floor(stepVal + 0.5)
    let shiftPixels = (stepVal - float(anchorInt)) * stepRel
    let halfCount = int(step_count / 2) + 1
    let baseX = flip_x ? lt.x : rb.x
    // Ladder
    for i in -halfCount..halfCount + 1
      let y = pos.y + (float(i) * stepRel) + shiftPixels
      if y > lt.y && y < rb.y
        let p1 = float2(baseX, y)
        let p2 = float2(baseX + size.x * (flip_x ? 1.0 : -1.0), y)
        let strVal = int(anchorInt) - i
        if strVal % 2 == 0
          let str = fmt |> invoke(strVal)
          drawStrAnchored(p1, str, flip_x ? AnchorHorz.Left : AnchorHorz.Right, AnchorVert.Center)
        else
          drawLine(p1, p2)


  def drawIas()
    let ias = fmw.ias * (isMetricUnits ? MPS_TO_KPH : MPS_TO_KTS)
    drawIasIndicator(ias)
    drawIasValue(ias)


  def drawIasIndicator(ias : float)
    let size = float2(0.05, 1.0)
    let pos = float2(-0.4, 0.0)
    let stepSize = 10.0
    let stepCount = 14
    let isFlipped = false

    setColor(COLOR_GREY)
    setFillColor(COLOR_GREY)
    let hw = size * 0.5
    drawBox(float2(-0.5, pos.y - hw.y), pos + hw)
    setColor(COLOR_WHITE)
    drawLine(pos + hw, float2(pos.x + hw.x, pos.y - hw.y))

    drawVerticalLadder(ias, pos, size, stepCount, stepSize, isFlipped) <| $(val : int)
      return fmt(":3d", val * 10)


  def drawIasValue(ias : float)
    setFillColor(COLOR_BLACK)
    let pos = float2(-0.5, 0.0)
    let padding = float2(0.02)
    let iasRounded = floori(ias)
    let size = getStringSize("000") + padding * 2.0

    let lt = float2(pos.x, pos.y - size.y * 0.5)
    let rb = float2(pos.x + size.x, pos.y + size.y * 0.5)
    drawBox(lt, rb)

    setViewport(lt, rb)
    let str1 = fmt(":02d", iasRounded / 10)
    let strPos = float2(pos.x + padding.x + getStringSize(str1).x, pos.y)
    drawStrAnchored(strPos, str1, AnchorHorz.Right, AnchorVert.Center)

    let offset = fract(ias) * getFontAscent()
    for i in -2..3
      let digit = iasRounded - i
      let str =  digit >= 0 ? string(digit % 10) : " "
      let digitPosY = strPos.y + (float(i) * getFontAscent()) + offset
      drawStrAnchored(float2(strPos.x, digitPosY), str, AnchorHorz.Left, AnchorVert.Center)
    restoreViewport()


  def drawAlt()
    let alt = (hero.unitTm[3].y - app.currentScene.waterLevel) * (isMetricUnits ? 1.0 : M_TO_FT) * 0.1
    drawAltIndicator(alt)
    drawAltValue(alt)


  def drawAltIndicator(alt : float)
    let size = float2(0.05, 1.0)
    let pos = float2(0.35, 0.0)
    let stepSize = 10.0
    let stepCount = 14
    let isFlipped = true

    setColor(COLOR_GREY)
    setFillColor(COLOR_GREY)
    let hw = size * 0.5
    drawBox(pos - hw, float2(0.5, pos.y + hw.y))
    setColor(COLOR_WHITE)
    drawLine(pos - hw, float2(pos.x - hw.x, pos.y + hw.y))

    drawVerticalLadder(alt, pos, size, stepCount, stepSize, isFlipped) <| $(val : int)
      return fmt(":3d", val * 100)


  def drawAltValue(alt : float)
    setFillColor(COLOR_BLACK)
    let pos = float2(0.5, 0.0)
    let padding = float2(0.02)
    let altRounded = floori(alt)
    let size = getStringSize("00000") + padding * 2.0

    let lt = float2(pos.x - size.x, pos.y - size.y * 0.5)
    let rb = float2(pos.x, pos.y + size.y * 0.5)
    drawBox(lt, rb)

    setViewport(lt, rb)
    let str1 = fmt(":03d", altRounded / 10)
    let strPos = float2(pos.x - padding.x - getStringSize("00").x, pos.y)
    drawStrAnchored(strPos, str1, AnchorHorz.Right, AnchorVert.Center)
    let offset = fract(alt) * getFontAscent()
    for i in -2..3
      let digit = altRounded - i
      let str =  digit >= 0 ? fmt(":02d", (digit % 10) * 10) : " "
      let digitPosY = strPos.y + (float(i) * getFontAscent()) + offset
      drawStrAnchored(float2(strPos.x, digitPosY), str, AnchorHorz.Left, AnchorVert.Center)
    restoreViewport()


  def drawHeadingTape()
    let ftHt = getFontAscent()
    let padding = float2(0.01)
    let size = float2(1.0, 0.03 + ftHt) + padding
    let pos = float2(0.0, 0.5 - size.y * 0.5)
    let forward = hero.unitTm[0]
    let heading = atan2(forward.x, forward.z)
    let lt = pos - 0.5 * size
    let rb = pos + 0.5 * size

    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(lt, rb)
    setColor(COLOR_WHITE)
    setFillColor(COLOR_WHITE)

    let triangle = array(
      float2(0.00, 0.00),
      float2(-0.025,  -0.06),
      float2(0.025,  -0.06),
    ).translate(float2(pos.x, lt.y))
    drawFilledPoly(triangle)

    let count = 8
    let stepRel = size.x / float(count)
    let totalTicks = 72.0
    let headingTicks = (0.5 * float(count + 1) - heading * totalTicks / TWOPI)
    let offset = fract(headingTicks) * stepRel

    for i in 0..count + 1
      let x = lt.x + (float(i) - 0.5) * stepRel + offset
      if x > lt.x && x < rb.x
        let tickValue = ((7200 - floori(headingTicks) + i) % 72) * 5
        let hasText = (tickValue % 10 == 0)
        let lineHeight = size.y - ftHt - padding.y
        let lineTop = float2(x, lt.y)
        let lineBottom = float2(x, lt.y + lineHeight)
        drawLine(lineTop, lineBottom)

        if hasText
          let str = fmt(":03", tickValue)
          let strSize = getStringSize(str, 2)
          let strPos = lineBottom
          drawStrAnchored(strPos, str, AnchorHorz.Center, AnchorVert.Top)


  def drawBankAngleIndicator()
    let pos = float2(0.0, 0.0)
    let divs = 36
    let interval = TWOPI / float(divs)
    var sina, cosa : float
    let half = divs / 2
    let up = half / 2
    let gap = 0.35
    for i in 3..half - 2
      var length = 0.02
      if i == up
        let triangle = array(
          float2(0.00, 0.00),
          float2(-0.03,  -0.03),
          float2(0.03,  -0.03),
        ).translate(float2(0.0, -gap))
        drawFilledPoly(triangle)
        continue
      if i % 3 == 0
        length *= 1.5
      let angle = -float(i) * interval
      sincos(angle, sina, cosa)
      let end = gap + length
      let startPos = float2(gap * cosa, gap * sina) + pos
      let endPos = float2(end * cosa, end * sina) + pos
      drawLine(startPos, endPos)

    let limit = 6.0 * interval
    let clampedRoll = clamp(visual.euler.z + PI, -limit + PI, limit + PI)
    sincos(clampedRoll, sina, cosa)
    let triangle = array(
      float2(0.00, 0.00),
      float2(-0.04,  -0.04),
      float2(0.04,  -0.04),
    ).translate(float2(0.0, gap)).rotate(sina, cosa).translate(pos)
    drawFilledPoly(triangle)


  def drawTopBar()
    let padding = float2(0.02)
    let lineWidthRel = toRelY(lineWidth)
    let lt = float2(-0.5, -0.5)
    let ht = getFontAscent() + padding.y * 2.0 + lineWidthRel
    let rb = float2(0.5, lt.y + ht)
    setFillColor(COLOR_BLACK)
    setColor(COLOR_BLACK)
    drawBox(lt, rb)
    drawPressure(padding, lineWidthRel)
    drawMach(padding, lineWidthRel)


  def drawPressure(padding : float2; line_width : float)
    let posPa = float2(0.0, -0.5 + padding.y + line_width)
    let posInhg = float2(0.5 - padding.x - line_width, -0.5 + padding.y + line_width)
    let pressure = GamePhys::pressure(hero.unitTm[3].y - app.currentScene.waterLevel)
    let strPa = "{fmt(":04d", roundi(pressure * 0.01))}hPa"
    let strInhg = "{fmt(":2.2f", pressure * PA_TO_INHG)}inHg"
    setColor(COLOR_WHITE)
    drawStrAnchored(posPa, strPa, AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(posInhg, strInhg, AnchorHorz.Right, AnchorVert.Top)


  def drawMach(padding : float2; line_width : float)
    let pos = float2(-0.5, -0.5) + padding + float2(line_width)
    let str = "{fmt(":>1.2f", fmw.fm.cache.Mach)}M"
    let bbox = getStrBbox(pos, str, AnchorHorz.Left, AnchorVert.Top)
    setColor(COLOR_WHITE)
    drawBBox(bbox, padding.x)
    drawStrAnchored(pos, str, AnchorHorz.Left, AnchorVert.Top)


  def drawAircraftSymbol
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawCircle(float2(0.0), 0.01)
    var wing = array<float2>(
      float2(-0.1, 0.05),
      float2(-0.1, 0.0),
      float2(-0.28, 0.0),
    )
    drawPolyLine(wing)
    drawPolyLine(wing.inv_x())


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawPitchLadder()
    drawBankAngleIndicator()
    drawHeadingTape()
    drawIas()
    drawAlt()
    drawTopBar()
    drawAircraftSymbol()
    restoreViewport()

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.isMetricUnits = getBool(props, "isMetricUnits", true)

  let blk = getBlk(props, "blk")
  return if blk == null

  propStorage.fontSize = *blk->datablock_getInt("fontSize", 35)
