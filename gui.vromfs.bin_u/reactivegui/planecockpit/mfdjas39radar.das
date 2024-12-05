require darg
require DagorStdGuiRender
require DagorMath
require RadarHud
require strings
require FlightModelWrap
require HeroManager
require Unit
require math
require GamePhys

let backgroundColor = E3DCOLOR(Color4(float4(0.5, 0.5, 0.5, 1.0)))
let radarBackgroundColor = E3DCOLOR(Color4(float4(0., 0.75, 1.0, 1.0)))
let radarScanColor = E3DCOLOR(Color4(float4(1., 1., 0.5, 1.0)))
let padding = 10.
let textColor = E3DCOLOR(Color4(float4(0., 0., 0., 1.)))
let transparentColor = E3DCOLOR(Color4(float4(0., 0., 0., 0.)))
let targetColor = E3DCOLOR(Color4(float4(1., 0., 0., 1.)))
let allyColor = E3DCOLOR(Color4(float4(0., 1., 0., 1.)))
let metrToFeet = 3.28084
let metrToThFeet = metrToFeet * 0.001
let kMetrToMile = 0.621371

def norm_ang(a : float) : float// [0..TWOPI]
  let na = a < 0. ? a + 2. * PI : a
  return na - 2. * PI * floor(na / (2. * PI))

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  useArea : float4 = float4(0., 0., 1., 1.)
  lineWidth : float = 2.
  isMetricUnits : bool = false

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.useArea = float4(0.13, 0., 0.87, 1.0)
  storage.lineWidth = props |> getFloat("lineWidth", 1.) * 2.
  storage.isMetricUnits = props |> getBool("isMetricUnits", false)

[export]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !get_radar_hud_mfd_radar_enabled()
    return

  let pos = rdata.pos + float2(data.useArea.x * rdata.size.x, data.useArea.y * rdata.size.y)
  let size = float2(rdata.size.x * (data.useArea.z - data.useArea.x), rdata.size.y * (data.useArea.w - data.useArea.y))
  ctx |> set_color(backgroundColor)
  let rb = pos + size
  let tc = float2(0., 0.)
  ctx |> render_rect(pos.x, pos.y, rb.x, rb.y, tc, tc, tc)

  let offset = draw_button_labels(ctx, data, pos, size)

  let rectPos = pos + float2(offset.x, padding)
  let rectSize = float2(size.x - offset.x - offset.y, size.y * 0.2)
  draw_rectangle_radar(ctx, data, rectPos, rectSize)

  draw_info(ctx, data, pos, size)
  let sectorPos = rectPos + float2(0., size.y * 0.35)
  let sectorSize = float2(size.x - offset.x - offset.y, size.y * 0.65 - float(data.fontSize))
  draw_round_radar(ctx, data, sectorPos, sectorSize)

