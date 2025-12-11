require darg
require ecs
require DagorSystem
require DagorStdGuiRender
require DagorMath
require RadarHud
require strings
require FlightModelWrap
require HeroManager
require Unit
require math
require GamePhys
require %rGui.utils.radar_common

let padding = 10.
let metrToFeet = 3.28084
let metrToThFeet = metrToFeet * 0.001
let kMetrToMile = 0.621371
let metersToMiles = kMetrToMile * 0.001

struct UsedColors
  white : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  gray : E3DCOLOR = E3DCOLOR(0xFFAAAAAA)
  halfTransparent : E3DCOLOR = E3DCOLOR(0x8F000000)
  transparent : E3DCOLOR = E3DCOLOR(0x00000000)
  brown : E3DCOLOR = E3DCOLOR(0xFF7C3F00)
  darkGray : E3DCOLOR = E3DCOLOR(0xFF050505)
  red : E3DCOLOR = E3DCOLOR(0xFFFF0000)
  green : E3DCOLOR = E3DCOLOR(0xFF00FF00)
  blue : E3DCOLOR = E3DCOLOR(0xFF0000FF)
  cyan : E3DCOLOR = E3DCOLOR(0xFF5050FF)

let colors : UsedColors = UsedColors()

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  useArea : float4 = float4(0., 0., 1., 1.)
  lineWidth : float = 2.

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.useArea = float4(0.13, 0., 0.87, 1.0)
  storage.lineWidth = props |> getFloat("lineWidth", 1.) * 2.

[export, unused_argument(rstate)]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !get_radar_hud_mfd_radar_enabled()
    return

  let pos_bottom = rdata.pos + float2(data.useArea.x * rdata.size.x, 0.47 * rdata.size.y)
  let size_bottom = float2(rdata.size.x * (data.useArea.z - data.useArea.x), 0.5 * rdata.size.y * (data.useArea.w - data.useArea.y))

  let pos_upper = rdata.pos + float2(data.useArea.x * rdata.size.x, data.useArea.y * rdata.size.y)
  let size_upper = float2(rdata.size.x * (data.useArea.z - data.useArea.x), 0.5 * rdata.size.y * (data.useArea.w - data.useArea.y))

  ctx |> draw_upper_part(data, pos_upper, size_upper)
  ctx |> draw_bottom_part(data, pos_bottom, size_bottom)
  ctx |> draw_dotted_line(pos_bottom, pos_bottom + float2(0.9 * size_bottom.x, 0.0), colors.white, data.lineWidth, 4.0, 4.0)
  ctx |> draw_dotted_line(pos_bottom + float2(0.01 * size_bottom.x, 0.0), pos_bottom + float2(0.01 * size_bottom.x, size_bottom.y), colors.white, data.lineWidth, 4.0, 4.0)
  ctx |> draw_labels_upper(pos_upper, size_upper)
  ctx |> draw_labels_bottom(pos_bottom, size_bottom)

