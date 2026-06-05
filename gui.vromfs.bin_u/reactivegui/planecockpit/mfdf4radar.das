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
require strings
require app
require Sensors

// ── Storage ──────────────────────────────────────────────────
struct CanvasParams
  fontId : int = 0
  vignette : Picture? = null

// ── Visual properties (APQ-120 style) ────────────────────────
struct Props
  bgColor : E3DCOLOR = E3DCOLOR(0xFF050D05)
  phosphorColor : E3DCOLOR = E3DCOLOR(0xFF00CC22)
  phosphorDim : E3DCOLOR = E3DCOLOR(0xFF006611)
  gridColor : E3DCOLOR = E3DCOLOR(0xFF00AA1A)
  markingsColor : E3DCOLOR = E3DCOLOR(0xFF00BB22)
  amberColor : E3DCOLOR = E3DCOLOR(0xFFCC6622)

  radarBoxHalfSize : float2 = float2(0.50, 0.50)
  radarBoxPos : float2 = float2(0.0, 0.0)

  elScaleWidth : float = 0.06

  acquisitionRadius : float = 0.025
  readoutFontSize : int = 20
  markingsFontSize : int = 16
  gridLineWidth : float = 1.5
  elementsLineWidth : float = 2.5
  markingsLineWidth : float = 1.0

