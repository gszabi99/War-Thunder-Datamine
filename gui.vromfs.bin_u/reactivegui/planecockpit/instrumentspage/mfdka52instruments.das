require darg
require DagorStdGuiRender
require FlightModelWrap
require HeroManager
require Unit
require math
require DagorMath
require strings
require %rGui.utils.constants_common
require app
require Plane

let colWhite   = E3DCOLOR(0xFF_FFFFFF)
let colCyan    = E3DCOLOR(0xFF_66D9FF)
let colYellow  = E3DCOLOR(0xFF_FFFF00)
let colRed     = E3DCOLOR(0xFF_FF2200)
let colGreen   = E3DCOLOR(0xFF_00FF00)
let colBlack   = E3DCOLOR(0xFF_000000)
let colEmpty   = E3DCOLOR(0x00_000000)
let colSky     = E3DCOLOR(uint4(0, 40, 200, 255))
let colGround  = E3DCOLOR(uint4(255, 20, 0, 255))

struct CanvasParams
  fontId : int = -1
  fontSize : int = 16
  horMask : Picture?
  lineWidth : float = 2.0

[export]
def setup(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 16)
  storage.horMask = props |> getPicture("horMask")
  storage.lineWidth = props |> getFloat("lineWidth", 2.0)

def tick(var ctx : GuiContext&; centerX : float; centerY : float; angle : float; radiusInner : float; radiusOuter : float; width : float; color : E3DCOLOR)
  let co = cos(angle)
  let si = sin(angle)
  ctx |> set_color(color)
  ctx |> draw_line(centerX + co * radiusInner, centerY + si * radiusInner, centerX + co * radiusOuter, centerY + si * radiusOuter, width)


def draw_centered(var ctx : GuiContext&; txt : string; centerX : float; centerY : float; fctx : StdGuiFontContext&)
  let bx = get_str_bbox(txt, txt |> length(), fctx)
  ctx |> goto_xy(centerX - bx.width.x * 0.5, centerY + bx.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, txt, txt |> length())

