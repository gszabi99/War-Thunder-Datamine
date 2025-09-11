require darg
require DagorStdGuiRender
require RadarHud
require math
require DagorMath
require strings
require HeroManager
require Unit
require %rGui.utils.radar_common

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  backgroundColor : E3DCOLOR = E3DCOLOR(0xFF000000)

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.color = fade_color(props |> getColor("color", E3DCOLOR(0xFFFFFFFF)), 255)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.backgroundColor = fade_color(props |> getColor("backgroundColor", E3DCOLOR(0xFFFFFFFF)), 255)

[export, unused_argument(rstate)]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !get_radar_hud_mfd_radar_enabled()
    return
  mfd_radar_background(ctx, rdata, data)
  draw_scale(ctx, rdata, data)
  draw_tas(ctx, rdata, data)
  b_scope_sector(ctx, rdata, data)
  owner_mark(ctx, rdata, data)
  draw_targets(ctx, rdata, data)
  draw_launch_zone(ctx, rdata, data)


def mfd_radar_background(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let scale = get_radar_hud_mfd_radar_scale() > 0. ? get_radar_hud_mfd_radar_scale() : 1.
  let size = rdata.size / scale
  let pos = float2(rdata.pos.x - (1. - scale) * 0.5 * size.x, rdata.pos.y - (1. - scale) * 0.5 * size.y)
  ctx |> set_color(data.backgroundColor)
  ctx |> render_box(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

def draw_scale(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  ctx |> set_color(data.color)
  let pos = rdata.pos
  let sz = rdata.size
  ctx |> draw_line(pos.x, pos.y + 0.98 * sz.y, pos.x + 0.1 * sz.x, pos.y + 0.98 * sz.y, ctx |> hdpx(2.))
  ctx |> draw_line(pos.x, pos.y + 0.98 * sz.y, pos.x, pos.y + 0.96 * sz.y, ctx |> hdpx(2.))
  ctx |> draw_line(pos.x + 0.1 * sz.x, pos.y + 0.98 * sz.y, pos.x + 0.1 * sz.x, pos.y + 0.96 * sz.y, ctx |> hdpx(2.))

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  let scaleText = fmt(":d", roundi(get_radar_hud_distance_max() * 0.1))
  let scaleTextBox = get_str_bbox(scaleText, scaleText |> length(), fctx)
  ctx |> goto_xy(pos.x + 0.5 * (sz.x * 0.1 - scaleTextBox.width.x), pos.y + 0.98 * sz.y - 5.)
  ctx |> draw_str_scaled(1.0, scaleText, scaleText |> length())

def draw_tas(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return

  let pos = rdata.pos
  let sz = rdata.size
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let speedText = fmt(":d", roundi(hero.speed * 3.6))
  let speedTextBox = get_str_bbox(speedText, speedText |> length(), fctx)
  ctx |> render_frame(pos.x + 0.9 * sz.x, pos.y + sz.y * 0.98 - speedTextBox.width.y * 2., pos.x + sz.x, pos.y + sz.y * 0.98, ctx |> hdpx(1.))
  ctx |> goto_xy(pos.x + 0.95 * sz.x - speedTextBox.width.x * 0.5, pos.y + sz.y * 0.98 - speedTextBox.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, speedText, speedText |> length())

def b_scope_sector(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let pos = rdata.pos
  let sz = rdata.size
  let sectorR = rdata.size * 0.8 * get_radar_hud_target_distance()
  let origin = pos + float2(sz.x * 0.5, sz.y * 0.9)
  ctx |> render_sector_aa(origin, sectorR, float2(-PI, 0.), 1.2,
   data.color, transparentColor)

  let coord <- to_array_move(fixed_array<float2>(float2(pos.x + sz.x * 0.5, origin.y - sectorR.y - sz.y * 0.02),
   float2(pos.x + sz.x * 0.48, origin.y - sectorR.y + sz.y * 0.02),
   float2(pos.x + sz.x * 0.52, origin.y - sectorR.y + sz.y * 0.02)))
  ctx |> render_line_aa(coord, true, 2., float2(0, 0), data.color)
  ctx |> draw_line(pos.x + sz.x * 0.5, origin.y - sectorR.y - sz.y * 0.03, pos.x + sz.x * 0.5, origin.y - sectorR.y, 2.)

def owner_mark(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let pos = rdata.pos
  let sz = rdata.size
  let origin = pos + float2(sz.x * 0.5, sz.y * 0.9)

  ctx |> render_ellipse_aa(origin, sz * 0.01, 1., data.color, transparentColor)
  ctx |> draw_line(origin.x, origin.y - sz.y * 0.01, origin.x, origin.y - sz.y * 0.05, 2.)

def draw_targets(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let radius = rdata.size * 0.8
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let origin = rdata.pos + float2(rdata.size.x * 0.5, rdata.size.y * 0.9)
  Radar`foreach_visible_target() <| $(var target)
    var color = float4(Color4(data.color))
    let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
    color *= (1. - target.ageRel) * signalRel
    let e3dColor = E3DCOLOR(Color4(color))

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

      let angleLeft = max(angle - 0.5 * angularWidth, get_radar_hud_azimuth_min() - PI * 0.5)
      let angleRight = min(angle + 0.5 * angularWidth, get_radar_hud_azimuth_max() - PI * 0.5)
      let sina = sin(angle)
      let cosa = cos(angle)
      let pos = origin + float2(cosa * distanceRel * radius.x, sina * distanceRel * radius.y)
      if !target.isEnemy
        ctx |> render_ellipse_aa(pos, rdata.size * 0.01, 1., e3dColor, transparentColor)
      elif target.isSelected && get_radar_hud_has_azimuth_scale() && target.losSpeed < 30000.
        let losAngle = atan2(target.losHorSpeed, -target.losSpeed)
        ctx |> setRotViewTm(pos.x, pos.y, losAngle, 0., false)

        ctx |> set_color(e3dColor)
        ctx |> draw_line(pos.x - rdata.size.y * 0.03, pos.y, pos.x + rdata.size.y * 0.03, pos.y, 2.)
        let los = sqrt(target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed) * 0.1
        ctx |> draw_line(pos.x, pos.y, pos.x, pos.y + los, 2.)
        if target.isTracked
          let coord <- to_array_move(fixed_array<float2>(pos,
            float2(pos.x + rdata.size.x * 0.02, pos.y - rdata.size.y * 0.03),
            float2(pos.x - rdata.size.x * 0.02, pos.y - rdata.size.y * 0.03)))
          ctx |> render_line_aa(coord, true, 2., float2(0, 0), data.color)

        ctx |> resetViewTm()
      else
        ctx |> render_sector_aa(origin, radius * distanceRel, float2(angleLeft, angleRight), 100. * radialWidthRel, e3dColor, transparentColor)

def draw_launch_zone(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  if !get_radar_hud_aam_launch_zone_visible() || !get_radar_hud_has_distance_scale()
    return
  let origin = rdata.pos + float2(rdata.size.x * 0.5, rdata.size.y * 0.9)

  let distMax = get_radar_hud_aam_launch_zone_dist_max()
  if distMax <= 1.
    let angles = float2(get_radar_hud_azimuth_min() - PI * 0.5, get_radar_hud_azimuth_max() - PI * 0.5)
    ctx |> render_sector_aa(origin, rdata.size * 0.45 * distMax, angles, 2., data.color, transparentColor)
    ctx |> draw_line(origin.x + cos(angles.x) * rdata.size.x * 0.05 * distMax, origin.y + sin(angles.x) * rdata.size.y * 0.05 * distMax,
     origin.x + cos(angles.x) * rdata.size.x * 0.45 * distMax, origin.y + sin(angles.x) * rdata.size.y * 0.45 * distMax, 2.)
    ctx |> draw_line(origin.x + cos(angles.y) * rdata.size.x * 0.05 * distMax, origin.y + sin(angles.y) * rdata.size.y * 0.05 * distMax,
     origin.x + cos(angles.y) * rdata.size.x * 0.45 * distMax, origin.y + sin(angles.y) * rdata.size.y * 0.45 * distMax, 2.)