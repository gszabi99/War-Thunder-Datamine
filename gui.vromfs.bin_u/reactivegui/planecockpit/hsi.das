require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require math
require strings
require Unit

enum NavSource
  NONE = 0
  LOC1 = 1
  LOC2 = 2
  VOR  = 3
  GPS  = 4
  ILS  = 5

struct HsiProps
  lineColor   : E3DCOLOR
  fontId      : int
  fontSize    : int
  lineWidth   : float
  courseSet   : float
  deviation   : float
  groundSpeed : int
  distance    : float
  toFrom      : int
  headingBug  : float
  navSource   : int

def navSourceToLabel(src : int) : string
  if src == int(NavSource.LOC1)
    return "LOC1"
  if src == int(NavSource.LOC2)
    return "LOC2"
  if src == int(NavSource.VOR)
    return "VOR"
  if src == int(NavSource.GPS)
    return "GPS"
  if src == int(NavSource.ILS)
    return "ILS"
  return "---"

let RING_R         = 0.44
let ROSE_OUTER_R   = 0.42
let CDI_HALF_LEN   = 0.13
let CDI_DOTS       = 5
let CDI_DOT_STEP   = 0.025
let ARROW_HEAD_W   = 0.028
let ARROW_HEAD_LEN = 0.07

let COLOR_GREEN = E3DCOLOR(0xFF00FF00)