def draw_targets_hei(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let distMax = get_radar_hud_distance_max()
  let maxHei = size.y / size.x * distMax * 1000.
  foreach_targets() <| $(var target)
    let e3dColor = E3DCOLOR(Color4(!target.isEnemy ? allyColor : targetColor))

    if target.targetType == int(RadarTargetType TYPE_TARGET)
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
        let spd <- to_array_move([[float2[2] pos; pos + float2(0., los)]])
        ctx |> render_line_aa(spd, false, data.lineWidth,  float2(0, 0), e3dColor)

        if target.ageRel > 0.25
          let triangle <- to_array_move([[float2[3] float2(pos.x, pos.y + size.y * 0.03);
              float2(pos.x + size.x * 0.015, pos.y - size.y * 0.03);
              float2(pos.x - size.x * 0.015, pos.y - size.y * 0.03)]])
          ctx |> render_poly(triangle, e3dColor)
          ctx |> render_line_aa(triangle, true, data.lineWidth, float2(0, 0), e3dColor)
        else
          ctx |> render_ellipse_aa(pos, float2(size.x * 0.01), 1., e3dColor, e3dColor)

        if target.isDetected || target.isTracked
          ctx |> render_ellipse_aa(pos, float2(size.x * 0.02), data.lineWidth, e3dColor, transparentColor)
          let cross <- to_array_move([[float2[2] pos - float2(size.x * 0.02); pos + float2(size.x * 0.02)]])
          ctx |> render_line_aa(cross, false, data.lineWidth,  float2(0, 0), e3dColor)
          let cross2 <- to_array_move([[float2[2] pos - float2(size.x * 0.02, -size.x * 0.02); pos + float2(size.x * 0.02, -size.x * 0.02)]])
          ctx |> render_line_aa(cross2, false, data.lineWidth,  float2(0, 0), e3dColor)

        ctx |> resetViewTm()
      else
        ctx |> render_ellipse_aa(pos, float2(size.x * 0.01), 1., e3dColor, e3dColor)

        if target.isDetected || target.isTracked
          ctx |> render_ellipse_aa(pos, float2(size.x * 0.02), data.lineWidth, e3dColor, transparentColor)

def draw_rectangle_radar(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let arrowPos = float2(pos.x + size.x * 0.02 + padding, pos.y + size.y * 0.83)
  let arrow <- to_array_move([[float2[3] arrowPos; float2(pos.x + 5., arrowPos.y - size.y * 0.04); float2(pos.x + 5., arrowPos.y + size.y * 0.04)]])
  ctx |> render_line_aa(arrow, true, data.lineWidth, float2(0, 0), textColor)

  let radarPos = float2(arrowPos.x, pos.y)
  let radarSize = float2(size.x - (arrowPos.x - pos.x), size.y)
  let rb = radarPos + radarSize
  ctx |> set_color(radarBackgroundColor)
  let tc = float2(0., 0.)
  ctx |> render_rect(radarPos.x, radarPos.y, rb.x, rb.y, tc, tc, tc)

  ctx |> set_viewport(radarPos.x, radarPos.y, rb.x, rb.y)

  var pitch = 0.0
  let hero = get_controlled_hero()
  if hero != null && !hero.isDelayed
    let fmw = hero |> as_fmw()
    if fmw != null
      pitch = -fmw.tangage * PI / 180.0

  let scanAngles = float2(pitch - get_radar_hud_scan_elevation_max(), pitch - get_radar_hud_scan_elevation_min())
  ctx |> render_sector_aa(arrowPos, float2(size.x) * get_radar_hud_target_distance(), scanAngles, 1., transparentColor, radarScanColor)

  let maxAngles = float2(pitch - get_radar_hud_elevation_max(), pitch - get_radar_hud_elevation_min())
  let sectorL1 <- to_array_move([[float2[2] arrowPos; arrowPos + float2(cos(maxAngles.x), sin(maxAngles.x)) * size.x]])
  ctx |> render_line_aa(sectorL1, false, data.lineWidth, float2(0., 0.), textColor)

  let sectorL2 <- to_array_move([[float2[2] arrowPos; arrowPos + float2(cos(maxAngles.y), sin(maxAngles.y)) * size.x]])
  ctx |> render_line_aa(sectorL2, false, data.lineWidth, float2(0., 0.), textColor)

  draw_targets_hei(ctx, data, arrowPos, radarSize)

  ctx |> restore_viewport()

  ctx |> set_color(textColor)
  ctx |> render_frame(radarPos.x, radarPos.y, rb.x, rb.y, data.lineWidth)

  ctx |> draw_line(radarPos.x + radarSize.x * 0.5, radarPos.y, radarPos.x + radarSize.x * 0.5, radarPos.y + radarSize.y, data.lineWidth)
  ctx |> draw_line(radarPos.x + radarSize.x * 0.95, radarPos.y, radarPos.x + radarSize.x * 0.95, radarPos.y + radarSize.y, data.lineWidth)
  ctx |> draw_line(radarPos.x + radarSize.x * 0.25, radarPos.y + radarSize.y * 0.92, radarPos.x + radarSize.x * 0.25, radarPos.y + radarSize.y, data.lineWidth)
  ctx |> draw_line(radarPos.x + radarSize.x * 0.125, radarPos.y + radarSize.y * 0.95, radarPos.x + radarSize.x * 0.125, radarPos.y + radarSize.y, data.lineWidth)
  ctx |> draw_line(radarPos.x + radarSize.x * 0.375, radarPos.y + radarSize.y * 0.95, radarPos.x + radarSize.x * 0.375, radarPos.y + radarSize.y, data.lineWidth)
  ctx |> draw_line(radarPos.x + radarSize.x * 0.75, radarPos.y + radarSize.y * 0.92, radarPos.x + radarSize.x * 0.75, radarPos.y + radarSize.y, data.lineWidth)

  ctx |> draw_line(radarPos.x, radarPos.y + radarSize.y * 0.165, radarPos.x + 5., radarPos.y + radarSize.y * 0.165, data.lineWidth)
  ctx |> draw_line(radarPos.x - 3., radarPos.y + radarSize.y * 0.33, radarPos.x + 5., radarPos.y + radarSize.y * 0.33, data.lineWidth)
  ctx |> draw_line(radarPos.x, radarPos.y + radarSize.y * 0.5, radarPos.x + 5., radarPos.y + radarSize.y * 0.5, data.lineWidth)
  ctx |> draw_line(radarPos.x - 3., radarPos.y + radarSize.y * 0.66, radarPos.x + 5., radarPos.y + radarSize.y * 0.66, data.lineWidth)

  ctx |> draw_line(radarPos.x + radarSize.x - 5., radarPos.y + radarSize.y * 0.165, radarPos.x + radarSize.x, radarPos.y + radarSize.y * 0.165, data.lineWidth)
  ctx |> draw_line(radarPos.x - 5. +  +radarSize.x, radarPos.y + radarSize.y * 0.33, radarPos.x + 3. + radarSize.x, radarPos.y + radarSize.y * 0.33, data.lineWidth)
  ctx |> draw_line(radarPos.x + radarSize.x - 5., radarPos.y + radarSize.y * 0.5, radarPos.x + radarSize.x, radarPos.y + radarSize.y * 0.5, data.lineWidth)
  ctx |> draw_line(radarPos.x - 5. + radarSize.x, radarPos.y + radarSize.y * 0.66, radarPos.x + 3. + radarSize.x, radarPos.y + radarSize.y * 0.66, data.lineWidth)
  ctx |> draw_line(radarPos.x + radarSize.x - 5., radarPos.y + radarSize.y * 0.83, radarPos.x + radarSize.x, radarPos.y + radarSize.y * 0.83, data.lineWidth)

def draw_horizontal_label(var ctx : GuiContext&; pos : float2; text : string)
  ctx |> goto_xy(pos.x, pos.y)
  ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_vertical_label(var ctx : GuiContext&; pos : float2; text : string; ht : float)
  ctx |> goto_xy(pos.x, pos.y)
  for c, i in text, range(0, length(text))
    ctx |> draw_char_u(uint16(c))
    ctx |> goto_xy(pos.x, pos.y + ht * float(i + 1))

def draw_button_labels(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 15)

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(15);
  ctx |> set_color(textColor)
  ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, textColor, 1)

  let box = get_str_bbox("E", 1, fctx)
  let emgyPos = pos + float2(3., 35.)
  draw_vertical_label(ctx, emgyPos, "EMGY", box.width.y + 1.)

  let initPos = pos + float2(3., 90.)
  draw_vertical_label(ctx, initPos, "INIT", box.width.y + 1.)

  let aaPos = pos + float2(6., 150.)
  draw_horizontal_label(ctx, aaPos, "A/A")
  ctx |> render_frame(aaPos.x - 3., aaPos.y - box.width.y - 3., aaPos.x + box.width.x * 3. + 3., aaPos.y + 3., 2.)

  let asPos = pos + float2(6., 165.)
  draw_horizontal_label(ctx, asPos, "A/S")

  let rcePos = pos + float2(6., 180.)
  draw_horizontal_label(ctx, rcePos, "RCE")

  let hresPos = pos + float2(3., 242.)
  draw_vertical_label(ctx, hresPos, "HRES", box.width.y + 1.)

  let cursPos = pos + float2(3., 298.)
  draw_vertical_label(ctx, cursPos, "CURS", box.width.y + 1.)

  let menuPos = pos + float2(3., 352.)
  draw_vertical_label(ctx, menuPos, "MENU", box.width.y + 1.)

  let savePos = pos + float2(35., size.y - 3.)
  draw_horizontal_label(ctx, savePos, "SAVE")

  let ximgPos = pos + float2(95., size.y - 3.)
  draw_horizontal_label(ctx, ximgPos, "XIMG")

  let frezPos = pos + float2(155., size.y - 3.)
  draw_horizontal_label(ctx, frezPos, "FREZ")

  let idPos = pos + float2(215., size.y - 3.)
  draw_horizontal_label(ctx, idPos, "ID")

  let corrPos = pos + float2(260., size.y - 3.)
  draw_horizontal_label(ctx, corrPos, "CORR")

  let grndPos = pos + float2(size.x - box.width.x - 3., 35.)
  draw_vertical_label(ctx, grndPos, "GRND", box.width.y + 1.)

  let gcsPos = pos + float2(size.x - box.width.x - 3., 135.)
  draw_vertical_label(ctx, gcsPos, "GCS", box.width.y + 1.)

  let alPos = pos + float2(size.x - box.width.x - 3., 195.)
  draw_vertical_label(ctx, alPos, "A/L", box.width.y + 2.)

  let snsrPos = pos + float2(size.x - box.width.x - 3., 245.)
  draw_vertical_label(ctx, snsrPos, "SNSR", box.width.y + 1.)

  let bscpPos = pos + float2(size.x - box.width.x - 3., 355.)
  draw_vertical_label(ctx, bscpPos, "BSCP", box.width.y + 1.)

  let airPos = pos + float2(size.x - box.width.x * 2. - 6., 35.)
  draw_vertical_label(ctx, airPos, "AIR", box.width.y + 1.)
  ctx |> render_frame(airPos.x - 3., airPos.y - box.width.y - 3., airPos.x + box.width.x + 3., airPos.y + box.width.y * 2. + 8., 2.)

  let exiPos = pos + float2(size.x - box.width.x * 2. - 6., 135.)
  draw_vertical_label(ctx, exiPos, "EXI", box.width.y + 1.)

  let exiPos2 = pos + float2(size.x - box.width.x * 2. - 6., 195.)
  draw_vertical_label(ctx, exiPos2, "EXI", box.width.y + 1.)

  let exiPos3 = pos + float2(size.x - box.width.x * 2. - 6., 245.)
  draw_vertical_label(ctx, exiPos3, "EXI", box.width.y + 1.)

  let ppiPos = pos + float2(size.x - box.width.x * 2. - 6., 355.)
  draw_vertical_label(ctx, ppiPos, "PPI", box.width.y + 1.)

  return float2(box.width.x + 3., box.width.y * 2. + 6.)

def draw_info(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let rdrlpPos = pos + float2(70., size.y * 0.25)
  draw_horizontal_label(ctx, rdrlpPos, "RDRLP")

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(20);
  ctx |> set_color(textColor)
  ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, textColor, 1)

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
  foreach_targets() <| $(var target)
    if target.targetType == int(RadarTargetType TYPE_TARGET)
      if target.isDetected || target.isTracked
        hasSelectedTarget = true
        targetAzimuth = get_radar_hud_azimuth_min() + max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) * target.azimuthRel
        distToTargetKm = get_radar_hud_distance_max() * target.distanceRel
        let targetElev = get_radar_hud_elevation_min() * (1.0 - target.elevationRel) + get_radar_hud_elevation_max() * target.elevationRel
        targetAltKm = hero.pos.y * 0.001 + distToTargetKm * sin(targetElev)
        taretSpeedSq = target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed + target.losVerSpeed * target.losVerSpeed

  if hasSelectedTarget
    let rPos = pos + float2(60., size.y * 0.3)
    let distMul = data.isMetricUnits ? 1. : kMetrToMile
    draw_horizontal_label(ctx, rPos, "R {roundi(distToTargetKm * distMul)}")

    let altPos = pos + float2(130., size.y * 0.25)
    let altMul = data.isMetricUnits ? 1. : metrToFeet
    let alt = "A{fmt(":.1f", targetAltKm * altMul)}"
    ctx |> goto_xy(altPos.x, altPos.y)
    ctx |> draw_str_scaled(1.0, alt, alt |> length())

    let machPos = pos + float2(130., size.y * 0.3)
    let machVal = sqrt(taretSpeedSq) / atmosphere_sonicSpeed(targetAltKm * 0.001)
    let mach = "M{fmt(":.2f", machVal)}"
    ctx |> goto_xy(machPos.x, machPos.y)
    ctx |> draw_str_scaled(1.0, mach, mach |> length())

    let tgtPos = pos + float2(size.x * 0.5 + 30., size.y * 0.25)
    let azimuthDegVal = norm_ang(atan2(hero.unitTm[0].x, hero.unitTm[0].z) + targetAzimuth) * 180.0 / PI
    let azimuth = "TGT {fmt(": .0f", azimuthDegVal)}"
    ctx |> set_font_ht(15);
    ctx |> goto_xy(tgtPos.x, tgtPos.y)
    ctx |> draw_str_scaled(1.0, azimuth, azimuth |> length())

