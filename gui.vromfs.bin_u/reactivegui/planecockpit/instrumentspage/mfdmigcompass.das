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
  fontSize : int = 16


let COL_BLACK      = E3DCOLOR(uint4(0, 0, 0, 255))
let COL_WHITE      = E3DCOLOR(uint4(255, 255, 255, 255))
let COL_CYAN       = E3DCOLOR(uint4(102, 217, 255, 255))
let COL_GREEN_HDG  = E3DCOLOR(uint4(10, 202, 10, 255))
let COL_YELLOW     = E3DCOLOR(uint4(255, 255, 0, 255))
let COL_GREEN      = E3DCOLOR(uint4(0, 200, 0, 255))
let COL_RED        = E3DCOLOR(uint4(220, 30, 30, 255))
let COL_PINK       = E3DCOLOR(uint4(220, 50, 220, 255))
let COL_LIGHT_BLUE = E3DCOLOR(uint4(0, 50, 200, 255))
let COL_PIL_BOX    = E3DCOLOR(uint4(0, 20, 120, 255))
let COL_NULL       = E3DCOLOR(0x0)

let MAP_CTR     = float2(0.0, 0.16)
let COMPASS_R   = 0.50
let MAP_R       = 0.38
let RANGE_M     = 30000.0
let RANGE_STEPS = 3
let ARC_SPAN    = 210.0 * degToRad
let BAR_H       = 0.06


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
  fontSize   : int              = 16
  mToCanvas  : float            = 1.0
  groundSpd  : float            = 0.0


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
    groundSpd = length(hero.vel.xz)

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
    setScale(canvasSize)


  def compassAngle(bearingDeg : float) : float
    var rel = (bearingDeg - headingDeg) * degToRad
    if rel > PI
      rel -= PI2
    elif rel < -PI
      rel += PI2
    return rel - PI_2


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


  def drawFrame()
    setColor(COL_LIGHT_BLUE)
    setFillColor(COL_LIGHT_BLUE)
    drawBox(float2(-0.5, -0.5), float2(0.5, -0.5 + BAR_H))
    drawBox(float2(-0.5, 0.5 - BAR_H), float2(0.5, 0.5))
    setFillColor(COL_NULL)


  def drawTopBar()
    setFontSize(13)
    let lblY = -0.5 + BAR_H - 0.015
    let step = 1.0 / 6.0
    let pilX = -0.5 + step * 0.9
    let pilSz = getStringSize("ПИЛ") * 0.5 + float2(0.010, 0.006)
    pushLocalAxes(float2(pilX, lblY), pilSz)
    setFillColor(COL_PIL_BOX)
    setColor(COL_PIL_BOX)
    drawBox(float2(-1.0), float2(1.0))
    setColor(COL_WHITE)
    setFillColor(COL_NULL)
    drawStrAnchored(float2(0.0), "ПИЛ", AnchorHorz.Center, AnchorVert.Center)
    popAxes()
    setColor(COL_WHITE)
    drawStrAnchored(float2(-0.5 + step * 1.6, lblY), "ТО",   AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.5 + step * 2.3, lblY), "РЭП",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.5 + step * 3.0, lblY), "ОПС",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.5 + step * 3.7, lblY), "СИСТ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.5 + step * 4.3, lblY), "ИЛС",  AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    setFillColor(COL_NULL)


  def drawBottomBar()
    setFontSize(13)
    let lblY = 0.5 - BAR_H + 0.015
    setColor(COL_RED)
    drawStrAnchored(float2(-0.38, lblY), "SWAP", AnchorHorz.Center, AnchorVert.Center)
    setColor(COL_WHITE)
    drawStrAnchored(float2(-0.10, lblY), "TSD2", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.14, lblY), "DCLT", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.38, lblY), "TSD3", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  def drawRangeCircles()
    setColor(COL_CYAN)
    setLineWidth(1.0)
    setFillColor(COL_NULL)
    let stepM = RANGE_M / float(RANGE_STEPS)
    setFontSize(fontSize - 2)
    for i in range(1, RANGE_STEPS + 1)
      let r = stepM * float(i) * mToCanvas
      drawCircle(MAP_CTR, r)
      let km = roundi(stepM * float(i) * 0.001)
      drawStrAnchored(MAP_CTR + float2(r - 0.03, 0.015), "{km}", AnchorHorz.Center, AnchorVert.Top)
    setFontSize(fontSize)
    setLineWidth(1.5)
    setColor(COL_WHITE)


  def drawCrosshair()
    setColor(COL_WHITE)
    setLineWidth(1.0)
    let clipR = MAP_R
    drawLine(MAP_CTR + float2(-clipR, 0.0), MAP_CTR + float2(clipR, 0.0))
    drawLine(MAP_CTR + float2(0.0, -clipR), MAP_CTR + float2(0.0, clipR))
    setLineWidth(1.5)


  def drawOwnShip()
    setColor(COL_PINK)
    setFillColor(COL_PINK)
    drawCircle(MAP_CTR, 0.012)
    setFillColor(COL_NULL)
    setColor(COL_WHITE)


  def drawCompassArc()
    setColor(COL_WHITE)
    setLineWidth(1.0)

    let halfSpan = ARC_SPAN * 0.5
    let arcStart = -PI_2 - halfSpan
    let arcEnd = -PI_2 + halfSpan
    let tickLen = 0.021

    for i in range(36)
      let tickDeg = float(i) * 10.0
      let angle = compassAngle(tickDeg)

      if angle < arcStart || angle > arcEnd
        continue

      let is30 = (i % 3) == 0

      var sinA, cosA : float
      sincos(angle, sinA, cosA)

      let outerR = COMPASS_R + tickLen
      drawLine(
        MAP_CTR + float2(COMPASS_R * cosA, COMPASS_R * sinA),
        MAP_CTR + float2(outerR * cosA, outerR * sinA))

      if is30
        let diff = norm_ang(angle + PI_2)
        let distFromTop = diff > PI ? PI2 - diff : diff
        if distFromTop < 8.0 * degToRad
          continue
        let markDeg = roundi(tickDeg) % 360
        let lbl = "{markDeg / 10}"
        let labelR = outerR + 0.022
        setFontSize(fontSize)
        drawStrAnchored(
          MAP_CTR + float2(labelR * cosA, labelR * sinA),
          lbl, AnchorHorz.Center, AnchorVert.Center)

    drawSector(MAP_CTR, float2(COMPASS_R), float2(arcStart, arcEnd))
    setLineWidth(1.5)


  def drawHeadingBox()
    let hdg = roundi(headingDeg) % 360
    let hdgStr = fmt(":03d", hdg)
    let boxY = MAP_CTR.y - COMPASS_R - 0.045
    let boxHW = 0.050
    let boxHH = 0.020

    setFillColor(COL_NULL)
    setColor(COL_GREEN_HDG)
    drawBox(float2(-boxHW, boxY - boxHH), float2(boxHW, boxY + boxHH))
    setFontSize(fontSize + 2)
    drawStrAnchored(float2(0.0, boxY), hdgStr, AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    setColor(COL_WHITE)

    let triY = MAP_CTR.y - COMPASS_R + 0.002
    let triH = 0.022
    let triW = 0.010
    setFillColor(COL_WHITE)
    drawFilledPoly(to_array_move(fixed_array(
      float2(0.0, triY),
      float2(-triW, triY - triH),
      float2(triW, triY - triH))))
    setFillColor(COL_NULL)


  def drawCourseLine()
    if !toiData.isActive
      return

    let tgtScreen = worldToScreen(toiData.pos)
    let dir = tgtScreen - MAP_CTR
    let dist = length(dir)
    if dist < 0.001
      return

    setColor(COL_CYAN)
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
    var sinA, cosA : float
    sincos(angle, sinA, cosA)
    let outerR = COMPASS_R + 0.002
    let innerR = COMPASS_R - 0.012
    let perpX = -sinA
    let perpY = cosA
    let hw = 0.006
    drawFilledPoly(to_array_move(fixed_array(
      MAP_CTR + float2(innerR * cosA, innerR * sinA),
      MAP_CTR + float2(outerR * cosA + perpX * hw, outerR * sinA + perpY * hw),
      MAP_CTR + float2(outerR * cosA - perpX * hw, outerR * sinA - perpY * hw))))
    setFillColor(COL_NULL)
    setColor(COL_WHITE)


  def drawTargets()
    let clipR = COMPASS_R - 0.01
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
        drawClosedPolyLine(to_array_move(fixed_array(
          uScreen + float2(-unitSize, -unitSize),
          uScreen + float2(unitSize, -unitSize),
          uScreen + float2(unitSize, unitSize),
          uScreen + float2(-unitSize, unitSize))))

    if toiData.isActive
      setColor(COL_YELLOW)
      setFillColor(COL_YELLOW)
      let tgtScreen = worldToScreen(toiData.pos)
      let dirT = tgtScreen - MAP_CTR
      let distT = length(dirT)
      if distT > 0.001
        var tpos = tgtScreen
        if distT > clipR
          tpos = MAP_CTR + dirT * (clipR / distT)
        let sz = 0.014
        drawFilledPoly(to_array_move(fixed_array(
          tpos + float2(-sz, -sz),
          tpos + float2(sz, -sz),
          tpos + float2(sz, sz),
          tpos + float2(-sz, sz))))
        setFillColor(COL_NULL)
        let distKm = toiData.distance * 0.001
        drawStrAnchored(tpos + float2(0.02, -0.01),
          fmt(":.1f", distKm), AnchorHorz.Left, AnchorVert.Center)

    setFillColor(COL_NULL)
    setColor(COL_WHITE)


  def drawInfoFields()
    setColor(COL_WHITE)
    setFontSize(fontSize - 2)
    let gsKph = groundSpd * MPS_TO_KPH
    let lx = -0.38
    let ly = -0.38
    drawStrAnchored(float2(lx, ly), "G/S", AnchorHorz.Left, AnchorVert.Center)
    let boxX = lx + 0.055
    let boxHW = 0.045
    let boxHH = 0.014
    setFillColor(COL_NULL)
    drawBox(float2(boxX, ly - boxHH), float2(boxX + boxHW * 2.0, ly + boxHH))
    drawStrAnchored(float2(boxX + boxHW, ly), "{roundi(gsKph)}", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  def drawCorField()
    setColor(COL_WHITE)
    setFontSize(fontSize - 2)
    let hdg = roundi(headingDeg) % 360
    let cy = 0.38
    drawStrAnchored(float2(0.0, cy), "COR", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0, cy + 0.025), fmt(":03d", hdg), AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  def draw()
    return if !isValid
    setFullCanvasViewport()

    drawBackground()
    drawFrame()
    drawTopBar()
    drawBottomBar()

    let vpL = -0.5
    let vpR = 0.5
    let vpT = -0.5 + BAR_H
    let vpB = 0.5 - BAR_H
    setViewport(float2(vpL, vpT), float2(vpR, vpB))

    drawRangeCircles()
    drawCrosshair()
    drawCourseLine()
    drawTargets()
    drawCompassArc()
    drawHeadingBox()
    drawOwnShip()
    drawInfoFields()
    drawCorField()

    restoreViewport()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; var props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId   = getInt(props, "fontId", 0)
  propStorage.fontSize = getInt(props, "fontSize", 16)