def draw_digi_box(var ctx : GuiContext&; centerX : float; centerY : float; boxW : float; boxH : float; frameCol : E3DCOLOR; txtCol : E3DCOLOR; txt : string; data : CanvasParams&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  let x0 = centerX - boxW * 0.5
  let y0 = centerY - boxH * 0.5
  ctx |> set_color(frameCol)
  ctx |> render_frame(x0, y0, x0 + boxW, y0 + boxH, 1.5)
  ctx |> set_color(txtCol)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  let bxx = get_str_bbox(txt, txt |> length(), fctx)
  ctx |> goto_xy(centerX - bxx.width.x * 0.5, centerY + bxx.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, txt, txt |> length())

def draw_bank_label(var ctx : GuiContext&; center : float2; radius : float; fctx : StdGuiFontContext&; bankDeg : float; txt : string)
  let abdeg = abs(bankDeg)
  let ang = bankDeg > 0.0 ? abdeg * (PI / 180.0) : (180.0 - abdeg) * (PI / 180.0)
  let labelR = radius * 0.83
  let bx = get_str_bbox(txt, txt |> length(), fctx)
  ctx |> set_color(colWhite)
  ctx |> goto_xy(center.x + cos(ang) * labelR - bx.width.x * 0.5, center.y + sin(ang) * labelR + bx.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, txt, txt |> length())

def draw_dial_mark(var ctx : GuiContext&; center : float2; radius : float; fctx : StdGuiFontContext&; txt : string; scrDeg : float)
  let ang = scrDeg * (PI / 180.0)
  tick(ctx, center.x, center.y, ang, radius * 0.80, radius * 1.0, 2.5, colWhite)
  let bx = get_str_bbox(txt, txt |> length(), fctx)
  let labelR = radius * 0.67
  ctx |> set_color(colWhite)
  ctx |> goto_xy(center.x + cos(ang) * labelR - bx.width.x * 0.5, center.y + sin(ang) * labelR + bx.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, txt, txt |> length())

def draw_minor_ticks(var ctx : GuiContext&; center : float2; radius : float; degStart : float; degEnd : float; degOffset : float = 0.0)
  let step = (degEnd - degStart) / 5.0
  for k in range(1, 5)
    var deg = degStart + step * float(k)
    if deg >= 360.0
      deg = deg - 360.0
    if deg < 0.0
      deg = deg + 360.0
    let ang = (degOffset + deg) * (PI / 180.0)
    tick(ctx, center.x, center.y, ang, radius * 0.90, radius * 1.0, 1.0, colWhite)

def draw_top_tab(var ctx : GuiContext&; posX : float; sp1 : float; sizeX : float; r1y : float; fctx : StdGuiFontContext&; idx : int; txt : string; off : float)
  let bx = get_str_bbox(txt, txt |> length(), fctx)
  let lx = posX + sp1 * float(idx + 1) + sizeX * off
  ctx |> set_color(idx == 0 ? colGreen : colWhite)
  ctx |> goto_xy(lx - bx.width.x * 0.5, r1y)
  ctx |> draw_str_scaled(1.0, txt, txt |> length())

def draw_tang_char(var ctx : GuiContext&; ch : string; posX : float; posY : float; fctx : StdGuiFontContext&)
  let chBx = get_str_bbox(ch, ch |> length(), fctx)
  ctx |> goto_xy(posX - chBx.width.x * 0.5, posY + chBx.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, ch, ch |> length())

[export, unused_argument(rstate)]
def render(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return

  let pos = rdata.pos
  let size = rdata.size

  ctx |> set_color(colBlack)
  ctx |> render_box(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

  let spdKmh  = hero.speed * mpsToKmh
  let pitch   = fmw.tangage
  let rollDeg = fmw.roll
  let vs      = fmw.fm.vertSpeed
  let ralt    = fmw.fm.input.currentAlt
  let baltM   = hero.unitTm[3].y - get_app().currentScene.waterLevel
  let hdg     = norm_ang(2.0 * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z)) * radToDeg
  let ball    = fmw.ballVal
  let aoaDeg = hero.speed > 1.0 ? fmw.fm.aoa : 0.0

  let topCy = pos.y + size.y * 0.28
  let botCy = pos.y + size.y * 0.73
  let sR  = size.y * 0.20
  let hR  = size.y * 0.22
  let bsR = size.y * 0.16
  let hsiR = size.y * 0.215

  draw_top_bar(ctx, pos, size, data, spdKmh)
  draw_horizon(ctx, float2(pos.x + size.x * 0.50, topCy), hR, data, pitch, rollDeg, ball)
  draw_speed(ctx, float2(pos.x + size.x * 0.17, topCy), sR, data, spdKmh)
  draw_vario(ctx, float2(pos.x + size.x * 0.83, topCy), sR, data, vs)
  draw_hsi(ctx, float2(pos.x + size.x * 0.50, botCy), hsiR, data, hdg)
  draw_radio_alt(ctx, float2(pos.x + size.x * 0.17, botCy - size.y * 0.05), bsR, data, ralt)
  draw_aoa(ctx, float2(pos.x + size.x * 0.24, botCy - size.y * 0.115), bsR, data, aoaDeg)
  draw_baro_alt(ctx, float2(pos.x + size.x * 0.83, botCy - size.y * 0.05), bsR, data, baltM)

  var tangFctx : StdGuiFontContext
  let tangFnt = max(data.fontSize - 4, 10)
  get_font_context(tangFctx, data.fontId, 0, 0, tangFnt)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(tangFnt)
  ctx |> set_color(colWhite)
  let tangX = pos.x + size.x * 0.98
  let tangMidY = (topCy + botCy - size.y * 0.05) * 0.5
  let tangStep = float(tangFnt) + 2.0
  let tangStartY = tangMidY - tangStep * 1.5
  draw_tang_char(ctx, "Т", tangX, tangStartY, tangFctx)
  draw_tang_char(ctx, "А", tangX, tangStartY + tangStep, tangFctx)
  draw_tang_char(ctx, "Н", tangX, tangStartY + tangStep * 2.0, tangFctx)
  draw_tang_char(ctx, "Г", tangX, tangStartY + tangStep * 3.0, tangFctx)

  draw_bottom_bar(ctx, pos, size, data, spdKmh, hdg)

def draw_speed(var ctx : GuiContext&; center : float2; radius : float; data : CanvasParams&; speed : float)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize - 2)
  ctx |> set_font(data.fontId, 0, 0)

  let startClock = 7.5
  let sweepDeg = 330.0
  let minVal = 20.0
  let maxVal = 350.0

  let arcS = (270.0 + startClock) * (PI / 180.0)
  let arcE = (270.0 + startClock + sweepDeg) * (PI / 180.0)
  ctx |> render_sector_aa(center, float2(radius), float2(arcS, arcE), 2.5, colWhite, colEmpty)

  let yf0 = (250.0 - minVal) / (maxVal - minVal)
  let yf1 = (270.0 - minVal) / (maxVal - minVal)
  let ya0 = (270.0 + startClock + yf0 * sweepDeg) * (PI / 180.0)
  let ya1 = (270.0 + startClock + yf1 * sweepDeg) * (PI / 180.0)
  ctx |> render_sector_aa(center, float2(radius * 0.98), float2(ya0, ya1), 3.5, colYellow, colEmpty)

  let rf0 = (270.0 - minVal) / (maxVal - minVal)
  let ra0 = (270.0 + startClock + rf0 * sweepDeg) * (PI / 180.0)
  ctx |> render_sector_aa(center, float2(radius * 0.98), float2(ra0, arcE), 4.0, colRed, colEmpty)

  ctx |> set_font_ht(data.fontSize - 2)
  let spdMarks <- to_array_move(fixed_array(20.0, 50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0))
  for val in spdMarks
    let frac = (val - minVal) / (maxVal - minVal)
    let ang = (270.0 + startClock + frac * sweepDeg) * (PI / 180.0)
    tick(ctx, center.x, center.y, ang, radius * 0.80, radius * 1.0, 2.5, colWhite)

    let txt = "{int(val / 10.0)}"
    let labelR = radius * 0.67
    ctx |> set_color(colWhite)
    let bx = get_str_bbox(txt, txt |> length(), fctx)
    ctx |> goto_xy(center.x + cos(ang) * labelR - bx.width.x * 0.5, center.y + sin(ang) * labelR + bx.width.y * 0.5)
    ctx |> draw_str_scaled(1.0, txt, txt |> length())

  for j in range(1, 3)
    let val = 20.0 + float(j) * 10.0
    let frac = (val - minVal) / (maxVal - minVal)
    let ang = (270.0 + startClock + frac * sweepDeg) * (PI / 180.0)
    tick(ctx, center.x, center.y, ang, radius * 0.90, radius * 1.0, 1.0, colWhite)
  for j in range(0, 31)
    let val = 50.0 + float(j) * 10.0
    if val > maxVal
      break
    let ival = int(val)
    if ival == 50 || ival == 100 || ival == 150 || ival == 200 || ival == 250 || ival == 300 || ival == 350
      continue
    let frac = (val - minVal) / (maxVal - minVal)
    let ang = (270.0 + startClock + frac * sweepDeg) * (PI / 180.0)
    tick(ctx, center.x, center.y, ang, radius * 0.90, radius * 1.0, 1.0, colWhite)

  let sf = max(data.fontSize - 4, 10)
  ctx |> set_font_ht(sf)
  ctx |> set_color(colWhite)
  draw_centered(ctx, "КМ/Ч", center.x, center.y - radius * 0.18, fctx)

  var digiCol = colGreen
  if speed > 270.0
    digiCol = colRed
  elif speed > 250.0
    digiCol = colYellow
  draw_digi_box(ctx, center.x, center.y + radius * 0.02, radius * 0.52, radius * 0.22, digiCol, digiCol, "{int(speed)}", data)

  ctx |> set_font_ht(sf)
  ctx |> set_color(colWhite)
  draw_centered(ctx, "СКОРОСТЬ", center.x, center.y + radius * 0.25, fctx)

  let clampedSpd = clamp(speed, minVal, maxVal)
  let nFrac = (clampedSpd - minVal) / (maxVal - minVal)
  let nA = (270.0 + startClock + nFrac * sweepDeg) * (PI / 180.0)
  let nDir = float2(cos(nA), sin(nA))
  let nPerp = float2(-nDir.y, nDir.x)
  let baseP = center + nDir * radius * 0.35
  let tipP = center + nDir * radius * 0.78
  let pts <- to_array_move(fixed_array(tipP, baseP + nPerp * radius * 0.04, baseP - nPerp * radius * 0.04))
  ctx |> render_poly(pts, colCyan)
  ctx |> render_line_aa(pts, true, 1.0, float2(0.0), colCyan)

  let gA = 210.0 * (PI / 180.0)
  let gDir = float2(cos(gA), sin(gA))
  let gPerp = float2(-gDir.y, gDir.x)
  let gP = center + gDir * radius * 0.96
  let gt <- to_array_move(fixed_array(gP + gDir * radius * 0.07, gP + gPerp * radius * 0.04, gP - gPerp * radius * 0.04))
  ctx |> render_poly(gt, colGreen)

  let bA2 = 330.0 * (PI / 180.0)
  let bDir = float2(cos(bA2), sin(bA2))
  let bPerp = float2(-bDir.y, bDir.x)
  let bP = center + bDir * radius * 0.96
  let bt <- to_array_move(fixed_array(bP + bDir * radius * 0.07, bP + bPerp * radius * 0.04, bP - bPerp * radius * 0.04))
  ctx |> render_poly(bt, colCyan)

[unused_argument(ballVal)]
def draw_horizon(var ctx : GuiContext&; center : float2; radius : float; data : CanvasParams&; pitch : float; roll : float; ballVal : float)
  let sz = float2(radius * 2.0)
  let tl = center - float2(radius)
  let horY = center.y + radius * cvt(pitch, -30.0, 30.0, -1.0, 1.0)

  ctx |> set_viewport(tl.x, tl.y, tl.x + sz.x, tl.y + sz.y)

  ctx |> set_color(colSky)
  ctx |> render_box(tl.x - radius, tl.y - radius * 3.0, tl.x + sz.x + radius, horY)
  ctx |> set_color(colGround)
  ctx |> render_box(tl.x - radius, horY, tl.x + sz.x + radius, tl.y + sz.y + radius * 3.0)
  ctx |> set_color(colWhite)
  ctx |> draw_line(tl.x - radius * 2.0, horY, tl.x + sz.x + radius * 2.0, horY, 2.5)

  var fctx : StdGuiFontContext
  let pf = max(data.fontSize - 3, 10)
  get_font_context(fctx, data.fontId, 0, 0, pf)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(pf)

  let pixPerDeg = radius / 30.0
  for i in range(-12, 13)
    let mv = (int(pitch) / 5) * 5 + i * 5
    if mv == 0
      continue
    let py = center.y + (pitch - float(mv)) * pixPerDeg
    ctx |> set_color(colWhite)

    if abs(mv) % 10 == 0
      let hwOuter = radius * 0.30
      let hwInner = radius * 0.10
      ctx |> draw_line(center.x - hwOuter, py, center.x - hwInner, py, 1.5)
      ctx |> draw_line(center.x + hwInner, py, center.x + hwOuter, py, 1.5)
      let txt = "{abs(mv)}"
      let bx = get_str_bbox(txt, txt |> length(), fctx)
      ctx |> goto_xy(center.x - bx.width.x * 0.5, py + bx.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, txt, txt |> length())
    else
      let hw = radius * 0.12
      ctx |> draw_line(center.x - hw, py, center.x + hw, py, 1.5)

  render_picture(ctx, data.horMask, tl - float2(1.0), sz + float2(2.0), colBlack)
  ctx |> restore_viewport()

  ctx |> set_viewport(tl.x, tl.y, tl.x + sz.x, tl.y + sz.y)
  ctx |> setRotViewTm(center.x, center.y, -roll * degToRad, 0.0, false)

  let cirR = radius * 0.088
  let wingY = center.y + cirR
  ctx |> set_color(colWhite)
  ctx |> render_ellipse_aa(center, float2(cirR), 2.5, colWhite, colEmpty)
  ctx |> render_ellipse_aa(center, float2(cirR * 0.25), 2.0, colWhite, colWhite)
  ctx |> draw_line(center.x - cirR * 0.7, wingY, center.x - cirR * 2.0, center.y, 2.5)
  ctx |> draw_line(center.x - cirR * 2.0, center.y, center.x - radius * 0.45, center.y, 2.5)
  ctx |> draw_line(center.x + cirR * 0.7, wingY, center.x + cirR * 2.0, center.y, 2.5)
  ctx |> draw_line(center.x + cirR * 2.0, center.y, center.x + radius * 0.45, center.y, 2.5)
  ctx |> draw_line(center.x, center.y - cirR, center.x, center.y - radius * 0.25, 2.5)

  ctx |> resetViewTm()
  ctx |> restore_viewport()

  var bankFctx : StdGuiFontContext
  let bankFnt = max(data.fontSize - 4, 9)
  get_font_context(bankFctx, data.fontId, 0, 0, bankFnt)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(bankFnt)

  draw_bank_label(ctx, center, radius, bankFctx, 15.0, "15")
  draw_bank_label(ctx, center, radius, bankFctx, -15.0, "15")
  draw_bank_label(ctx, center, radius, bankFctx, 30.0, "30")
  draw_bank_label(ctx, center, radius, bankFctx, -30.0, "30")
  draw_bank_label(ctx, center, radius, bankFctx, 45.0, "45")
  draw_bank_label(ctx, center, radius, bankFctx, -45.0, "45")
  draw_bank_label(ctx, center, radius, bankFctx, 60.0, "60")
  draw_bank_label(ctx, center, radius, bankFctx, -60.0, "60")

  let tt <- to_array_move(fixed_array(
    center - float2(0.0, radius * 0.96),
    center - float2(radius * 0.04, radius * 0.89),
    center + float2(radius * 0.04, -radius * 0.89)))
  ctx |> render_poly(tt, colWhite)

def draw_vario(var ctx : GuiContext&; center : float2; radius : float; data : CanvasParams&; vertSpeed : float)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize - 2)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize - 2)

  ctx |> render_ellipse_aa(center, float2(radius), 2.5, colWhite, colEmpty)

  draw_dial_mark(ctx, center, radius, fctx, "0", 270.0 + 270.0)
  draw_dial_mark(ctx, center, radius, fctx, "5", 270.0 + 300.0)
  draw_dial_mark(ctx, center, radius, fctx, "5", 270.0 + 240.0)
  draw_dial_mark(ctx, center, radius, fctx, "10", 270.0 + 352.5)
  draw_dial_mark(ctx, center, radius, fctx, "10", 270.0 + 187.5)
  draw_dial_mark(ctx, center, radius, fctx, "20", 270.0 + 45.0)
  draw_dial_mark(ctx, center, radius, fctx, "20", 270.0 + 135.0)
  draw_dial_mark(ctx, center, radius, fctx, "30", 270.0 + 90.0)

  draw_minor_ticks(ctx, center, radius, 270.0, 300.0, 270.0)
  draw_minor_ticks(ctx, center, radius, 300.0, 352.5, 270.0)
  draw_minor_ticks(ctx, center, radius, 352.5, 405.0, 270.0)
  draw_minor_ticks(ctx, center, radius, 45.0, 90.0, 270.0)
  draw_minor_ticks(ctx, center, radius, 270.0, 240.0, 270.0)
  draw_minor_ticks(ctx, center, radius, 240.0, 187.5, 270.0)
  draw_minor_ticks(ctx, center, radius, 187.5, 135.0, 270.0)
  draw_minor_ticks(ctx, center, radius, 135.0, 90.0, 270.0)

  let sf = max(data.fontSize - 4, 10)
  ctx |> set_font_ht(sf)
  ctx |> set_color(colWhite)
  draw_centered(ctx, "М/С", center.x, center.y - radius * 0.18, fctx)

  let vTen = int(abs(vertSpeed) * 10.0)
  let vW = vTen / 10
  let vF = vTen % 10
  var vTxt = ""
  if vertSpeed >= 0.0
    vTxt = "{vW}.{vF}"
  else
    vTxt = "-{vW}.{vF}"
  draw_digi_box(ctx, center.x, center.y + radius * 0.02, radius * 0.52, radius * 0.22, colCyan, colCyan, vTxt, data)

  ctx |> set_font_ht(sf)
  ctx |> set_color(colWhite)
  draw_centered(ctx, "ВР", center.x, center.y + radius * 0.25, fctx)

  let absVs = abs(vertSpeed)
  var needleClockDeg = 270.0
  if absVs <= 5.0
    needleClockDeg = 270.0 + (absVs / 5.0) * 30.0
  elif absVs <= 10.0
    needleClockDeg = 300.0 + ((absVs - 5.0) / 5.0) * 52.5
  elif absVs <= 20.0
    needleClockDeg = 352.5 + ((absVs - 10.0) / 10.0) * 52.5
  else
    needleClockDeg = 45.0 + ((clamp(absVs, 20.0, 30.0) - 20.0) / 10.0) * 45.0
  if vertSpeed < 0.0
    let offset = needleClockDeg - 270.0
    needleClockDeg = 270.0 - offset
    if needleClockDeg < 0.0
      needleClockDeg = needleClockDeg + 360.0
  let nA = (270.0 + needleClockDeg) * (PI / 180.0)
  let nDir = float2(cos(nA), sin(nA))
  let nPerp = float2(-nDir.y, nDir.x)
  let baseP = center + nDir * radius * 0.35
  let tipP = center + nDir * radius * 0.78
  let pts <- to_array_move(fixed_array(tipP, baseP + nPerp * radius * 0.04, baseP - nPerp * radius * 0.04))
  ctx |> render_poly(pts, colCyan)
  ctx |> render_line_aa(pts, true, 1.0, float2(0.0), colCyan)

