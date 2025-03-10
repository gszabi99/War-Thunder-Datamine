require darg
require DagorStdGuiRender
require DagorMath
require RadarHud
require %rGui.utils.canvas_common
require strings
require math
require Unit
require HeroManager
require Plane
require FlightModelWrap
require %rGui.utils.constants_common
require DagorSystem

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))
let allyColor = E3DCOLOR(0xFF0000FF)


def rad_to_deg(rad : float)
  return rad * 180. / PI

def deg_to_rad(rad : float)
  return rad * PI / 180.

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  lineWidth : float = 2.
  isElevationMode : bool = false

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.lineWidth = props |> getFloat("lineWidth", 1.) * 2.
  storage.isElevationMode = props |> getBool("isElevationMode", false)

[export, unused_argument(rstate)]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !get_radar_hud_mfd_radar_enabled() && !data.isElevationMode
    return
  let offset = draw_labels(ctx, rdata, data)
  let radarPos = rdata.pos + float2(offset.x, offset.y)
  let radarSize = rdata.size - float2(offset.x + offset.z, offset.y + offset.w)
  draw_radar(ctx, radarPos, radarSize, data)

def draw_labels(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);
  ctx |> set_color(data.color)

  let irst = get_radar_hud_is_irst()
  let box = get_str_bbox("Ш", 1, fctx)

  if !irst
    let sklPos = rdata.pos + float2(5., 30.)
    draw_horizontal_label(ctx, sklPos, "Ш")
    draw_horizontal_label(ctx, sklPos + float2(0., box.width.y + 1.), "К")
    draw_horizontal_label(ctx, sklPos + float2(0., 2. * box.width.y + 2.), "Л")

    let adPos = rdata.pos + float2(5., 110.)
    draw_horizontal_label(ctx, adPos, "А")
    draw_horizontal_label(ctx, adPos + float2(0., box.width.y + 1.), "/")
    let ch = data.isElevationMode ? "ε" : get_radar_hud_velocity_search() ? "V" : "Д"
    draw_horizontal_label(ctx, adPos + float2(0., 2. * box.width.y + 2.), ch)
    ctx |> render_frame(adPos.x - 3., adPos.y - box.width.y - 3., adPos.x + box.width.x + 3., adPos.y + 2. * box.width.y + 6., data.lineWidth)

    let pdPos = rdata.pos + float2(5., 200.)
    draw_horizontal_label(ctx, pdPos, "П")
    draw_horizontal_label(ctx, pdPos + float2(0., box.width.y + 1.), "Д")
    ctx |> render_frame(pdPos.x - 3., pdPos.y - box.width.y - 13., pdPos.x + box.width.x + 3., pdPos.y + box.width.y + 16., data.lineWidth)

    let nameId = get_radar_hud_mode_name_id()
    let modeName = nameId >= 0 && nameId < radarModeNames |> length() ? radarModeNames[nameId] : ""
    let ppsPos = rdata.pos + float2(5., 275.)
    if find(modeName, "HDN") >= 0
      draw_horizontal_label(ctx, ppsPos, "П")
      draw_horizontal_label(ctx, ppsPos + float2(0., box.width.y + 1.), "П")
      draw_horizontal_label(ctx, ppsPos + float2(0., 2. * box.width.y + 2.), "С")
    else
      draw_horizontal_label(ctx, ppsPos, "А")
      draw_horizontal_label(ctx, ppsPos + float2(0., box.width.y + 1.), "В")
      draw_horizontal_label(ctx, ppsPos + float2(0., 2. * box.width.y + 2.), "Т")
    ctx |> render_frame(ppsPos.x - 3., ppsPos.y - box.width.y - 3., ppsPos.x + box.width.x + 3., ppsPos.y + 2. * box.width.y + 6., data.lineWidth)

    let nrcPos = rdata.pos + float2(5., 350.)
    draw_horizontal_label(ctx, nrcPos, "Н")
    draw_horizontal_label(ctx, nrcPos + float2(0., box.width.y + 1.), "Ц")
    draw_horizontal_label(ctx, nrcPos + float2(0., 2. * box.width.y + 3.), "Р")
    draw_horizontal_label(ctx, nrcPos + float2(0., 3. * box.width.y + 4.), "1")

    let varPos = rdata.pos + float2(5., 430.)
    draw_horizontal_label(ctx, varPos, "В")
    draw_horizontal_label(ctx, varPos + float2(0., box.width.y + 1.), "А")
    draw_horizontal_label(ctx, varPos + float2(0., 2. * box.width.y + 2.), "Р")
    draw_horizontal_label(ctx, varPos + float2(0., 3. * box.width.y + 4.), "1")
    ctx |> render_frame(varPos.x - 3., varPos.y - box.width.y - 3., varPos.x + box.width.x + 3., varPos.y + 3. * box.width.y + 8., data.lineWidth)
  else
    let chp = rdata.pos + float2(5., 290.)
    draw_horizontal_label(ctx, chp, "^")
    draw_horizontal_label(ctx, chp + float2(0., box.width.y + 1.), "Ч")

    let ch = rdata.pos + float2(5., 380.)
    draw_horizontal_label(ctx, ch, "Ч")
    draw_horizontal_label(ctx, ch + float2(0., box.width.y + 1.), "◣")

    let rlcPos = rdata.pos + float2(5., 440.)
    draw_horizontal_label(ctx, rlcPos, "Р")
    draw_horizontal_label(ctx, rlcPos + float2(0., box.width.y + 1.), "Л")
    draw_horizontal_label(ctx, rlcPos + float2(0., 2. * box.width.y + 2.), "Ц")

  let olsPos = rdata.pos + float2(70., 500.)
  draw_horizontal_label(ctx, olsPos, irst ? "РЛВ" : "ОЛС")
  let cvsPos = rdata.pos + float2(150., 500.)
  draw_horizontal_label(ctx, cvsPos, "ЦВС")
  ctx |> render_frame(cvsPos.x - 5., cvsPos.y - box.width.y - 3., cvsPos.x + 3. * box.width.x + 8., cvsPos.y + 5., data.lineWidth)
  let lPos = rdata.pos + float2(250., 500.)
  draw_horizontal_label(ctx, lPos, "<")
  let ePos = rdata.pos + float2(330., 500.)
  draw_horizontal_label(ctx, ePos, irst ? "^" : "=")
  let rPos = rdata.pos + float2(420., 500.)
  draw_horizontal_label(ctx, rPos, ">")

  if irst
    let isPos = rdata.pos + float2(rdata.size.x - box.width.x - 5., 100.)
    draw_horizontal_label(ctx, isPos, "И")
    draw_horizontal_label(ctx, isPos + float2(0., box.width.y + 1.), "С")
  else
    let allPos = rdata.pos + float2(rdata.size.x - box.width.x - 5., 90.)
    draw_horizontal_label(ctx, allPos, "В")
    draw_horizontal_label(ctx, allPos + float2(0., box.width.y + 1.), "С")
    draw_horizontal_label(ctx, allPos + float2(0., 2. * box.width.y + 2.), "Е")
    ctx |> render_frame(allPos.x - 3., allPos.y - box.width.y - 3., allPos.x + box.width.x + 3., allPos.y + 2. * box.width.y + 6., data.lineWidth)

    let threePos = rdata.pos + float2(rdata.size.x - box.width.x - 5., 170.)
    draw_vertical_label(ctx, threePos, "300", box.width.y + 1.)
    ctx |> render_frame(threePos.x - 3., threePos.y - box.width.y - 3., threePos.x + box.width.x + 3., threePos.y + 2. * box.width.y + 6., data.lineWidth)

  let czrPos = rdata.pos + float2(rdata.size.x - box.width.x - 5., 255.)
  draw_horizontal_label(ctx, czrPos, "Ц")
  draw_horizontal_label(ctx, czrPos + float2(0., box.width.y + 1.), "З")
  draw_horizontal_label(ctx, czrPos + float2(0., 2. * box.width.y + 2.), "Р")
  ctx |> render_frame(czrPos.x - 3., czrPos.y - box.width.y - 3., czrPos.x + box.width.x + 3., czrPos.y + 2. * box.width.y + 6., data.lineWidth)

  let mhPos = rdata.pos + float2(rdata.size.x - box.width.x - 5., 345.)
  draw_horizontal_label(ctx, mhPos, "^")
  draw_horizontal_label(ctx, mhPos + float2(0., box.width.y + 1.), "H")

  let lhPos = rdata.pos + float2(rdata.size.x - box.width.x - 5., 430.)
  draw_horizontal_label(ctx, lhPos, "H")
  draw_horizontal_label(ctx, lhPos + float2(0., box.width.y + 1.), "◣")

  let pilPos = rdata.pos + float2(70., box.width.y + 2.)
  draw_horizontal_label(ctx, pilPos, "ПИЛ")
  let toPos = rdata.pos + float2(160., box.width.y + 2.)
  draw_horizontal_label(ctx, toPos, "ТО")
  let rapPos = rdata.pos + float2(240., box.width.y + 2.)
  draw_horizontal_label(ctx, rapPos, "РЭП")
  let kissPos = rdata.pos + float2(320., box.width.y + 2.)
  draw_horizontal_label(ctx, kissPos, "КИСС")
  let opsPos = rdata.pos + float2(405., box.width.y + 2.)
  draw_horizontal_label(ctx, opsPos, "ОПС")
  ctx |> render_frame(opsPos.x - 10., opsPos.y - box.width.y - 3., opsPos.x + 3. * box.width.x + 13., opsPos.y + 3., data.lineWidth)

  return float4(box.width.x + 5., box.width.y + 2., box.width.x + 5., 12. + box.width.y)

