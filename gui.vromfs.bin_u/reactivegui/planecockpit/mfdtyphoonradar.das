require darg
require DagorStdGuiRender
require DagorMath
require RadarHud
require strings
require FlightModelWrap
require HeroManager
require app
require Unit
require math
require GamePhys
require %rGui.utils.constants_common
require %rGui.utils.radar_common

let gridColor = E3DCOLOR(0xFF0000FF)
let gridEdgeColor = E3DCOLOR(0xFF1111FF)
let whiteColor = E3DCOLOR(0xFFFFFFFF)
let enemyColor = E3DCOLOR(0xFFFF0000)
let allyColor = E3DCOLOR(0xFF00FF00)

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  lineWidth : float = 2.

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.lineWidth = props |> getFloat("lineWidth", 1.) * 2.

[export, unused_argument(rstate)]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !get_radar_hud_mfd_radar_enabled()
    return
  let radarSize = rdata.size * 0.95
  let radarPos = rdata.pos + float2(rdata.size.x * 0.025, 0)
  draw_grid(ctx, radarPos, radarSize, data)
  draw_targets(ctx, radarPos, radarSize, data)
  draw_cue(ctx, radarPos, radarSize, data)
  draw_fly_info(ctx, rdata.pos, rdata.size, data)

def draw_grid(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  let origin = pos + float2(size.x * 0.5, size.y)
  ctx |> set_color(gridColor)
  ctx |> draw_line(origin.x, origin.y, origin.x, pos.y, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.1, origin.y, pos.x + size.x * 0.1, pos.y, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.3, origin.y, pos.x + size.x * 0.3, pos.y, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.7, origin.y, pos.x + size.x * 0.7, pos.y, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.9, origin.y, pos.x + size.x * 0.9, pos.y, data.lineWidth)
  ctx |> draw_line(pos.x, pos.y + size.y * 0.5, pos.x + size.x, pos.y + size.y * 0.5, data.lineWidth)
  ctx |> draw_line(pos.x, pos.y + size.y * 0.25, pos.x + size.x, pos.y + size.y * 0.25, data.lineWidth)
  ctx |> draw_line(pos.x, pos.y + size.y * 0.75, pos.x + size.x, pos.y + size.y * 0.75, data.lineWidth)
  ctx |> set_color(gridEdgeColor)
  ctx |> draw_line(pos.x, origin.y, pos.x, pos.y, data.lineWidth)
  ctx |> draw_line(pos.x + size.x, origin.y, pos.x + size.x, pos.y, data.lineWidth)
  ctx |> set_color(E3DCOLOR(0xFF00FF00))
  ctx |> draw_line(pos.x, pos.y + size.y, pos.x + size.x, pos.y + size.y, data.lineWidth)

  var fctx : StdGuiFontContext
  let fontSize = int(float(data.fontSize) * 0.8)
  get_font_context(fctx, data.fontId, 0, 0, fontSize)
  ctx |> set_color(E3DCOLOR(0xFFFFFF77))
  ctx |> set_font_ht(fontSize)

  let dist = get_radar_hud_distance_max() * kmetrToNavMile
  let distMaxStr = fmt(":d", roundi(dist))
  ctx |> goto_xy(pos.x + size.x * 0.01, pos.y + size.y * 0.1)
  ctx |> draw_str_scaled(1.0, distMaxStr, distMaxStr |> length())

  let dist1Str = fmt(":d", roundi(dist * 0.75))
  let dist1StrBox = get_str_bbox(dist1Str, dist1Str |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.01, pos.y + size.y * 0.25 + dist1StrBox.width.y)
  ctx |> draw_str_scaled(1.0, dist1Str, dist1Str |> length())

  let dist2Str = fmt(":d", roundi(dist * 0.5))
  let dist2StrBox = get_str_bbox(dist2Str, dist2Str |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.01, pos.y + size.y * 0.5 + dist2StrBox.width.y)
  ctx |> draw_str_scaled(1.0, dist2Str, dist2Str |> length())

  let dist3Str = fmt(":d", roundi(dist * 0.25))
  let dist3StrBox = get_str_bbox(dist3Str, dist3Str |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.01, pos.y + size.y * 0.75 + dist3StrBox.width.y)
  ctx |> draw_str_scaled(1.0, dist3Str, dist3Str |> length())

def draw_fly_info(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  ctx |> set_color(whiteColor)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let iasStr = "{fmt(":d", roundi(fmw.ias * mpsToKnots))} KT"
  let strBox = get_str_bbox(iasStr, iasStr |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.125 - strBox.width.x * 0.5, pos.y + strBox.width.y + size.y * 0.04)
  ctx |> draw_str_scaled(1.0, iasStr, iasStr |> length())

  let compass = roundi((norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * 180. / PI)
  let compassStr = "{compass}°"
  let cmpsStrBox = get_str_bbox(compassStr, compassStr |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.5 - cmpsStrBox.width.x * 0.5, pos.y + cmpsStrBox.width.y + size.y * 0.04)
  ctx |> draw_str_scaled(1.0, compassStr, compassStr |> length())

  let barHStr = fmt(":.1f", floor(hero.pos.y * metrToFeet * 0.01) * 0.1)
  let barHStrBox = get_str_bbox(barHStr, barHStr |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.75, pos.y + barHStrBox.width.y + size.y * 0.04)
  ctx |> draw_str_scaled(1.0, barHStr, barHStr |> length())

  let lowFontSize = int(float(data.fontSize) * 0.8)
  get_font_context(fctx, data.fontId, 0, 0, lowFontSize)
  ctx |> set_font_ht(lowFontSize)

  let barLStr = "{fmt(":02d", roundi(hero.pos.y * metrToFeet % 100.0))}FT"
  ctx |> goto_xy(pos.x + size.x * 0.75 + barHStrBox.width.x, pos.y + barHStrBox.width.y + size.y * 0.04)
  ctx |> draw_str_scaled(1.0, barLStr, barLStr |> length())

def draw_targets(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  let markSize = size * 0.025

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 14)

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(14)

  Radar`foreach_visible_target() <| $(var target)
    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      let angleRel = target.azimuthRel
      var distanceRel = 0.9
      if target.distanceRel >= 0.
        distanceRel = target.distanceRel

      let p = float2(pos.x + angleRel * size.x, pos.y + (1. - distanceRel) * size.y)
      if target.isEnemy
        let diamond <- to_array_move(fixed_array<float2>(
         float2(p.x + markSize.x, p.y),
         float2(p.x, p.y + markSize.y),
         float2(p.x - markSize.x, p.y),
         float2(p.x, p.y - markSize.y)))
        ctx |> render_poly(diamond, enemyColor)
        ctx |> render_line_aa(diamond, true, data.lineWidth, float2(0, 0), whiteColor)
      else
        ctx |> render_ellipse_aa(p, markSize, data.lineWidth, whiteColor, allyColor)

      let str = "A"
      let strBox = get_str_bbox(str, 1, fctx)
      ctx |> goto_xy(p.x - strBox.width.x * 0.5, p.y + strBox.width.y * 0.5)
      ctx |> draw_char_u(uint16('A' + int(target.persistentIndex)))

      if target.losSpeed < 3000.
        ctx |> set_color(whiteColor)
        let targetSpd = sqrt(target.losHorSpeed * target.losHorSpeed + target.losSpeed * target.losSpeed)
        let targetSpdInv = 1. / max(targetSpd, 1.)
        ctx |> draw_line(p.x - target.losHorSpeed * targetSpdInv * markSize.x,
          p.y - target.losSpeed * targetSpdInv * markSize.y,
          p.x - target.losHorSpeed * targetSpdInv * min(markSize.x + targetSpd * 0.5, 3. * markSize.x),
          p.y - target.losSpeed * targetSpdInv * min(markSize.y + targetSpd * 0.5, 3. * markSize.y), data.lineWidth)

      if target.isTracked
        let l1 <- to_array_move(fixed_array(
          p + float2(-markSize.x, -markSize.y),
          p + float2(-markSize.x * 1.3, -markSize.y * 1.3)))
        let l2 <- to_array_move(fixed_array(
          p + float2(markSize.x, markSize.y),
          p + float2(markSize.x * 1.3, markSize.y * 1.3)))
        let l3 <- to_array_move(fixed_array(
          p + float2(-markSize.x, markSize.y),
          p + float2(-markSize.x * 1.3, markSize.y * 1.3)))
        let l4 <- to_array_move(fixed_array(
          p + float2(markSize.x, -markSize.y),
          p + float2(markSize.x * 1.3, -markSize.y * 1.3)))
        ctx |> render_line_aa(l1, false, data.lineWidth, float2(0.), whiteColor)
        ctx |> render_line_aa(l2, false, data.lineWidth, float2(0.), whiteColor)
        ctx |> render_line_aa(l3, false, data.lineWidth, float2(0.), whiteColor)
        ctx |> render_line_aa(l4, false, data.lineWidth, float2(0.), whiteColor)
        draw_target_info(ctx, pos + float2(-size.x * 0.05, size.y), float2(size.x / 0.95, size.y * 0.05), data, int(target.persistentIndex), target)
      elif target.isDetected
        if target.isEnemy
          let diamond <- to_array_move(fixed_array<float2>(
          float2(p.x + markSize.x * 1.5, p.y),
          float2(p.x, p.y + markSize.y * 1.5),
          float2(p.x - markSize.x * 1.5, p.y),
          float2(p.x, p.y - markSize.y * 1.5)))
          ctx |> render_line_aa(diamond, true, data.lineWidth, float2(0, 0), whiteColor)
        else
          ctx |> render_ellipse_aa(p, markSize * 1.5, data.lineWidth, whiteColor, allyColor)
        draw_target_info(ctx, pos + float2(-size.x * 0.05, size.y), float2(size.x / 0.95, size.y * 0.05), data, int(target.persistentIndex), target)

def draw_target_info(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; i : int; target : RadarTarget const const#)
  let newFontSize = int(float(data.fontSize) * 0.8)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, newFontSize)

  ctx |> set_color(whiteColor)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(newFontSize)

  if target.typeId != ""
    let idText = loc(target.typeId)
    ctx |> goto_xy(pos.x + size.x * 0.14, pos.y + size.y * 0.75)
    ctx |> draw_str_scaled(1.0, idText, idText |> length())

  let unit = get_unit(int(target.id))
  if unit == null || unit.isDelayed
    return

  ctx |> goto_xy(pos.x + size.x * 0.1, pos.y + size.y * 0.75)
  ctx |> draw_char_u(uint16('A' + i))

  ctx |> goto_xy(pos.x + size.x * 0.3, pos.y - 5.)
  ctx |> draw_char_u(uint16('A' + i))

  let aBox = get_str_bbox("A", 1, fctx)
  ctx |> set_color(E3DCOLOR(0xFFFF0000))
  ctx |> render_frame(pos.x + size.x * 0.3 - 5., pos.y - 8. - aBox.width.y, pos.x + size.x * 0.3 + aBox.width.x + 5., pos.y, data.lineWidth)

  ctx |> set_color(whiteColor)

  let spd = "{roundi(unit.speed * mpsToKnots)}KT"
  ctx |> goto_xy(pos.x + size.x * 0.25, pos.y + size.y * 0.75)
  ctx |> draw_str_scaled(1.0, spd, spd |> length())

  let compass = roundi((norm_ang(2. * PI + atan2(unit.unitTm[0].x, unit.unitTm[0].z))) * 180. / PI)
  let compassStr = fmt(":03d", compass)
  ctx |> goto_xy(pos.x + size.x * 0.36, pos.y + size.y * 0.75)
  ctx |> draw_str_scaled(1.0, compassStr, compassStr |> length())

  let hei = "{fmt(":.1f", floor(unit.pos.y * metrToFeet * 0.01) * 0.1)}"
  let heiStrBox = get_str_bbox(hei, hei |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.5 - heiStrBox.width.x, pos.y + size.y * 0.75)
  ctx |> draw_str_scaled(1.0, hei, hei |> length())

def rad_to_deg(rad : float)
  return rad * 180. / PI

def draw_cue(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  if !get_radar_hud_cue_visible()
    return
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let cueAzimuthHwr = get_radar_hud_cue_azimuth_half_width_rel()
  let cueDistWidthRel =  get_radar_hud_cue_dist_width_rel()
  let cuePos = pos + float2((get_radar_hud_cue_azimuth() * (get_radar_hud_target_azimuth_width() / azimuthRange - cueAzimuthHwr) + 0.5) * size.x,
          (1. - (0.5 * cueDistWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - cueDistWidthRel))) * size.y)
  let lcoord <- to_array_move(fixed_array<float2>(float2(cuePos.x - cueAzimuthHwr * size.x, cuePos.y),
   float2(cuePos.x - cueAzimuthHwr * size.x * 0.35, cuePos.y)))
  ctx |> render_line_aa(lcoord, false, data.lineWidth, float2(0, 0), whiteColor)
  let rcoord <- to_array_move(fixed_array<float2>(float2(cuePos.x + cueAzimuthHwr * size.x, cuePos.y),
   float2(cuePos.x + cueAzimuthHwr * size.x * 0.35, cuePos.y)))
  ctx |> render_line_aa(rcoord, false, data.lineWidth, float2(0, 0), whiteColor)
  let tcoord <- to_array_move(fixed_array<float2>(float2(cuePos.x, cuePos.y - cueDistWidthRel * size.y * 0.35),
   float2(cuePos.x, cuePos.y - cueDistWidthRel * size.y)))
  ctx |> render_line_aa(tcoord, false, data.lineWidth, float2(0, 0), whiteColor)
  let bcoord <- to_array_move(fixed_array<float2>(float2(cuePos.x, cuePos.y + cueDistWidthRel * size.y * 0.35),
   float2(cuePos.x, cuePos.y + cueDistWidthRel * size.y)))
  ctx |> render_line_aa(bcoord, false, data.lineWidth, float2(0, 0), whiteColor)

  var fctx : StdGuiFontContext
  let fontSize = int(float(data.fontSize) * 0.8)
  get_font_context(fctx, data.fontId, 0, 0, fontSize)

  ctx |> set_color(whiteColor)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(fontSize)

  let dist = roundi(get_radar_hud_cue_distance() * get_radar_hud_distance_max() * kmetrToNavMile)
  let angle = roundi(rad_to_deg(get_radar_hud_cue_azimuth() * azimuthRange))
  let cueData = "{angle}/{dist}"
  ctx |> goto_xy(pos.x + size.x * 0.02, pos.y + size.y * 0.2)
  ctx |> draw_str_scaled(1., cueData, cueData |> length())
