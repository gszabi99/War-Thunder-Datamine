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
require %gameLibs.das.math.base
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
  isValid    : bool = false
  hero       : Unit? = null
  fmw        : FlightModelWrap? = null
  fm         : FlightModel? = null
  app        : AcesApp? = null
  colors     : Colors = Colors()
  shapes     : Shapes = Shapes()
  fuelState  : FuelState
  turretPitch : float = 0.0
  turretYaw   : float = 0.0
  droneRelYaw : float = 0.0
  aspectRatio : float = 1.777


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

    if hero.weap != null && length(hero.weap.turret) > 0
      turretYaw   = hero.weap.turret[0].yawVisual
      turretPitch = hero.weap.turret[0].pitchVisual

    droneRelYaw = -turretYaw * degToRad

    isValid = true
    aspectRatio = canvasSize.x / canvasSize.y
    setLineWidth(2.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(25)
    setFillColor(colors.white)
    setColor(colors.white)

  def drawRect(pos : float2; size : float2)
    drawFilledPoly(shapes.square.to_array().scale(size).translate(pos))

  def drawCenter()
    let pos = float2(0.0, 0.0)
    let arm = 0.03
    setLineWidth(3.0)
    drawLine(pos + float2(-arm, 0.0), pos + float2(-0.4 * arm, 0.0))
    drawLine(pos + float2(0.4 * arm, 0.0), pos + float2(arm, 0.0))
    drawLine(pos + float2(0.0, -arm), pos + float2(0.0, -0.4 * arm))
    drawLine(pos + float2(0.0, 0.4 * arm), pos + float2(0.0, arm))
    drawLine(pos + float2(-0.002, 0.0), pos + float2(0.002, 0.0))
    setLineWidth(2.0)

  def drawCameraAngleBar()
    let frameHalfW = 0.08 * aspectRatio
    let frameHalfH = 0.055
    let leg        = 0.03
    let barY       = 0.375
    let top        = barY - frameHalfH
    let bot        = barY + frameHalfH
    let lft        = -frameHalfW
    let rgt        =  frameHalfW

    setLineWidth(2.0)
    drawLine(float2(lft,       top), float2(lft + leg,  top))
    drawLine(float2(lft,       top), float2(lft,        top + leg))
    drawLine(float2(rgt,       top), float2(rgt - leg,  top))
    drawLine(float2(rgt,       top), float2(rgt,        top + leg))
    drawLine(float2(lft,       bot), float2(lft + leg,  bot))
    drawLine(float2(lft,       bot), float2(lft,        bot - leg))
    drawLine(float2(rgt,       bot), float2(rgt - leg,  bot))
    drawLine(float2(rgt,       bot), float2(rgt,        bot - leg))

    let yawMin   = -35.0
    let yawMax   =  35.0
    let pitchMin = -95.0
    let pitchMax =  15.0
    let innerW   = frameHalfW - leg
    let innerH   = frameHalfH - leg * 0.5
    let normYaw   = clamp((turretYaw   - yawMin)   / (yawMax   - yawMin), 0.0, 1.0)
    let normPitch = clamp((turretPitch - pitchMin) / (pitchMax - pitchMin), 0.0, 1.0)
    let mx = lerp(-innerW, innerW, normYaw)
    let my = lerp(barY + innerH, barY - innerH, normPitch)

    let arm = 0.012
    drawLine(float2(mx - arm, my), float2(mx + arm, my))
    drawLine(float2(mx, my - arm), float2(mx, my + arm))

  def drawDroneBody(cx : float; cy : float)
    let bW = 0.008
    let bH = 0.017
    drawLine(float2(cx - bW, cy - bH), float2(cx + bW, cy - bH))
    drawLine(float2(cx - bW, cy + bH), float2(cx + bW, cy + bH))
    drawLine(float2(cx - bW, cy - bH), float2(cx - bW, cy + bH))
    drawLine(float2(cx + bW, cy - bH), float2(cx + bW, cy + bH))

    let armY   = cy - bH * 0.3
    let armEnd = 0.030
    drawLine(float2(cx - bW, armY), float2(cx - bW - armEnd, armY))
    drawLine(float2(cx + bW, armY), float2(cx + bW + armEnd, armY))

    let mW = 0.007
    let mH = 0.010
    for i in range(0, 2)
      let mx = cx - bW - armEnd + float(i) * (2.0 * (bW + armEnd))
      drawLine(float2(mx - mW, armY - mH), float2(mx + mW, armY - mH))
      drawLine(float2(mx - mW, armY + mH), float2(mx + mW, armY + mH))
      drawLine(float2(mx - mW, armY - mH), float2(mx - mW, armY + mH))
      drawLine(float2(mx + mW, armY - mH), float2(mx + mW, armY + mH))
      let propY = armY - mH - 0.005
      drawLine(float2(mx - 0.016, propY), float2(mx + 0.016, propY))

  def drawPitchDiagram()
    let cx      = -0.250
    let cy      =  0.375
    let coneLen =  0.036
    let coneHW  =  0.013
    let bW      =  0.008
    let bH      =  0.017
    let armEnd  =  0.030
    let mH      =  0.010

    drawDroneBody(cx, cy)

    let camX = cx
    let camY = cy + bH + 0.010
    drawCircle(float2(camX, camY), 0.006)

    let pitchMin  = -95.0
    let pitchMax  =  15.0
    let pitchMid  = (pitchMin + pitchMax) * 0.5
    let pitchHalf = (pitchMax - pitchMin) * 0.5
    let pitchNorm = clamp((turretPitch - pitchMid) / pitchHalf, -1.0, 1.0)
    var sina, cosa = 0.0
    let maxAngle = 1.5
    sincos((pitchNorm * 0.5 + 0.5) * maxAngle, sina, cosa)
    let dirX = -sina
    let dirY =  cosa
    let perpX = -cosa
    let perpY = -sina
    let tipX = camX + dirX * coneLen
    let tipY = camY + dirY * coneLen
    let lx   = tipX - perpX * coneHW
    let ly   = tipY - perpY * coneHW
    let rx   = tipX + perpX * coneHW
    let ry   = tipY + perpY * coneHW
    drawLine(float2(camX, camY), float2(lx, ly))
    drawLine(float2(camX, camY), float2(rx, ry))
    drawLine(float2(lx, ly), float2(rx, ry))

    let armY   = cy - bH * 0.3
    let pPropX = cx + bW + armEnd
    let pPropY = armY - mH - 0.005 - 0.012
    drawStrAnchored(float2(pPropX, pPropY), "P", AnchorHorz.Center, AnchorVert.Center)

  def drawYawDiagram()
    let cx      =  0.250
    let cy      =  0.375
    let coneLen =  0.036
    let coneHW  =  0.013
    let bW      =  0.008
    let bH      =  0.017
    let armEnd  =  0.030
    let mH      =  0.010

    drawDroneBody(cx, cy)

    let camX = cx
    let camY = cy + bH + 0.010
    drawCircle(float2(camX, camY), 0.006)

    let yawNorm = clamp(turretYaw / 35.0, -1.0, 1.0)
    var sina, cosa = 0.0
    sincos(yawNorm * 1.2, sina, cosa)
    let dirX =  sina
    let dirY =  cosa
    let perpX = -cosa
    let perpY =  sina
    let tipX  = camX + dirX * coneLen
    let tipY2 = camY + dirY * coneLen
    let lx    = tipX - perpX * coneHW
    let ly    = tipY2 - perpY * coneHW
    let rx    = tipX + perpX * coneHW
    let ry    = tipY2 + perpY * coneHW
    drawLine(float2(camX, camY), float2(lx, ly))
    drawLine(float2(camX, camY), float2(rx, ry))
    drawLine(float2(lx, ly), float2(rx, ry))

    let armY   = cy - bH * 0.3
    let yPropX = cx - bW - armEnd
    let yPropY = armY - mH - 0.005 - 0.012
    drawStrAnchored(float2(yPropX, yPropY), "Y", AnchorHorz.Center, AnchorVert.Center)

  def drawDroneHeadingIndicator()
    let cx     = 0.0
    let cy     = 0.275
    let bodyHW = 0.012
    let armLen = 0.012
    let rotorR = 0.008

    let arrowCx  = cx
    let arrowCy  = cy - bodyHW - armLen - 0.025
    let arrowLen = 0.018
    let arrowHW  = 0.007
    drawLine(float2(arrowCx, arrowCy + arrowLen * 0.5), float2(arrowCx, arrowCy - arrowLen * 0.5))
    drawLine(float2(arrowCx - arrowHW, arrowCy + arrowLen * 0.1), float2(arrowCx, arrowCy - arrowLen * 0.5))
    drawLine(float2(arrowCx + arrowHW, arrowCy + arrowLen * 0.1), float2(arrowCx, arrowCy - arrowLen * 0.5))

    var sinA, cosA = 0.0
    sincos(droneRelYaw, sinA, cosA)

    let corners <- fixed_array(
      float2(-bodyHW, -bodyHW),
      float2(bodyHW, -bodyHW),
      float2(bodyHW, bodyHW),
      float2(-bodyHW, bodyHW),
    )
    let armDirs <- fixed_array(
      float2(-1.0, -1.0),
      float2(1.0, -1.0),
      float2(1.0, 1.0),
      float2(-1.0, 1.0),
    )

    for i in range(0, 4)
      let a = corners[i]
      let b = corners[(i + 1) % 4]
      let ra = float2(cx + a.x * cosA - a.y * sinA, cy + a.x * sinA + a.y * cosA)
      let rb = float2(cx + b.x * cosA - b.y * sinA, cy + b.x * sinA + b.y * cosA)
      drawLine(ra, rb)

    for i in range(0, 4)
      let c = corners[i]
      let d = normalize(armDirs[i]) * armLen
      let rc = float2(cx + c.x * cosA - c.y * sinA, cy + c.x * sinA + c.y * cosA)
      let tipLocal = c + d
      let rt = float2(cx + tipLocal.x * cosA - tipLocal.y * sinA, cy + tipLocal.x * sinA + tipLocal.y * cosA)
      drawLine(rc, rt)
      let perpDir = float2(-d.y, d.x) * (rotorR / length(d))
      let perpRot = float2(perpDir.x * cosA - perpDir.y * sinA, perpDir.x * sinA + perpDir.y * cosA)
      drawLine(rt - perpRot, rt + perpRot)

    let fwdLocal = float2(0.0, -bodyHW)
    let fwdRot   = float2(cx + fwdLocal.x * cosA - fwdLocal.y * sinA, cy + fwdLocal.x * sinA + fwdLocal.y * cosA)
    let tipFwd   = float2(cx + 0.0 * cosA - (-bodyHW - 0.008) * sinA, cy + 0.0 * sinA + (-bodyHW - 0.008) * cosA)
    drawLine(fwdRot, tipFwd)

  def drawFuelTime()
    let fuelRemainingTimeS = floori(get_remaining_fuel_time())
    let pos = float2(-0.362, 0.15)
    drawStrAnchored(pos, "{fmt(":02d", fuelRemainingTimeS / 60)} : {fmt(":02d", fuelRemainingTimeS % 60)}", AnchorHorz.Center, AnchorVert.Center)

  def drawFuelVoltage()
    let fuelRemaining = fuelState.current / fuelState.maxAvailable
    let pos = float2(-0.4, 0.19)
    let maxVoltage = 22.0
    let minVoltage = 18.0
    let curVoltage = lerp(minVoltage, maxVoltage, fuelRemaining)
    drawStrAnchored(pos, "{fmt(":.2f", curVoltage)} V", AnchorHorz.Left, AnchorVert.Bottom)

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
    drawStrAnchored(pos, "ALT  {fmt(":3d", floori(alt))}", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.1, 0.00), "M", AnchorHorz.Left, AnchorVert.Center)

  def drawVelocity()
    let vel = fm.speed * mpsToKmh
    let pos = float2(0.39, 0.18)
    drawStrAnchored(pos, "VEL  {fmt(":3d", floori(vel))}", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.1, 0.00), "km/h", AnchorHorz.Left, AnchorVert.Center)

  def drawEngineThrottle()
    let thrust = float(fm.appliedCT.getPower(0))
    let pos = float2(0.39, 0.21)
    drawStrAnchored(pos, "THR {fmt(":3d", floori(thrust * 100.0))}", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.1, 0.00), "%", AnchorHorz.Left, AnchorVert.Center)

  def drawSignalQuality()
    let signalQualityRatio = float(get_drone_connection_quality()) / 3.0
    let pos = float2(0.39, -0.2)
    let width = 0.01
    let startHeight = 0.007
    let heightInc = 0.007
    let margin = 0.002
    let maxLinesNumber = 6
    let linesNumber = int(signalQualityRatio * float(maxLinesNumber))
    drawStrAnchored(pos + float2(0.04, -0.06), "LQ", AnchorHorz.Center, AnchorVert.Center)
    for i in range(0, linesNumber)
      let curPos = pos + float(i) * float2(width + margin, 0.0)
      let curSize = float2(width, startHeight + float(i) * heightInc)
      drawFilledPoly(shapes.squareCorner.to_array().scale(-curSize).translate(curPos))

  def draw()
    if !isValid
      return

    setColor(colors.white)
    drawCenter()
    drawSignalQuality()
    drawAlt()
    drawVelocity()
    drawEngineThrottle()

    fuelState = get_fuel_state(fm.M) <| $[unused_argument(index, curr, max)] (index : int; curr, max : float)
      return
    drawFuelVoltage()
    drawFuelBattery()
    drawFuelTime()
    drawPitchDiagram()
    drawYawDiagram()
    drawDroneHeadingIndicator()
    drawCameraAngleBar()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