def draw_radio_alt(var ctx : GuiContext&; center : float2; radius : float; data : CanvasParams&; altitude : float)

  let maxA = 300.0

  let whiteS = 270.0 * (PI / 180.0)
  let whiteE = (270.0 + 307.5) * (PI / 180.0)
  ctx |> render_sector_aa(center, float2(radius), float2(whiteS, whiteE), 2.5, colWhite, colEmpty)

  let redS = 270.0 * (PI / 180.0)
  let redE = (270.0 + 217.5) * (PI / 180.0)
  ctx |> render_sector_aa(center, float2(radius * 1.09), float2(redS, redE), 2.5, colRed, colEmpty)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize - 3)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize - 3)

  draw_dial_mark(ctx, center, radius, fctx, "0", 270.0)
  draw_dial_mark(ctx, center, radius, fctx, "10", 292.5)
  draw_dial_mark(ctx, center, radius, fctx, "20", 330.0)
  draw_dial_mark(ctx, center, radius, fctx, "30", 360.0)
  draw_dial_mark(ctx, center, radius, fctx, "40", 30.0)
  draw_dial_mark(ctx, center, radius, fctx, "50", 60.0)
  draw_dial_mark(ctx, center, radius, fctx, "100", 90.0)
  draw_dial_mark(ctx, center, radius, fctx, "200", 150.0)
  draw_dial_mark(ctx, center, radius, fctx, "300", 217.5)

  draw_minor_ticks(ctx, center, radius, 270.0, 292.5)
  draw_minor_ticks(ctx, center, radius, 292.5, 330.0)
  draw_minor_ticks(ctx, center, radius, 330.0, 360.0)
  draw_minor_ticks(ctx, center, radius, 360.0, 390.0)
  draw_minor_ticks(ctx, center, radius, 390.0, 420.0)
  draw_minor_ticks(ctx, center, radius, 420.0, 450.0)
  draw_minor_ticks(ctx, center, radius, 450.0, 510.0)
  draw_minor_ticks(ctx, center, radius, 510.0, 577.5)

  let redTickA = 127.5 * (PI / 180.0)
  tick(ctx, center.x, center.y, redTickA, radius * 0.78, radius * 1.09, 2.5, colRed)

  let sf = max(data.fontSize - 4, 10)
  ctx |> set_font_ht(sf)
  ctx |> set_color(colWhite)
  draw_centered(ctx, "метры", center.x, center.y - radius * 0.18, fctx)

  var rvDigiFrame = colGreen
  var rvDigiTxt = colGreen
  if altitude < 150.0
    rvDigiFrame = colRed
    rvDigiTxt = colRed
  draw_digi_box(ctx, center.x, center.y + radius * 0.02, radius * 0.52, radius * 0.22, rvDigiFrame, rvDigiTxt, "{int(altitude)}", data)

  ctx |> set_font_ht(sf)
  ctx |> set_color(colWhite)
  draw_centered(ctx, "РВ", center.x, center.y + radius * 0.25, fctx)

  let clampedAlt = clamp(altitude, 0.0, maxA)
  var needleDeg = 270.0
  if clampedAlt <= 10.0
    needleDeg = 270.0 + clampedAlt / 10.0 * 22.5
  elif clampedAlt <= 20.0
    needleDeg = 292.5 + (clampedAlt - 10.0) / 10.0 * 37.5
  elif clampedAlt <= 30.0
    needleDeg = 330.0 + (clampedAlt - 20.0) / 10.0 * 30.0
  elif clampedAlt <= 40.0
    needleDeg = 360.0 + (clampedAlt - 30.0) / 10.0 * 30.0
  elif clampedAlt <= 50.0
    needleDeg = 390.0 + (clampedAlt - 40.0) / 10.0 * 30.0
  elif clampedAlt <= 100.0
    needleDeg = 420.0 + (clampedAlt - 50.0) / 50.0 * 30.0
  elif clampedAlt <= 200.0
    needleDeg = 450.0 + (clampedAlt - 100.0) / 100.0 * 60.0
  else
    needleDeg = 510.0 + (clampedAlt - 200.0) / 100.0 * 67.5
  let nA = needleDeg * (PI / 180.0)
  let nDir = float2(cos(nA), sin(nA))
  let nPerp = float2(-nDir.y, nDir.x)
  let baseP = center + nDir * radius * 0.35
  let tipP = center + nDir * radius * 0.78
  let pts <- to_array_move(fixed_array(tipP, baseP + nPerp * radius * 0.04, baseP - nPerp * radius * 0.04))
  ctx |> render_poly(pts, colCyan)
  ctx |> render_line_aa(pts, true, 1.0, float2(0.0), colCyan)

