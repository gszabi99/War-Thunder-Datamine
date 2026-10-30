require darg
require DagorStdGuiRender
require DagorMath
require RadarHud
require strings
require HeroManager
require Unit
require Sensors
require math
require %rGui.utils.radar_common
require %rGui.utils.constants_common

// F-15EX radar display: green monochrome, sector B-scope with compass arc
let f15Green = E3DCOLOR(Color4(float4(0.0, 0.85, 0.0, 1.)))
let f15GreenDim = E3DCOLOR(Color4(float4(0.0, 0.5, 0.0, 1.)))
let f15GreenBright = E3DCOLOR(Color4(float4(0.3, 1.0, 0.3, 1.)))
let f15Blue = E3DCOLOR(Color4(float4(0.2, 0.4, 0.8, 1.)))
let f15Yellow = E3DCOLOR(Color4(float4(1.0, 0.9, 0.0, 1.)))
let f15White = E3DCOLOR(Color4(float4(1.0, 1.0, 1.0, 1.)))
let transparentColor = E3DCOLOR(Color4(float4(0., 0., 0., 0.)))

let speedMaxInv = 1.0 / 700.0

let RADAR_FONT_SIZE = 20

struct CanvasParams
  fontId : int = -1
  radarFontSize : int = 20
  useArea : float4 = float4(0., 0., 1., 1.)
  lineWidth : float = 1.

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.radarFontSize = RADAR_FONT_SIZE
  storage.useArea = float4(0.05, 0., 0.95, 1.0)
  storage.lineWidth = props |> getFloat("lineWidth", 1.)

