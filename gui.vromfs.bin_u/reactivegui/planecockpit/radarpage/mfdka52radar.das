require darg
require DagorStdGuiRender
require DagorMath
require DagorTime
require RadarHud
require %rGui.utils.canvas_common
require strings
require math
require Unit
require HeroManager
require FlightModelWrap
require %rGui.utils.constants_common
require %rGui.utils.radar_common
require app
require %gameLibs.das.math.base


let COL_BLACK  = E3DCOLOR(uint4(0, 0, 0, 255))
let COL_WHITE  = E3DCOLOR(uint4(255, 255, 255, 255))
let COL_GREEN  = E3DCOLOR(uint4(0, 255, 0, 255))
let COL_YELLOW = E3DCOLOR(uint4(255, 255, 0, 255))

let FRAME_L = 0.03
let FRAME_T = 0.055
let FRAME_R = 0.97
let FRAME_B = 0.945
let TAB_Y   = 0.02
let LABEL_FONT_SIZE  = 18
let LABEL_FONT_SIZE_R = 18


struct CanvasParams
  color : E3DCOLOR = COL_WHITE
  fontId : int = -1
  lineWidth : float = 2.0



[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", COL_WHITE)
  storage.fontId = props |> getFontId()
  storage.lineWidth = props |> getFloat("lineWidth", 1.0) * 2.0


[export, unused_argument(rstate)]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let totalW = rdata.size.x
  let totalH = rdata.size.y

  draw_background(ctx, rdata)
  draw_frame(ctx, rdata, data)
  draw_top_tabs(ctx, rdata, data)
  draw_left_labels(ctx, rdata, data)
  draw_right_labels(ctx, rdata, data)
  draw_bottom_keys(ctx, rdata, data)

  let scopeL = rdata.pos.x + FRAME_L * totalW
  let scopeT = rdata.pos.y + FRAME_T * totalH
  let scopeR = rdata.pos.x + FRAME_R * totalW
  let scopeB = rdata.pos.y + FRAME_B * totalH
  let scopePos = float2(scopeL, scopeT)
  let scopeSize = float2(scopeR - scopeL, scopeB - scopeT)

  draw_info_bar(ctx, scopePos, scopeSize, data)
  draw_bscope(ctx, scopePos, scopeSize, data)


def draw_background(var ctx : GuiContext&; rdata : ElemRenderData& const)
  ctx |> set_color(COL_BLACK)
  ctx |> render_box(rdata.pos.x, rdata.pos.y, rdata.pos.x + rdata.size.x, rdata.pos.y + rdata.size.y)


def draw_frame(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  ctx |> set_color(COL_WHITE)
  let fl = rdata.pos.x + FRAME_L * rdata.size.x
  let ft = rdata.pos.y + FRAME_T * rdata.size.y
  let fr = rdata.pos.x + FRAME_R * rdata.size.x
  let fb = rdata.pos.y + FRAME_B * rdata.size.y
  ctx |> render_frame(fl, ft, fr, fb, data.lineWidth)


def draw_tab(var ctx : GuiContext&; tabX : float; tabY : float; text : string; active : bool; _data : CanvasParams&; fctx : StdGuiFontContext)
  let box = get_str_bbox(text, length(text), fctx)
  if active
    ctx |> set_color(COL_GREEN)
    ctx |> render_box(tabX - 3.0, tabY - 2.0, tabX + box.width.x + 3.0, tabY + box.width.y + 2.0)
    ctx |> set_color(COL_BLACK)
    ctx |> goto_xy(tabX, tabY + box.width.y)
    ctx |> draw_str_scaled(1.0, text, length(text))
    ctx |> set_color(COL_WHITE)
  else
    ctx |> set_color(COL_WHITE)
    ctx |> goto_xy(tabX, tabY + box.width.y)
    ctx |> draw_str_scaled(1.0, text, length(text))


def draw_top_tabs(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, LABEL_FONT_SIZE)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(LABEL_FONT_SIZE)
  let tabY = rdata.pos.y + TAB_Y * rdata.size.y
  let sw = rdata.size.x
  let sx = rdata.pos.x
  draw_tab(ctx, sx + 0.06 * sw, tabY, "ЦИХ", false, data, fctx)
  draw_tab(ctx, sx + 0.17 * sw, tabY, "ПЛТ", false, data, fctx)
  draw_tab(ctx, sx + 0.28 * sw, tabY, "НВГ", false, data, fctx)
  draw_tab(ctx, sx + 0.39 * sw, tabY, "ОВО", false, data, fctx)
  draw_tab(ctx, sx + 0.50 * sw, tabY, "БКС", false, data, fctx)
  draw_tab(ctx, sx + 0.61 * sw, tabY, "БКО", false, data, fctx)
  draw_tab(ctx, sx + 0.72 * sw, tabY, "РЛС", true, data, fctx)
  draw_tab(ctx, sx + 0.83 * sw, tabY, "ОПС", false, data, fctx)


def draw_vert_text(var ctx : GuiContext&; pos : float2; labels : array<string>; sp : float; fctx : StdGuiFontContext&)
  for idx in range(length(labels))
    let txt = labels[idx]
    let box = get_str_bbox(txt, length(txt), fctx)
    ctx |> goto_xy(pos.x, pos.y + sp * float(idx) + box.width.y)
    ctx |> draw_str_scaled(1.0, txt, length(txt))


def draw_vert_text_boxed(var ctx : GuiContext&; pos : float2; labels : array<string>; sp : float; fctx : StdGuiFontContext&)
  var maxW = 0.0
  for idx in range(length(labels))
    let box = get_str_bbox(labels[idx], length(labels[idx]), fctx)
    if box.width.x > maxW
      maxW = box.width.x
  let textH = sp * float(length(labels))
  let pad = 3.0
  ctx |> render_frame(pos.x - pad, pos.y - pad, pos.x + maxW + pad, pos.y + textH + pad, 1.5)
  draw_vert_text(ctx, pos, labels, sp, fctx)


def draw_left_labels(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  ctx |> set_color(COL_WHITE)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(LABEL_FONT_SIZE)
  let leftX = rdata.pos.x + 0.01 * rdata.size.x
  let sh = rdata.size.y
  let sy = rdata.pos.y
  let sp = 16.0
  let modeName = Radar`getModeName()
  let isAirMode = find(modeName, "air") >= 0
  let isGroundMode = find(modeName, "ground") >= 0
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, LABEL_FONT_SIZE)
  draw_vert_text(ctx, float2(leftX, sy + 0.05 * sh), to_array_move(fixed_array("М", "Е", "Т", "Е", "О")), sp, fctx)
  if isAirMode
    draw_vert_text_boxed(ctx, float2(leftX, sy + 0.22 * sh), to_array_move(fixed_array("В", "В")), sp, fctx)
  else
    draw_vert_text(ctx, float2(leftX, sy + 0.22 * sh), to_array_move(fixed_array("В", "В")), sp, fctx)
  draw_vert_text(ctx, float2(leftX, sy + 0.38 * sh), to_array_move(fixed_array("М", "В", "П")), sp, fctx)
  if isGroundMode
    draw_vert_text_boxed(ctx, float2(leftX, sy + 0.55 * sh), to_array_move(fixed_array("В", "П")), sp, fctx)
  else
    draw_vert_text(ctx, float2(leftX, sy + 0.55 * sh), to_array_move(fixed_array("В", "П")), sp, fctx)
  draw_vert_text(ctx, float2(leftX, sy + 0.72 * sh), to_array_move(fixed_array("К", "О", "Р", "Р")), sp, fctx)


def draw_right_labels(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  ctx |> set_color(COL_WHITE)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(LABEL_FONT_SIZE_R)
  let rightX = rdata.pos.x + 0.975 * rdata.size.x
  let sh = rdata.size.y
  let sy = rdata.pos.y
  let sp = 15.0
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, LABEL_FONT_SIZE_R)
  draw_vert_text(ctx, float2(rightX, sy + 0.05 * sh), to_array_move(fixed_array("И", "З", "Л")), sp, fctx)
  draw_vert_text(ctx, float2(rightX, sy + 0.25 * sh), to_array_move(fixed_array("Ш", "Р", "С")), sp, fctx)


def draw_bottom_keys(var _ctx : GuiContext&; _rdata : ElemRenderData& const; _data : CanvasParams&)
  pass


def draw_info_bar(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, LABEL_FONT_SIZE)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(LABEL_FONT_SIZE)

  let barY = pos.y + 5.0


  ctx |> set_color(COL_WHITE)
  let localTime = get_local_time()
  let timeStr = "{fmt(":02d", localTime.x)}:{fmt(":02d", localTime.y)}:{fmt(":02d", localTime.z)}"
  let timeBox = get_str_bbox(timeStr, length(timeStr), fctx)
  ctx |> goto_xy(pos.x + 5.0, barY + timeBox.width.y)
  ctx |> draw_str_scaled(1.0, timeStr, length(timeStr))

  let spdVal = roundi(hero.speed * mpsToKmh)
  let spdStr = "{spdVal} км/ч"
  ctx |> set_font_ht(roundi(float(LABEL_FONT_SIZE) * 1.2))
  var spdFctx : StdGuiFontContext
  get_font_context(spdFctx, data.fontId, 0, 0, roundi(float(LABEL_FONT_SIZE) * 1.2))
  let spdBox = get_str_bbox(spdStr, length(spdStr), spdFctx)
  let spdX = pos.x + size.x * 0.28
  let spdY = barY + 18.0 * 0.65
  let spdPad = 4.0
  ctx |> set_color(COL_WHITE)
  ctx |> render_box(spdX - spdPad, spdY - spdPad, spdX + spdBox.width.x + spdPad, spdY + spdBox.width.y + spdPad)
  ctx |> set_color(COL_BLACK)
  ctx |> goto_xy(spdX, spdY + spdBox.width.y)
  ctx |> draw_str_scaled(1.0, spdStr, length(spdStr))
  ctx |> set_color(COL_WHITE)
  ctx |> set_font_ht(LABEL_FONT_SIZE)

  let fwd = hero.unitTm[0]
  var headingRad = atan2(fwd.x, fwd.z)
  if headingRad < 0.0
    headingRad += 2.0 * PI
  let headingDeg = headingRad * 180.0 / PI
  let headingVal = roundi(headingDeg) % 360
  let hdgStr = "{headingVal}"
  let hdgBox = get_str_bbox(hdgStr, length(hdgStr), fctx)
  let hdgX = pos.x + size.x * 0.5 - hdgBox.width.x * 0.5
  ctx |> goto_xy(hdgX, barY + hdgBox.width.y)
  ctx |> draw_str_scaled(1.0, hdgStr, length(hdgStr))

  let altVal = roundi(fmw.fm.input.currentAlt)
  let altStr = "{altVal} м"
  ctx |> set_font_ht(roundi(float(LABEL_FONT_SIZE) * 1.2))
  var altFctx : StdGuiFontContext
  get_font_context(altFctx, data.fontId, 0, 0, roundi(float(LABEL_FONT_SIZE) * 1.2))
  let altBox = get_str_bbox(altStr, length(altStr), altFctx)
  let altX = pos.x + size.x * 0.72 - altBox.width.x
  let altY = spdY
  ctx |> set_color(COL_WHITE)
  ctx |> render_box(altX - spdPad, altY - spdPad, altX + altBox.width.x + spdPad, altY + altBox.width.y + spdPad)
  ctx |> set_color(COL_BLACK)
  ctx |> goto_xy(altX, altY + altBox.width.y)
  ctx |> draw_str_scaled(1.0, altStr, length(altStr))
  ctx |> set_color(COL_WHITE)
  ctx |> set_font_ht(LABEL_FONT_SIZE)

  let latlon = get_latitude_longitude()
  let baseLat = latlon.x
  let baseLon = latlon.y
  let cosLat = cos(baseLat * PI / 180.0)
  let lat = baseLat + hero.pos.z / 111320.0
  let lon = baseLon + hero.pos.x / (111320.0 * cosLat)
  let latDeg = roundi(abs(lat))
  let latMin = roundi((abs(lat) - float(latDeg)) * 60.0)
  let latSec = roundi(((abs(lat) - float(latDeg)) * 60.0 - float(latMin)) * 60.0)
  let lonDeg = roundi(abs(lon))
  let lonMin = roundi((abs(lon) - float(lonDeg)) * 60.0)
  let lonSec = roundi(((abs(lon) - float(lonDeg)) * 60.0 - float(lonMin)) * 60.0)
  let coordStr1 = "{fmt(":02d", latDeg)}° {fmt(":02d", latMin)}' {fmt(":02d", latSec)}\""
  let coordStr2 = "{fmt(":03d", lonDeg)}° {fmt(":02d", lonMin)}' {fmt(":02d", lonSec)}\""
  let coordX = pos.x + size.x * 0.78
  let coord1Box = get_str_bbox(coordStr1, length(coordStr1), fctx)
  ctx |> goto_xy(coordX, barY + coord1Box.width.y)
  ctx |> draw_str_scaled(1.0, coordStr1, length(coordStr1))
  ctx |> goto_xy(coordX, barY + coord1Box.width.y * 2.0 + 3.0)
  ctx |> draw_str_scaled(1.0, coordStr2, length(coordStr2))

  let readyY = barY + spdBox.width.y + 8.0
  let rlsStr = "РЛС ГОТОВ"
  let rlsBox = get_str_bbox(rlsStr, length(rlsStr), fctx)
  ctx |> goto_xy(pos.x + 5.0, readyY + rlsBox.width.y)
  ctx |> draw_str_scaled(1.0, rlsStr, length(rlsStr))

  let srzStr = "СРЗ ГОТОВ"
  ctx |> goto_xy(pos.x + 5.0, readyY + rlsBox.width.y * 2.0 + 4.0)
  ctx |> draw_str_scaled(1.0, srzStr, length(srzStr))


def draw_arc(var ctx : GuiContext&; cx : float; cy : float; radius : float; angStart : float; angEnd : float; steps : int; lw : float)
  for idx in range(steps)
    let a0 = lerp(angStart, angEnd, float(idx) / float(steps))
    let a1 = lerp(angStart, angEnd, float(idx + 1) / float(steps))
    ctx |> draw_line(cx + radius * cos(a0), cy + radius * sin(a0),
                     cx + radius * cos(a1), cy + radius * sin(a1), lw)


def draw_bscope_rect(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; _hero : Unit const?)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, LABEL_FONT_SIZE - 2)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(LABEL_FONT_SIZE - 2)

  let azMin = get_radar_hud_azimuth_min()
  let azMax = get_radar_hud_azimuth_max()
  let maxDist = get_radar_hud_distance_max()
  let offset = 5.0
  let markW = 8.0

  let sL = pos.x + size.x * 0.10
  let sR = pos.x + size.x * 0.88
  let sT = pos.y + size.y * 0.14
  let sB = pos.y + size.y * 0.84
  let sW = sR - sL
  let sH = sB - sT

  ctx |> set_color(COL_WHITE)

  ctx |> draw_line(sL - offset, sT, sL - offset, sB, data.lineWidth)
  let numRangeTicks = 5
  for rangeIdx in range(numRangeTicks)
    let frac = float(rangeIdx + 1) / float(numRangeTicks)
    let ry = sT + (1.0 - frac) * sH
    ctx |> draw_line(sL - offset - markW, ry, sL - offset, ry, data.lineWidth)

  ctx |> draw_line(sL, sB + offset, sR, sB + offset, data.lineWidth)
  for azIdx in range(9)
    let frac = float(azIdx) * 0.125
    let ax = sL + frac * sW
    ctx |> draw_line(ax, sB + offset, ax, sB + offset + markW, data.lineWidth)

  ctx |> draw_line(sR + offset, sT, sR + offset, sB, data.lineWidth)
  for elIdx in range(9)
    let frac = float(elIdx) * 0.125
    let ey = sT + frac * sH
    ctx |> draw_line(sR + offset, ey, sR + offset + markW, ey, data.lineWidth)

  for rangeIdx in range(numRangeTicks)
    let frac = float(rangeIdx + 1) / float(numRangeTicks)
    let dist = roundi(maxDist * frac)
    let distStr = "{dist}"
    let distBox = get_str_bbox(distStr, length(distStr), fctx)
    let ry = sT + (1.0 - frac) * sH
    ctx |> goto_xy(sL - offset - markW - distBox.width.x - 2.0, ry + distBox.width.y * 0.5)
    ctx |> draw_str_scaled(1.0, distStr, length(distStr))

  let maxAzStr = "{roundi(rad_to_deg(azMax))}"
  let maxAzBox = get_str_bbox(maxAzStr, length(maxAzStr), fctx)
  ctx |> goto_xy(sR - maxAzBox.width.x * 0.5, sB + offset + markW + maxAzBox.width.y + 2.0)
  ctx |> draw_str_scaled(1.0, maxAzStr, length(maxAzStr))
  let minAzStr = "{roundi(rad_to_deg(azMin))}"
  let minAzBox = get_str_bbox(minAzStr, length(minAzStr), fctx)
  ctx |> goto_xy(sL - minAzBox.width.x * 0.5, sB + offset + markW + minAzBox.width.y + 2.0)
  ctx |> draw_str_scaled(1.0, minAzStr, length(minAzStr))
  let zeroStr = "0"
  let zeroBox = get_str_bbox(zeroStr, 1, fctx)
  ctx |> goto_xy(sL + sW * 0.5 - zeroBox.width.x * 0.5, sB + offset + markW + zeroBox.width.y + 2.0)
  ctx |> draw_str_scaled(1.0, zeroStr, 1)

  let maxElStr = "{roundi(rad_to_deg(get_radar_hud_elevation_max()))}"
  let maxElBox = get_str_bbox(maxElStr, length(maxElStr), fctx)
  ctx |> goto_xy(sR + offset + markW + 3.0, sT + maxElBox.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, maxElStr, length(maxElStr))
  let minElStr = "{roundi(rad_to_deg(get_radar_hud_elevation_min()))}"
  ctx |> goto_xy(sR + offset + markW + 3.0, sB)
  ctx |> draw_str_scaled(1.0, minElStr, length(minElStr))
  ctx |> goto_xy(sR + offset + markW + 3.0, sT + sH * 0.5 + zeroBox.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, zeroStr, 1)

  let azimuthRange = max(0.0, azMax - azMin)
  if get_radar_hud_scan_azimuth_max() > get_radar_hud_scan_azimuth_min()
    let azimuthRangeInv = azimuthRange != 0.0 ? 1.0 / azimuthRange : 1.0
    let scanMinRel = max(0.0, 0.5 + get_radar_hud_scan_azimuth_min() * azimuthRangeInv)
    let scanMaxRel = min(1.0, 0.5 + get_radar_hud_scan_azimuth_max() * azimuthRangeInv)
    ctx |> draw_line(sL + scanMinRel * sW, sB + offset + markW,
      sL + scanMaxRel * sW, sB + offset + markW, data.lineWidth)

  let elevRange = max(0.0, get_radar_hud_elevation_max() - get_radar_hud_elevation_min())
  let elevRangeInv = elevRange != 0.0 ? 1.0 / elevRange : 1.0
  if get_radar_hud_scan_elevation_max() > get_radar_hud_scan_elevation_min()
    let scanElMinRel = 0.5 - get_radar_hud_scan_elevation_min() * elevRangeInv
    let scanElMaxRel = 0.5 - get_radar_hud_scan_elevation_max() * elevRangeInv
    ctx |> draw_line(sR + offset + markW, sT + scanElMaxRel * sH,
      sR + offset + markW, sT + scanElMinRel * sH, data.lineWidth)

  // Cue cursor
  if get_radar_hud_cue_visible()
    let cueAzHwr = get_radar_hud_cue_azimuth_half_width_rel()
    let cueDistW = get_radar_hud_cue_dist_width_rel()
    let cueAzRel = get_radar_hud_cue_azimuth() * get_radar_hud_target_azimuth_width() / azimuthRange + 0.5
    let cueDistRel = get_radar_hud_cue_distance() * get_radar_hud_target_distance()
    let cueX = sL + cueAzRel * sW
    let cueY = sT + (1.0 - cueDistRel) * sH
    let cueHW = cueAzHwr * sW
    let cueHH = cueDistW * sH * 0.5
    ctx |> render_frame(cueX - cueHW, cueY - cueHH, cueX + cueHW, cueY + cueHH, data.lineWidth)

  ctx |> set_font_ht(LABEL_FONT_SIZE - 2)
  let markSize = 5.0
  Radar`foreach_visible_target() <| $(var target)
    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      let angleRel = target.azimuthRel
      if angleRel < 0.0 || angleRel > 1.0
        return
      let distanceRel = target.distanceRel >= 0.0 ? target.distanceRel : 0.9
      let tp = float2(sL + angleRel * sW, sT + (1.0 - distanceRel) * sH)
      let color = target.isEnemy ? data.color : E3DCOLOR(0xFF0000FF)
      ctx |> set_color(color)
      if target.isDetected || target.isTracked || target.isAttacked
        let diamond <- to_array_move(fixed_array(
          float2(tp.x + markSize * 2.0, tp.y),
          float2(tp.x, tp.y + markSize * 2.0),
          float2(tp.x - markSize * 2.0, tp.y),
          float2(tp.x, tp.y - markSize * 2.0)))
        ctx |> render_line_aa(diamond, true, data.lineWidth, float2(0, 0), color)
      elif target.isSelected
        ctx |> draw_line(tp.x - markSize, tp.y - markSize, tp.x + markSize, tp.y + markSize, data.lineWidth)
        ctx |> draw_line(tp.x - markSize, tp.y + markSize, tp.x + markSize, tp.y - markSize, data.lineWidth)
      else
        ctx |> draw_line(tp.x - markSize, tp.y, tp.x + markSize, tp.y, data.lineWidth)

  ctx |> set_color(COL_WHITE)


def draw_bscope_scan(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; hero : Unit const?)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, LABEL_FONT_SIZE)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(LABEL_FONT_SIZE)

  let scopeCX = pos.x + size.x * 0.5
  let ownX = scopeCX
  let maxRadius = size.y * 0.8
  let ownY = pos.y + size.y * 0.12 + maxRadius

  let azMin = get_radar_hud_azimuth_min()
  let azMax = get_radar_hud_azimuth_max()
  let maxDist = get_radar_hud_distance_max()
  let arcScale = 0.85
  let azStart = -PI * 0.5 + azMin * arcScale
  let azEnd = -PI * 0.5 + azMax * arcScale
  ctx |> set_color(COL_WHITE)

  draw_arc(ctx, ownX, ownY, maxRadius, azStart, azEnd, 64, data.lineWidth * 2.0)

  let maxRangeKm = maxDist > 0.0 ? maxDist : 32.0
  let is32km = maxRangeKm >= 30.0
  let numMarks = is32km ? 7 : 4
  let baseTickArcSpan = 0.12
  ctx |> set_font_ht(18)
  get_font_context(fctx, data.fontId, 0, 0, 18)

  for ringIdx in range(numMarks)
    var markVal = 0.0
    if is32km
      markVal = 8.0 + 4.0 * float(ringIdx)
    else
      markVal = maxRangeKm / 4.0 * float(ringIdx + 1)
    let rangeFrac = markVal / maxRangeKm
    let arcR = maxRadius * rangeFrac
    let isInteger = abs(markVal - float(roundi(markVal))) < 0.01
    let distStr = isInteger ? "{roundi(markVal)}" : "{fmt(":.1f", markVal)}"
    let distBox = get_str_bbox(distStr, length(distStr), fctx)
    let tickArcSpan = baseTickArcSpan * (1.2 + 0.1 * float(ringIdx))

    let arcSpread = (azEnd - azStart) * 0.10
    let rangeAzStart = azStart - arcSpread
    let rangeAzEnd = azEnd + arcSpread

    let isLast = ringIdx == numMarks - 1

    if isLast
      let lastLabelOffset = 11.0
      let lAng = azStart
      let lP = float2(ownX + (maxRadius + lastLabelOffset) * cos(lAng), ownY + (maxRadius + lastLabelOffset) * sin(lAng))
      ctx |> goto_xy(lP.x - distBox.width.x * 0.5, lP.y + distBox.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, distStr, length(distStr))
      let rAng = azEnd
      let rP = float2(ownX + (maxRadius + lastLabelOffset) * cos(rAng), ownY + (maxRadius + lastLabelOffset) * sin(rAng))
      ctx |> goto_xy(rP.x - distBox.width.x * 0.5, rP.y + distBox.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, distStr, length(distStr))
    else
      let lLabelAng = rangeAzStart - 0.02
      let lx = ownX + arcR * cos(lLabelAng)
      let ly = ownY + arcR * sin(lLabelAng)
      ctx |> goto_xy(lx - distBox.width.x, ly + distBox.width.y * 0.3)
      ctx |> draw_str_scaled(1.0, distStr, length(distStr))
      let lTickGapAng = 0.03
      draw_arc(ctx, ownX, ownY, arcR, rangeAzStart + lTickGapAng, rangeAzStart + lTickGapAng + tickArcSpan, 6, data.lineWidth)

      let rTickGapAng = 0.03
      draw_arc(ctx, ownX, ownY, arcR, rangeAzEnd - rTickGapAng - tickArcSpan, rangeAzEnd - rTickGapAng, 6, data.lineWidth)
      let rLabelAng = rangeAzEnd + 0.02
      let rx = ownX + arcR * cos(rLabelAng)
      let ry = ownY + arcR * sin(rLabelAng)
      ctx |> goto_xy(rx, ry + distBox.width.y * 0.3)
      ctx |> draw_str_scaled(1.0, distStr, length(distStr))

  ctx |> set_font_ht(LABEL_FONT_SIZE)
  get_font_context(fctx, data.fontId, 0, 0, LABEL_FONT_SIZE)
  let fwdB = hero.unitTm[0]
  var hdgRad = atan2(fwdB.x, fwdB.z)
  if hdgRad < 0.0
    hdgRad += 2.0 * PI
  let hdgCenter = hdgRad * 180.0 / PI
  let hdgHalfSpan = rad_to_deg(azMax * arcScale)
  let tickStart = roundi(hdgCenter - hdgHalfSpan) - 5
  let tickEnd = roundi(hdgCenter + hdgHalfSpan) + 6

  let compassR = maxRadius
  let tickHalf = 7.0
  let labelOffset = tickHalf + 4.0

  ctx |> set_color(COL_WHITE)
  for tickIdx in range(tickEnd - tickStart)
    let tickDeg = tickStart + tickIdx
    var deg = tickDeg % 360
    if deg < 0
      deg += 360
    let relPos = (float(tickDeg) - hdgCenter) / hdgHalfSpan
    if abs(relPos) > 1.0
      continue
    let tickAng = lerp(azStart, azEnd, relPos * 0.5 + 0.5)

    if tickDeg % 10 == 0
      let innerP = float2(ownX + (compassR - tickHalf) * cos(tickAng), ownY + (compassR - tickHalf) * sin(tickAng))
      let outerP = float2(ownX + (compassR + tickHalf) * cos(tickAng), ownY + (compassR + tickHalf) * sin(tickAng))
      ctx |> draw_line(innerP.x, innerP.y, outerP.x, outerP.y, data.lineWidth)
      let numStr = "{deg / 10}"
      let numBox = get_str_bbox(numStr, length(numStr), fctx)
      let labelP = float2(ownX + (compassR + labelOffset) * cos(tickAng), ownY + (compassR + labelOffset) * sin(tickAng))
      ctx |> goto_xy(labelP.x - numBox.width.x * 0.5, labelP.y + numBox.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, numStr, length(numStr))
    elif tickDeg % 5 == 0
      let innerP = float2(ownX + (compassR - tickHalf * 0.5) * cos(tickAng), ownY + (compassR - tickHalf * 0.5) * sin(tickAng))
      let outerP = float2(ownX + (compassR + tickHalf * 0.5) * cos(tickAng), ownY + (compassR + tickHalf * 0.5) * sin(tickAng))
      ctx |> draw_line(innerP.x, innerP.y, outerP.x, outerP.y, data.lineWidth * 0.7)

  ctx |> set_color(COL_YELLOW)
  let markerAng = -PI * 0.5
  let mp = float2(ownX + (compassR + tickHalf * 0.5) * cos(markerAng), ownY + (compassR + tickHalf * 0.5) * sin(markerAng))
  ctx |> draw_line(mp.x - 4.0, mp.y, mp.x + 4.0, mp.y, data.lineWidth * 1.2)
  ctx |> draw_line(mp.x, mp.y - 4.0, mp.x, mp.y + 4.0, data.lineWidth * 1.2)

  ctx |> set_color(COL_WHITE)
  let crossCY = ownY - maxRadius * 0.45
  ctx |> draw_line(scopeCX - 10.0, crossCY, scopeCX + 10.0, crossCY, data.lineWidth * 0.8)
  ctx |> draw_line(scopeCX, crossCY - 10.0, scopeCX, crossCY + 10.0, data.lineWidth * 0.8)

  ctx |> set_font_ht(LABEL_FONT_SIZE)
  get_font_context(fctx, data.fontId, 0, 0, LABEL_FONT_SIZE)
  let botInfoY = pos.y + size.y * 0.90
  draw_horizontal_label(ctx, float2(scopeCX - 12.0, botInfoY), "УПР")

  let cueDistVal = get_radar_hud_cue_distance() * get_radar_hud_target_distance() * maxDist
  let cueAzRaw = get_radar_hud_cue_azimuth() * get_radar_hud_target_azimuth_width()
  let cueAzVal = rad_to_deg(cueAzRaw)
  let azInfoStr = "А {fmt(":.1f", abs(cueAzVal))}"
  let dInfoStr = "Д {fmt(":.3f", cueDistVal)}"
  let infoRight = pos.x + size.x * 0.88
  let azInfoBox = get_str_bbox(azInfoStr, length(azInfoStr), fctx)
  ctx |> goto_xy(infoRight - azInfoBox.width.x, botInfoY + azInfoBox.width.y)
  ctx |> draw_str_scaled(1.0, azInfoStr, length(azInfoStr))
  let dInfoBox = get_str_bbox(dInfoStr, length(dInfoStr), fctx)
  ctx |> goto_xy(infoRight - dInfoBox.width.x, botInfoY + azInfoBox.width.y + dInfoBox.width.y + 3.0)
  ctx |> draw_str_scaled(1.0, dInfoStr, length(dInfoStr))

  let markSize = 6.0
  Radar`foreach_visible_target() <| $(var target)
    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      if target.azimuthRel < 0.0 || target.azimuthRel > 1.0
        return
      let distanceRel = target.distanceRel >= 0.0 ? target.distanceRel : 0.9
      let tgtAng = lerp(azStart, azEnd, target.azimuthRel)
      let tgtR = maxRadius * distanceRel
      let tgtPos = float2(ownX + tgtR * cos(tgtAng), ownY + tgtR * sin(tgtAng))
      let color = target.isEnemy ? COL_GREEN : E3DCOLOR(0xFF0000FF)
      ctx |> set_color(color)
      if target.isDetected || target.isTracked || target.isAttacked
        let diamond <- to_array_move(fixed_array(
          float2(tgtPos.x + markSize, tgtPos.y),
          float2(tgtPos.x, tgtPos.y + markSize),
          float2(tgtPos.x - markSize, tgtPos.y),
          float2(tgtPos.x, tgtPos.y - markSize)))
        ctx |> render_line_aa(diamond, true, data.lineWidth, float2(0, 0), color)
      elif target.isSelected
        ctx |> draw_line(tgtPos.x - markSize, tgtPos.y - markSize, tgtPos.x + markSize, tgtPos.y + markSize, data.lineWidth)
        ctx |> draw_line(tgtPos.x - markSize, tgtPos.y + markSize, tgtPos.x + markSize, tgtPos.y - markSize, data.lineWidth)
      else
        ctx |> draw_line(tgtPos.x - markSize, tgtPos.y, tgtPos.x + markSize, tgtPos.y, data.lineWidth)

  ctx |> set_color(COL_WHITE)


def draw_bscope(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  if !get_radar_hud_mfd_radar_enabled()
    return
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return

  let modeName = Radar`getModeName()
  let isScanMode = find(modeName, "MTI") >= 0 || find(modeName, "standby") >= 0
  if isScanMode
    draw_bscope_scan(ctx, pos, size, data, hero)
  else
    draw_bscope_rect(ctx, pos, size, data, hero)
