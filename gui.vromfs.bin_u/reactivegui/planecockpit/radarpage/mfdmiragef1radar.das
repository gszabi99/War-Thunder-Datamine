require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.radar_common
require DagorStdGuiRender
require DagorMath
require math
require hud
require darg
require RadarHud
require HeroManager
require FlightModelWrap
require Unit
require Sensors


struct PropStorage
  fontId    : int   = 0
  prevAzRel : float = 0.0
  sweepX    : float = 0.0
  sweepDir  : float = 1.0


struct Props
  bgColor       : E3DCOLOR = E3DCOLOR(0xFF000000)
  scopeColor    : E3DCOLOR = E3DCOLOR(0xFFDDDD44)
  dimColor      : E3DCOLOR = E3DCOLOR(0xFF888822)
  scopeRadius   : float    = 0.384
  lineWidth     : float    = 2.5
  thinLineWidth : float    = 1.5
  fontSize      : int      = 24


class MirageF1Radar : Canvas
  props           : Props = Props()
  hero            : Unit?
  fmw             : FlightModelWrap?
  hasLockedTarget : bool  = false
  lockedAzX       : float = 0.0
  lockedDistRate  : float = 0.0
  sweepX          : float = 0.0
  sweepDir        : float = 1.0


  def MirageF1Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
                    rstate : RenderState& const; inParams : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    setFont(inParams.fontId)
    hero     = get_watched_not_delayed_hero()
    fmw      = as_fmw(hero)
    sweepX   = inParams.sweepX
    sweepDir = inParams.sweepDir
    if hero != null
      using() <| $(var toi : TargetOfInterest#)
        if hero.sensors.getSelectedTargetOfInterest(hero.detector, toi)
          lockedDistRate = toi.distanceRate


  def scanHW() : float
    return props.scopeRadius * 1.02

  def toPos(azRel : float; distRel : float) : float2
    let hw = scanHW()
    return float2((azRel * 2.0 - 1.0) * hw, (1.0 - distRel * 2.0) * hw)


  def drawBackground()
    setFillColor(props.bgColor)
    setColor(props.bgColor)
    drawBox(float2(-0.5), float2(0.5))


  def getRangeParams(rangeKm : float; var rangeNm : float&; var stepNm : float&)
    let kmPerNm = 1.852
    rangeNm = rangeKm / kmPerNm
    if rangeNm > 40.0
      stepNm = 10.0
    elif rangeNm > 20.0
      stepNm = 5.0
    elif rangeNm > 10.0
      stepNm = 5.0
    else
      stepNm = 2.0

  def drawRangeRingsAndLabels(var stor : PropStorage&)
    let hw      = scanHW()
    let rangeKm = get_radar_hud_distance_max()
    if rangeKm < 1.0
      return

    var rangeNm = 0.0
    var stepNm  = 0.0
    getRangeParams(rangeKm, rangeNm, stepNm)

    let labelX = -(props.scopeRadius + 0.06)
    setLineWidth(props.thinLineWidth)
    setFontSize(props.fontSize)

    var nmVal = stepNm
    while nmVal < rangeNm - stepNm * 0.5
      let distRel = nmVal / rangeNm
      let yLine   = (1.0 - distRel * 2.0) * hw
      let r2      = props.scopeRadius * props.scopeRadius
      let y2      = yLine * yLine
      let xClip   = y2 < r2 ? sqrt(r2 - y2) : 0.0
      if xClip >= 0.005
        if hasLockedTarget
          let rloHW = 0.024
          let lx = clamp(lockedAzX - rloHW, -xClip, xClip)
          let rx = clamp(lockedAzX + rloHW, -xClip, xClip)
          setColor(props.scopeColor)
          drawLine(float2(lx, yLine), float2(rx, yLine))
        else
          let trailLen = hw * 0.35
          let x0       = clamp(sweepX - sweepDir * trailLen, -xClip, xClip)
          let x1       = clamp(sweepX, -xClip, xClip)
          if abs(x1 - x0) > 0.001
            setColor(props.scopeColor)
            drawLine(float2(x0, yLine), float2(x1, yLine))
        setColor(props.scopeColor)
        drawStrAnchored(float2(labelX, yLine), fmt(":d", floori(nmVal)),
                        AnchorHorz.Right, AnchorVert.Center)
      nmVal += stepNm

    setColor(props.scopeColor)
    drawStrAnchored(float2(labelX, -hw), fmt(":d", floori(rangeNm)),
                    AnchorHorz.Right, AnchorVert.Center)


  def drawCentreAzimuthTick()
    let hw      = scanHW()
    let tickLen = hw * 0.12
    setColor(props.scopeColor)
    setLineWidth(props.thinLineWidth)
    drawLine(float2(0.0, -hw), float2(0.0, -hw + tickLen))


  def drawAircraftSilhouette()
    let hw       = scanHW()
    let cy       = hw * 0.82
    let segLen   = hw * 0.09
    let gap      = segLen
    let horizLen = segLen * 2.0 + gap

    setColor(props.scopeColor)
    setLineWidth(props.thinLineWidth)

    drawLine(float2(-horizLen, cy), float2(horizLen, cy))

    let rollRad = fmw != null ? -fmw.roll * degToRad : 0.0
    var sinR = 0.0
    var cosR = 0.0
    sincos(rollRad, sinR, cosR)
    let ay      = segLen * 0.55
    let llx = -horizLen * cosR - ay * (-sinR)
    let lly = -horizLen * sinR + ay * (-cosR)
    let lrx = -gap * 0.5 * cosR - ay * (-sinR)
    let lry = -gap * 0.5 * sinR + ay * (-cosR)
    drawLine(float2(llx, cy + lly), float2(lrx, cy + lry))
    let rlx =  gap * 0.5 * cosR - ay * (-sinR)
    let rly =  gap * 0.5 * sinR + ay * (-cosR)
    let rrx =  horizLen * cosR - ay * (-sinR)
    let rry =  horizLen * sinR + ay * (-cosR)
    drawLine(float2(rlx, cy + rly), float2(rrx, cy + rry))


  def drawSweep(var stor : PropStorage&)
    let hw     = scanHW()
    let azRel  = get_radar_hud_azimuth()
    let xSweep = (azRel * 2.0 - 1.0) * hw

    let prevAz = stor.prevAzRel
    stor.prevAzRel = azRel
    stor.sweepX    = xSweep
    sweepX         = xSweep
    let delta = azRel - prevAz
    if abs(delta) > 0.001
      let d = delta > 0.0 ? 1.0 : -1.0
      stor.sweepDir = d
      sweepDir      = d


  def drawGround()
    let hw  = scanHW()
    let pos  = toAbsPos(float2(-hw, -hw))
    let size = toAbsXY(float2(hw * 2.0, hw * 2.0))
    render_ground_reflection(*ctx, size, pos, props.dimColor, int2(20, 10), true)


  def drawTargets()
    Radar`foreach_visible_target() <| $(var target)
      let distRel = get_radar_hud_has_distance_scale() && target.distanceRel >= 0.0 ? target.distanceRel : 0.5
      let azRel   = get_radar_hud_has_azimuth_scale() ? target.azimuthRel : 0.5

      let signalRel = target.signalRel < 0.01 ? 0.0 : cvt(target.signalRel, 0.05, 1.0, 0.3, 1.0)
      let alpha    = (1.0 - target.ageRel) * signalRel
      let col4     = float4(Color4(props.scopeColor)) * alpha
      let col      = E3DCOLOR(Color4(col4))
      let tPos     = toPos(azRel, distRel)

      setFillColor(col)
      setColor(E3DCOLOR(0x00000000))
      drawEllipse(tPos, float2(0.012))

      if target.isSelected
        hasLockedTarget = true
        let hw = scanHW()
        setFillColor(E3DCOLOR(0x00000000))
        setColor(props.scopeColor)
        setLineWidth(props.thinLineWidth)

        let rloHW = 0.024
        drawLine(float2(tPos.x - rloHW, -hw), float2(tPos.x - rloHW, hw))
        drawLine(float2(tPos.x + rloHW, -hw), float2(tPos.x + rloHW, hw))
        drawLine(float2(tPos.x - rloHW, -hw), float2(tPos.x + rloHW, -hw))
        drawLine(float2(tPos.x - rloHW,  hw), float2(tPos.x + rloHW,  hw))

        // Radial velocity marker (figure 2-3 from Cyrano-IV manual):
        // main line: 0 m/s (bottom) to +900 m/s (top) for closing
        // short line: -100 to -200 m/s (below zero, gap between them)
        // horizontal tick = current closing speed (-distanceRate)
        let dMarkX  = hw * 0.65
        let tickHH  = hw * 0.025
        let pxPer100 = hw * 0.10   // 0.25 cm ~ 100 m/s scaled to scope
        let zeroY   = hw * 0.30    // Y position of 0 m/s on screen (lower = near bottom)
        let topY    = zeroY - 9.0 * pxPer100   // +900 m/s
        let ext1Y   = zeroY + 1.0 * pxPer100   // -100 m/s (gap start)
        let ext2Y   = zeroY + 2.0 * pxPer100   // -200 m/s (short line bottom)
        drawLine(float2(dMarkX, topY),  float2(dMarkX, zeroY))
        drawLine(float2(dMarkX, ext1Y), float2(dMarkX, ext2Y))
        let closingSpeed = -lockedDistRate
        let speedClamped = clamp(closingSpeed, -200.0, 900.0)
        let tickY = zeroY - speedClamped * pxPer100 / 100.0
        drawLine(float2(dMarkX - tickHH, tickY), float2(dMarkX + tickHH, tickY))

        if get_radar_hud_aam_launch_zone_visible()
          let distMax = get_radar_hud_aam_launch_zone_dist_max()
          let dgftMax = get_radar_hud_aam_launch_zone_dist_dgft_max()
          let distMin = get_radar_hud_aam_launch_zone_dist_min()
          let mHW     = hw * 0.10
          if distMax > 0.0
            let yMax = (1.0 - distMax * 2.0) * hw
            drawLine(float2(tPos.x - mHW, yMax), float2(tPos.x + mHW, yMax))
          if dgftMax > 0.0
            let yDgft = (1.0 - dgftMax * 2.0) * hw
            drawLine(float2(tPos.x - mHW, yDgft), float2(tPos.x + mHW, yDgft))
          if distMin > 0.0
            let yMin = (1.0 - distMin * 2.0) * hw
            drawLine(float2(tPos.x - mHW, yMin), float2(tPos.x + mHW, yMin))


  def drawRangeGate()
    if !get_radar_hud_cue_visible()
      return
    let hw      = scanHW()
    let halfGate = 0.5 * get_radar_hud_cue_dist_width_rel()
    let distRel  = halfGate + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1.0 - 2.0 * halfGate)
    let y        = (1.0 - distRel * 2.0) * hw
    setColor(props.scopeColor)
    setLineWidth(props.lineWidth)
    drawLine(float2(-hw, y), float2(hw, y))


  def drawModeLabel()
    setColor(props.scopeColor)
    setFontSize(props.fontSize)
    let modeName = get_radar_hud_mode_name()
    if modeName != ""
      drawStrAnchored(float2(-(props.scopeRadius + 0.06), -(props.scopeRadius * 0.60)),
                      modeName, AnchorHorz.Right, AnchorVert.Center)


  def draw(var stor : PropStorage&)
    return if hero == null

    Radar`foreach_visible_target() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET) && target.isSelected
        hasLockedTarget = true
        let azRel = get_radar_hud_has_azimuth_scale() ? target.azimuthRel : 0.5
        lockedAzX = (azRel * 2.0 - 1.0) * scanHW()

    setFullCanvasViewport()
    drawBackground()
    pushLocalAxes(float2(0.0, 0.0), float2(1.0))

    drawCentreAzimuthTick()
    drawRangeRingsAndLabels(stor)

    if get_radar_hud_is_visible()
      drawGround()
      if !hasLockedTarget
        drawSweep(stor)
      drawRangeGate()
      drawTargets()

    drawAircraftSilhouette()
    drawModeLabel()

    popAxes()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; var props : PropStorage&)
  new MirageF1Radar(guiCtx, rdata, rstate, props).draw(props)

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