def draw_aoa(var ctx : GuiContext&; center : float2; radius : float; data : CanvasParams&; aoaDeg : float)
  var fctx : StdGuiFontContext
  let sf = max(data.fontSize - 4, 10)
  get_font_context(fctx, data.fontId, 0, 0, sf)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(sf)

  let arcR = radius * 0.70
  let minV = 0.0
  let maxV = 30.0
  let aoaSweep = 120.0

  let arcStart = 270.0 * (PI / 180.0)
  let arcEnd = (270.0 + aoaSweep) * (PI / 180.0)
  ctx |> render_sector_aa(center, float2(arcR), float2(arcStart, arcEnd), 2.0, colWhite, colEmpty)

  let redS = 270.0 * (PI / 180.0)
  let redE = (270.0 + (1.0 - 2.0 / 3.0) * aoaSweep) * (PI / 180.0)
  ctx |> render_sector_aa(center, float2(arcR * 1.08), float2(redS, redE), 2.5, colRed, colEmpty)

  ctx |> set_font_ht(sf)
  for i in range(0, 7)
    let val = float(i) * 5.0
    let frac = val / maxV
    let scrDeg = 270.0 + (1.0 - frac) * aoaSweep
    let ang = scrDeg * (PI / 180.0)
    let co = cos(ang)
    let si = sin(ang)
    let isMajor = i % 2 == 0
    let ri = arcR
    let ro = arcR + radius * (isMajor ? 0.12 : 0.07)
    tick(ctx, center.x, center.y, ang, ri, ro, isMajor ? 2.0 : 1.0, colWhite)

    if isMajor
      let numVal = i / 2
      let txt = "{numVal}"
      let bx = get_str_bbox(txt, txt |> length(), fctx)
      let labelR = arcR + radius * 0.18
      ctx |> set_color(colWhite)
      ctx |> goto_xy(center.x + co * labelR - bx.width.x * 0.5, center.y + si * labelR + bx.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, txt, txt |> length())

  let clampedAoa = clamp(aoaDeg, minV, maxV)
  let aoaFrac = clampedAoa / maxV
  let aoaScrDeg = 270.0 + (1.0 - aoaFrac) * aoaSweep
  let aoaA = aoaScrDeg * (PI / 180.0)
  let aoaCo = cos(aoaA)
  let aoaSi = sin(aoaA)
  let triTip = center + float2(aoaCo, aoaSi) * (arcR - radius * 0.02)
  let triPerp = float2(-aoaSi, aoaCo)
  let triBase = center + float2(aoaCo, aoaSi) * (arcR - radius * 0.12)
  let triPts <- to_array_move(fixed_array(triTip, triBase + triPerp * radius * 0.04, triBase - triPerp * radius * 0.04))
  ctx |> render_poly(triPts, colCyan)

  ctx |> set_font_ht(sf)
  ctx |> set_color(colCyan)
  let aoaDisp = clamp(aoaDeg, 0.0, 30.0)
  let aoaDispI = int(aoaDisp * 10.0)
  let aoaW = aoaDispI / 10
  let aoaF = aoaDispI % 10
  let aoaTxt = "{aoaW},{aoaF}"
  draw_centered(ctx, aoaTxt, center.x + radius * 0.5, center.y + radius * -0.25, fctx)

