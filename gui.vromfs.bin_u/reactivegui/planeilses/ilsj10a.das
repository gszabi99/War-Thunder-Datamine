require %rGui.utils.avionics_common
require %rGui.utils.canvas_common
require %rGui.utils.helpers_common

require %dasGameLibs.math.base
require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require GamePhys
require HeroManager
require math
require Plane
require strings
require Unit
require Weapon

struct PropStorage
  fontId        : int
  isMetricUnits : bool
  ilsFovDeg     : float2

let
  COLOR_NULL = E3DCOLOR(0x0)
  COLOR_MASK = E3DCOLOR(0xFF000000)
  BLINKS_PER_SEC = 4.0

class Component : Canvas
  isValid          : bool
  isMetricUnits    : bool
  hudFov     : float2
  defaultLineWidth : float
  defaultFontSize  : int
  defaultColor     : E3DCOLOR

  app  : AcesApp?
  hero : Unit?
  fmw  : FlightModelWrap?

  secondaryWeapon : Weapon?
  fpm             : FlightPathMarker
  track           : Track
  totalTime       : float

  visual  : Visual
  limits  : LimitsEllipse
  isArmed : bool

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    app = get_app()
    return if app == null
    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null

    isValid = true

    isMetricUnits = props.isMetricUnits
    hudFov = deg_to_rad(props.ilsFovDeg)

    defaultColor = *fmw.cockpit->getPageColor(MfdPageType.MFD_PLANE_ILS)
    defaultLineWidth = floor(3.0 * fmw.cockpit.ilsLineWidthScale)
    defaultFontSize = 30
    setColor(defaultColor)
    setLineWidth(defaultLineWidth)
    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFontSize(defaultFontSize)

    limits <- LimitsEllipse(center = float2(0.0), radius = float2(0.48))
    get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
      secondaryWeapon := weapon
    totalTime = float(app.usefulTotalTime)
    visual <- avionics_common::get_visual(app.usefulTotalTime, hero)
    fpm <- avionics_common::get_flight_path_marker(visual.vel) <| $(world_pos : float3 const&; var screen_pos : float2&)
      return worldVecToHud(world_pos, screen_pos)
    clampFpm(fpm, limits)
    isArmed = avionics_common::get_armed_status(fmw)
    track <- avionics_common::get_track(hero) <| $(world_pos : float3 const&; var screen_pos : float2&)
      return worldPosToHud(world_pos, screen_pos)

  def clampFpm(var in_fpm : FlightPathMarker&; lim : LimitsEllipse const&)
    avionics_common::clamp_pos(in_fpm.screenPos, in_fpm.screenPos, lim)

  def drawFpm()
    if !fpm.isScreenPosValid
      return
    assume pos = fpm.screenPos
    let radius = 0.013
    drawCircle(pos, radius)
    let right0 = float2(radius, 0.0)
    let right1 = float2(2.5 * radius, 0.0)
    let up0 = float2(0.0, radius)
    let up1 = float2(0.0, 2.5 * radius)
    drawLine(pos - right0, pos - right1)
    drawLine(pos + right0, pos + right1)
    drawLine(pos - up0, pos - up1)

  def drawPitchLadder()
    setFontSize(roundi(float(defaultFontSize) * 0.9))
    let stepDeg = 5.0
    let stepRel = stepDeg / rad_to_deg(hudFov.y)

    let spaceWidth = 0.07
    let markWidth = 0.05
    let dashWidth = 0.0075
    let serifWidth = 0.015
    let count = roundi(toRelY(length(canvasSize)) / stepRel)
    let tangage5deg = rad_to_deg(visual.euler.y) / 5.0
    let marksVertOffset = fract(tangage5deg) * stepRel
    let markStartX = 0.5 * spaceWidth
    let roll = -visual.euler.z
    var sina = 0.0
    var cosa = 0.0
    sincos(roll, sina, cosa)
    let fpmRotated = rotate(fpm.screenPos, sina, cosa)
    let zeroPos = float2(fpmRotated.x, 0.0)
    setRotation(float2(0.0), -roll)
    setTextAnchorHorz(AnchorHorz.Left)

    for i in -count..count + 1
      let markTangage5deg = floori(tangage5deg) - i
      if abs(markTangage5deg) > 18
        continue
      let markOffset = marksVertOffset + float(i) * stepRel
      let pos = zeroPos + float2(0.0, markOffset)
      var markEndX = 0.5 * spaceWidth + markWidth
      let markEndY = 0.0
      if markTangage5deg > 0
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(markEndX, -markEndY)
        let p2 = float2(markEndX, -markEndY + serifWidth)
        drawLine(pos + p1, pos + p0)
        drawLine(pos + p1, pos + p2)
        drawLine(pos + inv_x(p1), pos + inv_x(p0))
        drawLine(pos + inv_x(p1), pos + inv_x(p2))
      elif markTangage5deg < 0
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(markEndX, -markEndY)
        let p2 = float2(markEndX, -markEndY - serifWidth)
        drawDashedLine(pos + p1, pos + p0, dashWidth, dashWidth)
        drawLine(pos + p1, pos + p2)
        drawDashedLine(pos + inv_x(p1), pos + inv_x(p0), dashWidth, dashWidth)
        drawLine(pos + inv_x(p1), pos + inv_x(p2))
      else
        markEndX *= 1.4
        let p0 = float2(markStartX, 0.0)
        let p1 = float2(markEndX, -markEndY)
        let p2 = float2(markEndX, -markEndY + serifWidth)
        drawLine(pos + p1, pos + p0)
        drawLine(pos + p1, pos + p2)
        drawLine(pos + inv_x(p1), pos + inv_x(p0))
        drawLine(pos + inv_x(p1), pos + inv_x(p2))

      let str = "{abs(markTangage5deg * 5)}"
      let strSize = getStringSize(str)
      let dx = 0.004 + markEndX
      let dy = 0.008 * float(sign(markTangage5deg))
      drawStrAnchored(pos + float2(dx, dy), str, AnchorHorz.Left, AnchorVert.Center)
      drawStrAnchored(pos + float2(-dx, dy), str, AnchorHorz.Right, AnchorVert.Center)
    resetViewTm()
    setFontSize(defaultFontSize)

  def drawIasIndicator()
    let ias = fmw.ias * 3.6
    let size = float2(0.015, 0.36)
    let pos = float2(-0.365, -0.185)
    let stepSize = 10.0
    let stepCount = 16
    let iasStr = fmt(":4", roundi(ias))
    let isFlipped = false

    drawVerticalLadder(ias, pos, size, stepCount, stepSize, iasStr, isFlipped) <| $(val : int)
      return fmt(":2", val)

  def drawAltIndicator()
    let alt = hero.unitTm[3].y - app.currentScene.waterLevel
    let size = float2(0.015, 0.36)
    let pos = float2(0.365, -0.185)
    let stepSize = 100.0
    let stepCount = 16
    let altStr = fmt(":5", roundi(alt))
    let isFlipped = true

    drawVerticalLadder(alt, pos, size, stepCount, stepSize, altStr, isFlipped) <| $(val : int)
      let isNegative = val < 0
      let whole = val / 10
      let rem = abs(val) % 10
      return isNegative ? "-{fmt(":1", whole)},{rem}" : "{fmt(":2", whole)},{rem}"

  def drawVerticalLadder(val : float;
                         pos : float2;
                         size : float2;
                         step_count : int;
                         step_sz : float;
                         val_str : string;
                         flip_x  : bool;
                         fmt : block<(val : int) : string>)
    let lt = pos - 0.5 * size
    let rb = pos + 0.5 * size
    let stepRel = size.y / float(step_count)
    let stepVal = val / step_sz
    let anchorInt = floor(stepVal + 0.5)
    let anchorText = flip_x ? AnchorHorz.Left : AnchorHorz.Right
    let shiftPixels = (stepVal - float(anchorInt)) * stepRel
    let halfCount = int(step_count / 2) + 1
    // Ladder
    for i in -halfCount..halfCount + 1
      let y = pos.y + (float(i) * stepRel) + shiftPixels
      if y > lt.y && y < rb.y
        let p1 = float2(rb.x, y)
        var p2 = float2(rb.x, y)
        let strVal = int(anchorInt) - i
        if strVal % 5 != 0
          p2.x -= size.x * 0.75
        else
          p2.x -= size.x
          let strPos = flip_x ? p1 + float2(0.005, 0.0) : p2 - float2(0.005, 0.0)
          let str = fmt |> invoke(strVal)
          drawStrAnchored(strPos, str, anchorText, AnchorVert.Center)
        drawLine(p1, p2)
    // Boxed value
    let padding = 0.005
    let strPos = float2(rb.x - padding, pos.y)
    let box = getStrBbox(strPos, val_str, anchorText, AnchorVert.Center)
    setFillColor(COLOR_MASK)
    drawBBox(box, padding)
    setFillColor(COLOR_NULL)
    drawStrAnchored(strPos, val_str, anchorText, AnchorVert.Center)

  def drawHeadingTape()
    let size = float2(0.66, 0.06)
    let pos = float2(0.0, -0.4)
    let forward = quat_get_forward(visual.quat)
    let heading = atan2(forward.x, forward.z)
    let lt = pos - 0.5 * size
    let rb = pos + 0.5 * size
    let count = 4
    let stepRel = size.x / float(count)
    let heading10deg = (0.5 * float(count + 1) - heading * 36.0 / TWOPI) % 36.0
    let linesOffset = fract(heading10deg) * stepRel
    let dotsOffset = fract(0.5 + heading10deg) * stepRel
    setViewport(lt, rb)

    for i in 0..count + 1
      let x = lt.x + (float(i) - 0.5) * stepRel
      let lineTop = float2(x + linesOffset, rb.y - 0.35 * size.y)
      let lineBottom = float2(x + linesOffset, rb.y)
      let str = fmt(":02", ((36 - floori(heading10deg) + i) % 36))
      let strSize = getStringSize(str, 2)
      let strPos = lineTop
      if strPos.x + strSize.x < rb.x && strPos.x - strSize.x > lt.x
        drawLine(lineTop, lineBottom)
        drawStrAnchored(strPos, str, AnchorHorz.Center, AnchorVert.Bottom)
      let lineCenterTop = float2(x + dotsOffset, rb.y - 0.2 * size.y)
      let lineCenterBottom = float2(x + dotsOffset, rb.y)
      if lineCenterBottom.x + strSize.x < rb.x && lineCenterBottom.x - strSize.x > lt.x
        drawLine(lineCenterTop, lineCenterBottom)

    restoreViewport()
    let centerMarkHt = 0.03
    let centerMarkPos = pos + float2(0.00, 0.5 * size.y - centerMarkHt * 0.25)
    drawLine(centerMarkPos, centerMarkPos + float2(0.0, centerMarkHt))

  def drawLosTarget()
    if !track.isActive
      return
    let size = float2(0.02)
    var clampedPos : float2
    let isTargetOnScreen = avionics_common::clamp_pos(track.screenPos, clampedPos, limits)
    let isBlink = fract(BLINKS_PER_SEC * totalTime) < 0.5
    if isTargetOnScreen || isBlink
      drawBox(
        float2(clampedPos - size),
        float2(clampedPos + size))

  def drawRollIndicator()
    let pos = float2(0.0, 0.03)
    let divs = 24
    let interval = TWOPI / float(divs)
    var sina, cosa : float
    let half = divs / 2
    let down = half / 2
    let gap = 0.25
    for i in 2..half - 1
      var length = 0.015
      if i == down
        length *= 2.0
      let angle = float(i) * interval
      sincos(angle, sina, cosa)
      let end = gap - length
      let startPos = float2(gap * cosa, gap * sina) + pos
      let endPos = float2(end * cosa, end * sina) + pos
      drawLine(startPos, endPos)

    var triangle = fixed_array(
      float2(0.00, 0.00),
      float2(-0.01,  0.01),
      float2(0.01,  0.01),
    )
    let limit = 4.0 * interval
    let clampedRoll = clamp(visual.euler.z, -limit, limit)
    sincos(clampedRoll, sina, cosa)
    drawClosedPolyLine(triangle.translate(float2(0.0, gap)).rotate(sina, cosa).translate(pos).to_array())

  def drawBoresightCross()
    let pos = float2(0.0, -0.3)
    let size = float2(0.035)
    drawCrossReticle(pos, size, float2(0.0))

  def drawMasterArm()
    let pos = float2(-0.34, 0.1)
    drawStrAnchored(pos, isArmed ? "ARM" : "SAFE", AnchorHorz.Left, AnchorVert.Bottom)

  def drawMach()
    let pos = float2(-0.42, 0.05)
    drawStrAnchored(pos, "M{fmt(":>5.2f", fmw.fm.Mach)}", AnchorHorz.Left, AnchorVert.Bottom)

  def drawVsi()
    let pos = float2(0.35, -0.26)
    drawStrAnchored(pos, "{roundi(hero.vel.y)}", AnchorHorz.Right, AnchorVert.Top)

  def drawAoa()
    let pos = float2(-0.42, -0.43)
    drawStrAnchored(pos, "α{fmt(":4d", roundi(fmw.fm.aoa))}", AnchorHorz.Left, AnchorVert.Top)

  def drawLoadFactor()
    let pos = float2(-0.42, -0.47)
    let load = max(float(fmw.fm.localAccel.y) * safeinv(gravity()) + 1.f, -9.9)
    drawStrAnchored(pos, "G{fmt(":4.1f", load)}", AnchorHorz.Left, AnchorVert.Top)

  def worldVecToHud(world_vec : float3 const&; var screen_pos : float2&)
    screen_pos = world_vec_to_hud(world_vec, hero.unitTm, hudFov)
    return true

  def worldPosToHud(world_pos : float3 const&; var screen_pos : float2&)
    screen_pos = world_pos_to_hud(world_pos, hero.unitTm, hudFov)
    return true

  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawFpm()
    drawPitchLadder()
    drawHeadingTape()
    drawLosTarget()
    drawRollIndicator()
    drawIasIndicator()
    drawAltIndicator()
    drawBoresightCross()
    drawMasterArm()
    drawMach()
    drawVsi()
    drawAoa()
    drawLoadFactor()
    restoreViewport()

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.isMetricUnits = getBool(props, "isMetricUnits", true)
  propStorage.ilsFovDeg.x = getFloat(props, "ilsFovDegX", 20.0)
  propStorage.ilsFovDeg.y = getFloat(props, "ilsFovDegY", 20.0)