require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require math
require Sensors
require strings
require Unit


struct PropStorage
  fontId   : int = 0
  fontSize : int = 18


let COL_BLACK  = E3DCOLOR(uint4(0, 0, 0, 255))
let COL_WHITE  = E3DCOLOR(uint4(255, 255, 255, 255))
let COL_CYAN   = E3DCOLOR(uint4(102, 217, 255, 255))
let COL_DIM    = E3DCOLOR(uint4(140, 140, 140, 255))
let COL_YELLOW = E3DCOLOR(uint4(255, 255, 0, 255))
let COL_NULL   = E3DCOLOR(0x0)

let MAP_CTR     = float2(0.0, 0.33)
let COMPASS_R   = 0.57
let MAP_R       = 0.304
let RANGE_M     = 5000.0
let RANGE_STEPS = 1


struct ToiData
  isActive : bool   = false
  pos      : float3 = float3(0.0)
  distance : float  = 0.0


class Component : Canvas
  isValid    : bool             = false
  hero       : Unit?            = null
  fmw        : FlightModelWrap? = null
  appRef     : AcesApp?         = null
  toiData    : ToiData          = ToiData()
  headingRad : float            = 0.0
  headingDeg : float            = 0.0
  forward    : float2           = float2(0.0, 1.0)
  fontSize   : int              = 18
  mToCanvas  : float            = 1.0


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
                rstate : RenderState& const; var props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    if hero == null
      return
    fmw = hero.as_fmw()
    if fmw == null
      return
    appRef = get_app()
    if appRef == null
      return

    isValid = true
    fontSize = props.fontSize

    let fwd = hero.unitTm[0]
    headingRad = atan2(fwd.x, fwd.z)
    headingDeg = norm_ang(headingRad) * radToDeg
    forward = fast_normalize(hero.unitTm[0].xz)
    mToCanvas = MAP_R / RANGE_M

    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        toiData.isActive = true
        toiData.pos = target.from + target.dirNorm * target.distance
        toiData.distance = target.distance

    setColor(COL_WHITE)
    setLineWidth(1.5)
    setFont(props.fontId)
    setFontSize(fontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))


  def compassAngle(bearingDeg : float) : float
    return (bearingDeg - headingDeg) * degToRad - PI_2


  def worldToScreen(worldPos : float3) : float2
    let dir = worldPos.xz - hero.pos.xz
    let leftDot = dot(dir, float2(-forward.y, forward.x))
    let fwdDot = dot(dir, forward)
    return MAP_CTR + float2(-leftDot, -fwdDot) * mToCanvas


  def drawBackground()
    setColor(COL_BLACK)
    setFillColor(COL_BLACK)
    drawBox(float2(-0.5), float2(0.5))
    setFillColor(COL_NULL)
    setColor(COL_WHITE)


  def drawTopBar()
    let y = -0.47
    let x0 = -0.42
    let dx = 0.14

    setColor(COL_DIM)
    drawStrAnchored(float2(x0, y), "ПЛТ", AnchorHorz.Center, AnchorVert.Center)

    setColor(COL_WHITE)
    let nvgX = x0 + dx
    let bw = 0.045
    let bh = 0.014
    setFillColor(COL_NULL)
    drawBox(float2(nvgX - bw, y - bh), float2(nvgX + bw, y + bh))
    drawStrAnchored(float2(nvgX, y), "НВГ", AnchorHorz.Center, AnchorVert.Center)

    setColor(COL_DIM)
    drawStrAnchored(float2(x0 + dx * 2.0, y), "ОВО", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x0 + dx * 3.0, y), "БКС", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x0 + dx * 4.0, y), "БКО", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x0 + dx * 5.0, y), "РЛС", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x0 + dx * 6.0, y), "ОПС", AnchorHorz.Center, AnchorVert.Center)

    setColor(COL_WHITE)


  def drawSystemBar()
    let y = -0.42
    setColor(COL_WHITE)
    drawStrAnchored(float2(0.34, y), "САУ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.44, y), "ПУТ", AnchorHorz.Center, AnchorVert.Center)


  def drawRangeCircles()
    setColor(COL_CYAN)
    setLineWidth(1.0)
    setFillColor(COL_NULL)

    let stepM = RANGE_M / float(RANGE_STEPS)
    for i in range(1, RANGE_STEPS + 1)
      let r = stepM * float(i) * mToCanvas
      drawCircle(MAP_CTR, r)

    setLineWidth(1.5)
    setColor(COL_WHITE)


  def drawCourseLine()
    if !toiData.isActive
      return

    let tgtScreen = worldToScreen(toiData.pos)
    let dir = tgtScreen - MAP_CTR
    let dist = length(dir)
    if dist < 0.001
      return

    setColor(COL_WHITE)
    let clipR = COMPASS_R - 0.01
    var endPt = tgtScreen
    if dist > clipR
      endPt = MAP_CTR + dir * (clipR / dist)
    drawLine(MAP_CTR, endPt)

    let bearDir = toiData.pos.xz - hero.pos.xz
    let bearRad = atan2(bearDir.x, bearDir.y)
    let bearDeg = norm_ang(bearRad) * radToDeg
    setColor(COL_YELLOW)
    setFillColor(COL_YELLOW)
    let angle = compassAngle(bearDeg)
    var sina, cosa : float
    sincos(angle, sina, cosa)
    let outerR = COMPASS_R + 0.002
    let innerR = COMPASS_R - 0.012
    let perpX = -sina
    let perpY = cosa
    let hw = 0.006
    drawFilledPoly(to_array_move(fixed_array(
      MAP_CTR + float2(innerR * cosa, innerR * sina),
      MAP_CTR + float2(outerR * cosa + perpX * hw, outerR * sina + perpY * hw),
      MAP_CTR + float2(outerR * cosa - perpX * hw, outerR * sina - perpY * hw))))
    setFillColor(COL_NULL)
    setColor(COL_WHITE)


  def drawTargetMark(pos : float2; size : float; selected : bool)
    if selected
      setFillColor(COL_YELLOW)
      drawFilledPoly(to_array_move(fixed_array(
        pos + float2(-size, -size),
        pos + float2(size, -size),
        pos + float2(size, size),
        pos + float2(-size, size))))
      setFillColor(COL_NULL)
    else
      drawClosedPolyLine(to_array_move(fixed_array(
        pos + float2(-size, -size),
        pos + float2(size, -size),
        pos + float2(size, size),
        pos + float2(-size, size))))


  def drawTargets()
    let clipR = COMPASS_R - 0.01
    let COL_GREEN = E3DCOLOR(uint4(0, 200, 0, 255))
    let unitSize = 0.008
    let unitClip = clipR - unitSize

    get_all_units() <| $(units : array<Unit?> const#)
      for u in units
        if u == null || u.isDelayed || u == hero
          continue
        if u.isFarAway
          continue
        if u.army != hero.army
          continue
        let uScreen = worldToScreen(u.pos)
        let dirU = uScreen - MAP_CTR
        let distU = length(dirU)
        if distU > unitClip
          continue
        setColor(COL_GREEN)
        drawTargetMark(uScreen, unitSize, false)

    if toiData.isActive
      setColor(COL_YELLOW)
      let tgtScreen = worldToScreen(toiData.pos)
      let dirT = tgtScreen - MAP_CTR
      let distT = length(dirT)
      if distT > 0.001
        var tpos = tgtScreen
        if distT > clipR
          tpos = MAP_CTR + dirT * (clipR / distT)
        drawTargetMark(tpos, 0.014, true)
        let distKm = toiData.distance * 0.001
        drawStrAnchored(tpos + float2(0.02, -0.01),
          fmt(":.1f", distKm), AnchorHorz.Left, AnchorVert.Center)

    setColor(COL_WHITE)


  def drawCompassRose()
    setColor(COL_WHITE)
    setLineWidth(1.0)
    drawCircle(MAP_CTR, COMPASS_R)
    setLineWidth(1.5)

    for i in range(72)
      let tickDeg = float(i) * 5.0
      let isCardinal = (i % 18) == 0
      let is30 = (i % 6) == 0
      let is10 = (i % 2) == 0

      var sina, cosa : float
      sincos(compassAngle(tickDeg), sina, cosa)

      var innerR = COMPASS_R - 0.010
      if isCardinal
        innerR = COMPASS_R - 0.038
      elif is30
        innerR = COMPASS_R - 0.030
      elif is10
        innerR = COMPASS_R - 0.022

      drawLine(
        MAP_CTR + float2(innerR * cosa, innerR * sina),
        MAP_CTR + float2(COMPASS_R * cosa, COMPASS_R * sina))

      if is30
        let screenAngle = compassAngle(tickDeg)
        let diff = norm_ang(screenAngle + PI_2)
        let distFromTop = diff > PI ? PI2 - diff : diff
        if distFromTop < 10.0 * degToRad
          continue
        let markDeg = roundi(tickDeg) % 360
        var lbl = ""
        if markDeg == 0
          lbl = "С"
        elif markDeg == 90
          lbl = "В"
        elif markDeg == 180
          lbl = "Ю"
        elif markDeg == 270
          lbl = "З"
        else
          lbl = "{markDeg / 10}"
        let labelR = innerR - 0.026
        drawStrAnchored(
          MAP_CTR + float2(labelR * cosa, labelR * sina),
          lbl, AnchorHorz.Center, AnchorVert.Center)


  def drawHeadingBox()
    let hdg = roundi(headingDeg) % 360
    let hdgStr = fmt(":03d", hdg)
    let boxY = MAP_CTR.y - COMPASS_R - 0.080
    let boxHW = 0.07
    let boxHH = 0.028

    setFillColor(COL_NULL)
    setColor(COL_CYAN)
    drawBox(float2(-boxHW, boxY - boxHH), float2(boxHW, boxY + boxHH))
    setFontSize(fontSize + 2)
    drawStrAnchored(float2(0.0, boxY), hdgStr, AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    setColor(COL_WHITE)

    let triY = MAP_CTR.y - COMPASS_R - 0.01
    let triH = 0.035
    let triW = 0.016
    setFillColor(COL_WHITE)
    drawFilledPoly(to_array_move(fixed_array(
      float2(0.0, triY),
      float2(-triW, triY - triH),
      float2(triW, triY - triH))))
    setFillColor(COL_NULL)


  def drawAircraftSymbol()
    setColor(COL_WHITE)
    setLineWidth(2.0)
    let c = MAP_CTR
    drawLine(c + float2(0.0, -0.030), c + float2(0.0, 0.030))
    drawLine(c + float2(-0.025, -0.01), c + float2(0.025, -0.01))
    drawLine(c + float2(-0.015, 0.018), c + float2(0.015, 0.018))
    setLineWidth(1.5)


  def drawCoordinates()
    setColor(COL_WHITE)
    setFontSize(fontSize - 2)

    let latlon = get_latitude_longitude()
    let baseLat = latlon.x
    let baseLon = latlon.y
    let lat = baseLat + hero.pos.z / 111320.0
    let cosLat = cos(baseLat * degToRad)
    let lon = baseLon + hero.pos.x / (111320.0 * cosLat)

    let latAbs = abs(lat)
    let latDeg = floori(latAbs)
    let latMinF = (latAbs - float(latDeg)) * 60.0
    let latMin = floori(latMinF)
    let latSec = roundi((latMinF - float(latMin)) * 60.0)
    let latH = lat >= 0.0 ? "С" : "Ю"

    let lonAbs = abs(lon)
    let lonDeg = floori(lonAbs)
    let lonMinF = (lonAbs - float(lonDeg)) * 60.0
    let lonMin = floori(lonMinF)
    let lonSec = roundi((lonMinF - float(lonMin)) * 60.0)
    let lonH = lon >= 0.0 ? "В" : "З"

    let rx = 0.50
    let ry = 0.25
    drawStrAnchored(float2(rx, ry),
      "{latH} {latDeg}°{fmt(":02d", latMin)}'{fmt(":02d", latSec)}",
      AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(rx, ry + 0.04),
      "{lonH} {lonDeg}°{fmt(":02d", lonMin)}'{fmt(":02d", lonSec)}",
      AnchorHorz.Right, AnchorVert.Center)

    setFontSize(fontSize)


  def drawFrame()
    setColor(COL_WHITE)
    setLineWidth(1.5)
    let top = -0.445
    let bot = 0.445
    let lft = -0.6
    let rgt = 0.6
    drawLine(float2(lft, top), float2(rgt, top))
    drawLine(float2(rgt, top), float2(rgt, bot))
    drawLine(float2(rgt, bot), float2(lft, bot))
    drawLine(float2(lft, bot), float2(lft, top))

    let mrshX = lft - 0.025
    let mrshY = -0.3
    let mw = 0.016
    let mh = 0.065
    setFillColor(COL_NULL)
    drawBox(float2(mrshX - mw, mrshY - mh), float2(mrshX + mw, mrshY + mh))
    drawStrVert(float2(mrshX, mrshY - mh + 0.014), "МРШ", AnchorHorz.Center, AnchorVert.Top)

    let arkX = rgt + 0.025
    drawStrVert(float2(arkX, mrshY - mh + 0.014), "АРК", AnchorHorz.Center, AnchorVert.Top)


  def drawBottomBar()
    setColor(COL_WHITE)
    let y = 0.47
    let dx = 0.14
    let x0 = -0.28

    drawStrAnchored(float2(x0, y), "ШПП", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x0 + dx, y), "ЦРлС", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x0 + dx * 2.0, y), "ОПБ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x0 + dx * 3.0, y), "ОРК", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x0 + dx * 4.0, y), "0.0", AnchorHorz.Center, AnchorVert.Center)


  def draw()
    return if !isValid
    setFullCanvasViewport()

    drawBackground()
    drawFrame()
    setViewport(float2(-0.6, -0.445), float2(0.6, 0.445))
    drawRangeCircles()
    drawCourseLine()
    drawTargets()
    drawCompassRose()
    drawHeadingBox()
    drawAircraftSymbol()
    drawCoordinates()
    restoreViewport()
    drawTopBar()
    drawSystemBar()
    drawBottomBar()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; var props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId   = getInt(props, "fontId", 0)
  propStorage.fontSize = getInt(props, "fontSize", 18)