def draw_elevation_scope(var ctx : GuiContext&; data : CanvasParams&; size : float2; frameL : float; frameT : float; frameB : float)
  let altMaxFt = 60000.0
  let scpX = frameL + size.x * 0.03
  let scpBot = frameT + (frameB - frameT) * 0.90
  let scpTop = frameT + (frameB - frameT) * 0.62
  let scpH = scpBot - scpTop
  let tickLen = size.x * 0.015
  let majorTickLen = size.x * 0.025
  let arrowW = size.x * 0.018

  // Vertical backbone line
  let vl <- to_array_move(fixed_array<float2>(float2(scpX, scpTop), float2(scpX, scpBot)))
  ctx |> render_line_aa(vl, false, data.lineWidth, float2(0., 0.), f15Green)

  // Ticks with labels: 0, 10, 20, 30, 40, 50, 60 (x1000 ft)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.radarFontSize + 4)
  var fctxElev : StdGuiFontContext
  get_font_context(fctxElev, data.fontId, 0, 0, data.radarFontSize + 4)
  for i in range(0, 7)
    let altFt = float(i) * 10000.0
    let yPos = scpBot - (altFt / altMaxFt) * scpH
    let tk <- to_array_move(fixed_array<float2>(float2(scpX, yPos), float2(scpX - majorTickLen, yPos)))
    ctx |> render_line_aa(tk, false, data.lineWidth, float2(0., 0.), f15Green)
  // Minor ticks at 5000 ft intervals
  for i in range(0, 12)
    let altFt = float(i) * 5000.0 + 5000.0
    if altFt >= altMaxFt
      continue
    if roundi(altFt) % 10000 == 0
      continue
    let yPos = scpBot - (altFt / altMaxFt) * scpH
    let tk <- to_array_move(fixed_array<float2>(float2(scpX, yPos), float2(scpX - tickLen * 0.6, yPos)))
    ctx |> render_line_aa(tk, false, data.lineWidth * 0.7, float2(0., 0.), f15GreenDim)

  // Own aircraft altitude marker (triangle pointing right)
  let hero = get_controlled_hero()
  if hero != null && !hero.isDelayed
    let ownAltFt = hero.pos.y * metrToFeet
    let ownY = scpBot - clamp(ownAltFt / altMaxFt, 0.0, 1.0) * scpH
    let ownArrow <- to_array_move(fixed_array<float2>(
      float2(scpX - arrowW, ownY - arrowW * 0.5),
      float2(scpX, ownY),
      float2(scpX - arrowW, ownY + arrowW * 0.5)))
    ctx |> render_line_aa(ownArrow, true, data.lineWidth, float2(0., 0.), f15Blue)

  // Radar scan zone top/bottom markers on altitude scale
  let distMaxKm = get_radar_hud_distance_max()
  let scanElevMin = get_radar_hud_scan_elevation_min()
  let scanElevMax = get_radar_hud_scan_elevation_max()
  if hero != null && !hero.isDelayed && distMaxKm > 0.1
    let ownAltM = hero.pos.y
    let distM = distMaxKm * 1000.0
    let scanTopAltFt = (ownAltM + distM * sin(scanElevMax)) * metrToFeet
    let scanBotAltFt = (ownAltM + distM * sin(scanElevMin)) * metrToFeet
    let scanTopY = scpBot - clamp(scanTopAltFt / altMaxFt, 0.0, 1.0) * scpH
    let scanBotY = scpBot - clamp(scanBotAltFt / altMaxFt, 0.0, 1.0) * scpH
    // Scan zone bracket lines
    let bracketW = size.x * 0.012
    let scanTopL <- to_array_move(fixed_array<float2>(float2(scpX + bracketW, scanTopY), float2(scpX, scanTopY)))
    ctx |> render_line_aa(scanTopL, false, data.lineWidth, float2(0., 0.), f15Green)
    let scanBotL <- to_array_move(fixed_array<float2>(float2(scpX + bracketW, scanBotY), float2(scpX, scanBotY)))
    ctx |> render_line_aa(scanBotL, false, data.lineWidth, float2(0., 0.), f15Green)
    // Vertical line connecting scan zone brackets
    let scanVert <- to_array_move(fixed_array<float2>(float2(scpX + bracketW, scanTopY), float2(scpX + bracketW, scanBotY)))
    ctx |> render_line_aa(scanVert, false, data.lineWidth * 0.7, float2(0., 0.), f15Green)
    // Scan zone altitude labels (kft)
    ctx |> set_color(f15White)
    let scanTopKft = roundi(scanTopAltFt / 1000.0)
    let scanTopLbl = scanTopKft <= 0 ? "O" : "O{fmt(":d", scanTopKft)}"
    let scanTopBox = get_str_bbox(scanTopLbl, scanTopLbl |> length(), fctxElev)
    ctx |> goto_xy(scpX + bracketW + size.x * 0.003, scanTopY + scanTopBox.width.y * 0.4)
    ctx |> draw_str_scaled(1.0, scanTopLbl, scanTopLbl |> length())
    let scanBotKft = roundi(scanBotAltFt / 1000.0)
    let scanBotLbl = scanBotKft <= 0 ? "O" : "O{fmt(":d", scanBotKft)}"
    let scanBotBox = get_str_bbox(scanBotLbl, scanBotLbl |> length(), fctxElev)
    ctx |> goto_xy(scpX + bracketW + size.x * 0.003, scanBotY + scanBotBox.width.y * 0.4)
    ctx |> draw_str_scaled(1.0, scanBotLbl, scanBotLbl |> length())

  // Target blips to the right of the line
  Radar`foreach_visible_target() <| $(var target)
    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      let altFt = target.height * metrToFeet
      let yPos = scpBot - clamp(altFt / altMaxFt, 0.0, 1.0) * scpH
      let blipColor = target.isSelected && target.isSelectedTargetOfInterest ? f15Yellow : f15Green
      let bh = size.y * 0.008
      let bw = size.x * 0.012
      ctx |> set_color(blipColor)
      ctx |> render_box(scpX + size.x * 0.003, yPos - bh, scpX + size.x * 0.003 + bw, yPos + bh)
      let altLabel = fmt(":03d", roundi(altFt / 100.0))
      let alb = get_str_bbox(altLabel, altLabel |> length(), fctxElev)
      ctx |> set_color(blipColor)
      ctx |> goto_xy(scpX + size.x * 0.003 + bw + size.x * 0.003, yPos + alb.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, altLabel, altLabel |> length())


def draw_target_zoom(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; barY : float)
  // Find the selected locked target
  var hasLocked = false
  var lockedLosSpeed = 0.0
  var lockedLosHorSpeed = 0.0
  var lockedHeight = 0.0
  var lockedIsEnemy = false
  var lockedIsDetected = false
  var lockedIsTracked = false

  Radar`foreach_visible_target() <| $(var target)
    if !hasLocked && target.targetType == int(RadarTargetType.TYPE_TARGET) && target.isSelected && target.isSelectedTargetOfInterest
      hasLocked = true
      lockedLosSpeed = target.losSpeed
      lockedLosHorSpeed = target.losHorSpeed
      lockedHeight = target.height
      lockedIsEnemy = target.isEnemy
      lockedIsDetected = target.isDetected
      lockedIsTracked = target.isTracked

  if !hasLocked
    return

  // Zoom box: bottom edge sits on barY, left edge starts just right of barLine end (pos.x + size.x * 0.9)
  let stripH = (pos.y + size.y) - barY
  let boxSize = stripH * 0.75
  let bx = pos.x + size.x * 0.7 + size.x * 0.01
  let by = barY - boxSize  // bottom edge on barY

  // Black fill (layer 1: background)
  ctx |> set_color(E3DCOLOR(Color4(float4(0., 0., 0., 1.))))
  ctx |> render_box(bx, by, bx + boxSize, by + boxSize)

  // White border square (layer 2: frame on top of fill)
  let border <- to_array_move(fixed_array<float2>(float2(bx, by), float2(bx + boxSize, by), float2(bx + boxSize, by + boxSize), float2(bx, by + boxSize), float2(bx, by)))
  ctx |> render_line_aa(border, false, data.lineWidth * 1.5, float2(0., 0.), f15White)

  // Center of zoom box
  let zc = float2(bx + boxSize * 0.5, by + boxSize * 0.5)
  let sqH = boxSize * 0.12  // enlarged target square half-size

  // Yellow target square
  let zsq <- to_array_move(fixed_array<float2>(
    zc + float2(-sqH, -sqH), zc + float2(sqH, -sqH),
    zc + float2(sqH, sqH), zc + float2(-sqH, sqH),
    zc + float2(-sqH, -sqH)))
  ctx |> render_line_aa(zsq, false, data.lineWidth, float2(0., 0.), f15Yellow)

  // Velocity vector
  if lockedLosSpeed < 30000.0 && (lockedLosSpeed * lockedLosSpeed + lockedLosHorSpeed * lockedLosHorSpeed) > 1.0
    let losAngle = atan2(lockedLosHorSpeed, -lockedLosSpeed)
    let vx = -sin(losAngle) * sqH * 3.0
    let vy = cos(losAngle) * sqH * 3.0
    let vline <- to_array_move(fixed_array<float2>(zc, zc + float2(vx, vy)))
    ctx |> render_line_aa(vline, false, data.lineWidth, float2(0., 0.), f15Yellow)

  // Designation cue: vertical bars left and right of target square
  let cueOffX = sqH * 1.8
  let cueHalfH = sqH * 1.2
  let cueLeft <- to_array_move(fixed_array<float2>(zc + float2(-cueOffX, -cueHalfH), zc + float2(-cueOffX, cueHalfH)))
  ctx |> render_line_aa(cueLeft, false, data.lineWidth * 1.5, float2(0., 0.), f15White)
  let cueRight <- to_array_move(fixed_array<float2>(zc + float2(cueOffX, -cueHalfH), zc + float2(cueOffX, cueHalfH)))
  ctx |> render_line_aa(cueRight, false, data.lineWidth * 1.5, float2(0., 0.), f15White)

  // NCTR info block: IFF / altitude inside the zoom box
  if lockedIsDetected || lockedIsTracked
    ctx |> set_font(data.fontId, 0, 0)
    ctx |> set_font_ht(data.radarFontSize - 2)
    var fctxNctr : StdGuiFontContext
    get_font_context(fctxNctr, data.fontId, 0, 0, data.radarFontSize - 2)

    let iffStr = lockedIsEnemy ? "HOSTILE" : "FRIEND"
    let iffColor = lockedIsEnemy ? f15Yellow : f15Green
    let altFt = roundi(lockedHeight * metrToFeet / 100.0) * 100
    let altStr = "{altFt}FT"

    let lineH = float(data.radarFontSize - 2) * 1.4
    let textX = bx + boxSize * 0.5
    // anchor two lines above the bottom edge
    let textY0 = by + boxSize - lineH * 1.18

    ctx |> set_color(iffColor)
    let iffBox = get_str_bbox(iffStr, iffStr |> length(), fctxNctr)
    ctx |> goto_xy(textX - iffBox.width.x * 0.5, textY0)
    ctx |> draw_str_scaled(1.0, iffStr, iffStr |> length())

    ctx |> set_color(f15Green)
    let altBox = get_str_bbox(altStr, altStr |> length(), fctxNctr)
    ctx |> goto_xy(textX - altBox.width.x * 0.5, textY0 + lineH * 0.7)
    ctx |> draw_str_scaled(1.0, altStr, altStr |> length())


