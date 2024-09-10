require darg
require DagorStdGuiRender
require DagorMath
require DagorSystem
require math
require FlightModelWrap
require HeroManager
require Unit
require strings
require Sensors
require RadarHud
require app
require hud

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))
let mpsToKnots = 1.94384
let metrToFeet = 3.28084
let mpsToKmh = 3.6
let metrToMile = 0.000621371

def deg_to_rad(rad : float)
  return rad * PI / 180.

def rad_to_deg(rad : float)
  return rad * 180. / PI

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  lineWidth : float = 2.
  isMetricUnits : bool = true

[export]
def setup_hmd_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.lineWidth = props |> getFloat("lineWidth", 2.)
  storage.isMetricUnits = props |> getBool("isMetricUnits", true)

[export]
def draw_hmd(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return
  let isCcipMode = fmw.sightMode >= int(CockpitSightMode HUD_SIGHT_MODE_GROUND_CANNONS)
  if hero.sensors |> hasSelectedTargetOfInterest() || isCcipMode
    draw_impoved_marker(ctx, data, rdata.pos, rdata.size, hero, isCcipMode)
  else
    draw_aim_mark(ctx, data, rdata.pos, rdata.size)
  draw_roll_pitch(ctx, data, rdata.pos, rdata.size, fmw)
  draw_speed(ctx, data, rdata.pos, rdata.size, fmw)
  draw_altitude(ctx, data, rdata.pos, rdata.size, fmw)
  draw_current_weapon(ctx, data, rdata.pos, rdata.size)
  draw_radar_target_mark(ctx, data, rdata.pos, rdata.size, hero)

def draw_aim_mark(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let center = pos + size * 0.5
  ctx |> set_color(data.color)
  ctx |> draw_line(center.x - size.y * 0.01, center.y - size.y * 0.01, center.x - size.y * 0.03, center.y - size.y * 0.03, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x + size.y * 0.01, center.y - size.y * 0.01, center.x + size.y * 0.03, center.y - size.y * 0.03, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x - size.y * 0.01, center.y + size.y * 0.01, center.x - size.y * 0.03, center.y + size.y * 0.03, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x + size.y * 0.01, center.y + size.y * 0.01, center.x + size.y * 0.03, center.y + size.y * 0.03, ctx |> hdpx(data.lineWidth))

def draw_roll_pitch(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; fmw : FlightModelWrap?)
  let roll = deg_to_rad(fmw.roll) - PI * 0.5
  let pitch = deg_to_rad(fmw.tangage) + PI * 0.5
  ctx |> set_color(data.color)

  let sectorAngles = float2(roll + pitch, roll - pitch)
  let center = pos + size * 0.5
  let rad = size.y * 0.3
  ctx |> render_sector_aa(center, float2(rad), sectorAngles, data.lineWidth, data.color, transparentColor)
  let edge1Beg = center + rad * float2(cos(sectorAngles.x), sin(sectorAngles.x))
  let edge1End = center + (rad + size.y * 0.02) * float2(cos(sectorAngles.x), sin(sectorAngles.x))
  ctx |> draw_line(edge1Beg.x, edge1Beg.y, edge1End.x, edge1End.y, ctx |> hdpx(data.lineWidth))
  let edge2Beg = center + rad * float2(cos(sectorAngles.y), sin(sectorAngles.y))
  let edge2End = center + (rad + size.y * 0.02) * float2(cos(sectorAngles.y), sin(sectorAngles.y))
  ctx |> draw_line(edge2Beg.x, edge2Beg.y, edge2End.x, edge2End.y, ctx |> hdpx(data.lineWidth))

  ctx |> draw_line(center.x - rad, center.y, center.x - rad - size.y * 0.02, center.y, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x + rad, center.y, center.x + rad + size.y * 0.02, center.y, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x, center.y + rad, center.x - size.y * 0.01, center.y + rad + size.y * 0.02, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x, center.y + rad, center.x + size.y * 0.01, center.y + rad + size.y * 0.02, ctx |> hdpx(data.lineWidth))

  let centerAngle = (sectorAngles.x + sectorAngles.y) * 0.5 - PI
  let cosa = cos(centerAngle)
  let sina = sin(centerAngle)
  let inner = rad - size.y * 0.02
  ctx |> draw_line(center.x + rad * cosa, center.y + rad * sina, center.x + inner * cosa - sina * 10., center.y + inner * sina + cosa * 10., ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x + rad * cosa, center.y + rad * sina, center.x + inner * cosa + sina * 10., center.y + inner * sina - cosa * 10., ctx |> hdpx(data.lineWidth))

def draw_speed(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; fmw : FlightModelWrap?)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  let iasStr = fmt(":d", roundi(fmw.ias * (data.isMetricUnits ? mpsToKmh : mpsToKnots)))
  let strBox = get_str_bbox(iasStr, iasStr |> length(), fctx)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);
  ctx |> set_color(data.color)
  //ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.modeColor), get_font_fx_factor(data.modeColor, ctx))

  ctx |> goto_xy(pos.x + size.x * 0.38, pos.y + size.y * 0.5 - strBox.width.y)
  ctx |> draw_str_scaled(1.0, iasStr, iasStr |> length())

  let mach = "M: {fmt(":.2f", fmw.fm.mach)}"
  ctx |> goto_xy(pos.x + size.x * 0.38, pos.y + size.y * 0.5 + 2.)
  ctx |> draw_str_scaled(1.0, mach, mach |> length())

def draw_altitude(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; fmw : FlightModelWrap?)
  let markPos = float2(pos.x + size.x * 0.6, pos.y + size.y * 0.5)
  ctx |> set_color(data.color)
  ctx |> draw_line(markPos.x, markPos.y, markPos.x - size.x * 0.01, markPos.y - size.y * 0.005, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(markPos.x, markPos.y, markPos.x - size.x * 0.01, markPos.y + size.y * 0.005, ctx |> hdpx(data.lineWidth))

  let step = size.y * 0.04 / 250.
  let alt = fmw.fm.alt * (data.isMetricUnits ? 1. : metrToFeet)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  let startMark = roundi(alt / 250.) * 250
  for i in range(-2, 3)
    let val = float(startMark + i * 250)
    if (val <= 500.)
      continue
    let withText = val % 500. == 0.
    draw_altitude_line(ctx, data, fctx, size, step, markPos, val, alt, withText)

  for i in range(0, 6)
    let val = float(100 * i)
    if (val < alt - 625.)
      continue
    draw_altitude_line(ctx, data, fctx, size, step, markPos, val, alt, true)

  let rtext = "RALT"
  let altBox = get_str_bbox(rtext, rtext |> length(), fctx)
  ctx |> goto_xy(markPos.x + 5., markPos.y + altBox.width.y + size.y * 0.12)
  ctx |> draw_str_scaled(1.0, rtext, rtext |> length())

def draw_altitude_line(var ctx : GuiContext&; data : CanvasParams&; fctx : StdGuiFontContext; size : float2; step : float; mark_pos : float2; val : float; current_alt : float; with_text : bool)
  if val < 0.
    return

  let linePos = (current_alt - val) * step + mark_pos.y
  ctx |> draw_line(mark_pos.x + 2., linePos, mark_pos.x + size.x * (with_text ? 0.01 : 0.003) + 2., linePos, ctx |> hdpx(data.lineWidth))

  if !with_text
    return
  let text = fmt(":d", roundi(val))
  let strBox = get_str_bbox(text, text |> length(), fctx)
  ctx |> goto_xy(mark_pos.x + size.x * 0.01 + 5., linePos + strBox.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_marker_with_dist(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; hero : Unit?; dist : float)
  let center = pos + size * 0.5
  let radius = size.y * 0.05
  let inner = radius - size.y * 0.01
  let outer = radius + size.y * 0.01
  ctx |> set_color(data.color)
  let coord <- to_array_move([[float2[2] center; center]])
  ctx |> render_line_aa(coord, false, data.lineWidth * 2., float2(0.), data.color)

  let radarDistSector = dist <= 0. ? -PI : cvt(dist, 0.0, 8400., PI, -PI + 0.01)
  ctx |> render_sector_aa(center, float2(radius), float2(radarDistSector, PI), data.lineWidth, data.color, transparentColor)

  let cosR = cos(radarDistSector)
  let sinR = sin(radarDistSector)
  ctx |> draw_line(center.x + radius * cosR, center.y + radius * sinR, center.x + inner * cosR - 5. * sinR, center.y + inner * sinR + 5. * cosR, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x + radius * cosR, center.y + radius * sinR, center.x + inner * cosR + 5. * sinR, center.y + inner * sinR - 5. * cosR, ctx |> hdpx(data.lineWidth))

  ctx |> draw_line(center.x, center.y - radius, center.x, center.y - outer, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x - radius, center.y, center.x - outer, center.y, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x, center.y + radius, center.x, center.y + outer, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(center.x + radius, center.y, center.x + outer, center.y, ctx |> hdpx(data.lineWidth))
  for i in range(0, 12 - int((radarDistSector - PI) / PI * -6.))
    if i % 3 == 0
      continue
    let angle = float(i) * 2. * PI * 0.08333 - PI
    let cosa = cos(angle)
    let sina = sin(angle)
    let pcoord <- to_array_move([[float2[2] float2(center.x + radius * cosa, center.y + radius * sina); float2(center.x + radius * cosa, center.y + radius * sina)]])
    ctx |> render_line_aa(pcoord, false, data.lineWidth * 2., float2(0.), data.color)

  if get_radar_hud_aam_launch_zone_visible()
    let minDist = cvt(get_radar_hud_aam_launch_zone_dist_min() * get_radar_hud_distance_max(), 0., 8.4, PI, -PI)
    let cosa = cos(minDist)
    let sina = sin(minDist)
    ctx |> draw_line(center.x + radius * cosa, center.y + radius * sina, center.x + outer * cosa, center.y + outer * sina, ctx |> hdpx(data.lineWidth))
    ctx |> draw_line(center.x + outer * cosa, center.y + outer * sina,
    center.x + outer * cosa + size.y * 0.01 * sina, center.y + outer * sina - size.y * 0.01 * cosa, ctx |> hdpx(data.lineWidth))

    let maxDist = cvt(get_radar_hud_aam_launch_zone_dist_max() * get_radar_hud_distance_max(), 0., 8.4, PI, -PI)
    let cosm = cos(maxDist)
    let sinm = sin(maxDist)
    ctx |> draw_line(center.x + radius * cosm, center.y + radius * sinm, center.x + outer * cosm, center.y + outer * sinm, ctx |> hdpx(data.lineWidth))
    ctx |> draw_line(center.x + outer * cosm, center.y + outer * sinm,
     center.x + outer * cosm - size.y * 0.01 * sinm, center.y + outer * sinm + size.y * 0.01 * cosm, ctx |> hdpx(data.lineWidth))

    let dgftDist = cvt(get_radar_hud_aam_launch_zone_dist_dgft_max() * get_radar_hud_distance_max(), 0., 8.4, PI, -PI)
    let cosd = cos(dgftDist)
    let sind = sin(dgftDist)
    ctx |> draw_line(center.x + radius * cosd, center.y + radius * sind, center.x + outer * cosd, center.y + outer * sind, ctx |> hdpx(data.lineWidth))
    ctx |> draw_line(center.x + outer * cosd - size.y * 0.01 * sind, center.y + outer * sind + size.y * 0.01 * cosd,
    center.x + outer * cosd + size.y * 0.01 * sind, center.y + outer * sind - size.y * 0.01 * cosd, ctx |> hdpx(data.lineWidth))

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);

  let distance = dist * (data.isMetricUnits ? 0.001 : metrToMile)
  let distText = fmt(":.1f", distance)
  let distTextBox = get_str_bbox(distText, distText |> length(), fctx)

  ctx |> goto_xy(center.x - distTextBox.width.x * 0.5, center.y + radius + distTextBox.width.y + size.y * 0.01)
  ctx |> draw_str_scaled(1.0, distText, distText |> length())

def draw_impoved_marker(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; hero : Unit?; ccip : bool)
  if ccip
    draw_marker_with_dist(ctx, data, pos, size, hero, get_hud_dist_to_target())
  else
    using() <| $(var target : TargetOfInterest#)
      if hero.sensors |> getSelectedTargetOfInterest(hero.detector, target)
        draw_marker_with_dist(ctx, data, pos, size, hero, target.distance)

def draw_current_weapon(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);

  let weaponName = get_hud_cur_weapon_name() != "" ? loc(get_hud_cur_weapon_name()) : "GUN"
  let textBox = get_str_bbox(weaponName, weaponName |> length(), fctx)

  ctx |> goto_xy(pos.x + size.x * 0.5 - textBox.width.x * 0.5, pos.y + size.y * 0.78)
  ctx |> draw_str_scaled(1.0, weaponName, weaponName |> length())

def draw_radar_target_mark(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; hero : Unit?)
  using() <| $(var target : TargetOfInterest#)
    if hero.sensors |> getSelectedTargetOfInterest(hero.detector, target)
      let worldPos = target.from + target.dirNorm * target.distance;
      var screenPos : float2
      if world_to_hmd_screen(worldPos, screenPos)
        if screenPos.x > size.x * 0.2 && screenPos.x < size.x * 0.8 && screenPos.y > size.y * 0.2 && screenPos.y < size.y * 0.8
          ctx |> draw_line(screenPos.x - size.x * 0.01, screenPos.y, screenPos.x + size.x * 0.01, screenPos.y, ctx |> hdpx(data.lineWidth))
          ctx |> draw_line(screenPos.x - size.x * 0.01, screenPos.y, screenPos.x - size.x * 0.01, screenPos.y + 10., ctx |> hdpx(data.lineWidth))
          ctx |> draw_line(screenPos.x + size.x * 0.01, screenPos.y, screenPos.x + size.x * 0.01, screenPos.y + 10., ctx |> hdpx(data.lineWidth))