def draw_hsi(var ctx : GuiContext&; center : float2; radius : float; data : CanvasParams&; heading : float)
  ctx |> render_ellipse_aa(center, float2(radius), 2.0, colWhite, colEmpty)

  var fctx : StdGuiFontContext
  let cf = max(data.fontSize - 2, 10)
  get_font_context(fctx, data.fontId, 0, 0, cf)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(cf)

  for i in range(0, 72)
    let deg = float(i) * 5.0
    let ang = (deg - heading - 90.0) * (PI / 180.0)
    let co = cos(ang)
    let si = sin(ang)

    let isMajor = i % 6 == 0
    let isMid = i % 2 == 0 && !isMajor
    let ro = radius
    var ri = radius * 0.81
    if !isMajor && !isMid
      ri = radius * 0.875
    elif isMid
      ri = radius * 0.86
    ctx |> set_color(colWhite)
    ctx |> draw_line(center.x + co * ri, center.y + si * ri, center.x + co * ro, center.y + si * ro, isMajor ? 2.0 : 1.0)

    if isMajor
      let degi = int(deg)
      var txt = ""
      if degi == 0
        txt = "36"
      else
        txt = "{degi / 10}"
      let bx = get_str_bbox(txt, txt |> length(), fctx)
      let labelR = radius * 0.70
      ctx |> set_color(colWhite)
      ctx |> goto_xy(center.x + co * labelR - bx.width.x * 0.5, center.y + si * labelR + bx.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, txt, txt |> length())

  let rt <- to_array_move(fixed_array(
    center - float2(0.0, radius * 0.96),
    center - float2(radius * 0.045, radius * 1.05),
    center + float2(radius * 0.045, -radius * 1.05)))
  ctx |> render_poly(rt, colRed)

  let ccR = radius * 0.08
  let dotR = ccR * 0.25
  let dotSp = ccR * 1.8
  ctx |> set_color(colCyan)
  ctx |> render_ellipse_aa(center, float2(ccR), 2.0, colCyan, colEmpty)
  ctx |> render_ellipse_aa(float2(center.x - ccR - dotSp, center.y), float2(dotR), 1.5, colCyan, colCyan)
  ctx |> render_ellipse_aa(float2(center.x - ccR - dotSp * 2.0, center.y), float2(dotR), 1.5, colCyan, colCyan)
  ctx |> render_ellipse_aa(float2(center.x + ccR + dotSp, center.y), float2(dotR), 1.5, colCyan, colCyan)
  ctx |> render_ellipse_aa(float2(center.x + ccR + dotSp * 2.0, center.y), float2(dotR), 1.5, colCyan, colCyan)
  ctx |> render_ellipse_aa(float2(center.x, center.y - ccR - dotSp), float2(dotR), 1.5, colCyan, colCyan)
  ctx |> render_ellipse_aa(float2(center.x, center.y - ccR - dotSp * 2.0), float2(dotR), 1.5, colCyan, colCyan)
  ctx |> render_ellipse_aa(float2(center.x, center.y + ccR + dotSp), float2(dotR), 1.5, colCyan, colCyan)
  ctx |> render_ellipse_aa(float2(center.x, center.y + ccR + dotSp * 2.0), float2(dotR), 1.5, colCyan, colCyan)

  let setHdg = heading
  let shA = (setHdg - heading - 90.0) * (PI / 180.0)
  let shCo = cos(shA)
  let shSi = sin(shA)
  let shP = center + float2(shCo, shSi) * radius * 0.95
  let shPerp = float2(-shSi, shCo)
  let gTri <- to_array_move(fixed_array(
    shP + float2(shCo, shSi) * radius * 0.07,
    shP + shPerp * radius * 0.035,
    shP - shPerp * radius * 0.035))
  ctx |> render_poly(gTri, colGreen)