[export, unused_argument(rstate)]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !get_radar_hud_mfd_radar_enabled()
    return

  let pos = rdata.pos + float2(data.useArea.x * rdata.size.x, data.useArea.y * rdata.size.y)
  let size = float2(rdata.size.x * (data.useArea.z - data.useArea.x), rdata.size.y * (data.useArea.w - data.useArea.y))

  // Blue dashed border frame
  let frameL = rdata.pos.x
  let frameR = rdata.pos.x + rdata.size.x
  let frameT = pos.y - rdata.size.y * 0.02
  let frameB = pos.y + size.y
  let frameW = frameR - frameL
  let frameH = frameB - frameT
  let dashLen = frameW * 0.012
  let gapLen = dashLen * 0.6
  let dashStep = dashLen + gapLen
  // Top edge
  var dx = 0.0
  while dx < frameW
    let x0 = frameL + dx
    let x1 = min(x0 + dashLen, frameR)
    let d <- to_array_move(fixed_array<float2>(float2(x0, frameT), float2(x1, frameT)))
    ctx |> render_line_aa(d, false, data.lineWidth, float2(0., 0.), f15Blue)
    dx += dashStep
  // Bottom edge
  dx = 0.0
  while dx < frameW
    let x0 = frameL + dx
    let x1 = min(x0 + dashLen, frameR)
    let d <- to_array_move(fixed_array<float2>(float2(x0, frameB), float2(x1, frameB)))
    ctx |> render_line_aa(d, false, data.lineWidth, float2(0., 0.), f15Blue)
    dx += dashStep
  // Left edge
  var dy = 0.0
  while dy < frameH
    let y0 = frameT + dy
    let y1 = min(y0 + dashLen, frameB)
    let d <- to_array_move(fixed_array<float2>(float2(frameL, y0), float2(frameL, y1)))
    ctx |> render_line_aa(d, false, data.lineWidth, float2(0., 0.), f15Blue)
    dy += dashStep
  // Right edge
  dy = 0.0
  while dy < frameH
    let y0 = frameT + dy
    let y1 = min(y0 + dashLen, frameB)
    let d <- to_array_move(fixed_array<float2>(float2(frameR, y0), float2(frameR, y1)))
    ctx |> render_line_aa(d, false, data.lineWidth, float2(0., 0.), f15Blue)
    dy += dashStep

  // Range NM top-right corner of blue frame
  let distNmVal = get_radar_hud_distance_max() * kmetrToNavMile
  let distNmStr = "{fmt(":d", roundi(distNmVal))}NM"
  ctx |> set_color(f15Green)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(30)
  var fctxNm : StdGuiFontContext
  get_font_context(fctxNm, data.fontId, 0, 0, 30)
  let nmBox = get_str_bbox(distNmStr, distNmStr |> length(), fctxNm)
  ctx |> goto_xy(frameR - nmBox.width.x - rdata.size.x * 0.01, frameT + nmBox.width.y * 1.1)
  ctx |> draw_str_scaled(1.0, distNmStr, distNmStr |> length())

  // Radar sector
  let radarMargin = size.x * 0.03
  let radarLeft = frameL + radarMargin
  let radarTop = frameT + radarMargin - size.y * 0.15
  let radarW = (frameR - frameL) - radarMargin * 2.0
  let radarH = (frameB - frameT) - radarMargin * 2.0 - size.y * 0.1
  let radarPos = float2(radarLeft, radarTop)
  let radarSize = float2(radarW, radarH)

  let barY = pos.y + size.y * 0.85

  // Compute heading once for both bottom label and compass arc
  var heading = 0.
  let hdgHero = get_controlled_hero()
  if hdgHero != null && !hdgHero.isDelayed
    heading = (norm_ang(2. * PI + atan2(hdgHero.unitTm[0].x, hdgHero.unitTm[0].z))) * 180. / PI

  // Clip all radar drawing to blue frame bounds
  ctx |> set_viewport(frameL, frameT, frameR, frameB)
  draw_sector_radar(ctx, data, radarPos, radarSize, heading, barY, frameT, frameB)
  ctx |> restore_viewport()

  // Bottom separator
  let barLine <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * 0.1, barY), float2(pos.x + size.x * 0.9, barY)))
  ctx |> render_line_aa(barLine, false, data.lineWidth, float2(0., 0.), f15Green)

  // Elevation scope
  draw_elevation_scope(ctx, data, size, frameL, frameT, frameB)

  // Target zoom inset
  draw_target_zoom(ctx, data, pos, size, barY)

  // Target info line below barY (yellow): altitude, speed, aspect, heading
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.radarFontSize + 4)
  var fctxInfo : StdGuiFontContext
  get_font_context(fctxInfo, data.fontId, 0, 0, data.radarFontSize + 4)
  Radar`foreach_visible_target() <| $(var target)
    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      if target.isSelected && target.isSelectedTargetOfInterest
        let tgtAltFt = target.height * metrToFeet
        let tgtAltKft = roundi(tgtAltFt / 1000.0)
        let altStr = "{tgtAltKft}K"
        let tgtSpd = sqrt(target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed) * mpsToKnots
        let spdStr = "{roundi(tgtSpd)}"
        let tgtAzRad = get_radar_hud_azimuth_min() + (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * target.azimuthRel
        let tgtAzDeg = tgtAzRad * 180.0 / PI
        let aspectRad = atan2(target.losHorSpeed, -target.losSpeed)
        let aspectAngle = clamp(roundi(abs(aspectRad) * 180.0 / PI), 0, 180)
        let aspectSide = target.losHorSpeed >= 0.0 ? "L" : "R"
        let aspectStr = "{aspectAngle}{aspectSide}"
        let tgtHeading = roundi(heading + tgtAzDeg + 180.0) % 360
        let hdgStr = "{fmt(":03d", tgtHeading)}"
        let infoStr = "{altStr}  {spdStr}  {aspectStr}  {hdgStr}"
        ctx |> set_color(f15Yellow)
        ctx |> goto_xy(pos.x + size.x * 0.10, barY + size.y * 0.02)
        ctx |> draw_str_scaled(1.0, infoStr, infoStr |> length())

  // Bottom labels: fixed-size button boxes with centered text
  ctx |> set_color(f15Green)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.radarFontSize)
  var fctxBtn : StdGuiFontContext
  get_font_context(fctxBtn, data.fontId, 0, 0, data.radarFontSize)
  let btnW = size.x * 0.07
  let btnH = size.y * 0.025
  let btnY = pos.y + size.y * 0.93
  // Buttons: move X,Y and text follows
  draw_boxed_label(ctx, data, fctxBtn, pos.x + size.x * 0.05, btnY, btnW, btnH, "INLV", f15Green)
  draw_boxed_label(ctx, data, fctxBtn, pos.x + size.x * 0.18, btnY, btnW, btnH, "RDR", f15Green)
  draw_boxed_label(ctx, data, fctxBtn, pos.x + size.x * 0.33, btnY, btnW, btnH, "IRST", f15Green)

  if hdgHero != null && !hdgHero.isDelayed
    let hdgStr = "{fmt(":03d", roundi(heading) % 360)}"
    ctx |> goto_xy(pos.x + size.x * 0.48, barY - size.y * 0.06)
    ctx |> draw_str_scaled(1.0, hdgStr, hdgStr |> length())


def draw_targets(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let radius = size.y * 0.5
  let vectorLenMax = radius * 0.45
  let sqHalf = radius * 0.02  // half-size of target square
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  var fctxTgt : StdGuiFontContext
  get_font_context(fctxTgt, data.fontId, 0, 0, data.radarFontSize - 4)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.radarFontSize - 4)

  Radar`foreach_visible_target() <| $(var target)
    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      var distanceRel = 0.9
      if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
        distanceRel = target.distanceRel

      var angle = -PI * 0.5
      if get_radar_hud_has_azimuth_scale()
        angle = get_radar_hud_azimuth_min() + azimuthRange * target.azimuthRel - PI * 0.5

      let sina = sin(angle)
      let cosa = cos(angle)
      let tpos = origin + float2(cosa * distanceRel * radius, sina * distanceRel * radius)

      // Yellow square
      let sq <- to_array_move(fixed_array<float2>(
        tpos + float2(-sqHalf, -sqHalf), tpos + float2(sqHalf, -sqHalf),
        tpos + float2(sqHalf, sqHalf), tpos + float2(-sqHalf, sqHalf),
        tpos + float2(-sqHalf, -sqHalf)))
      ctx |> render_line_aa(sq, false, data.lineWidth, float2(0, 0), f15Yellow)

      // Velocity vector from center of square
      if target.losSpeed < 30000.0 && (target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed) > 1.0
        // Tracked/selected: real velocity direction
        let losAngle = atan2(target.losHorSpeed, -target.losSpeed)
        let losSpd = sqrt(target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed)
        let vecLen = clamp(losSpd * speedMaxInv * vectorLenMax, sqHalf * 2.0, sqHalf * 5.0)
        let vx = -sin(losAngle) * vecLen
        let vy = cos(losAngle) * vecLen
        let spd <- to_array_move(fixed_array<float2>(tpos, tpos + float2(vx, vy)))
        ctx |> render_line_aa(spd, false, data.lineWidth, float2(0, 0), f15Yellow)
      else
        // Untracked: radial direction away from origin
        let diff = tpos - origin
        let diffLen = length(diff)
        if diffLen > 0.1
          let dir = diff / diffLen
          let spd <- to_array_move(fixed_array<float2>(tpos, tpos + dir * sqHalf * 3.0))
          ctx |> render_line_aa(spd, false, data.lineWidth, float2(0, 0), f15Yellow)

      // Lock line to origin if selected
      if target.isSelected && target.isSelectedTargetOfInterest
        let lockLine <- to_array_move(fixed_array<float2>(tpos, origin))
        ctx |> render_line_aa(lockLine, false, data.lineWidth, float2(0, 0), f15Blue)

        // Designation cue: vertical bars left and right of locked target square
        let cueOffX = sqHalf * 1.8
        let cueHalfH = sqHalf * 1.2
        let dcLeft <- to_array_move(fixed_array<float2>(tpos + float2(-cueOffX, -cueHalfH), tpos + float2(-cueOffX, cueHalfH)))
        ctx |> render_line_aa(dcLeft, false, data.lineWidth * 1.5, float2(0., 0.), f15White)
        let dcRight <- to_array_move(fixed_array<float2>(tpos + float2(cueOffX, -cueHalfH), tpos + float2(cueOffX, cueHalfH)))
        ctx |> render_line_aa(dcRight, false, data.lineWidth * 1.5, float2(0., 0.), f15White)