def foreach_targets(blk : block<(target : RadarTarget const const#) : void>)
  get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
    for t in targets
      invoke(blk, t)

def draw_targets(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let radius = size
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 12)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(12);
  ctx |> set_color(textColor)
  ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, textColor, 1)
  foreach_targets() <| $(var target)
    let e3dColor = E3DCOLOR(Color4(!target.isEnemy ? allyColor : targetColor))

    if target.targetType == int(RadarTargetType TYPE_TARGET)
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
        let spd <- to_array_move([[float2[2] linePos; linePos + float2(0., los)]])
        ctx |> render_line_aa(spd, false, data.lineWidth,  float2(0, 0), e3dColor)

        if target.ageRel > 0.25
          let triangle <- to_array_move([[float2[3] float2(pos.x, pos.y + size.y * 0.015);
              float2(pos.x + size.x * 0.015, pos.y - size.y * 0.015);
              float2(pos.x - size.x * 0.015, pos.y - size.y * 0.015)]])
          ctx |> render_poly(triangle, e3dColor)
          ctx |> render_line_aa(triangle, true, data.lineWidth, float2(0, 0), e3dColor)
        else
          ctx |> render_ellipse_aa(pos, float2(size.y * 0.02), 1., e3dColor, e3dColor)

        if target.isDetected || target.isTracked
          ctx |> render_ellipse_aa(pos, float2(size.y * 0.03), data.lineWidth, e3dColor, transparentColor)
          let cross <- to_array_move([[float2[2] pos - size * 0.03; pos + size * 0.03]])
          ctx |> render_line_aa(cross, false, data.lineWidth,  float2(0, 0), e3dColor)
          let cross2 <- to_array_move([[float2[2] pos - float2(size.x * 0.03, -size.y * 0.03); pos + float2(size.x * 0.03, -size.y * 0.03)]])
          ctx |> render_line_aa(cross2, false, data.lineWidth,  float2(0, 0), e3dColor)

        let textHei = "{fmt(":d", roundi(target.height * metrToThFeet))}"
        let strBox = get_str_bbox(textHei, textHei |> length(), fctx)
        ctx |> set_color(textColor)
        ctx |> goto_xy(pos.x - strBox.width.x * 0.5, pos.y - size.y * 0.035)
        ctx |> draw_str_scaled(1., textHei, textHei |> length())

        ctx |> resetViewTm()
      else
        ctx |> render_ellipse_aa(pos, float2(size.y * 0.02), 1., e3dColor, e3dColor)

        if target.isDetected || target.isTracked
          ctx |> render_ellipse_aa(pos, float2(size.y * 0.03), data.lineWidth, e3dColor, transparentColor)

        let textHei = "{fmt(":d", roundi(target.height * metrToThFeet))}"
        let strBox = get_str_bbox(textHei, textHei |> length(), fctx)
        ctx |> goto_xy(pos.x - strBox.width.x * 0.5, pos.y + size.y * 0.035 + strBox.width.y)
        ctx |> draw_str_scaled(1., textHei, textHei |> length())

def draw_compass(var ctx : GuiContext&; data : CanvasParams&; origin : float2; radius : float; compass : float)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 15)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(15);
  ctx |> set_color(textColor)
  for i in range(-3, 4)
    let markVal = (int(compass) / 10) * 10 + i * 10
    let diff = (compass - float(markVal)) * PI / 180.
    let markPos1 = origin + float2(-sin(diff), -cos(diff)) * radius
    let markPos2 = origin + float2(-sin(diff), -cos(diff)) * radius * 1.01
    let markCoord <- to_array_move([[float2[2] markPos1;
      markPos2]])
    ctx |> render_line_aa(markCoord, false, data.lineWidth, float2(0., 0.), textColor)
    if markVal % 20 == 0
      let text = "{markVal / 10}"
      let markStrBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(markPos2.x - markStrBox.width.x * 0.5, markPos2.y - ctx |> hdpx(5.))
      ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_round_radar(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let origin = pos + float2(size.x * 0.5, size.y)
  let radius = float2(size.y)

  ctx |> set_viewport(pos.x, pos.y - size.y * 0.12, pos.x + size.x, pos.y + size.y)

  let tc = float2(0., 0.)
  ctx |> set_color(radarBackgroundColor)
  ctx |> render_rect(pos.x, pos.y + size.y * 0.5, pos.x + size.x, pos.y + size.y, tc, tc, tc)
  let anglesExternal = float2(get_radar_hud_azimuth_min() - PI * 0.5, get_radar_hud_azimuth_max() - PI * 0.5)
  ctx |> render_sector_aa(origin, radius, anglesExternal, 1., transparentColor, radarBackgroundColor)

  let scanAngles = float2(get_radar_hud_scan_azimuth_min() - PI * 0.5, get_radar_hud_scan_azimuth_max() - PI * 0.5)
  ctx |> render_sector_aa(origin, radius * get_radar_hud_target_distance(), scanAngles, 1., radarScanColor, radarScanColor)

  draw_targets(ctx, data, origin, size)

  let cueAzimuth = get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width(), 0.)
  let cuePos = origin + float2(sin(cueAzimuth), -cos(cueAzimuth)) * get_radar_hud_cue_distance() * radius
  let cueR = get_radar_hud_cue_azimuth_half_width_rel() * size.y * 0.5
  ctx |> render_ellipse_aa(cuePos, float2(cueR), data.lineWidth, textColor, transparentColor)
  let l1 <- to_array_move([[float2[2] cuePos - float2(cos(cueAzimuth), sin(cueAzimuth)) * cueR; cuePos - float2(cos(cueAzimuth), sin(cueAzimuth)) * (cueR + 10.)]])
  ctx |> render_line_aa(l1, false, data.lineWidth, float2(0., 0.), textColor)
  let l2 <- to_array_move([[float2[2] cuePos + float2(cos(cueAzimuth), sin(cueAzimuth)) * cueR; cuePos + float2(cos(cueAzimuth), sin(cueAzimuth)) * (cueR + 10.)]])
  ctx |> render_line_aa(l2, false, data.lineWidth, float2(0., 0.), textColor)

  ctx |> render_sector_aa(origin, radius, anglesExternal, data.lineWidth, textColor, transparentColor)
  let line1 <- to_array_move([[float2[2] origin; origin - float2(cos(anglesExternal.x), sin(-anglesExternal.x)) * size.y]])
  ctx |> render_line_aa(line1, false, data.lineWidth, float2(0., 0.), textColor)
  let line2 <- to_array_move([[float2[2] origin; origin - float2(cos(anglesExternal.y), sin(-anglesExternal.y)) * size.y]])
  ctx |> render_line_aa(line2, false, data.lineWidth, float2(0., 0.), textColor)

  let cline <- to_array_move([[float2[2] origin; origin - float2(0., size.y)]])
  ctx |> render_line_aa(cline, false, data.lineWidth, float2(0., 0.), textColor)

  ctx |> render_sector_aa(origin, radius * 0.5, anglesExternal, data.lineWidth, textColor, transparentColor)
  ctx |> render_sector_aa(origin, radius * 0.95, anglesExternal, data.lineWidth, textColor, transparentColor)
  ctx |> render_sector_aa(origin, radius * 1.04, anglesExternal, data.lineWidth, textColor, transparentColor)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 15)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(15);
  ctx |> set_color(textColor)

  let distMul = data.isMetricUnits ? 1. : kMetrToMile
  let halfDist = "{fmt(":d", roundi(get_radar_hud_distance_max() * distMul * 0.5))}"
  let halfDistPos = origin + float2(cos(anglesExternal.y), sin(anglesExternal.y)) * size.y * 0.5
  let strBox = get_str_bbox(halfDist, halfDist |> length(), fctx)
  ctx |> goto_xy(halfDistPos.x, halfDistPos.y + strBox.width.y)
  ctx |> draw_str_scaled(1., halfDist, halfDist |> length())

  let halfDistPos2 = origin + float2(cos(anglesExternal.x), sin(anglesExternal.x)) * size.y * 0.5
  ctx |> goto_xy(halfDistPos2.x - strBox.width.x * 0.5, halfDistPos2.y + strBox.width.y * 1.5)
  ctx |> draw_str_scaled(1., halfDist, halfDist |> length())

  let dist = "{fmt(":d", roundi(get_radar_hud_distance_max() * distMul))}"
  let strBoxDist = get_str_bbox(dist, dist |> length(), fctx)
  ctx |> goto_xy(pos.x + 40., pos.y - 10.)
  ctx |> draw_str_scaled(1., dist, dist |> length())
  ctx |> render_frame(pos.x + 27., pos.y - 13. - strBoxDist.width.y, pos.x + 43. + strBoxDist.width.x, pos.y - 7., data.lineWidth)

  var compass = 0.
  let hero = get_controlled_hero()
  if hero != null && !hero.isDelayed
    compass = (norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * 180. / PI
  draw_compass(ctx, data, origin, size.y * 1.04, compass)

  ctx |> draw_line(origin.x, origin.y - radius.y * 1.04, origin.x, origin.y - radius.y * 1.01, data.lineWidth)
  ctx |> draw_line(origin.x, origin.y - radius.y * 1.04, origin.x - 4., origin.y - radius.y * 1.02, data.lineWidth)
  ctx |> draw_line(origin.x, origin.y - radius.y * 1.04, origin.x + 4., origin.y - radius.y * 1.02, data.lineWidth)

  ctx |> restore_viewport()
