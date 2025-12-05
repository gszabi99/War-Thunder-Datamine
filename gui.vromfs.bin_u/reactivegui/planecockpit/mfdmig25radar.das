require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.weaponslots_common
require %rGui.utils.radar_common

require darg
require DagorStdGuiRender
require DagorMath
require DagorSystem
require FlightModelWrap
require FlightControl
require RadarHud
require strings
require Unit
require HeroManager
require app
require DagorMathUtils
require GamePhys
require hud
require FlightModelWrap
require Plane
require math
require Weapon
require GuidanceLock

let borderScalePos : float2 = float2(0.3, 0.2)
let borderScaleSize : float2 = float2(0.02, -0.5)

let numOfDashes = 7
let weaponSlotCount = 4

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1

class Component : Canvas
  hero : Unit?
  fmw : FlightModelWrap?

  ws : WeaponSlots? = null

  baseColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : CanvasParams&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    fmw = hero.as_fmw()
    return if fmw == null

    ws = new WeaponSlots(hero, get_app(), fmw, hero.weap)

    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFont(props.fontId)
    setFontSize(30)

    setColor(props.color)
    setFillColor(props.color)
    baseColor = props.color


  def draw()
    drawAltitude()
    drawRange()
    drawAttitude()
    drawWeapons()

    drawRadar()

  def drawAltitude()
    let numOfDashes = 7
    let maxAltitude = 30000.0
    let minAltitude = 1500.0

    let pos = borderScalePos
    let size = borderScaleSize
    pushLocalAxes(pos, size)

    drawLine(float2(1.0, 0.0), float2(1.0, 1.0))
    for i in range(numOfDashes + 1)
      let t = float(i) / float(numOfDashes)
      drawLine(float2(0.6, t), float2(1.0, t))

    let altitude = fmw.fm.currentAlt
    let maxAlt = altitude > minAltitude ? maxAltitude : minAltitude
    let t = altitude / maxAlt
    drawLine(float2(0.0, t), float2(0.5, t))

    let maxAltText = "{floori(maxAlt)}"
    drawStrAnchored(float2(0.0, 1.0 - toRelY(*ctx |> hdpx(5.0))), maxAltText, AnchorHorz.Right, AnchorVert.Bottom)
    drawStrAnchored(float2(1.5, 0.0), "0", AnchorHorz.Left, AnchorVert.Bottom)

    popAxes()


  def drawRange()
    let pos = borderScalePos * float2(-1.0, 1.0)
    let size = borderScaleSize * float2(-1.0, 1.0)
    pushLocalAxes(pos, size)

    drawLine(float2(1.0, 0.0), float2(1.0, 1.0))
    for i in range(numOfDashes + 1)
      let t = float(i) / float(numOfDashes)
      drawLine(float2(0.6, t), float2(1.0, t))

    if get_radar_hud_is_visible() && get_radar_hud_is_emitting() && get_radar_hud_has_distance_scale()
      drawStrAnchored(float2(0.0, 1.0), "{get_radar_hud_distance_max()}", AnchorHorz.Left, AnchorVert.Bottom)

    if get_radar_hud_aam_launch_zone_visible()
      let distMax = get_radar_hud_aam_launch_zone_dist_max()
      drawLine(float2(1.3, distMax), float2(0.0, distMax))

      let noEscape = get_radar_hud_aam_launch_zone_dist_dgft_min()
      drawLine(float2(0.5, noEscape), float2(0.0, noEscape))

    popAxes()


  def drawAttitude()
    let outWidth = 0.2
    let inWidth = 0.05

    let maxRoll = 70.0
    let roll = clamp(fmw.roll, -maxRoll, maxRoll) * degToRad

    let maxPitch = 20.0
    let pitch = clamp(fmw.tangage, -maxPitch, maxPitch)

    let y = pitch / maxPitch * 0.3
    setRotation(float2(0.0, y), roll)
    drawLine(float2(-outWidth, y), float2(-inWidth, y))
    drawLine(float2(outWidth, y), float2(inWidth, y))

    resetViewTm()


  def drawWeapons()
    let size = float2(borderScalePos.x * 0.8, 0.01) * canvasSize
    let pos = toAbsPos(float2(0.0, 0.3))
    pushAxes(pos, size)

    setLineWidth(5.0)

    let count = ws.length()
    var counter = 0
    for i in 0 .. count
      continue if (hero.slotIdByWeaponId[i] <= 0)
      var slot = ws.getWeaponSlot(i)
      slot.slot -= 1
      counter += 1

      continue if slot.curAmmo < 1
      continue if slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)

      let x = lerp(-1.0, 1.0, float(slot.slot) / float(weaponSlotCount))
      let p = float2(x, 0.0)
      drawDot(p)

      if slot.selected
        let textPos = float2(x, 1.0)

        let guidanceType = get_cur_weapon_guidance_type()
        let guidanceTypeCheck = guidanceType == GuidanceType.TYPE_OPTICAL || guidanceType == GuidanceType.TYPE_SARH || guidanceType == GuidanceType.TYPE_ARH
        let aamLockState = get_aam_guidance_lock_state()
        let guidanceStateCheck = aamLockState == GuidanceLockState.RESULT_TRACKING || aamLockState == GuidanceLockState.RESULT_LOCK_AFTER_LAUNCH
        let launchPermitted = guidanceTypeCheck && guidanceStateCheck

        let text = launchPermitted ? "ПР" : "{counter}"
        drawStrAnchored(textPos, text, AnchorHorz.Center, AnchorVert.Top)

    popAxes()


  def drawRadar()
    return if !get_radar_hud_visible() || !get_radar_hud_is_emitting()

    let size = float2(borderScalePos.x * 2.0, borderScaleSize.y)
    let pos = float2(-borderScalePos.x, -borderScaleSize.y * 0.5)
    pushLocalAxes(pos, size)

    drawTargets()
    drawInstantaneousAzimuth()

    if get_radar_hud_is_irst()
      drawScanZone()

    popAxes()


  def drawScanZone()
    let maxY = cvt(get_radar_hud_scan_elevation_max() + get_radar_hud_elevation_half_width(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), 0.0, 1.0)
    let minY = cvt(get_radar_hud_scan_elevation_min() - get_radar_hud_elevation_half_width(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), 0.0, 1.0)

    let maxX = cvt(get_radar_hud_scan_azimuth_max() + get_radar_hud_azimuth_half_width(), get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)
    let minX = cvt(get_radar_hud_scan_azimuth_min() - get_radar_hud_azimuth_half_width(), get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)

    let lb = float2(minX, minY)
    let rb = float2(maxX, minY)
    let lt = float2(minX, maxY)
    let rt = float2(maxX, maxY)

    let len = 0.05
    let lx = float2(len, 0.0)
    let ly = float2(0.0, len)

    drawLine(lb, lb + lx)
    drawLine(lb, lb + ly)

    drawLine(rb, rb - lx)
    drawLine(rb, rb + ly)

    drawLine(lt, lt + lx)
    drawLine(lt, lt - ly)

    drawLine(rt, rt - lx)
    drawLine(rt, rt - ly)

  def drawTargets()
    var hasDetectedTarget = false
    var hasSelectedTarget = false
    Radar`foreach_visible_target() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        var distanceRel = 0.0
        var radialWidthRel = 0.02
        if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
          distanceRel = target.distanceRel
          radialWidthRel = max(radialWidthRel, target.distanceWidthRel)

        var azimuthRel = 0.0
        var azimuthWidth = 0.0
        if get_radar_hud_has_azimuth_scale()
          azimuthRel = target.azimuthRel
          azimuthWidth = target.azimuthWidthRel

        let targetPos = float2(azimuthRel, get_radar_hud_is_irst() || target.isSelectedTargetOfInterest ? target.elevationRel : distanceRel)
        let targetWidth = float2(azimuthWidth * 0.5, radialWidthRel * 0.5)

        let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
        let alphaColor = (1. - target.ageRel) * signalRel
        let col4 = float4(Color4(baseColor)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setFillColor(col)
        setColor(col)

        if !target.isEnemy
          let y = targetPos.y + targetWidth.y + 0.012
          let l = targetPos.x - targetWidth.x
          let r = targetPos.x + targetWidth.x
          drawLine(float2(l, y), float2(r, y))

        if target.isSelected
          drawEllipse(targetPos, float2(length(targetWidth) * 0.5))
          hasSelectedTarget = true

          if target.isSelectedTargetOfInterest && get_radar_hud_has_distance_scale()
            drawLine(float2(0.0, distanceRel), float2(0.02, distanceRel))
            drawLine(float2(0.05, distanceRel), float2(0.03, distanceRel))
        else
          if get_radar_hud_has_distance_scale()
            drawBox(targetPos - targetWidth, targetPos + targetWidth)
          else
            drawEllipse(targetPos, float2(length(targetWidth) * 0.5))

        if target.isDetected || target.isSelectedTargetOfInterest
          drawCueAt(targetPos)
          hasDetectedTarget = true

    if !hasDetectedTarget && get_radar_hud_cue_visible()
      drawCue()

    if hasSelectedTarget
      drawCrossReticle(float2(0.5), float2(0.05), float2(0.02))
      drawStrAnchored(float2(0.1, 1.0), "ATK", AnchorHorz.Left, AnchorVert.Bottom)


  def drawCueAt(pos : float2)
    setColor(baseColor)
    let sizeX = get_radar_hud_cue_visible() ? get_radar_hud_cue_azimuth_half_width_rel() : 0.05
    let sizeY = get_radar_hud_cue_visible() ? get_radar_hud_cue_dist_width_rel() * 0.5 : 0.05

    if get_radar_hud_is_irst()
      let minX = pos.x - sizeX
      let maxX = pos.x + sizeX
      drawLine(float2(minX, 0.0), float2(minX, 1.0))
      drawLine(float2(maxX, 0.0), float2(maxX, 1.0))
    else
      drawLine(pos + float2(-sizeX, -sizeY), pos + float2(sizeX, -sizeY))
      drawLine(pos + float2(-sizeX, sizeY), pos + float2(sizeX, sizeY))


  def drawCue()
    let x = cvt(get_radar_hud_cue_azimuth(), -1.0, 1.0, get_radar_hud_cue_azimuth_half_width_rel(), 1.0 - get_radar_hud_cue_azimuth_half_width_rel())
    let y = cvt(get_radar_hud_cue_distance(), 0.0, 1.0, get_radar_hud_cue_dist_width_rel() * 0.5, 1.0 - get_radar_hud_cue_dist_width_rel() * 0.5)
    drawCueAt(float2(x, y))


  def drawInstantaneousAzimuth()
    return if get_radar_hud_is_irst()

    let l = get_radar_hud_azimuth() - get_radar_hud_azimuth_half_width()
    let r = get_radar_hud_azimuth() + get_radar_hud_azimuth_half_width()

    drawLine(float2(l, 0.0), float2(r, 0.0))


[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))

[export]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  new Component(ctx, rdata, rstate, data).draw()