def foreach_targets(blk : block<(target : RadarTarget const const#) : void>)
  get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
    for t in targets
      invoke(blk, t)

def draw_cue(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; irst_azimuth : float2)
  if !get_radar_hud_cue_visible()
    return
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let cueAzimuthHwr = get_radar_hud_cue_azimuth_half_width_rel()
  let cueDistWidthRel =  get_radar_hud_cue_dist_width_rel()
  let cuePos = pos + float2((get_radar_hud_cue_azimuth() * (get_radar_hud_target_azimuth_width() / azimuthRange - cueAzimuthHwr) + 0.5) * size.x,
          (1. - (0.5 * cueDistWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - cueDistWidthRel))) * size.y)
  if !get_radar_hud_is_irst()
    ctx |> render_frame(cuePos.x - cueAzimuthHwr * size.x * 0.5, cuePos.y - cueDistWidthRel * size.y * 0.5,
      cuePos.x + cueAzimuthHwr * size.x * 0.5, cuePos.y + cueDistWidthRel * size.y * 0.5, data.lineWidth)
  else
    ctx |> render_frame(pos.x + irst_azimuth.x * size.x, pos.y,
      pos.x + irst_azimuth.y * size.x, pos.y + size.y, data.lineWidth)

def draw_scope(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  let offset = 5.
  let markW = 8.
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 15)
  ctx |> set_font_ht(15)

  let isIrst = get_radar_hud_is_irst()
  let isElevation = isIrst || data.isElevationMode
  let isSpeed = get_radar_hud_velocity_search()

  ctx |> set_color(data.color)
  if !isElevation && !get_radar_hud_velocity_search()
    ctx |> draw_line(pos.x - offset, pos.y, pos.x - offset, pos.y + size.y, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y, pos.x - offset, pos.y, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y * 0.2, pos.x - offset, pos.y + size.y * 0.2, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y * 0.4, pos.x - offset, pos.y + size.y * 0.4, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y * 0.6, pos.x - offset, pos.y + size.y * 0.6, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y * 0.8, pos.x - offset, pos.y + size.y * 0.8, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y, pos.x - offset, pos.y + size.y, data.lineWidth)
  elif isSpeed
    ctx |> draw_line(pos.x - offset, pos.y, pos.x - offset, pos.y + size.y, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y, pos.x - offset, pos.y, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y * 0.182, pos.x - offset, pos.y + size.y * 0.182, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y * 0.364, pos.x - offset, pos.y + size.y * 0.364, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y * 0.545, pos.x - offset, pos.y + size.y * 0.545, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y * 0.727, pos.x - offset, pos.y + size.y * 0.727, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y * 0.91, pos.x - offset, pos.y + size.y * 0.91, data.lineWidth)
    ctx |> draw_line(pos.x - offset - markW, pos.y + size.y, pos.x - offset, pos.y + size.y, data.lineWidth)

  ctx |> draw_line(pos.x + size.x + offset, pos.y, pos.x + size.x + offset, pos.y + size.y, data.lineWidth)
  ctx |> draw_line(pos.x + size.x + offset, pos.y, pos.x + size.x + offset + markW, pos.y, data.lineWidth)
  ctx |> draw_line(pos.x + size.x + offset, pos.y + size.y * 0.125, pos.x + size.x + offset + markW, pos.y + size.y * 0.125, data.lineWidth)
  ctx |> draw_line(pos.x + size.x + offset, pos.y + size.y * 0.25, pos.x + size.x + offset + markW, pos.y + size.y * 0.25, data.lineWidth)
  ctx |> draw_line(pos.x + size.x + offset, pos.y + size.y * 0.375, pos.x + size.x + offset + markW, pos.y + size.y * 0.375, data.lineWidth)
  ctx |> draw_line(pos.x + size.x + offset, pos.y + size.y * 0.5, pos.x + size.x + offset + markW, pos.y + size.y * 0.5, data.lineWidth)
  ctx |> draw_line(pos.x + size.x + offset, pos.y + size.y * 0.625, pos.x + size.x + offset + markW, pos.y + size.y * 0.625, data.lineWidth)
  ctx |> draw_line(pos.x + size.x + offset, pos.y + size.y * 0.75, pos.x + size.x + offset + markW, pos.y + size.y * 0.75, data.lineWidth)
  ctx |> draw_line(pos.x + size.x + offset, pos.y + size.y * 0.875, pos.x + size.x + offset + markW, pos.y + size.y * 0.875, data.lineWidth)
  ctx |> draw_line(pos.x + size.x + offset, pos.y + size.y, pos.x + size.x + offset + markW, pos.y + size.y, data.lineWidth)

  ctx |> draw_line(pos.x, pos.y + size.y + offset, pos.x + size.x, pos.y + size.y + offset, data.lineWidth)
  ctx |> draw_line(pos.x, pos.y + size.y + offset, pos.x, pos.y + size.y + offset + markW, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.125, pos.y + size.y + offset, pos.x + size.x * 0.125, pos.y + size.y + offset + markW, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.25, pos.y + size.y + offset, pos.x + size.x * 0.25, pos.y + size.y + offset + markW, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.375, pos.y + size.y + offset, pos.x + size.x * 0.375, pos.y + size.y + offset + markW, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.5, pos.y + size.y + offset, pos.x + size.x * 0.5, pos.y + size.y + offset + markW, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.625, pos.y + size.y + offset, pos.x + size.x * 0.625, pos.y + size.y + offset + markW, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.75, pos.y + size.y + offset, pos.x + size.x * 0.75, pos.y + size.y + offset + markW, data.lineWidth)
  ctx |> draw_line(pos.x + size.x * 0.875, pos.y + size.y + offset, pos.x + size.x * 0.875, pos.y + size.y + offset + markW, data.lineWidth)
  ctx |> draw_line(pos.x + size.x, pos.y + size.y + offset, pos.x + size.x, pos.y + size.y + offset + markW, data.lineWidth)

  if !isElevation && !isSpeed
    let maxDist = get_radar_hud_distance_max()
    for i in range(0, 6)
      let dist = "{float(i) * maxDist * 0.2}"
      let distBox = get_str_bbox(dist, dist |> length(), fctx)
      ctx |> goto_xy(pos.x - offset - distBox.width.x - markW, pos.y + size.y * 0.2 * (5. - float(i)) + distBox.width.y * 0.5)
      ctx |> draw_str_scaled(1., dist, dist |> length())
  elif isSpeed
    let dist = "5"
    let distBox = get_str_bbox(dist, dist |> length(), fctx)
    ctx |> goto_xy(pos.x - offset - distBox.width.x - markW - 2., pos.y + distBox.width.y * 0.5)
    ctx |> draw_str_scaled(1., dist, dist |> length())

    ctx |> goto_xy(pos.x - offset - distBox.width.x - markW - 2., pos.y + size.y * 0.91 + distBox.width.y * 0.5)
    ctx |> draw_str_scaled(1., "0", 1)

    let distMin = "-0.5"
    let distMinBox = get_str_bbox(distMin, distMin |> length(), fctx)
    ctx |> goto_xy(pos.x - offset - distMinBox.width.x - markW - 2., pos.y + size.y + distMinBox.width.y * 0.5)
    ctx |> draw_str_scaled(1., distMin, distMin |> length())

  let maxAz = "{roundi(rad_to_deg(get_radar_hud_azimuth_max()))}"
  let maxAzBox = get_str_bbox(maxAz, maxAz |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x - maxAzBox.width.x * 0.5, pos.y + size.y + markW + offset + maxAzBox.width.y)
  ctx |> draw_str_scaled(1., maxAz, maxAz |> length())

  let minAz = "{roundi(rad_to_deg(get_radar_hud_azimuth_min()))}"
  let minAzBox = get_str_bbox(minAz, minAz |> length(), fctx)
  ctx |> goto_xy(pos.x - minAzBox.width.x * 0.5, pos.y + size.y + markW + offset + minAzBox.width.y)
  ctx |> draw_str_scaled(1., minAz, minAz |> length())

  if !isIrst
    let maxEl = "{roundi(rad_to_deg(get_radar_hud_elevation_max()))}"
    let maxElBox = get_str_bbox(maxEl, maxEl |> length(), fctx)
    ctx |> goto_xy(pos.x + size.x + offset + markW + 3., pos.y + maxElBox.width.y * 0.5)
    ctx |> draw_str_scaled(1., maxEl, maxEl |> length())

    let minEl = "{roundi(rad_to_deg(get_radar_hud_elevation_min()))}"
    let minElBox = get_str_bbox(minEl, minEl |> length(), fctx)
    ctx |> goto_xy(pos.x + size.x + offset + markW, pos.y + size.y)
    ctx |> draw_str_scaled(1., minEl, minEl |> length())

  let zeroVal = "0"
  let zeroValBox = get_str_bbox(zeroVal, zeroVal |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x + offset + markW + 2., pos.y + size.y * 0.5 + zeroValBox.width.y * 0.5)
  ctx |> draw_str_scaled(1., zeroVal, zeroVal |> length())

  ctx |> goto_xy(pos.x + size.x * 0.5 - zeroValBox.width.x * 0.5, pos.y + size.y + markW + offset + zeroValBox.width.y + 2.)
  ctx |> draw_str_scaled(1., zeroVal, zeroVal |> length())

  var dontScale = false
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  if get_radar_hud_scan_azimuth_max() > get_radar_hud_scan_azimuth_min()
    let azimuthRangeInv = azimuthRange != 0. ? 1. / azimuthRange : 1.
    let scanAzimuthMinRelW = max(0., 0.5 + get_radar_hud_scan_azimuth_min() * azimuthRangeInv)
    let scanAzimuthMaxRelW = min(1., 0.5 + get_radar_hud_scan_azimuth_max() * azimuthRangeInv)
    ctx |> draw_line(pos.x + scanAzimuthMinRelW * size.x, pos.y + size.y + offset + markW,
      pos.x + scanAzimuthMaxRelW * size.x, pos.y + size.y + offset + markW, data.lineWidth)
  else
    dontScale = true

  let elevRange = max(0., get_radar_hud_elevation_max() - get_radar_hud_elevation_min())
  let elevRangeInv = elevRange != 0. ? 1. / elevRange : 1.
  if get_radar_hud_scan_elevation_max() > get_radar_hud_scan_elevation_min()
    let scanElevMinRelW = 0.5 - get_radar_hud_scan_elevation_min() * elevRangeInv
    let scanElevMaxRelW = 0.5 - get_radar_hud_scan_elevation_max() * elevRangeInv
    ctx |> draw_line(pos.x + size.x + offset + markW, pos.y + scanElevMaxRelW * size.y,
    pos.x + size.x + offset + markW, pos.y + scanElevMinRelW * size.y, data.lineWidth)
    let hero = get_controlled_hero()
    if !isSpeed && hero != null && !hero.isDelayed
      let fmw = hero |> as_fmw()
      let tangage = deg_to_rad(fmw.tangage)
      let hmin = (hero.pos.y * 0.001 + get_radar_hud_distance_max() * sin(get_radar_hud_scan_elevation_min() + tangage))
      let hmax = (hero.pos.y * 0.001 + get_radar_hud_distance_max() * sin(get_radar_hud_scan_elevation_max() + tangage))

      let maxH = "{roundi(hmax)}"
      let maxHBox = get_str_bbox(maxH, maxH |> length(), fctx)
      ctx |> goto_xy(pos.x + size.x + offset + markW + 2., pos.y + scanElevMaxRelW * size.y + maxHBox.width.y * 0.5)
      ctx |> draw_str_scaled(1., maxH, maxH |> length())

      let minH = "{roundi(hmin)}"
      let minHBox = get_str_bbox(minH, minH |> length(), fctx)
      ctx |> goto_xy(pos.x + size.x + offset + markW + 2., pos.y + scanElevMinRelW * size.y + minHBox.width.y * 0.5)
      ctx |> draw_str_scaled(1., minH, minH |> length())
  else
    dontScale = true


  let markSize = 5.
  var selectedCnt = 0
  let minAzimuth = isElevation && azimuthRange > 0. ? (get_radar_hud_scan_azimuth_min() - get_radar_hud_azimuth_min()) / azimuthRange : 0.
  let minElev = isElevation && elevRange > 0. ? (get_radar_hud_scan_elevation_min() - get_radar_hud_elevation_min()) / elevRange : 0.
  let scanAzimuthRange = max(0., get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min())
  let scanAzimuthRangMul = isElevation && azimuthRange > 0. && scanAzimuthRange > 0. ? scanAzimuthRange / azimuthRange : 1.
  let scanElevationRange = max(0., get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min())
  let scanElevationRangMul = isElevation && elevRange > 0. && scanElevationRange > 0. ? scanElevationRange / elevRange : 1.
  foreach_targets <| $(var target)
    if target.targetType == int(RadarTargetType TYPE_TARGET)
      let angleRel = dontScale ? target.azimuthRel : ((target.azimuthRel - minAzimuth) / scanAzimuthRangMul)
      if angleRel < 0. || angleRel > 1.
        return
      var distanceRel = 0.9
      if target.distanceRel >= 0.
        distanceRel = target.distanceRel

      let elevRel = max(0., min(1., dontScale ? target.elevationRel : ((target.elevationRel - minElev) / scanElevationRangMul)))

      let p = float2(pos.x + angleRel * size.x, pos.y + (1. - (isElevation ? elevRel : distanceRel)) * size.y)
      let color = target.isEnemy ? data.color : allyColor
      ctx |> set_color(color)
      if (target.isSelected || target.isAttacked) && !isIrst
        if !target.isTracked || target.isAttacked
          let l1 <- to_array_move([[float2[2]
            p - float2(markSize);
            p + float2(markSize)
            ]])
          ctx |> render_line_aa(l1, false, data.lineWidth, float2(0, 0), color)
          let l2 <- to_array_move([[float2[2]
            p + float2(-markSize, markSize);
            p + float2(markSize, -markSize)
            ]])
          ctx |> render_line_aa(l2, false, data.lineWidth, float2(0, 0), color)

        let id = "{int(target.id)}"
        let idBox = get_str_bbox(id, id |> length(), fctx)
        ctx |> goto_xy(p.x - markSize * 2. - idBox.width.x, p.y + idBox.width.y * 0.5)
        ctx |> draw_str_scaled(1., id, id |> length())

        let hei = "{roundi(target.height * 0.001)}"
        let heiBox = get_str_bbox(hei, hei |> length(), fctx)
        ctx |> goto_xy(p.x + markSize, p.y + markSize * 2. + heiBox.width.y)
        ctx |> draw_str_scaled(1., hei, hei |> length())

        let unit = get_unit(int(target.id))
        if unit != null && !unit.isDelayed
          let fmw = unit |> as_fmw()
          if fmw != null
            let spd = "{fmt(":.1f", fmw.fm.Mach)}"
            let spdBox = get_str_bbox(spd, spd |> length(), fctx)
            ctx |> goto_xy(p.x - markSize - spdBox.width.x, p.y + markSize * 2. + spdBox.width.y)
            ctx |> draw_str_scaled(1., spd, spd |> length())

        if target.isDetected || target.isTracked
          if target.typeId != ""
            let typeIds <- {{ "hud/single prop" => "ПРОП"; "hud/multi prop" => "ПРОПxN"; "hud/single jet" => "ТРД"; "hud/multi jet" => "ТРДxN"; "hud/helicopter" => "ВЕРТ"; "hud/rocket" => "РАКЕТА"}}
            get(typeIds, target.typeId) <| $(idText)
              let name = "{idText}"
              let nameBox = get_str_bbox(name, name |> length(), fctx)
              ctx |> goto_xy(pos.x + size.x - nameBox.width.x, pos.y + size.y - float(selectedCnt) * (nameBox.width.y + 4.))
              ctx |> draw_str_scaled(1., name, name |> length())
              selectedCnt += 1
      elif !target.isTracked
        let line <- to_array_move([[float2[2]
          p - float2(markSize, 0.);
          p + float2(markSize, 0.)
          ]])
        ctx |> render_line_aa(line, false, data.lineWidth, float2(0, 0), data.color)
      if target.isAttacked || target.isTracked || (isIrst && target.isSelected)
        let diamond <- to_array_move([[float2[4]
         float2(p.x + markSize * 2., p.y);
         float2(p.x, p.y + markSize * 2.);
         float2(p.x - markSize * 2., p.y);
         float2(p.x, p.y - markSize * 2.);
        ]])
        ctx |> render_line_aa(diamond, true, data.lineWidth, float2(0, 0), color)
        if target.isTracked
          let unit = get_unit(int(target.id))
          if unit != null && !unit.isDelayed
            let fmw = unit |> as_fmw()
            if fmw != null
              let dataStr = "ВЦ:   V:{roundi(unit.speed * mpsToKmh)}  {int(target.id)}  Ψ:{roundi(rad_to_deg(get_radar_hud_target_angle()))}  H={roundi(target.height * 0.001)*1000}"
              let dataStrBox = get_str_bbox(dataStr, dataStr |> length(), fctx)
              ctx |> goto_xy(pos.x + size.x - dataStrBox.width.x, pos.y)
              ctx |> draw_str_scaled(1., dataStr, dataStr |> length())
  ctx |> set_color(data.color)
  let azimuthHalfWidth = get_radar_hud_cue_azimuth_half_width_rel()
  var cueAz = float2(get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() / azimuthRange - azimuthHalfWidth, 0.))
  cueAz.x += (0.5 - azimuthHalfWidth)
  cueAz.y += (0.5 + azimuthHalfWidth)
  let irstCue = dontScale ? cueAz : float2((cueAz.x - minAzimuth) / scanAzimuthRangMul, (cueAz.y - minAzimuth) / scanAzimuthRangMul)
  draw_cue(ctx, pos, size, data, irstCue)

