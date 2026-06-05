require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require GuidanceLock
require HeroManager
require hud
require math
require Plane
require RadarHud
require Sensors
require strings
require Unit


struct PropStorage
  fontId : int = 0
  fontSize : int = 16


let
  COLOR_BLACK      = E3DCOLOR(uint4(0, 0, 0, 255))
  COLOR_GRAY       = E3DCOLOR(uint4(128, 128, 128, 255))
  COLOR_WHITE      = E3DCOLOR(uint4(255, 255, 255, 255))
  COLOR_GREEN      = E3DCOLOR(uint4(0, 200, 0, 255))
  COLOR_GREEN_BRIGHT = E3DCOLOR(uint4(0, 255, 0, 255))
  COLOR_YELLOW     = E3DCOLOR(uint4(255, 220, 0, 255))
  COLOR_RED        = E3DCOLOR(uint4(220, 30, 30, 255))
  COLOR_NULL       = E3DCOLOR(0x0)

  VIEW_LT          = float2(-0.35, -0.40)
  VIEW_RB          = float2(0.35, 0.36)


class Component : Canvas
  isValid      : bool             = false
  hero         : Unit?            = null
  fmw          : FlightModelWrap? = null
  app          : AcesApp?         = null
  headingRad   : float            = 0.0
  pitchDeg     : float            = 0.0
  rollDeg      : float            = 0.0
  iasMps       : float            = 0.0
  tasKph       : float            = 0.0
  altM         : float            = 0.0
  altGeomM     : float            = 0.0
  vyMps        : float            = 0.0
  nyG          : float            = 1.0
  sideSlipDeg  : float            = 0.0
  distToTargetM : float           = 0.0
  fontSize     : int              = 16


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
                rstate : RenderState& const; var props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    if hero == null
      return
    fmw = hero.as_fmw()
    if fmw == null
      return
    app = get_app()
    if app == null
      return
    isValid = true
    fontSize = props.fontSize

    let fwd = hero.unitTm[0]
    headingRad = atan2(fwd.x, fwd.z)
    pitchDeg   = fmw.tangage
    rollDeg    = fmw.roll
    iasMps     = fmw.ias
    assume fm = *fmw.fm
    tasKph     = fm.speed * MPS_TO_KPH
    altM       = hero.unitTm[3].y - app.currentScene.waterLevel
    altGeomM   = fm.input.currentAlt
    vyMps      = hero.vel.y
    nyG        = float(fm.localAccel.y) / 9.81
    sideSlipDeg = fm.aos

    var targetPos = float3(0.0)
    if hud::get_target_point_on_ground(targetPos)
      distToTargetM = length(targetPos - hero.pos)

    setColor(COLOR_GREEN)
    setLineWidth(1.5)
    setFont(props.fontId)
    setFontSize(fontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.x * 1.25, canvasSize.y))


  def drawBackground()
    let rx = 0.35
    let ry = 0.44
    setColor(COLOR_BLACK)
    setFillColor(COLOR_BLACK)
    drawBox(float2(-0.5, -0.5), float2(0.5, -ry))
    drawBox(float2(-0.5, ry), float2(0.5, 0.5))
    drawBox(float2(-0.5, -ry), float2(-rx, ry))
    drawBox(float2(rx, -ry), float2(0.5, ry))
    setFillColor(COLOR_NULL)
    setColor(COLOR_GREEN)


  def drawSpeeds()
    setColor(COLOR_YELLOW)
    let sf = int(float(fontSize) * 0.8)
    setFontSize(sf)
    let lx = VIEW_LT.x + 0.055
    let ly = VIEW_LT.y - 0.02
    let iasKph = iasMps * MPS_TO_KPH
    drawStrAnchored(float2(lx, ly), fmt(":d", floori(iasKph)), AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(lx, ly + 0.025), fmt(":d", floori(tasKph)), AnchorHorz.Left, AnchorVert.Top)
    setFontSize(fontSize)
    setColor(COLOR_GREEN)


  def drawAltitudes()
    let sf = int(float(fontSize) * 0.8)
    setFontSize(sf)
    let rx = VIEW_RB.x - 0.055
    let ry = VIEW_LT.y - 0.02
    setColor(COLOR_RED)
    drawStrAnchored(float2(rx, ry), fmt(":d", floori(altM)), AnchorHorz.Right, AnchorVert.Top)
    setColor(COLOR_RED)
    drawStrAnchored(float2(rx, ry + 0.025), fmt(":d", floori(altGeomM)), AnchorHorz.Right, AnchorVert.Top)
    setFontSize(fontSize)
    setColor(COLOR_GREEN)


  def drawRangeScale()
    let scaleX = VIEW_LT.x + 0.065
    let midY = (VIEW_LT.y + VIEW_RB.y) * 0.5
    let halfH = (VIEW_RB.y - VIEW_LT.y) * 0.25
    let scaleTop = midY - halfH
    let scaleBot = midY + halfH
    let scaleH = scaleBot - scaleTop
    let tickW = 0.015
    let sf = int(float(fontSize) * 0.75)
    let maxRangeKm = 5.0

    setColor(COLOR_GREEN_BRIGHT)
    setLineWidth(2.5)
    drawLine(float2(scaleX, scaleTop), float2(scaleX, scaleBot))

    setFontSize(sf)
    setLineWidth(1.5)
    for i in range(0, 6)
      let val = float(i)
      let y = scaleBot - (val / maxRangeKm) * scaleH
      drawLine(float2(scaleX - tickW, y), float2(scaleX, y))
      drawStrAnchored(float2(scaleX - tickW - 0.005, y), fmt(":d", i), AnchorHorz.Right, AnchorVert.Center)

    let bombLock = get_bomb_guidance_lock_state()
    let hasTarget = bombLock == GuidanceLockState.RESULT_TRACKING && distToTargetM > 0.0
    let curDistKm = distToTargetM * 0.001

    if hasTarget && curDistKm <= maxRangeKm
      let markerY = scaleBot - (curDistKm / maxRangeKm) * scaleH
      setLineWidth(3.0)
      setColor(COLOR_GREEN_BRIGHT)
      setFillColor(COLOR_GREEN_BRIGHT)
      drawFilledPoly(to_array_move(fixed_array(
        float2(scaleX, markerY),
        float2(scaleX + 0.018, markerY - 0.007),
        float2(scaleX + 0.018, markerY + 0.007))))
      setFillColor(COLOR_NULL)
      drawLine(float2(scaleX + 0.018, markerY), float2(scaleX + 0.035, markerY))

    if get_agm_launch_zone_visible()
      let agmDistM = float2(get_agm_launch_zone_dist_min(), get_agm_launch_zone_dist_max())
      let agmDistKm = agmDistM * 0.001

      setLineWidth(2.0)
      if agmDistKm.y > 0.0 && agmDistKm.y <= maxRangeKm
        let maxY = scaleBot - (agmDistKm.y / maxRangeKm) * scaleH
        drawLine(float2(scaleX - 0.01, maxY), float2(scaleX + 0.01, maxY))
        drawLine(float2(scaleX - 0.01, maxY), float2(scaleX - 0.01, maxY + 0.01))
        drawLine(float2(scaleX + 0.01, maxY), float2(scaleX + 0.01, maxY + 0.01))

      if agmDistKm.x > 0.0 && agmDistKm.x <= maxRangeKm
        let minY = scaleBot - (agmDistKm.x / maxRangeKm) * scaleH
        drawLine(float2(scaleX - 0.01, minY), float2(scaleX + 0.01, minY))
        drawLine(float2(scaleX - 0.01, minY), float2(scaleX - 0.01, minY - 0.01))
        drawLine(float2(scaleX + 0.01, minY), float2(scaleX + 0.01, minY - 0.01))

    setLineWidth(1.5)
    setFontSize(fontSize)
    setColor(COLOR_GREEN)


  def drawAircraftSymbol()
    let cx = 0.0
    let cy = -0.038
    setColor(COLOR_GRAY)
    setLineWidth(2.5)
    let arm = abs(VIEW_LT.x + 0.065)
    drawLine(float2(cx - arm, cy), float2(cx + arm, cy))
    drawLine(float2(cx, cy - arm), float2(cx, cy + arm))

    // Aircraft symbol at top of vertical line, rotated by roll
    let topY = cy - arm
    let wingW = 0.04
    let noseLen = 0.03
    let symY = topY - 0.030
    let pivot = float2(cx, symY)

    setRotation(pivot, rollDeg * degToRad)
    setColor(COLOR_WHITE)
    setLineWidth(3.0)
    drawLine(float2(cx, symY - noseLen), float2(cx, symY))
    drawLine(float2(cx - wingW, symY), float2(cx + wingW, symY))
    resetViewTm()

    // Fixed horizontal side lines (x4 size from compass)
    let halfGap = wingW * 1.2
    let lineLen = halfGap * 2.0
    setColor(COLOR_WHITE)
    setLineWidth(3.0)
    drawLine(float2(cx - wingW - halfGap - lineLen, symY), float2(cx - wingW - halfGap, symY))
    drawLine(float2(cx + wingW + halfGap, symY), float2(cx + wingW + halfGap + lineLen, symY))
    setLineWidth(1.5)
    setColor(COLOR_GREEN)

  def drawSideSlipIndicator()
    let cx = 0.0
    let indY = VIEW_RB.y - 0.02
    let hw = 0.24
    setColor(COLOR_GREEN)
    setLineWidth(1.5)
    drawLine(float2(cx - hw, indY), float2(cx + hw, indY))
    for i in range(-3, 4)
      let x = cx + float(i) * hw / 3.0
      let tl = (i == 0) ? 0.010 : 0.006
      drawLine(float2(x, indY), float2(x, indY - tl))
    let slipX = cx + clamp(sideSlipDeg / 8.0, -1.0, 1.0) * hw
    setFillColor(COLOR_GREEN)
    drawFilledPoly(to_array_move(fixed_array(
      float2(slipX, indY),
      float2(slipX - 0.006, indY + 0.010),
      float2(slipX + 0.006, indY + 0.010))))
    setFillColor(COLOR_NULL)


  def drawDangerousAlt()
    let dangerAlt = 100.0
    if altGeomM < dangerAlt * 1.5
      setColor(COLOR_RED)
      let sf = int(float(fontSize) * 0.7)
      setFontSize(sf)
      drawStrAnchored(float2(VIEW_RB.x - 0.02, VIEW_RB.y - 0.03), "ОВ", AnchorHorz.Right, AnchorVert.Center)
      setFontSize(fontSize)
      setColor(COLOR_GREEN)


  def drawOsbLabels()
    let sf = int(float(fontSize) * 0.85)
    setFontSize(sf)
    setColor(COLOR_GREEN)
    let off = 0.04
    drawStrAnchored(float2(-0.24, -0.5 + off), "ПИЛ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.12, -0.5 + off), "НВГ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0, -0.5 + off), "ИТО", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.12, -0.5 + off), "КИСС", AnchorHorz.Center, AnchorVert.Center)
    let tvX = 0.24
    let tvY = -0.5 + off
    let tvHW = 0.02
    let tvHH = 0.012
    setFillColor(COLOR_GREEN)
    drawBox(float2(tvX - tvHW, tvY - tvHH), float2(tvX + tvHW, tvY + tvHH))
    setFillColor(COLOR_NULL)
    setColor(COLOR_BLACK)
    drawStrAnchored(float2(tvX, tvY), "ТВ", AnchorHorz.Center, AnchorVert.Center)
    setColor(COLOR_GREEN)
    drawStrAnchored(float2(-0.12, 0.475), "ПНО", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.12, 0.475), "ФИЛ-О", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)


  def drawTvGsnIndicator()
    let scaleX = VIEW_RB.x - 0.05
    let midY = (VIEW_LT.y + VIEW_RB.y) * 0.5
    let halfH = (VIEW_RB.y - VIEW_LT.y) * 0.25
    let scaleTop = midY - halfH
    let scaleBot = midY + halfH
    let scaleH = scaleBot - scaleTop
    let brkW = 0.012
    let maxAngle = 55.0

    setColor(COLOR_GREEN)
    setLineWidth(2.0)

    drawLine(float2(scaleX, scaleTop), float2(scaleX, scaleBot))
    drawLine(float2(scaleX, scaleTop), float2(scaleX + brkW, scaleTop))
    drawLine(float2(scaleX, scaleBot), float2(scaleX + brkW, scaleBot))

    if distToTargetM > 0.0
      var targetPos = float3(0.0)
      hud::get_target_point_on_ground(targetPos)
      if targetPos != float3(0.0)
        let localTarget = targetPos - hero.pos
        let dist2d = sqrt(localTarget.x * localTarget.x + localTarget.z * localTarget.z)
        let elevDeg = atan2(-localTarget.y, dist2d) * radToDeg
        let clampedAngle = clamp(elevDeg, 0.0, maxAngle)
        let rel = clampedAngle / maxAngle
        let ptrY = scaleTop + rel * scaleH
        setFillColor(COLOR_GREEN)
        drawFilledPoly(to_array_move(fixed_array(
          float2(scaleX, ptrY),
          float2(scaleX + 0.015, ptrY - 0.007),
          float2(scaleX + 0.015, ptrY + 0.007))))
        setFillColor(COLOR_NULL)

    setLineWidth(1.5)


  def drawLockFrame()
    let bombLock = get_bomb_guidance_lock_state()
    if bombLock != GuidanceLockState.RESULT_TRACKING
      return
    let cx = 0.0
    let cy = -0.038
    let hw = 0.06
    let hh = 0.06
    let corner = 0.02
    setColor(COLOR_GRAY)
    setLineWidth(2.0)
    // Top-left
    drawLine(float2(cx - hw, cy - hh), float2(cx - hw + corner, cy - hh))
    drawLine(float2(cx - hw, cy - hh), float2(cx - hw, cy - hh + corner))
    // Top-right
    drawLine(float2(cx + hw, cy - hh), float2(cx + hw - corner, cy - hh))
    drawLine(float2(cx + hw, cy - hh), float2(cx + hw, cy - hh + corner))
    // Bottom-left
    drawLine(float2(cx - hw, cy + hh), float2(cx - hw + corner, cy + hh))
    drawLine(float2(cx - hw, cy + hh), float2(cx - hw, cy + hh - corner))
    // Bottom-right
    drawLine(float2(cx + hw, cy + hh), float2(cx + hw - corner, cy + hh))
    drawLine(float2(cx + hw, cy + hh), float2(cx + hw, cy + hh - corner))
    // "ПР" label at 25% of lower vertical cross line
    let crossArm = abs(VIEW_LT.x + 0.065)
    let prY = cy + crossArm * 0.75
    setColor(COLOR_YELLOW)
    setFontSize(fontSize + 3)
    drawStrAnchored(float2(cx, prY), "П Р", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(fontSize)
    setLineWidth(1.5)
    setColor(COLOR_GREEN)


  def drawAltWarning()
    let iasKph = iasMps * MPS_TO_KPH
    if altGeomM >= 350.0 || iasKph <= 450.0
      return
    let cx = 0.0
    let crossCy = -0.038
    let crossArm = abs(VIEW_LT.x + 0.065)
    let crossBottom = crossCy + crossArm
    let cy = crossBottom + 0.038 + 0.015
    let sf = int(float(fontSize) * 0.8)
    setFontSize(sf)
    let hw = 0.06
    let hh = 0.015
    setColor(COLOR_YELLOW)
    setLineWidth(2.0)
    drawLine(float2(cx - hw, cy - hh), float2(cx + hw, cy - hh))
    drawLine(float2(cx + hw, cy - hh), float2(cx + hw, cy + hh))
    drawLine(float2(cx + hw, cy + hh), float2(cx - hw, cy + hh))
    drawLine(float2(cx - hw, cy + hh), float2(cx - hw, cy - hh))
    drawStrAnchored(float2(cx, cy), "ВЫСОТА", AnchorHorz.Center, AnchorVert.Center)
    setLineWidth(1.5)
    setFontSize(fontSize)
    setColor(COLOR_GREEN)


  def drawSpeedLimits()
    let spdMin = 500.0
    let spdMax = 850.0
    let spdRangeMin = 400.0
    let spdRangeMax = 950.0
    let scaleW = 0.096
    let lx = VIEW_LT.x + 0.1
    let barY = VIEW_LT.y - 0.0025
    let barH = 0.01
    let rx = lx + scaleW

    setColor(COLOR_GREEN)
    setLineWidth(1.5)

    // Horizontal bar
    drawLine(float2(lx, barY), float2(rx, barY))
    // Left vertical at 500 kph - downward
    let x500 = lx + ((spdMin - spdRangeMin) / (spdRangeMax - spdRangeMin)) * scaleW
    drawLine(float2(x500, barY), float2(x500, barY + barH))
    // Right vertical at 850 kph - downward
    let x850 = lx + ((spdMax - spdRangeMin) / (spdRangeMax - spdRangeMin)) * scaleW
    drawLine(float2(x850, barY), float2(x850, barY + barH))

    // Current TAS triangle above bar
    let rel = clamp((tasKph - spdRangeMin) / (spdRangeMax - spdRangeMin), 0.0, 1.0)
    let triX = lx + rel * scaleW
    let triY = barY - 0.002
    let triH = 0.010
    let triW = 0.006
    setFillColor(COLOR_GREEN)
    drawFilledPoly(to_array_move(fixed_array(
      float2(triX, triY),
      float2(triX - triW, triY - triH),
      float2(triX + triW, triY - triH))))
    setFillColor(COLOR_NULL)


  def drawBorder()
    let rx = 0.35
    let ry = 0.44
    setColor(COLOR_GREEN)
    setLineWidth(2.0)
    drawLine(float2(-rx, -ry), float2(rx, -ry))
    drawLine(float2(rx, -ry), float2(rx, ry))
    drawLine(float2(rx, ry), float2(-rx, ry))
    drawLine(float2(-rx, ry), float2(-rx, -ry))
    setLineWidth(1.5)


  def draw()
    return if !isValid
    setFullCanvasViewport()

    drawBackground()
    drawAircraftSymbol()
    drawLockFrame()
    drawRangeScale()
    drawTvGsnIndicator()
    drawSpeeds()
    drawSpeedLimits()
    drawAltitudes()
    drawSideSlipIndicator()
    drawDangerousAlt()
    drawAltWarning()
    drawOsbLabels()
    drawBorder()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; var props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId   = getInt(props, "fontId", 0)
  propStorage.fontSize = getInt(props, "fontSize", 16)