def draw_upper_part(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  ctx |> draw_rectangular_radar(data, origin + float2(0.05 * size.x, 0.15 * size.y), float2(0.85 * size.x, 0.65 * size.y))

def draw_targets_hei(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let distMax = get_radar_hud_distance_max()
  let maxHei = 60000.0 / metrToFeet
  Radar`foreach_visible_target() <| $(var target)
    let e3dColor = E3DCOLOR(Color4(!target.isEnemy ? colors.green : colors.red))

    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      var distanceRel = 0.9
      var heiRel = 0.
      if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
        distanceRel = target.distanceRel
        if distMax > 0.
          heiRel = (target.height - hero.pos.y) / maxHei

      if heiRel > 1. || distanceRel > 1. || heiRel < -0.2 || distanceRel < 0.
        return
      let pos = origin + float2(distanceRel * size.x, -heiRel * size.y)
      if target.isDetected || target.isTracked
        ctx |> set_color(e3dColor)
        ctx |> draw_line(pos.x, origin.y - size.y, pos.x, origin.y + size.y * 0.33, data.lineWidth)
        ctx |> draw_line(pos.x - 5., origin.y, pos.x + 5., origin.y, data.lineWidth)
        ctx |> draw_line(pos.x - 3., origin.y - size.y * 0.33, pos.x + 3., origin.y - size.y * 0.33, data.lineWidth)
        ctx |> draw_line(pos.x - 3., origin.y - size.y * 0.66, pos.x + 3., origin.y - size.y * 0.66, data.lineWidth)
        ctx |> draw_line(pos.x - 5., origin.y - size.y * 0.165, pos.x + 5., origin.y - size.y * 0.165, data.lineWidth)
        ctx |> draw_line(pos.x - 5., origin.y - size.y * 0.5, pos.x + 5., origin.y - size.y * 0.5, data.lineWidth)
      if target.isSelected && get_radar_hud_has_azimuth_scale()
        let losAngle = atan2(distanceRel * distMax * 1000.0, target.height - hero.pos.y) + atan2(target.losVerSpeed, -target.losSpeed)
        ctx |> setRotViewTm(pos.x, pos.y, losAngle, 0., false)
        ctx |> set_color(e3dColor)

        let los = sqrt(target.losSpeed * target.losSpeed + target.losVerSpeed * target.losVerSpeed) * 0.1
        let spd <- to_array_move(fixed_array<float2>(pos, pos + float2(0., los)))
        ctx |> render_line_aa(spd, false, data.lineWidth,  float2(0, 0), e3dColor)

        if target.ageRel > 0.25
          let triangle <- to_array_move(fixed_array<float2>(float2(pos.x, pos.y + size.y * 0.03),
              float2(pos.x + size.x * 0.015, pos.y - size.y * 0.03),
              float2(pos.x - size.x * 0.015, pos.y - size.y * 0.03)))
          ctx |> render_poly(triangle, e3dColor)
          ctx |> render_line_aa(triangle, true, data.lineWidth, float2(0, 0), e3dColor)
        else
          ctx |> render_ellipse_aa(pos, float2(size.x * 0.01), 1., e3dColor, e3dColor)

        if target.isDetected || target.isTracked
          ctx |> render_ellipse_aa(pos, float2(size.x * 0.02), data.lineWidth, e3dColor, colors.transparent)
          let cross <- to_array_move(fixed_array<float2>(pos - float2(size.x * 0.02), pos + float2(size.x * 0.02)))
          ctx |> render_line_aa(cross, false, data.lineWidth,  float2(0, 0), e3dColor)
          let cross2 <- to_array_move(fixed_array<float2>(pos - float2(size.x * 0.02, -size.x * 0.02), pos + float2(size.x * 0.02, -size.x * 0.02)))
          ctx |> render_line_aa(cross2, false, data.lineWidth,  float2(0, 0), e3dColor)

        ctx |> resetViewTm()
      else
        ctx |> render_ellipse_aa(pos, float2(size.x * 0.01), 1., e3dColor, e3dColor)

        if target.isDetected || target.isTracked
          ctx |> render_ellipse_aa(pos, float2(size.x * 0.02), data.lineWidth, e3dColor, colors.transparent)

def draw_rectangular_radar(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  ctx |> draw_rectangular_radar_background(pos, size)
  ctx |> draw_rectangular_radar_scan_zone(data, pos, size)
  ctx |> draw_rectangular_radar_indication(data, pos, size)

def draw_rectangular_radar_background(var ctx : GuiContext&; pos : float2; size : float2)
  let arrowPos = float2(pos.x + size.x * 0.02 + padding, pos.y + size.y * 0.83)

  let radarPos = float2(arrowPos.x, pos.y)
  let radarSize = float2(size.x - (arrowPos.x - pos.x), size.y)
  let rb = radarPos + radarSize
  ctx |> set_color(colors.darkGray)
  let tc = float2(0., 0.)
  ctx |> render_rect(radarPos.x, radarPos.y, rb.x, rb.y, tc, tc, tc)

def draw_rectangular_radar_indication(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let arrowPos = float2(pos.x + size.x * 0.02 + padding, pos.y + size.y * 0.83)
  let horLines = 12
  for i in range(0, horLines)
    let lineStartPos = float2(arrowPos.x, pos.y + float(i) * size.y / float(horLines))
    let lineEndPos = float2(pos.x + size.x, lineStartPos.y)
    ctx |> render_simple_line(lineStartPos, lineEndPos, colors.white, 0.5 * data.lineWidth)

  let verticalIndicationX = arrowPos.x - 0.08 * size.x
  let verticalIndicationY = pos.y + 0.02 * size.y
  let verticalIndication <- to_array_move(fixed_array<string>("60", "45", "30", "15", ""))
  for text, i in verticalIndication, range(0, length(verticalIndication))
    let textPos = float2(verticalIndicationX, verticalIndicationY + float(i) * size.y / float(length(verticalIndication) - 1))
    ctx |> draw_horizontal_label(textPos, text)

  let horizontalIndicationY = pos.y + 1.1 * size.y
  let distMiles = get_radar_hud_distance_max() * kMetrToMile;
  let step = distMiles > 70.0 ? 20.0 : (distMiles < 35.0 ? 5.0 : 10.0)
  let numOfSteps = int(distMiles / step)
  let deltaX = -0.02 * size.x
  for i in range(0, numOfSteps)
    let textPos = float2(arrowPos.x + size.x * float(i) / float(numOfSteps) + deltaX, horizontalIndicationY)
    ctx |> draw_horizontal_label(textPos, "{int(step * float(i))}")
    let tickPos = float2(arrowPos.x + size.x * float(i) / float(numOfSteps), pos.y + size.y)
    ctx |> render_simple_line(tickPos, float2(tickPos.x, tickPos.y + 0.02 * size.y), colors.white, 0.5 * data.lineWidth)

def draw_rectangular_radar_scan_zone(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let horMaxAlt = 60000.0 / metrToFeet
  let horMaxLen = 1000.0 * get_radar_hud_distance_max() / metrToFeet
  let horRatioYtoX = horMaxLen / horMaxAlt

  var pitch = 0.0
  var height = 0.0
  let hero = get_controlled_hero()
  if hero != null && !hero.isDelayed
    let fmw = hero |> as_fmw()
    height = hero.pos.y * metrToFeet
    if fmw != null
      pitch = -fmw.tangage * PI / 180.0

  let heightDisplayRatio = max(0.0, min(1.0, (1.0 - height / 60000.0)))

  let arrowPos = float2(pos.x + size.x * 0.02 + padding, pos.y + heightDisplayRatio * size.y)
  let arrow <- to_array_move(fixed_array<float2>(arrowPos, float2(pos.x + 5., arrowPos.y - size.y * 0.04), float2(pos.x + 5., arrowPos.y + size.y * 0.04)))
  ctx |> render_line_aa(arrow, true, data.lineWidth, float2(0, 0), colors.cyan)


  let radarPos = float2(arrowPos.x, pos.y)
  let radarSize = float2(size.x - (arrowPos.x - pos.x), size.y)
  let rb = radarPos + radarSize

  ctx |> set_viewport(radarPos.x, radarPos.y, rb.x, rb.y)

  var scanAngles = float2(pitch - get_radar_hud_scan_elevation_max(), pitch - get_radar_hud_scan_elevation_min())
  scanAngles = float2(transform_angle_hor(scanAngles.x), transform_angle_hor(scanAngles.y))
  ctx |> render_sector_aa(arrowPos, float2(size.x) * get_radar_hud_target_distance(), scanAngles, 1., colors.transparent, colors.halfTransparent)

  ctx |> render_simple_line(arrowPos, arrowPos + float2(cos(scanAngles.x), sin(scanAngles.x)) * size.x, colors.cyan, data.lineWidth)
  ctx |> render_simple_line(arrowPos, arrowPos + float2(cos(scanAngles.y), sin(scanAngles.y)) * size.x, colors.cyan, data.lineWidth)

  let maxAngles = float2(pitch - get_radar_hud_elevation_max(), pitch - get_radar_hud_elevation_min())
  let sectorL1 <- to_array_move(fixed_array<float2>(arrowPos, arrowPos + float2(cos(maxAngles.x), sin(maxAngles.x) * horRatioYtoX) * size.x))
  ctx |> render_line_aa(sectorL1, false, data.lineWidth, float2(0., 0.), colors.white)

  let sectorL2 <- to_array_move(fixed_array<float2>(arrowPos, arrowPos + float2(cos(maxAngles.y), sin(maxAngles.y) * horRatioYtoX) * size.x))
  ctx |> render_line_aa(sectorL2, false, data.lineWidth, float2(0., 0.), colors.white)

  ctx |> draw_dotted_line(arrowPos, arrowPos + float2(cos(pitch), sin(pitch) * horRatioYtoX) * size.x, colors.white, data.lineWidth, 4.0, 4.0)

  draw_targets_hei(ctx, data, arrowPos, radarSize)
  ctx |> restore_viewport()

  ctx |> set_color(colors.white)
  ctx |> render_frame(radarPos.x, radarPos.y, rb.x, rb.y, data.lineWidth)


def draw_labels_upper(var ctx : GuiContext&; pos : float2; size : float2)
  ctx |> set_color(colors.white)
  ctx |> draw_horizontal_label(pos + float2(0.4 * size.x, 0.1 * size.y), "ID")
  ctx |> draw_horizontal_label(pos + float2(0.8 * size.x, 0.1 * size.y), "RTE")
  ctx |> draw_vertical_label(pos + float2(0.95 * size.x, 0.4 * size.y), "INIT", 15.0)

def draw_labels_bottom(var ctx : GuiContext&; pos : float2; size : float2)
  ctx |> set_color(colors.white)
  ctx |> draw_vertical_label(pos + float2(0.90 * size.x, 0.3 * size.y), "VOL", 15.0)
  ctx |> draw_vertical_label(pos + float2(0.90 * size.x, 0.5 * size.y), "RDR", 15.0)
  ctx |> draw_vertical_label(pos + float2(0.93 * size.x, 0.27 * size.y), "SECT", 15.0)
  ctx |> draw_vertical_label(pos + float2(0.93 * size.x, 0.52 * size.y), "MENU", 15.0)
  ctx |> draw_vertical_label(pos + float2(0.93 * size.x, 0.8 * size.y), "2C", 15.0)

def draw_info(var ctx : GuiContext&; pos : float2; size : float2)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return

  var hasSelectedTarget = false
  var targetAzimuth = 0.0
  var distToTargetKm = 0.0
  var targetAltKm = 0.0
  var taretSpeedSq = 0.0
  Radar`foreach_targets() <| $(var target)
    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      if target.isDetected || target.isTracked
        hasSelectedTarget = true
        targetAzimuth = get_radar_hud_azimuth_min() + max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * target.azimuthRel
        distToTargetKm = get_radar_hud_distance_max() * target.distanceRel
        let targetElev = get_radar_hud_elevation_min() * (1.0 - target.elevationRel) + get_radar_hud_elevation_max() * target.elevationRel
        targetAltKm = hero.pos.y * 0.001 + distToTargetKm * sin(targetElev)
        taretSpeedSq = target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed + target.losVerSpeed * target.losVerSpeed

  if hasSelectedTarget
    let rPos = pos + float2(0.1 * size.x, size.y * 1.05)
    let distMul = kMetrToMile
    draw_horizontal_label(ctx, rPos, "R {roundi(distToTargetKm * distMul)}")

    let altPos = pos + float2(0.3 * size.x, size.y * 1.05)
    let altMul = metrToFeet
    let alt = "A{fmt(":.1f", targetAltKm * altMul)}"
    ctx |> goto_xy(altPos.x, altPos.y)
    ctx |> draw_str_scaled(1.0, alt, alt |> length())

    let machPos = pos + float2(0.5 * size.x, size.y * 1.05)
    let machVal = sqrt(taretSpeedSq) / atmosphere_sonicSpeed(targetAltKm * 0.001)
    let mach = "M{fmt(":.2f", machVal)}"
    ctx |> goto_xy(machPos.x, machPos.y)
    ctx |> draw_str_scaled(1.0, mach, mach |> length())

    let tgtPos = pos + float2(0.7 * size.x, size.y * 1.05)
    let azimuthDegVal = norm_ang(atan2(hero.unitTm[0].x, hero.unitTm[0].z) + targetAzimuth) * 180.0 / PI
    let azimuth = "TGT {fmt(": .0f", azimuthDegVal)}"
    ctx |> set_font_ht(15)
    ctx |> goto_xy(tgtPos.x, tgtPos.y)
    ctx |> draw_str_scaled(1.0, azimuth, azimuth |> length())

def draw_targets(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let radius = size
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 12)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(12)
  ctx |> set_color(colors.white)
  ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, colors.white, 1)
  Radar`foreach_targets() <| $(var target)
    let e3dColor = E3DCOLOR(Color4(!target.isEnemy ? colors.green : colors.red))

    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      var distanceRel = 0.9
      var radialWidthRel = 0.05
      if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
        distanceRel = target.distanceRel
        radialWidthRel = max(target.distanceWidthRel, 0.05)

      var angle = -PI * 0.5
      var angularWidth = azimuthRange
      if get_radar_hud_has_azimuth_scale()
        angle = get_radar_hud_azimuth_min() + azimuthRange * target.azimuthRel - PI * 0.5
        angularWidth = azimuthRange * target.azimuthWidthRel

      let sina = sin(angle)
      let cosa = cos(angle)
      let pos = origin + float2(cosa * distanceRel * radius.x, sina * distanceRel * radius.y)
      if target.isSelected && get_radar_hud_has_azimuth_scale() && target.losSpeed < 30000.
        let losAngle = atan2(target.losHorSpeed, -target.losSpeed)
        ctx |> setRotViewTm(pos.x, pos.y, losAngle, 0., false)

        ctx |> set_color(e3dColor)
        let los = sqrt(target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed) * 0.1
        let linePos = pos + float2(0., size.y * 0.02)
        let spd <- to_array_move(fixed_array<float2>(linePos, linePos + float2(0., los)))
        ctx |> render_line_aa(spd, false, data.lineWidth,  float2(0, 0), e3dColor)

        if target.ageRel > 0.25
          let triangle <- to_array_move(fixed_array<float2>(float2(pos.x, pos.y + size.y * 0.015),
              float2(pos.x + size.x * 0.015, pos.y - size.y * 0.015),
              float2(pos.x - size.x * 0.015, pos.y - size.y * 0.015)))
          ctx |> render_poly(triangle, e3dColor)
          ctx |> render_line_aa(triangle, true, data.lineWidth, float2(0, 0), e3dColor)
        else
          ctx |> render_ellipse_aa(pos, float2(size.y * 0.02), 1., e3dColor, e3dColor)

        if target.isDetected || target.isTracked
          ctx |> render_ellipse_aa(pos, float2(size.y * 0.03), data.lineWidth, e3dColor, colors.transparent)
          let cross <- to_array_move(fixed_array<float2>(pos - size * 0.03, pos + size * 0.03))
          ctx |> render_line_aa(cross, false, data.lineWidth,  float2(0, 0), e3dColor)
          let cross2 <- to_array_move(fixed_array<float2>(pos - float2(size.x * 0.03, -size.y * 0.03), pos + float2(size.x * 0.03, -size.y * 0.03)))
          ctx |> render_line_aa(cross2, false, data.lineWidth,  float2(0, 0), e3dColor)

        let textHei = "{fmt(":d", roundi(target.height * metrToThFeet))}"
        let strBox = get_str_bbox(textHei, textHei |> length(), fctx)
        ctx |> set_color(colors.white)
        ctx |> goto_xy(pos.x - strBox.width.x * 0.5, pos.y - size.y * 0.035)
        ctx |> draw_str_scaled(1., textHei, textHei |> length())

        ctx |> resetViewTm()
      else
        ctx |> render_ellipse_aa(pos, float2(size.y * 0.02), 1., e3dColor, e3dColor)

        if target.isDetected || target.isTracked
          ctx |> render_ellipse_aa(pos, float2(size.y * 0.03), data.lineWidth, e3dColor, colors.transparent)

        let textHei = "{fmt(":d", roundi(target.height * metrToThFeet))}"
        let strBox = get_str_bbox(textHei, textHei |> length(), fctx)
        ctx |> goto_xy(pos.x - strBox.width.x * 0.5, pos.y + size.y * 0.035 + strBox.width.y)
        ctx |> draw_str_scaled(1., textHei, textHei |> length())

def draw_compass(var ctx : GuiContext&; data : CanvasParams&; origin : float2; radius : float; compass : float)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 12)
  ctx |> set_color(colors.cyan)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(12)
  ctx |> set_color(colors.cyan)

  ctx |> render_sector_aa(origin, float2(radius), float2(-6.0 / 5.0 * PI, PI / 2.0), 1., colors.cyan, colors.transparent)
  for i in range(-5, 6)
    var markVal = (int(compass) / 30) * 30 + i * 30
    markVal = markVal >= 0 ? (markVal < 360 ? markVal : markVal - 360) : 360 + markVal
    let diff = (compass - float(markVal)) * PI / 180.
    let markPos1 = origin + float2(-sin(diff), -cos(diff)) * radius
    let markPos2 = origin + float2(-sin(diff), -cos(diff)) * radius * 0.97
    let markPosTxt = origin + float2(-sin(diff), -cos(diff)) * radius * 0.8
    ctx |> render_simple_line(markPos1, markPos2, colors.cyan, data.lineWidth)

    let text = "{markVal / 10}"
    let markStrBox = get_str_bbox(text, text |> length(), fctx)
    ctx |> goto_xy(markPosTxt.x - markStrBox.width.x * 0.5, markPosTxt.y)
    ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_round_scan_angles(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let origin = pos + float2(size.x * 0.5, size.y)
  let radius = float2(size.y)

  ctx |> set_viewport(pos.x, pos.y, pos.x + size.x, pos.y + 1.1 * size.y)

  let tc = float2(0., 0.)
  ctx |> set_color(colors.darkGray)
  ctx |> render_rect(pos.x, pos.y + size.y * 0.5, pos.x + size.x, pos.y + size.y, tc, tc, tc)
  let anglesExternal = float2(get_radar_hud_azimuth_min() - PI * 0.5, get_radar_hud_azimuth_max() - PI * 0.5)
  ctx |> render_sector_aa(origin, radius, anglesExternal, 1., colors.cyan, colors.transparent)
  ctx |> render_simple_line(origin, origin + float2(cos(anglesExternal.x), sin(anglesExternal.x)) * radius, colors.cyan, data.lineWidth * 0.5)
  ctx |> render_simple_line(origin, origin + float2(cos(anglesExternal.y), sin(anglesExternal.y)) * radius, colors.cyan, data.lineWidth * 0.5)

  let scanAngles = float2(get_radar_hud_scan_azimuth_min() - PI * 0.5, get_radar_hud_scan_azimuth_max() - PI * 0.5)
  ctx |> render_sector_aa(origin, radius * get_radar_hud_target_distance(), scanAngles, 1., colors.cyan, colors.halfTransparent)

  ctx |> render_simple_line(origin, origin + float2(cos(scanAngles.x), sin(scanAngles.x)) * radius, colors.cyan, data.lineWidth)
  ctx |> render_simple_line(origin, origin + float2(cos(scanAngles.y), sin(scanAngles.y)) * radius, colors.cyan, data.lineWidth)

  draw_targets(ctx, data, origin, size)

  var compass = 0.
  let hero = get_controlled_hero()
  if hero != null && !hero.isDelayed
    compass = (norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * 180. / PI
  draw_compass(ctx, data, origin, size.y * 0.4, compass)

  ctx |> restore_viewport()


def draw_bottom_part(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  ctx |> draw_round_radar(data, origin, 0.90 * size)
  ctx |> draw_info(origin, size)

def draw_round_radar(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  ctx |> set_color(colors.darkGray)
  let rb = origin + float2(size.x, 1.1 * size.y)
  let tc = float2(0., 0.)
  ctx |> render_rect(origin.x, origin.y, rb.x, rb.y, tc, tc, tc)
  ctx |> draw_round_scan_angles(data, origin, size)
  ctx |> draw_radar_cue_indication(data, origin, size)

def draw_radar_cue_indication(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let startPos = float2(origin.x + 0.95 * size.x, origin.y + size.y)

  ctx |> render_simple_line(startPos + float2(0.0, 0.1 * size.y), startPos - float2(0.0, size.y), colors.white, data.lineWidth)

  let arrowPos = float2(startPos.x, startPos.y - size.y * get_radar_hud_cue_distance())
  ctx |> render_simple_line(arrowPos, arrowPos + float2(0.05 * size.x, 0.02 * size.y), colors.cyan, data.lineWidth)
  ctx |> render_simple_line(arrowPos, arrowPos + float2(0.05 * size.x, -0.02 * size.y), colors.cyan, data.lineWidth)
  ctx |> render_simple_line(arrowPos + float2(0.05 * size.x, 0.02 * size.y), arrowPos + float2(0.05 * size.x, -0.02 * size.y), colors.cyan, data.lineWidth)


  let maxDistMiles = get_radar_hud_distance_max() * kMetrToMile
  let step = maxDistMiles > 70.0 ? 10.0 : 5.0
  let numberOfTicks = int(maxDistMiles / step)

  for i in range(numberOfTicks)
    let tickStart = startPos - float2(0.0, float(i) * size.y / float(numberOfTicks))
    let tickEnd = tickStart - float2(0.03 * size.x, 0)
    ctx |> render_simple_line(tickStart, tickEnd, colors.white, data.lineWidth)
    if i % 3 == 0
      let lablePos = tickStart + float2(-0.1 * size.x, 0.02 * size.y)
      ctx |> draw_horizontal_label(lablePos, "{int(float(i) * step)}")


// utils

def render_simple_line(var ctx : GuiContext&; begin : float2; end : float2; color : E3DCOLOR; width : float)
  let line <- to_array_move(fixed_array<float2>(begin, end))
  ctx |> render_line_aa(line, false, width, float2(0, 0), color)

def draw_horizontal_label(var ctx : GuiContext&; pos : float2; text : string)
  ctx |> goto_xy(pos.x, pos.y)
  ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_vertical_label(var ctx : GuiContext&; pos : float2; text : string; ht : float)
  ctx |> goto_xy(pos.x, pos.y)
  for c, i in text, range(0, length(text))
    ctx |> draw_char_u(uint16(c))
    ctx |> goto_xy(pos.x, pos.y + ht * float(i + 1))

def draw_dotted_line(var ctx : GuiContext&; begin : float2; end : float2; color : E3DCOLOR; width : float; dot : float; space : float)
  let len = length(end - begin)
  let dotNum = int(len / (dot + space))
  let dir = (end - begin) / len
  for i in range(0, dotNum)
    let dotStart = lerp(begin, end, float(i) / float(dotNum))
    let dotEtart = dotStart + dot * dir
    ctx |> render_simple_line(dotStart, dotEtart, color, width)

def transform_angle_hor(angle : float)
  let horMaxAlt = 60000.0 / metrToFeet
  let horMaxLen = 1000.0 * get_radar_hud_distance_max() / metrToFeet
  let horRatioYtoX = horMaxLen / horMaxAlt

  var kSin, kCos : float
  sincos(angle, kSin, kCos)
  kSin *= horRatioYtoX
  let newSinCos = normalize(float2(kSin, kCos))
  return atan2(newSinCos.x, newSinCos.y)