def draw_radar(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);
  ctx |> set_color(data.color)

  let digText = "{roundi(hero.pos.y)}"
  let digStrBox = get_str_bbox(digText, digText |> length(), fctx)
  ctx |> goto_xy(pos.x + 350., pos.y + digStrBox.width.y + 10.)
  ctx |> draw_str_scaled(1., digText, digText |> length())
  ctx |> draw_line(pos.x + 350., pos.y + digStrBox.width.y + 12., pos.x + 350. + digStrBox.width.x, pos.y + digStrBox.width.y + 12., data.lineWidth)

  let autoText = "АВТ"
  let autoStrBox = get_str_bbox(autoText, autoText |> length(), fctx)
  if !get_radar_hud_is_irst() && !get_radar_hud_velocity_search() && !data.isElevationMode
    ctx |> goto_xy(pos.x + 20., pos.y + autoStrBox.width.y + digStrBox.width.y + 10.)
    ctx |> draw_str_scaled(1., autoText, autoText |> length())

  let modeText = get_radar_hud_is_irst() ? "ТП" : "РЛ"
  let modeStrBox = get_str_bbox(modeText, modeText |> length(), fctx)
  ctx |> goto_xy(pos.x + autoStrBox.width.x + 25., pos.y + modeStrBox.width.y + digStrBox.width.y * 0.5 + 10.)
  ctx |> draw_str_scaled(1., modeText, modeText |> length())

  var fctxValue : StdGuiFontContext
  get_font_context(fctxValue, data.fontId, 0, 0, 15)
  ctx |> set_font_ht(15);

  let maxElev = "+40"
  let maxElevBox = get_str_bbox(maxElev, maxElev |> length(), fctxValue)

  let offset = float2(autoStrBox.width.x + 25., autoStrBox.width.y + digStrBox.width.y + 12. + maxElevBox.width.y * 0.5)
  let scopePos = pos + offset
  let scopeSize = size - offset - float2(maxElevBox.width.x + 7., 10. + 2. * maxElevBox.width.y)
  draw_scope(ctx, scopePos, scopeSize, data)