def draw_baro_alt(var ctx : GuiContext&; center : float2; radius : float; data : CanvasParams&; altitudeM : float)
  ctx |> render_ellipse_aa(center, float2(radius), 2.5, colWhite, colEmpty)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize - 2)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize - 2)

  for i in range(0, 10)
    let ang = (float(i) * 36.0 - 90.0) * (PI / 180.0)
    tick(ctx, center.x, center.y, ang, radius * 0.80, radius * 1.0, 2.5, colWhite)
    let txt = "{i}"
    let bx = get_str_bbox(txt, txt |> length(), fctx)
    let labelR = radius * 0.67
    ctx |> set_color(colWhite)
    ctx |> goto_xy(center.x + cos(ang) * labelR - bx.width.x * 0.5, center.y + sin(ang) * labelR + bx.width.y * 0.5)
    ctx |> draw_str_scaled(1.0, txt, txt |> length())

  for i in range(0, 20)
    if i % 2 == 0
      continue
    let ang = (float(i) * 18.0 - 90.0) * (PI / 180.0)
    tick(ctx, center.x, center.y, ang, radius * 0.87, radius * 1.0, 1.2, colWhite)

  for i in range(0, 100)
    if i % 5 == 0
      continue
    let ang = (float(i) * 3.6 - 90.0) * (PI / 180.0)
    tick(ctx, center.x, center.y, ang, radius * 0.90, radius * 1.0, 1.0, colWhite)

  let sf = max(data.fontSize - 4, 10)
  ctx |> set_font_ht(sf)
  ctx |> set_color(colWhite)
  draw_centered(ctx, "метры", center.x, center.y - radius * 0.18, fctx)

  draw_digi_box(ctx, center.x, center.y + radius * 0.02, radius * 0.52, radius * 0.22, colCyan, colCyan, "{int(altitudeM)}", data)

  ctx |> set_font_ht(sf)
  ctx |> set_color(colWhite)
  draw_centered(ctx, "ВЫСОТА", center.x, center.y + radius * 0.25, fctx)

  let altC = clamp(altitudeM, 0.0, 9999.0)
  let thA = (altC / 10000.0 * 360.0 - 90.0) * (PI / 180.0)
  let thDir = float2(cos(thA), sin(thA))
  let thPerp = float2(-thDir.y, thDir.x)
  let thBase = center + thDir * radius * 0.35
  let thTip = center + thDir * radius * 0.55
  let thPts <- to_array_move(fixed_array(thTip, thBase + thPerp * radius * 0.05, thBase - thPerp * radius * 0.05))
  ctx |> render_poly(thPts, colCyan)
  ctx |> render_line_aa(thPts, true, 1.0, float2(0.0), colCyan)

  let hundFr = (altC - float(int(altC / 1000.0)) * 1000.0) / 1000.0
  let hA = (hundFr * 360.0 - 90.0) * (PI / 180.0)
  let hDir = float2(cos(hA), sin(hA))
  let hPerp = float2(-hDir.y, hDir.x)
  let hBase = center + hDir * radius * 0.35
  let hTip = center + hDir * radius * 0.78
  let hPts <- to_array_move(fixed_array(hTip, hBase + hPerp * radius * 0.04, hBase - hPerp * radius * 0.04))
  ctx |> render_poly(hPts, colCyan)
  ctx |> render_line_aa(hPts, true, 1.0, float2(0.0), colCyan)

  ctx |> set_font_ht(sf)
  ctx |> set_color(colCyan)
  let pw = radius * 0.48
  let ph = radius * 0.16
  let px = center.x - pw * 0.5
  let py = center.y + radius * 0.38
  ctx |> render_frame(px, py, px + pw, py + ph, 1.0)
  let ptxt = "740.2"
  let pbx = get_str_bbox(ptxt, ptxt |> length(), fctx)
  ctx |> goto_xy(center.x - pbx.width.x * 0.5, py + ph - 2.0)
  ctx |> draw_str_scaled(1.0, ptxt, ptxt |> length())