class Component : Canvas
  isValid    : bool             = false
  hero       : Unit?            = null
  fmw        : FlightModelWrap? = null
  props      : HsiProps const?  = null
  headingRad : float            = 0.0
  headingDeg : float            = 0.0
  gsKnots    : int              = 0

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
                rstate : RenderState& const; p : HsiProps&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null

    self.props = unsafe(addr(p))

    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setColor(p.lineColor)
    setLineWidth(p.lineWidth)
    setFont(p.fontId)
    setFontSize(p.fontSize)
    setLineSpacing(0.85)

    let fwd = fast_normalize(hero.unitTm[0].xz)
    headingRad = atan2_est(fwd.x, fwd.y)
    headingDeg = norm_ang(headingRad) * radToDeg

    gsKnots = int(length(hero.vel.xz) * mpsToKnots)

    isValid = true

  def compassAngle(bearingDeg : float) : float
    return bearingDeg * degToRad - headingRad - PI_2

  def drawOuterRing()
    drawCircle(float2(0.0), RING_R)

  def drawCompassRose()
    var sina, cosa : float
    for i in 0 .. 72
      let tickDeg    = i * 5
      let isCardinal = (i % 18) == 0
      let isLabel    = (i %  6) == 0
      let isMajor    = (i %  2) == 0

      sincos(compassAngle(float(tickDeg)), sina, cosa)

      var innerR = ROSE_OUTER_R - 0.03
      if isCardinal
        innerR = ROSE_OUTER_R - 0.09
      elif isMajor
        innerR = ROSE_OUTER_R - 0.06

      drawLine(float2(innerR      * cosa, innerR      * sina),
               float2(ROSE_OUTER_R * cosa, ROSE_OUTER_R * sina))

      if isLabel
        let screenAngle = compassAngle(float(tickDeg))
        let distFromTop = abs(norm_ang(screenAngle + PI_2))
        if distFromTop < 18.0 * degToRad
          continue
        var lbl = ""
        if tickDeg == 0
          lbl = "N"
        elif tickDeg == 90
          lbl = "E"
        elif tickDeg == 180
          lbl = "S"
        elif tickDeg == 270
          lbl = "W"
        else
          lbl = "{tickDeg / 10}"
        let textR = innerR - 0.055
        if isCardinal
          setFontSize(props.fontSize + 2)
        drawStrAnchored(float2(textR * cosa, textR * sina),
                        lbl, AnchorHorz.Center, AnchorVert.Center)
        if isCardinal
          setFontSize(props.fontSize)

  def drawHeadingBox()
    let hdg = roundi(headingDeg) % 360
    let str = fmt(":03d", hdg)
    let halfSz = getStringSize(str) * 0.5 + float2(0.025, 0.012)
    pushLocalAxes(float2(0.0, -RING_R + 0.14), halfSz)
    setFillColor(props.lineColor)
    drawBox(float2(-1.0), float2(1.0))
    setFillColor(E3DCOLOR(0x0))
    setColor(E3DCOLOR(0xFF000000))
    drawStrAnchored(float2(0.0), str, AnchorHorz.Center, AnchorVert.Center)
    setColor(props.lineColor)
    popAxes()

  def drawCoursePointer()
    setColor(COLOR_GREEN)
    let angle = compassAngle(props.courseSet)
    var sina, cosa : float
    sincos(angle, sina, cosa)

    let tipR   =  0.40
    let tailR  = -0.34
    let perpX  = -sina
    let perpY  =  cosa

    drawLine(float2(tailR * cosa, tailR * sina),
             float2(tipR  * cosa, tipR  * sina))

    var head : array<float2>
    push(head, float2(tipR                      * cosa,
                      tipR                      * sina))
    push(head, float2((tipR - ARROW_HEAD_LEN)   * cosa + perpX * ARROW_HEAD_W,
                      (tipR - ARROW_HEAD_LEN)   * sina + perpY * ARROW_HEAD_W))
    push(head, float2((tipR - ARROW_HEAD_LEN)   * cosa - perpX * ARROW_HEAD_W,
                      (tipR - ARROW_HEAD_LEN)   * sina - perpY * ARROW_HEAD_W))
    drawFilledPoly(head)

    drawLine(float2(tailR * cosa + perpX * ARROW_HEAD_W,
                    tailR * sina + perpY * ARROW_HEAD_W),
             float2(tailR * cosa - perpX * ARROW_HEAD_W,
                    tailR * sina - perpY * ARROW_HEAD_W))
    setColor(props.lineColor)

  def drawCDI()
    let angle = compassAngle(props.courseSet)
    var sina, cosa : float
    sincos(angle, sina, cosa)

    let perpX = -sina
    let perpY =  cosa

    let devOffset = clamp(props.deviation, -1.0, 1.0) * float(CDI_DOTS) * CDI_DOT_STEP
    let cx = devOffset * perpX
    let cy = devOffset * perpY

    drawLine(float2(cx + cosa * CDI_HALF_LEN, cy + sina * CDI_HALF_LEN),
             float2(cx - cosa * CDI_HALF_LEN, cy - sina * CDI_HALF_LEN))

    for j in 0 .. CDI_DOTS * 2 + 1
      let d = j - CDI_DOTS
      if d == 0
        continue
      let dotOffset = float(d) * CDI_DOT_STEP
      drawDot(float2(dotOffset * perpX, dotOffset * perpY))

  def drawAircraftSymbol()
    pushLocalAxes(float2(0.0), float2(0.065))
    drawLine(float2(0.0,  -1.0), float2(0.0,   0.55))
    drawLine(float2(-0.85,  0.0), float2(0.85,  0.0))
    drawLine(float2(-0.34,  0.55), float2(0.34,  0.55))
    drawCircle(float2(0.0), 0.18)
    popAxes()

  def drawHeadingBug()
    let angle = compassAngle(props.headingBug)
    var sina, cosa : float
    sincos(angle, sina, cosa)

    let perpX  = -sina
    let perpY  =  cosa
    let outerR = RING_R
    let innerR = ROSE_OUTER_R - 0.01
    let hw     = 0.022

    drawLine(float2(outerR * cosa + perpX * hw, outerR * sina + perpY * hw),
             float2(outerR * cosa - perpX * hw, outerR * sina - perpY * hw))
    drawLine(float2(outerR * cosa + perpX * hw, outerR * sina + perpY * hw),
             float2(innerR * cosa + perpX * hw, innerR * sina + perpY * hw))
    drawLine(float2(outerR * cosa - perpX * hw, outerR * sina - perpY * hw),
             float2(innerR * cosa - perpX * hw, innerR * sina - perpY * hw))

  def drawLabels()
    setColor(COLOR_GREEN)
    drawStrAnchored(float2(-0.42, 0.42), "GS KT",
                    AnchorHorz.Left, AnchorVert.Bottom)
    drawStrAnchored(float2(-0.42, 0.49), "{gsKnots}",
                    AnchorHorz.Left, AnchorVert.Bottom)

    let distStr = fmt(":.1f", props.distance)
    drawStrAnchored(float2(0.45, -0.42), "DST NM",
                    AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(0.45, -0.36), distStr,
                    AnchorHorz.Right, AnchorVert.Top)

    setColor(props.lineColor)
    let crsStr = fmt(":03d", roundi(props.courseSet) % 360)
    drawStrAnchored(float2(0.38, 0.49), "{crsStr}°",
                    AnchorHorz.Right, AnchorVert.Bottom)

    setColor(COLOR_GREEN)
    drawStrAnchored(float2(0.0, 0.10),
                    navSourceToLabel(props.navSource),
                    AnchorHorz.Center, AnchorVert.Center)

    if props.toFrom != 0
      setColor(props.lineColor)
      let tfLabel = props.toFrom > 0 ? "TO" : "FROM"
      drawStrAnchored(float2(0.0, 0.20), tfLabel,
                      AnchorHorz.Center, AnchorVert.Center)

  def drawEfiLabel()
    pushLocalAxes(float2(0.90, 0.30), float2(0.034, 0.115))
    setFillColor(E3DCOLOR(0xFFFFFFFF))
    drawBox(float2(-1.0), float2(1.0))
    setColor(E3DCOLOR(0xFF000000))
    drawStrAnchored(float2(0.0, -0.63), "E", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0,  0.0),  "F", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0,  0.63), "I", AnchorHorz.Center, AnchorVert.Center)
    setColor(props.lineColor)
    popAxes()

  def draw()
    return if !isValid

    setFullCanvasViewport()

    drawOuterRing()
    drawCompassRose()
    drawHeadingBug()
    drawCoursePointer()
    drawCDI()
    drawAircraftSymbol()
    drawHeadingBox()
    drawLabels()
    drawEfiLabel()

    restoreViewport()

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; props : HsiProps&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var hsi_props : HsiProps&)
  hsi_props.lineColor   = props.getColor("lineColor",   E3DCOLOR(0xFF00FF00))
  hsi_props.fontId      = props.getInt("fontId",        0)
  hsi_props.fontSize    = props.getInt("fontSize",      14)
  hsi_props.lineWidth   = props.getFloat("lineWidth",   1.5)
  hsi_props.courseSet   = props.getFloat("courseSet",   0.0)
  hsi_props.deviation   = props.getFloat("deviation",   0.0)
  hsi_props.groundSpeed = props.getInt("groundSpeed",   0)
  hsi_props.distance    = props.getFloat("distance",    0.0)
  hsi_props.toFrom      = props.getInt("toFrom",        1)
  hsi_props.headingBug  = props.getFloat("headingBug",  0.0)
  hsi_props.navSource   = props.getInt("navSource",     int(NavSource.LOC1))
