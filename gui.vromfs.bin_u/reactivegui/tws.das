require darg
require DagorStdGuiRender
require math
require DagorMath
require DagorSystem
require TwsHud
require app
require TwsHud
require hud

require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common

let indicatorRadius = 0.7
let trackRadarsRadius = 0.04
let azimuthMarkLength = 0.5 * 3.0 * trackRadarsRadius
let radarLineOpacity = 0.42

let centralMarkRadius = 0.1
let sectorLineWidth = 35.0

def target_opacity(age : float; holdTimeInv : float) : float
  return max(0.0, 1.0 - min(age * holdTimeInv, 1.0))

struct PropStorage
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  backgroundColor : E3DCOLOR = E3DCOLOR(0x32000000)
  isForTank : bool = false
  lineWidth : float = 2.0
  fontId : int = -1
  fontSize : int = 14
  fontFxColor : E3DCOLOR = E3DCOLOR(0xFF000000)
  fontFxFactor : int = 17
  textColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)

class Component : Canvas
  props : PropStorage = PropStorage()
  targetsOpacityMult : float = 1.0
  maximumTargetOpacity : float = 0.0
  blinkFade : float = 1.0
  stateYPos : float = -0.575

  hud : Hud? = null

  isValid : bool = false

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; p : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hud = get_cur_hud()
    if hud == null
      return

    props = p

    targetsOpacityMult = floor(sin(get_sync_time() * 10.0) + 0.5)
    blinkFade = (int(get_sync_time() * 4.0) % 2) == 0 ? 0.0 : 1.0

    let isMlwsLwsVisible = is_tws_hud_visible() || is_tws_hud_for_mfd_visible()
    stateYPos = isMlwsLwsVisible ? -0.785 : -0.585

    setColor(props.color)
    setLineWidth(props.lineWidth)
    setFont(props.fontId)
    setFontSize(props.fontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)

    let rwrHoldTimeInv = get_rwr_signal_hold_time_inv()
    let mlwsLwsHoldTimeInv = get_mlws_lws_signal_hold_time_inv()
    for t in hud.rwrTargets
      maximumTargetOpacity = max(maximumTargetOpacity, target_opacity(t.age, rwrHoldTimeInv))
    for t in hud.mlwsTargets
      maximumTargetOpacity = max(maximumTargetOpacity, target_opacity(t.age, mlwsLwsHoldTimeInv))
    for t in hud.lwsTargets
      maximumTargetOpacity = max(maximumTargetOpacity, target_opacity(t.age, mlwsLwsHoldTimeInv))

    isValid = true

  def drawBackground(scaleFactor : float; needBackground : bool)
    var clr = float4(Color4(props.color))
    if props.isForTank
      clr *= targetsOpacityMult
    setColor(E3DCOLOR(Color4(clr)))
    setFillColor(needBackground ? props.backgroundColor : TRANSPARENT)
    drawEllipse(float2(0.0), float2(indicatorRadius * scaleFactor))

    clr *= radarLineOpacity
    setColor(E3DCOLOR(Color4(clr)))
    let savedLineWidth = lineWidth
    setLineWidth(1.0)
    let angleStep = 30.0
    let lineCnt = int(360.0 / angleStep)
    for i in 0..lineCnt
      let angle = float(i) * angleStep / 180.0 * PI
      var dirSin, dirCos : float
      sincos(angle, dirSin, dirCos)
      let dir = float2(dirCos, dirSin)
      drawLine(dir * indicatorRadius * scaleFactor, dir * (indicatorRadius - azimuthMarkLength) * scaleFactor)
    setLineWidth(savedLineWidth)


  def drawCentralMark()
    setFillColor(TRANSPARENT)

    let fadedColor = color_mult4(props.color, maximumTargetOpacity)
    setColor(fadedColor)
    drawEllipse(float2(0.0), float2(indicatorRadius * centralMarkRadius))

    var clr = float4(Color4(props.color))
    clr *= radarLineOpacity
    setColor(E3DCOLOR(Color4(clr)))
    drawLine(float2(0.045, 0.0), float2(-0.045, 0.0))
    drawLine(float2(0.0, 0.045), float2(0.0, -0.045))

  def drawRwrTargets()
    for i in range(length(hud.rwrTargets))
      drawRwrTarget(hud.rwrTargets[i])

  def drawRwrTarget(target : RwrHudTarget const&)
    let ageFade = target_opacity(target.age, get_rwr_signal_hold_time_inv())
    let launchFade = target.launch ? blinkFade : 1.0
    let targetOpacity = ageFade * launchFade
    let priorityTargetOpacityMult = target.priority ? 2.0 : 1.0
    let fadedColor = color_mult4(props.color, targetOpacity)

    let elementsSizeMult = 0.43

    let maxTargetHalfSize = (toRelY(hdpx(sectorLineWidth * 0.5)))
    let minDisplayRange = 0.13
    let maxDisplayRange = 0.5 - maxTargetHalfSize
    let displayRange = cvt(target.rangeRel, 0.0, 1.0, minDisplayRange, maxDisplayRange)
    let targetDir = float2(target.dirX, target.dirY)
    let targetPos = targetDir * displayRange

    let priorityTargetLineWidth = target.priority ? 2.0 : 1.0
    setLineWidth(priorityTargetLineWidth)
    setColor(fadedColor)
    setFillColor(TRANSPARENT)

    // newTarget
    let rwrNewTargetHoldTimeInv = get_rwr_new_target_hold_time_inv()
    let age0Rel = target.age0 * rwrNewTargetHoldTimeInv
    let isNewTarget = rwrNewTargetHoldTimeInv < 10.0 && age0Rel < 1.0
    let newTargetRadius = 0.2 * elementsSizeMult
    if isNewTarget
      drawCircle(targetPos, newTargetRadius)

    // targetType
    assume rwrProps = hud.rwrHudProperties
    let dirIdx = rwrProps.directionMap |> lookup(target.groupId)
    let isTargetVisible = dirIdx != int(RwrDirectionMapResult.DIRECTION_HIDDEN)
    var isTargetMapped = false
    if isTargetVisible
      isTargetMapped = dirIdx != int(RwrDirectionMapResult.DIRECTION_UNMAPPED)
      if isTargetMapped
        let text = rwrProps |> getDirection(dirIdx)

        let fxColor = color_mult4(props.fontFxColor, targetOpacity)
        *ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, fxColor, props.fontFxFactor)
        let strBox = drawStrAnchored(targetPos, text, AnchorHorz.Center, AnchorVert.Center)
        *ctx |> set_draw_str_attr(FontFxType.FFT_NONE, 0, 0, props.fontFxColor, props.fontFxFactor)

        // IFF
        if !target.enemy
          let IFFvertOffset = -toRelY(strBox.width.y * 0.5 + hdpx(3.0))
          let IFFHorHalfSize = toRelX(strBox.width.x * 0.5 * elementsSizeMult)
          drawLine(targetPos + float2(-IFFHorHalfSize, IFFvertOffset), targetPos + float2(IFFHorHalfSize, IFFvertOffset))
      else
        let waveAngle = atan2(targetDir.y, targetDir.x)

        setRotation(targetPos, waveAngle)

        let waveAngles = float2(PI_2, PI_2 + PI)
        let offset = float2(0.04, 0.0)
        let p = targetPos + offset
        drawSector(p, float2(0.04, 0.05), waveAngles)
        drawSector(p, float2(0.06, 0.07), waveAngles)
        drawSector(p, float2(0.08, 0.09), waveAngles)

        // IFF
        if !target.enemy
          let halfSize = float2(0.0, 0.09)
          let l = p - halfSize
          let r = p + halfSize
          drawLine(l, r)

        resetViewTm()

    // sector
    if target.sector > 2.0
      setLineWidth(sectorLineWidth)
      let sectorColor = color_mult4(fadedColor, targetOpacity * priorityTargetOpacityMult) // double fade ported from darg
      setColor(sectorColor)
      let targetAngle = atan2(target.dirY, target.dirX)
      let sectorHalf = target.sector * degToRad
      drawSector(float2(0.0), float2(displayRange), float2(targetAngle - sectorHalf, targetAngle + sectorHalf))
      setLineWidth(priorityTargetLineWidth)
      setColor(fadedColor)

    // trackLine
    if target.track || target.launch
      let dashLen = toRelY(hdpx(5.0))
      let spaceLen = toRelY(hdpx(3.0))

      let startDistance = indicatorRadius * centralMarkRadius
      var endDistance = displayRange
      if isNewTarget || isTargetMapped
        endDistance -= newTargetRadius
      drawDashedLine(targetDir * startDistance, targetDir * endDistance, dashLen, spaceLen)

    // elevationMark
    if target.priority
      let elevationPos = float2(0.0)
      let elevationLineWidth = hdpx(3.2)
      let elevRadius = float2(indicatorRadius * centralMarkRadius - toRelY(elevationLineWidth * 0.5 + hdpx(1.0)))

      setLineWidth(elevationLineWidth)
      let elevationColor = color_mult4(fadedColor, targetOpacity) // double fade ported from darg
      setColor(elevationColor)

      if target.elev > 0.1
        drawSector(elevationPos, elevRadius, float2(PI, PI2))
      elif target.elev < -0.1
        drawSector(elevationPos, elevRadius, float2(0.0, PI))

      setLineWidth(priorityTargetLineWidth)
      setColor(fadedColor)

  def drawLwsTargets()
    for i in range(length(hud.lwsTargets))
      drawLwsTarget(hud.lwsTargets[i])

  def drawLwsTarget(target : RwrHudTarget const&)
    let mlwsSignalHoldTimeInv = get_mlws_lws_signal_hold_time_inv()
    let ageFade = target_opacity(target.age, mlwsSignalHoldTimeInv) * targetsOpacityMult
    if ageFade <= 0.0
      return
    let fadedColor = color_mult4(props.color, ageFade)

    let radiusScale = 1.2
    let displayRange = (target.rangeRel * 0.4 + 0.1) * radiusScale
    let targetDir = float2(target.dirX, target.dirY)
    let targetPos = targetDir * displayRange

    setLineWidth(1.0)
    setColor(fadedColor)
    setFillColor(TRANSPARENT)

    let iconAngle = atan2(targetDir.y, targetDir.x) + PI_2
    setRotation(targetPos, iconAngle)

    let scale = 0.002
    pushLocalAxes(targetPos, float2(scale))

    // Laser mark
    if props.isForTank
      drawLine(float2(15.0, 0.0), float2(0.0, 50.0))
      drawLine(float2(-15.0, 0.0), float2(0.0, 50.0))
      drawLine(float2(15.0, 0.0), float2(-15.0, 0.0))
    else
      drawLine(float2(0.0, -25.0), float2(0.0, 5.0))
      drawLine(float2(0.0, 13.0), float2(0.0, 27.0))
      drawLine(float2(5.0, 13.0), float2(11.0, 22.0))
      drawLine(float2(-5.0, 13.0), float2(-11.0, 22.0))
      drawLine(float2(-6.0, 10.0), float2(-15.0, 10.0))
      drawLine(float2(6.0, 10.0), float2(15.0, 10.0))

    // IFF circle for friendly
    if !target.enemy
      setFillColor(props.backgroundColor)
      drawCircle(float2(0.0), 45.0)
      setFillColor(TRANSPARENT)

    resetViewTm()
    popAxes()

    // sector
    if target.sector > 2.0
      let lwsSectorLineWidth = 30.0
      setLineWidth(lwsSectorLineWidth)
      let sectorOpacityMult = 0.25
      let sectorColor = color_mult4(fadedColor, sectorOpacityMult)
      setColor(sectorColor)
      let targetAngle = atan2(target.dirY, target.dirX)
      let sectorHalf = target.sector * degToRad
      let displayOffset = toRelY(hdpx(3.0))
      drawSector(float2(0.0), float2(displayRange + displayOffset), float2(targetAngle - sectorHalf, targetAngle + sectorHalf))
      setLineWidth(1.0)
      setColor(fadedColor)

  def drawLwsTargetsState()
    var lwsAgeMin = 1000.0
    for i in range(length(hud.lwsTargets))
      lwsAgeMin = min(lwsAgeMin, hud.lwsTargets[i].age)
    let stateOpacity = target_opacity(lwsAgeMin, get_mlws_lws_signal_hold_time_inv()) * blinkFade
    if stateOpacity <= 0.0
      return

    let statePos = float2(-0.5, stateYPos)
    let text = loc("hud/lws_laser")

    setColor(color_mult4(props.color, stateOpacity))
    let strBox = drawStrAnchored(statePos, text, AnchorHorz.Center, AnchorVert.Bottom)

    let borderWidth = 2.0
    setLineWidth(borderWidth)
    setFillColor(TRANSPARENT)

    let padding = float2(toRelX(hdpx(4.0)), toRelY(hdpx(9.0)))
    drawBBoxPadded(strBox, padding)

  def drawMlwsTargets()
    for i in range(length(hud.mlwsTargets))
      drawMlwsTarget(hud.mlwsTargets[i])

  def drawMlwsTarget(target : RwrHudTarget const&)
    let mlwsSignalHoldTimeInv = get_mlws_lws_signal_hold_time_inv()
    let ageFade = target_opacity(target.age, mlwsSignalHoldTimeInv) * targetsOpacityMult
    if ageFade <= 0.0
      return
    let fadedColor = color_mult4(props.color, ageFade)

    let radiusScale = 1.2
    let displayRange = (target.rangeRel * 0.4 + 0.1) * radiusScale
    let targetDir = float2(target.dirX, target.dirY)
    let targetPos = targetDir * displayRange

    setLineWidth(1.0)
    setColor(fadedColor)
    setFillColor(TRANSPARENT)

    let rocketAngle = atan2(targetDir.y, targetDir.x) + PI_2
    setRotation(targetPos, rocketAngle)

    let scale = 0.002
    pushLocalAxes(targetPos, float2(scale))

    // right stab
    drawLine(float2(-15.0, -40.0), float2(-15.0, -30.0))
    drawLine(float2(-15.0, -40.0), float2(-5.0, -35.0))
    drawLine(float2(-15.0, -30.0), float2(-5.0, -25.0))
    // left stab
    drawLine(float2(15.0, -40.0), float2(15.0, -30.0))
    drawLine(float2(15.0, -40.0), float2(5.0, -35.0))
    drawLine(float2(15.0, -30.0), float2(5.0, -25.0))
    // right stab 2
    drawLine(float2(-15.0, 0.0), float2(-15.0, 10.0))
    drawLine(float2(-15.0, 0.0), float2(-5.0, 5.0))
    drawLine(float2(-15.0, 10.0), float2(-5.0, 15.0))
    // left stab 2
    drawLine(float2(15.0, 0.0), float2(15.0, 10.0))
    drawLine(float2(15.0, 0.0), float2(5.0, 5.0))
    drawLine(float2(15.0, 10.0), float2(5.0, 15.0))
    // rocket body
    drawLine(float2(-5.0, -25.0), float2(-5.0, 0.0))
    drawLine(float2(5.0, -25.0), float2(5.0, 0.0))
    drawLine(float2(-5.0, -35.0), float2(5.0, -35.0))
    // rocket body 2
    drawLine(float2(-5.0, 15.0), float2(-5.0, 30.0))
    drawLine(float2(5.0, 15.0), float2(5.0, 30.0))
    // warhead
    drawLine(float2(-5.0, 30.0), float2(0.0, 40.0))
    drawLine(float2(5.0, 30.0), float2(0.0, 40.0))

    // IFF circle for friendly
    if !target.enemy
      setFillColor(props.backgroundColor)
      drawCircle(float2(0.0), 45.0)
      setFillColor(TRANSPARENT)

    resetViewTm()
    popAxes()

    // sector
    if target.sector > 2.0
      setLineWidth(sectorLineWidth)
      let sectorColor = color_mult4(fadedColor, 0.25)
      setColor(sectorColor)
      let targetAngle = atan2(target.dirY, target.dirX)
      let sectorHalf = target.sector * degToRad
      drawSector(float2(0.0), float2(displayRange), float2(targetAngle - sectorHalf, targetAngle + sectorHalf))
      setLineWidth(1.0)
      setColor(fadedColor)


  def drawMlwsTargetsState()
    var mlwsAgeMin = 1000.0
    for i in range(length(hud.mlwsTargets))
      mlwsAgeMin = min(mlwsAgeMin, hud.mlwsTargets[i].age)
    let mlwsSignalHoldTimeInv = get_mlws_lws_signal_hold_time_inv()
    let stateOpacity = target_opacity(mlwsAgeMin, mlwsSignalHoldTimeInv) * blinkFade
    if stateOpacity <= 0.01
      return

    let statePos = float2(0.5, stateYPos)
    let text = loc("hud/mlws_missile")

    setColor(color_mult4(props.color, stateOpacity))
    let strBox = drawStrAnchored(statePos, text, AnchorHorz.Center, AnchorVert.Bottom)

    let borderWidth = 2.0
    setLineWidth(borderWidth)
    setFillColor(TRANSPARENT)

    let padding = float2(toRelX(hdpx(4.0)), toRelY(hdpx(9.0)))
    drawBBoxPadded(strBox, padding)

  def drawRwrTargetsPresence()
    let presenceCount = length(hud.rwrTargetsPresence)
    if presenceCount == 0
      return

    let rwrSignalHoldTimeInv = get_rwr_signal_hold_time_inv()
    let isMlwsLwsVisible = is_tws_hud_visible() || is_tws_hud_for_mfd_visible()
    let colsMax = 3

    let anchorPos = float2(0.0, indicatorRadius * (isMlwsLwsVisible ? 1.05 : 0.75) + toRelY(hdpx(7.0)))

    let boxHalfSize = float2(0.2, 0.09)
    let boxPadding = float2(0.025, 0.05)
    let cellStep = boxHalfSize * 2.0 + boxPadding

    assume presenceMap = hud.rwrHudProperties.presenceMap
    for i in range(presenceCount)
      assume tp = hud.rwrTargetsPresence[i]
      var targetOpacity = 0.1
      if tp.presents
        targetOpacity = max(targetOpacity, target_opacity(tp.age, rwrSignalHoldTimeInv))

      let row = i / colsMax
      let col = i - row * colsMax
      let cols = min(presenceCount - row * colsMax, colsMax)

      let posX = anchorPos.x + (float(col) - float(cols - 1) * 0.5) * cellStep.x
      let posY = anchorPos.y + float(row) * cellStep.y + boxHalfSize.y
      let presencePos = float2(posX, posY)

      let priorityLineWidth = tp.priority ? 4.0 : 2.0
      setLineWidth(priorityLineWidth)
      setColor(color_mult4(props.color, targetOpacity))
      setFillColor(TRANSPARENT)

      let text = presenceMap.presences[i].text
      drawStrAnchored(presencePos, text, AnchorHorz.Center, AnchorVert.Center)
      drawBox(presencePos - boxHalfSize, presencePos + boxHalfSize)


  def drawRwrTargetsState()
    var trackingAgeMin = VERY_BIG_NUMBER
    var launchingAgeMin = VERY_BIG_NUMBER
    for i in range(length(hud.rwrTargets))
      assume t = hud.rwrTargets[i]
      if t.track
        trackingAgeMin = min(trackingAgeMin, t.age)
      if t.launch
        launchingAgeMin = min(launchingAgeMin, t.age)
    let minAge = min(trackingAgeMin, launchingAgeMin)

    let rwrSignalHoldTimeInv = get_rwr_signal_hold_time_inv()
    let isLaunching = launchingAgeMin * rwrSignalHoldTimeInv < 1.0
    let launchBlinkFade = isLaunching ? blinkFade : 1.0
    let stateOpacity = target_opacity(minAge, rwrSignalHoldTimeInv) * launchBlinkFade
    if stateOpacity <= 0.01
      return

    let statePos = float2(0.0, stateYPos)
    let text = isLaunching ? loc("hud/rwr_launch") : loc("hud/rwr_track")

    setColor(color_mult4(props.color, stateOpacity))
    let strBox = drawStrAnchored(statePos, text, AnchorHorz.Center, AnchorVert.Bottom)

    let borderWidth = 2.0
    setLineWidth(borderWidth)
    setFillColor(TRANSPARENT)

    let padding = float2(toRelX(hdpx(4.0)), toRelY(hdpx(9.0)))
    drawBBoxPadded(strBox, padding)

  def draw()
    return if !isValid

    // this realy needs a refactor. All values where ported from darg
    // rwr targets take 100% of canvase
    // rwr background is slightly larger, it takes up ~105% of canvas
    // tws background is even larger, taking up ~140%!!!
    var needRwrBack = true
    if is_tws_hud_visible() || is_tws_hud_for_mfd_visible()
      drawBackground(1.0, true)
      needRwrBack = false
    if is_rwr_hud_visible() || is_rwr_for_mfd_hud_visible()
      drawBackground(0.75, needRwrBack)
    drawCentralMark()

    drawRwrTargets()
    drawRwrTargetsState()
    drawRwrTargetsPresence()

    drawLwsTargets()
    drawLwsTargetsState()

    drawMlwsTargets()
    drawMlwsTargetsState()


[export, unused_argument(rstate)]
def draw_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : PropStorage&)
  new Component(ctx, rdata, rstate, data).draw()

[export]
def setup_data(props : Properties&; var storage : PropStorage&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.backgroundColor = props |> getColor("backgroundColor", E3DCOLOR(0x32000000))
  storage.isForTank = props |> getBool("isForTank", false)
  storage.lineWidth = props |> getFloat("lineWidth", 2.0)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 14)
  storage.fontFxColor = props |> getColor("fontFxColor", E3DCOLOR(0xFF000000))
  storage.fontFxFactor = props |> getInt("fontFxFactor", 14)
  storage.textColor = props |> getColor("textColor", E3DCOLOR(0xFFFFFFFF))