// ══════════════════════════════════════════════════════════════
//  APQ-120 radar display for F-4 Phantom II
// ══════════════════════════════════════════════════════════════
class F4Radar : Canvas
  props : Props = Props()

  lt : float2 = float2(0.0)
  rb : float2 = float2(0.0)

  hero : Unit?
  fmw : FlightModelWrap?

  def F4Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; inParams : CanvasParams&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    setFont(inParams.fontId)
    lt = props.radarBoxPos - props.radarBoxHalfSize
    rb = props.radarBoxPos + props.radarBoxHalfSize
    hero = get_watched_not_delayed_hero()
    fmw = as_fmw(hero)

  // ── Coordinate helpers ───────────────────────────────────
  def azimuthRelToX(azRel : float)
    return lerp(lt.x, rb.x, azRel)

  def azimuthDegToX(azDeg : float)
    let halfDeg = (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * radToDeg * 0.5
    if halfDeg < 0.1
      return props.radarBoxPos.x
    return cvt(azDeg, -halfDeg, halfDeg, lt.x, rb.x)

  def distRelToY(distRel : float)
    return lerp(rb.y, lt.y, distRel)

  def toRadarPos(azRel : float; distRel : float)
    return float2(azimuthRelToX(azRel), distRelToY(distRel))

  // ── Background ───────────────────────────────────────────
  def drawBackground()
    setFillColor(props.bgColor)
    setColor(props.bgColor)
    drawBox(float2(-0.5), float2(0.5))

  // ── Grid ─────────────────────────────────────────────────
  def drawGrid()
    setColor(props.gridColor)
    setLineWidth(props.gridLineWidth)

    let w = rb.x - lt.x
    let h = rb.y - lt.y

    let y1 = lt.y + h * 0.20
    let y2 = lt.y + h * 0.40
    let y3 = lt.y + h * 0.60
    let y4 = lt.y + h * 0.80

    drawLine(float2(lt.x, y1), float2(rb.x, y1))
    drawLine(float2(lt.x, y2), float2(rb.x, y2))
    drawLine(float2(lt.x, y3), float2(rb.x, y3))
    drawLine(float2(lt.x, y4), float2(rb.x, y4))

    let xL = lt.x + w * 0.25
    drawLine(float2(xL, lt.y), float2(xL, rb.y))

    let xR = lt.x + w * 0.75
    drawLine(float2(xR, lt.y), float2(xR, rb.y))

    let xC = lt.x + w * 0.50
    drawLine(float2(xC, lt.y), float2(xC, y1))
    drawLine(float2(xC, y1), float2(xC, y2))
    drawLine(float2(xC, y3), float2(xC, y4))
    drawLine(float2(xC, y4), float2(xC, rb.y))

  // ── Top readouts ─────────────────────────────────────────
  def drawTopReadouts()
    setColor(props.phosphorColor)
    setFontSize(props.readoutFontSize)

    let w = rb.x - lt.x
    let xL = lt.x + w * 0.25
    let xR = lt.x + w * 0.75

    let rangeMax = get_radar_hud_distance_max()
    if rangeMax > 0.0
      let rangeKm = floori(rangeMax)
      drawStrAnchored(float2(xL + 0.07, lt.y + 0.07), fmt(":d", rangeKm), AnchorHorz.Center, AnchorVert.Bottom)

    if hero != null && fmw != null
      let heading = atan2(hero.unitTm[0].x, hero.unitTm[0].z)
      var headDeg = heading * radToDeg
      if headDeg < 0.0
        headDeg += 360.0
      drawStrAnchored(float2(xR - 0.07, lt.y + 0.07), fmt(":04d", floori(headDeg)), AnchorHorz.Center, AnchorVert.Bottom)

  // ── Elevation scale (right side) ─────────────────────────
  def drawElevationScale()
    let elX = rb.x + 0.015
    let topY = lt.y
    let botY = rb.y
    let cenY = props.radarBoxPos.y

    setColor(props.amberColor)
    setFontSize(props.markingsFontSize)
    setLineWidth(props.markingsLineWidth)

    let elMin = get_radar_hud_elevation_min()
    let elMax = get_radar_hud_elevation_max()
    let elCur = get_radar_hud_elevation()
    var elY = cenY
    if abs(elMax - elMin) > 0.001
      let elRel = cvt(elCur, elMin, elMax, 0.0, 1.0)
      elY = lerp(botY, topY, elRel)

    let brkH = 0.015
    let brkW = 0.02
    drawLine(float2(elX, elY - brkH), float2(elX, elY + brkH))
    drawLine(float2(elX, elY), float2(elX + brkW, elY))
    drawLine(float2(elX, elY - brkH), float2(elX + brkW * 0.4, elY - brkH))
    drawLine(float2(elX, elY + brkH), float2(elX + brkW * 0.4, elY + brkH))

    setColor(props.markingsColor)
    setFontSize(props.markingsFontSize)
    let numX = rb.x + 0.02

    drawStrAnchored(float2(numX, topY), "60", AnchorHorz.Left, AnchorVert.Center)
    let y30t = lerp(topY, cenY, 0.5)
    drawStrAnchored(float2(numX, y30t), "30", AnchorHorz.Left, AnchorVert.Center)
    let y30b = lerp(cenY, botY, 0.5)
    drawStrAnchored(float2(numX, y30b), "30", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(numX, botY), "60", AnchorHorz.Left, AnchorVert.Center)

  // ── Left Y marker ────────────────────────────────────────
  def drawLeftMarker()
    let elMin = get_radar_hud_elevation_min()
    let elMax = get_radar_hud_elevation_max()
    let elCur = get_radar_hud_elevation()
    var elY = props.radarBoxPos.y
    if abs(elMax - elMin) > 0.001
      let elRel = cvt(elCur, elMin, elMax, 0.0, 1.0)
      elY = lerp(rb.y, lt.y, elRel)

    setColor(props.amberColor)
    setLineWidth(props.markingsLineWidth)

    let lx = lt.x - 0.015
    let brkH = 0.015
    let brkW = 0.02
    drawLine(float2(lx, elY - brkH), float2(lx, elY + brkH))
    drawLine(float2(lx - brkW, elY), float2(lx, elY))
    drawLine(float2(lx - brkW * 0.4, elY - brkH), float2(lx, elY - brkH))
    drawLine(float2(lx - brkW * 0.4, elY + brkH), float2(lx, elY + brkH))

  // ── Azimuth markings ─────────────────────────────────────
  def drawAzimuthMarkings()
    setColor(props.markingsColor)
    setFontSize(props.markingsFontSize)
    setLineWidth(props.markingsLineWidth)

    let botY = rb.y
    let tickLen = 0.018
    let halfDeg = (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * radToDeg * 0.5

    let cx = props.radarBoxPos.x
    drawLine(float2(cx, botY), float2(cx, botY + tickLen))

    if halfDeg >= 30.0
      let x30r = azimuthDegToX(30.0)
      let x30l = azimuthDegToX(-30.0)
      drawLine(float2(x30r, botY), float2(x30r, botY + tickLen))
      drawStrAnchored(float2(x30r, botY + tickLen + 0.005), "30", AnchorHorz.Center, AnchorVert.Top)
      drawLine(float2(x30l, botY), float2(x30l, botY + tickLen))
      drawStrAnchored(float2(x30l, botY + tickLen + 0.005), "30", AnchorHorz.Center, AnchorVert.Top)

  // ── Ground clutter ───────────────────────────────────────
  def drawGround()
    let pos = toAbsPos(lt)
    let size = toAbsXY(rb - lt)
    render_ground_reflection(*ctx, size, pos, props.phosphorDim, int2(20, 10), true)

  // ── Horizon line ─────────────────────────────────────────
  def drawHorizon()
    if fmw == null
      return
    setColor(props.phosphorDim)
    setLineWidth(3.0)
    let rotation = -fmw.roll * degToRad
    setRotation(props.radarBoxPos, rotation)
    let halfLen = 0.48
    let gap = 0.15
    drawLine(props.radarBoxPos - float2(halfLen, 0.0), props.radarBoxPos - float2(gap, 0.0))
    drawLine(props.radarBoxPos + float2(gap, 0.0), props.radarBoxPos + float2(halfLen, 0.0))
    resetViewTm()

  // ── B-sweep ──────────────────────────────────────────────
  def drawBSweep()
    var hasLock = false
    Radar`foreach_visible_target() <| $(var target)
      if target.isSelected
        hasLock = true
    if hasLock
      return
    setFillColor(props.phosphorColor)
    setColor(E3DCOLOR(0x00000000))
    setLineWidth(props.elementsLineWidth)
    let azRel = get_radar_hud_azimuth()
    let x = azimuthRelToX(azRel)
    drawGradientLine(float2(x, lt.y), float2(x, rb.y), 2.0, 6.0)

  // ── Acquisition symbol ───────────────────────────────────
  def drawAcquisitionAt(center : float2; halfExtents : float2)
    setColor(props.phosphorColor)
    setFillColor(E3DCOLOR(0x00000000))
    setLineWidth(props.elementsLineWidth)

    drawLine(float2(center.x - halfExtents.x, center.y - halfExtents.y),
             float2(center.x - halfExtents.x, center.y + halfExtents.y))
    drawLine(float2(center.x + halfExtents.x, center.y - halfExtents.y),
             float2(center.x + halfExtents.x, center.y + halfExtents.y))

  def drawAcquisitionSymbol()
    if !get_radar_hud_cue_visible()
      return

    let azRange = max(0.0, get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
    let cueAzHalfWidthRel = get_radar_hud_cue_azimuth_half_width_rel()
    let cueAz = get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() - cueAzHalfWidthRel * azRange, 0.0)
    let halfDistGate = 0.5 * get_radar_hud_cue_dist_width_rel()
    let distRel = halfDistGate + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1.0 - 2.0 * halfDistGate)

    let halfExtents = float2(cueAzHalfWidthRel * (rb.x - lt.x), halfDistGate * (lt.y - rb.y))
    drawAcquisitionAt(float2(azimuthDegToX(cueAz * radToDeg), distRelToY(distRel)), halfExtents)

  // ── Elevation strobe ─────────────────────────────────────
  def drawElevationStrobe()
    let elX = rb.x - 0.01
    let topY = lt.y
    let botY = rb.y

    let elMin = get_radar_hud_elevation_min()
    let elMax = get_radar_hud_elevation_max()
    let elCur = get_radar_hud_elevation()
    if abs(elMax - elMin) < 0.001
      return

    let elRel = cvt(elCur, elMin, elMax, 0.0, 1.0)
    let y = lerp(botY, topY, elRel)

    setColor(props.phosphorColor)
    setLineWidth(props.elementsLineWidth)

    let brkH = 0.012
    let brkW = 0.015
    drawLine(float2(elX, y - brkH), float2(elX, y + brkH))
    drawLine(float2(elX, y), float2(elX + brkW, y))

  // ── Range gate marker ────────────────────────────────────
  def drawRangeGateMarker()
    if get_radar_hud_cue_visible() == false
      return

    let halfDistGate = 0.5 * get_radar_hud_cue_dist_width_rel()
    let distRel = halfDistGate + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1.0 - 2.0 * halfDistGate)
    let y = distRelToY(distRel)

    setColor(props.phosphorColor)
    setLineWidth(props.elementsLineWidth)

    let markerX = rb.x - 0.04
    let markerW = 0.025
    drawLine(float2(markerX, y), float2(markerX + markerW, y))

  // ── Targets ──────────────────────────────────────────────
  def drawTargets()
    var hasDetected = false
    Radar`foreach_visible_target() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        let signalRel = target.signalRel < 0.01 ? 0.0 : cvt(target.signalRel, 0.05, 1.0, 0.3, 1.0)
        let alpha = (1.0 - target.ageRel) * signalRel
        let col4 = float4(Color4(props.phosphorColor)) * alpha
        let col = E3DCOLOR(Color4(col4))

        let tPos = toRadarPos(target.azimuthRel, target.distanceRel)

        setFillColor(col)
        setColor(E3DCOLOR(0x00000000))
        let halfW = float2(target.azimuthWidthRel, target.distanceWidthRel) * (lt - rb) * 0.5
        drawBox(tPos - halfW, tPos + halfW)

        if target.isSelected
          setColor(props.phosphorColor)
          setLineWidth(props.elementsLineWidth)
          setFillColor(E3DCOLOR(0x00000000))

          if get_radar_hud_aam_launch_zone_visible()
            let distMax = get_radar_hud_aam_launch_zone_dist_max()
            let dgftMax = get_radar_hud_aam_launch_zone_dist_dgft_max()
            let distMin = get_radar_hud_aam_launch_zone_dist_min()

            let strobeHalfW = 0.04

            if distMax > 0.0
              let yMax = distRelToY(distMax)
              drawLine(float2(tPos.x - strobeHalfW, yMax), float2(tPos.x + strobeHalfW, yMax))

            if dgftMax > 0.0
              let yDgft = distRelToY(dgftMax)
              drawLine(float2(tPos.x - strobeHalfW, yDgft), float2(tPos.x + strobeHalfW, yDgft))

            if distMin > 0.0
              let yMin = distRelToY(distMin)
              drawLine(float2(tPos.x - strobeHalfW, yMin), float2(tPos.x + strobeHalfW, yMin))

        if target.isDetected
          hasDetected = true
          let cueHalfH = 0.5 * get_radar_hud_cue_dist_width_rel() * (lt.y - rb.y)
          drawAcquisitionAt(tPos, float2(abs(halfW.x) * 1.5, cueHalfH))

    if !hasDetected
      drawAcquisitionSymbol()

  // ── Aim point (C-scope overlay) ──────────────────────────
  def drawAimPoint()
    if hero == null
      return

    var aimPosWorld = float3(0.0)
    var hasAim = false

    get_radar_hud_screen_targets() <| $(targets : array<RadarScreenTarget> const#)
      for target in targets
        if !hasAim && target.isTracked && target.hasAimPos && !target.forIlsOnly
          aimPosWorld = target.aimPos
          hasAim = true

    if !hasAim
      return

    let dir = aimPosWorld - hero.pos
    let localDir = quat_mul_vec(math::quat(inverse(hero.unitTm)), dir)

    let azimuth = atan2(localDir.x, localDir.z) - PI_2
    let elevation = atan2(localDir.y, localDir.xz.length())

    let elevMax = PI / 3.0
    let azimuthRel = cvt(azimuth, get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)
    let elevationRel = cvt(elevation, -elevMax, elevMax, 0.0, 1.0)

    let aimX = azimuthRelToX(azimuthRel)
    let aimY = lerp(rb.y, lt.y, elevationRel)

    setColor(props.phosphorColor)
    setFillColor(props.phosphorColor)
    setLineWidth(props.elementsLineWidth)

    let halfSize = 0.02
    drawBox(float2(aimX - halfSize, aimY - halfSize),
            float2(aimX + halfSize, aimY + halfSize))

    setFillColor(E3DCOLOR(0x0))

    let aseDist = get_radar_hud_aam_launch_zone_dist()
    let aseDistMin = get_radar_hud_aam_launch_zone_dist_min()
    let aseDistMax = get_radar_hud_aam_launch_zone_dist_max()
    if aseDistMax > aseDistMin && aseDistMax > 0.0
      let aseMin = 0.03
      let aseMax = 0.20
      let t = clamp((aseDist - aseDistMin) / (aseDistMax - aseDistMin), 0.0, 1.0)
      let aseRadius = lerp(aseMin, aseMax, t)
      drawEllipse(props.radarBoxPos, float2(aseRadius))

  // ── Vignette ─────────────────────────────────────────────
  def drawVignette(vignette : darg::Picture?)
    if vignette == null
      return
    setColor(E3DCOLOR(0xFFFFFFFF))
    let s = 0.65
    drawPicture(float2(-s, -s), float2(s * 2.0, s * 2.0), vignette)

  // ══════════════════════════════════════════════════════════
  //  MAIN DRAW
  // ══════════════════════════════════════════════════════════
  def drawMFD(canvasParams : CanvasParams&)
    setFullCanvasViewport()
    drawBackground()

    setViewport(lt, rb)
    setLineWidth(props.elementsLineWidth)
    drawGrid()
    drawHorizon()

    if get_radar_hud_is_visible()
      drawGround()
      drawBSweep()
      drawElevationStrobe()
      drawRangeGateMarker()
      drawTargets()
      drawAimPoint()

    restoreViewport()

    drawTopReadouts()
    drawAzimuthMarkings()
    drawElevationScale()
    drawLeftMarker()

    drawVignette(canvasParams.vignette)
    restoreViewport()


// ── Exports ──────────────────────────────────────────────────
[export]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  new F4Radar(ctx, rdata, rstate, data).drawMFD(data)

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.vignette = props |> getPicture("vignette")
