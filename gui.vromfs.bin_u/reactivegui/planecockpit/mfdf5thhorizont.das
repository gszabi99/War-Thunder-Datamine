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

struct CanvasParams
  fontId : int = -1
  fontSize : int = 20
  horMask : Picture?
  lineWidth : float = 2.

let green = E3DCOLOR(0xFF10FF10)
let transparent = E3DCOLOR(0x00000000)
let skyColor = E3DCOLOR(0xFF0038CC)
let groundColor = E3DCOLOR(0xFF2710)
let black = E3DCOLOR(0xFF000000)
let lineColor = E3DCOLOR(0xFFFFFF0F)

[export]
def setup(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 12)
  storage.horMask = props |> getPicture("horMask")
  storage.lineWidth = props |> getFloat("lineWidth", 2.)

[export, unused_argument(rstate)]
def draw(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return

  draw_avia_horizont(ctx, rdata.pos + float2(rdata.size.x * 0.5 - rdata.size.y * 0.3, rdata.size.y * 0.15),
   float2(rdata.size.y * 0.6, rdata.size.y * 0.7), data, fmw.tangage, fmw.roll)
  draw_speed(ctx, rdata.pos + float2(rdata.size.x * 0.25, rdata.size.y * 0.15),
   float2(rdata.size.x * 0.08, float(data.fontSize) * 1.4), data, hero.speed * mpsToKnots)
  let baroAlt = (hero.unitTm[3].y - get_app().currentScene.waterLevel) * metrToFeet
  draw_baro_alt(ctx, rdata.pos + float2(rdata.size.x * 0.68, rdata.size.y * 0.15),
   float2(rdata.size.x * 0.1, float(data.fontSize) * 1.4), data, baroAlt)
  let altitude = fmw.fm.currentAlt * metrToFeet
  draw_alt(ctx, rdata.pos + float2(rdata.size.x * 0.68, rdata.size.y * 0.75),
   float2(rdata.size.x * 0.14, float(data.fontSize)), data, altitude)
  draw_climb_speed(ctx, rdata.pos + float2(rdata.size.x * 0.67, rdata.size.y * 0.3),
   float2(rdata.size.x * 0.1, rdata.size.y * 0.4), data, fmw.fm.vertSpeed * mpsToFpm, false)
  draw_bank_indicator(ctx, rdata.pos + float2(rdata.size.x * 0.4, rdata.size.y * 0.75),
   float2(rdata.size.x * 0.2, rdata.size.y * 0.25), fmw.ballVal, false)
  let compass = (norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * 180. / PI
  draw_compass(ctx, rdata.pos + float2(rdata.size.x * 0.5, 10.), rdata.size, data, compass)
  draw_labels(ctx, rdata.pos, rdata.size, data)

  ctx |> set_color(lineColor)
  ctx |> draw_line(rdata.pos.x, rdata.pos.y + rdata.size.y, rdata.pos.x + rdata.size.x, rdata.pos.y + rdata.size.y, 2.)

def draw_avia_horizont(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; tangage : float; roll : float)
  let horLevel = pos.y + size.y * cvt(tangage, -30., 30., 0., 1.)
  let tc = float2(0., 0.)
  let origin = pos + size * 0.5

  ctx |> set_viewport(pos.x, pos.y, pos.x + size.x, pos.y + size.y)
  ctx |> setRotViewTm(origin.x, origin.y, -roll * degToRad, 0., false)

  ctx |> set_color(skyColor)
  let dim = max(size.x, size.y)
  ctx |> render_rect(pos.x + (size.x - dim) * 0.5, pos.y, pos.x + dim, horLevel, tc, tc, tc)
  ctx |> set_color(groundColor)
  ctx |> render_rect(pos.x + (size.x - dim) * 0.5, horLevel, pos.x + dim, pos.y + size.y, tc, tc, tc)

  ctx |> set_color(lineColor)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  for i in range(-5, 7)
    let markVal = (int(tangage) / 5) * 5 + i * 5
    let posY = pos.y + size.y * 0.5 + (tangage - float(markVal)) * 0.01667 * size.y
    ctx |> set_alpha_blend(BlendMode.NONPREMULTIPLIED)

    if markVal > 0
      ctx |> set_color(lineColor)
      if abs(markVal % 10) > 0
        ctx |> draw_line(pos.x + size.x * 0.45, posY, pos.x + size.x * 0.55, posY, 2.)
      else
        ctx |> draw_line(pos.x + size.x * 0.35, posY, pos.x + size.x * 0.65, posY, 2.)
    elif markVal != 0
      if abs(markVal % 10) > 0
        ctx |> render_line_dashed(float2(pos.x + size.x * 0.45, posY), float2(pos.x + size.x * 0.55, posY), 2., 3., 2., black)
      else
        ctx |> render_line_dashed(float2(pos.x + size.x * 0.35, posY), float2(pos.x + size.x * 0.65, posY), 2., 3., 2., black)
    else
      let left <- to_array_move(fixed_array(
        origin - float2(size.x * 0.18, 0.),
        origin - float2(size.x * 0.37, 0.),
        origin - float2(size.x * 0.37, size.y * -0.015)))
      ctx |> render_line_aa(left, false, 2., float2(0., 0.), lineColor)
      let leftArrow <- to_array_move(fixed_array(
        origin - float2(size.x * 0.2, size.y * 0.02),
        origin - float2(size.x * 0.18, 0.),
        origin - float2(size.x * 0.2, size.y * -0.02)))
      ctx |> render_line_aa(leftArrow, false, 2., float2(0., 0.), lineColor)

      let right <- to_array_move(fixed_array(
        origin + float2(size.x * 0.18, 0.),
        origin + float2(size.x * 0.37, 0.),
        origin + float2(size.x * 0.37, size.y * 0.015)))
      ctx |> render_line_aa(right, false, 2., float2(0., 0.), lineColor)

    if abs(markVal % 10) == 0 && markVal != 0
      let text = "{abs(markVal)}"
      let strBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> set_color(markVal > 0 ? lineColor : black)
      ctx |> goto_xy(pos.x + size.x * 0.3 - strBox.width.x, posY + strBox.width.y * 0.5)
      ctx |> draw_str_scaled(1., text, text |> length())

      ctx |> goto_xy(pos.x + size.x * 0.7, posY + strBox.width.y * 0.5)
      ctx |> draw_str_scaled(1., text, text |> length())

  let triangle <- to_array_move(fixed_array(
    origin - float2(0., size.y * 0.45),
    origin - float2(size.y * 0.02, size.y * 0.42),
    origin - float2(-size.y * 0.02, size.y * 0.42)))
  ctx |> render_poly(triangle, lineColor)
  ctx |> render_line_aa(triangle, true, 1., float2(0., 0.), lineColor)

  ctx |> resetViewTm()

  ctx |> render_ellipse_aa(origin, size * 0.02, 2., lineColor, transparent)
  let wl <- to_array_move(fixed_array(
    origin - float2(size.x * 0.02, 0.),
    origin - float2(size.x * 0.15, 0.)))
  ctx |> render_line_aa(wl, false, 2., float2(0., 0.), lineColor)
  let wr <- to_array_move(fixed_array(
    origin + float2(size.x * 0.02, 0.),
    origin + float2(size.x * 0.15, 0.)))
  ctx |> render_line_aa(wr, false, 2., float2(0., 0.), lineColor)
  let tail <- to_array_move(fixed_array(
    origin - float2(0., size.y * 0.02),
    origin - float2(0., size.y * 0.05)))
  ctx |> render_line_aa(tail, false, 2., float2(0., 0.), lineColor)

  ctx |> set_color(black)
  for i in range(-9, 10)
    var angle = float(i) * 5.
    let angleM = abs(angle)
    if angleM > 45. || (angleM != 45. && angleM % 10. > 0.) || angleM == 40.
      continue
    if angle == 0.
      let trianglePoints <- to_array_move(fixed_array(
        origin - float2(0., size.y * 0.46),
        origin - float2(size.y * 0.02, size.y * 0.5),
        origin - float2(-size.y * 0.02, size.y * 0.5)))
      ctx |> render_poly(trianglePoints, black)
      ctx |> render_line_aa(trianglePoints, true, 1., float2(0., 0.), black)
    else
      let outL = 0.45
      angle += 90.
      let cosa = cos(angle * degToRad)
      let sina = sin(angle * degToRad)
      let mark <- to_array_move(fixed_array<float2>(origin - float2(cosa * size.x * 0.5, sina * size.y * 0.5),
      origin - float2(cosa * size.x * outL, sina * size.y * outL)))
      ctx |> render_line_aa(mark, false, 3., float2(0.), black)

  render_picture(ctx, data.horMask, pos - float2(1.), size + float2(2.), black)
  ctx |> restore_viewport

  ctx |> render_sector_aa(origin, float2(size.x * 0.5, size.y * 0.5), float2(-PI * 0.847, -PI * 0.153), 3., lineColor, transparent)
  ctx |> render_sector_aa(origin, float2(size.x * 0.5, size.y * 0.5), float2(PI * 0.15, PI * 0.846), 3., lineColor, transparent)
  ctx |> set_color(lineColor)
  ctx |> draw_line(origin.x - size.x * 0.44, origin.y - size.y * 0.23, origin.x - size.x * 0.44, origin.y + size.y * 0.23, 3.)
  ctx |> draw_line(origin.x + size.x * 0.44, origin.y - size.y * 0.23, origin.x + size.x * 0.44, origin.y + size.y * 0.23, 3.)

def draw_speed(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; speed : float)
  ctx |> set_color(green)
  let rb = pos + size
  ctx |> render_frame(pos.x, pos.y, rb.x, rb.y, 2.)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let text = "{int(speed)}"
  let strBox = get_str_bbox(text, text |> length(), fctx)
  ctx |> goto_xy(rb.x - strBox.width.x - 4., pos.y + (size.y + strBox.width.y) * 0.5)
  ctx |> draw_str_scaled(1., text, text |> length())

def draw_baro_alt(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; alt : float)
  ctx |> set_color(green)
  let rb = pos + size
  ctx |> render_frame(pos.x, pos.y, rb.x, rb.y, 2.)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let text = "{int(alt)}"
  let strBox = get_str_bbox(text, text |> length(), fctx)
  ctx |> goto_xy(rb.x - strBox.width.x - 4., pos.y + (size.y + strBox.width.y) * 0.5)
  ctx |> draw_str_scaled(1., text, text |> length())

def draw_alt(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; alt : float)
  ctx |> set_color(green)
  let rb = pos + size

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let labelText = "RALT"
  ctx |> goto_xy(pos.x, rb.y)
  ctx |> draw_str_scaled(1., labelText, labelText |> length())

  let altText = "{int(alt)}"
  let strBox = get_str_bbox(altText, altText |> length(), fctx)
  ctx |> goto_xy(rb.x - strBox.width.x, rb.y)
  ctx |> draw_str_scaled(1., altText, altText |> length())

def draw_climb_speed(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; climb : float; is_small : bool)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(lineColor)

  for i in range(0, 9)
    let step = 12.5
    let posY = pos.y + float(i) * step
    let len = size.x * (i % 2 != 0 ? 0.1 : 0.2)
    ctx |> draw_line(pos.x, posY, pos.x + len, posY, 2.)

    if i % 2 == 0
      let text = "{(4 - i) / 2}"
      let strBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(pos.x - strBox.width.x - 3., posY + strBox.width.y * 0.5)
      ctx |> draw_str_scaled(1., text, text |> length())

  let markPos = float2(pos.x + size.x * 0.2, pos.y + cvt(climb, -2000., 2000., 1., 0.) * size.y)
  if is_small
    let mark <- to_array_move(fixed_array(
      markPos,
      markPos + float2(size.x * 0.3, size.y * 0.08),
      markPos + float2(size.x * 0.3, size.y * -0.08),
      ))
    ctx |> render_poly(mark, climb < 0. ? groundColor : skyColor)
    ctx |> render_line_aa(mark, true, 2., float2(0., 0.), climb < 0. ? groundColor : skyColor)
  else
    let mark <- to_array_move(fixed_array(
      markPos,
      markPos + float2(size.x * 0.15, size.y * 0.08),
      markPos + float2(size.x * 0.8, size.y * 0.08),
      markPos + float2(size.x * 0.8, size.y * -0.08),
      markPos + float2(size.x * 0.15, size.y * -0.08),
      ))
    ctx |> render_poly(mark, climb < 0. ? groundColor : skyColor)
    ctx |> render_line_aa(mark, true, 2., float2(0., 0.), lineColor)

    let text = "{int(abs(climb))}"
    let strBox = get_str_bbox(text, text |> length(), fctx)
    ctx |> goto_xy(markPos.x + size.x * 0.75 - strBox.width.x, markPos.y + strBox.width.y * 0.5)
    ctx |> draw_str_scaled(1., text, text |> length())

def draw_bank_indicator(var ctx : GuiContext&; pos : float2; size : float2; bank : float; is_small : bool)
  let origin = pos + float2(size.x * 0.5, size.y * 1.5)
  let radius = float2(size.y)
  ctx |> render_sector_aa(origin, radius, float2(PI * -0.7, PI * -0.3), 2., lineColor, transparent)
  ctx |> render_sector_aa(origin, radius * 0.82, float2(PI * -0.7, PI * -0.3), 2., lineColor, transparent)
  if is_small
    ctx |> draw_line(pos.x + size.x * 0.42, pos.y + size.y * 0.6, pos.x + size.x * 0.58, pos.y + size.y * 0.6, 10.)
    ctx |> draw_line(pos.x + size.x * 0.76, pos.y + size.y * 0.63, pos.x + size.x * 0.88, pos.y + size.y * 0.7, 10.)
    ctx |> draw_line(pos.x + size.x * 0.24, pos.y + size.y * 0.63, pos.x + size.x * 0.12, pos.y + size.y * 0.7, 10.)
  else
    ctx |> draw_line(pos.x + size.x * 0.44, pos.y + size.y * 0.6, pos.x + size.x * 0.56, pos.y + size.y * 0.6, 10.)
    ctx |> draw_line(pos.x + size.x * 0.67, pos.y + size.y * 0.62, pos.x + size.x * 0.78, pos.y + size.y * 0.72, 10.)
    ctx |> draw_line(pos.x + size.x * 0.34, pos.y + size.y * 0.62, pos.x + size.x * 0.24, pos.y + size.y * 0.7, 10.)

  let cosa = cos(PI * -0.3)
  let sina = sin(PI * -0.3)
  let l1 <- to_array_move(fixed_array(
    origin + float2(radius.x * cosa, radius.y * sina),
    origin + float2(radius.x * cosa * 0.82, radius.y * sina * 0.82)
  ))
  ctx |> render_line_aa(l1, false, 2., float2(0.), lineColor)
  let l2 <- to_array_move(fixed_array(
    origin + float2(-radius.x * cosa, radius.y * sina),
    origin + float2(-radius.x * cosa * 0.82, radius.y * sina * 0.82)
  ))
  ctx |> render_line_aa(l2, false, 2., float2(0.), lineColor)

  let angle = PI * -0.5 + bank * degToRad
  ctx |> render_sector_aa(origin, radius * 0.7, float2(angle - PI * 0.03, angle + PI * 0.03), 8., lineColor, transparent)

def draw_compass(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; compass : float)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_color(lineColor)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let valueStrBox = get_str_bbox("222", 3, fctx)
  ctx |> render_frame(pos.x - valueStrBox.width.x * 0.7, pos.y - data.lineWidth - 3.,
   pos.x + valueStrBox.width.x * 0.7, pos.y + valueStrBox.width.y + data.lineWidth + 3., data.lineWidth)

  let compassText = "{roundi(compass)}"
  let compassTextBox = get_str_bbox(compassText, compassText |> length(), fctx)
  ctx |> goto_xy(pos.x - compassTextBox.width.x * 0.5, pos.y + compassTextBox.width.y)
  ctx |> draw_str_scaled(1.0, compassText, compassText |> length())

  for i in range(-2, 3)
    let markVal = (roundi(compass / 10.)) * 10 + i * 10
    var markPos = pos + float2((-compass + float(markVal)) * 0.006 * size.x, 0.)

    let text = "{markVal / 10}"
    let markStrBox = get_str_bbox(text, text |> length(), fctx)
    markPos.x -= markStrBox.width.x * 0.5
    if (markPos.x + markStrBox.width.x > pos.x - valueStrBox.width.x * 0.6) && (markPos.x < pos.x + valueStrBox.width.x * 0.6)
      continue

    ctx |> goto_xy(markPos.x, markPos.y + markStrBox.width.y)
    ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_labels(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_color(green)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let adhsi = "ADHSI"
  let adhsiStrBox = get_str_bbox(adhsi, adhsi |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.2, pos.y + adhsiStrBox.width.y + 10.)
  ctx |> draw_str_scaled(1.0, adhsi, adhsi |> length())

  let bcn = "BCN"
  let bcnStrBox = get_str_bbox(bcn, bcn |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.15, pos.y + size.y * 0.65 + bcnStrBox.width.y)
  ctx |> draw_str_scaled(1.0, bcn, bcn |> length())

  let hi = "HI"
  let hiStrBox = get_str_bbox(hi, hi |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.15, pos.y + size.y * 0.65 + bcnStrBox.width.y + hiStrBox.width.y + 2.)
  ctx |> draw_str_scaled(1.0, hi, hi |> length())

[export, unused_argument(rstate)]
def draw_small(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return

  draw_avia_horizont(ctx, rdata.pos + float2(rdata.size.x * 0.5 - rdata.size.y * 0.4, rdata.size.y * 0.16),
   float2(rdata.size.y * 0.8, rdata.size.y * 0.7), data, fmw.tangage, fmw.roll)
  draw_speed(ctx, rdata.pos + float2(rdata.size.x * 0.05, rdata.size.y * 0.15),
   float2(rdata.size.x * 0.15, float(data.fontSize) * 1.4), data, hero.speed * mpsToKnots)
  let baroAlt = (hero.unitTm[3].y - get_app().currentScene.waterLevel) * metrToFeet
  draw_baro_alt(ctx, rdata.pos + float2(rdata.size.x * 0.75, rdata.size.y * 0.15),
   float2(rdata.size.x * 0.16, float(data.fontSize) * 1.4), data, baroAlt)
  draw_climb_speed(ctx, rdata.pos + float2(rdata.size.x * 0.9, rdata.size.y * 0.3),
   float2(rdata.size.x * 0.15, rdata.size.y * 0.4), data, fmw.fm.vertSpeed * mpsToFpm, true)
  draw_bank_indicator(ctx, rdata.pos + float2(rdata.size.x * 0.4, rdata.size.y * 0.77),
   float2(rdata.size.x * 0.2, rdata.size.y * 0.25), fmw.ballVal, true)
  let compass = (norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * 180. / PI
  draw_compass(ctx, rdata.pos + float2(rdata.size.x * 0.5, 20.), rdata.size, data, compass)

  ctx |> set_color(lineColor)
  ctx |> draw_line(rdata.pos.x, rdata.pos.y + rdata.size.y, rdata.pos.x + rdata.size.x, rdata.pos.y + rdata.size.y, 2.)
  ctx |> draw_line(rdata.pos.x + rdata.size.x, rdata.pos.y, rdata.pos.x + rdata.size.x, rdata.pos.y + rdata.size.y, 2.)