def draw_top_bar(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; spdKmh : float)
  var fctx : StdGuiFontContext
  let sf = max(data.fontSize - 5, 9)
  get_font_context(fctx, data.fontId, 0, 0, sf)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(sf)

  let r1y = pos.y + float(sf) + 2.0
  let sp1 = size.x / 8.0

  draw_top_tab(ctx, pos.x, sp1, size.x, r1y, fctx, 0, "ПЛТ", 0.05)
  draw_top_tab(ctx, pos.x, sp1, size.x, r1y, fctx, 1, "НВГ", 0.04)
  draw_top_tab(ctx, pos.x, sp1, size.x, r1y, fctx, 2, "ОВО", 0.015)
  draw_top_tab(ctx, pos.x, sp1, size.x, r1y, fctx, 3, "БКС", 0.0)
  draw_top_tab(ctx, pos.x, sp1, size.x, r1y, fctx, 4, "БКО", -0.02)
  draw_top_tab(ctx, pos.x, sp1, size.x, r1y, fctx, 5, "РЛС", -0.035)
  draw_top_tab(ctx, pos.x, sp1, size.x, r1y, fctx, 6, "ОПС", -0.045)

  let r2y = r1y + float(sf) + 3.0

  ctx |> set_color(colYellow)
  let lblLeft = "СНС СВС ДИСС РВ ИНС СБКВ"
  ctx |> goto_xy(pos.x + size.x * 0.04, r2y)
  ctx |> draw_str_scaled(1.0, lblLeft, lblLeft |> length())

  ctx |> set_color(colYellow)
  if spdKmh < 5.0
    let lblR = "САУ ПОСАД-ЗАВИС"
    ctx |> goto_xy(pos.x + size.x * 0.35, r2y)
    ctx |> draw_str_scaled(1.0, lblR, lblR |> length())
  else
    let lblMid = "РУЧ УПР"
    ctx |> goto_xy(pos.x + size.x * 0.35, r2y)
    ctx |> draw_str_scaled(1.0, lblMid, lblMid |> length())

  ctx |> set_color(colYellow)
  ctx |> goto_xy(pos.x + size.x * 0.88, r2y)
  ctx |> draw_str_scaled(1.0, "ЭК", 2)