def draw_compass_arc(var ctx : GuiContext&; data : CanvasParams&; origin : float2; radius : float; compass : float)
  ctx |> set_color(f15Green)
  let scanAzimuthMin = get_radar_hud_scan_azimuth_min()
  let scanAzimuthMax = get_radar_hud_scan_azimuth_max()
  let arcMin = min(get_radar_hud_azimuth_min(), scanAzimuthMin)
  let arcMax = max(get_radar_hud_azimuth_max(), scanAzimuthMax)
  ctx |> render_sector_aa(origin, float2(radius), float2(arcMin - PI * 0.5, arcMax - PI * 0.5), data.lineWidth, f15Green, transparentColor)

  for i in range(-18, 19)
    let markVal = (int(compass) / 10) * 10 + i * 10
    let azimuth = floori(norm_ang_deg(float(markVal)))
    let is60 = azimuth % 60 == 0
    if !is60
      continue
    let diff = (compass - float(markVal)) * PI / 180.
    let markDir = float2(-sin(diff), -cos(diff))
    let markLen = radius * 0.25  // from outer arc to midpoint between outer and inner dashed ring
    let markPos1 = origin + markDir * radius
    let markPos2 = origin + markDir * (radius - markLen)
    let markCoord <- to_array_move(fixed_array<float2>(markPos1, markPos2))
    ctx |> render_line_aa(markCoord, false, data.lineWidth, float2(0., 0.), f15Green)


