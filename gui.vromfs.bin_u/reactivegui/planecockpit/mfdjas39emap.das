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
require %dasGameLibs.math.base
require GamePhys
require %rGui.utils.radar_common

let padding = 10.
let metrToFeet = 3.28084
let metrToThFeet = metrToFeet * 0.001
let kMetrToMile = 0.621371
let metersToMiles = kMetrToMile * 0.001
let yWorldSize = 35000.0

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
  lineWidth : float = 2.

[export]
def setup(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.lineWidth = props |> getFloat("lineWidth", 1.)

[export, unused_argument(rstate)]
def render(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  ctx |> set_font_ht(15)
  if !get_radar_hud_mfd_radar_enabled()
    return

  let origin = rdata.pos + float2(0.0, 0.0)
  let size = float2(rdata.size.x, rdata.size.y)
  ctx |> set_viewport(origin.x, origin.y, origin.x + size.x, origin.y + size.y)
  ctx |> draw_round_radar(data, origin, size)
  ctx |> draw_horizon(data, origin, size)
  ctx |> draw_target_info(origin + float2(0.2 * size.x, 0.85 * size.y), float2(0.6 * size.x, 0.1 * size.y))
  ctx |> restore_viewport()



def draw_targets(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  if get_radar_hud_distance_max() <= 0.0
    return

  let radius = 0.5 * size
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 12)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(12)
  ctx |> set_color(colors.white)
  ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, colors.white, 1)
  Radar`foreach_targets() <| $(var target)
    let e3dColor = E3DCOLOR(Color4(!target.isEnemy ? colors.blue : colors.red))

    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      var distanceRel = 0.9
      var radialWidthRel = 0.05
      if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
        distanceRel = target.distanceRel
        radialWidthRel = max(target.distanceWidthRel, 0.05)

      distanceRel = target.distanceRel * (yWorldSize / get_radar_hud_distance_max() / 1000.0)
      var angle = -PI * 0.5
      var angularWidth = azimuthRange
      if get_radar_hud_has_azimuth_scale()
        angle = get_radar_hud_azimuth_min() + azimuthRange * target.azimuthRel - PI * 0.5
        angularWidth = azimuthRange * target.azimuthWidthRel

      var sina, cosa : float
      sincos(angle, sina, cosa)
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
          ctx |> render_ellipse_aa(pos, float2(size.y * 0.024), data.lineWidth, colors.brown, colors.transparent)

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
  ctx |> set_font_ht(15)

  ctx |> render_ellipse_aa(origin, float2(1.05 * radius, radius), 1., colors.cyan, colors.transparent)
  ctx |> render_simple_line(origin, origin + float2(0.05 * radius, 0.15 * radius), colors.blue, data.lineWidth * 0.5)
  ctx |> render_simple_line(origin, origin + float2(-0.05 * radius, 0.15 * radius), colors.blue, data.lineWidth * 0.5)
  ctx |> render_simple_line(origin + float2(0.05 * radius, 0.15 * radius), origin + float2(-0.05 * radius, 0.15 * radius), colors.blue, data.lineWidth * 0.5)
  for i in range(-6, 6)
    var markVal = (int(compass) / 30) * 30 + i * 30
    markVal = markVal >= 0 ? (markVal < 360 ? markVal : markVal - 360) : 360 + markVal
    let diff = (compass - float(markVal)) * PI / 180.
    let markPos1 = origin + float2(-sin(diff) * 1.05, -cos(diff)) * radius
    let markPos2 = origin + float2(-sin(diff) * 1.05, -cos(diff)) * radius * 0.97
    let markPosTxt = origin + float2(-sin(diff) * 1.05, -cos(diff)) * radius * 0.8
    ctx |> render_simple_line(markPos1, markPos2, colors.cyan, data.lineWidth)

    let text = "{markVal / 10}"
    let markStrBox = get_str_bbox(text, text |> length(), fctx)
    ctx |> goto_xy(markPosTxt.x - markStrBox.width.x * 0.5, markPosTxt.y)
    ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_round_scan_angles(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let origin = pos + float2(size.x * 0.5, size.y * 0.5)
  let radius = float2(size.y)

  let anglesExternal = float2(get_radar_hud_azimuth_min() - PI * 0.5, get_radar_hud_azimuth_max() - PI * 0.5)
  ctx |> render_sector_aa(origin, radius, anglesExternal, 1., colors.transparent, colors.transparent)
  ctx |> render_simple_line(origin, origin + float2(cos(anglesExternal.x), sin(anglesExternal.x)) * radius, colors.cyan, data.lineWidth * 0.5)
  ctx |> render_simple_line(origin, origin + float2(cos(anglesExternal.y), sin(anglesExternal.y)) * radius, colors.cyan, data.lineWidth * 0.5)

  let scanAngles = float2(get_radar_hud_scan_azimuth_max() - PI * 0.5, get_radar_hud_scan_azimuth_min() - PI * 0.5)
  ctx |> render_sector_aa(origin, 2. * radius * get_radar_hud_target_distance(), scanAngles, 1., colors.transparent, colors.halfTransparent)

  ctx |> render_simple_line(origin, origin + float2(cos(scanAngles.x), sin(scanAngles.x)) * radius, colors.green, data.lineWidth)
  ctx |> render_simple_line(origin, origin + float2(cos(scanAngles.y), sin(scanAngles.y)) * radius, colors.green, data.lineWidth)

  draw_targets(ctx, data, origin, size)

  var compass = 0.
  let hero = get_controlled_hero()
  if hero != null && !hero.isDelayed
    compass = (norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * 180. / PI
  draw_compass(ctx, data, origin, size.y * 0.25, compass)

def draw_horizon(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return
  var tSin, tCos : float
  sincos(deg_to_rad(-fmw.roll), tSin, tCos)
  let center = origin + float2(0.5 * size.x, 0.5 * size.y * (1.0 + (fmw.tangage / 90.0)))
  ctx |> render_ellipse_aa(center, float2(0.03 * size.y), data.lineWidth, colors.brown, colors.transparent)

  ctx |> render_simple_line(center + 0.03 * size.y * float2(tCos, tSin), center + 2.0 * size.y * float2(tCos, tSin), colors.brown, data.lineWidth)
  ctx |> render_simple_line(center - 0.03 * size.y * float2(tCos, tSin), center - 2.0 * size.y * float2(tCos, tSin), colors.brown, data.lineWidth)
  ctx |> render_simple_line(center + 0.03 * size.y * float2(-tSin, tCos), center + 0.06 * size.y * float2(-tSin, tCos), colors.brown, data.lineWidth)
  return

def draw_target_info(var ctx : GuiContext&; pos : float2; size : float2)
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
    ctx |> set_color(colors.darkGray)
    let rb = pos + float2(size.x, size.y)
    let tc = float2(0., 0.)
    ctx |> render_rect(pos.x, pos.y, rb.x, rb.y, tc, tc, tc)
    ctx |> set_color(colors.white)
    let rPos = pos + float2(0.1 * size.x, 0.4 * size.y)
    let distMul = kMetrToMile
    draw_horizontal_label(ctx, rPos, "R {roundi(distToTargetKm * distMul)}")

    let altPos = pos + float2(0.1 * size.x, 0.8 * size.y)
    let altMul = metrToFeet
    let alt = "A{fmt(":.1f", targetAltKm * altMul)}"
    ctx |> goto_xy(altPos.x, altPos.y)
    ctx |> draw_str_scaled(1.0, alt, alt |> length())

    let machPos = pos + float2(0.55 * size.x, 0.4 * size.y)
    let machVal = sqrt(taretSpeedSq) / atmosphere_sonicSpeed(targetAltKm * 0.001)
    let mach = "M{fmt(":.2f", machVal)}"
    ctx |> goto_xy(machPos.x, machPos.y)
    ctx |> draw_str_scaled(1.0, mach, mach |> length())

    let tgtPos = pos + float2(0.55 * size.x, 0.8 * size.y)
    let azimuthDegVal = norm_ang(atan2(hero.unitTm[0].x, hero.unitTm[0].z) + targetAzimuth) * 180.0 / PI
    let azimuth = "TGT {fmt(": .0f", azimuthDegVal)}"
    ctx |> set_font_ht(15)
    ctx |> goto_xy(tgtPos.x, tgtPos.y)
    ctx |> draw_str_scaled(1.0, azimuth, azimuth |> length())

def draw_round_radar(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  ctx |> draw_round_scan_angles(data, origin, size)
  ctx |> draw_radar_cue_indication(data, origin, size)

def draw_radar_cue_indication(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let startPos = float2(origin.x + 0.95 * size.x, origin.y + size.y * 0.5)

  ctx |> render_simple_line(startPos + float2(0.0, 0.5 * size.y), startPos - float2(0.5, size.y), colors.white, data.lineWidth)

  let arrowPos = float2(startPos.x, startPos.y - size.y * get_radar_hud_cue_distance())
  ctx |> render_simple_line(arrowPos, arrowPos + float2(0.05 * size.x, 0.02 * size.y), colors.cyan, data.lineWidth)
  ctx |> render_simple_line(arrowPos, arrowPos + float2(0.05 * size.x, -0.02 * size.y), colors.cyan, data.lineWidth)
  ctx |> render_simple_line(arrowPos + float2(0.05 * size.x, 0.02 * size.y), arrowPos + float2(0.05 * size.x, -0.02 * size.y), colors.cyan, data.lineWidth)


  let maxDistMiles = yWorldSize * metersToMiles
  let step = 2.5
  let numberOfTicks = int(maxDistMiles / step)

  for i in range(-numberOfTicks, numberOfTicks)
    let tickStart = startPos - float2(0.0, float(i) * size.y * 0.5 / float(numberOfTicks))
    let tickEnd = tickStart - float2(0.03 * size.x, 0)
    ctx |> render_simple_line(tickStart, tickEnd, colors.white, data.lineWidth)
    if i % 4 == 0
      let lablePos = tickStart + float2(-0.1 * size.x, 0.02 * size.y)
      ctx |> draw_horizontal_label(lablePos, "{int(float(i) * step)}")


// utils

def render_simple_line(var ctx : GuiContext&; begin : float2; end : float2; color : E3DCOLOR; width : float)
  let line <- to_array_move(fixed_array<float2>(begin, end))
  ctx |> render_line_aa(line, false, width, float2(0, 0), color)

def draw_horizontal_label(var ctx : GuiContext&; pos : float2; text : string)
  ctx |> goto_xy(pos.x, pos.y)
  ctx |> draw_str_scaled(1.0, text, text |> length())