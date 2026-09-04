require darg
require DagorStdGuiRender
require DagorMath
require math
require FlightModelWrap
require HeroManager
require Unit
require Sensors
require Weapon
require app
require hud
require RadarHud
require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require DagorMathUtils
require strings
require GuidanceLock
require Plane
require Localization
require %rGui.utils.weaponslots_common

let rangeScaleMaxDefault = 10.0
let dangerousAltThreshold = 350.0

struct PropStorage
  fontId : int
  fontSize : int = 18

class Component : Canvas
  isValid : bool = false
  unit : Unit? = null
  fmw : FlightModelWrap? = null

  heading : float = 0.0
  altitude : float = 0.0
  ias : float = 0.0
  gLoad : float = 0.0

  hasTrackedTarget : bool = false
  trackedTargetVisible : bool = false
  trackedTargetAbsPos : float2
  trackedTargetDist : float = 0.0

  hasLockedTarget : bool = false
  lockedTargetAbsPos : float2
  isLockAfterLaunch : bool = false

  showLaunchZone : bool = false
  launchDistMin : float = 0.0
  launchDistMax : float = 0.0
  inLaunchZone : bool = false

  weaponName : string = ""
  hasWeapon : bool = false

  rangeScaleMax : float = rangeScaleMaxDefault
  radarActive : bool = false
  radarAzMin : float = -1.0
  radarAzMax : float = 1.0
  radarAzSaved : bool = false

  // S14-S21 pylon data
  // screen L->R: idx 11,10,9,8,4,3,2,1
  pylonAmmo : int[8]
  pylonHasWeapon : bool[8]
  pylonSelected : bool[8]

  wc : WeaponController? = null
  appRef : AcesApp? = null
  ws : WeaponSlots? = null

  defaultFontSize : int = 18
  baseLineW : float = 2.0
  axisRatioYX : float = 1.0

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    unit = get_watched_not_delayed_hero()
    fmw = as_fmw(unit)
    return if fmw == null || fmw.cockpit == null

    heading = norm_ang_deg((dir_to_angles(unit.unitTm[0]).x + PI * 0.5) * radToDeg)
    altitude = unit.unitTm[3].y - get_app().currentScene.waterLevel
    ias = fmw.ias * MPS_TO_KPH
    gLoad = float(fmw.fm.localAccel.y) / 9.81 + 1.0

    // radar target via world_to_hmd_screen
    using() <| $(var target : TargetOfInterest#)
      if unit.sensors.getSelectedTargetOfInterest(unit.detector, target)
        hasTrackedTarget = true
        trackedTargetDist = target.distance
        let pos = target.from + target.dirNorm * target.distance
        var hmdPos : float2
        if world_to_hmd_screen(pos, hmdPos)
          trackedTargetVisible = true
          trackedTargetAbsPos = hmdPos

    // fallback: radar target distance when TOI not available
    if !hasTrackedTarget
      let radarDistRel = get_radar_hud_target_distance()
      if radarDistRel > 0.0
        let radarDistMax = get_radar_hud_distance_max()
        if radarDistMax > 0.0
          hasTrackedTarget = true
          trackedTargetDist = radarDistRel * radarDistMax * 1000.0

    let aamLockState = get_aam_guidance_lock_state()
    let guidanceType = get_cur_weapon_guidance_type()
    let lockOk = aamLockState == GuidanceLockState.RESULT_TRACKING || aamLockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH
    let guidanceOk = guidanceType == GuidanceType.TYPE_OPTICAL || guidanceType == GuidanceType.TYPE_SARH || guidanceType == GuidanceType.TYPE_ARH
    if lockOk && guidanceOk
      hasLockedTarget = get_aam_tracker_visible()
      lockedTargetAbsPos = hasLockedTarget ? get_screen_aam_tracker_pos() : trackedTargetAbsPos
      isLockAfterLaunch = aamLockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH

    let hudWpnName = get_hud_cur_weapon_name()
    if hudWpnName != ""
      hasWeapon = true
      weaponName = loc(hudWpnName)

    // S14-S21 weapon slots
    wc = unit.weap
    if wc != null
      appRef = get_app()
      ws = new WeaponSlots(unit, appRef, fmw, wc)
      for wpnIdx in 0 .. ws.length()
        if unit.slotIdByWeaponId[wpnIdx] <= 0
          continue
        let slot = ws.getWeaponSlot(wpnIdx)
        let slotId = slot.slot
        var pi = -1
        if slotId == 11
          pi = 0
        elif slotId == 10
          pi = 1
        elif slotId == 9
          pi = 2
        elif slotId == 8
          pi = 3
        elif slotId == 4
          pi = 4
        elif slotId == 3
          pi = 5
        elif slotId == 2
          pi = 6
        elif slotId == 1
          pi = 7
        if pi >= 0
          pylonAmmo[pi] += slot.curAmmo
          pylonHasWeapon[pi] = slot.maxAmmo > 0
          if slot.selected
            pylonSelected[pi] = true

    let radarDistMaxKm = get_radar_hud_distance_max()
    if radarDistMaxKm > 0.0
      rangeScaleMax = radarDistMaxKm
    else
      rangeScaleMax = rangeScaleMaxDefault

    showLaunchZone = hasTrackedTarget && get_radar_hud_aam_launch_zone_visible()
    if showLaunchZone
      launchDistMin = get_radar_hud_aam_launch_zone_dist_min() * rangeScaleMax * 1000.0
      launchDistMax = get_radar_hud_aam_launch_zone_dist_max() * rangeScaleMax * 1000.0
      if launchDistMin > 0.0 && launchDistMax > 0.0
        inLaunchZone = trackedTargetDist >= launchDistMin && trackedTargetDist <= launchDistMax

    radarActive = get_radar_hud_is_emitting()
    if radarActive && !hasTrackedTarget
      radarAzMin = get_radar_hud_scan_azimuth_min()
      radarAzMax = get_radar_hud_scan_azimuth_max()
      radarAzSaved = true

    let baseCol = *fmw.cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS)
    let dimCol = E3DCOLOR(Color4(float4(Color4(baseCol)) * 0.5))
    setColor(dimCol)
    baseLineW = max(floor(3.0 * fmw.cockpit.ilsLineWidthScale) - 1.0, 1.0)
    setLineWidth(baseLineW)
    setFont(props.fontId)
    setScale(float2(canvasSize.y))
    defaultFontSize = floori(20.0 * float(rdata.size.y) / 1080.0)
    setFontSize(defaultFontSize)
    isValid = true


  // S2 - sight ring
  def drawSightRing()
    drawCircle(float2(0.0, 0.0), 0.06)


  // S3 - altitude (top right)
  def drawAltitude()
    drawStrAnchored(float2(0.27, -0.3), "{roundi(altitude)}", AnchorHorz.Left, AnchorVert.Center)


  // S4 - heading (top center)
  def drawHeading()
    let hdg = roundi(norm_ang_deg(heading))
    drawStrAnchored(float2(0.0, -0.42), "{hdg}", AnchorHorz.Center, AnchorVert.Center)


  // S5 - speed (top left)
  def drawSpeed()
    drawStrAnchored(float2(-0.27, -0.3), "{roundi(ias)}", AnchorHorz.Right, AnchorVert.Center)


  // S6 - g-load (bottom left)
  def drawGLoad()
    let gStr = "G {fmt(":.1f", gLoad)}"
    drawStrAnchored(float2(-0.18, 0.3), gStr, AnchorHorz.Right, AnchorVert.Center)


  // S8 - weapon type (bottom right)
  def drawWeaponType()
    if !hasWeapon
      return
    drawStrAnchored(float2(0.27, 0.3), weaponName, AnchorHorz.Left, AnchorVert.Center)


  // S9 - range scale (ils31 style: vertical line, 6 ticks, arrow, launch zone)
  def drawRangeScale()
    let scaleX = -0.24
    let scaleTop = -0.24
    let scaleBot = 0.24
    let scaleH = scaleBot - scaleTop
    let tickLen = 0.0165

    // vertical line
    drawLine(float2(scaleX, scaleTop), float2(scaleX, scaleBot))
    // 6 ticks (0%, 20%, 40%, 60%, 80%, 100%) — both sides for top/bottom, right for middle
    drawLine(float2(scaleX - tickLen, scaleTop), float2(scaleX + tickLen, scaleTop))
    drawLine(float2(scaleX, scaleTop + scaleH * 0.2), float2(scaleX + tickLen, scaleTop + scaleH * 0.2))
    drawLine(float2(scaleX, scaleTop + scaleH * 0.4), float2(scaleX + tickLen, scaleTop + scaleH * 0.4))
    drawLine(float2(scaleX, scaleTop + scaleH * 0.6), float2(scaleX + tickLen, scaleTop + scaleH * 0.6))
    drawLine(float2(scaleX, scaleTop + scaleH * 0.8), float2(scaleX + tickLen, scaleTop + scaleH * 0.8))
    drawLine(float2(scaleX - tickLen, scaleBot), float2(scaleX + tickLen, scaleBot))

    // labels: max distance top, "0" bottom
    drawStrAnchored(float2(scaleX - 0.015, scaleTop), "{roundi(rangeScaleMax)}", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(scaleX - 0.015, scaleBot), "0", AnchorHorz.Right, AnchorVert.Center)

    // launch zone marks (min/max distance as thick horizontal bars)
    if showLaunchZone && launchDistMax > 0.0
      let launchBarLen = tickLen + 0.025
      let minT = clamp(launchDistMin / (rangeScaleMax * 1000.0), 0.0, 1.0)
      let maxT = clamp(launchDistMax / (rangeScaleMax * 1000.0), 0.0, 1.0)
      let minY = scaleBot - minT * scaleH
      let maxY = scaleBot - maxT * scaleH
      setLineWidth(2.5)
      drawLine(float2(scaleX, maxY), float2(scaleX + launchBarLen, maxY))
      drawLine(float2(scaleX, minY), float2(scaleX + launchBarLen, minY))
      setLineWidth(1.5)

    // target distance arrow (ils31 style: arrowhead touching tick ends)
    if !hasTrackedTarget
      return
    let distKm = trackedTargetDist * 0.001
    let t = clamp(distKm / rangeScaleMax, 0.0, 1.0)
    let arrowY = scaleBot - t * scaleH
    let arrowTip = scaleX + tickLen
    let arrowBack = arrowTip + 0.02
    let arrowTail = arrowTip + 0.05
    let arrowHH = 0.010
    // arrowhead
    drawLine(float2(arrowTip, arrowY), float2(arrowBack, arrowY - arrowHH))
    drawLine(float2(arrowTip, arrowY), float2(arrowBack, arrowY + arrowHH))
    // tail
    drawLine(float2(arrowBack, arrowY - arrowHH), float2(arrowBack, arrowY - arrowHH * 0.5))
    drawLine(float2(arrowBack, arrowY - arrowHH * 0.5), float2(arrowTail, arrowY - arrowHH * 0.5))
    drawLine(float2(arrowBack, arrowY + arrowHH), float2(arrowBack, arrowY + arrowHH * 0.5))
    drawLine(float2(arrowBack, arrowY + arrowHH * 0.5), float2(arrowTail, arrowY + arrowHH * 0.5))


  // S10 - launch permission (shown when target in launch zone)
  def drawLaunchPermission()
    if !inLaunchZone && !hasLockedTarget
      return
    drawStrAnchored(float2(0.0, 0.12), "ПР", AnchorHorz.Center, AnchorVert.Top)


  // S11 - tracked target diamond (world-linked via world_to_hmd_screen)
  def drawTargetMark()
    if !trackedTargetVisible
      return
    let p = toRelPos(trackedTargetAbsPos)
    let sz = 0.017
    drawLine(float2(p.x, p.y - sz), float2(p.x + sz, p.y))
    drawLine(float2(p.x + sz, p.y), float2(p.x, p.y + sz))
    drawLine(float2(p.x, p.y + sz), float2(p.x - sz, p.y))
    drawLine(float2(p.x - sz, p.y), float2(p.x, p.y - sz))


  // S11 - locked target mark (square around diamond, crossed after launch)
  def drawLockedTargetMark()
    if !hasLockedTarget
      return
    let p = toRelPos(lockedTargetAbsPos)
    let sz = 0.022
    drawLine(float2(p.x - sz, p.y - sz), float2(p.x + sz, p.y - sz))
    drawLine(float2(p.x + sz, p.y - sz), float2(p.x + sz, p.y + sz))
    drawLine(float2(p.x + sz, p.y + sz), float2(p.x - sz, p.y + sz))
    drawLine(float2(p.x - sz, p.y + sz), float2(p.x - sz, p.y - sz))
    if isLockAfterLaunch
      drawLine(float2(p.x - sz, p.y - sz), float2(p.x + sz, p.y + sz))
      drawLine(float2(p.x + sz, p.y - sz), float2(p.x - sz, p.y + sz))


  // S7 - dangerous altitude (arrow up below center)
  def drawDangerousAlt()
    if altitude >= dangerousAltThreshold
      return
    let cx = 0.0
    let tipY = 0.14
    let baseY = 0.21
    let headW = 0.014
    let neckY = 0.17
    // shaft (vertical line)
    drawLine(float2(cx, neckY), float2(cx, baseY))
    // arrowhead (filled triangle)
    setFillColor(color)
    drawFilledPoly(to_array_move(fixed_array(
      float2(cx, tipY),
      float2(cx + headW, neckY),
      float2(cx - headW, neckY))))
    setFillColor(E3DCOLOR(0u))


  // S12 - radar scan zone (aircraft-linked)
  def drawRadarScanZone()
    if !radarActive
      return
    let azScale = 0.15
    let leftX = radarAzMin * azScale
    let rightX = radarAzMax * azScale
    let top = -0.3
    let bot = 0.3
    drawLine(float2(leftX, top), float2(leftX, bot))
    drawLine(float2(rightX, top), float2(rightX, bot))


  // S14-S21 - weapon pylons (short ticks + ammo count above)
  def drawPylons()
    let pylonY = 0.39
    let step = 0.045
    let tickLen = 0.01
    let tickGap = 0.006
    for i in range(8)
      let px = (float(i) - 3.5) * step
      if !pylonHasWeapon[i]
        continue
      let cnt = pylonAmmo[i]
      if cnt <= 0
        continue
      drawStrAnchored(float2(px, pylonY - 0.02), "{cnt}", AnchorHorz.Center, AnchorVert.Bottom)
      if cnt > 9
        drawLine(float2(px - tickLen, pylonY), float2(px + tickLen, pylonY))
      else
        let drawCnt = cnt
        let totalW = float(drawCnt) * tickLen + float(drawCnt - 1) * tickGap
        let startX = px - totalW * 0.5
        for j in range(drawCnt)
          let tx = startX + float(j) * (tickLen + tickGap)
          drawLine(float2(tx, pylonY), float2(tx + tickLen, pylonY))


  def draw()
    return if !isValid

    pushLocalAxes(float2(0.0), float2(0.67, 0.67))
    setFullCanvasViewport()

    drawSightRing()
    drawAltitude()
    drawHeading()
    drawSpeed()
    drawGLoad()
    drawWeaponType()
    drawRangeScale()
    drawLaunchPermission()
    drawPylons()

    drawTargetMark()
    drawLockedTargetMark()

    drawDangerousAlt()
    drawRadarScanZone()

    restoreViewport()
    popAxes()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.fontSize = getInt(props, "fontSize", 18)