def draw_sector_radar(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; compass : float; barY : float; frameT : float; frameB : float)
  let radius = size.y * 0.55
  let radius2 = float2(radius)
  let origin = pos + float2(size.x * 0.5, size.y)

  // Own ship marker: christian cross, smaller size
  let sv = radius * 0.025  // vertical arm up
  let sd = radius * 0.05   // vertical arm down (longer)
  let sh = radius * 0.022  // horizontal half-arm
  let hOff = sv * 0.4      // crossbar offset below top
  let ownV <- to_array_move(fixed_array<float2>(origin + float2(0., -sv), origin + float2(0., sd)))
  ctx |> render_line_aa(ownV, false, data.lineWidth, float2(0., 0.), f15Green)
  let ownH <- to_array_move(fixed_array<float2>(origin + float2(-sh, hOff), origin + float2(sh, hOff)))
  ctx |> render_line_aa(ownH, false, data.lineWidth, float2(0., 0.), f15Green)
  // Bottom horizontal foot line
  let ownFoot <- to_array_move(fixed_array<float2>(origin + float2(-sh * 0.5, sd), origin + float2(sh * 0.5, sd)))
  ctx |> render_line_aa(ownFoot, false, data.lineWidth, float2(0., 0.), f15Green)

  // Scan zone lines start with gap from marker
  let strokeGap = radius * 0.07
  let scanAzimuthMin = get_radar_hud_scan_azimuth_min()
  let scanAzimuthMax = get_radar_hud_scan_azimuth_max()
  if (scanAzimuthMax - scanAzimuthMin > 0.01)
    let scanLeftDir = float2(cos(scanAzimuthMin + PI * 0.5), sin(scanAzimuthMin + PI * 0.5))
    let scanLeft <- to_array_move(fixed_array<float2>(origin - scanLeftDir * strokeGap, origin - scanLeftDir * 1.10 * radius))
    ctx |> render_line_aa(scanLeft, false, data.lineWidth, float2(0., 0.), f15Green)
    let scanRightDir = float2(cos(scanAzimuthMax + PI * 0.5), sin(scanAzimuthMax + PI * 0.5))
    let scanRight <- to_array_move(fixed_array<float2>(origin - scanRightDir * strokeGap, origin - scanRightDir * 1.10 * radius))
    ctx |> render_line_aa(scanRight, false, data.lineWidth, float2(0., 0.), f15Green)
    ctx |> render_sector_aa(origin, radius2 * 1.10, float2(scanAzimuthMin - PI * 0.5, scanAzimuthMax - PI * 0.5), data.lineWidth, f15Green, transparentColor)

  // Range ring: dashed, upper semicircle, increase multiplier to reach bar line
  let dashRingRadius = radius * 0.55
  let ringArcSpan = PI * 1.3  // 1.0 = semicircle, >1.0 = extends ends downward
  let ringDashes = 25
  // dash + gap fits evenly: total = N dashes + (N-1) gaps
  let ringDashLen = ringArcSpan / (float(ringDashes) * 2.0 - 1.0)
  let ringGapLen = ringDashLen
  let ringStart = -PI - (ringArcSpan - PI) * 0.5
  for i in range(ringDashes)
    let a0 = ringStart + float(i) * (ringDashLen + ringGapLen)
    ctx |> render_sector_aa(origin, float2(dashRingRadius), float2(a0, a0 + ringDashLen), data.lineWidth * 0.5, f15GreenDim, transparentColor)

  // Elevation scale
  let elevationRangeInv = 1.0 / max(get_radar_hud_elevation_max() - get_radar_hud_elevation_min(), 0.0)
  let elevationScaleHalfSize = size.y * 0.4
  let elevationMarkLen = radius * 0.05
  let elevationMarks = fixed_array(-60.0, -40.0, -20.0, -10.0, 0.0, 10.0, 20.0, 40.0, 60.0)
  let elevBaseX = origin.x - radius - size.x * 0.02
  let elevBaseY = origin.y - size.y * 0.35
  for elevationMark in elevationMarks
    let yOff = elevationMark * PI / 180.0 * elevationRangeInv * elevationScaleHalfSize
    let ml <- to_array_move(fixed_array<float2>(float2(elevBaseX, elevBaseY + yOff), float2(elevBaseX - elevationMarkLen, elevBaseY + yOff)))
    ctx |> render_line_aa(ml, false, data.lineWidth, float2(0., 0.), f15GreenDim)

  let scanElevationMin = get_radar_hud_scan_elevation_min()
  let scanElevationMax = get_radar_hud_scan_elevation_max()
  if (scanElevationMax - scanElevationMin > 0.01)
    let elevZoneLen = 0.4 * elevationMarkLen
    ctx |> set_color(f15Green)
    ctx |> render_box(elevBaseX - elevationMarkLen - elevZoneLen, elevBaseY - scanElevationMin * elevationRangeInv * elevationScaleHalfSize,
      elevBaseX - elevationMarkLen, elevBaseY - scanElevationMax * elevationRangeInv * elevationScaleHalfSize)

  // Targets
  draw_targets(ctx, data, origin, size)

  // Launch zone clipped at barY (horizontal separator line)
  ctx |> set_viewport(origin.x - size.x, origin.y - size.y, origin.x + size.x, barY)
  draw_launch_zone(ctx, origin, size)
  ctx |> restore_viewport()

  // Cue gate
  if get_radar_hud_cue_visible()
    let cueAzHalfRel = get_radar_hud_cue_azimuth_half_width_rel()
    let designWidth = get_radar_hud_target_azimuth_width() * (1.0 - 2.0 * cueAzHalfRel)
    let cueAzRel = get_radar_hud_cue_azimuth()
    let cueAzL = (cueAzRel - cueAzHalfRel) * designWidth
    let cueAzR = (cueAzRel + cueAzHalfRel) * designWidth
    let cueDistRel = get_radar_hud_cue_distance()
    let cueDistHalf = 0.5 * get_radar_hud_cue_dist_width_rel()
    let cueRNear = (cueDistRel - cueDistHalf) * radius
    let cueRFar  = (cueDistRel + cueDistHalf) * radius
    let cueLDir = float2(cos(cueAzL + PI * 0.5), sin(cueAzL + PI * 0.5))
    let cueLLine <- to_array_move(fixed_array<float2>(origin - cueLDir * cueRNear, origin - cueLDir * cueRFar))
    ctx |> render_line_aa(cueLLine, false, data.lineWidth, float2(0., 0.), f15Green)
    let cueRDir = float2(cos(cueAzR + PI * 0.5), sin(cueAzR + PI * 0.5))
    let cueRLine <- to_array_move(fixed_array<float2>(origin - cueRDir * cueRNear, origin - cueRDir * cueRFar))
    ctx |> render_line_aa(cueRLine, false, data.lineWidth, float2(0., 0.), f15Green)

  // Closure rate scale (knots): -600 to 2000
  let vcMin = -600.0
  let vcMax = 2000.0
  let vcRange = vcMax - vcMin
  let scaleX = pos.x + size.x - size.x * 0.03
  let scaleTop = frameT + (frameB - frameT) * 0.62
  let scaleBot = frameT + (frameB - frameT) * 0.90
  let scaleH = scaleBot - scaleTop
  let arrowW = size.x * 0.036

  // Dashed vertical backbone line
  let dashH = scaleH * 0.06
  let gapH = dashH * 0.5
  var dy2 = 0.0
  while dy2 < scaleH
    let y0 = scaleTop + dy2
    let y1 = min(y0 + dashH, scaleBot)
    let dseg <- to_array_move(fixed_array<float2>(float2(scaleX, y0), float2(scaleX, y1)))
    ctx |> render_line_aa(dseg, false, data.lineWidth, float2(0., 0.), f15Green)
    dy2 += dashH + gapH

  // Closure rate from TargetOfInterest.distanceRate
  let hero = get_controlled_hero()
  var closureRate = 0.0
  var hasClosureRate = false
  if hero != null && !hero.isDelayed
    using() <| $(var toi : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, toi)
        closureRate = -toi.distanceRate * mpsToKnots
        hasClosureRate = true

  // Closure rate marker and info for selected target
  if hasClosureRate
    let vcClamped = clamp(closureRate, vcMin, vcMax)
    let vcY = scaleBot - ((vcClamped - vcMin) / vcRange) * scaleH
    let chevron <- to_array_move(fixed_array<float2>(
      float2(scaleX - arrowW * 0.5, vcY - arrowW * 0.5),
      float2(scaleX, vcY),
      float2(scaleX - arrowW * 0.5, vcY + arrowW * 0.5)))
    ctx |> render_line_aa(chevron, false, data.lineWidth, float2(0., 0.), f15Green)
    ctx |> set_font(data.fontId, 0, 0)
    ctx |> set_font_ht(data.radarFontSize + 4)
    var fctxVc : StdGuiFontContext
    get_font_context(fctxVc, data.fontId, 0, 0, data.radarFontSize + 4)
    let lineH = float(data.radarFontSize + 4) * 1.3
    // Bearing-distance line above closure speed
    Radar`foreach_visible_target() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        if target.isSelected && target.isSelectedTargetOfInterest
          let targetAzRad = get_radar_hud_azimuth_min() + (get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * target.azimuthRel
          let bearingDeg = roundi(compass + targetAzRad * 180.0 / PI) % 360
          var brStr = "{fmt(":03d", bearingDeg)}"
          if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.0
            let distNm = roundi(get_radar_hud_distance_max() * target.distanceRel * kmetrToNavMile)
            brStr = "{fmt(":03d", bearingDeg)}-{fmt(":d", distNm)}"
          let brBox = get_str_bbox(brStr, brStr |> length(), fctxVc)
          ctx |> set_color(f15Yellow)
          ctx |> goto_xy(scaleX - arrowW * 0.5 - brBox.width.x - size.x * 0.005, vcY - lineH + brBox.width.y * 0.4)
          ctx |> draw_str_scaled(1.0, brStr, brStr |> length())
    // Closure speed value
    let vcStr = "{fmt(":d", roundi(closureRate))}"
    let vcBox = get_str_bbox(vcStr, vcStr |> length(), fctxVc)
    ctx |> set_color(f15Yellow)
    ctx |> goto_xy(scaleX - arrowW * 0.5 - vcBox.width.x - size.x * 0.005, vcY + vcBox.width.y * 0.4)
    ctx |> draw_str_scaled(1.0, vcStr, vcStr |> length())

  let compassBR = radius * 1.1
  ctx |> set_viewport(origin.x - compassBR, origin.y - compassBR, origin.x + compassBR, origin.y - radius * 0.3)
  draw_compass_arc(ctx, data, origin, radius * 1.10, compass)
  ctx |> restore_viewport()

  // Lines from arc ends to own ship marker (with gap)
  let arcMin = get_radar_hud_azimuth_min()
  let arcMax = get_radar_hud_azimuth_max()
  let arcGap = radius * 0.07
  let arcRadius = radius * 1.10
  let arcLDir = float2(cos(arcMin + PI * 0.5), sin(arcMin + PI * 0.5))
  let arcRDir = float2(cos(arcMax + PI * 0.5), sin(arcMax + PI * 0.5))
  let arcLLine <- to_array_move(fixed_array<float2>(origin - arcLDir * arcGap, origin - arcLDir * arcRadius))
  ctx |> render_line_aa(arcLLine, false, data.lineWidth, float2(0., 0.), f15Green)
  let arcRLine <- to_array_move(fixed_array<float2>(origin - arcRDir * arcGap, origin - arcRDir * arcRadius))
  ctx |> render_line_aa(arcRLine, false, data.lineWidth, float2(0., 0.), f15Green)




def draw_launch_zone(var ctx : GuiContext&; origin : float2; size : float2)
  if !get_radar_hud_aam_launch_zone_visible()
    return
  let distMax = get_radar_hud_aam_launch_zone_dist_max()
  if distMax <= 1.
    ctx |> render_ellipse_aa(origin, float2(size.y * 0.5 * distMax), 0.1, f15GreenBright, transparentColor)
  let dgftDistMin = get_radar_hud_aam_launch_zone_dist_dgft_min()
  if dgftDistMin <= 1.
    let numDashes = 10
    let dashAngle = PI / (float(numDashes) * 2.0 + 1.0)
    for i in range(numDashes + 1)
      let angle = PI + dashAngle * 2.0 * float(i)
      ctx |> render_sector_aa(origin, float2(size.y * 0.5 * dgftDistMin), float2(angle, angle + dashAngle), 0.1, f15GreenBright, transparentColor)


def draw_boxed_label(var ctx : GuiContext&; data : CanvasParams&; fctx : StdGuiFontContext; bx : float; by : float; bw : float; bh : float; text : string; color : E3DCOLOR; txtOffX : float = 0.0; txtOffY : float = 0.0)
  let rect <- to_array_move(fixed_array<float2>(float2(bx, by), float2(bx + bw, by), float2(bx + bw, by + bh), float2(bx, by + bh), float2(bx, by)))
  ctx |> render_line_aa(rect, false, data.lineWidth * 1.5, float2(0., 0.), color)
  ctx |> set_color(color)
  let strBox = get_str_bbox(text, text |> length(), fctx)
  ctx |> goto_xy(bx + (bw - strBox.width.x) * 0.5 + txtOffX, by + bh * 0.5 + strBox.width.y * 0.25 + txtOffY)
  ctx |> draw_str_scaled(1.0, text, text |> length())