def draw_bottom_bar(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; spdKmh : float; heading : float)
  var fctx : StdGuiFontContext
  let sf = max(data.fontSize - 4, 10)
  get_font_context(fctx, data.fontId, 0, 0, sf)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(sf)

  let by = pos.y + size.y - float(sf) * 3.5

  let ny = pos.y + size.y - float(sf) - 2.0
  ctx |> set_color(colWhite)
  let navTxt = "ЗК {int(heading)}  ЗПУ {int(heading)}  ИНС   СБКВ   ИК"
  ctx |> goto_xy(pos.x + size.x * 0.15, ny)
  ctx |> draw_str_scaled(1.0, navTxt, navTxt |> length())

  ctx |> set_color(colRed)
  let vl = "VL = {int(spdKmh)} КМ/Ч"
  ctx |> goto_xy(pos.x + size.x * 0.675, by - size.y * 0.03)
  ctx |> draw_str_scaled(1.0, vl, vl |> length())
  let vt = "VT = {int(spdKmh * 0.6)} КМ/Ч"
  ctx |> goto_xy(pos.x + size.x * 0.675, by - size.y * 0.03 + float(sf) + 2.0)
  ctx |> draw_str_scaled(1.0, vt, vt |> length())

  ctx |> set_color(colWhite)
  let btnY = pos.y + size.y - float(sf) * 1.5
  ctx |> render_frame(pos.x + size.x * 0.85, btnY, pos.x + size.x * 0.90, btnY + float(sf) + 2.0, 1.0)
  draw_centered(ctx, "VT", pos.x + size.x * 0.875, btnY + float(sf) * 0.5 + 1.0, fctx)
  ctx |> render_frame(pos.x + size.x * 0.91, btnY, pos.x + size.x * 0.96, btnY + float(sf) + 2.0, 1.0)
  draw_centered(ctx, "VL", pos.x + size.x * 0.935, btnY + float(sf) * 0.5 + 1.0, fctx)
